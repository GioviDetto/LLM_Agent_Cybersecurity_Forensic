"""LLM service module for handling local vLLM and remote API models."""

from .vllm_wrapper import VLLMChatModel
from .factory import get_vllm_model, init_llm

__all__ = ["VLLMChatModel", "get_vllm_model", "init_llm"]
