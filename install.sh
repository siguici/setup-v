#!/usr/bin/env bash

set -e

VERSION="latest"
INSTALL_DIR="$HOME"
FORCE_INSTALL=false
QUIET=false
DRY_RUN=false
CHECK_ONLY=false
UPDATE_ONLY=false
FORCE_LINK=false
SKIP_LINK=false

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

function get_installed_version() {
    local v_bin="$INSTALL_DIR/v/v"
    if [[ -x "$v_bin" ]]; then
        "$v_bin" version 2>/dev/null | awk '{print $2}'
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
    log "📦 Extracting V into $destination..."

    case "$archive" in
        *.zip) unzip -o "$archive" -d "$destination" >/dev/null ;;
        *.tar.gz) tar -xzf "$archive" -C "$destination" ;;
        *) error "Unsupported archive format: $archive" && exit 1 ;;
    esac

    if [[ -d "$destination/v" ]]; then
        log "📂 V extracted to $destination/v"
    else
        error "❌ Expected 'v' directory not found after extraction!"
        exit 1
    fi
}

function install_vlang() {
    if [[ "$CHECK_ONLY" = true ]]; then
        check_v_installed && exit 0 || exit 1
    fi

    local V_DIR="$INSTALL_DIR/v"

    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release)
    fi

    local CURRENT_VERSION=""
    if [[ -x "$V_DIR/v" ]]; then
        CURRENT_VERSION=$(get_installed_version)
    fi

    if [[ "$UPDATE_ONLY" = true ]]; then
        if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
            log "✅ V is already up to date: $VERSION"
            exit 0
        else
            log "🔄 Updating from $CURRENT_VERSION to $VERSION..."
        fi
    elif [[ "$CURRENT_VERSION" == "$VERSION" && "$FORCE_INSTALL" = false ]]; then
        log "✅ V $VERSION is already installed in $V_DIR. Use --force to reinstall."
        exit 0
    fi

    ASSET_NAME=$(get_asset_name)
    DOWNLOAD_URL="https://github.com/vlang/v/releases/download/$VERSION/$ASSET_NAME"
    TEMP_FILE="$TMP_DIR/$ASSET_NAME"

    if [[ "$DRY_RUN" = true ]]; then
        log "🔍 Dry run:"
        log " - Target version: $VERSION"
        log " - Install dir: $INSTALL_DIR"
        log " - Download URL: $DOWNLOAD_URL"
        log " - Force install: $FORCE_INSTALL"
        log " - Update only: $UPDATE_ONLY"
        log " - Link: $FORCE_LINK"
        log " - No link: $SKIP_LINK"
        exit 0
    fi

    if [[ -f "$TEMP_FILE" ]]; then
        log "📦 Archive already downloaded: $TEMP_FILE"
    else
        download_vlang "$DOWNLOAD_URL" "$TEMP_FILE"
    fi

    if [[ "$FORCE_INSTALL" = true && -d "$V_DIR" ]]; then
        log "♻️ Removing old install at $V_DIR..."
        rm -rf "$V_DIR"
    fi

    if [[ -x "$V_DIR/v" ]]; then
        log "📂 V already extracted to $V_DIR"
    else
        extract_vlang "$TEMP_FILE" "$INSTALL_DIR"
    fi

    if [[ -f "$V_DIR/v" ]]; then
        if [[ "$SKIP_LINK" = false ]]; then
            log "🔧 Linking V to system path..."
            sudo "$V_DIR/v" symlink >/dev/null
        else
            log "🚫 Skipping symlink creation (use --link to force)"
        fi
    else
        error "V binary not found in $V_DIR after extraction!"
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
        --update) UPDATE_ONLY=true ;;
        --link) FORCE_LINK=true ;;
        --no-link) SKIP_LINK=true ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$FORCE_LINK" = true && "$SKIP_LINK" = true ]]; then
    error "--link and --no-link cannot be used together."
    exit 1
fi

validate_tools
install_vlang
