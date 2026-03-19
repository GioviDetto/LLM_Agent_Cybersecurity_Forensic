# Architecture Deep Dive: Direct vLLM Instantiation

## How vLLM Direct Instantiation Works

This document explains the internal architecture and execution flow of the new direct vLLM instantiation approach.

## High-Level Flow

```
User Command
    │
    bash scripts/run_agent_unified.sh
    │
    ├─ Parse arguments → Sets env vars
    │
    ├─ Pre-flight checks
    │   ├─ Python installed?
    │   ├─ vLLM installed?
    │   └─ Dependencies present?
    │
    └─ Execute: python3 src/run_agent.py
        │
        ├─ Load configuration from .env
        │
        ├─ Initialize embeddings (HF or OpenAI)
        │
        ├─ Create agent graph
        │
        └─ For each PCAP event:
            │
            ├─ Agent needs LLM → init_llm("vllm/meta-llama/...")
            │   │
            │   └─ Factory detects "vllm/" prefix
            │       │
            │       └─ Calls get_vllm_model()
            │           │
            │           └─ Creates VLLMChatModel instance
            │               │
            │               └─ On first invoke() call:
            │                   └─ _load_model() loads vLLM directly
            │
            ├─ Agent calls LLM.invoke(messages)
            │   │
            │   └─ VLLMChatModel._generate(messages)
            │       │
            │       ├─ Format messages as prompt string
            │       │
            │       ├─ Create SamplingParams
            │       │
            │       └─ Call: self._vllm_model.generate([prompt], params)
            │           │
            │           └─ Direct GPU/CPU inference
            │               └─ Return results
            │
            └─ Agent processes results
```

## Detailed: vLLM Model Loading

### Understanding `_load_model()`

```python
def _load_model(self):
    """Load vLLM model on first use."""
    if self._vllm_model is None:
        self._vllm_model = LLM(
            model=self.model,                           # 1. Model name
            gpu_memory_utilization=self.gpu_memory_utilization,  # 2. GPU %
            trust_remote_code=True,                     # 3. Allow custom code
            dtype="auto"                                # 4. Auto dtype
        )
```

**What happens:**

1. **Model Name** (`"meta-llama/Meta-Llama-3-8B-Instruct"`)
   - vLLM checks HuggingFace cache
   - If not cached → Downloads from HuggingFace
   - Saves to `~/.cache/huggingface/hub/`

2. **GPU Memory Utilization** (`0.9`)
   - Sets max GPU allocation to 90% of available
   - vLLM manages memory dynamically
   - Leaves 10% for OS and other processes

3. **Trust Remote Code** (`True`)
   - Allows execution of custom Python code in models
   - Required for many modern models
   - Security consideration: Only load trusted models

4. **Data Type** (`"auto"`)
   - Automatically selects optimal dtype
   - Usually FP16 (float16) for GPU memory efficiency
   - Can be overridden with explicit type

### Lazy Loading Explained

```python
class VLLMChatModel:
    _vllm_model: Optional[LLM] = None
    
    def __init__(self, **data):
        super().__init__(**data)
        # Model NOT loaded here!
    
    def _generate(self, messages, **kwargs):
        self._load_model()  # Loaded on first use!
        outputs = self._vllm_model.generate(...)
```

**Why lazy loading?**

1. **Fast initialization:** Creating VLLMChatModel is instant
2. **Defer overhead:** Model loading only happens when first inference needed
3. **Flexible lifecycle:** Can create multiple model instances

**Timeline:**
```
t=0:     VLLMChatModel created
         ├─ __init__ runs ~10ms
         └─ _vllm_model = None

t=1:     First call to _generate()
         ├─ Check: if _vllm_model is None
         ├─ Load model: LLM(...)
         │   └─ Takes 5-30 seconds
         └─ Model loaded and ready

t=>2:    Subsequent calls
         └─ _vllm_model already loaded
             └─ Inference only (~3-5 seconds)
```

## Message Formatting

### Challenge: vLLM vs LangChain Message Format

**LangChain format (from agent):**
```python
messages = [
    SystemMessage("You are a security analyst"),
    HumanMessage("Analyze this PCAP"),
    AIMessage("I'll help"),
    HumanMessage("Focus on port 8080")
]
```

**vLLM format (what model expects):**
```python
prompt = """<s>[INST] <<SYS>>
You are a security analyst
<</SYS>>

Analyze this PCAP [/INST]
I'll help</s><s>[INST]
Focus on port 8080 [/INST]"""
```

### Solution: `_format_messages_to_prompt()`

```python
@staticmethod
def _format_messages_to_prompt(messages: List[dict]) -> str:
    """Format messages into a chat prompt string."""
    prompt = ""
    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        
        if role == "system":
            # System message wrapped in SYS tags
            prompt += f"<s>[INST] <<SYS>>\n{content}\n<</SYS>>\n\n"
        elif role == "user":
            # User message ends with [/INST]
            prompt += f"{content} [/INST]"
        elif role == "assistant":
            # Assistant response, then new user turn
            prompt += f" {content}\n</s><s>[INST] "
    
    # Ensure prompt ends properly
    if not prompt.endswith("[/INST]"):
        prompt += " [/INST]"
    
    return prompt
```

**Example conversion:**

Input message:
```python
{"role": "user", "content": "What is CVE-2022-24706?"}
```

Output prompt:
```
<s>[INST] What is CVE-2022-24706? [/INST]
```

### Why This Format?

This is the **Llama 2 chat format**, which is the standard for:
- Meta-Llama-3
- Mistral
- Other open-source chat models

Different models may use different formats. This wrapper uses the most common one.

## Sampling Parameters

### Configuration Options

```python
sampling_params = SamplingParams(
    temperature=0.7,      # Randomness (0.0=deterministic, 1.0=random)
    top_p=0.95,          # Nucleus sampling (0.0-1.0)
    max_tokens=1024,     # Max output length
    stop=["</response>"] # Stop generation at these tokens
)
```

**What each does:**

| Parameter | Range | Effect | Default |
|-----------|-------|--------|---------|
| `temperature` | 0.0-2.0 | Lower = focused, Higher = random | 0.7 |
| `top_p` | 0.0-1.0 | Nucleus sampling cutoff | 0.95 |
| `max_tokens` | 1+ | Max output tokens | 1024 |
| `stop` | List | Stop token strings | [] |

**Recommended values for forensic analysis:**
- `temperature=0.5` - More deterministic
- `top_p=0.9` - Good balance
- `max_tokens=2048` - Detailed responses
- `stop=["<END>", "---"]` - Reliable termination

## GPU Memory Management

### How Memory Allocation Works

```
GPU Total Memory: 24 GB

vLLM allocation = 24 GB × gpu_memory_utilization
vLLM allocation = 24 GB × 0.9 = 21.6 GB

Model weights:    8.2 GB  (8B model)
KV cache:        12.0 GB  (for batching)
Overhead:         1.4 GB  (allocator, utilities)
Free:             2.4 GB  (OS, other)
```

### Adjusting GPU Memory

```bash
# Check GPU memory
nvidia-smi

# Run with specific fraction
bash scripts/run_agent_unified.sh --gpu-memory 0.7

# Monitor during execution
watch -n 1 nvidia-smi
```

### Memory Efficiency Tips

1. **Use smaller models:**
   ```bash
   # 3B model uses ~2GB
   bash scripts/run_agent_unified.sh --model microsoft/phi-2
   ```

2. **Reduce max tokens:**
   ```bash
   --max-tokens 512  # Instead of 1024
   ```

3. **Use quantization (in future):**
   ```python
   # Lower precision = less memory
   dtype="float16"  # 50% less than float32
   ```

## Performance Characteristics

### Why Direct Instantiation is Faster

#### Old (HTTP-based)

```
Agent calls LLM.invoke()
    │
    └─ VLLMChatModel._generate()
        │
        ├─ Serialize: messages → JSON
        │
        ├─ Make HTTP request to server
        │   ├─ Network latency: ~10-50ms
        │   ├─ Server processing: ~3000ms
        │   └─ Response transmission: ~10-20ms
        │
        └─ Deserialize: JSON → response
            
Total: ~3030-3070ms (3+ seconds)
```

#### New (Direct)

```
Agent calls LLM.invoke()
    │
    └─ VLLMChatModel._generate()
        │
        ├─ Format: messages → prompt string
        │
        ├─ Call vLLM directly
        │   └─ GPU inference: ~3000ms
        │
        └─ Extract results from output objects
            
Total: ~3000ms (3 seconds)
```

**Difference: ~30-70ms per request**  
**Savings over 100 requests: 3-7 seconds** ⚡

### Scalability

**Single Analysis:**
- 1 LLM call: ~3 seconds
- 10 LLM calls: ~30 seconds
- 100 LLM calls: ~5 minutes

**Memory grows with:**
- Model size (fixed)
- Batch size (adaptive)
- Context length (adaptive)

## Error Handling

### What Happens on Error?

```python
try:
    outputs = self._vllm_model.generate([prompt], sampling_params)
    content = output.outputs[0].text.strip()
except Exception as e:
    # vLLM error occurred
    raise ValueError(f"vLLM inference failed: {e}")
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| CUDA OOM | GPU too small | Reduce `gpu_memory_utilization` |
| Model not found | Wrong model name | Check HuggingFace |
| Connection refused | Not running | Script starts automatically |
| Token limit | Response too long | Increase `max_tokens` |

## Async Support

### Current Implementation

```python
async def _agenerate(self, messages, **kwargs):
    """Async generate text from messages using vLLM."""
    # For now, run sync version in async context
    return self._generate(messages, **kwargs)
```

**Note:** This is a "pseudo-async" implementation. vLLM doesn't have native async API, so we wrap the sync version.

**Why this works:**
- LangChain calls can be async
- Wrapping sync code in async is acceptable
- Real async would require vLLM's async features (future work)

## Resource Cleanup

### Model Lifecycle

```python
def __del__(self):
    """Clean up vLLM resources on model deletion."""
    if self._vllm_model is not None:
        del self._vllm_model
        self._vllm_model = None
```

**What happens:**
1. Python deletes VLLMChatModel instance
2. `__del__()` is called
3. vLLM GPU memory is freed
4. Process can exit cleanly

### Manual Cleanup (if needed)

```python
# If you want to free GPU memory manually
del llm

# Force garbage collection
import gc
gc.collect()

# Verify memory freed
# (check with nvidia-smi in another terminal)
```

## Comparison with Alternatives

### Alternative 1: Call External API

```python
# In VLLMChatModel._generate()
response = openai.ChatCompletion.create(
    model="gpt-4o",
    messages=messages
)
```

**Pros:** No local GPU needed  
**Cons:** Slower, costs $$, privacy concerns

### Alternative 2: HTTP Server (Old)

```python
# In VLLMChatModel._generate()
response = client.post(
    "http://localhost:8000/v1/chat/completions",
    json=request
)
```

**Pros:** Can scale to multiple clients  
**Cons:** More complex, network overhead

### Alternative 3: Direct Instantiation ✅ (Current)

```python
# In VLLMChatModel._generate()
outputs = self._vllm_model.generate([prompt], sampling_params)
```

**Pros:** Simple, fast, full control ✅✅✅  
**Cons:** Single process only

## Future Optimizations

### Possible Improvements

1. **Batching:**
   ```python
   # Process multiple PCAP events in parallel
   outputs = llm.generate(prompts=[p1, p2, p3, p4])
   ```

2. **Streaming:**
   ```python
   # Get results as they're generated
   for token in llm.stream(prompt):
       print(token, end="", flush=True)
   ```

3. **Quantization:**
   ```python
   # Use 4-bit models to save 75% memory
   llm = LLM("model", quantization="gptq")
   ```

4. **Multi-LoRA:**
   ```python
   # Use task-specific adapters
   llm = LLM("model", lora_modules=[...])
   ```

## Summary

**Direct vLLM instantiation provides:**

✅ Simple integration (no server)  
✅ Fast execution (no network overhead)  
✅ Full control (direct API)  
✅ Clear error handling  
✅ Resource cleanup  
✅ Scalable within single process  

**Architecture is:**
- Clean (factory pattern)
- Maintainable (single responsibility)
- Extensible (easy to add variations)
- Production-ready (error handling, cleanup)

---

For more details, see:
- `VLLM_DIRECT_INSTANTIATION.md` - Full technical guide
- `VLLM_DIRECT_QUICK_START.md` - Quick reference
- `VLLM_EXAMPLE_WALKTHROUGH.md` - Step-by-step examples
