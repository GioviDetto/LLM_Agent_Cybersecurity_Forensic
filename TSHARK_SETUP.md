# Apptainer TShark Setup Guide

This project **requires Apptainer and a containerized tshark** for PCAP analysis.

## Quick Start on HPC Clusters

### 1. Load Apptainer Module

Most HPC clusters provide Apptainer via module system:

```bash
module load apptainer
apptainer --version  # Verify it's loaded
```

If that doesn't work, check available modules:
```bash
module avail apptainer
module avail singularity  # Sometimes named singularity
```

### 2. Create/Get tshark.sif Container

Build the container once:

```bash
bash scripts/setup_apptainer_tshark.sh
```

This creates `tshark.sif` at repo root (~1GB).

Or download it manually:
```bash
cd /path/to/repo
apptainer pull tshark.sif docker://wireshark/wireshark:latest
```

### 3. Set Environment Variable

Add to your `.env` or shell profile:

```bash
export TSHARK_CONTAINER_PATH=/path/to/repo/tshark.sif
```

Or keep `tshark.sif` at repo root (default location).

### 4. Run Your Analysis

```bash
python src/run_agent.py --events 5
```

## Verify Setup

Check if system detects Apptainer:

```python
from multi_agent.common.tshark_apptainer import _is_apptainer_available, get_tshark_container_path

print(f"Apptainer available: {_is_apptainer_available()}")
print(f"Container path: {get_tshark_container_path()}")
```

## Troubleshooting

### "Apptainer is not available in PATH"

**On HPC cluster:**
```bash
# Check if module exists
module avail | grep -i apptainer

# Load it
module load apptainer

# Verify
which apptainer
```

**If module not available:**
Contact your HPC admin to install Apptainer, or:
1. Check if it's named `singularity` instead
2. Ask admin to add to module system
3. Compile from source (https://apptainer.org/docs/admin/main/)

### "Tshark container not found at tshark.sif"

Build it:
```bash
bash scripts/setup_apptainer_tshark.sh
```

Or set correct path:
```bash
export TSHARK_CONTAINER_PATH=/your/custom/path/tshark.sif
```

### Container build fails

Try this instead:
```bash
cd /tmp
apptainer pull tshark.sif docker://wireshark/wireshark:latest
export TSHARK_CONTAINER_PATH=/tmp/tshark.sif
```

### "permission denied" when running

Ensure container is readable:
```bash
ls -la tshark.sif
chmod 755 tshark.sif  # If needed
```

## Advanced: Custom Container

Build from custom Dockerfile:

```bash
cat > Dockerfile.tshark << 'EOF'
Bootstrap: docker
From: ubuntu:22.04

%post
    apt-get update
    apt-get install -y tshark wireshark-common
    
%runscript
    exec tshark "$@"
EOF

apptainer build tshark.sif Dockerfile.tshark
export TSHARK_CONTAINER_PATH=$(pwd)/tshark.sif
```

## Performance Notes

- **First run**: Container startup ~2-5 seconds
- **Subsequent runs**: Fast execution with caching
- **Network overhead**: Minimal, containerized locally

---

## In sbatch Script

Add to your SLURM batch file:

```bash
#!/bin/bash
#SBATCH --job-name=agent_analysis
#SBATCH --partition=gpu
#SBATCH --gpus=1

# Load Apptainer
module load apptainer

# Set container path
export TSHARK_CONTAINER_PATH=/path/to/repo/tshark.sif

# Run analysis
python src/run_agent.py \
    --events 5 \
    --model meta-llama/Meta-Llama-3-70B-Instruct
```

---

## Status Check

```bash
# Check everything is ready
bash -c '
module load apptainer 2>/dev/null || true
export TSHARK_CONTAINER_PATH=$(pwd)/tshark.sif

echo "=== Apptainer Status ==="
which apptainer && apptainer --version || echo "NOT FOUND"

echo "=== Container Status ==="
[ -f "$TSHARK_CONTAINER_PATH" ] && echo "✓ Found at $TSHARK_CONTAINER_PATH" || echo "✗ NOT FOUND"

echo "=== Can run tshark ==="
apptainer exec "$TSHARK_CONTAINER_PATH" tshark --version 2>/dev/null && echo "✓ Ready" || echo "✗ Failed"
'
```

