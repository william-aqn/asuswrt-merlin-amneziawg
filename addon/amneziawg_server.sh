#!/bin/sh
# =============================================================
# AmneziaWG SERVER role for Asuswrt-Merlin
# Road-warrior access to the home LAN + optional per-peer policy
# routing (double hop through the CLIENT tunnel awg0).
#
# This script owns ONLY the server instance (iface awgs0, its own
# daemon process named awgs-go, its own lock/log/status files).
# All hardened shared helpers come from amneziawg.sh, sourced in
# LIB MODE below — fixes to launch_daemon/locks/reload_dnsmasq
# flow into both roles automatically.
#
# Settings prefix: awgs_ (deliberately NOT matched by ^awg_).
# Peer store: awgs_peers (+ awgs_peers1..N overflow chunks, the
# awg_initdata ~2900-chars-per-value convention). One entry per
# peer, ';'-separated; fields '|'-separated:
#   name|ip|policy|mode|enabled|pubkey|privkey|psk
#   - policy: direct | vpn_all | vpn_geo | vpn_geo_<id>  (per-peer
#     routing through the CLIENT tunnel — consumed by amneziawg.sh's
#     server_peer_policy_entries; fail-OPEN when the client is down)
#   - mode:   full | lan   (AllowedIPs of the GENERATED peer config;
#     informational here — the page builds the .conf/QR client-side)
#   - privkey/psk are stored so the page can re-show the QR later
#     (same trust model as the client page's own keys in
#     custom_settings).
# =============================================================

ADDON_DIR="/jffs/addons/amneziawg"

# --- Shared helper library (hardened client script in lib mode) ---
if [ ! -f "$ADDON_DIR/amneziawg.sh" ]; then
    logger -t "awg-server" "ERROR: $ADDON_DIR/amneziawg.sh missing — cannot run the server role"
    exit 1
fi
AWG_LIB_MODE=1
. "$ADDON_DIR/amneziawg.sh"
unset AWG_LIB_MODE

# --- Instance overrides (every shared helper below operates on THESE) ---
SCRIPT_NAME="awg-server"            # logger tag; the client's log grep ("amneziawg") won't match it
IFACE="awgs0"
AWGS_DIR="$AWG_DIR/server"          # /opt/amneziawg/server
CONF="$AWGS_DIR/awgs0.conf"
STATUS_FILE="/www/user/awgs_status.htm"
UI_LOG="/www/user/awgs_log.htm"
DIAG_FILE="/www/user/awgs_diag.htm"
LOCKDIR="/tmp/.awgs_lock"
DAEMON_LOG="/tmp/awgs_daemon.log"
DAEMON_RC="/tmp/awgs_daemon.rc"
STARTING_FLAG="/tmp/.awgs_starting"
STOPPING_FLAG="/tmp/.awgs_stopping"
# The server daemon runs under its OWN process name (hardlink to the same binary): the
# client's hardened teardown/watchdog paths do blanket `kill $(pidof amneziawg-go)` /
# `wait_for_pid_exit amneziawg-go` — a second daemon under that name would be killed by
# every client stop/start. `pidof awgs-go` and `pidof amneziawg-go` are disjoint, so the
# two instances can't touch each other. Short name (7 chars) — safely under the kernel's
# 15-char comm truncation that busybox pidof compares against.
AWG_GO_SRV="$AWG_DIR/awgs-go"
AWG_GO="$AWG_GO_SRV"
# Last successfully-installed listen port — teardown drains THIS one, so a port change in
# the UI can't orphan the old INPUT accept rule. tmpfs: reboot clears rules and file alike.
AWGS_PORT_STATE="/tmp/.awgs_port"

# =============================================================
# Settings & config
# =============================================================

# Listen port (default 51821 — one above the WireGuard convention so a firmware WG server
# on 51820 doesn't collide out of the box).
srv_port(){
    local p
    p=$(get_setting awgs_port)
    validate_port "$p" || p=51821
    echo "$p"
}

# Tunnel subnet, strict "x.y.z.0/24" form (v1 keeps the math trivial: router = .1, peers
# .2-.254). Invalid/absent -> the 10.9.0.0/24 default.
srv_subnet(){
    local s
    s=$(get_setting awgs_subnet)
    case "$s" in
        *.*.*.0/24) validate_ip "${s%/24}" || s="" ;;
        *) s="" ;;
    esac
    [ -z "$s" ] && s="10.9.0.0/24"
    echo "$s"
}

# Router's address inside the tunnel ("10.9.0.1").
srv_router_ip(){
    local net
    net=$(srv_subnet); net="${net%.0/24}"
    echo "${net}.1"
}

# Reassembled peer store (chunks joined), one entry per line.
srv_peers_raw(){
    local raw _i _chunk
    raw=$(get_setting awgs_peers)
    [ -z "$raw" ] && return 0
    _i=1
    while [ "$_i" -le 10 ]; do
        _chunk=$(get_setting "awgs_peers${_i}")
        [ -z "$_chunk" ] && break
        raw="${raw}${_chunk}"
        _i=$((_i + 1))
    done
    printf '%s\n' "$raw" | tr ';' '\n' | grep -v '^[[:space:]]*$'
}

# Best public name for the generated peer configs / the status hint: the firmware DDNS
# hostname when enabled, else the current WAN IP. The page shows it and warns when it is
# private/CGNAT (the server can't take inbound connections behind one).
srv_endpoint_hint(){
    local h
    if [ "$(nvram get ddns_enable_x 2>/dev/null)" = "1" ]; then
        h=$(nvram get ddns_hostname_x 2>/dev/null)
        [ -n "$h" ] && { echo "$h"; return 0; }
    fi
    nvram get wan0_ipaddr 2>/dev/null
}

# Is the WAN address private/CGNAT? (10/8, 172.16/12, 192.168/16, 100.64/10 -> "1")
srv_wan_private(){
    local ip o2
    ip=$(nvram get wan0_ipaddr 2>/dev/null)
    validate_ip "$ip" || { echo 0; return; }
    case "$ip" in
        10.*|192.168.*) echo 1; return ;;
        172.*)
            o2=${ip#172.}; o2=${o2%%.*}
            [ "$o2" -ge 16 ] 2>/dev/null && [ "$o2" -le 31 ] 2>/dev/null && { echo 1; return; } ;;
        100.*)
            o2=${ip#100.}; o2=${o2%%.*}
            [ "$o2" -ge 64 ] 2>/dev/null && [ "$o2" -le 127 ] 2>/dev/null && { echo 1; return; } ;;
    esac
    echo 0
}

# Firmware WireGuard server on the same UDP port? ("1" when wgs is enabled on our port)
srv_port_conflict(){
    local p
    p=$(srv_port)
    if [ "$(nvram get wgs_enable 2>/dev/null)" = "1" ] && [ "$(nvram get wgs_port 2>/dev/null)" = "$p" ]; then
        echo 1; return
    fi
    echo 0
}

# Strict IPv4 (octets 0-255). The shared validate_ip checks only the x.x.x.x SHAPE — a
# hand-edited 999.9.9.9 passes it, and ONE such AllowedIPs line makes setconf reject the
# WHOLE config, taking every peer down. So peers get the strict check.
srv_valid_ip4(){
    echo "$1" | grep -qE '^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$'
}

# Generate awgs0.conf from awgs_* settings: [Interface] with the obfuscation params +
# one [Peer] per ENABLED stored peer (AllowedIPs = its /32). Validation mirrors the
# client's generate_config via the same shared validate_* helpers.
srv_generate_config(){
    umask 077
    mkdir -p "$AWGS_DIR"

    local privkey port jc jmin jmax s1 s2 s3 s4 h1 h2 h3 h4
    privkey=$(get_setting awgs_privkey)
    port=$(srv_port)
    jc=$(get_setting awgs_jc); jmin=$(get_setting awgs_jmin); jmax=$(get_setting awgs_jmax)
    s1=$(get_setting awgs_s1); s2=$(get_setting awgs_s2)
    s3=$(get_setting awgs_s3); s4=$(get_setting awgs_s4)
    h1=$(get_setting awgs_h1); h2=$(get_setting awgs_h2)
    h3=$(get_setting awgs_h3); h4=$(get_setting awgs_h4)

    if [ -z "$privkey" ]; then
        log_msg "ERROR: server private key is not set — save the server settings first"
        return 1
    fi
    validate_wgkey "$privkey" || return 1
    [ -n "$jc" ]   && { validate_uint "$jc"    || { log_msg "ERROR: Invalid Jc: $jc"; return 1; }; }
    [ -n "$jmin" ] && { validate_uint "$jmin"  || { log_msg "ERROR: Invalid Jmin: $jmin"; return 1; }; }
    [ -n "$jmax" ] && { validate_uint "$jmax"  || { log_msg "ERROR: Invalid Jmax: $jmax"; return 1; }; }
    [ -n "$s1" ]   && { validate_uint "$s1"    || { log_msg "ERROR: Invalid S1: $s1"; return 1; }; }
    [ -n "$s2" ]   && { validate_uint "$s2"    || { log_msg "ERROR: Invalid S2: $s2"; return 1; }; }
    [ -n "$s3" ]   && { validate_uint "$s3"    || { log_msg "ERROR: Invalid S3: $s3"; return 1; }; }
    [ -n "$s4" ]   && { validate_uint "$s4"    || { log_msg "ERROR: Invalid S4: $s4"; return 1; }; }
    [ -n "$h1" ]   && { validate_header "$h1"  || { log_msg "ERROR: Invalid H1: $h1"; return 1; }; }
    [ -n "$h2" ]   && { validate_header "$h2"  || { log_msg "ERROR: Invalid H2: $h2"; return 1; }; }
    [ -n "$h3" ]   && { validate_header "$h3"  || { log_msg "ERROR: Invalid H3: $h3"; return 1; }; }
    [ -n "$h4" ]   && { validate_header "$h4"  || { log_msg "ERROR: Invalid H4: $h4"; return 1; }; }

    # I1-I5: chunked base64 (awgs_initdata + awgs_initdata1 + …), decoded to "In = <...>"
    # lines — the exact convention the client page/backend already use for awg_initdata.
    local i1="" i2="" i3="" i4="" i5="" initdata _ic _ichunk decoded
    initdata=$(get_setting awgs_initdata)
    _ic=1
    while [ "$_ic" -le 30 ]; do
        _ichunk=$(get_setting "awgs_initdata${_ic}")
        [ -z "$_ichunk" ] && break
        initdata="${initdata}${_ichunk}"
        _ic=$((_ic + 1))
    done
    if [ -n "$initdata" ]; then
        decoded=$(echo "$initdata" | base64 -d 2>/dev/null)
        i1=$(echo "$decoded" | awk '/^I1 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i2=$(echo "$decoded" | awk '/^I2 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i3=$(echo "$decoded" | awk '/^I3 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i4=$(echo "$decoded" | awk '/^I4 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i5=$(echo "$decoded" | awk '/^I5 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
    fi
    local _in _iv
    for _in in 1 2 3 4 5; do
        eval "_iv=\$i$_in"
        [ -n "$_iv" ] && { validate_iparam "$_iv" || { log_msg "ERROR: I$_in looks truncated/malformed (unbalanced <> or no closing '>')"; return 1; }; }
    done

    {
        echo "[Interface]"
        echo "PrivateKey = $privkey"
        echo "ListenPort = $port"
        [ -n "$jc" ]   && echo "Jc = $jc"
        [ -n "$jmin" ] && echo "Jmin = $jmin"
        [ -n "$jmax" ] && echo "Jmax = $jmax"
        [ -n "$s1" ]   && echo "S1 = $s1"
        [ -n "$s2" ]   && echo "S2 = $s2"
        [ -n "$s3" ]   && echo "S3 = $s3"
        [ -n "$s4" ]   && echo "S4 = $s4"
        [ -n "$h1" ]   && echo "H1 = $h1"
        [ -n "$h2" ]   && echo "H2 = $h2"
        [ -n "$h3" ]   && echo "H3 = $h3"
        [ -n "$h4" ]   && echo "H4 = $h4"
        [ -n "$i1" ]   && echo "I1 = $i1"
        [ -n "$i2" ]   && echo "I2 = $i2"
        [ -n "$i3" ]   && echo "I3 = $i3"
        [ -n "$i4" ]   && echo "I4 = $i4"
        [ -n "$i5" ]   && echo "I5 = $i5"
    } > "$CONF"

    # One [Peer] per ENABLED stored peer. Keys are validated per-peer; a malformed entry is
    # SKIPPED with a named log line (one broken peer must not take the whole server down).
    local _added=0
    srv_peers_raw | while IFS='|' read -r p_name p_ip p_policy p_mode p_enabled p_pub p_priv p_psk; do
        [ "$p_enabled" = "1" ] || continue
        srv_valid_ip4 "$p_ip" || { log_msg "WARNING: peer '$p_name' skipped — bad tunnel IP '$p_ip'"; continue; }
        echo "$p_pub" | grep -qE '^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$' || { log_msg "WARNING: peer '$p_name' skipped — bad public key"; continue; }
        {
            echo ""
            echo "[Peer]"
            echo "PublicKey = $p_pub"
            if [ -n "$p_psk" ]; then
                if echo "$p_psk" | grep -qE '^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$'; then
                    echo "PresharedKey = $p_psk"
                else
                    log_msg "WARNING: peer '$p_name' — bad PSK ignored (connecting without it will fail if the client config carries one)"
                fi
            fi
            echo "AllowedIPs = ${p_ip}/32"
        } >> "$CONF"
    done
    # NB: the while above runs in a pipeline subshell — $_added would not survive it, so the
    # "any peers?" signal is re-derived from the file itself.
    _added=$(grep -c '^\[Peer\]' "$CONF" 2>/dev/null)

    chmod 600 "$CONF"
    log_msg "Server config saved (port $(srv_port), subnet $(srv_subnet), peers: ${_added:-0})"
    return 0
}

# =============================================================
# Firewall
# =============================================================

# Default-route egress device (WAN): where peer traffic NATs out when its policy is direct.
srv_wan_iface(){
    ip route 2>/dev/null | awk '/^default/{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}'
}

srv_setup_firewall(){
    local port subnet wan_if
    port=$(srv_port)
    subnet=$(srv_subnet)
    wan_if=$(srv_wan_iface)

    # Inbound handshake/data: one UDP port, -C-guarded like every add in this repo.
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT -p udp --dport "$port" -j ACCEPT
    echo "$port" > "$AWGS_PORT_STATE" 2>/dev/null

    # Peer traffic through the router (LAN access + forwarding toward WAN/awg0).
    iptables -C INPUT -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "$IFACE" -j ACCEPT

    # MSS clamp both ways: peers add tunnel overhead, and a vpn_all peer chains через awg0
    # (double tunnel) — clamp-to-pmtu covers both single- and double-hop paths.
    iptables -t mangle -C FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -C FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    # NAT per egress (deliberately NOT a blanket `-s subnet -j MASQUERADE`: that would also
    # rewrite hairpinned peer<->peer traffic exiting back via awgs0 and hide peer identity):
    #  - WAN: internet access for direct-policy peers;
    #  - awg0: the double hop — the CLIENT's own masquerade is scoped to the LAN subnet, so
    #    peer sources need their own rule to leave through the tunnel;
    #  - br0 (optional, awgs_nat_lan=1 default): peers masquerade as the ROUTER's LAN IP, so
    #    Windows-firewall "LocalSubnet"-scoped machines answer them (the classic road-warrior
    #    silence). Off = peers keep their 10.9.x identity toward the LAN.
    [ -n "$wan_if" ] && { iptables -t nat -C POSTROUTING -s "$subnet" -o "$wan_if" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -I POSTROUTING -s "$subnet" -o "$wan_if" -j MASQUERADE; }
    iptables -t nat -C POSTROUTING -s "$subnet" -o awg0 -j MASQUERADE 2>/dev/null \
        || iptables -t nat -I POSTROUTING -s "$subnet" -o awg0 -j MASQUERADE
    if [ "$(get_setting awgs_nat_lan)" != "0" ]; then
        iptables -t nat -C POSTROUTING -s "$subnet" -o br0 -j MASQUERADE 2>/dev/null \
            || iptables -t nat -I POSTROUTING -s "$subnet" -o br0 -j MASQUERADE
    else
        ipt_drain -t nat -D POSTROUTING -s "$subnet" -o br0 -j MASQUERADE
    fi
}

srv_cleanup_firewall(){
    local port subnet wan_if
    # Drain the port rule for BOTH the recorded active port and the current setting — a port
    # changed in the UI between start and stop must not orphan the old accept.
    port=$(cat "$AWGS_PORT_STATE" 2>/dev/null)
    [ -n "$port" ] && ipt_drain -D INPUT -p udp --dport "$port" -j ACCEPT
    port=$(srv_port)
    ipt_drain -D INPUT -p udp --dport "$port" -j ACCEPT
    rm -f "$AWGS_PORT_STATE" 2>/dev/null

    ipt_drain -D INPUT -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -o "$IFACE" -j ACCEPT
    ipt_drain -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ipt_drain -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    subnet=$(srv_subnet)
    wan_if=$(srv_wan_iface)
    [ -n "$wan_if" ] && ipt_drain -t nat -D POSTROUTING -s "$subnet" -o "$wan_if" -j MASQUERADE
    ipt_drain -t nat -D POSTROUTING -s "$subnet" -o awg0 -j MASQUERADE
    ipt_drain -t nat -D POSTROUTING -s "$subnet" -o br0 -j MASQUERADE
}

# =============================================================
# Lifecycle
# =============================================================

# The server daemon binary: a HARDLINK to amneziawg-go under its own name (see AWG_GO_SRV).
# Recreated on every start — a package update replaces amneziawg-go with a new inode and a
# stale link would silently keep running the OLD build. Falls back to a copy if the link
# fails (link always works here: same dir, same fs; the cp is belt-and-suspenders).
srv_ensure_binary(){
    [ -s "$AWG_DIR/amneziawg-go" ] || { log_msg "ERROR: $AWG_DIR/amneziawg-go missing/empty — reinstall the package"; return 1; }
    rm -f "$AWG_GO_SRV" 2>/dev/null
    ln "$AWG_DIR/amneziawg-go" "$AWG_GO_SRV" 2>/dev/null || cp "$AWG_DIR/amneziawg-go" "$AWG_GO_SRV" 2>/dev/null
    chmod +x "$AWG_GO_SRV" 2>/dev/null
    [ -s "$AWG_GO_SRV" ] && [ -x "$AWG_GO_SRV" ]
}

# Poke the CLIENT script to rebuild its policy rules (it reads our peer store via
# server_peer_policy_entries). Detached: setup_firewall can take seconds (geo reload) and
# our service-event handler must return promptly. No-op while the client tunnel is down.
srv_poke_policies(){
    ( sh "$ADDON_DIR/amneziawg.sh" apply_policies >/dev/null 2>&1 ) </dev/null >/dev/null 2>&1 &
}

srv_any_policy_peer(){
    srv_peers_raw | awk -F'|' 'NF>=5 && $5=="1" && $3!="" && $3!="direct" {found=1; exit} END{exit found?0:1}'
}

do_srv_start(){
    [ -f /tmp/.awg_no_autostart ] && { log_msg "Server start blocked: update in progress"; return 0; }

    if is_running; then
        log_msg "Server already running"
        srv_update_status
        return 0
    fi

    # No CTF hard-block here: the server role installs NO policy ip-rules and NO fwmark —
    # the exact machinery that wedges CTF boxes. Per-peer policy rules are the CLIENT
    # script's, and its own do_start refuses under CTF. Still worth a breadcrumb:
    if ctf_active; then
        log_msg "NOTE: Broadcom CTF is ON. The server role itself avoids the policy-routing that wedges CTF boxes, but per-peer VPN policies will only apply once the client tunnel runs (which requires CTF off)."
    fi

    touch "$STARTING_FLAG"
    trap 'rm -f "$STARTING_FLAG"; srv_update_status' EXIT INT TERM
    srv_update_status

    if ! ip -4 addr show br0 2>/dev/null | grep -q "inet "; then
        log_msg "Waiting for network (br0)..."
        wait_for_iface_ip br0 30
    fi

    acquire_lock || { log_msg "Cannot acquire server lock, aborting start"; srv_update_status; return 1; }
    if is_running; then
        log_msg "Server already running (a concurrent start finished first)"
        release_lock
        return 0
    fi

    srv_generate_config || { srv_update_status; release_lock; return 1; }
    srv_ensure_binary   || { srv_update_status; release_lock; return 1; }
    if [ ! -s "$AWG_BIN" ]; then
        log_msg "ERROR: awg tool missing/empty ($AWG_BIN) — reinstall the package"
        srv_update_status; release_lock; return 1
    fi

    # TUN prerequisites (same steps as the client start — old boxes don't autoload tun).
    if ! lsmod 2>/dev/null | grep -q "^tun "; then
        modprobe tun 2>/dev/null || log_msg "WARNING: modprobe tun failed (module missing or modprobe not on PATH)"
    fi
    mkdir -p /dev/net
    [ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
    mkdir -p /var/run/amneziawg

    # Clean slate for OUR instance only (pidof awgs-go can never match the client daemon).
    if pidof awgs-go >/dev/null 2>&1; then
        log_msg "Clearing stale awgs-go before start"
        kill $(pidof awgs-go) 2>/dev/null
        wait_for_pid_exit awgs-go 5
        pidof awgs-go >/dev/null 2>&1 && kill -9 $(pidof awgs-go) 2>/dev/null
    fi
    ip link del "$IFACE" 2>/dev/null
    rm -f /var/run/amneziawg/"$IFACE".sock 2>/dev/null

    log_msg "Go runtime cap: GOMEMLIMIT=$(compute_go_memlimit) GOGC=$AWG_GOGC"
    launch_daemon
    if ! wait_for_iface "$IFACE" 10; then
        local drc dgist
        drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' $DAEMON_RC 2>/dev/null)
        log_msg "ERROR: server daemon failed to create $IFACE (rc=${drc:-none — still running/hung})"
        dgist=$(daemon_log_gist 6 | tr '\n' '|')
        [ -n "$dgist" ] && log_msg "  daemon said: $dgist"
        pidof awgs-go >/dev/null 2>&1 && { kill $(pidof awgs-go) 2>/dev/null; wait_for_pid_exit awgs-go 5; }
        ip link del "$IFACE" 2>/dev/null
        log_msg "  retrying once with LOG_LEVEL=verbose..."
        launch_daemon verbose
        if ! wait_for_iface "$IFACE" 10; then
            drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' $DAEMON_RC 2>/dev/null)
            dgist=$(daemon_log_gist 8 | tr '\n' '|')
            log_msg "  verbose retry failed too (rc=${drc:-none}); daemon output: ${dgist:-<nothing after the banner>}"
            pidof awgs-go >/dev/null 2>&1 && kill $(pidof awgs-go) 2>/dev/null
            srv_update_status; release_lock; return 1
        fi
        log_msg "  verbose retry succeeded — continuing start"
    fi

    # setconf with the same UAPI-race handling as the client (short retries, stderr kept,
    # one verbose relaunch to NAME a rejected obfuscation param).
    wait_for_uapi "$IFACE" 15 || log_msg "WARNING: UAPI control socket not ready after 15s — trying setconf anyway"
    local sc_rc=1 sc_try=0 sc_err=""
    while [ $sc_try -lt 5 ]; do
        sc_err=$("$AWG_BIN" setconf "$IFACE" "$CONF" 2>&1)
        sc_rc=$?
        { [ "$sc_rc" -eq 0 ] || [ "$sc_rc" -eq 132 ]; } && break
        sc_try=$((sc_try + 1))
        sleep 1
    done
    if [ "$sc_rc" -ne 0 ]; then
        log_msg "ERROR: server setconf failed (exit $sc_rc): ${sc_err:-<no stderr>}"
        if [ "$sc_rc" -ne 132 ]; then
            kill $(pidof awgs-go) 2>/dev/null; wait_for_pid_exit awgs-go 5
            ip link del "$IFACE" 2>/dev/null
            launch_daemon verbose
            if wait_for_iface "$IFACE" 5 && wait_for_uapi "$IFACE" 8; then
                "$AWG_BIN" setconf "$IFACE" "$CONF" >/dev/null 2>&1
                local vrej
                vrej=$(grep -iE 'fail|invalid|error|parse|unable|reject|must be|overlap|not.*valid' $DAEMON_LOG 2>/dev/null \
                       | grep -ivF 'first class support' | head -3 | tr '\n' '|')
                [ -n "$vrej" ] && log_msg "  verbose reject: $vrej"
            fi
        fi
        ip link del "$IFACE" 2>/dev/null
        pidof awgs-go >/dev/null 2>&1 && kill $(pidof awgs-go) 2>/dev/null
        srv_update_status; release_lock; return 1
    fi

    # Address / MTU / up. The /24 route in the MAIN table appears automatically with the
    # address — that is what routes LAN->peer replies back into the tunnel.
    ip addr add "$(srv_router_ip)/24" dev "$IFACE" 2>/dev/null
    local mtu
    mtu=$(get_setting awgs_mtu)
    { [ -n "$mtu" ] && validate_uint "$mtu" && [ "$mtu" -ge 576 ] && [ "$mtu" -le 1500 ]; } || mtu=1420
    ip link set "$IFACE" mtu "$mtu"
    ip link set "$IFACE" up

    # Loose rp_filter on our iface: policied peers' return traffic arrives asymmetrically
    # when it chains through awg0. Scoped to awgs0 only — the /proc entry (and the setting)
    # vanishes with the interface, so there is nothing to restore on stop.
    echo 2 > "/proc/sys/net/ipv4/conf/$IFACE/rp_filter" 2>/dev/null

    srv_setup_firewall

    # Hairpin route for vpn_all sources (see setup_firewall's twin add): whichever side
    # comes up second wins; dev-scoped so it purges itself when awgs0 goes.
    ip route add "$(srv_subnet)" dev "$IFACE" table $RT_TABLE 2>/dev/null

    # dnsmasq: the postconf hook appends interface=awgs0 ONLY while the iface exists, so a
    # real restart is needed to (re)bind — clear the skip-signature first or reload_dnsmasq
    # may decide the conf is unchanged and skip it.
    rm -f "$DNSRELOAD_SIG"
    reload_dnsmasq

    # Self-heal + live status (mirrors the client cron lifecycle: removed on user stop).
    cru a awgs_watchdog "*/5 * * * * '$ADDON_DIR/amneziawg_server.sh' watchdog"
    cru a awgs_status "*/1 * * * * '$ADDON_DIR/amneziawg_server.sh' status"

    # Per-peer policies live in the CLIENT's firewall — poke it to re-read the peer store.
    srv_any_policy_peer && srv_poke_policies

    [ "$(srv_wan_private)" = "1" ] && log_msg "WARNING: WAN address $(nvram get wan0_ipaddr 2>/dev/null) is private/CGNAT — peers from the internet will NOT reach this server (need a public IP or port forwarding on the upstream router)"
    [ "$(srv_port_conflict)" = "1" ] && log_msg "WARNING: firmware WireGuard server is enabled on the same UDP port $(srv_port) — change one of the ports"

    log_msg "Server started: port $(srv_port), subnet $(srv_subnet), endpoint hint $(srv_endpoint_hint)"
    srv_update_status
    release_lock
}

do_srv_stop(){
    local user_stop="$1"
    acquire_lock || { log_msg "Cannot acquire server lock, aborting stop"; return 1; }
    rm -f "$STARTING_FLAG"
    touch "$STOPPING_FLAG"
    srv_update_status

    srv_cleanup_firewall

    [ "$user_stop" = "user" ] && cru d awgs_watchdog 2>/dev/null
    [ "$user_stop" = "user" ] && cru d awgs_status 2>/dev/null

    local pid
    pid=$(pidof awgs-go 2>/dev/null)
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null
        wait_for_pid_exit awgs-go 5
        pidof awgs-go >/dev/null 2>&1 && kill -9 $(pidof awgs-go) 2>/dev/null
    fi
    ip link set "$IFACE" down 2>/dev/null
    ip link del "$IFACE" 2>/dev/null
    rm -f /var/run/amneziawg/"$IFACE".sock
    # (table-300 hairpin + the main-table /24 are dev-scoped — the kernel purged them.)

    # Drop the interface=awgs0 dnsmasq line (postconf omits it now that the iface is gone).
    rm -f "$DNSRELOAD_SIG"
    reload_dnsmasq

    log_msg "Server stopped"
    rm -f "$STOPPING_FLAG"
    srv_update_status
    release_lock
}

do_srv_restart(){
    do_srv_stop
    touch "$STARTING_FLAG"
    srv_update_status
    wait_for_pid_exit awgs-go 10
    do_srv_start
}

# Boot entry (S99): opt-in via awgs_autostart=1 — a server that opens a WAN port must never
# appear by itself after a firmware/package operation the user didn't intend it for.
do_srv_boot_start(){
    is_running && { do_srv_start; return 0; }
    if [ "$(get_setting awgs_autostart)" = "1" ] && [ -n "$(get_setting awgs_privkey)" ]; then
        do_srv_start
    else
        srv_update_status
    fi
}

# Apply saved settings to a RUNNING server without dropping every peer when possible:
# syncconf diffs the conf (peer add/remove, params); a changed subnet/address needs the
# full restart. Firewall re-applied either way (port may have changed; old port drained).
do_srv_apply(){
    if ! is_running; then
        # Not running: just validate + persist the generated conf so errors surface now.
        srv_generate_config
        srv_update_status
        srv_any_policy_peer && srv_poke_policies
        return 0
    fi
    local cur_ip want_ip
    cur_ip=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}')
    want_ip=$(srv_router_ip)
    if [ "$cur_ip" != "$want_ip" ]; then
        log_msg "Subnet changed ($cur_ip -> $want_ip) — full server restart"
        do_srv_restart
        srv_poke_policies
        return 0
    fi
    acquire_lock || { log_msg "Cannot acquire server lock for apply"; return 1; }
    if ! srv_generate_config; then
        srv_update_status; release_lock; return 1
    fi
    local sync_err
    sync_err=$("$AWG_BIN" syncconf "$IFACE" "$CONF" 2>&1)
    if [ $? -ne 0 ]; then
        log_msg "syncconf failed (${sync_err:-no stderr}) — falling back to a full restart"
        release_lock
        do_srv_restart
        srv_poke_policies
        return 0
    fi
    srv_cleanup_firewall
    srv_setup_firewall
    ip route add "$(srv_subnet)" dev "$IFACE" table $RT_TABLE 2>/dev/null
    log_msg "Server settings applied (syncconf)"
    srv_update_status
    release_lock
    srv_poke_policies
}

# =============================================================
# Watchdog / status
# =============================================================

do_srv_watchdog(){
    date '+%Y-%m-%d %H:%M:%S' > /tmp/.awgs_wd_beat 2>/dev/null

    # Stand down during a package update (same shared flag + staleness rule as the client;
    # the 15-min reclaim keeps a died updater from disabling self-heal forever).
    if [ -f /tmp/.awg_no_autostart ]; then
        [ -z "$(find /tmp/.awg_no_autostart -mmin +15 2>/dev/null)" ] && return 0
        rm -f /tmp/.awg_no_autostart
    fi

    # Busy/stale lock handling (alive holder -> busy; dead holder -> reclaim).
    if [ -d "$LOCKDIR" ]; then
        local _lp
        _lp=$(cat "$LOCKDIR/pid" 2>/dev/null)
        if [ -n "$_lp" ] && kill -0 "$_lp" 2>/dev/null; then
            return 0
        fi
        if [ -z "$_lp" ]; then
            [ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +5 2>/dev/null)" ] || return 0
        fi
        log_msg "WATCHDOG: stale server lock (holder ${_lp:-unknown} is gone) — reclaiming"
        rm -rf "$LOCKDIR"
    fi

    if ! iface_exists "$IFACE" || ! pidof awgs-go >/dev/null 2>&1; then
        log_msg "WATCHDOG: server down ($IFACE missing or awgs-go dead), restarting"
        do_srv_stop 2>/dev/null
        wait_for_pid_exit awgs-go 10
        do_srv_start
        return
    fi

    # A firmware firewall restart flushes filter/nat — re-assert our rules (idempotent -C
    # adds; also re-adds the table-300 hairpin the same way).
    local port
    port=$(srv_port)
    if ! iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null; then
        log_msg "WATCHDOG: server firewall rules missing (firewall restarted?) — re-applying"
        srv_setup_firewall
        ip route add "$(srv_subnet)" dev "$IFACE" table $RT_TABLE 2>/dev/null
    fi
}

# Re-apply rules after a firmware firewall restart (firewall-start hook; cheap fast-path).
do_srv_firewall_restart(){
    is_running || return 0
    local port
    port=$(srv_port)
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null && return 0
    log_msg "Firewall restart detected — re-applying server rules"
    srv_setup_firewall
    ip route add "$(srv_subnet)" dev "$IFACE" table $RT_TABLE 2>/dev/null
}

# Status JSON for the server page. Peers = the STORE (every configured peer), enriched with
# live handshake/transfer from `awg show dump` when running (joined by public key).
srv_update_status(){
    local running=false starting=false stopping=false
    is_running && running=true
    [ -f "$STARTING_FLAG" ] && starting=true
    [ -f "$STOPPING_FLAG" ] && stopping=true

    local port subnet router_ip pubkey
    port=$(srv_port)
    subnet=$(srv_subnet)
    router_ip=$(srv_router_ip)
    pubkey=$(get_setting awgs_pubkey)
    if [ "$running" = "true" ]; then
        local live_pub
        live_pub=$("$AWG_BIN" show "$IFACE" public-key 2>/dev/null)
        [ -n "$live_pub" ] && pubkey="$live_pub"
    fi

    # Live peer telemetry, tab-separated: pub<TAB>endpoint<TAB>hs<TAB>rx<TAB>tx
    local dump=""
    [ "$running" = "true" ] && dump=$("$AWG_BIN" show "$IFACE" dump 2>/dev/null | tail -n +2)

    # peers_json: store entries (name/ip/policy/mode/enabled/pub) + live fields by pubkey.
    # ORDER MATTERS: the live "D" (dump) lines MUST be emitted BEFORE the "S" (store) lines,
    # so the ep/hs/rx/tx lookup arrays are already populated when each S row is rendered.
    # Emitting S first left every peer's live fields at their "" / 0 defaults (endpoint/
    # handshake/transfer never showed in the UI) — caught on real hardware, a connected peer
    # read hs_epoch:0 while `awg show` showed a 58s-old handshake + 2 MiB transferred.
    local peers_json
    peers_json=$( { printf '%s\n' "$dump" | awk -F'\t' 'NF>=7 {print "D\t"$1"\t"$3"\t"$5"\t"$6"\t"$7}'
                    srv_peers_raw | awk -F'|' 'NF>=6 {print "S\t"$1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6}'
                  } | awk -F'\t' '
        $1=="D" { ep[$2]=$3; hs[$2]=$4; rx[$2]=$5; tx[$2]=$6; next }
        $1=="S" {
            n++
            name=$2; gsub(/\\/,"",name); gsub(/"/,"",name)
            pub=$7
            e=(pub in ep)?ep[pub]:""
            if (e=="(none)") e=""
            h=(pub in hs)?hs[pub]:0
            r=(pub in rx)?rx[pub]:0
            t=(pub in tx)?tx[pub]:0
            if (h !~ /^[0-9]+$/) h=0
            if (r !~ /^[0-9]+$/) r=0
            if (t !~ /^[0-9]+$/) t=0
            item="{\"name\":\"" name "\",\"ip\":\"" $3 "\",\"policy\":\"" $4 "\",\"mode\":\"" $5 "\",\"enabled\":" (($6=="1")?"true":"false") ",\"pub\":\"" pub "\",\"endpoint\":\"" e "\",\"hs_epoch\":" h ",\"rx_bytes\":" r ",\"tx_bytes\":" t "}"
            out=out (n>1?",":"") item
        }
        END { print "[" out "]" }')
    [ -n "$peers_json" ] || peers_json="[]"

    local log_text
    log_text=$(grep "awg-server" /tmp/syslog.log 2>/dev/null | tail -20 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

    local client_running=false
    iface_exists awg0 && client_running=true

    local pref_lang
    pref_lang=$(nvram get preferred_lang 2>/dev/null)
    [ -z "$pref_lang" ] && pref_lang="EN"

    local ep_hint wan_priv port_conf nat_lan autostart
    ep_hint=$(srv_endpoint_hint | sed 's/"/\\"/g')
    wan_priv=$(srv_wan_private)
    port_conf=$(srv_port_conflict)
    nat_lan=true; [ "$(get_setting awgs_nat_lan)" = "0" ] && nat_lan=false
    autostart=false; [ "$(get_setting awgs_autostart)" = "1" ] && autostart=true

    # Reverse-coexistence: a transparent proxy (xray/XRAYUI in TPROXY "redirect all" mode)
    # captures the router's OWN egress via an ip-rule at prio 19 (fwmark 0x10000 -> table 77),
    # which sits AHEAD of the per-peer VPN-policy rule (prio 99) — so a vpn_all/vpn_geo peer's
    # double-hop through the client tunnel is stolen by xray, and even direct peers can be
    # grabbed. Surface it so the page warns + offers a one-click stop (routed to the client
    # script's do_xray_stop via the awgxraystop event, which uses xrayui's own cleanup).
    local xray_capture=false xray_ctl=false
    xray_redirect_active && xray_capture=true
    [ -x /jffs/scripts/xrayui ] && xray_ctl=true

    rm -f "${STATUS_FILE}.tmp" "${STATUS_FILE}".[0-9]* 2>/dev/null
    cat > "${STATUS_FILE}.$$" << STATUSEOF
{"running":${running},"starting":${starting},"stopping":${stopping},"version":"${AWG_VERSION}","lang":"${pref_lang}","port":"${port}","subnet":"${subnet}","router_ip":"${router_ip}","public_key":"${pubkey}","endpoint_hint":"${ep_hint}","wan_private":$([ "$wan_priv" = "1" ] && echo true || echo false),"port_conflict":$([ "$port_conf" = "1" ] && echo true || echo false),"nat_lan":${nat_lan},"autostart":${autostart},"client_running":${client_running},"xray_capture":${xray_capture},"xray_ctl":${xray_ctl},"peers":${peers_json},"log":"${log_text}"}
STATUSEOF
    mv "${STATUS_FILE}.$$" "$STATUS_FILE" 2>/dev/null
}

do_srv_diag(){
    echo "=== AmneziaWG SERVER diag (v$AWG_VERSION) ==="
    echo "date: $(date '+%Y-%m-%d %H:%M:%S') (up $(cut -d. -f1 /proc/uptime 2>/dev/null)s)"
    echo "iface $IFACE: $(iface_exists "$IFACE" && echo present || echo ABSENT); daemon awgs-go: $(pidof awgs-go >/dev/null 2>&1 && echo running || echo DEAD)"
    echo "port: $(srv_port); subnet: $(srv_subnet); router ip: $(srv_router_ip)"
    echo "endpoint hint: $(srv_endpoint_hint); wan_private: $(srv_wan_private); port_conflict(fw wgs): $(srv_port_conflict)"
    echo "client tunnel awg0: $(iface_exists awg0 && echo up || echo down)"
    echo "--- awg show ---"
    "$AWG_BIN" show "$IFACE" 2>&1 | redact_secrets
    echo "--- firewall ---"
    echo "  INPUT udp $(srv_port): $(iptables -C INPUT -p udp --dport "$(srv_port)" -j ACCEPT 2>/dev/null && echo present || echo MISSING)"
    echo "  FORWARD in/out: $(iptables -C FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null && echo in-ok || echo in-MISSING) / $(iptables -C FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null && echo out-ok || echo out-MISSING)"
    echo "  NAT: $(iptables -t nat -S POSTROUTING 2>/dev/null | grep -cF -- "-s $(srv_subnet)") rule(s) for $(srv_subnet)"
    echo "--- routes ---"
    ip route show table $RT_TABLE 2>/dev/null | sed 's/^/  t300: /'
    ip route show 2>/dev/null | grep -F "$IFACE" | sed 's/^/  main: /'
    echo "--- dnsmasq ---"
    echo "  interface=$IFACE in effective conf: $(grep -c "^interface=$IFACE" /etc/dnsmasq.conf 2>/dev/null)"
    echo "--- watchdog beat ---"
    echo "  $(cat /tmp/.awgs_wd_beat 2>/dev/null || echo never)"
    echo "--- daemon log tail ---"
    tail -n 15 $DAEMON_LOG 2>/dev/null | sed 's/^/  /'
    echo "  last daemon exit: $(cat $DAEMON_RC 2>/dev/null || echo '(none — running or never exited)')"
    echo "=== end ==="
}

# =============================================================
# Service events & CLI
# =============================================================

do_srv_service_event(){
    local event="$2"
    case "$event" in
        awgsrvstart|awgsrvstop|awgsrvrestart|awgsrvsave) ui_log_reset ;;
    esac
    case "$event" in
        awgsrvstart)   do_srv_start ;;
        awgsrvstop)    do_srv_stop user ;;
        awgsrvrestart) do_srv_restart ;;
        awgsrvsave)
            # Give the firmware a beat to flush custom_settings (same wait the client's
            # apply uses) — the POST that carries the settings triggers this very event.
            local _wt=0
            while [ $_wt -lt 5 ] && [ -z "$(get_setting awgs_privkey)" ]; do sleep 1; _wt=$((_wt+1)); done
            do_srv_apply
            ;;
        awgsrvdiag)
            do_srv_diag > "$DIAG_FILE" 2>&1
            echo "[DIAG_DONE]" >> "$DIAG_FILE"
            ;;
        awgsrvstatus)  srv_update_status ;;
    esac
}

case "$1" in
    start)            do_srv_start ;;
    boot_start)       do_srv_boot_start ;;
    stop)             do_srv_stop "$2" ;;
    restart)          do_srv_restart ;;
    apply)            do_srv_apply ;;
    status)           srv_update_status ;;
    watchdog)         do_srv_watchdog ;;
    firewall_restart) do_srv_firewall_restart ;;
    diag)             do_srv_diag ;;
    service_event)    do_srv_service_event "$2" "$3" ;;
    *)                echo "Usage: $0 {start|boot_start|stop [user]|restart|apply|status|watchdog|firewall_restart|diag}" ;;
esac
