"""
Apptainer tshark wrapper for running tshark commands within a container.

This module provides a unified interface to run tshark commands via Apptainer.
Requires Apptainer to be installed and a tshark.sif container image.

On HPC clusters with module systems, ensure Apptainer is loaded:
    module load apptainer
    
Or set the PATH:
    export PATH=/path/to/apptainer/bin:$PATH
"""

import subprocess
import os
import shutil
from typing import Optional, List


class ApptainerTsharkError(Exception):
    """Raised when tshark execution via Apptainer fails."""
    pass


def _is_apptainer_available() -> bool:
    """Check if Apptainer is installed and accessible in PATH."""
    return shutil.which("apptainer") is not None


def get_tshark_container_path() -> str:
    """
    Get the path to the tshark Apptainer container image.
    
    Reads from environment variable TSHARK_CONTAINER_PATH or defaults to 'tshark.sif'
    in the current directory.
    
    Returns:
        Path to the tshark container image
    """
    return os.getenv("TSHARK_CONTAINER_PATH", "tshark.sif")


def get_available_tshark_backend() -> str:
    """
    Determine if Apptainer tshark backend is available.
    
    Returns:
        "apptainer" if Apptainer + container available
        "none" if Apptainer or container not available
    """
    if _is_apptainer_available():
        container_path = get_tshark_container_path()
        if os.path.exists(container_path):
            return "apptainer"
    
    return "none"


def run_tshark_apptainer(
    pcap_file: str, 
    tshark_args: List[str],
    container_path: Optional[str] = None
) -> str:
    """
    Run tshark command via Apptainer container.
    
    Uses --fakeroot to handle UID mapping and --writable-tmpfs to avoid
    SIF-to-sandbox conversion issues that cause user account lookup failures.
    
    Args:
        pcap_file: Path to the PCAP file to analyze (on host filesystem)
        tshark_args: List of tshark arguments (excluding the 'tshark' command itself)
                    Example: ['-r', 'file.pcap', '-T', 'fields', '-e', 'tcp.stream']
        container_path: Path to tshark.sif container (defaults to TSHARK_CONTAINER_PATH env var)
    
    Returns:
        stdout from tshark execution
    
    Raises:
        ApptainerTsharkError: If Apptainer is not available or tshark execution fails
    
    Example:
        # Run: tshark -r file.pcap -T fields -e tcp.stream
        output = run_tshark_apptainer(
            'file.pcap',
            ['-r', 'file.pcap', '-T', 'fields', '-e', 'tcp.stream']
        )
    """
    # Check if Apptainer is available
    if not _is_apptainer_available():
        raise ApptainerTsharkError(
            "Apptainer is not available in PATH.\n\n"
            "On HPC clusters with module systems, load Apptainer with:\n"
            "    module load apptainer\n\n"
            "Or ensure Apptainer is installed:\n"
            "    Ubuntu/Debian: sudo apt-get install -y apptainer\n"
            "    RHEL/CentOS: sudo dnf install -y apptainer\n\n"
            "If Apptainer is installed but not in PATH, set it:\n"
            "    export PATH=/path/to/apptainer/bin:$PATH\n\n"
            "For more info: https://apptainer.org/docs/admin/main/installation.html"
        )
    
    if container_path is None:
        container_path = get_tshark_container_path()
    
    # Verify container exists
    if not os.path.exists(container_path):
        raise ApptainerTsharkError(
            f"Tshark container not found at: {container_path}\n\n"
            f"Create the container with:\n"
            f"    bash scripts/setup_apptainer_tshark.sh\n\n"
            f"Or set TSHARK_CONTAINER_PATH to the correct location:\n"
            f"    export TSHARK_CONTAINER_PATH=/path/to/tshark.sif"
        )
    
    # Build the apptainer command with flags for HPC compatibility
    # --fakeroot: Maps host UID/GID through fakeroot
    # --writable-tmpfs: Use tmpfs for writes instead of converting SIF to sandbox
    #                   This avoids user account lookup failures during sandbox creation
    container_env = os.getenv("APPTAINER_EXTRA_FLAGS", "")
    base_flags = ["--fakeroot", "--writable-tmpfs"]
    
    command = ["apptainer", "exec"] + base_flags
    if container_env:
        command.extend(container_env.split())
    command.extend([container_path, "tshark"])  # tshark command within container
    
    # Add tshark arguments
    command.extend(tshark_args)
    
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False  # Don't raise on non-zero exit, we'll handle it
        )
        
        if result.returncode != 0:
            error_msg = result.stderr if result.stderr else result.stdout
            raise ApptainerTsharkError(
                f"Tshark command failed with exit code {result.returncode}:\n{error_msg}"
            )
        
        return result.stdout
        
    except FileNotFoundError:
        raise ApptainerTsharkError(
            "Apptainer executable not found. Please ensure Apptainer is installed and in PATH."
        )
    except Exception as e:
        raise ApptainerTsharkError(f"Failed to run tshark via Apptainer: {str(e)}")


def count_flows_apptainer(pcap_file: str) -> int:
    """
    Count the number of distinct TCP flows in a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -T fields -e tcp.stream
    
    Args:
        pcap_file: Path to the PCAP file
    
    Returns:
        Number of distinct TCP flows
    """
    try:
        output = run_tshark_apptainer(
            pcap_file,
            ['-r', pcap_file, '-T', 'fields', '-e', 'tcp.stream']
        )
        
        # Split the output into lines and filter out empty lines
        streams = [line for line in output.splitlines() if line.strip()]
        
        # Use a set to get unique streams
        unique_streams = set(streams)
        
        return len(unique_streams)
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to count flows: {str(e)}")


def get_flow_apptainer(pcap_file: str, stream: int) -> str:
    """
    Extract a TCP flow from a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -q -z follow,tcp,ascii,<stream>
    
    Args:
        pcap_file: Path to the PCAP file
        stream: TCP stream number to extract
    
    Returns:
        Flow data as ASCII text
    """
    try:
        output = run_tshark_apptainer(
            pcap_file,
            ['-r', pcap_file, '-q', '-z', f'follow,tcp,ascii,{stream}']
        )
        return output
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get flow {stream}: {str(e)}")


def get_flow_http2_apptainer(
    pcap_file: str, 
    stream: int, 
    subflow: int = 0,
    keylog_file: Optional[str] = None
) -> str:
    """
    Extract an HTTP/2 subflow from a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -q -z follow,http2,ascii,<stream>,<subflow> -o tls.keylog_file:<keyfile>
    
    Args:
        pcap_file: Path to the PCAP file
        stream: TCP stream number
        subflow: HTTP/2 subflow index (default: 0)
        keylog_file: Optional path to TLS keylog file
    
    Returns:
        HTTP/2 flow data as ASCII text
    """
    try:
        args = ['-r', pcap_file, '-q', '-z', f'follow,http2,ascii,{stream},{subflow}']
        
        # Add keylog file if provided
        if keylog_file:
            if not os.path.exists(keylog_file):
                # Warn but don't fail - keylog file might not exist
                pass
            args.extend(['-o', f'tls.keylog_file:{keylog_file}'])
        
        output = run_tshark_apptainer(pcap_file, args)
        return output
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get HTTP/2 flow {stream},{subflow}: {str(e)}")


def get_flow_http_apptainer(
    pcap_file: str,
    stream: int,
    keylog_file: Optional[str] = None
) -> str:
    """
    Extract an HTTP flow from a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -q -z follow,http,ascii,<stream> -o tls.keylog_file:<keyfile>
    
    Args:
        pcap_file: Path to the PCAP file
        stream: TCP stream number
        keylog_file: Optional path to TLS keylog file
    
    Returns:
        HTTP flow data as ASCII text
    """
    try:
        args = ['-r', pcap_file, '-q', '-z', f'follow,http,ascii,{stream}']
        
        # Add keylog file if provided
        if keylog_file:
            if not os.path.exists(keylog_file):
                # Warn but don't fail - keylog file might not exist
                pass
            args.extend(['-o', f'tls.keylog_file:{keylog_file}'])
        
        output = run_tshark_apptainer(pcap_file, args)
        return output
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get HTTP flow {stream}: {str(e)}")


def conv_tcp_apptainer(pcap_file: str) -> str:
    """
    Get TCP conversation statistics from a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -q -z conv,tcp
    
    Args:
        pcap_file: Path to the PCAP file
    
    Returns:
        Conversation statistics as text
    """
    try:
        output = run_tshark_apptainer(
            pcap_file,
            ['-r', pcap_file, '-q', '-z', 'conv,tcp']
        )
        return output
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get TCP conversations: {str(e)}")


def get_tls_streams_apptainer(pcap_file: str) -> set:
    """
    Get the TCP streams that contain TLS traffic from a PCAP file.
    
    Equivalent to: tshark -r <pcap_file> -Y tls -T fields -e tcp.stream
    
    Args:
        pcap_file: Path to the PCAP file
    
    Returns:
        Set of unique TCP stream numbers containing TLS traffic
    
    Raises:
        ApptainerTsharkError: If tshark execution fails
    """
    try:
        output = run_tshark_apptainer(
            pcap_file,
            ['-r', pcap_file, '-Y', 'tls', '-T', 'fields', '-e', 'tcp.stream']
        )
        # Extract unique stream numbers
        streams = set(int(line.strip()) for line in output.splitlines() if line.strip().isdigit())
        return streams
    except ApptainerTsharkError as e:
        raise ApptainerTsharkError(f"Failed to get TLS streams: {str(e)}")


__all__ = [
    "ApptainerTsharkError",
    "run_tshark_apptainer",
    "count_flows_apptainer",
    "get_flow_apptainer",
    "get_flow_http2_apptainer",
    "get_flow_http_apptainer",
    "conv_tcp_apptainer",
    "get_tls_streams_apptainer",
    "get_tshark_container_path",
    "get_available_tshark_backend",
]
