#!/bin/bash

# Quick setup script for Apptainer tshark container

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Apptainer tshark Setup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo

# Check if Apptainer is installed
if ! command -v apptainer &> /dev/null; then
    echo -e "${RED}Error: Apptainer is not installed${NC}"
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt-get install -y apptainer"
    echo "  RHEL/CentOS: sudo dnf install -y apptainer"
    echo "  Or visit: https://apptainer.org/docs/admin/main/installation.html"
    exit 1
fi

echo -e "${GREEN}✓ Apptainer is installed${NC}"
apptainer --version

# Determine where to build/place container
REPO_ROOT="$(dirname "$(dirname "$(dirname "$0")")")"
CONTAINER_PATH="${REPO_ROOT}/tshark.sif"
CONTAINER_PATH_ENV="${REPO_ROOT}/src/.env.example"

echo

# Option 1: Check if container already exists
if [ -f "$CONTAINER_PATH" ]; then
    echo -e "${GREEN}✓ Found existing tshark.sif at: $CONTAINER_PATH${NC}"
    ls -lh "$CONTAINER_PATH"
    echo
    read -p "Use existing container? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing container${NC}"
    else
        echo -e "${YELLOW}Removing old container...${NC}"
        rm "$CONTAINER_PATH"
    fi
fi

# Option 2: Build or download container
if [ ! -f "$CONTAINER_PATH" ]; then
    echo
    echo -e "${YELLOW}Building/downloading tshark container...${NC}"
    echo
    
    # Method 1: Quick - download from Docker registry
    echo "Method 1: Download from Docker (fastest, requires ~1GB disk)"
    read -p "Use Docker image? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Downloading wireshark/wireshark Docker image...${NC}"
        apptainer pull "$CONTAINER_PATH" docker://wireshark/wireshark:latest
    else
        # Method 2: Use local Dockerfile if exists
        if [ -f "${REPO_ROOT}/Dockerfile.tshark" ]; then
            echo -e "${YELLOW}Building from Dockerfile.tshark...${NC}"
            apptainer build "$CONTAINER_PATH" "${REPO_ROOT}/Dockerfile.tshark"
        else
            # Create a simple Dockerfile
            echo -e "${YELLOW}Creating simple tshark Dockerfile...${NC}"
            cat > "${REPO_ROOT}/Dockerfile.tshark" << 'DOCKERFILE'
Bootstrap: docker
From: ubuntu:22.04

%post
    apt-get update
    apt-get install -y --no-install-recommends \
        tshark \
        ca-certificates
    apt-get clean
    rm -rf /var/lib/apt/lists/*

%labels
    Version 1.0
    Description tshark container for network packet analysis

%help
    This container provides tshark for PCAP analysis
    
    Usage: apptainer exec tshark.sif tshark [options]
    
    Examples:
      tshark -r file.pcap -q -z conv,tcp
      tshark -r file.pcap -T fields -e tcp.stream
DOCKERFILE
            
            echo -e "${YELLOW}Building container from Dockerfile...${NC}"
            apptainer build "$CONTAINER_PATH" "${REPO_ROOT}/Dockerfile.tshark"
        fi
    fi
fi

# Verify container
echo
echo -e "${YELLOW}Verifying container...${NC}"

if [ ! -f "$CONTAINER_PATH" ]; then
    echo -e "${RED}Error: Container not created${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container exists: $CONTAINER_PATH${NC}"
ls -lh "$CONTAINER_PATH"

# Test container
echo
echo -e "${YELLOW}Testing container...${NC}"

if apptainer exec "$CONTAINER_PATH" tshark --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ tshark works in container${NC}"
    apptainer exec "$CONTAINER_PATH" tshark --version
else
    echo -e "${RED}✗ tshark test failed${NC}"
    echo "Try testing manually: apptainer exec $CONTAINER_PATH tshark --version"
    exit 1
fi

# Update .env
echo
echo -e "${YELLOW}Updating .env configuration...${NC}"

if [ -f "${REPO_ROOT}/src/.env" ]; then
    echo "Updating existing .env"
    # Remove any existing TSHARK_CONTAINER_PATH
    sed -i '/TSHARK_CONTAINER_PATH/d' "${REPO_ROOT}/src/.env"
    echo "TSHARK_CONTAINER_PATH = $CONTAINER_PATH" >> "${REPO_ROOT}/src/.env"
else
    echo "Creating .env from template"
    cp "${REPO_ROOT}/src/.env.example" "${REPO_ROOT}/src/.env"
    sed -i "s|TSHARK_CONTAINER_PATH = .*|TSHARK_CONTAINER_PATH = $CONTAINER_PATH|" "${REPO_ROOT}/src/.env"
fi

echo -e "${GREEN}✓ Updated .env configuration${NC}"
echo "TSHARK_CONTAINER_PATH = $CONTAINER_PATH"

# Final verification
echo
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Apptainer tshark setup complete!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo
echo "Next steps:"
echo "1. Export environment: export TSHARK_CONTAINER_PATH=\"$CONTAINER_PATH\""
echo "2. Or it will use value from .env: $(grep TSHARK_CONTAINER_PATH ${REPO_ROOT}/src/.env)"
echo "3. Run the agent: cd src && python run_agent.py"
echo
echo "Test manually with:"
echo "  apptainer exec $CONTAINER_PATH tshark -r sample.pcap -q -z conv,tcp"
echo
