#!/usr/bin/env python
"""Test script for tiktoken integration with PowerShell MCP"""

import sys
import os
import tiktoken

def count_tokens(text, model='gpt-4'):
    """Count tokens for given text using specified model encoding"""
    try:
        enc = tiktoken.encoding_for_model(model)
        tokens = enc.encode(text)
        return len(tokens)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return -1

if __name__ == "__main__":
    # Get text from command line argument or file
    if len(sys.argv) > 1:
        text_input = sys.argv[1]
        # Check if it's a file path
        if os.path.isfile(text_input):
            try:
                with open(text_input, 'r', encoding='utf-8') as f:
                    text = f.read()
            except Exception as e:
                print(f"Error reading file: {e}", file=sys.stderr)
                sys.exit(1)
        else:
            text = text_input
    else:
        text = "Hello, World!"

    model = sys.argv[2] if len(sys.argv) > 2 else "gpt-4"

    token_count = count_tokens(text, model)

    if token_count >= 0:
        print(token_count)
        sys.exit(0)
    else:
        sys.exit(1)
