#!/bin/sh
# =============================================================
# AmneziaWG online installer for Asuswrt-Merlin
# Usage: curl -sfL https://raw.githubusercontent.com/r0otx/asuswrt-merlin-amneziawg/main/install-online.sh | sh
# =============================================================

REPO="r0otx/asuswrt-merlin-amneziawg"
TMP_DIR=""

echo ""
echo "============================================"
echo "  AmneziaWG Installer"
echo "============================================"
echo ""

# Ensure /opt/bin is in PATH (not set in non-interactive curl|sh shells)
export PATH="/opt/bin:/opt/sbin:$PATH"

# Check Entware
if [ ! -x /opt/bin/opkg ]; then
    echo "ERROR: Entware not installed. Install it first via amtm."
    exit 1
fi
echo "Entware: OK"

# Detect architecture from opkg config (matches what opkg actually expects)
PKG_ARCH=$(opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2!="all" {print $2}' | head -1)
if [ -z "$PKG_ARCH" ]; then
    # Fallback to uname-based detection
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64) PKG_ARCH="aarch64-3.10" ;;
        armv7l)  PKG_ARCH="armv7-2.6" ;;
        *)
            echo "ERROR: Unsupported architecture: $ARCH"
            echo "Supported: aarch64, armv7l"
            exit 1
            ;;
    esac
fi
echo "Architecture: $PKG_ARCH"

# Get latest release URL
echo "Fetching latest release..."
RELEASE_JSON=$(curl -sfL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null)
if [ -z "$RELEASE_JSON" ]; then
    echo "ERROR: Cannot reach GitHub API"
    exit 1
fi

VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
# Validate version string
case "$VERSION" in
    *[!0-9.]*) echo "ERROR: Invalid version format: $VERSION"; exit 1 ;;
esac
echo "Latest version: $VERSION"

# Find matching .ipk asset (exact arch, then fallback to base arch)
IPK_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep "$PKG_ARCH" | grep '.ipk"' | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
if [ -z "$IPK_URL" ]; then
    # Fallback: armv7-3.2 -> try armv7, aarch64-3.10 -> try aarch64
    BASE_ARCH=$(echo "$PKG_ARCH" | sed 's/-.*//')
    IPK_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep "${BASE_ARCH}" | grep '.ipk"' | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
fi
if [ -z "$IPK_URL" ]; then
    echo "ERROR: No .ipk found for $PKG_ARCH in release $VERSION"
    exit 1
fi

# Validate URL is from GitHub
case "$IPK_URL" in
    https://github.com/*) ;;
    *) echo "ERROR: Unexpected download URL: $IPK_URL"; exit 1 ;;
esac

IPK_FILE=$(basename "$IPK_URL")
echo "Package: $IPK_FILE"

# Download
TMP_DIR=$(mktemp -d /tmp/amneziawg_install.XXXXXX) || { echo "ERROR: Cannot create temp directory"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
echo "Downloading..."
if ! curl -sfL "$IPK_URL" -o "$TMP_DIR/$IPK_FILE"; then
    echo "ERROR: Download failed"
    rm -rf "$TMP_DIR"
    exit 1
fi
echo "Downloaded: $TMP_DIR/$IPK_FILE"

# Install
echo "Installing..."
opkg install "$TMP_DIR/$IPK_FILE" || opkg install --force-architecture "$TMP_DIR/$IPK_FILE"
RC=$?

# Cleanup
rm -rf "$TMP_DIR"

if [ $RC -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "  AmneziaWG $VERSION installed!"
    echo "============================================"
    echo "  Web UI:  VPN > AmneziaWG"
    echo "  Start:   /opt/etc/init.d/S99amneziawg start"
    echo ""
else
    echo "ERROR: Installation failed (exit code $RC)"
    exit 1
fi
