# vLLM Integration Guide

This guide explains how to refactor and run the LLM Agent with a locally-running vLLM model instead of the OpenAI API.

## Overview

The repository has been refactored to support both:
- **Remote LLM API** (OpenAI, etc.)
- **Local LLM via vLLM** (Meta-Llama, Mistral, etc.)

### Architecture Changes

1. **LLM Service Module** (`src/multi_agent/llm_service/`)
   - `factory.py`: Factory function `init_llm()` for model initialization
   - `vllm_wrapper.py`: LangChain-compatible wrapper for vLLM

2. **Embeddings Service Module** (`src/multi_agent/embeddings_service/`)
   - `__init__.py`: Factory function `get_embeddings()` for local/remote embeddings

3. **Configuration Updates** (`src/configuration.py`)
   - New vLLM-specific settings
   - Local embeddings configuration

4. **Updated Dependencies** (`requirements.txt`)
   - Added: `vllm`, `sentence-transformers`, `transformers`

## Setup Instructions

### Step 1: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 2: Start vLLM Server

Choose one of the following options:

#### Option A: Direct Installation (Recommended for GPU)

```bash
# Set environment variables
export VLLM_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
export VLLM_PORT=8000

# Run the startup script
bash scripts/start_vllm.sh
```

#### Option B: Docker (Recommended for Easy Setup)

```bash
# Ensure Docker and nvidia-docker are installed
bash scripts/start_vllm_docker.sh
```

#### Option C: Manual vLLM Launch

```bash
vllm serve meta-llama/Meta-Llama-3-8B-Instruct \
    --port 8000 \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.8 \
    --dtype float16
```

### Step 3: Configure Environment

Edit `.env` in the `src/` directory:

```bash
# Copy the example
cp src/.env.example src/.env

# Edit with your settings
nano src/.env
```

Key settings for vLLM:

```env
# Use vLLM model
MODEL = vllm/meta-llama/Meta-Llama-3-8B-Instruct

# vLLM server location
VLLM_BASE_URL = http://localhost:8000/v1

# Use local embeddings
USE_LOCAL_EMBEDDINGS = true
EMBEDDING_MODEL = all-MiniLM-L6-v2
```

### Step 4: Run Experiments

#### Using the Convenience Script

```bash
# Run with defaults
bash scripts/run_with_vllm.sh

# Run with specific model and settings
bash scripts/run_with_vllm.sh \
    --model meta-llama/Meta-Llama-3-70B-Instruct \
    --dataset CFA \
    --events 20 \
    --executions 3 \
    --embeddings
```

#### Manual Execution

```bash
cd src
export MODEL="vllm/meta-llama/Meta-Llama-3-8B-Instruct"
export VLLM_BASE_URL="http://localhost:8000/v1"
export USE_LOCAL_EMBEDDINGS="true"
export DATASET="CFA"

python run_agent.py
```

## Configuration Options

### Environment Variables

#### LLM Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL` | `openai/gpt-4o` | Model ID (e.g., `vllm/meta-llama/Meta-Llama-3-8B-Instruct`) |
| `CONTEXT_WINDOW_SIZE` | `128000` | Context window size in tokens |

#### vLLM-Specific

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_MODEL` | `meta-llama/Meta-Llama-3-8B-Instruct` | Model name for vLLM |
| `VLLM_BASE_URL` | `http://localhost:8000/v1` | vLLM server URL |
| `VLLM_MAX_TOKENS` | `1024` | Max tokens in response |
| `VLLM_TIMEOUT` | `200` | Request timeout in seconds |

#### Embeddings Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_LOCAL_EMBEDDINGS` | `false` | Use local embeddings instead of OpenAI |
| `EMBEDDING_MODEL` | `all-MiniLM-L6-v2` | Local embedding model name |

### Embedding Models

**Local Options:**
- `all-MiniLM-L6-v2` (384 dims, ~22MB) - Fast, good for English
- `BAAI/bge-small-en` (384 dims) - High quality
- `BAAI/bge-base-en` (768 dims) - Better quality, slower
- `BAAI/bge-large-en` (1024 dims) - Best quality, slowest

**Remote:**
- OpenAI `text-embedding-3-small` (1536 dims) - Default when `USE_LOCAL_EMBEDDINGS=false`

### vLLM Launch Options

When starting vLLM, you can customize:

```bash
# Adjust GPU memory utilization (0.0-1.0)
export VLLM_GPU_MEMORY_UTILIZATION=0.8

# Use specific GPU devices
export VLLM_GPU_DEVICES="0,1"  # Use GPUs 0 and 1

# Increase tensor parallelism for multi-GPU
export VLLM_TENSOR_PARALLEL_SIZE=2

# Set max model length for context
export VLLM_MAX_MODEL_LEN=8096

# Use float32 for CPU or reduced precision compatibility
export VLLM_DTYPE=float32
```

## Supported Models

### Tested Models

1. **Meta-Llama-3-8B-Instruct** (Recommended for balance)
   - Model size: ~16GB VRAM
   - Context: 8K tokens
   - Speed: ~100 tokens/sec on V100

2. **Meta-Llama-3-70B-Instruct** (High quality)
   - Model size: ~140GB VRAM (requires multi-GPU)
   - Context: 8K tokens
   - Quality: State-of-the-art

3. **Mistral-7B-Instruct-v0.2**
   - Model size: ~14GB VRAM
   - Context: 32K tokens
   - Speed: Fast, good for long documents

### Custom Models

To use a different model from HuggingFace:

```bash
export VLLM_MODEL="mistralai/Mistral-7B-Instruct-v0.2"
bash scripts/start_vllm.sh
```

## Troubleshooting

### Port Already in Use

```bash
# Kill existing process
lsof -i :8000
kill -9 <PID>

# Or use a different port
export VLLM_PORT=8001
```

### CUDA Out of Memory

```bash
# Reduce GPU memory utilization
export VLLM_GPU_MEMORY_UTILIZATION=0.6

# Or use smaller model
export VLLM_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
```

### vLLM Server Not Responding

```bash
# Check if server is running
curl http://localhost:8000/v1/models

# View server logs (Docker)
docker logs vllm-server

# Restart server with debug output
bash scripts/start_vllm.sh
```

### Model Download Issues

```bash
# Pre-download model manually
python -c "from transformers import AutoTokenizer, AutoModelForCausalLM; \
    AutoTokenizer.from_pretrained('meta-llama/Meta-Llama-3-8B-Instruct'); \
    AutoModelForCausalLM.from_pretrained('meta-llama/Meta-Llama-3-8B-Instruct')"

# Accept HuggingFace model card terms at: https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct
```

## Performance Considerations

### Memory Requirements

| Model | VRAM | System RAM | Storage |
|-------|------|-----------|---------|
| 8B GPT | 16GB | 8GB | 20GB |
| 70B GPT | 140GB | 32GB | 150GB |
| 8B on CPU | - | 64GB | 20GB |

### Optimization Tips

1. **Use Smaller Models** for faster iteration
   ```bash
   VLLM_MODEL="mistralai/Mistral-7B-Instruct-v0.2"
   ```

2. **Reduce Context Window** if not needed
   ```bash
   VLLM_MAX_MODEL_LEN=4096
   ```

3. **Use bfloat16 for Faster Compute**
   ```bash
   VLLM_DTYPE=bfloat16
   ```

4. **Enable Tensor Parallelism** for multi-GPU
   ```bash
   VLLM_TENSOR_PARALLEL_SIZE=2
   ```

## Module Structure

### `llm_service/` - LLM Initialization

```
llm_service/
├── __init__.py          # Exports
├── factory.py           # init_llm() factory
└── vllm_wrapper.py      # VLLMChatModel LangChain wrapper
```

**Usage:**
```python
from multi_agent.llm_service import init_llm

llm = init_llm("vllm/meta-llama/Meta-Llama-3-8B-Instruct", timeout=200)
```

### `embeddings_service/` - Embeddings Initialization

```
embeddings_service/
└── __init__.py          # get_embeddings() factory
```

**Usage:**
```python
from multi_agent.embeddings_service import get_embeddings

embeddings = get_embeddings(use_local=True, model_name="all-MiniLM-L6-v2")
```

## Integration Points

### Changed Files

1. **`src/configuration.py`**
   - Added vLLM and embeddings settings

2. **`src/multi_agent/main_agent/nodes/main_agent.py`**
   - Changed from `init_chat_model()` to `init_llm()`

3. **`src/multi_agent/log_reporter/log_reporter.py`**
   - Changed from `init_chat_model()` to `init_llm()`

4. **`src/multi_agent/pcap_flow_analyzer/pcap_flow_analyzer.py`**
   - Changed from `init_chat_model()` to `init_llm()`

5. **`src/multi_agent/main_agent/nodes/tools.py`**
   - Changed from `init_chat_model()` to `init_llm()`

6. **`src/run_agent.py` and `src/run_agent_web_events.py`**
   - Updated embeddings initialization to use `get_embeddings()`

## Switching Between Providers

### To Use OpenAI
```bash
export MODEL="openai/gpt-4o"
export USE_LOCAL_EMBEDDINGS="false"
python src/run_agent.py
```

### To Use vLLM with Local Embeddings
```bash
export MODEL="vllm/meta-llama/Meta-Llama-3-8B-Instruct"
export USE_LOCAL_EMBEDDINGS="true"
python src/run_agent.py
```

## Next Steps

1. Start vLLM server: `bash scripts/start_vllm.sh`
2. Configure `.env` file with your settings
3. Run experiments: `bash scripts/run_with_vllm.sh`
4. Monitor results in `../results/`

## Support

For issues:
1. Check `.env` configuration
2. Verify vLLM server is running: `curl http://localhost:8000/v1/models`
3. Check logs in `../results/run{N}/log_steps/`
4. Review vLLM documentation: https://docs.vllm.ai/
