"""
Extract TLS flows from a PCAP file via Apptainer tshark.

Executes: tshark -r file.pcap -Y tls -T fields -e tcp.stream
Removes duplicates and returns a set of TCP streams that contain TLS traffic.
"""
from typing import Set
from multi_agent.common.tshark_apptainer import get_tls_streams_apptainer, ApptainerTsharkError

def get_tls_streams(pcap_file: str) -> Set[int]:
    """
    Get the TCP streams that contain TLS traffic from a pcap file via Apptainer.

    Args:
        pcap_file (str): The path to the pcap file.

    Returns:
        Set[int]: A set of TCP stream numbers that contain TLS traffic.
    
    Raises:
        ApptainerTsharkError: If tshark execution fails.
    """
    try:
        return get_tls_streams_apptainer(pcap_file)
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get TLS streams from {pcap_file}: {str(e)}")