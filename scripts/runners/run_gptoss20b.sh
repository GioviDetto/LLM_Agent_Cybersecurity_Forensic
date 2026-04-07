sbatch instantiate_model_on_node.sbatch "openai/gpt-oss-20b" \
	--tensor-parallel-size=1 \
	--gpu-memory-utilization 0.95 \
	--block-size=64
