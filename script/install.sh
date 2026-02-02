#!/bin/bash
set -e
BIN_NAME="hashcode"
INSTALL_DIR="$HOME/.local/bin"

# Detect download tool
if command -v curl >/dev/null 2>&1; then
    DOWNLOAD_CMD="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD_CMD="wget"
else
    echo "Error: Neither curl nor wget found. Please install one of them." >&2
    exit 1
fi

# Detect platform
if [ -n "$PREFIX" ] && [ -d "$PREFIX" ]; then
    PLATFORM="android-termux"
else
    OS=$(uname -s)
    ARCH=$(uname -m)
    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64)  PLATFORM="linux-amd64" ;;
                aarch64) PLATFORM="linux-arm64" ;;
                *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
            esac
            ;;
        *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
    esac
fi

# Resolve latest release asset URL
if [ "$DOWNLOAD_CMD" = "curl" ]; then
    LATEST_URL=$(curl -s "https://api.github.com/repos/HashShin/hashcode/releases/latest" \
      | grep "browser_download_url" \
      | grep "$PLATFORM" \
      | cut -d '"' -f 4)
else
    LATEST_URL=$(wget -qO- "https://api.github.com/repos/HashShin/hashcode/releases/latest" \
      | grep "browser_download_url" \
      | grep "$PLATFORM" \
      | cut -d '"' -f 4)
fi

[ -n "$LATEST_URL" ] || { echo "Failed to get download URL for platform: $PLATFORM" >&2; exit 1; }

# Prepare install dir
mkdir -p "$INSTALL_DIR"
TMP_FILE="$(mktemp)"

# Download binary
if [ "$DOWNLOAD_CMD" = "curl" ]; then
    curl -L -o "$TMP_FILE" "$LATEST_URL"
else
    wget -O "$TMP_FILE" "$LATEST_URL"
fi

# Install binary
chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$INSTALL_DIR/$BIN_NAME"

# Update PATH for current shell
export PATH="$INSTALL_DIR:$PATH"

# Persist PATH in ~/.bashrc only
RC="$HOME/.bashrc"
grep -qxF "#HASHCODE" "$RC" 2>/dev/null || echo "#HASHCODE" >> "$RC"
grep -qxF "export PATH=\"$INSTALL_DIR:\$PATH\"" "$RC" 2>/dev/null || \
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC"

source ~/.bashrc
clear

cat <<'EOF'
 ░█░█░█▀█░█▀▀░█░█░█▀▀░█▀█░█▀▄░█▀▀░
 ░█▀█░█▀█░▀▀█░█▀█░█░░░█░█░█░█░█▀▀░
 ░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀░░▀▀▀░
EOF
echo
echo -e "Installation complete. Run: \033[1;32mhashcode\033[0m"
