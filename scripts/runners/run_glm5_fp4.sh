#!/usr/bin/env bash

# 1. Dynamically find the root of the repository
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(dirname $(dirname $SCRIPT_DIR))

# 2. Point to the new location of the sbatch script
SBATCH_SCRIPT="$REPO_ROOT/scripts/slurm/split_node/instantiate_model_on_node.sbatch"

echo "Submitting GLM-5-FP8 to Slurm..."

# 3. Execute with the correct path
sbatch $SBATCH_SCRIPT "zai-org/GLM-5-FP8" \
    --tensor-parallel-size 8 \
    --tool-call-parser glm47 \
    --reasoning-parser glm45 \
    --gpu-memory-utilization 0.85 \
    --served-model-name glm-5-fp8