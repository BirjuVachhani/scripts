#!/bin/bash

# Install script for adding scripts directory to PATH
# This script adds the scripts directory, local, and custom directories to your PATH environment variable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR"
LOCAL_DIR="$HOME/.scripts/local"
CUSTOM_DIR="$HOME/.scripts/custom"

# Determine the shell configuration file
if [ -n "$ZSH_VERSION" ]; then
    # zsh
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    # bash
    if [ -f "$HOME/.bash_profile" ]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    else
        SHELL_CONFIG="$HOME/.bashrc"
    fi
else
    # Default to .zshrc for macOS
    SHELL_CONFIG="$HOME/.zshrc"
fi

# Check if PATH entry already exists
if grep -q "export PATH.*$SCRIPTS_DIR" "$SHELL_CONFIG" 2>/dev/null; then
    echo "✓ Scripts directories are already in PATH"
    exit 0
fi

# Create local and custom directories if they don't exist
mkdir -p "$LOCAL_DIR"
mkdir -p "$CUSTOM_DIR"

# Add to PATH
echo "" >> "$SHELL_CONFIG"
echo "# Added by scripts install script" >> "$SHELL_CONFIG"
echo "export PATH=\"\$PATH:$SCRIPTS_DIR:$LOCAL_DIR:$CUSTOM_DIR\"" >> "$SHELL_CONFIG"

echo "✓ Successfully added scripts directories to PATH"
echo "  Main scripts: $SCRIPTS_DIR"
echo "  Local scripts: $LOCAL_DIR"
echo "  Custom scripts: $CUSTOM_DIR"
echo "  Added to: $SHELL_CONFIG"
echo ""

# Handle .env file creation
ENV_FILE="$SCRIPT_DIR/.env"
ENV_SAMPLE="$SCRIPT_DIR/.env.sample"

if [ -f "$ENV_FILE" ]; then
    # .env already exists, ask if user wants to override
    read -p "⚠ .env file already exists. Override with .env.sample? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$ENV_SAMPLE" ]; then
            cp "$ENV_SAMPLE" "$ENV_FILE"
            echo "✓ .env file updated from .env.sample"
        else
            echo "⚠ Warning: .env.sample not found, keeping existing .env"
        fi
    else
        echo "✓ Keeping existing .env file"
    fi
else
    # .env doesn't exist, create it from .env.sample
    if [ -f "$ENV_SAMPLE" ]; then
        cp "$ENV_SAMPLE" "$ENV_FILE"
        echo "✓ Created .env file from .env.sample"
    else
        echo "⚠ Warning: .env.sample not found, skipping .env creation"
    fi
fi

echo ""
echo "Please run 'source $SHELL_CONFIG' or restart your terminal to use the scripts."

