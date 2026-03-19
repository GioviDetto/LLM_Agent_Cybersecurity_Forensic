# Flow: Web Search with Apptainer tshark

This document details the complete flow when the agent needs to search the web and analyze network traffic with the **new Apptainer containerized tshark** integration.

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent Needs Web Search                   │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│         LLM Decides to Call web_quick_search Tool            │
│  (Uses configured LLM: vLLM local or OpenAI API)             │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│    src/multi_agent/main_agent/nodes/tools.py                │
│      → web_quick_search tool execution                        │
│      → Initialize LLM via init_llm()                          │
│         (same model as agent, local or remote)                │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│            src/browser/online_browser.py                     │
│    → web_quick_search_func() performs web search              │
│       (requires GOOGLE_API_KEY_1, GOOGLE_CSE_ID)              │
│    → Returns web search results to LLM for summarization      │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│         LLM Summarizes Web Search Results                    │
│  (Uses same model: vLLM local or OpenAI API)                 │
│         ↓ if vLLM (local)                                    │
│         ✓ Completely local, private summarization             │
│         ↓ if OpenAI                                          │
│         ✓ API call via OpenAI                                │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│         Return Summary to Agent                              │
│    Summary is added as tool result message                    │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│     Agent Uses Summary for Analysis                          │
│                                                               │
│     If analyzing PCAP with web results:                      │
│     → Call to get_flow() or other PCAP functions             │
│     → These NOW use Apptainer tshark!                        │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│    src/multi_agent/common/utils.py                          │
│                                                               │
│    count_flows(pcap)                                         │
│         └→ count_flows_apptainer(pcap)                       │
│            └→ run_tshark_apptainer(["-r", pcap, ...])        │
│               └→ subprocess(["apptainer", "exec", ...])      │
│                  └→ tshark inside container                  │
│                     └→ Containerized analysis                │
│                                                               │
│    get_flow(pcap, stream)                                    │
│         └→ get_flow_apptainer(pcap, stream)                  │
│            └→ run_tshark_apptainer(["-q", "-z", ...])        │
│               └→ subprocess(["apptainer", "exec", ...])      │
│                  └→ tshark follows TCP stream in container   │
│                     └→ Containerized flow extraction         │
│                                                               │
│    get_flow_web_browsing(pcap, stream)                       │
│         └→ get_flow_http_apptainer(pcap, stream)             │
│            └→ run_tshark_apptainer(["-z", "follow,http"])   │
│               └→ subprocess(["apptainer", "exec", ...])      │
│                  └→ tshark extracts HTTP flow in container   │
│                     └→ Containerized HTTP flow extraction    │
│                                                               │
│    generate_summary(pcap)  [from pcap_summary.py]            │
│         └→ conv_tcp_apptainer(pcap)                          │
│            └→ run_tshark_apptainer(["-z", "conv,tcp"])       │
│               └→ subprocess(["apptainer", "exec", ...])      │
│                  └→ tshark gets conversations in container   │
│                     └→ Containerized conversation analysis   │
└──────────────────────────┬──────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│     Results Returned to Agent                                │
│    Combined web search + PCAP analysis                        │
└─────────────────────────────────────────────────────────────┘
```

## Step-by-Step Execution with Components

### 1️⃣ Agent Identifies Web Search Need
```python
# In main_agent.py
messages = [...]  # Build context with PCAP data
llm = init_llm(configurable.model)  # Get LLM (vLLM or OpenAI)
msg = llm_with_tools.invoke(messages)  # LLM processes

# LLM decides: "I need more info about CVE-2022-24706"
# Tool call: {"name": "web_quick_search", "args": {"query": "CVE-2022-24706"}}
```

### 2️⃣ Web Search Tool is Called
```python
# In tools.py
web_calls = [tc for tc in tool_calls if tc["name"] == "web_quick_search"]
if web_calls:
    first_web_call = web_calls[0]
    configurable = Configuration.from_runnable_config(config)
    llm = init_llm(configurable.model, timeout=100)  # ← Same LLM!
    
    # Example:
    # If MODEL="vllm/meta-llama/..." → local Llama 3 model
    # If MODEL="openai/gpt-4o" → OpenAI API
    
    (response, inCount, outCount) = web_quick_search_func(
        **first_web_call["args"],
        llm_model=llm,  # ← Passes configured LLM
        strategy="LLM_summary",
        context_window_size=configurable.context_window_size
    )
```

### 3️⃣ Web Search Execution
```python
# In src/browser/online_browser.py
def web_quick_search_func(query, llm_model, strategy="LLM_summary", **kwargs):
    """
    1. Perform Google Search (requires GOOGLE_API_KEY_1, GOOGLE_CSE_ID)
    2. Get results from web pages (uses BeautifulSoup)
    3. Summarize with LLM
    """
    
    # Step 1: Google Search
    search_results = google_search(query)  # External API call
    
    # Step 2: Fetch web pages
    web_content = fetch_web_pages(search_results)
    
    # Step 3: Summarize with LLM
    # ↓ If using vLLM
    #   └─ Local inference on your GPU/CPU
    #      └─ No external API calls for summarization
    #         └─ Private, fast, free
    # ↓ If using OpenAI
    #   └─ API call to openai.com
    #      └─ Results sent to OpenAI servers
    #         └─ API costs apply
    
    summary = llm_model.invoke(format_prompt(web_content))
    return summary
```

### 4️⃣ Agent Gets Web Search Summary
```python
# Web search returns summary like:
"""
CVE-2022-24706 is a critical vulnerability in SaltStack projects...
Impact: Remote code execution on affected systems...
Affected versions: Salt versions < 3001.8, < 3002.5, < 3003.1...
Mitigation: Update to patched versions...
"""
```

### 5️⃣ Agent Analyzes PCAP with Web Context
```python
# Agent now has:
# - Original PCAP data
# - Web search summary about the CVE
# - Agent decides to extract flows for deeper analysis

# Agent calls: "Extract flows from the PCAP to see attack patterns"

from multi_agent.main_agent.tools.pcap import generate_summary
summary = generate_summary(pcap_path)

# This internally calls:
# generate_summary(pcap_file)
#   └── conv_tcp_apptainer(pcap_file)
#       └── run_tshark_apptainer(pcap_file, [..., "conv,tcp"])
#           ├── Build command:
#           │   ["apptainer", "exec", "tshark.sif", 
#           │    "tshark", "-r", pcap_file, "-q", "-z", "conv,tcp"]
#           └── subprocess.run(command)
#               └── Apptainer Container
#                   └── tshark (inside container)
#                       └── Analyzes PCAP
#                           └── Returns conversation summary
```

### 6️⃣ Different Scenarios

#### Scenario A: vLLM (Local Mode)
```
Agent decides web search needed
    ↓
Initialize vLLM (local inference)
    ↓
Google Search (external API) → web results
    ↓
vLLM summarizes results (LOCAL - no API call!)
    ↓
Agent analyzes PCAP
    ↓
Extract flow: get_flow(pcap, stream)
    ├─ Apptainer tshark wrapper calls
    ├─ subprocess: apptainer exec tshark.sif tshark -q -z follow,tcp,...
    ├─ Container runs tshark
    └─ Flow extracted and returned

Result: 
- No LLM API calls (web search summary done locally on vLLM)
- PCAP analyzed in containerized tshark
- Completely private and fast
```

#### Scenario B: OpenAI (Remote API Mode)
```
Agent decides web search needed
    ↓
Initialize OpenAI API client
    ↓
Google Search (external API) → web results
    ↓
OpenAI API call for summarization
    │ (data sent to openai.com, costs $$$)
    └─ Summary received
    ↓
Agent analyzes PCAP
    ↓
Extract flow: get_flow(pcap, stream)
    ├─ Apptainer tshark wrapper calls
    ├─ subprocess: apptainer exec tshark.sif tshark -q -z follow,tcp,...
    ├─ Container runs tshark
    └─ Flow extracted and returned

Result:
- LLM API call made (OpenAI)
- PCAP analyzed in containerized tshark
- Web-based LLM, local network analysis
```

## Configuration Impact

### Environment Variables Used

```env
# LLM Choice
MODEL = vllm/meta-llama/Meta-Llama-3-8B-Instruct
# or
MODEL = openai/gpt-4o

# Web Search (always required if agent searches web)
GOOGLE_API_KEY_1 = xxx
GOOGLE_CSE_ID = xxx

# Apptainer tshark (always required for PCAP analysis)
TSHARK_CONTAINER_PATH = ./tshark.sif

# Embeddings
USE_LOCAL_EMBEDDINGS = true
EMBEDDING_MODEL = all-MiniLM-L6-v2
```

## Complete Data Flow Example

```
┌───────────────────────────────────────────────────────────────┐
│ USER INPUT                                                    │
│ "Analyze CVE-2022-24706 attack in this PCAP file"             │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 1: Agent Initializes                                     │
│ - Load PCAP: CVE-2022-24706.pcap                               │
│ - Initialize LLM: vLLM (Meta-Llama-3 local)                   │
│ - Parse configuration                                          │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 2: Analyze PCAP with tshark (Apptainer)                  │
│ $ apptainer exec tshark.sif tshark -r CVE-2022-24706.pcap     │
│   -q -z conv,tcp                                               │
│                                                               │
│ Returns: TCP conversation statistics                          │
│ ├─ 192.168.1.100:55432 → 10.0.0.50:8080                       │
│ ├─ 192.168.1.101:55433 → 10.0.0.50:8080                       │
│ └─ ...more conversations...                                   │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 3: Agent Reasoning                                       │
│ LLM (vLLM on local GPU):                                       │
│ "These look like exploitation attempts. I should:             │
│  1. Search web for CVE-2022-24706 details                     │
│  2. Extract the attack flows                                  │
│  3. Compare with known attack patterns"                       │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 4: Web Search Tool Called                                │
│ query = "CVE-2022-24706 exploitation details"                 │
│                                                               │
│ Google Search API → web results                               │
│ LLM (vLLM on GPU) summarizes:                                  │
│                                                               │
│ "CVE-2022-24706 is a critical RCE in SaltStack.              │
│ Attackers exploit unauthenticated API endpoint on port 8080.  │
│ Payloads typically send OS commands..."                       │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 5: Extract Attack Flows from PCAP                        │
│ $ apptainer exec tshark.sif tshark -r CVE-2022-24706.pcap     │
│   -q -z follow,tcp,ascii,0                                    │
│                                                               │
│ Returns: Full TCP stream 0                                    │
│ POST /run HTTP/1.1                                            │
│ Host: 10.0.0.50:8080                                          │
│ Content-Length: 156                                           │
│                                                               │
│ {"eauth": "", "token": "", "cmd": "cat /etc/passwd"}         │
│ ... more attack payload ...                                   │
│                                                               │
│ $ apptainer exec tshark.sif tshark -r CVE-2022-24706.pcap     │
│   -q -z follow,tcp,ascii,1                                    │
│ ... more flows ...                                            │
└──────────────────────────┬──────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│ STEP 6: Agent Synthesis                                       │
│ LLM (vLLM) combines information:                               │
│ - Web search knowledge: CVE-2022-24706 details                │
│ - PCAP flows: Actual attack payloads                          │
│                                                               │
│ Final Report:                                                  │
│ "CONFIRMED: CVE-2022-24706 exploitation detected              │
│ Source IPs: 192.168.1.100, 192.168.1.101                      │
│ Target: 10.0.0.50 (SaltStack service)                         │
│ Attack Type: RCE via unauthenticated API                      │
│ Payloads: OS command injection (cat /etc/passwd, etc.)        │
│ Severity: CRITICAL"                                           │
└────────────────────────────────────────────────────────────────┘
```

## Key Interactions

### LLM Integration
- **Model Selection**: `init_llm()` chooses vLLM or OpenAI
- **Web Search Summarization**: Same LLM used for all analyses
- **vLLM Advantage**: Local execution = private + fast
- **OpenAI Advantage**: Higher quality (but costs $$$)

### Apptainer tshark Integration
- **Automatic**: No code changes needed for web search
- **Containerized**: All PCAP analysis in container
- **Error Handling**: Graceful fallback with clear messages
- **Performance**: ~100-500ms overhead per tshark invocation

### Configuration Priority
1. Environment variable `TSHARK_CONTAINER_PATH`
2. Value from `.env` file
3. Default `tshark.sif` in current directory

## Summary

When web search is needed:
1. ✅ Agent uses configured LLM (vLLM local or OpenAI remote)
2. ✅ Performs Google Search (requires API keys)
3. ✅ Summarizes results with same LLM
4. ✅ Analyzes PCAP with Apptainer tshark (containerized)
5. ✅ Combines findings for comprehensive analysis

**Result**: Private, containerized, intelligent forensic analysis! 🔍🚀
