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
# Single source of truth: read the addon version from amneziawg.sh (the value the UI shows
# and the release tag uses) and append the packaging revision. Prevents the .ipk version
# from drifting behind AWG_VERSION at release time.
AWG_VERSION="$(awk -F'"' '/^AWG_VERSION=/{print $2; exit}' addon/amneziawg.sh)"
[ -n "$AWG_VERSION" ] || { echo "ERROR: could not read AWG_VERSION from addon/amneziawg.sh" >&2; exit 1; }
PKG_VERSION="${AWG_VERSION}-1"

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
Source: https://github.com/william-aqn/asuswrt-merlin-amneziawg
Description: AmneziaWG VPN for Asuswrt-Merlin
 DPI-obfuscated WireGuard VPN with per-device policy routing
 and GeoIP/GeoSite selective routing for ASUS routers.
 Userspace implementation - works on any kernel version.
Installed-Size: ${installed_size}
EOF

    cat > "$CONTROL_DIR/postinst" << 'POSTEOF'
#!/bin/sh
set -e
for file in /opt/amneziawg/amneziawg-go /opt/amneziawg/awg; do
    [ -f "$file" ] || { echo "ERROR: $file not found"; exit 1; }
    chmod +x "$file"
done
chmod +x /opt/etc/init.d/S99amneziawg
chmod +x /jffs/addons/amneziawg/amneziawg.sh
ln -sf /opt/amneziawg/awg /opt/bin/awg
mkdir -p /opt/amneziawg/geo/geoip /opt/amneziawg/geo/domains
mkdir -p -m 700 /var/run/amneziawg
mkdir -p /dev/net
mknod -m 600 /dev/net/tun c 10 200 2>/dev/null || true
chmod 600 /dev/net/tun 2>/dev/null || true
# Compatibility mode (don't hijack :53 DNS) defaults ON for brand-new installs only, so an
# undetected co-resident DPI/proxy tool (zapret2 / Xray / b4 / ...) can't lock the LAN out of
# DNS. "New" = no AmneziaWG settings yet; upgrades (awg_* keys already present) are untouched.
SETTINGS=/jffs/addons/custom_settings.txt
if ! grep -q '^awg_' "$SETTINGS" 2>/dev/null; then
    : >> "$SETTINGS" 2>/dev/null || true
    echo "awg_no_dns_intercept 1" >> "$SETTINGS" 2>/dev/null || true
fi
if [ -f /usr/sbin/helper.sh ]; then
    /jffs/addons/amneziawg/amneziawg.sh install_page || true
fi
echo ""
echo "============================================"
echo "  AmneziaWG installed!"
echo "============================================"
echo "  Web UI:  VPN > AmneziaWG"
echo "  Start:   /opt/etc/init.d/S99amneziawg start"
echo ""
if pidof b4 >/dev/null 2>&1 || [ -x /opt/sbin/b4 ] || [ -f /opt/etc/init.d/S99b4 ]; then
    echo "NOTE: b4 (DPI-bypass) detected. AmneziaWG runs in compatibility mode (no :53 DNS"
    echo "  hijack) so they don't clash. Both share router CPU/RAM - on low-RAM routers"
    echo "  (<512MB) running both can OOM/hang. Prefer default policy 'Direct' or 'Geo only'."
    echo ""
fi
POSTEOF
    chmod 755 "$CONTROL_DIR/postinst"

    cat > "$CONTROL_DIR/prerm" << 'PRERMEOF'
#!/bin/sh
# `uninstall` already runs a full `do_stop user` (stops the VPN, strips firewall/DNS rules + the
# dnsmasq include, drops the watchdog cron). Calling `stop` first only spawned a SECOND detached
# dnsmasq-reload racing the first — on a low-RAM box (RT-AC68U, 256MB) two concurrent
# `service restart_dnsmasq` storms during opkg can OOM/blackout the LAN. So run uninstall only.
if [ -f /jffs/addons/amneziawg/amneziawg.sh ]; then
    /jffs/addons/amneziawg/amneziawg.sh uninstall 2>/dev/null || true
fi
# Defensive strip (in case uninstall was interrupted or the script was already gone): a dangling
# `conf-file=/opt/amneziawg/...` in the persistent /jffs include is fatal to the firmware's dnsmasq
# at the next boot once we rm -rf /opt/amneziawg below. Rewrite unconditionally (an empty result is
# fine) — do NOT chain on grep's exit code.
if [ -f /jffs/configs/dnsmasq.conf.add ]; then
    grep -vF 'conf-file=/opt/amneziawg/' /jffs/configs/dnsmasq.conf.add > /jffs/configs/dnsmasq.conf.add.tmp 2>/dev/null
    mv /jffs/configs/dnsmasq.conf.add.tmp /jffs/configs/dnsmasq.conf.add 2>/dev/null
fi
# Same defensive class for "DNS via tunnel": with /opt/amneziawg gone the server=@awg0 lines
# are gone too, so the flag must fall — a stray flag makes dnsmasq.postconf strip the firmware
# upstreams and leaves dnsmasq with NO upstreams (dead LAN DNS until reboot). The postconf
# hook line is removed by uninstall; strip it here too in case uninstall was interrupted.
rm -f /tmp/.awg_tunnel_dns
[ -f /jffs/scripts/dnsmasq.postconf ] && sed -i '/amneziawg/d' /jffs/scripts/dnsmasq.postconf 2>/dev/null
# Wait for any in-flight dnsmasq reload to finish, then confirm the resolver is back, BEFORE
# deleting files — so a restart can't land mid-teardown and leave the LAN without DNS/DHCP until a
# hard reboot.
_i=0; while [ -d /tmp/.awg_dnsreload ] && [ $_i -lt 60 ]; do sleep 1; _i=$((_i + 1)); done
_i=0; while ! pidof dnsmasq >/dev/null 2>&1 && [ $_i -lt 15 ]; do service restart_dnsmasq >/dev/null 2>&1; sleep 2; _i=$((_i + 1)); done
rm -f /opt/bin/awg
rm -rf /opt/amneziawg
exit 0
PRERMEOF
    chmod 755 "$CONTROL_DIR/prerm"

    : > "$CONTROL_DIR/conffiles"

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
    cp addon/amneziawg_widget.js     "$DATA_DIR/jffs/addons/amneziawg/amneziawg_widget.js"

    chmod 755 "$DATA_DIR/opt/amneziawg/amneziawg-go"
    chmod 755 "$DATA_DIR/opt/amneziawg/awg"
    chmod 755 "$DATA_DIR/jffs/addons/amneziawg/amneziawg.sh"
    chmod 644 "$DATA_DIR/jffs/addons/amneziawg/amneziawg_page.asp"
    chmod 644 "$DATA_DIR/jffs/addons/amneziawg/amneziawg_widget.js"

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
    update)
        /jffs/addons/amneziawg/amneziawg.sh update "$2"
        ;;
    diag)
        /jffs/addons/amneziawg/amneziawg.sh diag
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|update [version]|diag}"
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

# Build arm (ARM32) — RT-AC68U, RT-AC66U and other Cortex-A9 / armv7-2.6 routers.
# Both the Go daemon (GOARM=5) AND the awg tool (awg-arm5) are built to the lowest
# common denominator here: the shared armv7 awg-arm below is an Alpine linux/arm/v7
# build (ARMv7-A, emits NEON + hardware divide udiv/sdiv) and dies with "Illegal
# instruction" on the Cortex-A9, which lacks those. awg-arm5 is an ARMv6 build (a
# strict subset that also runs on every newer ARMv7 core).
build_ipk "armv7-2.6" "output/amneziawg-go-arm5" "output/awg-arm5" || true

# Build arm (ARM32, newer Entware/HND) — RT-AX56U, RT-AX58U, etc.
build_ipk "armv7-3.2" "output/amneziawg-go-arm" "output/awg-arm" || true

echo ""
echo "Done. Install on router:"
echo "  scp output/<package>.ipk admin@<router>:/tmp/"
echo "  opkg install /tmp/<package>.ipk"
