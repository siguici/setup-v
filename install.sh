#!/usr/bin/env bash

set -e

VERSION="latest"
INSTALL_DIR="$HOME/vlang"
OS_TYPE="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

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
                *) echo "Unsupported macOS architecture: $ARCH" && exit 1 ;;
            esac
        ;;
        "msys"|"mingw"|"cygwin") echo "v_windows.zip" ;;
        *) echo "Unsupported OS: $OS_TYPE" && exit 1 ;;
    esac
}

function download_vlang() {
    local url="$1"
    local output="$2"

    echo "Downloading Vlang from $url..."
    curl -L -o "$output" "$url"
}

function extract_vlang() {
    local archive="$1"
    local destination="$2"

    echo "Extracting Vlang..."
    mkdir -p "$destination"

    case "$archive" in
        *.zip) unzip -o "$archive" -d "$destination" ;;
        *.tar.gz) tar -xzf "$archive" -C "$destination" ;;
        *) echo "Unsupported archive format: $archive" && exit 1 ;;
    esac
}

function install_vlang() {
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release)
    fi

    ASSET_NAME=$(get_asset_name)
    DOWNLOAD_URL="https://github.com/vlang/v/releases/download/$VERSION/$ASSET_NAME"

    TEMP_FILE="/tmp/$ASSET_NAME"

    download_vlang "$DOWNLOAD_URL" "$TEMP_FILE"
    extract_vlang "$TEMP_FILE" "$INSTALL_DIR"

    # Nettoyage
    rm -f "$TEMP_FILE"

    echo "Vlang has been installed in $INSTALL_DIR"
}

# Lire les arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --dir) INSTALL_DIR="$2"; shift ;;
    esac
    shift
done

install_vlang
