"""
Get TCP conversation statistics from a PCAP file via Apptainer tshark.

Executes the command: tshark -r <pcap_file> -q -z conv,tcp on the pcap file and returns the output.
It shows a table of IP conversations, with columns like:

    -Source IP ↔ Destination IP
    -Number of packets and bytes sent in each direction
    -Total packets and bytes
    -Duration of each conversation

This is useful for identifying the main endpoints communicating in a capture and the amount of data exchanged.

Requires Apptainer and tshark.sif container to be properly configured.
"""

import logging
from multi_agent.common.tshark_apptainer import (
    conv_tcp_apptainer, 
    ApptainerTsharkError
)

logger = logging.getLogger(__name__)

def generate_summary(pcap_file: str) -> str:
    """
    Get TCP conversation summary from a PCAP file via Apptainer tshark.
    
    Equivalent to: tshark -r <pcap_file> -q -z conv,tcp
    
    Args:
        pcap_file: the path to the pcap file.
    
    Returns:
        The output of the command.
    
    Raises:
        ApptainerTsharkError: If Apptainer is not available or tshark execution fails.
    """
    try:
        out = conv_tcp_apptainer(pcap_file)
    except ApptainerTsharkError as e:
        logger.error(f"Failed to generate PCAP summary: {e}")
        raise
    
    if len(out.strip()) == 0:
        out = "No output found for the given command."
    return out


__all__ = ["generate_summary"]