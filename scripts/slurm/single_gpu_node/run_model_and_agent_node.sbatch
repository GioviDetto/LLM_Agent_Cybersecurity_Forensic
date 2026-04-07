#!/usr/bin/env bash

#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --threads-per-core=1
#SBATCH --gres=gpu:4
#SBATCH --mem=500GB
#SBATCH --time=0-10:00:00
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
# 2. ENVIRONMENT & COMPILER SETUP
# =====================================================================
mkdir -p sbatch_out
module purge

# Activate your environment BEFORE resolving system paths
source activate CyberS
module load gcc/12.4.0
module load nvhpc-hpcx-cuda12/25.11

echo "Looking for Apptainer..."
which apptainer || echo "WARNING: Apptainer still not found!"

# --- ROBUST HPC COMPILER CONFIGURATION ---
export CC=$(which gcc)
export CXX=$(which g++)
export TRITON_CC=$(which gcc)

NVHPC_COMPILER_DIR=$(dirname $(dirname $(which nvcc)))
NVHPC_BASE_DIR=$(dirname $NVHPC_COMPILER_DIR)
export CUDA_HOME=$(ls -d $NVHPC_BASE_DIR/cuda/12.* | head -n 1)

export PATH=$CUDA_HOME/bin:$PATH
export LIBRARY_PATH=$CUDA_HOME/lib64:$LIBRARY_PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

rm -rf ~/.cache/flashinfer
rm -rf ~/.cache/triton

# =====================================================================
# 3. WORKSPACE SETUP
# =====================================================================
export HF_TOKEN=$HUGGINGFACE_TOKEN
WORKING_DIR=$HOME/LLM_Agent_Cybersecurity_Forensic

# 1. Define the High-Performance Storage Paths
BEEGFS_DIR="/mnt/beegfs/coll_h200_sd"
MODEL_DIR="$BEEGFS_DIR/shared_models"

# 2. Force HuggingFace (both vLLM and Python Embeddings) to use BeeGFS
export HF_HOME="$BEEGFS_DIR/huggingface_cache"
export TRANSFORMERS_CACHE="$BEEGFS_DIR/huggingface_cache"

# 3. Setup Simulation Directory (keep this on standard scratch or BeeGFS, your choice)
SIMULATION_DIR=$SCRATCH/llm_judge_experiments/login_run_$SLURM_JOB_ID

mkdir -p $MODEL_DIR
mkdir -p $HF_HOME
mkdir -p $SIMULATION_DIR

echo "Copying files to simulation directory: $SIMULATION_DIR"
cp -r $WORKING_DIR/* $SIMULATION_DIR/
cd $SIMULATION_DIR

export PYTHONPATH=$PWD:$PYTHONPATH
export TSHARK_CONTAINER_PATH="$SIMULATION_DIR/tshark.sif"

# =====================================================================
# 4. START LOCAL vLLM SERVER
# =====================================================================
PORT=8000
LOCAL_API_URL="http://localhost:${PORT}/v1"
echo "Assigned Node: $SLURM_JOB_NODELIST"
echo "Starting vLLM locally on port $PORT..."

# Start vLLM in the background
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
# 5. RUN PYTHON AGENT
# =====================================================================
USE_LOCAL_EMBEDDINGS="true"
EMBEDDING_MODEL="all-MiniLM-L6-v2"
DATASET="CFA"
NUMBER_OF_EVENTS="1"
NUMBER_OF_EXECUTIONS="1"

echo "Starting Python agent script..."
# Using the local python binary from the conda environment, pointing to the local API
$HOME/miniconda3/envs/CyberS/bin/python3 src/run_agent.py \
    --api-url "$LOCAL_API_URL" \
    --model "vllm/$MODEL_ID" \
    --events "$NUMBER_OF_EVENTS" \
    --use-local-embeddings "$USE_LOCAL_EMBEDDINGS" \
    --embedding-model "$EMBEDDING_MODEL" \
    --dataset "$DATASET" \
    --executions "$NUMBER_OF_EXECUTIONS" \
    --max-steps 10

echo "Python script finished execution."

# =====================================================================
# 6. CLEANUP & SYNC
# =====================================================================
echo "Shutting down vLLM server..."
kill $VLLM_PID

echo "Syncing results back to home directory..."
mkdir -p $WORKING_DIR/results/

# Sync results safely (only deleting scratch if the rsync succeeds)
if [ -d "$SIMULATION_DIR/results/" ]; then
    rsync -av $SIMULATION_DIR/results/ $WORKING_DIR/results/ && rm -rf $SIMULATION_DIR
    echo "Sync successful and scratch directory cleaned."
else
    echo "No results directory found in scratch. Cleaning up..."
    rm -rf $SIMULATION_DIR
fi

echo "Job Complete!"