#!/bin/bash
set -e

# --- Defaults & Colors ---
MODEL_ID=${MODEL_ID:-"meta-llama/Meta-Llama-3-8B-Instruct"}
GPU_MEMORY="0.9"
MAX_TOKENS="1024"
NUM_EVENTS="20"
DATASET="CFA-benchmark"
USE_LOCAL="false"
SCRIPT="src/run_agent.py"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)      MODEL_ID="$2"; shift 2 ;;
    --gpu-memory) GPU_MEMORY="$2"; shift 2 ;;
    --events)     NUM_EVENTS="$2"; shift 2 ;;
    --web-events) SCRIPT="src/run_agent_web_events.py"; shift ;;
    --use-local-embeddings) USE_LOCAL="true"; shift ;;
    --help)       grep '^# ' "$0" | head -n 20; exit 0 ;;
    *)            error "Unknown option: $1. Use --help." ;;
  esac
done

# --- Pre-flight Checks ---
log "Verifying environment..."
[[ -f "$SCRIPT" ]] || error "Script $SCRIPT not found. Run from repo root."
command -v python3 >/dev/null || error "Python3 not found."

# Ensure .env exists
[[ -f .env ]] || { log "Creating .env..."; cp .env.example .env 2>/dev/null || touch .env; }

# Verify dependencies (Checks vllm, langchain, etc. in one go)
python3 -c "import vllm, langchain, langgraph, pydantic" 2>/dev/null || \
  error "Missing dependencies. Run: pip install vllm langchain langgraph pydantic"

# --- Environment Setup ---
export VLLM_MODEL="$MODEL_ID"
export VLLM_GPU_MEMORY="$GPU_MEMORY"
export VLLM_MAX_TOKENS="$MAX_TOKENS"
export NUMBER_OF_EVENTS="$NUM_EVENTS"
export USE_LOCAL_EMBEDDINGS="$USE_LOCAL"
export MODEL="vllm/$MODEL_ID"

# --- Execution ---
echo -e "${GREEN}▶ Starting Analysis with $MODEL_ID...${NC}"
python3 "$SCRIPT"

echo -e "${GREEN}✓ Analysis complete.${NC}"