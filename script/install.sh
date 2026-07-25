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

TERMUX_PREFIX="/data/data/com.termux/files/usr"
IS_TERMUX=0
if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = "$TERMUX_PREFIX" ] || [ -d "$TERMUX_PREFIX/bin" ]; then
  IS_TERMUX=1
fi

if [ "$IS_TERMUX" -eq 1 ]; then
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
TMP_BINARY="${TMP_DIR}/${BINARY}"

info "Downloading ${BINARY} ${TAG} for ${PLATFORM}..."
curl -fL --progress-bar "$URL" -o "$TMP_BINARY" || die "Download failed: $URL"

chmod +x "$TMP_BINARY"

# Termux always uses its canonical PREFIX. On regular Linux, prefer the path
# the shell already uses so an older copy cannot shadow the new binary.
EXISTING_BINARY="$(command -v "$BINARY" 2>/dev/null || true)"
MANAGED_EXISTING=""
case "$EXISTING_BINARY" in
  "${HOME}/.local/bin/${BINARY}" | "/usr/local/bin/${BINARY}")
    MANAGED_EXISTING="$EXISTING_BINARY"
    ;;
esac
if [ -n "${PREFIX:-}" ] && [ "$EXISTING_BINARY" = "${PREFIX}/bin/${BINARY}" ]; then
  MANAGED_EXISTING="$EXISTING_BINARY"
fi

if [ "$IS_TERMUX" -eq 1 ]; then
  INSTALL_DIR="${PREFIX:-$TERMUX_PREFIX}/bin"
elif [ -n "$MANAGED_EXISTING" ]; then
  INSTALL_DIR="${MANAGED_EXISTING%/*}"
  [ -w "$INSTALL_DIR" ] ||
    die "Existing installation at ${MANAGED_EXISTING} is not writable."
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="${HOME}/.local/bin"
fi

mkdir -p "$INSTALL_DIR"
mv "$TMP_BINARY" "${INSTALL_DIR}/${BINARY}"
success "Installed ${BINARY} ${TAG} to ${INSTALL_DIR}/${BINARY}"

# Older Termux installs used ~/.local/bin. Remove that obsolete copy after the
# new binary is safely installed in Termux's canonical PREFIX.
if [ "$IS_TERMUX" -eq 1 ]; then
  LEGACY_TERMUX_BINARY="${HOME}/.local/bin/${BINARY}"
  if [ -e "$LEGACY_TERMUX_BINARY" ] || [ -L "$LEGACY_TERMUX_BINARY" ]; then
    rm -f "$LEGACY_TERMUX_BINARY"
    success "Removed old Termux copy at ${LEGACY_TERMUX_BINARY}"
  fi
fi

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    PROFILE="${HOME}/.profile"
    if [ "$INSTALL_DIR" = "${HOME}/.local/bin" ]; then
      PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
    else
      PATH_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
    grep -qxF "$PATH_LINE" "$PROFILE" 2>/dev/null || printf '\n%s\n' "$PATH_LINE" >>"$PROFILE"
    warn "Added ${INSTALL_DIR} to PATH in ${PROFILE}; restart your terminal."
    ;;
esac

printf '\n%s\n' "${BOLD}${GREEN}Done!${RESET} Run: ${CYAN}${BINARY}${RESET}"
