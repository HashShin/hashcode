#!/usr/bin/env bash
set -euo pipefail

APP="hashcode"
INSTALL_DIR="$HOME/.local/bin"

MUTED='\033[0;2m'
RED='\033[0;31m'
ORANGE='\033[38;5;214m'
NC='\033[0m'

binary_path=""
no_modify_path=false

mkdir -p "$INSTALL_DIR"

require_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        echo -e "${RED}Neither curl nor wget is installed${NC}" >&2
        exit 1
    fi
}

detect_platform() {
    if [ -n "${PREFIX-}" ] && [ -d "$PREFIX" ]; then
        PLATFORM="android-termux"
    else
        OS=$(uname -s)
        ARCH=$(uname -m)
        case "$OS" in
            Linux)
                case "$ARCH" in
                    x86_64) PLATFORM="linux-amd64" ;;
                    aarch64) PLATFORM="linux-arm64" ;;
                    *) echo -e "${RED}Unsupported architecture: $ARCH${NC}" >&2; exit 1 ;;
                esac
                ;;
            *) echo -e "${RED}Unsupported OS: $OS${NC}" >&2; exit 1 ;;
        esac
    fi
}

download_latest() {
    if [ "$DOWNLOADER" = "curl" ]; then
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

    [ -n "$LATEST_URL" ] || {
        echo -e "${RED}Failed to get download URL for platform: $PLATFORM${NC}" >&2
        exit 1
    }
}

install_binary() {
    if [ -n "$binary_path" ]; then
        [ -f "$binary_path" ] || { echo -e "${RED}Binary not found at $binary_path${NC}"; exit 1; }
        cp "$binary_path" "$INSTALL_DIR/$APP"
    else
        TMP_FILE="$(mktemp)"
        if [ "$DOWNLOADER" = "curl" ]; then
            curl -L -o "$TMP_FILE" "$LATEST_URL"
        else
            wget -O "$TMP_FILE" "$LATEST_URL"
        fi
        chmod +x "$TMP_FILE"
        mv "$TMP_FILE" "$INSTALL_DIR/$APP"
    fi
    chmod +x "$INSTALL_DIR/$APP"
}

add_to_path_file() {
    local file="$1"
    local line="export PATH=\"$INSTALL_DIR:\$PATH\""
    if ! grep -Fxq "$line" "$file"; then
        echo -e "\n# HASHCODE" >> "$file"
        echo "$line" >> "$file"
    fi
}

update_path() {
    export PATH="$INSTALL_DIR:$PATH"
    if [ "$no_modify_path" != "true" ]; then
        for rc_file in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
            [ -f "$rc_file" ] && add_to_path_file "$rc_file"
        done
    fi
}

print_banner() {
    clear
    cat <<'EOF'

  ░█░█░█▀█░█▀▀░█░█░█▀▀░█▀█░█▀▄░█▀▀░
  ░█▀█░█▀█░▀▀█░█▀█░█░░░█░█░█░█░█▀▀░
  ░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀░░▀▀▀░

EOF
    echo -e " ${MUTED}Installation complete. Run: ${NC}\033[1;32mhashcode\033[0m"
}

main() {
    require_downloader
    detect_platform
    [ -z "$binary_path" ] && download_latest
    install_binary
    update_path
    print_banner
}

main
