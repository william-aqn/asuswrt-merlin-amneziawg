#!/bin/bash
# =============================================================
# Build .ipk packages for AmneziaWG on Asuswrt-Merlin
# Userspace-only (amneziawg-go), no kernel module needed
# Builds for aarch64 (ARM64) and arm (ARM32)
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PKG_NAME="amneziawg"
PKG_VERSION="1.0.8-1"

build_ipk(){
    local arch="$1"
    local go_bin="$2"
    local awg_bin="$3"
    local ipk_file="${PKG_NAME}_${PKG_VERSION}_${arch}.ipk"

    if [ ! -f "$go_bin" ]; then
        echo "SKIP $arch: $go_bin not found"
        return 1
    fi
    if [ ! -f "$awg_bin" ]; then
        echo "SKIP $arch: $awg_bin not found"
        return 1
    fi

    echo "Building $ipk_file ..."

    WORK_DIR="$(mktemp -d)"

    # --- debian-binary ---
    echo "2.0" > "$WORK_DIR/debian-binary"

    # --- control tarball ---
    CONTROL_DIR="$WORK_DIR/control"
    mkdir -p "$CONTROL_DIR"

    local installed_size
    installed_size=$(( $(wc -c < "$go_bin") / 1024 + $(wc -c < "$awg_bin") / 1024 ))

    cat > "$CONTROL_DIR/control" << EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: net
Architecture: ${arch}
Maintainer: amneziawg-merlin
Source: https://github.com/r0otx/asuswrt-merlin-amneziawg
Description: AmneziaWG VPN for Asuswrt-Merlin
 DPI-obfuscated WireGuard VPN with per-device policy routing
 and GeoIP/GeoSite selective routing for ASUS routers.
 Userspace implementation - works on any kernel version.
Installed-Size: ${installed_size}
EOF

    cat > "$CONTROL_DIR/postinst" << 'POSTEOF'
#!/bin/sh
chmod +x /opt/amneziawg/amneziawg-go
chmod +x /opt/amneziawg/awg
chmod +x /opt/etc/init.d/S99amneziawg
chmod +x /jffs/addons/amneziawg/amneziawg.sh
ln -sf /opt/amneziawg/awg /opt/bin/awg
mkdir -p /opt/amneziawg/geo/geoip /opt/amneziawg/geo/domains
mkdir -p /var/run/amneziawg
mkdir -p /dev/net
[ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun
if [ -f /usr/sbin/helper.sh ]; then
    /jffs/addons/amneziawg/amneziawg.sh install_page
fi
echo ""
echo "============================================"
echo "  AmneziaWG installed!"
echo "============================================"
echo "  Web UI:  VPN > AmneziaWG"
echo "  Start:   /opt/etc/init.d/S99amneziawg start"
echo ""
POSTEOF
    chmod 755 "$CONTROL_DIR/postinst"

    cat > "$CONTROL_DIR/prerm" << 'PRERMEOF'
#!/bin/sh
[ -f /jffs/addons/amneziawg/amneziawg.sh ] && /jffs/addons/amneziawg/amneziawg.sh stop 2>/dev/null
[ -f /jffs/addons/amneziawg/amneziawg.sh ] && /jffs/addons/amneziawg/amneziawg.sh uninstall 2>/dev/null
rm -f /opt/bin/awg
exit 0
PRERMEOF
    chmod 755 "$CONTROL_DIR/prerm"

    cat > "$CONTROL_DIR/conffiles" << 'CONFEOF'
/opt/amneziawg/awg0.conf
CONFEOF

    cd "$CONTROL_DIR"
    gtar czf "$WORK_DIR/control.tar.gz" --format=gnu ./control ./postinst ./prerm ./conffiles
    cd - > /dev/null

    # --- data tarball ---
    DATA_DIR="$WORK_DIR/data"
    mkdir -p "$DATA_DIR/opt/amneziawg"
    mkdir -p "$DATA_DIR/opt/bin"
    mkdir -p "$DATA_DIR/opt/etc/init.d"
    mkdir -p "$DATA_DIR/jffs/addons/amneziawg"

    cp "$go_bin"                     "$DATA_DIR/opt/amneziawg/amneziawg-go"
    cp "$awg_bin"                    "$DATA_DIR/opt/amneziawg/awg"
    cp addon/amneziawg.sh            "$DATA_DIR/jffs/addons/amneziawg/amneziawg.sh"
    cp addon/amneziawg_page.asp      "$DATA_DIR/jffs/addons/amneziawg/amneziawg_page.asp"

    chmod 755 "$DATA_DIR/opt/amneziawg/amneziawg-go"
    chmod 755 "$DATA_DIR/opt/amneziawg/awg"
    chmod 755 "$DATA_DIR/jffs/addons/amneziawg/amneziawg.sh"
    chmod 644 "$DATA_DIR/jffs/addons/amneziawg/amneziawg_page.asp"

    cd "$DATA_DIR/opt/bin"
    ln -sf ../amneziawg/awg awg
    cd - > /dev/null

    cat > "$DATA_DIR/opt/etc/init.d/S99amneziawg" << 'INITEOF'
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
    chmod 755 "$DATA_DIR/opt/etc/init.d/S99amneziawg"

    cd "$DATA_DIR"
    gtar czf "$WORK_DIR/data.tar.gz" --format=gnu ./opt ./jffs
    cd - > /dev/null

    # --- Assemble .ipk (tar.gz format — Entware opkg uses tar.gz, not ar) ---
    cd "$WORK_DIR"
    mkdir -p "$SCRIPT_DIR/output"
    gtar czf "$SCRIPT_DIR/output/$ipk_file" --format=gnu ./debian-binary ./data.tar.gz ./control.tar.gz
    cd "$SCRIPT_DIR"

    rm -rf "$WORK_DIR"

    echo "  -> output/$ipk_file ($(ls -lh "output/$ipk_file" | awk '{print $5}'))"
}

echo "=== AmneziaWG .ipk builder ==="
echo ""

# Build aarch64 (ARM64) — GT-AX11000, RT-AX86U, RT-AX88U, etc.
build_ipk "aarch64-3.10" "output/amneziawg-go" "output/awg" || true

# Build arm (ARM32) — RT-AC86U (384.x), RT-AC68U, etc.
build_ipk "armv7-2.6" "output/amneziawg-go-arm" "output/awg-arm" || true

echo ""
echo "Done. Install on router:"
echo "  scp output/<package>.ipk admin@<router>:/tmp/"
echo "  opkg install /tmp/<package>.ipk"
