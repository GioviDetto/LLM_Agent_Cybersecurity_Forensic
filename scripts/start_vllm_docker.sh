#!/bin/bash

# Docker-based vLLM server launcher
# Uses Docker to run vLLM without GPU driver installation requirements
# Set DOCKER_IMAGE to use a custom vLLM Docker image

set -e

# Configuration
DOCKER_IMAGE="${DOCKER_IMAGE:-vllm/vllm-openai:v0.6.7}"
VLLM_MODEL="${VLLM_MODEL:-meta-llama/Meta-Llama-3-8B-Instruct}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_GPU_DEVICES="${VLLM_GPU_DEVICES:-all}"
VLLM_CONTAINER_NAME="vllm-server"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}vLLM Docker Server Launcher${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Docker Image:${NC} $DOCKER_IMAGE"
echo -e "${GREEN}Model:${NC} $VLLM_MODEL"
echo -e "${GREEN}Port:${NC} $VLLM_PORT"
echo -e "${GREEN}GPU Devices:${NC} $VLLM_GPU_DEVICES"
echo -e "${YELLOW}========================================${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker from https://docs.docker.com/get-docker/"
    exit 1
fi

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${VLLM_CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Stopping existing vLLM container...${NC}"
    docker stop "$VLLM_CONTAINER_NAME" || true
    docker rm "$VLLM_CONTAINER_NAME" || true
fi

# Launch vLLM container
echo -e "${YELLOW}Launching vLLM server in Docker...${NC}"
docker run -d \
    --name "$VLLM_CONTAINER_NAME" \
    --gpus "$VLLM_GPU_DEVICES" \
    -p "$VLLM_PORT:8000" \
    -e VLLM_ALLOW_RUNTIME_LORA_UPDATING=0 \
    "$DOCKER_IMAGE" \
    --model "$VLLM_MODEL" \
    --served-model-name "default" \
    --api-key "sk-default-key"

# Wait for server to be ready
echo -e "${YELLOW}Waiting for server to be ready...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s "http://localhost:$VLLM_PORT/v1/models" > /dev/null 2>&1; then
        echo -e "${GREEN}vLLM server is ready!${NC}"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}Timeout waiting for vLLM server to start${NC}"
    docker logs "$VLLM_CONTAINER_NAME" || true
    exit 1
fi

echo -e "${GREEN}vLLM server started successfully${NC}"
echo -e "${YELLOW}Base URL: http://localhost:$VLLM_PORT/v1${NC}"
echo
echo -e "${YELLOW}To view logs: docker logs -f ${VLLM_CONTAINER_NAME}${NC}"
echo -e "${YELLOW}To stop server: docker stop ${VLLM_CONTAINER_NAME}${NC}"
