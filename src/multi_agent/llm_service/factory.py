"""Factory for initializing LLM models based on configuration."""

import os
from typing import Dict, Any, Optional
from langchain.chat_models import init_chat_model
from multi_agent.llm_service.vllm_wrapper import VLLMChatModel
from multi_agent.common.utils import split_model_and_provider


def init_llm(model_config: str, timeout: int = 200, **kwargs) -> Any:
    """
    Initialize LLM based on model configuration string.
    
    Args:
        model_config: Model configuration string in format:
            - "openai/gpt-4o" - uses OpenAI API
            - "vllm/meta-llama/Meta-Llama-3-8B-Instruct" - uses local vLLM
            - "vllm" - uses vLLM with default vllm_model from env
        timeout: Request timeout in seconds
        **kwargs: Additional arguments to pass to LLM
    
    Returns:
        Initialized LLM instance
    """
    if "/" in model_config:
        parts = model_config.split("/", 1)
        provider = parts[0]
        model = parts[1]
    else:
        provider = "vllm"
        model = os.getenv("VLLM_MODEL", "meta-llama/Meta-Llama-3-8B-Instruct")
    
    if provider.lower() == "vllm":
        return get_vllm_model(
            model=model,
            base_url=os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1"),
            timeout=timeout,
            **kwargs
        )
    else:
        # Use existing init_chat_model for OpenAI and other providers
        return init_chat_model(
            model=model,
            model_provider=provider,
            timeout=timeout,
            **kwargs
        )


def get_vllm_model(
    model: str = "meta-llama/Meta-Llama-3-8B-Instruct",
    base_url: str = "http://localhost:8000/v1",
    max_tokens: int = 1024,
    temperature: float = 0.7,
    top_p: float = 0.95,
    timeout: int = 200,
    **kwargs
) -> VLLMChatModel:
    """
    Get a vLLM model instance.
    
    Args:
        model: Model identifier (e.g., "meta-llama/Meta-Llama-3-8B-Instruct")
        base_url: vLLM server base URL
        max_tokens: Maximum tokens in response
        temperature: Sampling temperature
        top_p: Top-p probability
        timeout: Request timeout
        **kwargs: Additional keyword arguments
    
    Returns:
        VLLMChatModel instance
    """
    # Override with environment variables if set
    model = os.getenv("VLLM_MODEL", model)
    base_url = os.getenv("VLLM_BASE_URL", base_url)
    max_tokens = int(os.getenv("VLLM_MAX_TOKENS", max_tokens))
    timeout = int(os.getenv("VLLM_TIMEOUT", timeout))
    
    return VLLMChatModel(
        model=model,
        base_url=base_url,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p,
        timeout=timeout,
        **kwargs
    )


def is_vllm_available() -> bool:
    """Check if vLLM service is running."""
    import httpx
    
    base_url = os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1")
    try:
        with httpx.Client(timeout=2) as client:
            response = client.get(f"{base_url}/models")
            return response.status_code == 200
    except Exception:
        return False
