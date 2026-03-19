# Migration Guide: Refactoring to vLLM Support

This document explains the changes made to support local vLLM models and how they impact the codebase.

## Summary of Changes

### New Modules

#### 1. LLM Service Module (`src/multi_agent/llm_service/`)

**Purpose**: Abstract LLM initialization to support both API-based and local models.

**Files**:
- `factory.py`: Contains `init_llm()` factory function
- `vllm_wrapper.py`: LangChain-compatible wrapper for vLLM

**Key Functions**:
```python
def init_llm(model_config: str, timeout: int = 200) -> Any:
    """Initialize LLM based on config string."""
    # Format: "provider/model-name"
    # Examples: "openai/gpt-4o", "vllm/meta-llama/Meta-Llama-3-8B-Instruct"
```

#### 2. Embeddings Service Module (`src/multi_agent/embeddings_service/`)

**Purpose**: Provide consistent embeddings initialization for local or remote models.

**Key Functions**:
```python
def get_embeddings(use_local: Optional[bool] = None, model_name: Optional[str] = None):
    """Get embeddings instance (HuggingFace local or OpenAI remote)."""
```

### Configuration Changes (`src/configuration.py`)

Added fields:
```python
vllm_model: str                    # Model ID for vLLM
vllm_base_url: str                 # vLLM server URL
vllm_max_tokens: int               # Response token limit
use_local_embeddings: bool         # Toggle local embeddings
embedding_model: str               # Local embedding model name
```

### Module Updates

#### Files Changed:
1. `src/multi_agent/main_agent/nodes/main_agent.py`
   - Import: `from multi_agent.llm_service import init_llm`
   - Changed: `init_llm(configurable.model, timeout=200)` (was `init_chat_model(...)`)

2. `src/multi_agent/log_reporter/log_reporter.py`
   - Same changes as above

3. `src/multi_agent/pcap_flow_analyzer/pcap_flow_analyzer.py`
   - Same changes as above

4. `src/multi_agent/main_agent/nodes/tools.py`
   - Same changes as above

5. `src/run_agent.py`
   - New: `from multi_agent.embeddings_service import get_embeddings`
   - Updated: `init_store()` function uses `get_embeddings()`

6. `src/run_agent_web_events.py`
   - Same changes as run_agent.py

### Dependency Changes (`requirements.txt`)

Added:
```
vllm==0.6.7
sentence-transformers==3.1.1
transformers==4.45.0
```

## Migration Path

### For Developers

If you're adding new LLM calls, follow these patterns:

**Before (Old)**:
```python
from langchain.chat_models import init_chat_model
from multi_agent.common.utils import split_model_and_provider

# ...in code...
llm = init_chat_model(**split_model_and_provider(configurable.model), timeout=200)
```

**After (New)**:
```python
from multi_agent.llm_service import init_llm

# ...in code...
llm = init_llm(configurable.model, timeout=200)
```

### For Running Experiments

**Before (Old)**:
```bash
export MODEL="openai/gpt-4o"
export OPENAI_API_KEY="sk-..."
python src/run_agent.py
```

**After (New - vLLM)**:
```bash
export MODEL="vllm/meta-llama/Meta-Llama-3-8B-Instruct"
export USE_LOCAL_EMBEDDINGS="true"
python src/run_agent.py
```

**After (New - Still supports OpenAI)**:
```bash
export MODEL="openai/gpt-4o"
export OPENAI_API_KEY="sk-..."
export USE_LOCAL_EMBEDDINGS="false"
python src/run_agent.py
```

## Architecture Decisions

### Why Factory Pattern?

The factory pattern (`init_llm()`, `get_embeddings()`) provides:
1. **Single source of truth** for model initialization logic
2. **Easy to extend** to new providers
3. **Decouples** provider-specific logic from business logic
4. **Centralized configuration** management

### Why vLLM Wrapper?

LangChain doesn't directly support vLLM's OpenAI-compatible API. The wrapper:
1. Uses vLLM's `/v1/chat/completions` endpoint
2. Implements LangChain's `BaseChatModel` interface
3. Provides async support
4. Handles token counting

### Why Local Embeddings?

Local embeddings:
1. **No API calls** - faster and more private
2. **No rate limits** - unlimited usage
3. **No API costs** - run locally for free
4. **Consistent** - same results every time

## Backward Compatibility

The refactoring maintains backward compatibility:

✅ OpenAI API still works: `MODEL="openai/gpt-4o"`
✅ Old configuration keys still work (in `configuration.py`)
✅ Existing code patterns work (old methods still available)
✅ No breaking changes to public APIs

## Testing the Refactoring

### Unit Tests
```bash
# Test LLM initialization
python -c "from multi_agent.llm_service import init_llm; llm = init_llm('vllm/meta-llama/...')"

# Test Embeddings
python -c "from multi_agent.embeddings_service import get_embeddings; emb = get_embeddings(use_local=True)"
```

### Integration Tests
```bash
# Run with vLLM
export MODEL="vllm/meta-llama/Meta-Llama-3-8B-Instruct"
python src/run_agent.py --events 1

# Run with OpenAI
export MODEL="openai/gpt-4o"
python src/run_agent.py --events 1
```

## Performance Characteristics

### vLLM vs OpenAI API

| Metric | vLLM (Local) | OpenAI API |
|--------|------------|-----------|
| Latency | ~500ms-2s | ~2-5s (API + queue) |
| Throughput | High (limited by GPU) | Limited by rate limits |
| Cost | Free (hardware) | ~$0.01-0.05/call |
| Privacy | Private (local) | Data sent to OpenAI |
| Control | Full | Limited |

### Embedding Costs

| Model | Speed | Quality | Size |
|-------|-------|---------|------|
| all-MiniLM | Fastest | Good | 22MB |
| BGE-small | Fast | Very Good | 90MB |
| BGE-base | Slow | Excellent | 300MB |
| OpenAI | Moderate | Excellent | API |

## Future Extensions

The modular design enables:

1. **New LLM Providers**:
   ```python
   # Add support for Hugging Face Inference API, Replicate, etc.
   if provider == "huggingface":
       return HuggingFaceModel(...)
   ```

2. **New Embedding Providers**:
   ```python
   # Add support for Voyage, Cohere, etc.
   if provider == "voyage":
       return VoyageEmbeddings(...)
   ```

3. **Model Caching**:
   ```python
   # Cache models to avoid repeated instantiation
   @functools.lru_cache
   def init_llm(model_config, timeout):
       ...
   ```

4. **Monitoring/Logging**:
   ```python
   # Add token counting, latency tracking, etc.
   llm = init_llm(...)
   llm = with_token_counter(llm)
   ```

## Common Issues and Solutions

### Issue: Model not found
```python
# Ensure model is downloaded
from transformers import AutoModel
AutoModel.from_pretrained("meta-llama/Meta-Llama-3-8B-Instruct")
```

### Issue: Out of memory
```python
# Use smaller model or reduce precision
export VLLM_DTYPE=float16
export VLLM_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
```

### Issue: Slow inference
```python
# Check vLLM server is using GPU
curl http://localhost:8000/v1/models
# Should show loaded model, check GPU in nvidia-smi
```

## Related Documentation

- [VLLM_INTEGRATION.md](VLLM_INTEGRATION.md) - Full integration guide
- [QUICKSTART_VLLM.md](QUICKSTART_VLLM.md) - Quick start guide
- [Configuration](src/configuration.py) - Configuration details
