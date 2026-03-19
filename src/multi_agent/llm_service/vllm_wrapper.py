"""vLLM wrapper for LangChain compatibility."""

import os
from typing import Any, Optional, List, Dict, Union
from langchain_core.language_models.chat_model import BaseChatModel
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.outputs.chat_generation import ChatGeneration
from langchain_core.outputs.llm_result import LLMResult
import httpx
import time


class VLLMChatModel(BaseChatModel):
    """LangChain wrapper for vLLM OpenAI-compatible endpoint."""
    
    model: str = "meta-llama/Meta-Llama-3-8B-Instruct"
    base_url: str = "http://localhost:8000/v1"
    max_tokens: int = 1024
    temperature: float = 0.7
    top_p: float = 0.95
    timeout: int = 200
    
    @property
    def _llm_type(self) -> str:
        return "vllm_chat"
    
    def _generate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager = None,
        **kwargs: Any,
    ) -> LLMResult:
        """Generate text from messages using vLLM."""
        # Convert messages to OpenAI format
        formatted_messages = []
        for msg in messages:
            if isinstance(msg, HumanMessage):
                role = "user"
            elif isinstance(msg, AIMessage):
                role = "assistant"
            elif isinstance(msg, SystemMessage):
                role = "system"
            else:
                role = "user"
            
            formatted_messages.append({
                "role": role,
                "content": msg.content
            })
        
        request_payload = {
            "model": self.model,
            "messages": formatted_messages,
            "max_tokens": kwargs.get("max_tokens", self.max_tokens),
            "temperature": kwargs.get("temperature", self.temperature),
            "top_p": kwargs.get("top_p", self.top_p),
        }
        
        if stop:
            request_payload["stop"] = stop
        
        # Make request to vLLM
        client = httpx.Client(timeout=self.timeout)
        try:
            response = client.post(
                f"{self.base_url}/chat/completions",
                json=request_payload
            )
            response.raise_for_status()
            result = response.json()
            
            # Extract response
            content = result["choices"][0]["message"]["content"]
            finish_reason = result["choices"][0]["finish_reason"]
            
            # Count tokens (estimate)
            input_tokens = sum(len(msg["content"].split()) for msg in formatted_messages)
            output_tokens = len(content.split())
            
            return LLMResult(
                generations=[
                    [
                        ChatGeneration(
                            message=AIMessage(content=content),
                            generation_info={
                                "finish_reason": finish_reason,
                                "model": self.model
                            }
                        )
                    ]
                ],
                llm_output={
                    "token_usage": {
                        "prompt_tokens": input_tokens,
                        "completion_tokens": output_tokens,
                        "total_tokens": input_tokens + output_tokens
                    }
                }
            )
        finally:
            client.close()
    
    async def _agenerate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager = None,
        **kwargs: Any,
    ) -> LLMResult:
        """Async generate text from messages using vLLM."""
        # Format same as sync version
        formatted_messages = []
        for msg in messages:
            if isinstance(msg, HumanMessage):
                role = "user"
            elif isinstance(msg, AIMessage):
                role = "assistant"
            elif isinstance(msg, SystemMessage):
                role = "system"
            else:
                role = "user"
            
            formatted_messages.append({
                "role": role,
                "content": msg.content
            })
        
        request_payload = {
            "model": self.model,
            "messages": formatted_messages,
            "max_tokens": kwargs.get("max_tokens", self.max_tokens),
            "temperature": kwargs.get("temperature", self.temperature),
            "top_p": kwargs.get("top_p", self.top_p),
        }
        
        if stop:
            request_payload["stop"] = stop
        
        # Make async request
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                json=request_payload
            )
            response.raise_for_status()
            result = response.json()
            
            content = result["choices"][0]["message"]["content"]
            finish_reason = result["choices"][0]["finish_reason"]
            
            input_tokens = sum(len(msg["content"].split()) for msg in formatted_messages)
            output_tokens = len(content.split())
            
            return LLMResult(
                generations=[
                    [
                        ChatGeneration(
                            message=AIMessage(content=content),
                            generation_info={
                                "finish_reason": finish_reason,
                                "model": self.model
                            }
                        )
                    ]
                ],
                llm_output={
                    "token_usage": {
                        "prompt_tokens": input_tokens,
                        "completion_tokens": output_tokens,
                        "total_tokens": input_tokens + output_tokens
                    }
                }
            )
