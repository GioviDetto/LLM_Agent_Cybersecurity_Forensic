"""Embeddings service module for local and remote embeddings."""

import os
from typing import Optional, Union
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_openai import OpenAIEmbeddings


def get_embeddings(
    use_local: Optional[bool] = None,
    model_name: Optional[str] = None
) -> Union[HuggingFaceEmbeddings, OpenAIEmbeddings]:
    """
    Get embeddings instance based on configuration.
    
    Args:
        use_local: Whether to use local embeddings. If None, reads USE_LOCAL_EMBEDDINGS env var.
        model_name: Model name to use. If None, reads EMBEDDING_MODEL env var.
    
    Returns:
        HuggingFaceEmbeddings for local mode, OpenAIEmbeddings for remote mode.
    """
    use_local = use_local if use_local is not None else \
        os.getenv("USE_LOCAL_EMBEDDINGS", "false").lower() == "true"
    
    model_name = model_name or os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
    
    if use_local:
        return HuggingFaceEmbeddings(model_name=model_name)
    else:
        return OpenAIEmbeddings(model="text-embedding-3-small")
