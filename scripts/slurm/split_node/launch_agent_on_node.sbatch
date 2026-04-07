#!/bin/bash
#SBATCH --job-name=cyber_cpu        # Job name
#SBATCH --output=result.out         # Standard output log
#SBATCH --error=result.err          # Standard error log
#SBATCH --nodes=1                   # Number of nodes
#SBATCH --ntasks=1                  # Number of tasks
#SBATCH --cpus-per-task=8           # Number of CPU cores (adjust as needed)
#SBATCH --mem=16G                   # Memory (RAM)
#SBATCH --time=06:00:00             # Time limit (HH:MM:SS)
#SBATCH --partition=cpu_sapphire             # Specify a CPU-only partition (if required)

# Load necessary modules (e.g., Python, GCC)
# module load python/3.10

# Execute your script
chmod +x run_agent_login.sh
./run_agent_login.sh
