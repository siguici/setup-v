#!/usr/bin/env bash

set -e

VERSION="latest"
INSTALL_DIR="$HOME/vlang"
FORCE_INSTALL=false
QUIET=false
DRY_RUN=false
CHECK_ONLY=false

OS_TYPE="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
TMP_DIR="$(mktemp -d)"

function log() {
    if [ "$QUIET" = false ]; then
        echo -e "$@"
    fi
}

function error() {
    echo -e "❌ $@" >&2
}

function get_latest_release() {
    curl -s "https://api.github.com/repos/vlang/v/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

function get_asset_name() {
    case "$OS_TYPE" in
        "linux") echo "v_linux.zip" ;;
        "darwin") 
            case "$ARCH" in
                "arm64") echo "v_macos_arm64.zip" ;;
                "x86_64") echo "v_macos_x86_64.zip" ;;
                *) error "Unsupported macOS architecture: $ARCH" && exit 1 ;;
            esac
        ;;
        "msys"|"mingw"|"cygwin") echo "v_windows.zip" ;;
        *) error "Unsupported OS: $OS_TYPE" && exit 1 ;;
    esac
}

function check_v_installed() {
    if command -v v >/dev/null; then
        V_VERSION=$(v version 2>/dev/null || echo "unknown")
        log "✅ V is already installed: $V_VERSION"
        return 0
    else
        log "❌ V is not installed."
        return 1
    fi
}

function download_vlang() {
    local url="$1"
    local output="$2"
    log "📥 Downloading V from $url..."
    curl -sL -o "$output" "$url"
    [[ -f "$output" ]] || { error "Download failed: $output not found!"; exit 1; }
}

function extract_vlang() {
    local archive="$1"
    local destination="$2"
    log "📦 Extracting V..."
    mkdir -p "$destination"
    case "$archive" in
        *.zip) unzip -o "$archive" -d "$destination" >/dev/null ;;
        *.tar.gz) tar -xzf "$archive" -C "$destination" ;;
        *) error "Unsupported archive format: $archive" && exit 1 ;;
    esac
}

function install_vlang() {
    # CHECK mode
    if [[ "$CHECK_ONLY" = true ]]; then
        check_v_installed && exit 0 || exit 1
    fi

    # SKIP if already installed
    if [[ -d "$INSTALL_DIR" && "$FORCE_INSTALL" = false ]]; then
        log "ℹ️ V is already installed in $INSTALL_DIR. Use --force to reinstall."
        exit 0
    fi

    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release)
    fi

    ASSET_NAME=$(get_asset_name)
    DOWNLOAD_URL="https://github.com/vlang/v/releases/download/$VERSION/$ASSET_NAME"
    TEMP_FILE="$TMP_DIR/$ASSET_NAME"

    # DRY-RUN mode
    if [[ "$DRY_RUN" = true ]]; then
        log "🔍 Dry run:"
        log " - Target version: $VERSION"
        log " - Install dir: $INSTALL_DIR"
        log " - Download URL: $DOWNLOAD_URL"
        log " - Asset: $ASSET_NAME"
        log " - Force install: $FORCE_INSTALL"
        exit 0
    fi

    # Start installation
    download_vlang "$DOWNLOAD_URL" "$TEMP_FILE"

    # Remove previous installation if forced
    if [[ "$FORCE_INSTALL" = true && -d "$INSTALL_DIR" ]]; then
        log "♻️ Removing old install..."
        rm -rf "$INSTALL_DIR"
    fi
    extract_vlang "$TEMP_FILE" "$INSTALL_DIR"

    if [[ -f "$INSTALL_DIR/v" ]]; then
        log "🔧 Linking V to system path..."
        (cd "$INSTALL_DIR" && ./v symlink >/dev/null)
    else
        error "V binary not found after extraction!"
        exit 1
    fi

    if command -v v >/dev/null; then
        log "✅ V $VERSION installed successfully! Run: v version"
    else
        log "⚠️ V is installed but not in your PATH."
        log "👉 Add to your PATH manually or restart your terminal."
    fi

    rm -rf "$TMP_DIR"
}

# Validate if required tools are installed
function validate_tools() {
    for cmd in curl unzip tar; do
        command -v "$cmd" >/dev/null || { error "$cmd is not installed."; exit 1; }
    done
}

# Parse args
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift ;;
        --dir) INSTALL_DIR="$2"; shift ;;
        --force) FORCE_INSTALL=true ;;
        --quiet) QUIET=true ;;
        --check) CHECK_ONLY=true ;;
        --dry-run) DRY_RUN=true ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Validate tools
validate_tools

# Start installation
install_vlang
