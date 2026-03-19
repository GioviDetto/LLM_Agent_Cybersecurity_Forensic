#!/bin/bash

# vLLM Server Startup Script
# This script launches a vLLM server with configurable model and GPU settings

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from environment or defaults
VLLM_MODEL="${VLLM_MODEL:-meta-llama/Meta-Llama-3-8B-Instruct}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_TENSOR_PARALLEL_SIZE="${VLLM_TENSOR_PARALLEL_SIZE:-1}"
VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.8}"
VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8096}"
VLLM_DTYPE="${VLLM_DTYPE:-float16}"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}vLLM Server Startup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Model:${NC} $VLLM_MODEL"
echo -e "${GREEN}Port:${NC} $VLLM_PORT"
echo -e "${GREEN}Tensor Parallel Size:${NC} $VLLM_TENSOR_PARALLEL_SIZE"
echo -e "${GREEN}GPU Memory Utilization:${NC} $VLLM_GPU_MEMORY_UTILIZATION"
echo -e "${GREEN}Max Model Length:${NC} $VLLM_MAX_MODEL_LEN"
echo -e "${GREEN}Data Type:${NC} $VLLM_DTYPE"
echo -e "${YELLOW}========================================${NC}"

# Check if vLLM is installed
if ! command -v vllm &> /dev/null; then
    echo -e "${RED}Error: vLLM is not installed${NC}"
    echo "Please install it with: pip install vllm"
    exit 1
fi

# Launch vLLM server
echo -e "${YELLOW}Starting vLLM server...${NC}"
vllm serve "$VLLM_MODEL" \
    --port "$VLLM_PORT" \
    --tensor-parallel-size "$VLLM_TENSOR_PARALLEL_SIZE" \
    --gpu-memory-utilization "$VLLM_GPU_MEMORY_UTILIZATION" \
    --max-model-len "$VLLM_MAX_MODEL_LEN" \
    --dtype "$VLLM_DTYPE" \
    --api-key "sk-default-key" \
    --served-model-name "default" \
    "$@"

echo -e "${RED}vLLM server stopped${NC}"
