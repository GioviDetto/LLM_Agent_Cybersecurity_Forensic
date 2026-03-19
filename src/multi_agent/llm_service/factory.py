"""Factory for initializing LLM models based on configuration."""

import os
from typing import Any
from langchain.chat_models import init_chat_model
from multi_agent.llm_service.vllm_wrapper import VLLMChatModel


def init_llm(model_config: str, timeout: int = 200, **kwargs) -> Any:
    """
    Initialize LLM based on model configuration string.
    
    Args:
        model_config: Model configuration string in format:
            - "openai/gpt-4o" - uses OpenAI API
            - "vllm/meta-llama/Meta-Llama-3-8B-Instruct" - uses local vLLM
            - "vllm" - uses vLLM with default model from env
        timeout: Request timeout in seconds (only for OpenAI)
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
        return get_vllm_model(model=model, **kwargs)
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
    max_tokens: int = 1024,
    temperature: float = 0.7,
    top_p: float = 0.95,
    gpu_memory_utilization: float = 0.9,
    **kwargs
) -> VLLMChatModel:
    """
    Get a vLLM model instance for direct local execution.
    
    Args:
        model: Model identifier (e.g., "meta-llama/Meta-Llama-3-8B-Instruct")
        max_tokens: Maximum tokens in response
        temperature: Sampling temperature
        top_p: Top-p probability
        gpu_memory_utilization: GPU memory fraction to use (0-1)
        **kwargs: Additional keyword arguments
    
    Returns:
        VLLMChatModel instance (model loaded on first use)
    """
    # Override with environment variables if set
    model = os.getenv("VLLM_MODEL", model)
    max_tokens = int(os.getenv("VLLM_MAX_TOKENS", max_tokens))
    gpu_memory_utilization = float(os.getenv("VLLM_GPU_MEMORY", gpu_memory_utilization))
    
    return VLLMChatModel(
        model=model,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p,
        gpu_memory_utilization=gpu_memory_utilization,
        **kwargs
    )
