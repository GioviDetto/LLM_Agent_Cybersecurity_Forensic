#!/bin/bash

###############################################################################
# Unified Script: Run Agent with Direct vLLM Model Loading
#
# This script loads the vLLM model directly in the same Python process
# and runs the forensic analysis agent.
#
# No separate server needed - everything runs in a single process!
#
# Usage:
#   bash scripts/run_agent_unified.sh [options]
#
# Options:
#   --model MODEL_ID              HuggingFace model ID (default: meta-llama/Meta-Llama-3-8B-Instruct)
#   --gpu-memory 0-1              GPU memory fraction (default: 0.9)
#   --max-tokens N                Max tokens per response (default: 1024)
#   --events N                    Number of events to analyze (default: 20)
#   --dataset DATASET             Dataset: CFA-benchmark or TestSet_benchmark (default: CFA-benchmark)
#   --use-local-embeddings        Use HuggingFace embeddings (local) instead of OpenAI
#   --embedding-model MODEL       Embedding model name (default: all-MiniLM-L6-v2)
#   --web-events                  Analyze web browsing events instead
#   --help                        Show this help message
#
# Examples:
#   # Run with default Llama 3 model (8B)
#   bash scripts/run_agent_unified.sh
#
#   # Run with custom model and GPU memory usage
#   bash scripts/run_agent_unified.sh --model mistralai/Mistral-7B-Instruct-v0.2 --gpu-memory 0.8
#
#   # Run with web browsing analysis
#   bash scripts/run_agent_unified.sh --web-events
#
#   # Run with local embeddings
#   bash scripts/run_agent_unified.sh --use-local-embeddings
#
###############################################################################

set -e

# Default values
MODEL_ID="meta-llama/Meta-Llama-3-8B-Instruct"
GPU_MEMORY="0.9"
MAX_TOKENS="1024"
NUM_EVENTS="20"
DATASET="CFA-benchmark"
USE_LOCAL_EMBEDDINGS="false"
EMBEDDING_MODEL="all-MiniLM-L6-v2"
SCRIPT_TYPE="standard"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL_ID="$2"
            shift 2
            ;;
        --gpu-memory)
            GPU_MEMORY="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --events)
            NUM_EVENTS="$2"
            shift 2
            ;;
        --dataset)
            DATASET="$2"
            shift 2
            ;;
        --use-local-embeddings)
            USE_LOCAL_EMBEDDINGS="true"
            shift
            ;;
        --embedding-model)
            EMBEDDING_MODEL="$2"
            shift 2
            ;;
        --web-events)
            SCRIPT_TYPE="web_events"
            shift
            ;;
        --help)
            head -n 42 "$0" | tail -n 40
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Function to print info
print_info() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Print banner
echo -e "${BLUE}"
cat << "EOF"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        LLM Agent - Forensic Analysis with vLLM               ║
║        Direct Model Loading (No Separate Server)             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
echo -e "${NC}"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 not found. Please install Python 3."
    exit 1
fi
print_info "Python 3 found: $(python3 --version)"

# Check if we're in the right directory
if [ ! -f "src/run_agent.py" ] && [ ! -f "src/run_agent_web_events.py" ]; then
    print_error "This script must be run from the repository root directory"
    print_error "Expected to find: src/run_agent.py or src/run_agent_web_events.py"
    exit 1
fi
print_info "Repository structure verified"

print_header "Configuration Summary"

echo "Model Configuration:"
echo "  Model ID:             $MODEL_ID"
echo "  GPU Memory Usage:     $GPU_MEMORY (0-1)"
echo "  Max Tokens/Response:  $MAX_TOKENS"
echo ""
echo "Analysis Configuration:"
echo "  Dataset:              $DATASET"
echo "  Events to Analyze:    $NUM_EVENTS"
echo "  Analysis Type:        $([ "$SCRIPT_TYPE" = "web_events" ] && echo "Web Browsing Events" || echo "PCAP Events")"
echo ""
echo "Embedding Configuration:"
echo "  Use Local Embeddings: $USE_LOCAL_EMBEDDINGS"
if [ "$USE_LOCAL_EMBEDDINGS" = "true" ]; then
    echo "  Embedding Model:      $EMBEDDING_MODEL"
fi
echo ""

# Set environment variables for Python
export VLLM_MODEL="$MODEL_ID"
export VLLM_MAX_TOKENS="$MAX_TOKENS"
export VLLM_GPU_MEMORY="$GPU_MEMORY"
export NUMBER_OF_EVENTS="$NUM_EVENTS"
export USE_LOCAL_EMBEDDINGS="$USE_LOCAL_EMBEDDINGS"
export EMBEDDING_MODEL="$EMBEDDING_MODEL"

# Set model to use vLLM
export MODEL="vllm/$MODEL_ID"

print_header "Pre-flight Checks"

# Check if vLLM is installed
if python3 -c "import vllm" 2>/dev/null; then
    print_info "vLLM is installed"
else
    print_error "vLLM is not installed"
    print_warning "Installing vLLM..."
    pip install vllm
fi

# Check if required dependencies are installed
REQUIRED_PACKAGES=("langchain" "langgraph" "pydantic" "python-dotenv")
for package in "${REQUIRED_PACKAGES[@]}"; do
    if python3 -c "import ${package}" 2>/dev/null; then
        print_info "$package is installed"
    else
        print_error "$package is not installed"
        exit 1
    fi
done

# Check if embeddings packages are installed if using local embeddings
if [ "$USE_LOCAL_EMBEDDINGS" = "true" ]; then
    if python3 -c "import sentence_transformers" 2>/dev/null; then
        print_info "sentence-transformers is installed (for embeddings)"
    else
        print_warning "Installing sentence-transformers..."
        pip install sentence-transformers
    fi
fi

print_header "Environment Setup"

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    print_info "Creating .env file from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        print_warning ".env.example not found, creating new .env..."
        cat > .env << 'ENVEOF'
# vLLM Configuration (Direct Loading)
VLLM_MODEL=meta-llama/Meta-Llama-3-8B-Instruct
VLLM_MAX_TOKENS=1024
VLLM_GPU_MEMORY=0.9

# Embeddings Configuration
USE_LOCAL_EMBEDDINGS=false
EMBEDDING_MODEL=all-MiniLM-L6-v2

# Apptainer tshark Configuration
TSHARK_CONTAINER_PATH=./tshark.sif

# Other Configuration
NUMBER_OF_EVENTS=20
CONTEXT_WINDOW_SIZE=128000
TOKENS_BUDGET=400000
ENVEOF
    fi
else
    print_info ".env file exists"
fi

# Load .env file (for any additional config not passed as arguments)
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
    print_info "Loaded configuration from .env"
fi

print_header "Starting Analysis"

echo -e "${GREEN}Initializing vLLM model directly in Python...${NC}\n"
echo "This may take 1-2 minutes on first run (downloading model if needed)"
echo "Subsequent runs will be much faster (model cached)"
echo ""

# Run the appropriate script
if [ "$SCRIPT_TYPE" = "web_events" ]; then
    print_info "Running web events analysis..."
    python3 src/run_agent_web_events.py
else
    print_info "Running PCAP events analysis..."
    python3 src/run_agent.py
fi

EXIT_CODE=$?

print_header "Analysis Complete"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Analysis completed successfully${NC}"
    echo ""
    echo "Results can be found in:"
    echo "  - Log reports: data/"
    echo "  - Agent outputs: Check console output above"
else
    print_error "Analysis failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
