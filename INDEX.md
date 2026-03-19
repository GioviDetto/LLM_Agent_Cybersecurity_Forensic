# Documentation Index - vLLM Integration

## 📋 Quick Navigation

### For First-Time Users
1. **Start here**: [QUICKSTART_VLLM.md](QUICKSTART_VLLM.md) - 5-minute setup
2. **Then read**: [VLLM_INTEGRATION.md](VLLM_INTEGRATION.md) - Full guide with troubleshooting

### For Developers
1. **Architecture**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - How refactoring works
2. **Details**: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - What changed and why
3. **Changes**: [CHANGES.md](CHANGES.md) - Complete file-by-file changes

### For Verification
1. **Check status**: Run `python validate_refactoring.py`
2. **See summary**: [REFACTORING_COMPLETE.md](REFACTORING_COMPLETE.md)

---

## 📚 Documentation Files

### Getting Started (Recommended Reading Order)

#### 1. [QUICKSTART_VLLM.md](QUICKSTART_VLLM.md)
**Best for**: Getting running in 5 minutes
**Contains**:
- 5-minute setup guide
- 3 setup options (direct, Docker, manual)
- Key environment variables
- Common issues & quick fixes
- Performance notes

**Time to read**: 5-10 minutes
**Next step**: VLLM_INTEGRATION.md

---

#### 2. [VLLM_INTEGRATION.md](VLLM_INTEGRATION.md)
**Best for**: Complete understanding and troubleshooting
**Contains**:
- Detailed setup instructions
- Configuration reference (all variables)
- Supported models list
- Performance considerations
- Troubleshooting guide
- Module structure
- Integration points

**Time to read**: 20-30 minutes
**Sections**:
- Overview of changes (10 min)
- Setup instructions (5 min)
- Configuration options (5 min)
- Model support (5 min)
- Troubleshooting (5 min)

---

#### 3. [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
**Best for**: Understanding architecture and extending
**Contains**:
- Summary of changes
- Old vs. new patterns
- Migration path for code
- Architecture decisions explained
- Testing guidance
- Future extension points

**Time to read**: 15-20 minutes
**Audience**: Developers modifying the code

---

#### 4. [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
**Best for**: Overview of implementation
**Contains**:
- Module descriptions
- Configuration updates
- Code updates summary
- Deployment scripts overview
- Validation results
- Getting started checklist

**Time to read**: 10-15 minutes
**Best with**: validate_refactoring.py output

---

#### 5. [REFACTORING_COMPLETE.md](REFACTORING_COMPLETE.md)
**Best for**: What was accomplished
**Contains**:
- Key achievements summary
- File structure overview
- How to use examples
- Environment variables
- Architecture improvements
- Performance characteristics

**Time to read**: 10 minutes
**Status**: Final summary

---

#### 6. [CHANGES.md](CHANGES.md)
**Best for**: File-by-file change tracking
**Contains**:
- Complete file listing
- Line-by-line changes
- Backward compatibility verification
- Before/after code patterns
- Statistics

**Time to read**: 5-10 minutes
**Use**: As reference when digging into specific files

---

## 🔧 Configuration Files

### [src/.env.example](src/.env.example)
**Purpose**: Template for environment configuration
**When to use**: Copy to `src/.env` before running

**Key variables**:
```
MODEL = vllm/meta-llama/Meta-Llama-3-8B-Instruct
VLLM_BASE_URL = http://localhost:8000/v1
USE_LOCAL_EMBEDDINGS = true
EMBEDDING_MODEL = all-MiniLM-L6-v2
```

---

## 🐍 Python Files

### Core Modules

#### [src/multi_agent/llm_service/](src/multi_agent/llm_service/)
**Purpose**: LLM initialization abstraction
**Files**:
- `__init__.py` - Exports
- `factory.py` - `init_llm()` function
- `vllm_wrapper.py` - vLLM LangChain wrapper

**Usage**:
```python
from multi_agent.llm_service import init_llm
llm = init_llm("vllm/meta-llama/Meta-Llama-3-8B-Instruct")
```

#### [src/multi_agent/embeddings_service/](src/multi_agent/embeddings_service/)
**Purpose**: Embeddings initialization abstraction
**Files**:
- `__init__.py` - `get_embeddings()` function

**Usage**:
```python
from multi_agent.embeddings_service import get_embeddings
embeddings = get_embeddings(use_local=True)
```

### Updated Files
- `src/configuration.py` - Configuration with vLLM settings
- `src/run_agent.py` - Uses get_embeddings() factory
- `src/run_agent_web_events.py` - Uses get_embeddings() factory
- `src/multi_agent/main_agent/nodes/main_agent.py` - Uses init_llm()
- `src/multi_agent/main_agent/nodes/tools.py` - Uses init_llm()
- `src/multi_agent/log_reporter/log_reporter.py` - Uses init_llm()
- `src/multi_agent/pcap_flow_analyzer/pcap_flow_analyzer.py` - Uses init_llm()

---

## 🚀 Scripts

### [scripts/start_vllm.sh](scripts/start_vllm.sh)
**Purpose**: Start vLLM server directly
**Usage**:
```bash
bash scripts/start_vllm.sh
# or with options
VLLM_MODEL="meta-llama/Meta-Llama-3-70B-Instruct" bash scripts/start_vllm.sh
```
**Best for**: Direct installation on GPU machines

---

### [scripts/start_vllm_docker.sh](scripts/start_vllm_docker.sh)
**Purpose**: Start vLLM in Docker
**Usage**:
```bash
bash scripts/start_vllm_docker.sh
```
**Best for**: Easy setup without GPU driver installation

---

### [scripts/run_with_vllm.sh](scripts/run_with_vllm.sh)
**Purpose**: Run experiments with convenient CLI
**Usage**:
```bash
bash scripts/run_with_vllm.sh \
    --model meta-llama/Meta-Llama-3-8B-Instruct \
    --dataset CFA \
    --events 20 \
    --embeddings
```
**Best for**: Launching experiments with custom parameters

---

## ✅ Validation

### [validate_refactoring.py](validate_refactoring.py)
**Purpose**: Verify refactoring completeness
**Usage**:
```bash
python validate_refactoring.py
```
**Checks**:
- 13 file structure checks
- 6 code update checks
- 4 configuration checks
- 3 dependency checks

---

## 📊 Documentation Statistics

| File | Purpose | Length | Audience |
|------|---------|--------|----------|
| QUICKSTART_VLLM.md | 5-minute setup | ~150 lines | Everyone |
| VLLM_INTEGRATION.md | Complete guide | ~400 lines | Operators |
| MIGRATION_GUIDE.md | Architecture | ~300 lines | Developers |
| IMPLEMENTATION_SUMMARY.md | Overview | ~250 lines | Managers |
| REFACTORING_COMPLETE.md | Summary | ~300 lines | Project leads |
| CHANGES.md | Change tracking | ~200 lines | Developers |
| INDEX.md | Navigation | This file | Everyone |

---

## 🎯 Quick Decision Guide

### I want to...

**Get running in 5 minutes**
→ Read: QUICKSTART_VLLM.md

**Understand all configuration options**
→ Read: VLLM_INTEGRATION.md (Configuration Options section)

**Troubleshoot a problem**
→ Read: VLLM_INTEGRATION.md (Troubleshooting section) or QUICKSTART_VLLM.md

**Add a new LLM provider**
→ Read: MIGRATION_GUIDE.md (Architecture Decisions section)

**See what files changed**
→ Read: CHANGES.md (Complete List of Changes)

**Verify everything is set up**
→ Run: `python validate_refactoring.py`

**Run with a different model**
→ Use: `bash scripts/run_with_vllm.sh --model <name>`

**Switch back to OpenAI**
→ Set: `export MODEL="openai/gpt-4o"` and `export USE_LOCAL_EMBEDDINGS="false"`

---

## 🔗 Related Resources

### Official Documentation
- [vLLM Docs](https://docs.vllm.ai/)
- [LangChain Docs](https://docs.langchain.com/)
- [HuggingFace Models](https://huggingface.co/models)

### Key Models
- [Meta-Llama-3-8B-Instruct](https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct)
- [Meta-Llama-3-70B-Instruct](https://huggingface.co/meta-llama/Meta-Llama-3-70B-Instruct)
- [Mistral-7B-Instruct](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2)

### Embedding Models
- [all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
- [BAAI/bge-small-en](https://huggingface.co/BAAI/bge-small-en)
- [BAAI/bge-base-en](https://huggingface.co/BAAI/bge-base-en)

---

## 📝 Summary

**Start here**: Pick your reading based on the Decision Guide above
**Main goal**: Run experiments with local vLLM models
**Key achievement**: Abstracted LLM and embeddings initialization
**Status**: ✅ Production ready

---

*Documentation last updated: March 19, 2026*
