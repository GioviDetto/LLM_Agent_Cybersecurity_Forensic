"""Utility functions used in our graph."""
import tiktoken
import subprocess
from typing import Optional
from multi_agent.common.tshark_apptainer import (
    count_flows_apptainer,
    get_flow_apptainer,
    get_flow_http2_apptainer,
    get_flow_http_apptainer,
    ApptainerTsharkError,
)

# This encoding is used for token counting by most of the providers
encoding = tiktoken.get_encoding("cl100k_base")

def split_model_and_provider(full_name: str) -> dict:
    
    if "/" in full_name:
        if len(full_name.split("/")) > 2:
            provider,model = full_name.split("/")[0], "/".join(full_name.split("/")[1:])  
        else: 
            provider,model = full_name.split("/", maxsplit=1)
    else:
        # Default fallback
        provider = "openai"
        model = "gpt-4o"

    return {"model": model,"model_provider":provider}


def count_tokens(message) -> int:
    """
    Count tokens in a message (BaseMessage), memory (SearchItem), or raw string.
    """
    num_tokens = 4  # overhead base

    if hasattr(message, "content"):  # BaseMessage
        text = message.content
    elif hasattr(message, "value"):  # SearchItem (memoria semantica)
        text = message.value
    elif isinstance(message, str):
        text = message
    else:
        raise TypeError(f"Unsupported type for token counting: {type(message)}")

    num_tokens += len(encoding.encode(text))
    num_tokens += 2  # priming
    return num_tokens

def truncate_flow(flow_text: str, tokens_budget: int,context_window: int=128000)-> str:
    #If the token budget overcome the context window, we set it to 90% of the context window
    if tokens_budget > context_window:
        tokens_budget = context_window*0.90
    half_budget = tokens_budget // 2
    tokens = encoding.encode(flow_text)
    
    # Safety: can't take more tokens than available
    first_half = tokens[:half_budget]
    second_half = tokens[-half_budget:]
    
    # Decode token sequences back to text
    part1 = encoding.decode(first_half)
    part2 = encoding.decode(second_half)
    
    return "Beginning of the tcp flow: \n" + part1 + "\n--- final part of the flow ---\n" + part2

def count_flows(pcap_file: str) -> int:
    """
    Get the number of distinct TCP flows in a PCAP file.
    Runs via Apptainer tshark container.
    Returns the number of distinct tcp flows in the pcap file.
    """
    try:
        return count_flows_apptainer(pcap_file)
    except ApptainerTsharkError as e:
        print(f"[ERROR] Failed to count flows: {e}")
        return 0


def get_flow(pcap_file: str, stream: int) -> str:
    """
    Extract a TCP flow from a PCAP file.
    The flow is extracted using the follow TCP command via Apptainer tshark.
    Returns the flow data as text.
    """
    try:
        return get_flow_apptainer(pcap_file, stream)
    except ApptainerTsharkError as e:
        print(f"[ERROR] Failed to get flow {stream}: {e}")
        return "" 

def is_empty_follow_block(text: str) -> bool:
    return len(text.strip().split('\n')) <= 6

def concatenate_subflows(pcap_file:str,stream:int)->Optional[str]:
    """Concatenate HTTP/2 subflows from a PCAP file via Apptainer tshark."""
    subflows = []
    key_file_path = '/'.join(pcap_file.split("/")[:-1]) + "/sslkeylogfile.txt" 
    i = 0
    while True:
        try:
            raw_text = get_flow_http2_apptainer(
                pcap_file, 
                stream, 
                subflow=i,
                keylog_file=key_file_path if key_file_path else None
            ).strip()
        except ApptainerTsharkError as e:
            print(f"[ERROR] Failed to get HTTP/2 subflow {stream},{i}: {e}")
            break

        if is_empty_follow_block(raw_text):
            break
        i+=1
        subflows.append(raw_text + '\n')

    if len(subflows) == 0:
        return None    
    return ''.join(subflows)
        

def get_flow_web_browsing(pcap_file: str, stream: int) -> Optional[str]:
    """
    Extract a web browsing HTTP flow from a PCAP file.
    The flow is extracted using the follow HTTP command via Apptainer tshark.
    Falls back to HTTP/2 subflows if main flow is empty.
    """
    
    key_file_path = '/'.join(pcap_file.split("/")[:-1]) + "/sslkeylogfile.txt"  

    try:
        raw_text = get_flow_http_apptainer(
            pcap_file,
            stream,
            keylog_file=key_file_path if key_file_path else None
        )
    except ApptainerTsharkError as e:
        print(f"[ERROR] Failed to get HTTP flow {stream}: {e}")
        return None

    if is_empty_follow_block(raw_text):
        subflows_text = concatenate_subflows(pcap_file, stream)
        if not subflows_text:
            return None
        else:
            return subflows_text
    return raw_text 