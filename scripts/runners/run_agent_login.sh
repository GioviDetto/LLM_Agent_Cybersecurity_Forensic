#!/usr/bin/env bash

# =====================================================================
# 1. ENVIRONMENT SETUP
# =====================================================================
echo "Setting up environment..."
module purge
source activate CyberS

export HF_TOKEN=$HUGGINGFACE_TOKEN
WORKING_DIR=$HOME/LLM_Agent_Cybersecurity_Forensic

# Generate a unique ID using the current timestamp
SIMULATION_ID=$(date +%s)
SIMULATION_DIR=$SCRATCH/llm_judge_experiments/login_run_$SIMULATION_ID

mkdir -p $SIMULATION_DIR
echo "Copying files to simulation directory: $SIMULATION_DIR"
cp -r $WORKING_DIR/* $SIMULATION_DIR/
cd $SIMULATION_DIR

export PYTHONPATH=$PWD:$PYTHONPATH

# Only keep this if your Python script actually calls the Tshark container locally
export TSHARK_CONTAINER_PATH="$SIMULATION_DIR/tshark.sif" 

# =====================================================================
# 2. RUN PYTHON SCRIPT
# =====================================================================
REMOTE_API_URL="http://compute-7-12:8000/v1"

VLLM_GPU_MEMORY="0.9"
USE_LOCAL_EMBEDDINGS="true"
EMBEDDING_MODEL="all-MiniLM-L6-v2"
DATASET="CFA"
NUMBER_OF_EVENTS="1"
NUMBER_OF_EXECUTIONS="1"

echo "Starting Python script..."
$HOME/miniconda3/envs/CyberS/bin/python3 src/run_agent.py \
    --api-url "$REMOTE_API_URL" \
    --model "vllm/qwen3.5-397b-fp8" \
    --gpu-memory "$VLLM_GPU_MEMORY" \
    --events "$NUMBER_OF_EVENTS" \
    --use-local-embeddings "$USE_LOCAL_EMBEDDINGS" \
    --embedding-model "$EMBEDDING_MODEL" \
    --dataset "$DATASET" \
    --executions "$NUMBER_OF_EXECUTIONS" \
    --max-steps 10

# =====================================================================
# 3. CLEANUP
# =====================================================================
echo "Syncing results and cleaning up..."
mkdir -p $WORKING_DIR/results/
if [ -d "$SIMULATION_DIR/results/" ]; then
    rsync -av $SIMULATION_DIR/results/ $WORKING_DIR/results/
fi

rm -rf $SIMULATION_DIR
echo "Job Complete!"
