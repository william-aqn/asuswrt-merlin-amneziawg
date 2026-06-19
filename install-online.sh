#!/bin/sh
# =============================================================
# AmneziaWG online installer for Asuswrt-Merlin
# Usage: curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh
# =============================================================

REPO="william-aqn/asuswrt-merlin-amneziawg"
PKG_NAME="amneziawg"
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

# Ensure full-featured mktemp (busybox mktemp may be missing or limited)
echo "Installing coreutils-mktemp..."
opkg install coreutils-mktemp || { opkg update && opkg install coreutils-mktemp; } || echo "WARNING: coreutils-mktemp not installed; using built-in mktemp"

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

# --- Resolve the latest version + download URL ---
# GitHub's API is the freshest source, but api.github.com is blocked in some regions.
# Fall back to jsDelivr, which mirrors the repo's git tags and is reachable where
# GitHub's API is not. The .ipk asset name is deterministic (see build-ipk.sh), so
# once we know the version we can build the URL.
echo "Fetching latest release..."
VERSION=""
RELEASE_JSON=""

# 1) GitHub API
RELEASE_JSON=$(curl -sfL --connect-timeout 8 --max-time 15 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null)
if [ -n "$RELEASE_JSON" ]; then
    VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//;s/^v//;s/".*//')
fi

# 2) jsDelivr data API — resolves the newest git tag (strips the leading "v")
if [ -z "$VERSION" ]; then
    echo "  GitHub API unreachable, resolving version via jsDelivr..."
    VERSION=$(curl -sfL --connect-timeout 8 --max-time 15 "https://data.jsdelivr.com/v1/packages/gh/${REPO}/resolved" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 3) jsDelivr CDN (the host this installer was fetched from) — read PKG_VERSION from
#    build-ipk.sh at the latest tag as a last resort.
if [ -z "$VERSION" ]; then
    VERSION=$(curl -sfL --connect-timeout 8 --max-time 15 "https://cdn.jsdelivr.net/gh/${REPO}@latest/build-ipk.sh" 2>/dev/null | sed -n 's/^PKG_VERSION="\([0-9][0-9.]*\).*/\1/p' | head -1)
fi

# Validate version string
case "$VERSION" in
    "") echo "ERROR: Could not determine the latest version (GitHub API and jsDelivr both unreachable)."
        echo "Check connectivity, e.g.: ping cdn.jsdelivr.net"; exit 1 ;;
    *[!0-9.]*) echo "ERROR: Invalid version format: $VERSION"; exit 1 ;;
esac
echo "Latest version: $VERSION"

# Determine the .ipk URL. From the API when available (exact arch, then base arch);
# otherwise construct the canonical release-asset URL deterministically.
IPK_URL=""
if [ -n "$RELEASE_JSON" ]; then
    IPK_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep "$PKG_ARCH" | grep '.ipk"' | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    if [ -z "$IPK_URL" ]; then
        # Fallback: armv7-3.2 -> try armv7, aarch64-3.10 -> try aarch64
        BASE_ARCH=$(echo "$PKG_ARCH" | sed 's/-.*//')
        IPK_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep "${BASE_ARCH}" | grep '.ipk"' | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    fi
fi
if [ -z "$IPK_URL" ]; then
    # Package revision is always -1 (see build-ipk.sh: PKG_VERSION="<ver>-1").
    IPK_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${PKG_NAME}_${VERSION}-1_${PKG_ARCH}.ipk"
fi

# Validate URL is from GitHub
case "$IPK_URL" in
    https://github.com/*) ;;
    *) echo "ERROR: Unexpected download URL: $IPK_URL"; exit 1 ;;
esac

IPK_FILE=$(basename "$IPK_URL")
echo "Package: $IPK_FILE"

# Best-effort SHA256 from the GitHub API digest. Present only when api.github.com is
# reachable; otherwise we skip the check and install anyway.
EXPECTED_SHA=""
if [ -n "$RELEASE_JSON" ]; then
    EXPECTED_SHA=$(echo "$RELEASE_JSON" | awk -v f="$IPK_FILE" '
        /"name":/ { in_a = (index($0, f) > 0) }
        in_a && /"digest":/ { s=$0; sub(/.*sha256:/, "", s); sub(/".*/, "", s); print s; exit }
    ')
    case "$EXPECTED_SHA" in *[!0-9a-fA-F]*) EXPECTED_SHA="" ;; esac
fi

# Download
TMP_DIR=$(mktemp -d /tmp/amneziawg_install.XXXXXX) || { echo "ERROR: Cannot create temp directory"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
# Try GitHub directly, then proxy mirrors — the release-assets host is often
# unreachable in some regions.
DEST="$TMP_DIR/$IPK_FILE"
echo "Downloading..."
DL_OK=0
for PREFIX in "" "https://ghproxy.net/" "https://gh-proxy.com/"; do
    [ -n "$PREFIX" ] && echo "  direct failed, trying mirror: $PREFIX"
    if curl -sfL --connect-timeout 8 --max-time 90 --speed-limit 1024 --speed-time 15 "${PREFIX}${IPK_URL}" -o "$DEST" 2>/dev/null && [ -s "$DEST" ]; then
        DL_OK=1; break
    fi
done
if [ "$DL_OK" != 1 ]; then
    echo "ERROR: Download failed (GitHub and mirrors unreachable)."
    echo "  Workaround: download on a device with access, scp to /tmp, then: opkg install /tmp/$IPK_FILE"
    rm -rf "$TMP_DIR"; exit 1
fi

# Verify against the GitHub API digest when we have it; otherwise skip and continue.
if [ -n "$EXPECTED_SHA" ]; then
    ACTUAL_SHA=$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')
    [ -z "$ACTUAL_SHA" ] && ACTUAL_SHA=$(openssl dgst -sha256 "$DEST" 2>/dev/null | awk '{print $NF}')
    if [ -n "$ACTUAL_SHA" ] && [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        echo "ERROR: SHA256 mismatch — refusing to install"
        echo "  expected: $EXPECTED_SHA"
        echo "  actual:   $ACTUAL_SHA"
        rm -rf "$TMP_DIR"; exit 1
    fi
    [ -n "$ACTUAL_SHA" ] && echo "Integrity: SHA256 verified"
else
    echo "Integrity: SHA256 unavailable (GitHub API blocked) — skipping check"
fi

echo "Downloaded: $DEST"

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
