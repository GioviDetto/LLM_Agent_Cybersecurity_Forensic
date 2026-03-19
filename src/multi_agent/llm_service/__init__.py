"""LLM service module for handling local vLLM and remote API models."""

from .vllm_wrapper import VLLMChatModel
from .factory import get_llm_model, init_llm

__all__ = ["VLLMChatModel", "get_llm_model", "init_llm"]
