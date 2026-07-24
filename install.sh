#!/bin/sh
set -eu

REPO="HashShin/hashcode"
BINARY="hashcode"

if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  ESC="$(printf '\033')"
  BOLD="${ESC}[1m"
  RESET="${ESC}[0m"
  GREEN="${ESC}[32m"
  CYAN="${ESC}[36m"
  RED="${ESC}[31m"
  YELLOW="${ESC}[33m"
else
  BOLD=""
  RESET=""
  GREEN=""
  CYAN=""
  RED=""
  YELLOW=""
fi

info() { printf '%s\n' "${CYAN}${BOLD}=>${RESET} $*"; }
success() { printf '%s\n' "${GREEN}${BOLD}OK${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}${BOLD}!${RESET}  $*"; }
die() {
  printf '%s\n' "${RED}${BOLD}ERROR:${RESET} $*" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || die "curl is required."

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64 | amd64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *) die "Unsupported architecture: $ARCH" ;;
esac

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  linux) PLATFORM="linux-${ARCH}" ;;
  *)
    die "Unsupported OS: $OS. On Windows run: irm https://raw.githubusercontent.com/${REPO}/main/install.ps1 | iex"
    ;;
esac

if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = "/data/data/com.termux/files/usr" ]; then
  [ "$ARCH" = "arm64" ] || die "The Termux build currently supports ARM64 only."
  PLATFORM="android-termux"
fi

info "Fetching the latest release..."
RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")" ||
  die "Unable to fetch release information."
TAG="$(printf '%s' "$RELEASE_JSON" |
  sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
  head -n 1)"
[ -n "$TAG" ] || die "The latest release has no tag."

FILENAME="${BINARY}-${PLATFORM}"
URL="https://github.com/${REPO}/releases/download/${TAG}/${FILENAME}"
CHECKSUM_URL="https://github.com/${REPO}/releases/download/${TAG}/checksums.txt"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
TMP_BINARY="${TMP_DIR}/${BINARY}"

info "Downloading ${BINARY} ${TAG} for ${PLATFORM}..."
curl -fL --progress-bar "$URL" -o "$TMP_BINARY" || die "Download failed: $URL"

if curl -fsSL "$CHECKSUM_URL" -o "${TMP_DIR}/checksums.txt"; then
  EXPECTED="$(awk -v file="$FILENAME" '$2 == file || $2 == "*" file { print $1; exit }' "${TMP_DIR}/checksums.txt")"
  if [ -n "$EXPECTED" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      ACTUAL="$(sha256sum "$TMP_BINARY" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      ACTUAL="$(shasum -a 256 "$TMP_BINARY" | awk '{print $1}')"
    else
      ACTUAL=""
      warn "No SHA-256 utility found; skipping checksum verification."
    fi
    [ -z "$ACTUAL" ] || [ "$ACTUAL" = "$EXPECTED" ] || die "Checksum verification failed."
    [ -z "$ACTUAL" ] || success "Checksum verified."
  else
    warn "No checksum entry found for ${FILENAME}."
  fi
else
  warn "This release has no checksums.txt; continuing without verification."
fi

chmod +x "$TMP_BINARY"

if [ -n "${TERMUX_VERSION:-}" ] && [ -n "${PREFIX:-}" ]; then
  INSTALL_DIR="${PREFIX}/bin"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

mv "$TMP_BINARY" "${INSTALL_DIR}/${BINARY}"
success "Installed ${BINARY} ${TAG} to ${INSTALL_DIR}/${BINARY}"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    PROFILE="${HOME}/.profile"
    PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
    grep -qxF "$PATH_LINE" "$PROFILE" 2>/dev/null || printf '\n%s\n' "$PATH_LINE" >>"$PROFILE"
    warn "Added ${INSTALL_DIR} to PATH in ${PROFILE}; restart your terminal."
    ;;
esac

printf '\n%s\n' "${BOLD}${GREEN}Done!${RESET} Run: ${CYAN}${BINARY}${RESET}"
