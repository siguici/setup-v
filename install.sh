#!/usr/bin/env bash

set -e

VERSION="latest"
INSTALL_DIR="$HOME/vlang"
FORCE_INSTALL=false
OS_TYPE="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
TMP_DIR="$(mktemp -d)"

# Check dependencies ✅
for cmd in curl unzip tar; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "❌ $cmd is required but not installed!"; exit 1; }
done

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
                *) echo "❌ Unsupported macOS architecture: $ARCH" && exit 1 ;;
            esac
        ;;
        "msys"|"mingw"|"cygwin") echo "v_windows.zip" ;;
        *) echo "❌ Unsupported OS: $OS_TYPE" && exit 1 ;;
    esac
}

function download_vlang() {
    local url="$1"
    local output="$2"
    echo "🌐 Downloading V from $url..."
    curl -L -o "$output" "$url"
    [[ -f "$output" ]] || { echo "❌ Download failed: $output not found!"; exit 1; }
}

function extract_vlang() {
    local archive="$1"
    local destination="$2"
    echo "📦 Extracting V..."
    mkdir -p "$destination"
    case "$archive" in
        *.zip) unzip -o "$archive" -d "$destination" ;;
        *.tar.gz) tar -xzf "$archive" -C "$destination" ;;
        *) echo "❌ Unsupported archive format: $archive" && exit 1 ;;
    esac
}

function install_vlang() {
    if [[ -d "$INSTALL_DIR" && "$FORCE_INSTALL" == false ]]; then
        echo "ℹ️ V is already installed in $INSTALL_DIR. Use --force to reinstall."
        return 0
    fi

    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release)
    fi

    ASSET_NAME=$(get_asset_name)
    DOWNLOAD_URL="https://github.com/vlang/v/releases/download/$VERSION/$ASSET_NAME"
    TEMP_FILE="$TMP_DIR/$ASSET_NAME"

    download_vlang "$DOWNLOAD_URL" "$TEMP_FILE"

    [[ "$FORCE_INSTALL" == true && -d "$INSTALL_DIR" ]] && echo "♻️ Cleaning existing installation..." && rm -rf "$INSTALL_DIR"
    extract_vlang "$TEMP_FILE" "$INSTALL_DIR"

    if [[ -f "$INSTALL_DIR/v" ]]; then
        echo "🔧 Linking V to system path..."
        (cd "$INSTALL_DIR" && ./v symlink)
    else
        echo "❌ Error: V binary not found after extraction!"
        exit 1
    fi

    if command -v v >/dev/null; then
        echo "✅ V is successfully installed! Run: v version"
    else
        echo "⚠️ V is installed but not in your PATH."
        echo "👉 Add to your PATH manually or restart your terminal."
    fi

    # Cleanup
    rm -rf "$TMP_DIR"
}

# Parse args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) [[ -n "$2" ]] && VERSION="$2" || { echo "❌ Missing argument for --version"; exit 1; }; shift ;;
        --dir) [[ -n "$2" ]] && INSTALL_DIR="$2" || { echo "❌ Missing argument for --dir"; exit 1; }; shift ;;
        --force) FORCE_INSTALL=true ;;
        *) echo "⚠️ Unknown option: $1"; exit 1 ;;
    esac
    shift
done

install_vlang
