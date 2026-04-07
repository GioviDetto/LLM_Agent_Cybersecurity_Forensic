# LLM Agent for Cybersecurity Forensic Analysis - Comprehensive System Report

## Executive Summary

This is an **LLM-powered AI agent** that performs autonomous forensic analysis on network security events captured in PCAP files. The system detects vulnerabilities (e.g., CVEs), identifies affected services, and generates structured forensic reports using local or cloud-based language models.

**Key Innovation**: The agent combines network traffic analysis (tshark), LLM reasoning, and web search to provide comprehensive cybersecurity forensic reports.

---

## What the System Does

### Core Mission
Analyze network traffic PCAP files to:
1. **Identify suspicious network flows** and activities
2. **Detect CVEs and vulnerabilities** in traffic patterns
3. **Correlate findings** with system logs and historical data
4. **Generate forensic reports** with actionable intelligence

### Input & Output
- **Input**: `.pcap` files (network packet captures) + optional system logs
- **Output**: Structured forensic reports with CVE identifications, affected services, and security assessments

### Use Cases
- Incident response and forensic investigation
- Vulnerability detection in network traffic
- Security event correlation and analysis
- Compliance and audit reporting

---

## Architecture Overview

### High-Level System Flow

```
PCAP Event Dataset
    ↓
┌─────────────────────────────────────┐
│  Agent Initialization               │
│  ├─ Load LLM (vLLM or OpenAI)      │
│  ├─ Initialize embeddings           │
│  └─ Setup tools (browser, analyzer) │
└────────────────┬────────────────────┘
                 ↓
         For Each PCAP Event:
                 ↓
    ┌────────────────────────────┐
    │ PCAP Flows Analyzer        │
    │ ├─ Extract TCP flows       │
    │ ├─ Identify HTTP traffic   │
    │ └─ Parse conversations     │
    └────────────┬───────────────┘
                 ↓
    ┌────────────────────────────┐
    │ Agent Reasoning Loop       │
    │ ├─ Analyze findings        │
    │ ├─ Search vulnerabilities  │
    │ ├─ Query web resources     │
    │ └─ Synthesize conclusions  │
    └────────────┬───────────────┘
                 ↓
    ┌────────────────────────────┐
    │ Report Generation          │
    │ ├─ CVE mapping             │
    │ ├─ Risk assessment         │
    │ └─ Structured output       │
    └────────────────────────────┘
```

### Multiple Architecture Options

The system supports **5 different agent designs**, each trading off complexity vs. capability:

1. **Flow Reporter** (main branch) - Lightweight, direct flow analysis
2. **Single-Agent** - Minimal architecture, single LLM agent
3. **TShark Expert** - Multi-agent with tshark command execution
4. **TShark Expert + Logs** - Enhanced with system log analysis
5. **Pipeline of Agents** - Three specialized agents working in sequence

**Switch architectures by changing Git branches** - each has independent implementation.

---

## Core Components

### 1. LLM Service Layer (`src/multi_agent/llm_service/`)

**Purpose**: Abstract LLM provider (vLLM or OpenAI)

**Key Classes**:
- `VLLMChatModel` - Direct vLLM model instantiation with GPU support
- `LLMFactory` (via `init_llm()`) - Routes to provider based on model string

**How It Works**:
```
Model String Analysis:
├─ "vllm/meta-llama/..." → Load local vLLM model directly
└─ "openai/gpt-4o" → Use OpenAI API

Configuration:
├─ GPU memory allocation (0-1.0)
├─ Max tokens per response
└─ Sampling parameters (temperature, top-p)
```

**Lazy Loading**: Model loads on first use (5-30 seconds), subsequent calls are fast (3-5 seconds)

### 2. PCAP Flow Analyzer (`src/multi_agent/pcap_flow_analyzer/`)

**Purpose**: Extract and parse network flows from PCAP files

**Key Functions**:
- `count_flows()` - Count TCP flows in PCAP
- `get_flow()` - Extract specific TCP flow
- `get_flow_http()` - Extract HTTP flows with TLS keys
- `get_flow_http2()` - Parse HTTP/2 subflows
- `conv_tcp()` - Get TCP conversation statistics

**Works With**:
- **Apptainer containerized tshark** - No host installation needed
- **Extracts**: Packet timings, protocols, payloads, encryption keys

### 3. Web Browser & Search (`src/browser/`)

**Purpose**: Research vulnerabilities and security information online

**Key Functions**:
- `online_browser.py` - Browser automation for web searches
- `chunking_utils.py` - Intelligently chunk large web content
- `summarization_utils.py` - Compress research findings

**Used For**:
- CVE database lookups
- Vulnerability confirmation
- Service identification

### 4. Main Agent (`src/multi_agent/main_agent/`)

**Purpose**: Orchestrate analysis workflow using LangGraph state machine

**Components**:
- `graph.py` - Agent state machine and node definitions
- `prompts.py` - System prompts for forensic reasoning
- `nodes/` - Individual analysis steps (classify, research, report)
- `tools/` - Executable tools available to agent

**Workflow Nodes**:
1. **Classify** - Initial traffic characterization
2. **Research** - Deep vulnerability investigation
3. **Report** - Final findings synthesis
4. **Reflect** - Self-check and iteration

### 5. Log Reporter (`src/multi_agent/log_reporter/`)

**Purpose**: Analyze system logs for correlated findings

**Functions**:
- Parse application and system logs
- Correlate events with network findings
- Enhance vulnerability context

### 6. Common Utilities (`src/multi_agent/common/`)

**Key Modules**:
- `tshark_apptainer.py` - Containerized network analysis
- `utils.py` - PCAP manipulation functions
- `global_state.py` - Shared application state
- `configuration.py` - Environment and settings management

---

## Deployment Options

### Option 1: Direct vLLM (Recommended)
```bash
bash scripts/run_agent_unified.sh --model meta-llama/Meta-Llama-3-8B-Instruct
```
- **Single process**, no server needed
- **Direct GPU execution**
- Model loads on first use
- Simplest deployment

### Option 2: Docker-Based vLLM
```bash
bash scripts/run_with_vllm.sh --docker --model mistralai/Mistral-7B-Instruct-v0.2
```
- Containerized vLLM server
- Better isolation
- Easier multi-machine setup

### Option 3: OpenAI API
```bash
export MODEL="openai/gpt-4o"
python src/run_agent.py
```
- Cloud-based inference
- No local GPU needed
- Higher per-token cost

### Option 4: Apptainer Container
```bash
bash scripts/setup_apptainer_tshark.sh
python src/run_agent.py
```
- Containerized tshark
- Reproducible environment
- No system-wide dependencies

---

## Configuration & Environment

### Key Environment Variables

```env
# Model Selection
MODEL = vllm/meta-llama/Meta-Llama-3-8B-Instruct

# vLLM Settings (if using local model)
VLLM_MODEL = meta-llama/Meta-Llama-3-8B-Instruct
VLLM_GPU_MEMORY = 0.9          # 90% GPU allocation
VLLM_MAX_TOKENS = 2048          # Response length limit

# Embeddings (for vector search)
USE_LOCAL_EMBEDDINGS = true
EMBEDDING_MODEL = all-MiniLM-L6-v2

# Network Analysis
TSHARK_CONTAINER_PATH = ./tshark.sif

# Dataset Selection
DATASET = CFA-benchmark            # or TestSet_benchmark
NUM_EVENTS = 20                    # How many events to process

# OpenAI (optional backup)
OPENAI_API_KEY = your_key_here
```

---

## Data Structure

### Dataset Organization

```
data/
├── CFA-benchmark/              # Main forensic dataset
│   ├── raw/eventID_0/         # PCAP + logs for event 0
│   │   ├── *.pcap             # Network traffic captures
│   │   └── *.log              # System/application logs
│   └── tasks/data.json        # Event metadata and ground truth
│
└── TestSet_benchmark/          # Smaller test/validation set
    ├── raw/eventID_0/
    └── tasks/data.json
```

### Task Metadata Format

```json
{
  "eventID": 0,
  "description": "Potential SQL injection attack detected",
  "pcap_file": "pcap_0.pcap",
  "log_file": "events.log",
  "cves": ["CVE-2022-12345"],
  "affected_services": ["MySQL", "Apache"],
  "risk_level": "high"
}
```

---

## Execution Flow

### Step-by-Step Process

**1. Initialization** (5-10 seconds)
```
├─ Load configuration from .env
├─ Initialize LLM (model loads on first use)
├─ Setup embeddings model
├─ Load PCAP dataset metadata
└─ Initialize agent graph
```

**2. For Each Event** (3-15 minutes per event depending on model)
```
Analyze PCAP:
├─ Extract flows using tshark
├─ Parse HTTP/TLS streams
├─ Correlate with logs
└─ Initial classification

Agent Thinking:
├─ Analyze findings through LLM lens
├─ Generate research queries
├─ Execute web searches
├─ Synthesize conclusions
└─ Generate forensic report

Output:
├─ Save structured findings (JSON)
├─ Generate markdown report
└─ Log execution trace
```

**3. Aggregation** (1-5 seconds)
```
├─ Compile all event reports
├─ Generate summary statistics
├─ Create overall analysis
└─ Generate consolidated report
```

---

## Key Features & Capabilities

### Vulnerability Detection
- **CVE Identification** - Maps network patterns to known CVEs
- **Service Detection** - Identifies applications and versions
- **Protocol Analysis** - Deep inspection of HTTP, TLS, DNS, etc.

### Analysis Methods
- **Network Flow Analysis** - TCP/UDP conversation patterns
- **HTTP/HTTPS Inspection** - Request/response analysis with decryption
- **Log Correlation** - System and application log matching
- **Temporal Analysis** - Event timing and sequence correlation
- **Web Research** - Real-time vulnerability lookup

### Output Formats
- **Structured JSON** - Machine-readable findings
- **Markdown Reports** - Human-readable analysis
- **Execution Logs** - Debug and audit trail
- **Summary Statistics** - Aggregate insights

---

## Integration Points & Extensibility

### Adding New Tools
The agent can use any Python callable as a tool. Add to `src/multi_agent/main_agent/tools/`:
```python
def my_analysis_tool(pcap_file, param1):
    """Tool that agent can invoke."""
    return analysis_results
```

### Custom Prompts
Modify forensic reasoning prompts in:
- `src/multi_agent/main_agent/prompts.py`
- `src/multi_agent/log_reporter/prompts.py`

### Changing Models
Switch LLM by editing `.env`:
```env
MODEL = vllm/mistralai/Mistral-7B-Instruct-v0.2
```

### Adding New Analysis Nodes
Extend agent graph in `src/multi_agent/main_agent/graph.py`:
```python
graph.add_node("my_analysis", my_analysis_function)
graph.add_edge("classify", "my_analysis")
```

---

## Refactoring & Recent Updates

### vLLM Direct Instantiation
**What Changed**: Moved from HTTP client-server to direct model loading
- **Before**: Separate vLLM server process + HTTP calls
- **After**: Single Python process with in-memory model
- **Benefit**: Simpler deployment, no networking overhead, better resource sharing

### Apptainer Integration
**What Changed**: Containerized tshark instead of host installation
- **Before**: Required system-wide tshark installation
- **After**: Self-contained tshark container
- **Benefit**: Reproducible environment, portable across systems

### Embeddings Factory
**What Changed**: Flexible embedding provider (HuggingFace or OpenAI)
- **Before**: Hard-coded OpenAI embeddings
- **After**: Choose local or cloud embeddings at runtime
- **Benefit**: Cost savings with local embeddings, flexibility for different needs

---

## Troubleshooting Common Issues

### Memory Issues
```bash
# Reduce GPU memory allocation
bash scripts/run_agent_unified.sh --gpu-memory 0.7
```

### Slow Performance
```bash
# Use smaller, faster model
bash scripts/run_agent_unified.sh --model mistralai/Mistral-7B-Instruct-v0.2
```

### CUDA/GPU Not Found
```bash
# Fallback to CPU (very slow)
export VLLM_GPU_MEMORY=0  # Disables GPU
```

### tshark Analysis Fails
```bash
# Verify Apptainer setup
bash scripts/setup_apptainer_tshark.sh --verify
```

### Out of Memory on First Run
```bash
# Reduce dataset size
python src/run_agent.py --num-events 5
```

---

## Project Structure Summary

```
src/
├── configuration.py              # Load env config
├── run_agent.py                  # Main entry point
├── run_agent_web_events.py       # Web browsing variant
├── multi_agent/
│   ├── llm_service/              # LLM provider abstraction
│   ├── pcap_flow_analyzer/       # Network analysis
│   ├── log_reporter/             # System log analysis
│   ├── embeddings_service/       # Vector embeddings
│   ├── main_agent/               # Core reasoning agent
│   │   ├── graph.py              # LangGraph definition
│   │   ├── prompts.py            # System prompts
│   │   ├── nodes/                # Analysis nodes
│   │   └── tools/                # Agent tools
│   └── common/                   # Shared utilities
│       ├── tshark_apptainer.py   # Container wrapper
│       └── utils.py              # Helper functions
└── browser/                      # Web search tools

scripts/
├── run_agent_unified.sh          # Main entry script
├── run_with_vllm.sh              # Advanced runner
├── start_vllm.sh                 # vLLM server (legacy)
└── setup_apptainer_tshark.sh    # Container setup

data/
├── CFA-benchmark/               # Primary dataset
└── TestSet_benchmark/           # Test dataset
```

---

## Quick Start

### 30-Second Setup
```bash
# 1. Clone and setup
cd /path/to/LLM_Agent_Cybersecurity_Forensic
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. Configure
cp src/.env.example src/.env
# Edit src/.env with your model choice

# 3. Run
bash scripts/run_agent_unified.sh
```

### Full Documentation Map
- **Getting Started**: `QUICKSTART_VLLM.md`
- **Deployment**: `VLLM_INTEGRATION.md`
- **Architecture**: `VLLM_ARCHITECTURE_DEEP_DIVE.md`
- **Network Setup**: `APPTAINER_TSHARK_GUIDE.md`
- **Changes Made**: `CHANGES.md`

---

## Next Steps

1. **Install dependencies**: `pip install -r requirements.txt`
2. **Setup environment**: Copy and edit `src/.env.example`
3. **Verify setup**: `python validate_refactoring.py`
4. **Run agent**: `bash scripts/run_agent_unified.sh`
5. **Check results**: Look in `results/` directory for reports
6. **Extend**: Add custom tools or analysis nodes as needed

---

## Summary

This system is a **production-ready AI agent** for cybersecurity forensic analysis that:
- ✅ Analyzes network PCAP files autonomously
- ✅ Detects CVEs and vulnerabilities
- ✅ Supports multiple LLM backends
- ✅ Provides detailed forensic reports
- ✅ Runs on local hardware or cloud
- ✅ Is highly extensible and configurable

The architecture balances **flexibility** (5 different agent designs) with **simplicity** (single unified script), making it suitable for both research and production deployment.
