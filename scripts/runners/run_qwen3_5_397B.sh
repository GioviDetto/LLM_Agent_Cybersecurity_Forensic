#!/usr/bin/env bash

# 1. Dynamically find the root of the repository
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(dirname $(dirname $SCRIPT_DIR))

# 2. Point to the new location of the sbatch script
SBATCH_SCRIPT="$REPO_ROOT/scripts/slurm/split_node/instantiate_model_on_node.sbatch"

echo "Submitting Qwen3.5-397B-A17B-FP8 to Slurm..."

# 3. Execute with the correct path and all specified parameters
sbatch $SBATCH_SCRIPT "Qwen/Qwen3.5-397B-A17B-FP8" \
    --tensor-parallel-size 4 \
    --gpu-memory-utilization 0.9 \
    --max-model-len 32768 \
    --trust-remote-code \
    --served-model-name qwen3.5-397b-fp8 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_xml