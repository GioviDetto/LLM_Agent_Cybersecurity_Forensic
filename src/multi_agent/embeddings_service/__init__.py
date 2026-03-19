"""Embeddings service module for local and remote embeddings."""

import os
from typing import Optional
from langchain.embeddings import init_embeddings
from langchain_community.embeddings import HuggingFaceEmbeddings


def get_embeddings(use_local: Optional[bool] = None, model_name: Optional[str] = None):
    """
    Get embeddings instance based on configuration.
    
    Args:
        use_local: Whether to use local embeddings. If None, reads from USE_LOCAL_EMBEDDINGS env var.
        model_name: Model name to use. If None, reads from EMBEDDING_MODEL env var.
    
    Returns:
        Embeddings instance (either HuggingFaceEmbeddings or OpenAI via init_embeddings)
    """
    if use_local is None:
        use_local = os.getenv("USE_LOCAL_EMBEDDINGS", "false").lower() == "true"
    
    if model_name is None:
        model_name = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
    
    if use_local:
        return HuggingFaceEmbeddings(model_name=model_name)
    else:
        # Use OpenAI embeddings
        return init_embeddings("openai:text-embedding-3-small")
