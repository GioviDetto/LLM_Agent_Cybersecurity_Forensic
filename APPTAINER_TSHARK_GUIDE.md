# Apptainer tshark Integration Guide

## Overview

Your agent now runs **tshark via Apptainer containers** instead of requiring direct installation. This provides:

✅ **Isolation** - tshark runs in a container, not on host  
✅ **Portability** - Same environment everywhere  
✅ **Reproducibility** - Container version control  
✅ **Security** - Containerized network analysis tools  

## Setup

### Step 1: Create/Obtain tshark Container Image

#### Option A: Build from Dockerfile

```bash
# Create a simple Dockerfile
cat > Dockerfile << 'EOF'
Bootstrap: docker
From: wireshark/wireshark:latest

%post
    apt-get update
    apt-get install -y tshark
    
%labels
    Version 1.0
    Author YourName

%help
    This container provides tshark for network analysis
EOF

# Build the Apptainer image
apptainer build tshark.sif Dockerfile
```

#### Option B: Convert existing Docker image

```bash
# If you have a Docker image with tshark
apptainer build tshark.sif docker://wireshark/wireshark:latest
```

#### Option C: Use pre-built container

```bash
# Download a pre-built tshark container or use one from registry
apptainer pull tshark.sif docker://wireshark/wireshark:latest
```

### Step 2: Place Container in Repository

```bash
# Copy to repository root or set path
cp tshark.sif /home/dauin_user/gdettori/LLM_Agent_Cybersecurity_Forensic/

# Or place elsewhere and set environment variable
export TSHARK_CONTAINER_PATH="/path/to/tshark.sif"
```

### Step 3: Update Environment

Edit `src/.env`:

```env
# Path to tshark Apptainer container
TSHARK_CONTAINER_PATH = ./tshark.sif
# OR (absolute path)
TSHARK_CONTAINER_PATH = /home/dauin_user/gdettori/LLM_Agent_Cybersecurity_Forensic/tshark.sif
```

Or set at runtime:

```bash
export TSHARK_CONTAINER_PATH="./tshark.sif"
python run_agent.py
```

## Architecture

### Before (Direct tshark)

```
agent → subprocess → tshark (host installation required)
```

### After (Apptainer tshark)

```
agent → ApptainerTsharkWrapper 
      → subprocess 
      → apptainer exec tshark.sif tshark
      → tshark (containerized, isolated)
```

## Usage

### From Agent Code

Everything works transparently. The agent automatically uses Apptainer tshark:

```python
# In your agent code - no changes needed!
from multi_agent.common.utils import count_flows, get_flow

# These now run via Apptainer automatically
num_flows = count_flows("file.pcap")
flow_data = get_flow("file.pcap", stream_id=0)
```

### Direct Module Usage

```python
from multi_agent.common.tshark_apptainer import (
    count_flows_apptainer,
    get_flow_apptainer,
    conv_tcp_apptainer,
    ApptainerTsharkError
)

# Count flows
try:
    num = count_flows_apptainer("file.pcap")
    print(f"Found {num} flows")
except ApptainerTsharkError as e:
    print(f"Error: {e}")

# Get conversation summary
try:
    summary = conv_tcp_apptainer("file.pcap")
    print(summary)
except ApptainerTsharkError as e:
    print(f"Error: {e}")
```

### Manual tshark Commands

For custom tshark commands:

```python
from multi_agent.common.tshark_apptainer import run_tshark_apptainer

output = run_tshark_apptainer(
    "file.pcap",
    ["-r", "file.pcap", "-T", "json", "-e", "ip.src"]
)
print(output)
```

## Supported Functions

All standard tshark functions are available via Apptainer:

| Function | Equivalent Command |
|----------|-------------------|
| `count_flows_apptainer(pcap)` | `tshark -r <pcap> -T fields -e tcp.stream` |
| `get_flow_apptainer(pcap, stream)` | `tshark -r <pcap> -q -z follow,tcp,ascii,<stream>` |
| `get_flow_http_apptainer(pcap, stream)` | `tshark -r <pcap> -q -z follow,http,ascii,<stream>` |
| `get_flow_http2_apptainer(pcap, stream, subflow)` | `tshark -r <pcap> -q -z follow,http2,ascii,<stream>,<subflow>` |
| `conv_tcp_apptainer(pcap)` | `tshark -r <pcap> -q -z conv,tcp` |
| `run_tshark_apptainer(pcap, args)` | Custom tshark commands |

## Error Handling

The wrapper provides detailed error messages:

```python
from multi_agent.common.tshark_apptainer import ApptainerTsharkError

try:
    result = count_flows_apptainer("nonexistent.pcap")
except ApptainerTsharkError as e:
    print(f"Error details: {e}")
    # Handle error appropriately
```

Common errors:

| Error | Solution |
|-------|----------|
| "Container not found" | Set `TSHARK_CONTAINER_PATH` correctly |
| "Apptainer not found" | Install Apptainer: `sudo apt-get install apptainer` |
| "Permission denied" | Ensure tshark.sif has correct permissions |
| Tshark command returns no output | PCAP file might be invalid or empty |

## Performance Considerations

### Overhead

Apptainer adds ~100-500ms per call for container startup. This is acceptable for:
- One-time PCAP analysis
- Batch processing with caching
- Not for real-time packet capture

### Optimization Tips

1. **Cache results**: Store tshark outputs to avoid re-running
2. **Batch operations**: Process multiple streams in one container invocation
3. **Container preloading**: Keep container image in memory if possible

### Example with Caching

```python
from functools import lru_cache
from multi_agent.common.tshark_apptainer import count_flows_apptainer

@lru_cache(maxsize=100)
def cached_count_flows(pcap_file):
    """Cache flow counts to avoid repeated Apptainer calls."""
    return count_flows_apptainer(pcap_file)

# First call: runs tshark via Apptainer
count1 = cached_count_flows("file.pcap")

# Second call: returns cached result (no Apptainer overhead)
count2 = cached_count_flows("file.pcap")
```

## Configuration Reference

### Environment Variables

```bash
# Required: Path to tshark container
TSHARK_CONTAINER_PATH="./tshark.sif"
# or absolute path
TSHARK_CONTAINER_PATH="/opt/containers/tshark.sif"

# Optional: Apptainer options
APPTAINER_OPTS="--nv"  # Enable GPU (if available)
APPTAINER_OPTS="--containall"  # More isolation
```

### Python Configuration

In code:

```python
import os
os.environ["TSHARK_CONTAINER_PATH"] = "/path/to/tshark.sif"

# Or import and configure
from multi_agent.common import tshark_apptainer
container = tshark_apptainer.get_tshark_container_path()
print(f"Using container: {container}")
```

## Troubleshooting

### Issue: "Container not found at: tshark.sif"

**Solution**: 
```bash
# Check if container exists
ls -la tshark.sif

# Or set explicit path
export TSHARK_CONTAINER_PATH="/absolute/path/to/tshark.sif"

# Or place in current directory
cp /path/to/tshark.sif .
```

### Issue: "Apptainer not found"

**Solution**:
```bash
# Install Apptainer
sudo apt-get update
sudo apt-get install -y apptainer

# Verify installation
apptainer --version
```

### Issue: Container runs but tshark returns error

**Solution**:
```bash
# Test container manually
apptainer exec tshark.sif tshark --version

# Test with actual PCAP
apptainer exec tshark.sif tshark -r /path/to/file.pcap -q -z conv,tcp

# Check PCAP file validity
file test.pcap
```

### Issue: Permission denied running container

**Solution**:
```bash
# Check container permissions
ls -la tshark.sif
chmod 755 tshark.sif

# Or rebuild container
apptainer build --force tshark.sif Dockerfile
```

## Container Maintenance

### Update Container

```bash
# Rebuild from updated Dockerfile
apptainer build --force tshark.sif Dockerfile

# Or download newer version
apptainer pull --force tshark.sif docker://wireshark/wireshark:latest
```

### Inspect Container

```bash
# Check container metadata
apptainer inspect tshark.sif

# Test tshark version inside container
apptainer exec tshark.sif tshark --version

# List available tshark plugins
apptainer exec tshark.sif tshark -G plugins
```

## Integration with Agent

### Automatic Usage

The agent automatically uses Apptainer tshark for all PCAP analysis:

1. **PCAP Flow Analysis** - `pcap_flow_analyzer` uses Apptainer tshark
2. **Flow Extraction** - `get_flow()` uses Apptainer tshark
3. **Conversation Summary** - `conv_tcp` uses Apptainer tshark
4. **Web Browsing** - HTTP/2 flow extraction uses Apptainer tshark

### Example Workflow

```bash
# 1. Build/obtain container
apptainer build tshark.sif Dockerfile

# 2. Set environment
export TSHARK_CONTAINER_PATH="./tshark.sif"

# 3. Run agent normally (uses Apptainer automatically)
cd src
python run_agent.py
```

## Advanced Usage

### Custom tshark Arguments

```python
from multi_agent.common.tshark_apptainer import run_tshark_apptainer

# Extract IP addresses to JSON
output = run_tshark_apptainer(
    "file.pcap",
    [
        "-r", "file.pcap",
        "-T", "json",
        "-e", "ip.src",
        "-e", "ip.dst",
        "-e", "tcp.dstport"
    ]
)

import json
data = json.loads(output)
print(data)
```

### Multi-Container Setup

Run different analysis in different containers:

```python
# Main tshark container
os.environ["TSHARK_CONTAINER_PATH"] = "./tshark.sif"
output1 = conv_tcp_apptainer("file.pcap")

# Alternative specialized container if needed
# Just switch TSHARK_CONTAINER_PATH for different tools
```

## References

- [Apptainer Documentation](https://apptainer.org/documentation/)
- [tshark Manual](https://www.wireshark.org/docs/man-pages/tshark.html)
- [Wireshark Docker Image](https://hub.docker.com/r/wireshark/wireshark)

## Summary

✅ **Agent automatically uses containerized tshark**
✅ **Transparent to user - no code changes needed**
✅ **Set TSHARK_CONTAINER_PATH environment variable once**
✅ **All PCAP analysis now runs in isolated container**
✅ **Error handling for common issues built-in**

**Status**: Ready to use containerized tshark! 🚀
