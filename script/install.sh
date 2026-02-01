#!/bin/bash
set -e

BIN_NAME="hashcode"
INSTALL_DIR="$HOME/.local/bin"

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
LATEST_URL=$(curl -s "https://api.github.com/repos/HashShin/hashcode/releases/latest" \
  | grep "browser_download_url" \
  | grep "$PLATFORM" \
  | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "Failed to get download URL for platform: $PLATFORM" >&2
    exit 1
fi

# Prepare install dir
mkdir -p "$INSTALL_DIR"
TMP_FILE="$(mktemp)"

# Download binary
curl -L -o "$TMP_FILE" "$LATEST_URL"

# Install binary
chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$INSTALL_DIR/$BIN_NAME"

# Update PATH for current shell
export PATH="$INSTALL_DIR:$PATH"

# Persist PATH in shell RC files with #HASHCODE comment
for RC in ~/.profile ~/.bashrc ~/.zprofile ~/.zshrc ~/.config/fish/config.fish; do
    [ -f "$RC" ] || continue
    case "$RC" in
        *.fish)
            grep -qxF "#HASHCODE" "$RC" 2>/dev/null || echo "#HASHCODE" >> "$RC"
            grep -qxF "set -gx PATH \$PATH $INSTALL_DIR" "$RC" 2>/dev/null || \
                echo "set -gx PATH \$PATH $INSTALL_DIR" >> "$RC"
            ;;
        *)
            grep -qxF "#HASHCODE" "$RC" 2>/dev/null || echo "#HASHCODE" >> "$RC"
            grep -qxF "export PATH=\"$INSTALL_DIR:\$PATH\"" "$RC" 2>/dev/null || \
                echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC"
            ;;
    esac
done

# Source shell RC files immediately (simplified)
source ~/.profile
source ~/.bashrc
source ~/.zprofile
source ~/.zshrc

clear
cat <<'EOF'
░█░█░█▀█░█▀▀░█░█░█▀▀░█▀█░█▀▄░█▀▀░
░█▀█░█▀█░▀▀█░█▀█░█░░░█░█░█░█░█▀▀░
░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀░░▀▀▀░
EOF
echo
echo -e "Installation complete. Run: \033[1;32mhashcode\033[0m"
