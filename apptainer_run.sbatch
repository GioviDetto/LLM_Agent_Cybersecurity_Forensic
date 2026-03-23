#!/usr/bin/env bash

#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --threads-per-core=1
#SBATCH --gres=gpu:4
#SBATCH --mem=128GB
#SBATCH --time=0-12:00:00
#SBATCH --partition=gpu_h200
#SBATCH --output=sbatch_out/result_%j.out
#SBATCH --export=ALL

# =====================================================================
# 1. PARSE DYNAMIC ARGUMENTS
# =====================================================================
# The first argument passed to sbatch is the Model ID/Path
MODEL_ID=$1
shift # This removes the first argument so we can capture the rest

# All remaining arguments are stored here to be passed to vLLM
VLLM_EXTRA_ARGS="$@"

if [ -z "$MODEL_ID" ]; then
    echo "ERROR: You must provide a model ID or local path!"
    echo "Usage: sbatch run_sh.sbatch <model_id> [vllm_args...]"
    exit 1
fi

echo "Deploying Model: $MODEL_ID"
echo "With vLLM Parameters: $VLLM_EXTRA_ARGS"

# =====================================================================
# 2. ENVIRONMENT SETUP
# =====================================================================
mkdir -p sbatch_out
module purge
source activate CyberS
module load gcc/12.4.0
module load nvhpc-hpcx-cuda12/25.11

export CUDA_HOME=$(dirname $(dirname $(which nvcc)))
export LIBRARY_PATH=$CUDA_HOME/lib64:$LIBRARY_PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

export HF_TOKEN=$HUGGINGFACE_TOKEN
WORKING_DIR=$HOME/LLM_Agent_Cybersecurity_Forensic
SIMULATION_DIR=$SCRATCH/llm_judge_experiments/$SLURM_JOB_ID
MODEL_DIR=$SCRATCH/shared_models

mkdir -p $MODEL_DIR
mkdir -p $SIMULATION_DIR
cp -r $WORKING_DIR/* $SIMULATION_DIR/
cd $SIMULATION_DIR
export PYTHONPATH=$PWD:$PYTHONPATH

# =====================================================================
# 3. START DYNAMIC vLLM SERVER
# =====================================================================
PORT=8000
LOCAL_API_URL="http://localhost:${PORT}/v1"

echo "Starting vLLM..."

# We inject the dynamic model ID and the extra arguments here
vllm serve ${MODEL_ID} \
  --download-dir ${MODEL_DIR} \
  --port ${PORT} \
  ${VLLM_EXTRA_ARGS} &

VLLM_PID=$!

echo "Waiting for vLLM to initialize..."
while ! curl -s "${LOCAL_API_URL}/models" > /dev/null; do
    sleep 15
done
echo "vLLM is ready!"

# =====================================================================
# 4. RUN AGENT & CLEANUP
# =====================================================================
# You can also pass the MODEL_ID to your Python script if it needs to know what model is running

VLLM_GPU_MEMORY="0.9"
USE_LOCAL_EMBEDDINGS="true"
EMBEDDING_MODEL="all-MiniLM-L6-v2"
DATASET="CFA"
NUMBER_OF_EVENTS="3"
NUMBER_OF_EXECUTIONS="1"

python3 src/run_agent.py \
    --api-url "$LOCAL_API_URL" \
    --model "$MODEL_ID" \
    --gpu-memory "$VLLM_GPU_MEMORY" \
    --events "$NUMBER_OF_EVENTS" \
    --use-local-embeddings  "$USE_LOCAL_EMBEDDINGS" \
    --embedding-model "$EMBEDDING_MODEL" \
    --dataset "$DATASET" \
    --executions "$NUMBER_OF_EXECUTIONS"

echo "Shutting down vLLM server..."
kill $VLLM_PID
wait $VLLM_PID 2>/dev/null

mkdir -p $WORKING_DIR/data/results/
if [ -d "$SIMULATION_DIR/data/results/" ]; then
    rsync -av $SIMULATION_DIR/data/results/ $WORKING_DIR/data/results/
fi
rm -rf $SIMULATION_DIR
echo "Job Complete!"

# ==== CONFIGURATION ====



