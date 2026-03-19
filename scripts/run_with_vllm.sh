#!/bin/bash

# Convenience script to run experiments with vLLM models
# Usage: ./run_with_vllm.sh [options]
# Options:
#   --model MODEL_NAME      The model to use (default: meta-llama/Meta-Llama-3-8B-Instruct)
#   --dataset DATASET       Dataset to use: CFA, test, web_browsing_events (default: CFA)
#   --events N              Number of events to process (default: 20)
#   --executions N          Number of executions (default: 3)
#   --embeddings            Use local embeddings (default: remote OpenAI)
#   --help                  Show this help message

set -e

# Color output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Defaults
VLLM_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
DATASET="CFA"
NUM_EVENTS=20
NUM_EXECUTIONS=3
USE_LOCAL_EMBEDDINGS="false"
RUN_AGENT_SCRIPT="src/run_agent.py"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            VLLM_MODEL="$2"
            shift 2
            ;;
        --dataset)
            DATASET="$2"
            if [[ "$DATASET" == "web_browsing_events" ]]; then
                RUN_AGENT_SCRIPT="src/run_agent_web_events.py"
            fi
            shift 2
            ;;
        --events)
            NUM_EVENTS="$2"
            shift 2
            ;;
        --executions)
            NUM_EXECUTIONS="$2"
            shift 2
            ;;
        --embeddings)
            USE_LOCAL_EMBEDDINGS="true"
            shift
            ;;
        --help)
            cat <<'HELP'
Usage: ./run_with_vllm.sh [options]

Options:
  --model MODEL_NAME        vLLM model identifier (default: meta-llama/Meta-Llama-3-8B-Instruct)
  --dataset DATASET         Dataset: CFA, test, web_browsing_events (default: CFA)
  --events N                Number of events to process (default: 20)
  --executions N            Number of executions (default: 3)
  --embeddings              Use local HuggingFace embeddings (default: OpenAI)
  --help                    Show this help message

Examples:
  # Run with default settings
  ./run_with_vllm.sh

  # Run with Llama 3 70B and local embeddings
  ./run_with_vllm.sh --model meta-llama/Meta-Llama-3-70B-Instruct --embeddings

  # Run web browsing events
  ./run_with_vllm.sh --dataset web_browsing_events --events 10
HELP
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}vLLM Experiment Runner${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Model:${NC} $VLLM_MODEL"
echo -e "${GREEN}Dataset:${NC} $DATASET"
echo -e "${GREEN}Events:${NC} $NUM_EVENTS"
echo -e "${GREEN}Executions:${NC} $NUM_EXECUTIONS"
echo -e "${GREEN}Local Embeddings:${NC} $USE_LOCAL_EMBEDDINGS"
echo -e "${YELLOW}========================================${NC}"
echo

# Set environment variables
export MODEL="vllm/$VLLM_MODEL"
export VLLM_MODEL="$VLLM_MODEL"
export VLLM_BASE_URL="http://localhost:8000/v1"
export DATASET="$DATASET"
export NUMBER_OF_EVENTS="$NUM_EVENTS"
export NUMBER_OF_EXECUTIONS="$NUM_EXECUTIONS"
export USE_LOCAL_EMBEDDINGS="$USE_LOCAL_EMBEDDINGS"
export EMBEDDING_MODEL="all-MiniLM-L6-v2"

# Check vLLM server is running
echo -e "${YELLOW}Checking vLLM server...${NC}"
if ! curl -s "$VLLM_BASE_URL/models" > /dev/null; then
    echo -e "${YELLOW}Warning: vLLM server not responding at $VLLM_BASE_URL${NC}"
    echo -e "${YELLOW}Start vLLM with: ./scripts/start_vllm.sh --model \"$VLLM_MODEL\"${NC}"
    exit 1
fi
echo -e "${GREEN}vLLM server is running${NC}"
echo

# Run the experiment
echo -e "${YELLOW}Starting experiment...${NC}"
cd "$(dirname "$BASH_SOURCE")"
python "$RUN_AGENT_SCRIPT"

echo -e "${GREEN}Experiment completed!${NC}"
