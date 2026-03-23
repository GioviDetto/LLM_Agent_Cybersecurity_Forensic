sbatch run_sh.sbatch "Intel/GLM-5-int4-mixed-AutoRound" \
     --tensor-parallel-size 4 \
     --gpu-memory-utilization 0.85 \
     --tool-call-parser glm47 \
     --reasoning-parser glm45 \
     --enable-auto-tool-choice \
     --speculative-config.method mtp \
     --speculative-config.num_speculative_tokens 1 \
     --served-model-name glm-5