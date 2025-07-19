#!/usr/bin/env bash
# Build release packages for bws-init

set -e

VERSION=$(grep "VERSION=" src/bws-init.sh | head -1 | cut -d'"' -f2)
RELEASE_DIR="releases/v$VERSION"

echo "Building bws-init release v$VERSION..."

# Create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Create tarball for Unix systems
echo "Creating Unix release..."
tar -czf "$RELEASE_DIR/bws-init-v$VERSION-unix.tar.gz" \
    --exclude=.git \
    --exclude=releases \
    --exclude=tests \
    --exclude=.gitignore \
    --exclude=package.json \
    --transform "s,^,bws-init/," \
    bin src scripts/install.sh README.md LICENSE

# Create zip for Windows
echo "Creating Windows release..."
zip -r "$RELEASE_DIR/bws-init-v$VERSION-windows.zip" \
    bin/bws-init.cmd \
    src/bws-init.ps1 \
    README.md \
    LICENSE \
    -x "*.git*"

# Create standalone scripts
echo "Creating standalone scripts..."
cp src/bws-init.sh "$RELEASE_DIR/bws-init-standalone.sh"
cp src/bws-init.ps1 "$RELEASE_DIR/bws-init-standalone.ps1"

# Create checksums
echo "Generating checksums..."
cd "$RELEASE_DIR"
sha256sum * > checksums.txt

echo ""
echo "✓ Release v$VERSION built successfully!"
echo ""
echo "Files created in $RELEASE_DIR:"
ls -la
echo ""
echo "Next steps:"
echo "1. Test the release packages"
echo "2. Create GitHub release and upload files"
echo "3. Update installation documentation"