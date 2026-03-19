# Quick Start: Running with vLLM

## 5-Minute Setup

### 1. Install packages
```bash
pip install -r requirements.txt
```

### 2. Start vLLM (in a separate terminal)
```bash
export VLLM_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
bash scripts/start_vllm.sh
```

**Waiting for first model download?** This may take 5-15 minutes on first run.

### 3. Configure environment
```bash
cd src
cp .env.example .env
# Edit .env as needed - defaults work for vLLM + local embeddings
```

### 4. Run experiment
```bash
export MODEL="vllm/meta-llama/Meta-Llama-3-8B-Instruct"
export USE_LOCAL_EMBEDDINGS="true"
python run_agent.py
```

## Using Docker (Easiest)

```bash
# Start vLLM in Docker
bash scripts/start_vllm_docker.sh

# In another terminal, run experiment
cd src
python run_agent.py
```

## Using Different Models

### Mistral 7B (Faster)
```bash
VLLM_MODEL="mistralai/Mistral-7B-Instruct-v0.2" bash scripts/start_vllm.sh
```

### Llama 70B (Better Quality, needs multi-GPU)
```bash
VLLM_MODEL="meta-llama/Meta-Llama-3-70B-Instruct" \
VLLM_TENSOR_PARALLEL_SIZE=2 \
bash scripts/start_vllm.sh
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port 8000 in use | `export VLLM_PORT=8001` |
| Out of GPU memory | Use smaller model or `VLLM_GPU_MEMORY_UTILIZATION=0.6` |
| Model download fails | Accept terms at https://huggingface.co/meta-llama/... |
| Server not responding | Check `curl http://localhost:8000/v1/models` |

## Performance Notes

- **First model download**: 5-15 min (depends on internet)
- **Model loading**: 30-60 sec per startup
- **Inference speed**: ~50-100 tokens/sec on V100 (8B model)
- **Memory**: ~16GB for 8B model, ~140GB for 70B

## Next Steps

See [VLLM_INTEGRATION.md](VLLM_INTEGRATION.md) for full documentation.
