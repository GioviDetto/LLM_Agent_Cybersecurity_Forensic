#!/usr/bin/env bash

# 1. Dynamically find the root of the repository
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(dirname $(dirname $SCRIPT_DIR))

# 2. Point to the new location of the sbatch script
SBATCH_SCRIPT="$REPO_ROOT/scripts/slurm/split_node/instantiate_model_on_node.sbatch"

echo "Submitting GLM-5-INT4 (AutoRound) to Slurm..."

# 3. Execute with the correct path and all specified parameters
sbatch $SBATCH_SCRIPT "Intel/GLM-5-int4-mixed-AutoRound" \
    --tensor-parallel-size 8 \
    --gpu-memory-utilization 0.8 \
    --tool-call-parser glm47 \
    --reasoning-parser glm45 \
    --served-model-name glm-5 \
    --trust-remote-code \
    --max-model-len 8192 \
    --enable-auto-tool-choice