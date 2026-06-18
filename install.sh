#!/bin/sh
# =============================================================
# AmneziaWG full installer for ASUS GT-AX11000 (Merlin 388.x)
# Installs: kernel module + awg tool + web UI addon
# Run ON THE ROUTER via SSH
# =============================================================
set -e

AWG_DIR="/opt/amneziawg"
ADDON_DIR="/jffs/addons/amneziawg"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== AmneziaWG Installer for GT-AX11000 ==="
echo ""

# --- Preflight checks ---

# Check for module and tool
MODULE_SRC=""
TOOL_SRC=""
PAGE_SRC=""
ADDON_SCRIPT_SRC=""

for dir in "$SRC_DIR"; do
    [ -f "$dir/amneziawg.ko" ] && MODULE_SRC="$dir/amneziawg.ko"
    [ -f "$dir/awg" ] && TOOL_SRC="$dir/awg"
    [ -f "$dir/amneziawg_page.asp" ] && PAGE_SRC="$dir/amneziawg_page.asp"
    [ -f "$dir/amneziawg.sh" ] && ADDON_SCRIPT_SRC="$dir/amneziawg.sh"
done

if [ -z "$MODULE_SRC" ] || [ -z "$TOOL_SRC" ]; then
    echo "ERROR: amneziawg.ko and/or awg not found in $SRC_DIR or /tmp"
    echo ""
    echo "Copy build artifacts first:"
    echo "  scp output/amneziawg.ko output/awg admin@<router>:/tmp/"
    echo "  scp addon/amneziawg_page.asp addon/amneziawg.sh admin@<router>:/tmp/"
    exit 1
fi

if [ ! -d "/opt" ]; then
    echo "ERROR: /opt not found. Is Entware installed?"
    echo "  Install Entware first via amtm"
    exit 1
fi

# --- Verify vermagic ---

RUNNING_KERNEL=$(uname -r)
MODULE_VERMAGIC=$(strings "$MODULE_SRC" | grep "vermagic=" | head -1)
echo "Running kernel:   $RUNNING_KERNEL"
echo "Module vermagic:  $MODULE_VERMAGIC"

if ! echo "$MODULE_VERMAGIC" | grep -q "$RUNNING_KERNEL"; then
    echo ""
    echo "ERROR: Vermagic mismatch!"
    echo "Module was built for a different kernel version."
    echo "Rebuild with matching kernel config."
    exit 1
fi
echo "Vermagic: OK"
echo ""

# --- Install core files ---

echo "[1/4] Installing module and tools..."
mkdir -p "$AWG_DIR"
cp "$MODULE_SRC" "$AWG_DIR/amneziawg.ko"
cp "$TOOL_SRC"   "$AWG_DIR/awg"
chmod +x "$AWG_DIR/awg"
ln -sf "$AWG_DIR/awg" /opt/bin/awg

# Copy example config if no config exists
if [ ! -f "$AWG_DIR/awg0.conf" ]; then
    for dir in "$SRC_DIR" "/tmp"; do
        if [ -f "$dir/awg0.conf.example" ]; then
            cp "$dir/awg0.conf.example" "$AWG_DIR/awg0.conf.example"
            break
        fi
    done
fi

echo "  Module:  $AWG_DIR/amneziawg.ko"
echo "  Tool:    $AWG_DIR/awg"

# --- Test module loading ---

echo ""
echo "[2/4] Testing module..."
if lsmod | grep -q amneziawg; then
    rmmod amneziawg 2>/dev/null
fi

insmod "$AWG_DIR/amneziawg.ko"
if lsmod | grep -q amneziawg; then
    echo "  Module loaded OK"
    rmmod amneziawg
else
    echo "  ERROR: Module failed to load!"
    echo "  Check: dmesg | tail -30"
    exit 1
fi

# --- Install Entware init script ---

echo ""
echo "[3/4] Installing autostart script..."
cat > /opt/etc/init.d/S99amneziawg << 'INITEOF'
#!/bin/sh

case "$1" in
    start)
        /jffs/addons/amneziawg/amneziawg.sh start
        ;;
    stop)
        /jffs/addons/amneziawg/amneziawg.sh stop
        ;;
    restart)
        /jffs/addons/amneziawg/amneziawg.sh restart
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
INITEOF
chmod +x /opt/etc/init.d/S99amneziawg
echo "  /opt/etc/init.d/S99amneziawg"

# --- Install web UI addon ---

echo ""
echo "[4/4] Installing web UI addon..."

mkdir -p "$ADDON_DIR"

# Copy addon script
if [ -n "$ADDON_SCRIPT_SRC" ]; then
    cp "$ADDON_SCRIPT_SRC" "$ADDON_DIR/amneziawg.sh"
    chmod +x "$ADDON_DIR/amneziawg.sh"
else
    echo "  WARNING: amneziawg.sh not found, skipping addon backend"
fi

# Copy web page
if [ -n "$PAGE_SRC" ]; then
    cp "$PAGE_SRC" "$ADDON_DIR/amneziawg_page.asp"
    # Trigger addon page installation
    "$ADDON_DIR/amneziawg.sh" install_page
else
    echo "  WARNING: amneziawg_page.asp not found, skipping web UI"
    echo "  To install later: scp amneziawg_page.asp admin@router:/tmp/"
    echo "  Then run: /jffs/addons/amneziawg/amneziawg.sh install_page"
fi

# --- Done ---

echo ""
echo "============================================"
echo "  Installation complete!"
echo "============================================"
echo ""
echo "Web UI:  Open router admin > VPN > AmneziaWG"
echo ""
echo "CLI usage:"
echo "  awg show                                # status"
echo "  /opt/etc/init.d/S99amneziawg start      # start"
echo "  /opt/etc/init.d/S99amneziawg stop       # stop"
echo ""
echo "Config:  Edit via web UI or vi $AWG_DIR/awg0.conf"
echo ""
echo "To uninstall:"
echo "  /jffs/addons/amneziawg/amneziawg.sh uninstall"
