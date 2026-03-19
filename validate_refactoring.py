#!/usr/bin/env python3
"""
Validation script to check if the vLLM refactoring is complete and working.
Run this to verify all components are in place.
"""

import sys
import os
from pathlib import Path

def check_file_exists(path: str, description: str) -> bool:
    """Check if a file exists."""
    exists = Path(path).exists()
    status = "✓" if exists else "✗"
    print(f"  {status} {description}: {path}")
    return exists

def check_import(module_path: str, description: str) -> bool:
    """Check if a module can be imported."""
    try:
        parts = module_path.split(".")
        exec(f"from {'.'.join(parts[:-1])} import {parts[-1]}")
        print(f"  ✓ {description}: {module_path}")
        return True
    except ImportError as e:
        print(f"  ✗ {description}: {module_path} - {e}")
        return False

def check_environment_variable(var_name: str, required: bool = False) -> bool:
    """Check if environment variable is set."""
    value = os.getenv(var_name)
    if value:
        print(f"  ✓ {var_name} = {value}")
        return True
    else:
        status = "✗" if required else "⚠"
        print(f"  {status} {var_name} not set{' (required)' if required else ' (optional)'}")
        return not required

def main():
    print("\n" + "="*60)
    print("vLLM Integration Validation")
    print("="*60 + "\n")
    
    all_good = True
    base_dir = Path(__file__).parent
    src_dir = base_dir / "src"
    
    # Check file structure
    print("1. Checking File Structure")
    print("-" * 60)
    checks = [
        (str(base_dir / "VLLM_INTEGRATION.md"), "vLLM Integration Guide"),
        (str(base_dir / "QUICKSTART_VLLM.md"), "Quick Start Guide"),
        (str(base_dir / "MIGRATION_GUIDE.md"), "Migration Guide"),
        (str(base_dir / "REFACTORING_COMPLETE.md"), "Refactoring Summary"),
        (str(src_dir / "configuration.py"), "Extended Configuration"),
        (str(src_dir / "multi_agent" / "llm_service" / "__init__.py"), "LLM Service Package"),
        (str(src_dir / "multi_agent" / "llm_service" / "factory.py"), "LLM Factory"),
        (str(src_dir / "multi_agent" / "llm_service" / "vllm_wrapper.py"), "vLLM Wrapper"),
        (str(src_dir / "multi_agent" / "embeddings_service" / "__init__.py"), "Embeddings Service"),
        (str(base_dir / "scripts" / "start_vllm.sh"), "vLLM Start Script"),
        (str(base_dir / "scripts" / "start_vllm_docker.sh"), "vLLM Docker Script"),
        (str(base_dir / "scripts" / "run_with_vllm.sh"), "Experiment Runner"),
        (str(src_dir / ".env.example"), "Environment Template"),
    ]
    
    for path, desc in checks:
        if not check_file_exists(path, desc):
            all_good = False
    
    # Check Python packages
    print("\n2. Checking Python Packages")
    print("-" * 60)
    packages = [
        ("multi_agent.llm_service.init_llm", "LLM Factory Function"),
        ("multi_agent.llm_service.VLLMChatModel", "vLLM Wrapper Class"),
        ("multi_agent.embeddings_service.get_embeddings", "Embeddings Factory"),
    ]
    
    for package, desc in packages:
        if not check_import(package, desc):
            all_good = False
    
    # Check updated files contain new imports
    print("\n3. Checking Updated Files")
    print("-" * 60)
    
    updated_files = {
        str(src_dir / "multi_agent" / "main_agent" / "nodes" / "main_agent.py"): "init_llm",
        str(src_dir / "multi_agent" / "log_reporter" / "log_reporter.py"): "init_llm",
        str(src_dir / "multi_agent" / "pcap_flow_analyzer" / "pcap_flow_analyzer.py"): "init_llm",
        str(src_dir / "multi_agent" / "main_agent" / "nodes" / "tools.py"): "init_llm",
        str(src_dir / "run_agent.py"): "get_embeddings",
        str(src_dir / "run_agent_web_events.py"): "get_embeddings",
    }
    
    for file_path, expected_import in updated_files.items():
        if Path(file_path).exists():
            with open(file_path) as f:
                content = f.read()
                if expected_import in content:
                    print(f"  ✓ {Path(file_path).name} contains '{expected_import}'")
                else:
                    print(f"  ✗ {Path(file_path).name} missing '{expected_import}'")
                    all_good = False
        else:
            print(f"  ✗ {file_path} not found")
            all_good = False
    
    # Check configuration
    print("\n4. Checking Configuration Extensions")
    print("-" * 60)
    
    config_file = src_dir / "configuration.py"
    if config_file.exists():
        with open(config_file) as f:
            content = f.read()
            fields = [
                ("vllm_model", "vLLM Model"),
                ("vllm_base_url", "vLLM Base URL"),
                ("use_local_embeddings", "Local Embeddings Toggle"),
                ("embedding_model", "Embedding Model"),
            ]
            for field, desc in fields:
                if field in content:
                    print(f"  ✓ {desc}: {field}")
                else:
                    print(f"  ✗ {desc}: {field} not found")
                    all_good = False
    
    # Check requirements
    print("\n5. Checking Dependencies")
    print("-" * 60)
    
    req_file = base_dir / "requirements.txt"
    if req_file.exists():
        with open(req_file) as f:
            content = f.read()
            deps = ["vllm", "sentence-transformers", "transformers"]
            for dep in deps:
                if dep in content.lower():
                    print(f"  ✓ {dep} in requirements.txt")
                else:
                    print(f"  ⚠ {dep} not found in requirements.txt")
    
    # Check environment setup
    print("\n6. Checking Environment Variables")
    print("-" * 60)
    
    required_env = []
    optional_env = [
        "MODEL",
        "VLLM_MODEL",
        "VLLM_BASE_URL",
        "USE_LOCAL_EMBEDDINGS",
        "EMBEDDING_MODEL",
    ]
    
    for var in optional_env:
        check_environment_variable(var, required=False)
    
    # Summary
    print("\n" + "="*60)
    if all_good:
        print("✓ All checks passed! vLLM integration is complete.")
        print("\nNext steps:")
        print("  1. Read: QUICKSTART_VLLM.md")
        print("  2. Copy: cp src/.env.example src/.env")
        print("  3. Edit: nano src/.env")
        print("  4. Start vLLM: bash scripts/start_vllm.sh")
        print("  5. Run: cd src && python run_agent.py")
        return 0
    else:
        print("✗ Some checks failed. Please review the output above.")
        print("\nTroubleshooting:")
        print("  - Ensure you're running from the repository root")
        print("  - Check file permissions: chmod +x scripts/*.sh")
        print("  - Install packages: pip install -r requirements.txt")
        return 1

if __name__ == "__main__":
    sys.exit(main())
