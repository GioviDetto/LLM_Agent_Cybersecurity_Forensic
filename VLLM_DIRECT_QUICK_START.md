# Quick Start: Direct vLLM Instantiation

## What Changed?

The vLLM integration has been simplified from a **client-server model** to **direct model loading**:

| Aspect | Before | After |
|--------|--------|-------|
| Approach | HTTP API to separate vLLM server | Direct Python API in same process |
| Scripts | 2 separate scripts (server + agent) | 1 unified script |
| Performance | Slower (HTTP overhead) | Faster (direct execution) |
| Complexity | Moderate (manage 2 processes) | Simple (1 process) |
| Memory | 4.5 GB total | 3.5 GB total |

## Installation

### 1. Update vLLM (if needed)

```bash
pip install vllm==0.6.7
```

### 2. That's it! ✅

No more complex setup steps. Everything else is the same!

## Run Your Analysis

### Option A: Default Settings (Recommended for first-time)

```bash
bash scripts/run_agent_unified.sh
```

This runs with:
- Model: Meta-Llama-3-8B-Instruct
- GPU Memory: 90%
- Events: 20
- Dataset: CFA-benchmark

### Option B: Custom Settings

```bash
# With a different model
bash scripts/run_agent_unified.sh --model mistralai/Mistral-7B-Instruct-v0.2

# With less GPU memory (for smaller GPUs)
bash scripts/run_agent_unified.sh --gpu-memory 0.6

# With local embeddings
bash scripts/run_agent_unified.sh --use-local-embeddings

# Full example
bash scripts/run_agent_unified.sh \
    --model meta-llama/Llama-2-13b-chat-hf \
    --gpu-memory 0.8 \
    --events 50 \
    --use-local-embeddings
```

### Option C: Help

```bash
bash scripts/run_agent_unified.sh --help
```

## What's Different in Code?

### Loading the Model

**Before:**
```python
# Had to wait for separate vLLM server to be running
# Then: init_llm("vllm/meta-llama/...")
# Connected via HTTP to localhost:8000
```

**After:**
```python
# Just call init_llm() as before
init_llm("vllm/meta-llama/Meta-Llama-3-8B-Instruct")
# Model loads directly in same process
```

### Behind the Scenes

```python
# Old: VLLMChatModel._generate()
#   └─ httpx.Client.post(f"{base_url}/chat/completions")

# New: VLLMChatModel._generate()
#   └─ self._vllm_model.generate([prompt], sampling_params)
```

## Configuration

### Environment Variables (Updated)

```bash
# Still used
VLLM_MODEL=meta-llama/Meta-Llama-3-8B-Instruct
VLLM_MAX_TOKENS=1024

# Changed: GPU memory fraction instead of server URL
VLLM_GPU_MEMORY=0.9  # Instead of VLLM_BASE_URL

# New: GPU memory can be tuned per run
bash scripts/run_agent_unified.sh --gpu-memory 0.7
```

### .env File (.env.example updated)

```env
# New vLLM configuration (direct mode)
VLLM_MODEL = meta-llama/Meta-Llama-3-8B-Instruct
VLLM_MAX_TOKENS = 1024
VLLM_GPU_MEMORY = 0.9  # ← GPU memory fraction (0.0-1.0)

# OLD configuration (no longer used)
# VLLM_BASE_URL = http://localhost:8000/v1  ❌ REMOVE THIS
```

## Troubleshooting

### Issue: "vLLM is not installed"
```bash
pip install vllm
```

### Issue: "CUDA out of memory"
```bash
# Use less GPU memory
bash scripts/run_agent_unified.sh --gpu-memory 0.5
```

### Issue: First run is slow
**This is normal!** (20-60 seconds)
- Model downloads from HuggingFace (~30-60s)
- Model loads into GPU (~5-10s)

Subsequent runs are ~10 seconds (model cached).

### Issue: Model not downloading
```bash
# Check internet connection
curl https://huggingface.co

# Check disk space  
df -h ~/.cache/huggingface/

# Check HuggingFace token
cat ~/.huggingface/token

# If no token, login:
huggingface-cli login
```

## Model Options

All [HuggingFace models](https://huggingface.co/models?library=transformers) work!

### Recommended Models

**Fast & Small (3B - best for testing)**
```bash
bash scripts/run_agent_unified.sh --model microsoft/phi-2
```

**Balanced (8B - good default)**
```bash
bash scripts/run_agent_unified.sh --model meta-llama/Meta-Llama-3-8B-Instruct
```

**Powerful (13B - better quality)**
```bash
bash scripts/run_agent_unified.sh --model meta-llama/Llama-2-13b-chat-hf
```

**Very Powerful (70B - best quality, needs large GPU)**
```bash
bash scripts/run_agent_unified.sh --model meta-llama/Meta-Llama-3-70B-Instruct
```

**Fast Alternative (Mistral)**
```bash
bash scripts/run_agent_unified.sh --model mistralai/Mistral-7B-Instruct-v0.2
```

## Performance Tips

### Tip 1: Adjust GPU Memory Based on Your GPU

```bash
# 8GB GPU → Use 50-60% memory
bash scripts/run_agent_unified.sh --gpu-memory 0.5

# 16GB GPU → Use 75-80% memory
bash scripts/run_agent_unified.sh --gpu-memory 0.8

# 24GB+ GPU → Use 90-95% memory
bash scripts/run_agent_unified.sh --gpu-memory 0.95
```

### Tip 2: Pre-Download Model for Instant Startup

```bash
# One-time setup
python3 -c "from vllm import LLM; LLM('meta-llama/Meta-Llama-3-8B-Instruct'); print('✓ Model cached')"

# Now runs instantly
time bash scripts/run_agent_unified.sh
```

### Tip 3: Monitor GPU During Analysis

```bash
# In another terminal
watch -n 1 'nvidia-smi'
```

## Moving from Old to New

### If you were using the old approach:

```bash
# OLD: Two terminals
# Terminal 1
bash scripts/start_vllm.sh          # Start server

# Terminal 2
bash scripts/run_with_vllm.sh       # Run agent

# Check server is working
curl http://localhost:8000/v1/models
```

### Now: One command

```bash
# NEW: Just run this
bash scripts/run_agent_unified.sh
```

### Old scripts still work (backward compatible)

The old client-server approach still works if you prefer:
```bash
bash scripts/start_vllm.sh              # Start server
bash scripts/run_with_vllm.sh            # Run agent (separate terminal)
```

But we recommend the new unified approach! 🚀

## Next Steps

1. **Install/update vLLM:**
   ```bash
   pip install vllm==0.6.7
   ```

2. **Try the new script:**
   ```bash
   bash scripts/run_agent_unified.sh
   ```

3. **Monitor progress:**
   - First run: 2-3 minutes (model downloading + loading)
   - Subsequent runs: ~10 seconds setup + analysis time
   - Open `data/` folder to see results

4. **Customize as needed:**
   ```bash
   bash scripts/run_agent_unified.sh --help
   ```

## Advanced Configuration

### Custom Model with Web Search

```bash
bash scripts/run_agent_unified.sh \
    --model mistralai/Mistral-7B-Instruct-v0.2 \
    --web-events \
    --use-local-embeddings
```

### Production Analysis (100 events, high quality)

```bash
bash scripts/run_agent_unified.sh \
    --model meta-llama/Llama-2-13b-chat-hf \
    --gpu-memory 0.85 \
    --events 100 \
    --dataset TestSet_benchmark
```

### Research (Multiple models comparison)

```bash
# Test model 1
bash scripts/run_agent_unified.sh --model microsoft/phi-2

# Test model 2  
bash scripts/run_agent_unified.sh --model mistralai/Mistral-7B-Instruct-v0.2

# Test model 3
bash scripts/run_agent_unified.sh --model meta-llama/Meta-Llama-3-8B-Instruct

# Compare results in data/
```

## Questions?

- **vLLM docs:** https://docs.vllm.ai/
- **Models:** https://huggingface.co/models
- **Issues:** Check VLLM_DIRECT_INSTANTIATION.md

---

**Summary:** One script, direct execution, better performance! 🚀
