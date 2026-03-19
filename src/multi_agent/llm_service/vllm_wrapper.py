"""vLLM wrapper for direct local model execution."""

import os
from typing import Any, Optional, List
from langchain_core.language_models import BaseChatModel
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.outputs import ChatGeneration, LLMResult

try:
    from vllm import LLM, SamplingParams
except ImportError:
    raise ImportError("vLLM is not installed. Install with: pip install vllm")


class VLLMChatModel(BaseChatModel):
    """LangChain wrapper for direct vLLM model execution."""
    
    model: str = "meta-llama/Meta-Llama-3-8B-Instruct"
    max_tokens: int = 1024
    temperature: float = 0.7
    top_p: float = 0.95
    gpu_memory_utilization: float = 0.9
    _vllm_model: Optional[LLM] = None
    
    def __init__(self, **data):
        """Initialize VLLMChatModel (lazy load model on first use)."""
        super().__init__(**data)
    
    def _load_model(self):
        """Load vLLM model on first use."""
        if self._vllm_model is None:
            # Load model with optimized settings for local use
            self._vllm_model = LLM(
                model=self.model,
                gpu_memory_utilization=self.gpu_memory_utilization,
                trust_remote_code=True,
                dtype="auto"
            )
            print(f"✓ Loaded vLLM model: {self.model}")
    
    @property
    def _llm_type(self) -> str:
        return "vllm"
    
    def _get_message_role(self, msg: BaseMessage) -> str:
        """Get role from message type."""
        role_map = {
            HumanMessage: "user",
            AIMessage: "assistant",
            SystemMessage: "system"
        }
        return role_map.get(type(msg), "user")
    
    def _generate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager = None,
        **kwargs: Any,
    ) -> LLMResult:
        """Generate text from messages using vLLM directly."""
        # Lazy load model on first inference
        if self._vllm_model is None:
            self._load_model()
        
        # Convert messages to chat format
        formatted_messages = [
            {
                "role": self._get_message_role(msg),
                "content": msg.content
            }
            for msg in messages
        ]
        
        # Prepare sampling parameters
        sampling_params = SamplingParams(
            temperature=kwargs.get("temperature", self.temperature),
            top_p=kwargs.get("top_p", self.top_p),
            max_tokens=kwargs.get("max_tokens", self.max_tokens),
            stop=stop
        )
        
        # Format as prompt string for the model
        # vLLM's generate() expects list of prompts
        prompt = self._format_messages_to_prompt(formatted_messages)
        
        # Generate using vLLM
        outputs = self._vllm_model.generate([prompt], sampling_params)
        output = outputs[0]
        
        # Extract generated text
        generated = output.outputs[0]
        content = generated.text.strip()
        finish_reason = generated.finish_reason
        
        # Estimate token counts (word-based approximation)
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
    
    async def _agenerate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager = None,
        **kwargs: Any,
    ) -> LLMResult:
        """Async generate text from messages using vLLM."""
        # For now, run sync version in async context
        # vLLM doesn't have native async API, but this is acceptable for most use cases
        return self._generate(messages, stop, run_manager, **kwargs)
    
    @staticmethod
    def _format_messages_to_prompt(messages: List[dict]) -> str:
        """Format messages into a chat prompt string."""
        # Standard chat format for models like Llama
        prompt = ""
        for msg in messages:
            role = msg["role"]
            content = msg["content"]
            
            if role == "system":
                prompt += f"<s>[INST] <<SYS>>\n{content}\n<</SYS>>\n\n"
            elif role == "user":
                prompt += f"{content} [/INST]"
            elif role == "assistant":
                prompt += f" {content}\n</s><s>[INST] "
        
        # Ensure prompt ends properly for generation
        if not prompt.endswith("[/INST]"):
            prompt += " [/INST]"
        
        return prompt
    
    def bind_tools(self, tools: List[Any], **kwargs: Any) -> "VLLMChatModel":
        """
        Bind tools to the model.
        
        Note: vLLM does not natively support function calling like OpenAI.
        This method accepts tools for compatibility with LangChain agents
        but doesn't modify model behavior. Tool use is handled by the agent framework.
        
        Args:
            tools: List of tools to bind
            **kwargs: Additional arguments (ignored)
        
        Returns:
            Self for method chaining
        """
        # vLLM doesn't support native tool calling, but we accept tools
        # for compatibility with LangChain agent patterns
        return self
    
    def __del__(self):
        """Clean up vLLM resources on model deletion."""
        if self._vllm_model is not None:
            # Explicitly free GPU memory
            del self._vllm_model
            self._vllm_model = None
