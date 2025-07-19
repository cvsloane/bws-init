#!/usr/bin/env bash
# Installation script for bws-init

set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://github.com/yourusername/bws-init"
TEMP_DIR=$(mktemp -d)

echo "Installing bws-init..."

# Check for dependencies
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed"
    exit 1
fi

# Clone repository
echo "Downloading bws-init..."
git clone --depth 1 "$REPO_URL" "$TEMP_DIR/bws-init" || {
    echo "Error: Failed to download bws-init"
    exit 1
}

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Installing to $INSTALL_DIR..."
cp -r "$TEMP_DIR/bws-init/bin"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bws-init"

# Copy source files
mkdir -p "$HOME/.local/share/bws-init"
cp -r "$TEMP_DIR/bws-init/src" "$HOME/.local/share/bws-init/"

# Update paths in bin script
sed -i "s|ROOT_DIR=\"\$(dirname \"\$SCRIPT_DIR\")\"|ROOT_DIR=\"$HOME/.local/share/bws-init\"|g" "$INSTALL_DIR/bws-init"

# Clean up
rm -rf "$TEMP_DIR"

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "WARNING: $INSTALL_DIR is not in your PATH"
    echo "Add the following to your shell configuration file:"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo ""
echo "✓ bws-init installed successfully!"
echo ""
echo "Run 'bws-init --help' to get started"