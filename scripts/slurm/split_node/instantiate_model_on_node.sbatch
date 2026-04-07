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
# 2. ENVIRONMENT SETUP
# =====================================================================
mkdir -p sbatch_out
module purge

# Activate your environment BEFORE resolving system paths
source activate CyberS
module load gcc/12.4.0
module load nvhpc-hpcx-cuda12/25.11

# Quick sanity check so you can see it in your Slurm logs
echo "Looking for Apptainer..."
which apptainer || echo "WARNING: Apptainer still not found!"

# --- ROBUST HPC COMPILER CONFIGURATION ---
export CC=$(which gcc)
export CXX=$(which g++)
export TRITON_CC=$(which gcc)

# 1. Find the base NVHPC directory by stepping back from the proprietary nvcc path
NVHPC_COMPILER_DIR=$(dirname $(dirname $(which nvcc)))
NVHPC_BASE_DIR=$(dirname $NVHPC_COMPILER_DIR)

# 2. Locate the standard CUDA toolkit hidden inside the NVHPC SDK
export CUDA_HOME=$(ls -d $NVHPC_BASE_DIR/cuda/12.* | head -n 1)

# 3. Force the system to use the standard CUDA nvcc by putting it at the front of your PATH
export PATH=$CUDA_HOME/bin:$PATH

# 4. Set the linking paths so 'ld' can find libcudart.so
export LIBRARY_PATH=$CUDA_HOME/lib64:$LIBRARY_PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# 5. Clear the previous failed build caches
rm -rf ~/.cache/flashinfer
rm -rf ~/.cache/triton
# ----------------------------------------------------------

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
# 3. START DYNAMIC vLLM SERVER
# =====================================================================
PORT=8000
LOCAL_API_URL="http://localhost:${PORT}/v1"
echo "Assigned Node: $SLURM_JOB_NODELIST"
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

echo "Server is running. Keeping job alive until Slurm timeout..."

wait $VLLM_PID

