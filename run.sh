#!/bin/bash
set -e

# ==== CONFIGURATION ====
MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
VLLM_GPU_MEMORY="0.9"
USE_LOCAL_EMBEDDINGS="true"
EMBEDDING_MODEL="all-MiniLM-L6-v2"
DATASET="CFA"
NUMBER_OF_EVENTS="20"
NUMBER_OF_EXECUTIONS="1"

python3 src/run_agent.py \
    --model "$MODEL" \
    --gpu-memory "$VLLM_GPU_MEMORY" \
    --events "$NUMBER_OF_EVENTS" \
    --use-local-embeddings  "$USE_LOCAL_EMBEDDINGS" \
    --embedding-model "$EMBEDDING_MODEL" \
    --dataset "$DATASET" \
    --executions "$NUMBER_OF_EXECUTIONS"
