#!/bin/sh
# =============================================================
# AmneziaWG addon backend for Asuswrt-Merlin
# Userspace amneziawg-go, per-device policy routing, GeoIP/GeoSite
# =============================================================

AWG_VERSION="1.1.81"
ADDON_DIR="/jffs/addons/amneziawg"
AWG_DIR="/opt/amneziawg"
CONF="$AWG_DIR/awg0.conf"
AWG_GO="$AWG_DIR/amneziawg-go"
AWG_BIN="$AWG_DIR/awg"
IFACE="awg0"
STATUS_FILE="/www/user/awg_status.htm"
UI_LOG="/www/user/awg_log.htm"
DIAG_FILE="/www/user/awg_diag.htm"
# Manual .ipk upload (web UI): base64 text is appended here chunk-by-chunk (awgupload
# event), then decoded + installed (awgmanualinstall). Progress/result the UI polls:
AWG_UPLOAD_B64="/tmp/amneziawg_manual.ipk.b64"
AWG_UPLOAD_SEQ="/tmp/.amneziawg_manual.seq"
AWG_UPLOAD_STATUS="/www/user/awg_upload.htm"
STARTING_FLAG="/tmp/.awg_starting"
STOPPING_FLAG="/tmp/.awg_stopping"
GEO_BUSY_FLAG="/tmp/.awg_geo_busy"
SETTINGS="/jffs/addons/custom_settings.txt"
CLIENTS_FILE="$AWG_DIR/clients.list"
GEO_DIR="$AWG_DIR/geo"
IPSET_NAME="awg_dst"
# ipset capacity. Raised above the old 131072 so antifilter.download lists fit
# (ipresolve alone is ~154K) alongside GeoIP/GeoSite/custom entries.
IPSET_MAXELEM=262144
FWMARK="0x100"
DNSMASQ_AWG_CONF="$AWG_DIR/dnsmasq_awg.conf"
DNSMASQ_INCLUDE="/jffs/configs/dnsmasq.conf.add"
SCRIPT_NAME="amneziawg"
RT_TABLE=300
AWG_CHAIN="AWG"
LOCKDIR="/tmp/.awg_lock"
GEOLOCK="/tmp/.awg_geolock"   # long-running background geo-download mutex (separate from LOCKDIR)
V2FLY_GEOIP_BASE="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text"
GEOIP_SERVICES="telegram google facebook twitter netflix cloudflare fastly cloudfront"

# Ensure Entware binaries are in PATH (not set when called from httpd/service-event)
export PATH="/opt/bin:/opt/sbin:/sbin:/usr/sbin:$PATH"

# Resolve a WORKING `ipset` once, then route every call through a wrapper. The addon runs
# without Entware's /opt/etc/profile, so the Entware ipset in /opt/sbin loads the firmware's
# older /usr/lib/libipset.so.13 and dies at dynamic-link time with "version `LIBIPSET_x.y'
# not found" — which silently disabled ALL geo (create AND the `ipset list` guards fail).
# Probe each candidate's `version` (fails the same way on a lib mismatch) and keep the first
# that runs. Firmware ipset (/usr/sbin,/sbin) is self-consistent with its libipset, dnsmasq
# and the kernel set modules; the Entware build needs LD_LIBRARY_PATH=/opt/lib (its own lib).
AWG_IPSET_BIN=""; AWG_IPSET_LIB=""
_awg_try_ipset(){   # $1=binary  $2=libdir (optional)
    [ -x "$1" ] || return 1
    if [ -n "$2" ]; then LD_LIBRARY_PATH="$2${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$1" version >/dev/null 2>&1
    else "$1" version >/dev/null 2>&1; fi
}
if   _awg_try_ipset /usr/sbin/ipset;          then AWG_IPSET_BIN=/usr/sbin/ipset
elif _awg_try_ipset /sbin/ipset;              then AWG_IPSET_BIN=/sbin/ipset
elif _awg_try_ipset /opt/sbin/ipset /opt/lib; then AWG_IPSET_BIN=/opt/sbin/ipset; AWG_IPSET_LIB=/opt/lib
fi
# Wrapper named `ipset` so all existing call sites work unchanged. Absolute-path branches and
# `command ipset` both bypass this function (no recursion). Forked pipeline subshells (e.g.
# `awk … | ipset restore`) inherit the function + AWG_IPSET_* vars, so they route through here too.
ipset(){
    if   [ -n "$AWG_IPSET_LIB" ]; then LD_LIBRARY_PATH="$AWG_IPSET_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$AWG_IPSET_BIN" "$@"
    elif [ -n "$AWG_IPSET_BIN" ]; then "$AWG_IPSET_BIN" "$@"
    else command ipset "$@"; fi
}

# --- Helpers ---

log_msg(){
    logger -t "$SCRIPT_NAME" "$1"
    # Real-time on-page log (web-readable, polled by the UI); reset per user action.
    echo "$(date '+%H:%M:%S') $1" >> "$UI_LOG" 2>/dev/null
}

# Clear the on-page log at the start of a user-facing operation
ui_log_reset(){
    : > "$UI_LOG" 2>/dev/null
}

get_setting(){
    awk -v key="$1" '$1==key{sub(/^[^ ]+ /,"");print;exit}' "$SETTINGS" 2>/dev/null
}

# Remove a custom-settings line. Used for one-shot keys (e.g. awg_update_version) so a
# version pinned for a single update can never pin a later automatic update.
clear_setting(){
    local key="$1" tmp
    [ -f "$SETTINGS" ] || return 0
    grep -q "^$key " "$SETTINGS" 2>/dev/null || return 0
    tmp="$SETTINGS.awgtmp.$$"
    grep -v "^$key " "$SETTINGS" > "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS"
    rm -f "$tmp" 2>/dev/null
}

is_running(){
    ip link show "$IFACE" >/dev/null 2>&1
}

get_lan_net(){
    ip -4 route show dev br0 2>/dev/null | awk '$1 ~ /^[0-9]/ && $1 ~ /\// {print $1; exit}'
}

get_router_ip(){
    ip -4 addr show br0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}'
}

get_endpoint(){
    awk -F'[ =:]+' '/^Endpoint/{print $2}' "$CONF" 2>/dev/null
}

flush_conntrack(){
    # Drop ONLY conntrack entries with our fwmark, so marked devices reconnect
    # through the tunnel. Never fall back to a full 'conntrack -F': a zero-match
    # targeted delete returns 1, which used to wipe the whole table (killing every
    # LAN connection) on any Apply that had no currently-marked flows.
    command -v conntrack >/dev/null 2>&1 || return 0
    conntrack -D --mark "$FWMARK"/"$FWMARK" 2>/dev/null
    return 0
}

save_and_set_rp_filter(){
    for iface in all awg0 br0; do
        local f="/proc/sys/net/ipv4/conf/$iface/rp_filter"
        # Idempotent save: only capture the TRUE baseline if we haven't already, so a
        # re-entry (e.g. a concurrent start) can't overwrite the saved value with the
        # already-modified 2 and leave rp_filter forced loose after stop.
        [ -f "/tmp/.awg_rp_$iface" ] || { [ -f "$f" ] && cat "$f" > "/tmp/.awg_rp_$iface" 2>/dev/null; }
        echo 2 > "$f" 2>/dev/null
    done
}

restore_rp_filter(){
    for iface in all awg0 br0; do
        local saved="/tmp/.awg_rp_$iface"
        local f="/proc/sys/net/ipv4/conf/$iface/rp_filter"
        if [ -f "$saved" ]; then
            cat "$saved" > "$f" 2>/dev/null
            rm -f "$saved"
        fi
    done
}

# Wait for process to exit. Usage: wait_for_pid_exit <name> <timeout>
wait_for_pid_exit(){
    local pname="$1" max="${2:-10}" i=0
    while [ $i -lt $max ]; do
        pidof "$pname" >/dev/null 2>&1 || return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Wait for DNS resolver. Usage: wait_for_dns <timeout>
wait_for_dns(){
    local max="${1:-10}" i=0
    while [ $i -lt $max ]; do
        nslookup localhost 127.0.0.1 >/dev/null 2>&1 && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Wait for network interface IP. Usage: wait_for_iface_ip <iface> <timeout>
wait_for_iface_ip(){
    local iface="$1" max="${2:-10}" i=0
    while [ $i -lt $max ]; do
        ip -4 addr show "$iface" 2>/dev/null | grep -q "inet " && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Wait for interface to appear. Usage: wait_for_iface <iface> <timeout>
wait_for_iface(){
    local iface="$1" max="${2:-10}" i=0
    while [ $i -lt $max ]; do
        ip link show "$iface" >/dev/null 2>&1 && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

acquire_lock(){
    local tries=0
    while ! mkdir "$LOCKDIR" 2>/dev/null; do
        if [ -f "$LOCKDIR/pid" ]; then
            local old_pid
            old_pid=$(cat "$LOCKDIR/pid" 2>/dev/null)
            if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
                rm -rf "$LOCKDIR"
                continue
            fi
        fi
        tries=$((tries + 1))
        [ $tries -ge 30 ] && { log_msg "ERROR: lock timeout"; return 1; }
        sleep 1
    done
    echo $$ > "$LOCKDIR/pid"
}

release_lock(){
    # Owner-aware: only free the lock if WE hold it (pid matches), so a stray release on an
    # error path can't free a lock another concurrent actor acquired.
    local p
    p=$(cat "$LOCKDIR/pid" 2>/dev/null)
    [ -n "$p" ] && [ "$p" != "$$" ] && return 0
    rm -rf "$LOCKDIR"
}

human_size(){
    local bytes=${1:-0}
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        echo "$bytes" | awk '{printf "%.1f GiB", $1/1073741824}'
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        echo "$bytes" | awk '{printf "%.1f MiB", $1/1048576}'
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        echo "$bytes" | awk '{printf "%.1f KiB", $1/1024}'
    else
        echo "${bytes} B"
    fi
}

# Human-readable hint for a curl exit code, so download failures in the log say WHY
# (DNS vs refused vs timeout vs TLS vs HTTP error) instead of a bare number. Keeps the
# raw code too — `man curl` EXIT CODES has the full list.
curl_err_hint(){
    case "$1" in
        0)  echo "ok" ;;
        6)  echo "curl 6: DNS resolution failed" ;;
        7)  echo "curl 7: connection refused/unreachable" ;;
        22) echo "curl 22: HTTP error (4xx/5xx — asset missing or blocked)" ;;
        28) echo "curl 28: timeout (connect or stalled transfer)" ;;
        35) echo "curl 35: TLS handshake failed" ;;
        47) echo "curl 47: too many redirects" ;;
        52) echo "curl 52: empty reply from server" ;;
        56) echo "curl 56: connection reset during transfer" ;;
        *)  echo "curl $1" ;;
    esac
}

# Echo a curl "--interface <ip>" option that binds the request's SOURCE address to the
# awg0 tunnel IP, so the download egresses through the VPN and bypasses regional blocks
# on GitHub/jsDelivr/etc. $1 = feature ("geo" or "update"). Returns nothing — download
# goes out the WAN as before — unless the matching toggle is on AND the tunnel is up with
# an IP. Source-binding alone is enough: setup_firewall installs
# "ip rule from <awg0-ip> lookup $RT_TABLE prio 100", which routes anything sourced from
# that address through the tunnel table. DNS still uses the system resolver (not the
# tunnel), so this bypasses IP/TCP-level blocks, not DNS poisoning.
awg_dl_iface_opt(){
    local feature="$1" key addr
    case "$feature" in
        geo)    key="awg_geo_via_awg" ;;
        update) key="awg_update_via_awg" ;;
        *)      return 0 ;;
    esac
    [ "$(get_setting "$key")" = "1" ] || return 0
    is_running || return 0
    addr=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -n "$addr" ] || return 0
    # Bind ONLY when the tunnel routing is actually in place — not just the link. During
    # do_start and do_firewall_restart (the latter fires on EVERY router firewall restart)
    # there is a brief window where awg0 is up with its IP but cleanup_firewall has flushed
    # the policy rule + table $RT_TABLE routes that setup_firewall re-adds last. Binding in
    # that window would egress the WAN with a martian source and fail with no fallback, so
    # require both the "from <addr> lookup $RT_TABLE" rule and the table's default route;
    # otherwise emit nothing -> direct (WAN) download.
    ip rule show 2>/dev/null | grep -qF "from $addr lookup $RT_TABLE" || return 0
    ip route show table "$RT_TABLE" 2>/dev/null | grep -q "0.0.0.0/1" || return 0
    printf -- '--interface %s' "$addr"
}

# Fetch $1 -> $2 (max-time $3), trying GitHub directly then mirrors. raw.githubusercontent
# and the release CDN are often unreachable in some regions; jsDelivr mirrors repo files.
# When "geo via VPN" is on and the tunnel is up, all attempts egress through it (awg_bind).
fetch_with_mirrors(){
    local url="$1" out="$2" mt="${3:-60}" u list
    local awg_bind=$(awg_dl_iface_opt geo)
    case "$url" in
        https://raw.githubusercontent.com/*)
            local jsd=$(echo "$url" | sed 's#https://raw.githubusercontent.com/\([^/]*\)/\([^/]*\)/\([^/]*\)/#https://cdn.jsdelivr.net/gh/\1/\2@\3/#')
            # if raw GitHub already timed out this run, try jsDelivr first
            if [ "$RAW_GH_DOWN" = 1 ]; then list="$jsd $url"; else list="$url $jsd"; fi
            ;;
        *) list="$url" ;;
    esac
    for u in $list "https://ghproxy.net/$url" "https://gh-proxy.com/$url"; do
        if curl -sfL $awg_bind --connect-timeout 6 --max-time "$mt" --retry 1 "$u" -o "$out" 2>/dev/null && [ -s "$out" ]; then
            return 0
        fi
        case "$url" in https://raw.githubusercontent.com/*) [ "$u" = "$url" ] && RAW_GH_DOWN=1 ;; esac
    done
    log_msg "  download failed (incl. mirrors): $url"
    return 1
}

# Download a single GeoIP service list (IPv4 only)
download_geoip_service(){
    local svc="$1"
    svc=$(echo "$svc" | tr -d ' ' | tr 'A-Z' 'a-z')
    [ -z "$svc" ] && return 1
    local tmp="$GEO_DIR/geoip/.dl_${svc}.tmp"
    if fetch_with_mirrors "${V2FLY_GEOIP_BASE}/${svc}.txt" "$tmp" 30 && [ -s "$tmp" ]; then
        grep -v ":" "$tmp" > "$GEO_DIR/geoip/v2fly_${svc}.cidr"
        rm -f "$tmp"
        # Reject garbage (e.g. a proxy HTML error page): require at least one IPv4 line
        if ! grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$GEO_DIR/geoip/v2fly_${svc}.cidr" 2>/dev/null; then
            rm -f "$GEO_DIR/geoip/v2fly_${svc}.cidr"; return 1
        fi
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Selected GeoIP services: the UI "GeoIP Service Lists" field, or GEOIP_SERVICES default
selected_geoip(){
    local s
    s=$(get_setting awg_geo_v2fly_ip | tr ',' ' ' | tr 'A-Z' 'a-z')
    s=$(echo $s)
    [ -z "$s" ] && s="$GEOIP_SERVICES"
    echo "$s"
}

# Download all geo databases (called at install and update)
# Remove GeoIP .cidr files for services no longer selected (handles a service removed
# from the UI field). Selection = the field, or the GEOIP_SERVICES default if empty.
prune_geoip(){
    local sel=" $(selected_geoip) " f fsvc
    for f in "$GEO_DIR"/geoip/v2fly_*.cidr; do
        [ -f "$f" ] || continue
        fsvc=$(basename "$f" .cidr); fsvc=${fsvc#v2fly_}
        case "$sel" in *" $fsvc "*) ;; *) rm -f "$f" ;; esac
    done
}

# --- antifilter.download lists (RKN-blocked subnets/domains) ---
# Registry of supported lists: key -> source URL. IP/CIDR lists load into the awg_dst
# ipset alongside GeoIP; community_domains is a small domain list fed to dnsmasq.
antifilter_url(){
    case "$1" in
        allyouneed)        echo "https://antifilter.download/list/allyouneed.lst" ;;
        ipsum)             echo "https://antifilter.download/list/ipsum.lst" ;;
        subnet)            echo "https://antifilter.download/list/subnet.lst" ;;
        ip)                echo "https://antifilter.download/list/ip.lst" ;;
        ipresolve)         echo "https://antifilter.download/list/ipresolve.lst" ;;
        community)         echo "https://community.antifilter.download/list/community.lst" ;;
        community_domains) echo "https://community.antifilter.download/list/domains.lst" ;;
    esac
}

# True for keys that are domain lists (fed to dnsmasq), false for IP/CIDR lists.
antifilter_is_domain(){ [ "$1" = "community_domains" ]; }

# Selected antifilter lists: the UI checkboxes (awg_antifilter_lists, comma-separated)
selected_antifilter(){
    echo $(get_setting awg_antifilter_lists | tr ',' ' ' | tr 'A-Z' 'a-z')
}

# Download a single antifilter list. IP lists -> antifilter/af_<key>.cidr (IPv4 only,
# bare IPs/CIDR both valid in hash:net); the domain list -> domains/antifilter_<key>.lst.
# Temp + swap so a failed download keeps the existing list; reject HTML error pages.
download_antifilter_list(){
    local key="$1" url out tmp
    url=$(antifilter_url "$key"); [ -z "$url" ] && return 1
    if antifilter_is_domain "$key"; then
        out="$GEO_DIR/domains/antifilter_${key}.lst"
        tmp="$GEO_DIR/domains/.dl_af_${key}.tmp"
        mkdir -p "$GEO_DIR/domains"
        if fetch_with_mirrors "$url" "$tmp" 60 && [ -s "$tmp" ]; then
            grep -E '^[a-zA-Z0-9]' "$tmp" > "$out"
            rm -f "$tmp"
            [ -s "$out" ] || { rm -f "$out"; return 1; }
            return 0
        fi
    else
        out="$GEO_DIR/antifilter/af_${key}.cidr"
        tmp="$GEO_DIR/antifilter/.dl_af_${key}.tmp"
        mkdir -p "$GEO_DIR/antifilter"
        if fetch_with_mirrors "$url" "$tmp" 60 && [ -s "$tmp" ]; then
            grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$tmp" > "$out"
            rm -f "$tmp"
            [ -s "$out" ] || { rm -f "$out"; return 1; }
            return 0
        fi
    fi
    rm -f "$tmp"
    return 1
}

# Remove antifilter files for lists no longer selected (mirror of prune_geoip)
prune_antifilter(){
    local sel=" $(selected_antifilter) " f fkey
    for f in "$GEO_DIR"/antifilter/af_*.cidr; do
        [ -f "$f" ] || continue
        fkey=$(basename "$f" .cidr); fkey=${fkey#af_}
        case "$sel" in *" $fkey "*) ;; *) rm -f "$f" ;; esac
    done
    for f in "$GEO_DIR"/domains/antifilter_*.lst; do
        [ -f "$f" ] || continue
        fkey=$(basename "$f" .lst); fkey=${fkey#antifilter_}
        case "$sel" in *" $fkey "*) ;; *) rm -f "$f" ;; esac
    done
}

# Download the v2fly GeoSite domain DB (the full category set). To temp + swap on
# success, so a failed download keeps the existing DB.
download_geosite(){
    mkdir -p "$GEO_DIR/domains"
    log_msg "Downloading v2fly domain database..."
    update_status
    local tmp_yml="$GEO_DIR/v2fly_all.yml.tmp"
    # Validate the body before the swap: a flaky mirror (ghproxy) can return HTTP 200 with an
    # HTML/JSON error page that curl -f accepts and [ -s ] passes — an unconditional mv would
    # then overwrite a good DB with garbage and silently empty every GeoSite category. Require
    # at least one real category marker (mirrors the GeoIP/antifilter validators); otherwise
    # keep the existing v2fly_all.yml.
    if fetch_with_mirrors "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml" "$tmp_yml" 120 && [ -s "$tmp_yml" ] && grep -q '^  - name: ' "$tmp_yml"; then
        mv "$tmp_yml" "$GEO_DIR/v2fly_all.yml"
        grep '  - name: ' "$GEO_DIR/v2fly_all.yml" | sed 's/.*- name: //' | sort > "$GEO_DIR/v2fly_categories.txt"
        cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null
        log_msg "GeoSite: $(wc -l < "$GEO_DIR/v2fly_categories.txt") categories downloaded"
    else
        rm -f "$tmp_yml"
        log_msg "WARNING: v2fly domain download failed or invalid (kept existing DB)"
    fi
}

download_all_geo(){
    mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains"
    log_msg "Downloading all geo databases..."

    # Download GeoIP service CIDR lists (driven by the UI field; default GEOIP_SERVICES)
    local geoip_list=$(selected_geoip)
    prune_geoip   # drop lists for services removed from the selection
    local count=0 total=0 ok=0
    for svc in $geoip_list; do
        total=$((total + 1))
    done
    for svc in $geoip_list; do
        count=$((count + 1))
        log_msg "GeoIP: downloading $svc ($count/$total)..."
        if download_geoip_service "$svc"; then
            ok=$((ok + 1))
        else
            log_msg "WARNING: GeoIP $svc failed"
        fi
        update_status
    done
    log_msg "GeoIP: $ok/$total service lists downloaded"

    download_geosite

    # Download selected antifilter.download lists (RKN-blocked subnets/domains)
    mkdir -p "$GEO_DIR/antifilter"
    prune_antifilter   # drop files for lists removed from the selection
    local af_key
    for af_key in $(selected_antifilter); do
        log_msg "Antifilter: downloading $af_key..."
        download_antifilter_list "$af_key" || log_msg "WARNING: Antifilter $af_key failed"
        update_status
    done

    # Save timestamp
    date +%s > "$GEO_DIR/.last_update"
    update_status
    log_msg "Geo databases updated"
}

# Mount AmneziaWG tab + global header widget into Merlin menu.
# Idempotent: the tab line is matched precisely and the widget loader lives in a
# marker-delimited block, so re-running (services-start, service events) never
# duplicates or corrupts either one.
mount_menu_tree(){
    local page="$1"
    [ ! -f /tmp/menuTree.js ] && cp /www/require/modules/menuTree.js /tmp/
    # Remove our previous tab line (precise match — does not touch the widget block)
    sed -i '/tabName: "AmneziaWG"/d' /tmp/menuTree.js
    # Remove our previous widget block (marker range; independent of the word "AmneziaWG")
    sed -i '/\/\* AWG_WIDGET_START \*\//,/\/\* AWG_WIDGET_END \*\//d' /tmp/menuTree.js
    # Insert the AmneziaWG tab after the OpenVPN entry
    sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$page\", tabName: \"AmneziaWG\"}," /tmp/menuTree.js
    # Append the tiny widget loader (runs on every page; version-stamped for cache-busting)
    cat >> /tmp/menuTree.js <<AWGEOF
/* AWG_WIDGET_START */
(function(){try{if(window.__awgWidget)return;window.__awgWidget=1;window.__awgPage='${page}';
var s=document.createElement('script');s.src='/user/awg_widget.js?v=${AWG_VERSION}';s.async=true;
(document.head||document.documentElement).appendChild(s);}catch(e){}})();
/* AWG_WIDGET_END */
AWGEOF
    umount /www/require/modules/menuTree.js 2>/dev/null
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
}

# Bulk-load CIDR file into ipset using restore (much faster than individual adds)
ipset_load_file(){
    local file="$1"
    local setname="$2"
    [ ! -f "$file" ] && return
    awk -v s="$setname" '
        /^[0-9]/ && !/^#/ {
            gsub(/[[:space:]\r]/, "")
            if ($0 != "") print "add " s " " $0 " timeout 0"
        }
    ' "$file" | ipset restore -! 2>/dev/null
}

# --- Unified firewall setup ---

# Detect a co-resident DPI-bypass / proxy tool that we must not fight: zapret/zapret2 by
# bol-van (nfqws/tpws daemons, or NFQUEUE/TPROXY targets in iptables), OR a transparent
# proxy daemon (xray/XRAYUI, v2ray, sing-box). When detected we skip the global DNS hijack
# below so we don't collide with its DNS/redirect handling and lock out the LAN — the addon's
# marks/table/conntrack flush are already its own. (Name kept as zapret_active for callers.)
zapret_active(){
    { pidof nfqws || pidof tpws; } >/dev/null 2>&1 && return 0
    { pidof xray || pidof v2ray || pidof sing-box; } >/dev/null 2>&1 && return 0
    iptables-save 2>/dev/null | grep -qE 'NFQUEUE|TPROXY' && return 0
    return 1
}

# Human-readable name of a co-resident DPI-bypass / proxy tool, for the UI coexistence
# warning (status JSON "dpi_tool"). Echoes the first match, or nothing. Proxy daemons first
# (the common Xray/XRAYUI case), then zapret, then a generic NFQUEUE/TPROXY footprint.
detect_dpi_tool(){
    pidof xray     >/dev/null 2>&1 && { echo "Xray";     return; }
    pidof v2ray    >/dev/null 2>&1 && { echo "V2Ray";    return; }
    pidof sing-box >/dev/null 2>&1 && { echo "sing-box"; return; }
    { pidof nfqws || pidof tpws; } >/dev/null 2>&1 && { echo "zapret"; return; }
    iptables-save 2>/dev/null | grep -qE 'NFQUEUE|TPROXY' && { echo "DPI (NFQUEUE/TPROXY)"; return; }
}

# True when the firmware's OWN DNS redirection is active: DNSFilter / DNS Director
# (dnsfilter_enable_x), or DoT/DNS-over-TLS via stubby (dnspriv_enable). Like the
# zapret/xray case, we must NOT slam our global :53 DNAT on top of it — that would silently
# override the user's per-client DNS policy or disable encrypted DNS. When detected we skip
# our hijack (geo-by-IP still works; only forced domain-geo is weakened for external-resolver
# clients) instead of fighting the firmware.
fw_dns_redirect_active(){
    [ "$(nvram get dnsfilter_enable_x 2>/dev/null)" = "1" ] && return 0
    [ "$(nvram get dns_director_enable 2>/dev/null)" = "1" ] && return 0
    [ "$(nvram get dnspriv_enable 2>/dev/null)" = "1" ] && return 0
    return 1
}

# Single source of truth for "should the global :53 DNS interception be installed right now?"
# so setup_firewall and the watchdog reconciler make the SAME decision and can't drift.
# Returns 0 (wanted) only when a VPN/geo policy needs forced DNS AND no co-resident DNS owner
# (user opt-out, zapret/xray, or firmware DNSFilter/Director/DoT) is present AND dnsmasq is up.
intercept_wanted(){
    local dp
    dp=$(get_setting awg_default_policy); [ -z "$dp" ] && dp="direct"
    { [ "$dp" != "direct" ] || geo_in_use; } || return 1
    [ "$(get_setting awg_no_dns_intercept)" = "1" ] && return 1
    zapret_active && return 1
    fw_dns_redirect_active && return 1
    pidof dnsmasq >/dev/null 2>&1 || return 1
    return 0
}

setup_dns_interception(){
    # Never DNAT :53 to a dead resolver — that black-holes all LAN DNS. If dnsmasq isn't
    # up, skip interception (clients keep working DNS); reload_dnsmasq + the start deadman
    # bring geo DNS online shortly after.
    if ! pidof dnsmasq >/dev/null 2>&1; then
        log_msg "WARNING: dnsmasq not running — skipping DNS interception (would break LAN DNS)"
        return 0
    fi
    local router_ip
    router_ip=$(get_router_ip)
    [ -z "$router_ip" ] && router_ip="192.168.1.1"
    # Remember the IP we DNAT to so cleanup can remove the rule even if br0's IP
    # changes later (otherwise an orphaned DNAT to the old IP breaks LAN DNS).
    echo "$router_ip" > /tmp/.awg_dns_ip 2>/dev/null
    iptables -t nat -C PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null || iptables -t nat -I PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip"
    iptables -t nat -C PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null || iptables -t nat -I PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip"
    iptables -C FORWARD -i br0 -p tcp --dport 853 -j REJECT 2>/dev/null || iptables -I FORWARD -i br0 -p tcp --dport 853 -j REJECT
    local doh_ip
    for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
        iptables -C FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT 2>/dev/null || iptables -I FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT
        iptables -C FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT 2>/dev/null || iptables -I FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT
    done
    log_msg "DNS interception enabled"
}

# True if our LAN DNS interception (:53 DNAT to the router) is currently installed. Checked
# against the exact rule we add so a stale /tmp/.awg_dns_ip or a foreign :53 DNAT won't match.
dns_intercept_active(){
    local ip
    ip=$(cat /tmp/.awg_dns_ip 2>/dev/null)
    [ -z "$ip" ] && return 1
    iptables -t nat -C PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$ip" 2>/dev/null
}

# Resolve a well-known name via the router's own dnsmasq (the resolver LAN clients are
# DNAT'd to). Returns 0 only on a real answer. The health check/watchdog use this to catch
# the "tunnel pings 8.8.8.8 but DNS is dead" lockout that an ICMP-only probe silently misses
# (e.g. dnsmasq's upstream is blackholed through a non-passing tunnel). busybox nslookup
# prints a "Name:" line only on success; failure prints "can't resolve" with no such line.
dns_ok(){
    local n
    for n in cloudflare.com google.com quad9.net; do
        nslookup "$n" 127.0.0.1 2>/dev/null | grep -q '^Name:' && return 0
    done
    return 1
}

setup_ipv6_block(){
    local ipv6_svc
    ipv6_svc=$(nvram get ipv6_service 2>/dev/null)
    [ "$ipv6_svc" = "disabled" ] || [ -z "$ipv6_svc" ] && return 0
    # Idempotent (-C guard) so setup_firewall can re-assert it on every Apply without
    # stacking duplicates. setup_firewall is the single rebuild point that all three trigger
    # paths (do_start, do_firewall_restart, awgsaveconf) hit, so the IPv6 block stays
    # symmetric — a bare "Apply" no longer tears it down and leaks IPv6 around the tunnel.
    ip6tables -C FORWARD -i br0 -o "$IFACE" -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null \
        || ip6tables -I FORWARD -i br0 -o "$IFACE" -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null
    ip6tables -C FORWARD -i "$IFACE" -o br0 -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null \
        || ip6tables -I FORWARD -i "$IFACE" -o br0 -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null
}

cleanup_ipv6_block(){
    ip6tables -D FORWARD -i br0 -o "$IFACE" -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null
    ip6tables -D FORWARD -i "$IFACE" -o br0 -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null
}

# Remove ONLY the global :53 DNS-interception rules (DNAT + DoH/DoT REJECTs). Factored out of
# cleanup_firewall so the watchdog can tear down just the DNS hijack when a co-resident DPI
# tool appears AFTER us, without rebuilding the whole firewall. Prefer the IP we actually
# DNAT'd to (saved at setup) so a changed br0 IP doesn't leave an orphaned DNAT to the old
# address; also drops the saved-IP record so dns_intercept_active reports inactive afterwards.
cleanup_dns_interception(){
    local router_ip
    router_ip=$(cat /tmp/.awg_dns_ip 2>/dev/null)
    [ -z "$router_ip" ] && router_ip=$(get_router_ip)
    [ -z "$router_ip" ] && router_ip="192.168.1.1"
    iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null
    iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null
    iptables -D FORWARD -i br0 -p tcp --dport 853 -j REJECT 2>/dev/null
    local doh_ip
    for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
        iptables -D FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT 2>/dev/null
        iptables -D FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT 2>/dev/null
    done
    rm -f /tmp/.awg_dns_ip 2>/dev/null
}

cleanup_firewall(){
    # Unhook from PREROUTING, flush and delete custom chain
    iptables -t mangle -D PREROUTING -j "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -F "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -X "$AWG_CHAIN" 2>/dev/null

    # Remove all ip rules for our table/fwmark
    local _i=0; while [ $_i -lt 100 ] && ip rule del lookup $RT_TABLE 2>/dev/null; do _i=$((_i+1)); done
    _i=0; while [ $_i -lt 100 ] && ip rule del fwmark "$FWMARK" 2>/dev/null; do _i=$((_i+1)); done
    # Direct-policy rules use "lookup main prio 97" — not matched by the deletes above
    _i=0; while [ $_i -lt 100 ] && ip rule del prio 97 2>/dev/null; do _i=$((_i+1)); done

    # Remove the global :53 DNS-interception rules (DNAT + DoH/DoT REJECTs)
    cleanup_dns_interception

    # Destroy the ipset only if it's the one we own (default name). A custom name means the user
    # shares this set with other connections/tools — leave it intact, just drop our rules above.
    if [ "$IPSET_NAME" = "awg_dst" ]; then
        ipset flush "$IPSET_NAME" 2>/dev/null
        ipset destroy "$IPSET_NAME" 2>/dev/null
    fi

    # Remove dnsmasq config
    rm -f "$DNSMASQ_AWG_CONF"
    # Fixed-string removal (the path contains '.', which a sed regex would treat as
    # any-char and could match an unrelated line).
    [ -f "$DNSMASQ_INCLUDE" ] && grep -vF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.tmp" 2>/dev/null && mv "${DNSMASQ_INCLUDE}.tmp" "$DNSMASQ_INCLUDE"

    # Remove the geo-update cron (re-added by setup_firewall only when autoupdate is on, so
    # toggling it off is honored here). The self-heal watchdog cron is deliberately NOT
    # dropped here: cleanup_firewall runs on every Apply/firewall-restart AND on the
    # health-check/deadman auto-rollback, and removing the watchdog there would strand a
    # rolled-back tunnel with no way to recover. It is removed only on a user stop/uninstall.
    cru d awg_geo_update 2>/dev/null

    cleanup_ipv6_block

    log_msg "Firewall rules cleaned"
}

# Reload dnsmasq so it re-reads our ipset/domain rules from dnsmasq.conf.add.
# When invoked from a service-event, rc_service is busy and a direct
# "service restart_dnsmasq" is dropped ("skip the event: restart_dnsmasq"); a
# foreground retry would deadlock (rc waits for this very handler). So defer to a
# detached job that retries until the restart actually takes (dnsmasq PID changes),
# then pre-resolves geo domains to populate the ipset.
reload_dnsmasq(){
    (
        # Serialize reload jobs: wait for any prior one (so the last restart loads the
        # current on-disk config), then hold the lock. Avoids ping-ponging restarts.
        _w=0
        while ! mkdir /tmp/.awg_dnsreload 2>/dev/null; do
            _w=$((_w + 1)); [ $_w -ge 60 ] && break
            sleep 1
        done
        trap 'rmdir /tmp/.awg_dnsreload 2>/dev/null' EXIT INT TERM
        oldpid=$(pidof dnsmasq 2>/dev/null)
        i=0
        while [ $i -lt 30 ]; do
            service restart_dnsmasq >/dev/null 2>&1
            sleep 2
            newpid=$(pidof dnsmasq 2>/dev/null)
            if [ -n "$newpid" ] && [ "$newpid" != "$oldpid" ]; then
                log_msg "dnsmasq reloaded (geo rules active)"
                break
            fi
            i=$((i + 1))
            sleep 1
        done
        [ $i -ge 30 ] && log_msg "WARNING: dnsmasq reload was skipped by rc; geo domains may need a manual restart"
        # Self-heal: if dnsmasq is NOT running at all now, our generated config most likely
        # broke it (bad/oversized rules) and the LAN just lost DHCP/DNS. Drop our include
        # and restart clean so the router stays reachable — degraded geo beats a dead LAN.
        if ! pidof dnsmasq >/dev/null 2>&1; then
            log_msg "ERROR: dnsmasq down after reload — removing AWG dnsmasq rules + restarting to restore DNS/DHCP"
            rm -f "$DNSMASQ_AWG_CONF"
            [ -f "$DNSMASQ_INCLUDE" ] && grep -vF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.tmp" 2>/dev/null && mv "${DNSMASQ_INCLUDE}.tmp" "$DNSMASQ_INCLUDE"
            _j=0
            while [ $_j -lt 15 ]; do
                service restart_dnsmasq >/dev/null 2>&1
                sleep 2
                pidof dnsmasq >/dev/null 2>&1 && { log_msg "dnsmasq recovered (AWG dnsmasq rules removed)"; break; }
                _j=$((_j + 1)); sleep 1
            done
        fi
        wait_for_dns 10
        if [ -f "$DNSMASQ_AWG_CONF" ]; then
            bg_count=0
            awk -F/ '/^ipset=/{for(i=2;i<NF;i++)print $i}' "$DNSMASQ_AWG_CONF" | while read -r domain; do
                [ -z "$domain" ] && continue
                nslookup "$domain" 127.0.0.1 >/dev/null 2>&1 &
                bg_count=$((bg_count + 1))
                [ $bg_count -ge 10 ] && { wait; bg_count=0; }
            done
            wait
        fi
    ) </dev/null >/dev/null 2>&1 &
}

setup_firewall(){
    cleanup_firewall

    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local has_geo=false

    # --- Create ipset ---
    # Old routers (e.g. RT-AC68U) don't autoload the ip_set kernel modules, and the
    # in-kernel auto-load needs modprobe — absent from the httpd/service-event PATH
    # context — so `ipset create` fails there. Load them explicitly (no-op if already
    # loaded or built-in). xt_set backs the `-m set --match-set` mangle rules below.
    local m ipset_err
    for m in ip_set ip_set_hash_net xt_set; do
        modprobe "$m" 2>/dev/null
    done
    # Set default timeout 24h: governs domain entries added by dnsmasq (GeoSite/custom
    # domains). They MUST expire — domains (CDNs) rotate IPs; dnsmasq re-adds the
    # current IP on each resolution (refreshing it), so active domains stay while stale
    # IPs age out instead of accumulating forever. Static GeoIP/custom-IP entries are
    # added with an explicit "timeout 0" (permanent), overriding this default.
    # Capture stderr instead of masking it, so the real kernel error (e.g. "set type not
    # supported" when ip_set_hash_net is missing) lands in the UI log rather than a bare
    # "creation failed". The `ipset list` guard keeps a benign "set with the same name
    # already exists" on re-run from being logged as an error.
    # RAM-aware cap: on low-memory routers (RT-AC68U etc., 256MB) the big lists (antifilter
    # ipresolve ~154K) can exhaust kernel memory and hang the router. Scale the set ceiling
    # to total RAM; adds past it fail harmlessly (ipset restore -!), trading some geo
    # coverage for not locking up. Logged, not silent.
    local maxelem="$IPSET_MAXELEM" memkb
    memkb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$memkb" ] && [ "$memkb" -lt 393216 ]; then
        maxelem=98304
        log_msg "Low RAM (${memkb}KB total): ipset capped at $maxelem (was $IPSET_MAXELEM) to avoid OOM"
    fi
    ipset_err=$(ipset create "$IPSET_NAME" hash:net family inet hashsize 4096 maxelem "$maxelem" timeout 86400 2>&1)
    if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        log_msg "ERROR: ipset $IPSET_NAME creation failed, geo routing disabled${ipset_err:+: $ipset_err}"
        has_geo=false
    fi
    # Did the set actually come up? Gate both the mangle match-set rules AND the dnsmasq
    # ipset= rules on this single check so the two never disagree.
    local has_set=false
    ipset list "$IPSET_NAME" >/dev/null 2>&1 && has_set=true

    # --- Load selected GeoIP subnets into ipset (bulk) ---
    # Only services in the UI field (default GEOIP_SERVICES) are loaded; prune first so
    # a service removed from the field also has its .cidr file deleted, not just unrouted.
    prune_geoip
    local ip_count=0 gsvc gf
    for gsvc in $(selected_geoip); do
        gf="$GEO_DIR/geoip/v2fly_${gsvc}.cidr"
        [ -f "$gf" ] || continue
        ipset_load_file "$gf" "$IPSET_NAME"
        ip_count=$((ip_count + $(wc -l < "$gf")))
    done

    # --- Load selected antifilter.download IP/CIDR lists into the same ipset (bulk) ---
    # Domain lists (community_domains) are skipped here; their .lst file lives in
    # $GEO_DIR/domains/ and is picked up by the dnsmasq builder loop below.
    prune_antifilter
    local akey af
    for akey in $(selected_antifilter); do
        antifilter_is_domain "$akey" && continue
        af="$GEO_DIR/antifilter/af_${akey}.cidr"
        [ -f "$af" ] || continue
        ipset_load_file "$af" "$IPSET_NAME"
        ip_count=$((ip_count + $(wc -l < "$af")))
    done

    # Check ipset fill level
    local ipset_entries
    ipset_entries=$(ipset list "$IPSET_NAME" -t 2>/dev/null | awk '/Number of entries/{print $NF}')
    [ -n "$ipset_entries" ] && [ "$ipset_entries" -ge "$maxelem" ] 2>/dev/null && \
        log_msg "WARNING: ipset $IPSET_NAME full ($ipset_entries/$maxelem), some geo routes may be missing (raise RAM or trim lists)"

    # --- Extract v2fly domains from downloaded database ---
    local geo_v2fly=$(get_setting awg_geo_v2fly)
    rm -f "$GEO_DIR/domains/v2fly_"*.txt   # always clear stale category files (handles a cleared field)
    if [ -n "$geo_v2fly" ] && [ -f "$GEO_DIR/v2fly_all.yml" ]; then
        for svc in $(echo "$geo_v2fly" | tr ',' ' '); do
            svc=$(echo "$svc" | tr -d ' ')
            [ -z "$svc" ] && continue
            awk -v cat="$svc" '
                /^  - name: / { if(found) exit; name=$NF; found=(name==cat); next }
                found && /^      - "domain:/ { sub(/.*"domain:/,""); sub(/".*/,""); print }
                found && /^      - "full:/ { sub(/.*"full:/,""); sub(/".*/,""); print }
            ' "$GEO_DIR/v2fly_all.yml" > "$GEO_DIR/domains/v2fly_${svc}.txt"
        done
    fi

    # --- Save custom domains/IPs ---
    local custom_domains=$(get_setting awg_geo_custom_domains)
    rm -f "$GEO_DIR/domains/custom.txt"   # clear stale file when the field is emptied
    if [ -n "$custom_domains" ]; then
        mkdir -p "$GEO_DIR/domains"
        echo "$custom_domains" | tr ',' '\n' > "$GEO_DIR/domains/custom.txt"
    fi
    local custom_ips=$(get_setting awg_geo_custom_ips)
    if [ -n "$custom_ips" ]; then
        mkdir -p "$GEO_DIR/geoip"
        echo "$custom_ips" | tr ',' '\n' | while read -r cidr; do
            cidr=$(echo "$cidr" | tr -d ' \r')
            [ -n "$cidr" ] && ipset add "$IPSET_NAME" "$cidr" timeout 0 2>/dev/null
        done
    fi

    # --- Build dnsmasq config for domain-based routing ---
    local domain_count=0
    local block_ipv6=$(get_setting awg_block_ipv6_dns)
    [ -z "$block_ipv6" ] && block_ipv6="1"
    # Emit the GLOBAL filter-AAAA when the user wants it AND a VPN/geo policy is active. We do
    # NOT gate on ipv6_service: filter-AAAA is useful even with IPv6 disabled on the router —
    # it stops dual-stack clients (Happy Eyeballs) from trying dead AAAA addresses first and
    # stalling (a buffering regression in 1.1.69), and forces the IPv4 path that geo-routing
    # actually covers. The policy gate still avoids stripping AAAA LAN-wide when nothing is
    # tunnelled (so a pure-"direct" LAN keeps its IPv6 DNS).
    local want_aaaa=0
    [ "$block_ipv6" = "1" ] && { [ "$default_policy" != "direct" ] || geo_in_use; } && want_aaaa=1
    echo "# AmneziaWG domain routing - auto-generated" > "$DNSMASQ_AWG_CONF"
    [ "$want_aaaa" = 1 ] && echo "filter-AAAA" >> "$DNSMASQ_AWG_CONF"
    # Domain->ipset rules only work if the set actually exists. Mirror the mangle vpn_geo
    # guard (which re-checks `ipset list`) so a failed ipset create doesn't leave dnsmasq
    # emitting ipset=/dom/awg_dst lines that error on every lookup and silently kill geo.
    if [ "$has_set" = true ]; then
    for f in "$GEO_DIR"/domains/*.txt "$GEO_DIR"/domains/*.lst; do
        [ ! -f "$f" ] && continue
        local chunk_line="ipset=/"
        local chunk_count=0
        while read -r domain; do
            domain=$(echo "$domain" | tr -d ' \r')
            [ -z "$domain" ] && continue
            echo "$domain" | grep -q '^#' && continue
            domain=$(echo "$domain" | sed 's/^\.//;s/:@[^ ]*$//')
            echo "$domain" | grep -q '[^a-zA-Z0-9._-]' && continue
            chunk_line="${chunk_line}${domain}/"
            chunk_count=$((chunk_count + 1))
            domain_count=$((domain_count + 1))
            if [ $chunk_count -ge 20 ]; then
                echo "${chunk_line}${IPSET_NAME}" >> "$DNSMASQ_AWG_CONF"
                chunk_line="ipset=/"
                chunk_count=0
            fi
        done < "$f"
        [ $chunk_count -gt 0 ] && echo "${chunk_line}${IPSET_NAME}" >> "$DNSMASQ_AWG_CONF"
    done
    else
        ls "$GEO_DIR"/domains/*.txt "$GEO_DIR"/domains/*.lst >/dev/null 2>&1 && \
            log_msg "domain-geo disabled: ipset $IPSET_NAME unavailable (domains configured but not routable)"
    fi

    # Add conf-file include to dnsmasq (idempotent) — also when only filter-AAAA is set
    if [ $domain_count -gt 0 ] || [ "$want_aaaa" = 1 ]; then
        if ! grep -qF "conf-file=$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
            echo "conf-file=$DNSMASQ_AWG_CONF" >> "$DNSMASQ_INCLUDE"
        fi
    fi

    # --- Create custom chain in mangle table ---
    iptables -t mangle -N "$AWG_CHAIN" 2>/dev/null || iptables -t mangle -F "$AWG_CHAIN"

    # --- Exclusion rules (evaluated first) ---
    local lan_net
    lan_net=$(get_lan_net)
    local endpoint
    endpoint=$(get_endpoint)

    iptables -t mangle -A "$AWG_CHAIN" -m addrtype --dst-type LOCAL -j RETURN
    [ -n "$lan_net" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$lan_net" -j RETURN
    iptables -t mangle -A "$AWG_CHAIN" -p udp -m multiport --dports 67,68,123 -j RETURN
    iptables -t mangle -A "$AWG_CHAIN" -d 224.0.0.0/4 -j RETURN
    [ -n "$endpoint" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$endpoint" -j RETURN

    # --- Per-device rules (two passes for correct ordering) ---
    save_clients
    if [ -f "$CLIENTS_FILE" ] && [ -s "$CLIENTS_FILE" ]; then

        # Pass 1: "direct" exclusions (RETURN rules must come before MARK rules)
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' ')
            policy=$(echo "$policy" | tr -d ' ')
            mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue
            [ "$policy" != "direct" ] && continue

            if [ "$default_policy" != "direct" ]; then
                if [ -n "$mac" ]; then
                    iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" -j RETURN
                else
                    ip rule add from "$dev_id" lookup main prio 97
                fi
                log_msg "Route: $dev_id ($name) -> Direct (excluded)"
            else
                log_msg "Route: $dev_id ($name) -> Direct"
            fi
        done < "$CLIENTS_FILE"

        # Pass 2: vpn_all and vpn_geo rules
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' ')
            policy=$(echo "$policy" | tr -d ' ')
            mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue

            case "$policy" in
                vpn_all)
                    if [ -n "$mac" ]; then
                        iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" -j MARK --set-mark "$FWMARK"
                    else
                        ip rule add from "$dev_id" lookup $RT_TABLE prio 99
                    fi
                    log_msg "Route: $dev_id ($name) -> VPN (all)"
                    ;;
                vpn_geo)
                    if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
                        if [ -n "$mac" ]; then
                            iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" \
                                -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
                        else
                            iptables -t mangle -A "$AWG_CHAIN" -s "$dev_id" \
                                -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
                        fi
                        has_geo=true
                        log_msg "Route: $dev_id ($name) -> VPN (geo)"
                    else
                        log_msg "WARNING: ipset missing, skipping geo for $dev_id ($name)"
                    fi
                    ;;
            esac
        done < "$CLIENTS_FILE"
    fi

    # --- Default policy (last rules in chain) ---
    case "$default_policy" in
        vpn_all)
            iptables -t mangle -A "$AWG_CHAIN" -j MARK --set-mark "$FWMARK"
            log_msg "Default: all -> VPN"
            ;;
        vpn_geo)
            if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
                iptables -t mangle -A "$AWG_CHAIN" \
                    -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
                has_geo=true
                log_msg "Default: geo -> VPN"
            else
                log_msg "WARNING: ipset missing, geo default policy not applied"
            fi
            ;;
        direct|*)
            log_msg "Default: direct"
            ;;
    esac

    # --- Hook chain into PREROUTING ---
    iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>/dev/null || \
        iptables -t mangle -A PREROUTING -j "$AWG_CHAIN"

    # --- Single fwmark rule for all marked traffic ---
    ip rule add fwmark "$FWMARK" lookup $RT_TABLE prio 98

    # --- Force DNS through dnsmasq whenever VPN is active ---
    # The global :53 DNAT + DoH/DoT REJECT is the one piece that collides with a co-resident
    # DPI-bypass / proxy tool (zapret/zapret2, xray/XRAYUI, v2ray, sing-box) and can lock out
    # the LAN. Skip it when the user opted out (awg_no_dns_intercept=1) OR when such a tool is
    # detected — geo-by-IP (GeoIP / antifilter CIDR) keeps working; only forced domain-geo is
    # weakened for clients that use an external resolver instead of the router. This is what
    # lets AWG coexist with xray/zapret. NOTE: this only resolves the DNS-layer clash — with
    # default_policy=vpn_all the marks/table still steal the proxy's traffic, so coexistence
    # also needs a direct/geo default policy, not all->VPN.
    if [ "$default_policy" != "direct" ] || [ "$has_geo" = true ]; then
        if [ "$(get_setting awg_no_dns_intercept)" = "1" ]; then
            log_msg "DNS interception OFF (awg_no_dns_intercept=1) — coexistence mode"
        elif zapret_active; then
            log_msg "DNS interception OFF — zapret/xray/NFQUEUE detected, coexisting (geo-by-IP still active)"
        elif fw_dns_redirect_active; then
            log_msg "DNS interception OFF — firmware DNSFilter/DNS Director/DoT active, not overriding (geo-by-IP still active)"
        else
            setup_dns_interception
        fi
    fi

    # Coexistence guard: a co-resident proxy/DPI tool + an "all -> VPN" policy is a config
    # footgun. NOTE the proxy's OWN egress is locally generated (OUTPUT/POSTROUTING) and is
    # NOT captured by our PREROUTING chain — but vpn_all does pull LAN forward-traffic into
    # the tunnel that a transparent-proxy setup may want for itself. Warn loudly (the status
    # JSON also exposes coexist_warn); we never silently override the user's chosen policy.
    local _dpi
    _dpi=$(detect_dpi_tool)
    if [ -n "$_dpi" ] && { [ "$default_policy" = "vpn_all" ] || get_setting awg_clients | grep -q vpn_all; }; then
        log_msg "WARNING: $_dpi co-resident with an all->VPN policy — the tunnel will capture LAN traffic; use Direct or Geo-Only default policy to coexist"
    fi

    # --- Reload dnsmasq if geo active (deferred + retried; see reload_dnsmasq) ---
    if [ $domain_count -gt 0 ] || [ "$has_geo" = true ] || [ "$want_aaaa" = 1 ]; then
        reload_dnsmasq
    fi

    # --- Flush conntrack of already-marked flows so they re-establish through the tunnel.
    #     NOTE: this re-routes only flows that ALREADY carry our fwmark; a device just
    #     switched direct->VPN keeps its in-flight (unmarked) flows on their old path until
    #     they close. New connections route correctly immediately. ---
    flush_conntrack

    # --- Policy route for router-originated traffic. Re-added here (not only in
    #     do_start) so it survives firewall-restart and Apply, which call
    #     setup_firewall directly after cleanup_firewall removed it ---
    local awg_self
    awg_self=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -n "$awg_self" ] && ip rule add from "$awg_self" lookup $RT_TABLE prio 100 2>/dev/null

    # --- Cron: optional geo auto-update + route self-heal watchdog. The watchdog is
    #     (re)added here so it survives firewall-restart/Apply — cleanup_firewall drops
    #     it, and previously it was only added in do_start and was silently lost ---
    if [ "$(get_setting awg_geo_autoupdate)" = "1" ]; then
        cru a awg_geo_update "0 4 * * * '$ADDON_DIR/amneziawg.sh' update_geo"
    fi
    cru a awg_watchdog "*/5 * * * * '$ADDON_DIR/amneziawg.sh' watchdog"

    # Re-assert the IPv6 leak block here (idempotent) so it survives a bare Apply
    # (awgsaveconf -> setup_firewall), which previously tore it down without re-adding it.
    setup_ipv6_block

    log_msg "Firewall configured: $ip_count IPs, $domain_count domains"
}

save_clients(){
    local clients=$(get_setting awg_clients)
    if [ -n "$clients" ]; then
        echo "$clients" | tr ';' '\n' > "$CLIENTS_FILE"
    else
        > "$CLIENTS_FILE"
    fi
}

# Check if geo databases exist locally (GeoIP CIDRs or antifilter lists)
geo_available(){
    { [ -d "$GEO_DIR/geoip" ] && [ -n "$(ls "$GEO_DIR/geoip/"*.cidr 2>/dev/null)" ]; } && return 0
    { [ -d "$GEO_DIR/antifilter" ] && [ -n "$(ls "$GEO_DIR/antifilter/"*.cidr 2>/dev/null)" ]; } && return 0
    return 1
}

update_geo_if_needed(){
    if ! geo_available; then
        log_msg "WARNING: Geo databases not downloaded. Use Update Now in web UI."
    fi
}

# Re-download all geo databases (Update Now / auto-update cron). If awg_geo_wipe_update
# is on, wipe every geo file first (guarantees a clean set, but a failed re-download
# leaves that list missing); off (default) keeps existing lists on failure — download
# overwrites on success and prune_geoip drops de-selected. Caller runs do_firewall_restart
# afterwards, which re-extracts domains and reloads dnsmasq.
update_geo_lists(){
    [ -n "$GEO_DIR" ] || return 1
    if [ "$(get_setting awg_geo_wipe_update)" = "1" ]; then
        log_msg "Full geo refresh (wipe enabled): clearing old lists..."
        rm -rf "$GEO_DIR/geoip" "$GEO_DIR/domains" "$GEO_DIR/antifilter" 2>/dev/null
        rm -f "$GEO_DIR/v2fly_all.yml" "$GEO_DIR/v2fly_all.yml.tmp" "$GEO_DIR/v2fly_categories.txt" 2>/dev/null
    fi
    download_all_geo
}

# Is geo routing actually configured (so geo lists are worth downloading)?
geo_in_use(){
    case "$(get_setting awg_default_policy)" in *geo*) return 0 ;; esac
    case "$(get_setting awg_clients)" in *vpn_geo*) return 0 ;; esac
    [ -n "$(get_setting awg_geo_v2fly)$(get_setting awg_geo_v2fly_ip)$(get_setting awg_geo_custom_domains)$(get_setting awg_geo_custom_ips)$(get_setting awg_antifilter_lists)" ] && return 0
    return 1
}

# Download geo lists if they are configured but missing on disk — e.g. wiped by an
# update (prerm removes /opt/amneziawg) or a service/category just added in the UI.
# Runs in the background so Apply/Force Apply/update return promptly; the log shows
# progress and setup_firewall is re-applied afterwards.
ensure_geo(){
    prune_geoip   # delete .cidr of services removed from the field (sync on Apply/update)
    prune_antifilter   # likewise for de-selected antifilter lists
    geo_in_use || return 0
    # Collect ONLY what's missing — don't re-download lists that are already present
    # (adding one GeoIP service shouldn't re-fetch the others or the big v2fly DB).
    local need_svcs="" svc
    for svc in $(selected_geoip); do
        [ -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ] || need_svcs="$need_svcs $svc"
    done
    local need_yml=0
    [ -n "$(get_setting awg_geo_v2fly)" ] && [ ! -f "$GEO_DIR/v2fly_all.yml" ] && need_yml=1
    local need_af="" af_key
    for af_key in $(selected_antifilter); do
        if antifilter_is_domain "$af_key"; then
            [ -f "$GEO_DIR/domains/antifilter_${af_key}.lst" ] || need_af="$need_af $af_key"
        else
            [ -f "$GEO_DIR/antifilter/af_${af_key}.cidr" ] || need_af="$need_af $af_key"
        fi
    done
    [ -z "$need_svcs" ] && [ "$need_yml" = 0 ] && [ -z "$need_af" ] && return 0
    # Single-flight: only one background geo download at a time. Without this, a double
    # Apply/SaveConf (or Apply + update) fired ensure_geo twice and the old lockless "( ) &"
    # ran two download loops in lockstep — minutes of duplicate failing fetches plus two
    # back-to-back setup_firewall rebuilds. mkdir is busybox's only atomic test-and-set, so
    # acquire with plain mkdir (NOT mkdir -p, which returns 0 even if the dir already exists).
    # If the lock is held by a LIVE pid, skip — the running pass re-applies the firewall when
    # it finishes; a service added mid-download is picked up on the next Apply/update. If the
    # holder is gone (empty/dead pid -> crashed before its cleanup trap), reclaim the lock so
    # geo can't wedge off until a reboot. /tmp is tmpfs, so the lock never survives a reboot.
    if ! mkdir "$GEOLOCK" 2>/dev/null; then
        local gp; gp=$(cat "$GEOLOCK/pid" 2>/dev/null)
        if [ -n "$gp" ] && kill -0 "$gp" 2>/dev/null; then
            log_msg "Geo download already in progress (pid $gp) — skipping duplicate"
            return 0
        fi
        rm -rf "$GEOLOCK"
        mkdir "$GEOLOCK" 2>/dev/null || { log_msg "Geo download already in progress — skipping duplicate"; return 0; }
    fi
    log_msg "Downloading missing geo lists in background..."
    (
        trap 'rm -rf "$GEOLOCK"' EXIT INT TERM
        mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains" "$GEO_DIR/antifilter"
        for svc in $need_svcs; do
            log_msg "GeoIP: downloading $svc..."
            download_geoip_service "$svc" || log_msg "WARNING: GeoIP $svc failed"
            update_status
        done
        [ "$need_yml" = 1 ] && download_geosite
        for af_key in $need_af; do
            log_msg "Antifilter: downloading $af_key..."
            download_antifilter_list "$af_key" || log_msg "WARNING: Antifilter $af_key failed"
            update_status
        done
        # Re-apply under the operation lock so this background rebuild can't race
        # do_start/do_stop/do_firewall_restart (all of which hold LOCKDIR). A full
        # setup_firewall is required here (not the cheap do_firewall_restart fast-path) so
        # the freshly downloaded lists actually get loaded into the ipset. release_lock is
        # owner-aware, so it only frees the lock this subshell took.
        if is_running && acquire_lock; then
            setup_firewall
            release_lock
        fi
        update_status
    ) </dev/null >/dev/null 2>&1 &
    echo $! > "$GEOLOCK/pid" 2>/dev/null   # real bg-subshell PID, written by the parent
}

# --- Validation helpers ---

validate_wgkey(){
    echo "$1" | grep -qE '^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$' && return 0
    log_msg "ERROR: Invalid WireGuard key"
    return 1
}

validate_endpoint(){
    local host port
    port="${1##*:}"
    host="${1%:*}"
    echo "$port" | grep -qE '^[0-9]+$' || { log_msg "ERROR: Invalid endpoint port: $1"; return 1; }
    [ "$port" -ge 1 ] && [ "$port" -le 65535 ] 2>/dev/null || { log_msg "ERROR: Endpoint port out of range: $port"; return 1; }
    [ -n "$host" ] || { log_msg "ERROR: Empty endpoint host"; return 1; }
    return 0
}

validate_port(){
    echo "$1" | grep -qE '^[0-9]+$' || return 1
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ] 2>/dev/null || return 1
    return 0
}

validate_uint(){
    echo "$1" | grep -qE '^[0-9]+$' || return 1
    return 0
}

validate_header(){
    echo "$1" | grep -qE '^[0-9]([0-9-]*[0-9])?$' || return 1
    return 0
}

validate_ip(){
    echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || return 1
    return 0
}

# --- Generate awg0.conf ---

generate_config(){
    umask 077   # private key + config must not be world-readable
    mkdir -p "$AWG_DIR"

    local privkey=$(get_setting awg_privatekey)
    local listenport=$(get_setting awg_listenport)
    local jc=$(get_setting awg_jc)
    local jmin=$(get_setting awg_jmin)
    local jmax=$(get_setting awg_jmax)
    local s1=$(get_setting awg_s1)
    local s2=$(get_setting awg_s2)
    local s3=$(get_setting awg_s3)
    local s4=$(get_setting awg_s4)
    local h1=$(get_setting awg_h1)
    local h2=$(get_setting awg_h2)
    local h3=$(get_setting awg_h3)
    local h4=$(get_setting awg_h4)

    # I1-I5 from base64-encoded setting
    local i1="" i2="" i3="" i4="" i5=""
    local initdata=$(get_setting awg_initdata)
    if [ -n "$initdata" ]; then
        local decoded
        decoded=$(echo "$initdata" | base64 -d 2>/dev/null)
        i1=$(echo "$decoded" | awk '/^I1 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i2=$(echo "$decoded" | awk '/^I2 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i3=$(echo "$decoded" | awk '/^I3 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i4=$(echo "$decoded" | awk '/^I4 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i5=$(echo "$decoded" | awk '/^I5 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
    fi

    local peer_pubkey=$(get_setting awg_peer_pubkey)
    local peer_psk=$(get_setting awg_peer_psk)
    local peer_endpoint=$(get_setting awg_peer_endpoint)
    local peer_allowedips=$(get_setting awg_peer_allowedips | sed 's/,[[:space:]]*$//;s/,/, /g')
    local peer_keepalive=$(get_setting awg_peer_keepalive)

    if [ -z "$privkey" ] || [ -z "$peer_pubkey" ] || [ -z "$peer_endpoint" ]; then
        log_msg "ERROR: Missing required config"
        return 1
    fi
    validate_wgkey "$privkey" || return 1
    validate_wgkey "$peer_pubkey" || return 1
    [ -n "$peer_psk" ] && { validate_wgkey "$peer_psk" || return 1; }
    validate_endpoint "$peer_endpoint" || return 1
    [ -n "$listenport" ] && { validate_port "$listenport" || { log_msg "ERROR: Invalid listen port: $listenport"; return 1; }; }
    [ -n "$jc" ] && { validate_uint "$jc" || { log_msg "ERROR: Invalid Jc: $jc"; return 1; }; }
    [ -n "$jmin" ] && { validate_uint "$jmin" || { log_msg "ERROR: Invalid Jmin: $jmin"; return 1; }; }
    [ -n "$jmax" ] && { validate_uint "$jmax" || { log_msg "ERROR: Invalid Jmax: $jmax"; return 1; }; }
    [ -n "$s1" ] && { validate_uint "$s1" || { log_msg "ERROR: Invalid S1: $s1"; return 1; }; }
    [ -n "$s2" ] && { validate_uint "$s2" || { log_msg "ERROR: Invalid S2: $s2"; return 1; }; }
    [ -n "$s3" ] && { validate_uint "$s3" || { log_msg "ERROR: Invalid S3: $s3"; return 1; }; }
    [ -n "$s4" ] && { validate_uint "$s4" || { log_msg "ERROR: Invalid S4: $s4"; return 1; }; }
    [ -n "$h1" ] && { validate_header "$h1" || { log_msg "ERROR: Invalid H1: $h1"; return 1; }; }
    [ -n "$h2" ] && { validate_header "$h2" || { log_msg "ERROR: Invalid H2: $h2"; return 1; }; }
    [ -n "$h3" ] && { validate_header "$h3" || { log_msg "ERROR: Invalid H3: $h3"; return 1; }; }
    [ -n "$h4" ] && { validate_header "$h4" || { log_msg "ERROR: Invalid H4: $h4"; return 1; }; }

    {
        echo "[Interface]"
        echo "PrivateKey = $privkey"
        [ -n "$listenport" ] && echo "ListenPort = $listenport"
        [ -n "$jc" ] && echo "Jc = $jc"
        [ -n "$jmin" ] && echo "Jmin = $jmin"
        [ -n "$jmax" ] && echo "Jmax = $jmax"
        [ -n "$s1" ] && echo "S1 = $s1"
        [ -n "$s2" ] && echo "S2 = $s2"
        [ -n "$s3" ] && echo "S3 = $s3"
        [ -n "$s4" ] && echo "S4 = $s4"
        [ -n "$h1" ] && echo "H1 = $h1"
        [ -n "$h2" ] && echo "H2 = $h2"
        [ -n "$h3" ] && echo "H3 = $h3"
        [ -n "$h4" ] && echo "H4 = $h4"
        [ -n "$i1" ] && echo "I1 = $i1"
        [ -n "$i2" ] && echo "I2 = $i2"
        [ -n "$i3" ] && echo "I3 = $i3"
        [ -n "$i4" ] && echo "I4 = $i4"
        [ -n "$i5" ] && echo "I5 = $i5"
        echo ""
        echo "[Peer]"
        echo "PublicKey = $peer_pubkey"
        [ -n "$peer_psk" ] && echo "PresharedKey = $peer_psk"
        [ -n "$peer_endpoint" ] && echo "Endpoint = $peer_endpoint"
        echo "AllowedIPs = ${peer_allowedips:-0.0.0.0/0}"
        [ -n "$peer_keepalive" ] && echo "PersistentKeepalive = $peer_keepalive"
    } > "$CONF"

    chmod 600 "$CONF"

    local address=$(get_setting awg_address)
    [ -n "$address" ] && echo "$address" > "$AWG_DIR/awg0.addr"
    local dns=$(get_setting awg_dns)
    [ -n "$dns" ] && echo "$dns" > "$AWG_DIR/awg0.dns"

    log_msg "Config saved"
    return 0
}

# --- Diagnostics ---

# Print the ELF class / machine / ARM EABI float ABI of a binary using only busybox
# (dd + od) — the router has neither `file` nor `readelf`. Echoes e.g.
# "ELF32 ARM eabi=05 float=soft", "ELF64 AARCH64", or "missing" / "not-ELF(...)".
elf_arch(){
    local f="$1"
    [ -f "$f" ] || { echo "missing"; return; }
    # Just report the byte size — it reliably distinguishes builds (e.g. 176752 = soft-float
    # arm awg, 635816 = old hard-float, 3342498 = go daemon). Parsing the ELF header for
    # arch proved unreliable across this firmware's minimal busybox od (it rejected -A/-t,
    # and -b/-x didn't match either), and the live probes below are the authoritative arch
    # check anyway, so don't risk a misleading "not ELF" on a parse miss.
    echo "$(wc -c < "$f" 2>/dev/null)B"
}

# Run a command, capturing its exit/signal without aborting. Translates the shell's
# 128+signal codes for the ones that matter here (132=SIGILL, the wrong-arch symptom).
probe_bin(){
    local label="$1"; shift
    local out rc note=""
    out=$("$@" 2>&1); rc=$?
    case "$rc" in
        132) note="  <<< SIGILL (Illegal instruction — wrong-arch binary)" ;;
        134) note="  <<< SIGABRT" ;;
        139) note="  <<< SIGSEGV" ;;
        126|127) note="  <<< not executable / exec format error" ;;
    esac
    echo "  $label -> exit=$rc$note"
    [ -n "$out" ] && echo "      $(echo "$out" | head -2 | tr '\n' '|')"
}

# One-shot debug dump: platform, CPU, installed package, binary architectures, and live
# SIGILL probes. Read-only — safe to run anytime. Usage: amneziawg.sh diag
do_diag(){
    echo "================= AmneziaWG diag ================="
    echo "addon version    : $AWG_VERSION"
    echo "date             : $(date 2>/dev/null)"
    echo "--- platform ---"
    echo "uname -a         : $(uname -a 2>/dev/null)"
    echo "uname -m         : $(uname -m 2>/dev/null)"
    if [ -f /proc/cpuinfo ]; then
        echo "cpuinfo:"
        grep -iE 'model name|^processor|features|cpu architecture|cpu part|cpu variant|cpu implementer' /proc/cpuinfo | sed 's/^/  /'
    fi
    echo "opkg arch        :"
    opkg print-architecture 2>/dev/null | sed 's/^/  /' || echo "  (opkg not available)"
    echo "--- installed package ---"
    opkg list-installed 2>/dev/null | grep -i amnezia | sed 's/^/  /' || echo "  (amneziawg not in opkg db)"
    echo "--- binaries ($AWG_DIR) ---"
    ls -la "$AWG_GO" "$AWG_BIN" 2>/dev/null | sed 's/^/  /'
    echo "  amneziawg-go : $(elf_arch "$AWG_GO")"
    echo "  awg          : $(elf_arch "$AWG_BIN")"
    echo "--- ipset (selected: ${AWG_IPSET_BIN:-NONE}${AWG_IPSET_LIB:+ +LD_LIBRARY_PATH=$AWG_IPSET_LIB}) ---"
    for _b in /usr/sbin/ipset /sbin/ipset /opt/sbin/ipset; do
        [ -x "$_b" ] && echo "  $_b : $("$_b" version 2>&1 | head -1)"
    done
    echo "--- live probes (which binary raises Illegal instruction?) ---"
    probe_bin "amneziawg-go --version" "$AWG_GO" --version
    probe_bin "awg (usage)"            "$AWG_BIN"
    probe_bin "awg genkey (crypto)"    "$AWG_BIN" genkey
    echo "--- last amneziawg-go output (/tmp/awg_daemon.log) ---"
    [ -f /tmp/awg_daemon.log ] && sed 's/^/  /' /tmp/awg_daemon.log || echo "  (none)"
    echo "--- runtime / network / TUN ---"
    echo "memory (free):"; free 2>/dev/null | sed 's/^/  /'
    echo "amneziawg-go running : $(pidof amneziawg-go 2>/dev/null || echo no)"
    echo "dnsmasq running      : $(pidof dnsmasq 2>/dev/null || echo no)"
    echo "zapret/xray/NFQUEUE  : $(zapret_active && echo "yes -> DNS interception auto-off (coexist)" || echo no)"
    echo "lan_ipaddr           : $(nvram get lan_ipaddr 2>/dev/null)"
    echo "awg0 link            :"; ip link show "$IFACE" 2>&1 | sed 's/^/  /'
    echo "awg0 inet            : $(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}')"
    echo "tun module loaded    : $(lsmod 2>/dev/null | grep -q '^tun ' && echo yes || echo no)"
    echo "modprobe tun         : $(modprobe tun 2>&1; echo rc=$?)"
    echo "/dev/net/tun         :"; ls -la /dev/net/tun 2>&1 | sed 's/^/  /'
    echo "================================================="
}

# Detached LAN-safety net ("deadman"). A wrong/oversized config can leave the router
# without DHCP/DNS (dnsmasq dead) and lock everyone out — including SSH. Armed just before
# the risky firewall/DNS setup; after a grace period it checks dnsmasq and, if it's dead,
# rolls the VPN back and restarts dnsmasq so access returns without a physical reboot.
# Detached + </dev/null so it survives an SSH disconnect or the parent exiting.
arm_lan_deadman(){
    local gen="$1"   # amneziawg-go pid this start armed for; detects a superseding start
    (
        sleep 75
        # reload_dnsmasq bounces dnsmasq; re-check a few times before concluding it's dead.
        _k=0
        while [ $_k -lt 6 ]; do
            pidof dnsmasq >/dev/null 2>&1 && exit 0
            sleep 3; _k=$((_k + 1))
        done
        # Superseded-start guard: if the VPN is already down, or a DIFFERENT amneziawg-go now
        # owns the tunnel (a newer start/restart replaced the one we armed for), this is a
        # stale deadman — don't roll back a tunnel we weren't watching.
        is_running || exit 0
        [ -n "$gen" ] && ! pidof amneziawg-go 2>/dev/null | grep -qw "$gen" && exit 0
        logger -t "$SCRIPT_NAME" "DEADMAN: dnsmasq still down ~90s after start — rolling back VPN to restore LAN/DHCP"
        echo "$(date '+%H:%M:%S') DEADMAN: dnsmasq down, rolling back to restore LAN access" >> "$UI_LOG" 2>/dev/null
        # Auto-rollback (NOT a user stop) — keep the watchdog cron so recovery can continue.
        "$ADDON_DIR/amneziawg.sh" stop_auto >/dev/null 2>&1
        # Bounce dnsmasq only if it's actually still dead (do_stop's reload_dnsmasq may have
        # already revived it) — avoids fighting an in-flight reload.
        pidof dnsmasq >/dev/null 2>&1 || service restart_dnsmasq >/dev/null 2>&1
    ) </dev/null >/dev/null 2>&1 &
}

# --- Start ---

do_start(){
    # Skip if update in progress (opkg triggers S99amneziawg start)
    [ -f /tmp/.awg_no_autostart ] && { log_msg "Start blocked: update in progress"; return 0; }

    if is_running; then
        log_msg "Already running"
        update_status
        return 0
    fi

    # Mark start-in-progress so the UI shows "Connecting" even across a page
    # refresh; the trap clears it and writes the final status on any exit path.
    touch "$STARTING_FLAG"
    trap 'rm -f "$STARTING_FLAG"; update_status' EXIT INT TERM
    update_status

    # Wait for network to be ready (br0 up with IP), important on boot
    if ! ip -4 addr show br0 2>/dev/null | grep -q "inet "; then
        log_msg "Waiting for network (br0)..."
        wait_for_iface_ip br0 30
        if ! ip -4 addr show br0 2>/dev/null | grep -q "inet "; then
            log_msg "ERROR: Network not ready (br0 has no IP after 30s)"
            return 1
        fi
    fi

    acquire_lock || { log_msg "Cannot acquire lock, aborting start"; update_status; return 1; }

    generate_config || { update_status; release_lock; return 1; }
    [ ! -f "$CONF" ] && { log_msg "ERROR: No config"; update_status; release_lock; return 1; }
    [ ! -f "$AWG_GO" ] && { log_msg "ERROR: amneziawg-go not found"; update_status; release_lock; return 1; }

    # Ensure the TUN module is loaded + device node exists. Older routers (e.g.
    # RT-AC68U) don't autoload tun, and modprobe lives in /sbin — which is why
    # /sbin is on PATH above (it's missing when run from httpd/service-event).
    if ! lsmod 2>/dev/null | grep -q "^tun "; then
        modprobe tun 2>/dev/null || log_msg "WARNING: modprobe tun failed (module missing or modprobe not on PATH)"
    fi
    mkdir -p /dev/net
    [ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun

    # Start userspace daemon
    mkdir -p /var/run/amneziawg
    # Clean slate: a previous botched start can leave an orphaned amneziawg-go (and/or the
    # awg0 link) alive, holding the TUN — then a fresh daemon dies with "Failed to create
    # TUN device: device or resource busy". is_running already returned above if awg0 was
    # up, so anything left here is stale. Kill it and remove the link + stale control sock.
    if pidof amneziawg-go >/dev/null 2>&1; then
        log_msg "Clearing stale amneziawg-go before start (frees the TUN)"
        kill $(pidof amneziawg-go) 2>/dev/null
        wait_for_pid_exit amneziawg-go 5
        pidof amneziawg-go >/dev/null 2>&1 && kill -9 $(pidof amneziawg-go) 2>/dev/null
    fi
    ip link del "$IFACE" 2>/dev/null
    rm -f /var/run/amneziawg/"$IFACE".sock 2>/dev/null
    # Breadcrumb on every start: host arch + the arch of both binaries, so a wrong-arch
    # install is visible in the log without running 'diag' separately.
    log_msg "Platform $(uname -m): amneziawg-go=$(elf_arch "$AWG_GO") awg=$(elf_arch "$AWG_BIN")"
    log_msg "ipset binary: ${AWG_IPSET_BIN:-NONE (no working ipset found — geo will be disabled)}${AWG_IPSET_LIB:+ (LD_LIBRARY_PATH=$AWG_IPSET_LIB)}"
    "$AWG_GO" "$IFACE" > /tmp/awg_daemon.log 2>&1 &
    if ! wait_for_iface "$IFACE" 10; then
        log_msg "ERROR: amneziawg-go failed to create interface"
        [ -f /tmp/awg_daemon.log ] && log_msg "Daemon output: $(cat /tmp/awg_daemon.log)"
        pidof amneziawg-go >/dev/null 2>&1 && kill $(pidof amneziawg-go) 2>/dev/null
        update_status; release_lock; return 1
    fi
    log_msg "Userspace daemon started"

    # Configure interface. Capture the exit code explicitly: a wrong-arch awg dies with
    # SIGILL (shell exit 132 = 128 + signal 4) — the most common failure on old ARM
    # routers — so name it in the log instead of a generic "setconf failed".
    "$AWG_BIN" setconf "$IFACE" "$CONF"
    local sc_rc=$?
    if [ "$sc_rc" -ne 0 ]; then
        if [ "$sc_rc" -eq 132 ]; then
            log_msg "ERROR: 'awg setconf' killed by SIGILL (Illegal instruction) — wrong-arch awg"
            log_msg "  awg=$(elf_arch "$AWG_BIN") host=$(uname -m); run '$ADDON_DIR/amneziawg.sh diag'"
        else
            log_msg "ERROR: setconf failed (exit $sc_rc)"
        fi
        ip link del "$IFACE" 2>/dev/null
        pidof amneziawg-go >/dev/null 2>&1 && kill $(pidof amneziawg-go) 2>/dev/null
        update_status; release_lock; return 1
    fi

    [ -f "$AWG_DIR/awg0.addr" ] && ip addr add "$(cat "$AWG_DIR/awg0.addr")" dev "$IFACE"
    # MTU: configurable via awg_mtu (default 1280); fall back if unset/out of range
    local mtu=$(get_setting awg_mtu)
    { [ -n "$mtu" ] && validate_uint "$mtu" && [ "$mtu" -ge 576 ] && [ "$mtu" -le 1500 ]; } || mtu=1280
    ip link set "$IFACE" mtu "$mtu"
    ip link set "$IFACE" up

    # Routing table
    local lan_net gw endpoint
    lan_net=$(get_lan_net)
    gw=$(ip route | awk '/^default/{print $3; exit}')
    endpoint=$(get_endpoint)
    [ -n "$endpoint" ] && [ -n "$gw" ] && ip route add "$endpoint" via "$gw" 2>/dev/null
    ip route add 0.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    ip route add 128.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    [ -n "$lan_net" ] && ip route add "$lan_net" dev br0 table $RT_TABLE 2>/dev/null
    # Kill-switch (opt-in, awg_killswitch=1): a device-independent blackhole default in the
    # tunnel table. While awg0 is up the /1 routes (longer prefix) win; if awg0 vanishes
    # abnormally (daemon crash / OOM) the kernel purges the dev-awg0 routes but the policy
    # rules persist — without this, marked VPN-only traffic falls through to the WAN in
    # cleartext (fail-OPEN). With it, that traffic is dropped (fail-CLOSED). The
    # `ip route flush table $RT_TABLE` on stop/restart removes it.
    [ "$(get_setting awg_killswitch)" = "1" ] && ip route add blackhole default table $RT_TABLE metric 1000 2>/dev/null

    save_and_set_rp_filter

    # Base iptables
    iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -o "$IFACE" -j ACCEPT
    setup_ipv6_block
    iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    if [ -n "$lan_net" ]; then
        iptables -t nat -I POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    else
        iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE
    fi

    # Arm the LAN deadman BEFORE the risky part: setup_firewall does the ipset load, DNS
    # interception and dnsmasq reload — the steps that can lock the router out. If they
    # kill dnsmasq, the deadman rolls everything back within ~90s even if we hang here.
    arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
    setup_firewall

    log_msg "Started, verifying tunnel connectivity (probing: $(watchdog_hosts))..."
    update_status
    release_lock

    # Health check (detached): verify the tunnel passes traffic and roll back if not.
    # Backgrounded so the service-event handler returns promptly — otherwise
    # rc_service stays busy for up to ~60s and silently drops other events.
    (
        hc_ok=false
        hc_try=0
        hc_reason="not passing traffic (probed: $(watchdog_hosts))"
        while [ $hc_try -lt 30 ]; do
            if ping_hosts_once; then
                # ICMP is up. If we hijacked LAN DNS, also require it to actually resolve:
                # an ICMP-only "verified" tunnel leaves clients pinned to a dead resolver
                # (with DoH/DoT REJECTed too) = silent LAN-wide outage that never rolls back.
                # Skip the DNS gate when dnsmasq isn't up (a dnsmasq problem, not the tunnel's
                # — the 30x2s retry covers a brief restart; don't roll back the VPN for it).
                if ! dns_intercept_active || ! pidof dnsmasq >/dev/null 2>&1 || dns_ok; then
                    hc_ok=true
                    break
                fi
                hc_reason="DNS not resolving through tunnel"
            fi
            hc_try=$((hc_try + 1))
            sleep 2
        done
        if [ "$hc_ok" = true ]; then
            log_msg "Tunnel verified: traffic passing"
            update_status
        else
            log_msg "ERROR: Tunnel $hc_reason after 60s, rolling back to prevent lockout"
            do_stop 2>/dev/null
            log_msg "VPN stopped automatically. Check server config and endpoint reachability."
            update_status
        fi
    ) </dev/null >/dev/null 2>&1 &
}

# --- Stop ---

do_stop(){
    local user_stop="$1"   # "user" = deliberate user stop/uninstall; removes the watchdog cron
    acquire_lock || { log_msg "Cannot acquire lock, aborting stop"; return 1; }
    rm -f "$STARTING_FLAG"
    # Mark stop-in-progress so the UI shows "Stopping..." even across a page refresh
    touch "$STOPPING_FLAG"
    update_status

    iptables -D INPUT -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null
    cleanup_ipv6_block
    iptables -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    iptables -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    local lan_net
    lan_net=$(get_lan_net)
    [ -n "$lan_net" ] && iptables -t nat -D POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE 2>/dev/null
    iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null

    cleanup_firewall
    # On a deliberate user stop/uninstall, also drop the self-heal watchdog so the VPN stays
    # down. Auto-rollbacks (health-check, deadman) call do_stop withOUT "user", so the
    # watchdog survives and can still recover the tunnel on its own.
    [ "$user_stop" = "user" ] && cru d awg_watchdog 2>/dev/null

    ip route flush table $RT_TABLE 2>/dev/null
    local endpoint
    endpoint=$(get_endpoint)
    [ -n "$endpoint" ] && ip route del "$endpoint" 2>/dev/null

    restore_rp_filter

    # Stop the daemon FIRST so it releases the TUN before we remove the link — deleting the
    # link out from under a live amneziawg-go is the "device or resource busy" condition a
    # subsequent start would otherwise hit.
    local awg_pid
    awg_pid=$(pidof amneziawg-go 2>/dev/null)
    if [ -n "$awg_pid" ]; then
        kill "$awg_pid" 2>/dev/null
        wait_for_pid_exit amneziawg-go 5
        # Force kill if still alive (crashed/stuck process)
        pidof amneziawg-go >/dev/null 2>&1 && kill -9 "$(pidof amneziawg-go)" 2>/dev/null
    fi
    ip link set "$IFACE" down 2>/dev/null
    ip link del "$IFACE" 2>/dev/null
    rm -f /var/run/amneziawg/"$IFACE".sock

    reload_dnsmasq

    log_msg "Stopped"
    rm -f "$STOPPING_FLAG"
    update_status
    release_lock
}

# --- Status JSON for web UI ---

update_status(){
    local running=false
    local pub_key=""
    local listen_port=""
    local iface_addr=""
    local peers_json="[]"
    local log_text=""

    if is_running; then
        running=true
        iface_addr=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2; exit}')
        listen_port=$("$AWG_BIN" show "$IFACE" listen-port 2>/dev/null)
        pub_key=$("$AWG_BIN" show "$IFACE" public-key 2>/dev/null)

        local dump=$("$AWG_BIN" show "$IFACE" dump 2>/dev/null | tail -n +2)
        if [ -n "$dump" ]; then
            local p_items=""
            while IFS='	' read -r pkey psk endpoint aips handshake rx tx keepalive; do
                local hs_text="никогда"
                if [ "$handshake" != "0" ] && [ -n "$handshake" ]; then
                    local ago=$(( $(date +%s) - handshake ))
                    if [ $ago -lt 60 ]; then hs_text="${ago} с назад"
                    elif [ $ago -lt 3600 ]; then hs_text="$(( ago / 60 )) мин назад"
                    else hs_text="$(( ago / 3600 )) ч назад"; fi
                fi
                local rx_h=$(human_size "${rx:-0}")
                local tx_h=$(human_size "${tx:-0}")
                local item="{\"endpoint\":\"${endpoint}\",\"allowed_ips\":\"${aips}\",\"transfer_rx\":\"${rx_h}\",\"transfer_tx\":\"${tx_h}\",\"latest_handshake\":\"${hs_text}\"}"
                [ -n "$p_items" ] && p_items="${p_items},${item}" || p_items="$item"
            done <<EOF
$dump
EOF
            peers_json="[${p_items}]"
        fi
    fi

    log_text=$(grep "amneziawg" /tmp/syslog.log 2>/dev/null | tail -20 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local clients_data=$(get_setting awg_clients | sed 's/"/\\"/g')
    local active_rules=$(ip rule show 2>/dev/null | grep -c "lookup $RT_TABLE\|fwmark $FWMARK")

    local ipset_count=0
    ipset list "$IPSET_NAME" -t 2>/dev/null | grep -q "Number of entries" && \
        ipset_count=$(ipset list "$IPSET_NAME" -t 2>/dev/null | awk '/Number of entries/{print $NF}')

    local geo_domains=0
    [ -f "$DNSMASQ_AWG_CONF" ] && geo_domains=$(grep -c "^ipset=" "$DNSMASQ_AWG_CONF" 2>/dev/null)
    [ -z "$geo_domains" ] && geo_domains=0

    local geo_downloaded=false
    geo_available && geo_downloaded=true
    local geo_busy=false
    [ -f "$GEO_BUSY_FLAG" ] && geo_busy=true

    local starting=false
    [ -f "$STARTING_FLAG" ] && starting=true
    local stopping=false
    [ -f "$STOPPING_FLAG" ] && stopping=true

    # Co-resident DPI/proxy tool (Xray/zapret/etc.), surfaced to the UI so it can warn that
    # "all->VPN" + DNS interception will collide with it.
    local dpi_tool=$(detect_dpi_tool)
    # Kill-switch state (opt-in fail-closed routing) for the UI toggle.
    local killswitch=false
    [ "$(get_setting awg_killswitch)" = "1" ] && killswitch=true
    # Coexistence alarm: a DPI/proxy tool present AND an all->VPN policy that pulls LAN
    # traffic into the tunnel. Surfaced so the page can render a blocking banner.
    local coexist_warn=false
    [ -n "$dpi_tool" ] && [ "$default_policy" = "vpn_all" ] && coexist_warn=true

    # Write atomically (temp + rename) so the UI never reads a half-written file.
    cat > "${STATUS_FILE}.tmp" << STATUSEOF
{"running":${running},"starting":${starting},"stopping":${stopping},"version":"${AWG_VERSION}","public_key":"${pub_key}","listen_port":"${listen_port}","interface_addr":"${iface_addr}","peers":${peers_json},"default_policy":"${default_policy}","dpi_tool":"${dpi_tool}","killswitch":${killswitch},"coexist_warn":${coexist_warn},"clients":"${clients_data}","active_rules":${active_rules},"ipset_count":${ipset_count},"geo_domains":${geo_domains},"geo_downloaded":${geo_downloaded},"geo_busy":${geo_busy},"log":"${log_text}"}
STATUSEOF
    mv "${STATUS_FILE}.tmp" "$STATUS_FILE" 2>/dev/null
}

# --- Install/Mount/Uninstall ---

do_install_page(){
    source /usr/sbin/helper.sh
    nvram get rc_support | grep -q am_addons || { log_msg "ERROR: Addons not supported"; return 1; }

    mkdir -p "$ADDON_DIR"
    [ "$(readlink -f "$0")" != "$(readlink -f "$ADDON_DIR/amneziawg.sh")" ] && cp "$0" "$ADDON_DIR/amneziawg.sh"
    chmod +x "$ADDON_DIR/amneziawg.sh"

    [ -f "/tmp/amneziawg_page.asp" ] && cp /tmp/amneziawg_page.asp "$ADDON_DIR/amneziawg_page.asp"

    # Clean old page slots before requesting a new one
    for f in /www/user/user*.asp; do
        grep -q "AmneziaWG" "$f" 2>/dev/null && rm -f "$f"
    done

    am_get_webui_page "$ADDON_DIR/amneziawg_page.asp"
    [ "$am_webui_page" = "none" ] && { log_msg "ERROR: No page slot"; return 1; }

    cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$am_webui_page"
    # Publish the global header widget to the web root before binding the loader
    [ -f "$ADDON_DIR/amneziawg_widget.js" ] && cp "$ADDON_DIR/amneziawg_widget.js" /www/user/awg_widget.js 2>/dev/null
    mount_menu_tree "$am_webui_page"

    echo "{\"running\":false,\"starting\":false,\"stopping\":false,\"version\":\"${AWG_VERSION}\",\"killswitch\":false,\"coexist_warn\":false,\"dpi_tool\":\"\",\"peers\":[],\"log\":\"Installed.\"}" > "$STATUS_FILE"

    [ ! -f /jffs/scripts/service-event ] && echo "#!/bin/sh" > /jffs/scripts/service-event
    chmod +x /jffs/scripts/service-event 2>/dev/null
    if ! grep -q "amneziawg" /jffs/scripts/service-event; then
        echo 'echo "$2" | grep -q "^awg" && /jffs/addons/amneziawg/amneziawg.sh "service_event" "$1" "$2"' >> /jffs/scripts/service-event
    fi

    # WAN event hook
    [ ! -f /jffs/scripts/wan-event ] && echo "#!/bin/sh" > /jffs/scripts/wan-event
    chmod +x /jffs/scripts/wan-event 2>/dev/null
    if ! grep -q "amneziawg" /jffs/scripts/wan-event; then
        echo '/jffs/addons/amneziawg/amneziawg.sh wan_event "$1" "$2"  # AmneziaWG' >> /jffs/scripts/wan-event
    fi

    # Firewall restart hook
    [ ! -f /jffs/scripts/firewall-start ] && echo "#!/bin/sh" > /jffs/scripts/firewall-start
    chmod +x /jffs/scripts/firewall-start 2>/dev/null
    if ! grep -q "amneziawg" /jffs/scripts/firewall-start; then
        echo '/jffs/addons/amneziawg/amneziawg.sh firewall_restart  # AmneziaWG' >> /jffs/scripts/firewall-start
    fi

    [ ! -f /jffs/scripts/services-start ] && echo "#!/bin/sh" > /jffs/scripts/services-start
    chmod +x /jffs/scripts/services-start 2>/dev/null
    grep -q "amneziawg" /jffs/scripts/services-start || echo "/jffs/addons/amneziawg/amneziawg.sh mount_ui &" >> /jffs/scripts/services-start

    [ -f "$GEO_DIR/v2fly_categories.txt" ] && cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null

    log_msg "Page installed: $am_webui_page"
    echo "Installed. Access: VPN > AmneziaWG"
}

do_mount_ui(){
    source /usr/sbin/helper.sh
    # Clean old slots
    for f in /www/user/user*.asp; do
        grep -q "AmneziaWG" "$f" 2>/dev/null && rm -f "$f"
    done
    am_get_webui_page "$ADDON_DIR/amneziawg_page.asp"
    if [ "$am_webui_page" != "none" ]; then
        cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$am_webui_page"
        [ -f "$ADDON_DIR/amneziawg_widget.js" ] && cp "$ADDON_DIR/amneziawg_widget.js" /www/user/awg_widget.js 2>/dev/null
        mount_menu_tree "$am_webui_page"
    fi

    [ -f "$GEO_DIR/v2fly_categories.txt" ] && cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null
    update_status

    if [ "$(get_setting awg_autostart)" = "1" ]; then
        sleep 10
        do_start
    fi
}

do_uninstall(){
    do_stop user   # user intent: remove the watchdog cron too

    [ -f /jffs/scripts/service-event ] && sed -i '/amneziawg/d' /jffs/scripts/service-event
    [ -f /jffs/scripts/services-start ] && sed -i '/amneziawg/d' /jffs/scripts/services-start
    [ -f /jffs/scripts/wan-event ] && sed -i '/amneziawg/d' /jffs/scripts/wan-event
    [ -f /jffs/scripts/firewall-start ] && sed -i '/amneziawg/d' /jffs/scripts/firewall-start

    local page=$(ls /www/user/ 2>/dev/null | while read f; do grep -l "AmneziaWG" "/www/user/$f" 2>/dev/null; done | head -1)
    [ -n "$page" ] && rm -f "$page"
    rm -f "$STATUS_FILE" /www/user/awg_widget.js /www/user/v2fly_categories.htm /www/user/awg_changelog.htm /www/user/awg_update.htm /www/user/awg_log.htm /www/user/awg_diag.htm

    rm -rf "$ADDON_DIR"

    if [ -f /tmp/menuTree.js ]; then
        sed -i '/tabName: "AmneziaWG"/d' /tmp/menuTree.js
        sed -i '/\/\* AWG_WIDGET_START \*\//,/\/\* AWG_WIDGET_END \*\//d' /tmp/menuTree.js
        umount /www/require/modules/menuTree.js 2>/dev/null
        mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
    fi

    log_msg "Uninstalled"
}

# The tunnel liveness-probe target hosts: user-configured (awg_watchdog_hosts, space/comma
# separated) or the default anycast pair. Sanitized to a safe host charset (IPv4 or hostname:
# digits/letters/dot/dash) so a bad setting can't inject into the ping command, and capped to
# the first 4 so a long list can't drag out the probe. Empty/all-invalid -> default, so the
# watchdog can never be left with nothing to probe. Tip: prefer IPs (no DNS dependency). Make
# these configurable because a fixed target (8.8.8.8) can be blocked/unreachable at certain
# times, which would make the watchdog false-fail and restart a healthy tunnel.
watchdog_hosts(){
    local raw out="" h n=0
    raw=$(get_setting awg_watchdog_hosts | tr ',' ' ')
    for h in $raw; do
        # Must START with an alnum (every IP/hostname does). This also blocks a token that
        # begins with '-' from being read by ping as an OPTION (e.g. "-f" = flood) instead of
        # a host. Then require only safe host chars in the rest.
        case "$h" in ""|[!0-9A-Za-z]*) continue ;; esac
        case "$h" in *[!0-9A-Za-z.-]*) continue ;; esac
        out="$out $h"; n=$((n + 1))
        [ $n -ge 4 ] && break
    done
    [ -n "$out" ] && { echo "${out# }"; return; }
    echo "8.8.8.8 1.1.1.1"
}

# Ping each configured host once through the tunnel; return 0 on the FIRST reply. Single pass
# (no sleeps) — callers add their own retry cadence.
ping_hosts_once(){
    local h
    for h in $(watchdog_hosts); do
        ping -c 1 -W 2 -I "$IFACE" "$h" >/dev/null 2>&1 && return 0
    done
    return 1
}

# Is the tunnel passing traffic? True if ANY configured host replies across a couple of quick
# rounds. A SINGLE ICMP can be dropped/delayed past its timeout under heavy tunnel load (e.g.
# streaming) without the tunnel being down — restarting the whole VPN on one miss tore working
# tunnels down every 5-min watchdog tick and broke streams (1.1.69 regression). Only a
# sustained all-miss across all hosts counts as dead. Returns on the first reply (fast).
tunnel_alive(){
    local i=0
    while [ $i -lt 2 ]; do
        ping_hosts_once && return 0
        i=$((i + 1)); sleep 1
    done
    return 1
}

# Cheap WAN-renumber heal: if the endpoint host-route points via a stale gateway (PPPoE
# re-dial / DHCP-WAN lease change), just re-pin it instead of a full VPN teardown. Returns 0
# if it re-pinned (caller should re-probe). Skips hostname endpoints (no host-route exists).
repin_endpoint_route(){
    local endpoint cur have
    endpoint=$(get_endpoint)
    [ -n "$endpoint" ] || return 1
    case "$endpoint" in *[!0-9.]*) return 1 ;; esac   # not an IPv4 literal -> no host-route
    cur=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')
    [ -n "$cur" ] || return 1
    have=$(ip route show "$endpoint" 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="via") print $(i+1)}')
    [ "$have" = "$cur" ] && return 1
    ip route del "$endpoint" 2>/dev/null
    ip route add "$endpoint" via "$cur" 2>/dev/null
    log_msg "WATCHDOG: endpoint route re-pinned $endpoint via $cur (was ${have:-none})"
    return 0
}

# --- Watchdog (called by cron every 5 min) ---

do_watchdog(){
    # Skip if lock held (another operation in progress)
    [ -d "$LOCKDIR" ] && return 0

    # DNS-interception coexistence reconcile (only while the tunnel is up). Our one-shot
    # decision at setup_firewall time goes stale when a DPI/proxy tool starts AFTER us, when
    # dnsmasq wasn't up yet at boot, or when the DPI tool is later removed. Re-evaluate here —
    # cheap, idempotent — and catch the br0-side ":53 collision" that dns_ok (which probes
    # 127.0.0.1, bypassing the DNAT) can't see, WITHOUT a full VPN restart.
    if is_running; then
        if dns_intercept_active && { zapret_active || fw_dns_redirect_active || [ "$(get_setting awg_no_dns_intercept)" = "1" ]; }; then
            log_msg "WATCHDOG: co-resident DNS owner detected — removing our :53 interception (coexist)"
            cleanup_dns_interception
        elif ! dns_intercept_active && intercept_wanted; then
            log_msg "WATCHDOG: DNS interception now warranted (DPI gone / dnsmasq up) — installing"
            setup_dns_interception
        fi
    fi

    local reason=""
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        reason="interface $IFACE missing"
    elif ! pidof amneziawg-go >/dev/null 2>&1; then
        reason="amneziawg-go process dead"
    elif ! tunnel_alive; then
        # Before a full teardown, try the cheap WAN-renumber heal: a stale endpoint gateway
        # (PPPoE re-dial / DHCP renumber) black-holes the handshake. Re-pin and re-probe.
        if repin_endpoint_route && tunnel_alive; then
            : # re-pin fixed it; tunnel passing again
        else
            reason="tunnel not passing traffic (probed: $(watchdog_hosts))"
        fi
    elif dns_intercept_active && pidof dnsmasq >/dev/null 2>&1 && ! dns_ok; then
        # Confirm before acting: dnsmasq gets bounced by many unrelated events (DHCP lease
        # churn, other addons, our own reload_dnsmasq). Re-probe after a short settle so a
        # transient resolver blip doesn't trigger a full VPN restart — only a DNS that stays
        # dead WHILE dnsmasq is up is the tunnel-DNS lockout we want to roll back.
        sleep 5
        if pidof dnsmasq >/dev/null 2>&1 && ! dns_ok; then
            reason="DNS not resolving through tunnel"
        fi
    fi

    local wd_state="/tmp/.awg_wd_state"
    if [ -n "$reason" ]; then
        # Backoff: don't churn a 5-min teardown/rebuild loop when the server is simply
        # unreachable. Widen the retry interval with consecutive failures (5 min * N,
        # capped at 60 min) so the LAN settles into a stable "VPN down" state.
        local fails last now cooldown
        fails=$(sed -n 1p "$wd_state" 2>/dev/null); [ -z "$fails" ] && fails=0
        last=$(sed -n 2p "$wd_state" 2>/dev/null); [ -z "$last" ] && last=0
        now=$(date +%s 2>/dev/null); [ -z "$now" ] && now=0
        cooldown=$((fails * 300)); [ $cooldown -gt 3600 ] && cooldown=3600
        if [ $fails -gt 0 ] && [ $now -gt 0 ] && [ $((now - last)) -lt $cooldown ]; then
            log_msg "WATCHDOG: $reason, backing off ($fails consecutive failures)"
            return
        fi
        log_msg "WATCHDOG: $reason, restarting"
        printf '%s\n%s\n' "$((fails + 1))" "$now" > "$wd_state" 2>/dev/null
        do_stop 2>/dev/null
        wait_for_pid_exit amneziawg-go 10
        do_start
        return
    fi
    rm -f "$wd_state" 2>/dev/null   # healthy: reset backoff counter

    # A firewall restart wipes our mangle chain/hook (the packet marking) while the
    # tunnel and route table stay up — the checks above still pass. Detect the
    # missing PREROUTING hook (what restart_firewall actually drops) OR a lost policy
    # route and rebuild — lighter than a full restart, self-heals within ~5 min even
    # if the firewall-start hook didn't fire. (Old code checked only the route and
    # missed the far more common mangle-reset case.)
    if ! iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>/dev/null \
       || ! ip route show table $RT_TABLE 2>/dev/null | grep -q "0.0.0.0/1"; then
        log_msg "WATCHDOG: routing/marking incomplete, re-applying firewall/routes"
        do_firewall_restart
    fi
}

# --- Update check ---

# Resolve the latest published version (e.g. "1.1.43"). GitHub's API is freshest, but
# api.github.com is blocked in some regions, so fall back to jsDelivr (reachable where
# GitHub's API is not): first its data API (newest git tag), then PKG_VERSION from
# build-ipk.sh on the CDN. Echoes the version, or nothing if every source is unreachable.
awg_resolve_version(){
    local repo="$1" skip_api="$2" v=""
    local awg_bind=$(awg_dl_iface_opt update)
    # api.github.com first (freshest), unless the caller already found it unreachable
    # — re-trying a blocked API just adds another connect timeout to the wait.
    if [ "$skip_api" != "skip_api" ]; then
        v=$(curl -sfL $awg_bind --connect-timeout 5 --max-time 12 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//;s/^v//;s/".*//')
    fi
    [ -z "$v" ] && v=$(curl -sfL $awg_bind --connect-timeout 6 --max-time 15 "https://data.jsdelivr.com/v1/packages/gh/${repo}/resolved" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -z "$v" ] && v=$(curl -sfL $awg_bind --connect-timeout 6 --max-time 15 "https://cdn.jsdelivr.net/gh/${repo}@latest/build-ipk.sh" 2>/dev/null | sed -n 's/^PKG_VERSION="\([0-9][0-9.]*\).*/\1/p' | head -1)
    case "$v" in ""|*[!0-9.]*) return 1 ;; esac
    echo "$v"
}

check_update(){
    local repo="william-aqn/asuswrt-merlin-amneziawg"
    local latest
    latest=$(awg_resolve_version "$repo")
    if [ -z "$latest" ]; then
        echo "{\"current\":\"$AWG_VERSION\",\"latest\":\"\",\"update\":false,\"error\":\"Cannot reach GitHub\"}"
        return
    fi
    local update=false
    [ "$latest" != "$AWG_VERSION" ] && update=true
    echo "{\"current\":\"$AWG_VERSION\",\"latest\":\"$latest\",\"update\":$update}"
}

# Install a ready .ipk at $1 (human label $2, e.g. "v1.2.3" or "uploaded package").
# Shared by do_update (after a verified download) and do_manual_install (after a
# verified upload). Preserves geo lists across the opkg upgrade, stops the VPN, installs,
# restores geo, re-installs the web page from the new version and refreshes status.
finalize_ipk_install(){
    local tmp="$1" label="$2"

    # Preserve geo lists across the upgrade unless "wipe before update" is on. The
    # package prerm runs 'rm -rf /opt/amneziawg', so move geo to a sibling dir (same
    # filesystem = instant rename, no extra space) that survives, and restore it after.
    local geo_bak="${AWG_DIR}_geobak"
    rm -rf "$geo_bak" 2>/dev/null
    if [ "$(get_setting awg_geo_wipe_update)" != "1" ] && [ -d "$GEO_DIR" ]; then
        mv "$GEO_DIR" "$geo_bak" 2>/dev/null && log_msg "Update: preserving geo lists"
    fi

    log_msg "Update: stopping VPN"
    do_stop 2>/dev/null
    wait_for_pid_exit amneziawg-go 10
    # Block auto-start during opkg install (S99amneziawg is triggered by opkg)
    touch /tmp/.awg_no_autostart
    log_msg "Update: installing package via opkg"
    if ! opkg install "$tmp" && ! opkg install --force-architecture "$tmp"; then
        log_msg "Update: ERROR opkg install failed — staying on v$AWG_VERSION"
        rm -f "$tmp" /tmp/.awg_no_autostart
        if [ -d "$geo_bak" ]; then mkdir -p "$AWG_DIR"; mv "$geo_bak" "$GEO_DIR" 2>/dev/null; fi
        update_status; return 1
    fi
    rm -f "$tmp"
    # Stop VPN if opkg's init script started it
    do_stop 2>/dev/null
    wait_for_pid_exit amneziawg-go 10
    rm -f /tmp/.awg_no_autostart
    # Restore preserved geo lists (if we moved them aside above)
    if [ -d "$geo_bak" ]; then
        rm -rf "$GEO_DIR" 2>/dev/null
        mkdir -p "$AWG_DIR"
        mv "$geo_bak" "$GEO_DIR" 2>/dev/null && log_msg "Update: geo lists restored"
    fi
    # Install page from new version
    /jffs/addons/amneziawg/amneziawg.sh install_page
    log_msg "Update: complete — now on $label. Start VPN from the UI."
    # Refresh status with the NEW script (this process still runs the old code in memory,
    # so calling update_status directly would re-write the OLD version number).
    /jffs/addons/amneziawg/amneziawg.sh status 2>/dev/null
    # If geo wasn't preserved (wipe option on, or restore failed), re-download with the NEW script.
    /jffs/addons/amneziawg/amneziawg.sh ensure_geo 2>/dev/null
    return 0
}

# Manual install: assemble a base64-encoded .ipk uploaded chunk-by-chunk from the web UI
# (see the awgupload service event), verify it, and install it. The browser cannot POST a
# multi-MB binary through the firmware's apply path (httpd caps it and is line-oriented),
# so the file arrives as base64 text appended to AWG_UPLOAD_B64; here we decode it once,
# check the exact byte length the browser reported, validate the gzip CRC (an .ipk is a
# tar.gz, so a corrupt/truncated upload fails this) and the opkg .ipk structure, then
# hand off to finalize_ipk_install. Progress/result is written to AWG_UPLOAD_STATUS for
# the UI to poll. Nothing is installed unless every check passes.
do_manual_install(){
    local b64="$AWG_UPLOAD_B64" tmp="/tmp/amneziawg_manual.ipk"
    local want_len got_len tok
    # Read the upload token BEFORE clearing the one-shot keys, and stamp it on every final
    # status line (awg_man_status). The UI matches on this token, so a stale poller from a
    # previous/aborted upload can never act on another run's result.
    tok=$(get_setting awg_ipk_token)
    tok=$(printf '%s' "$tok" | tr -cd 'A-Za-z0-9_-')
    want_len=$(get_setting awg_ipk_len)
    # One-shot keys: clear now so a stale chunk/length can never affect a later operation.
    clear_setting awg_ipk_len
    clear_setting awg_ipk_chunk
    clear_setting awg_ipk_seq
    clear_setting awg_ipk_first
    clear_setting awg_ipk_token
    rm -f "$AWG_UPLOAD_SEQ"
    case "$want_len" in *[!0-9]*) want_len="" ;; esac

    ui_log_reset
    log_msg "Manual install: assembling uploaded package"
    if [ ! -s "$b64" ]; then
        log_msg "Manual install: ERROR no upload data received"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"Нет данных загрузки\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$b64"; update_status; return 1
    fi

    # Decode base64 text -> binary .ipk (busybox base64 -d, openssl fallback).
    if ! base64 -d "$b64" > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
        if ! openssl base64 -d -A -in "$b64" -out "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
            log_msg "Manual install: ERROR base64 decode failed"
            echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"Ошибка декодирования\"}" > "$AWG_UPLOAD_STATUS"
            rm -f "$b64" "$tmp"; update_status; return 1
        fi
    fi
    rm -f "$b64"

    got_len=$(wc -c < "$tmp" 2>/dev/null)
    if [ -n "$want_len" ] && [ "$got_len" != "$want_len" ]; then
        log_msg "Manual install: ERROR size mismatch (got ${got_len}, expected ${want_len})"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"Размер не совпал — загрузка повреждена\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi

    # An .ipk is a gzip-compressed tar. Decompress the WHOLE stream (reads to EOF and
    # verifies the trailing gzip CRC32/length), so any corruption or truncation that
    # slipped through the upload is caught here, BEFORE we touch opkg. gzip/gunzip is
    # always present (opkg itself needs it); try both applet spellings.
    if ! gzip -dc "$tmp" > /dev/null 2>&1 && ! gunzip -c "$tmp" > /dev/null 2>&1; then
        log_msg "Manual install: ERROR archive is corrupt (gzip CRC check failed)"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"Файл повреждён или не .ipk\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi
    # Must be an opkg .ipk: a gzip tar that contains control.tar.gz (the last member, so a
    # successful listing also proves the archive decompressed fully).
    if ! tar tzf "$tmp" 2>/dev/null | grep -q 'control\.tar\.gz'; then
        log_msg "Manual install: ERROR not an opkg package (no control.tar.gz)"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"Это не пакет opkg (.ipk)\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi

    log_msg "Manual install: package OK ($(human_size "$got_len")) — installing"
    if finalize_ipk_install "$tmp" "загруженный пакет"; then
        echo "{\"status\":\"installed\",\"tok\":\"$tok\"}" > "$AWG_UPLOAD_STATUS"
    else
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"msg\":\"opkg install не удался\"}" > "$AWG_UPLOAD_STATUS"
    fi
}

do_update(){
    local repo="william-aqn/asuswrt-merlin-amneziawg"
    # "Update via VPN" bind, resolved while the tunnel is still up (do_update stops it only
    # later, in finalize_ipk_install — every download below happens before that).
    local awg_bind=$(awg_dl_iface_opt update)
    # Target version: explicit CLI arg ($1), else a one-shot version pinned by the UI
    # (custom setting), else empty = resolve the latest. Cleared right away so a pinned
    # version can never carry over to a later automatic update.
    local target="$1"
    [ -z "$target" ] && target=$(get_setting awg_update_version)
    clear_setting awg_update_version
    case "$target" in *[!0-9.]*) target="" ;; esac

    log_msg "Update: starting (installed v$AWG_VERSION)"

    local pkg_arch
    pkg_arch=$(opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2!="all" {print $2}' | head -1)
    if [ -z "$pkg_arch" ]; then
        local arch=$(uname -m)
        case "$arch" in
            aarch64) pkg_arch="aarch64-3.10" ;;
            armv7l)  pkg_arch="armv7-2.6" ;;
            *) log_msg "Update: ERROR unsupported architecture: $arch"; update_status; return 1 ;;
        esac
    fi

    # Resolve the version and, when api.github.com is reachable, grab the release JSON
    # (it carries the per-asset SHA256 digest we verify against). One API call gives both
    # the version and the digest.
    if [ -n "$awg_bind" ]; then
        log_msg "Update: egress via VPN tunnel ${awg_bind#--interface } (awg_update_via_awg=1)"
    else
        log_msg "Update: egress via WAN (direct)"
    fi

    local version="" rel_json="" api_rc
    if [ -n "$target" ]; then
        version="$target"
        log_msg "Update: requested version v$version (pinned)"
        local api_url="https://api.github.com/repos/${repo}/releases/tags/v${version}"
        log_msg "Update: querying $api_url"
        rel_json=$(curl -sfL $awg_bind --connect-timeout 5 --max-time 12 "$api_url" 2>/dev/null); api_rc=$?
        [ -n "$rel_json" ] && log_msg "Update: GitHub API OK (release metadata for v$version fetched)" \
                           || log_msg "Update: GitHub API gave nothing for v$version ($(curl_err_hint "$api_rc")) — release may not exist or API is blocked"
    else
        local api_url="https://api.github.com/repos/${repo}/releases/latest"
        log_msg "Update: resolving latest version via $api_url"
        rel_json=$(curl -sfL $awg_bind --connect-timeout 5 --max-time 12 "$api_url" 2>/dev/null); api_rc=$?
        [ -n "$rel_json" ] && version=$(echo "$rel_json" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//;s/^v//;s/".*//')
        # API blocked or unparsable -> jsDelivr (API already tried, so skip it there)
        if [ -z "$version" ]; then
            log_msg "Update: GitHub API gave no version ($(curl_err_hint "$api_rc")) — falling back to jsDelivr"
            version=$(awg_resolve_version "$repo" skip_api)
            [ -n "$version" ] && log_msg "Update: resolved v$version via jsDelivr"
        else
            log_msg "Update: GitHub API resolved latest as v$version"
        fi
        if [ -z "$version" ]; then
            log_msg "Update: ERROR could not resolve latest version (api.github.com and jsDelivr both unreachable)"
            update_status; return 1
        fi
    fi

    if [ "$version" = "$AWG_VERSION" ]; then
        log_msg "Update: already on v$AWG_VERSION — nothing to install"
        update_status
        return 0
    fi

    # Asset name is deterministic (build-ipk.sh: amneziawg_<ver>-1_<arch>.ipk).
    local ipk_url="https://github.com/${repo}/releases/download/v${version}/amneziawg_${version}-1_${pkg_arch}.ipk"
    local tmp="/tmp/amneziawg_update.ipk"

    # Best-effort SHA256 from the GitHub API digest. If api.github.com is blocked there's
    # no digest — then we skip the check and install anyway rather than refuse.
    local ipk_file expected_sha=""
    ipk_file=$(basename "$ipk_url")
    if [ -n "$rel_json" ]; then
        expected_sha=$(echo "$rel_json" | awk -v f="$ipk_file" '
            /"name":/ { in_a = (index($0, f) > 0) }
            in_a && /"digest":/ { s=$0; sub(/.*sha256:/, "", s); sub(/".*/, "", s); print s; exit }
        ')
        case "$expected_sha" in *[!0-9a-fA-F]*) expected_sha="" ;; esac
    fi
    [ -n "$expected_sha" ] && log_msg "Update: SHA256 from GitHub API — will verify" || log_msg "Update: SHA256 unavailable (API blocked) — skipping check"

    # Download: GitHub direct, then proxy mirrors (the release-assets host is often
    # unreachable in some regions). --speed-limit/--speed-time aborts a stalled
    # connection in ~15s (a blocked host accepts the socket then goes silent) so we
    # fall through to a working mirror fast instead of hanging on --max-time.
    # NOTE: jsDelivr is NOT a fallback here — it mirrors git-tracked repo files, not
    # GitHub *release assets*, so it cannot serve the .ipk.
    log_msg "Update: downloading v$version ($pkg_arch) — asset $ipk_file"
    local dl_ok=0 prefix label full_url rc http
    for prefix in "" "https://ghproxy.net/" "https://gh-proxy.com/"; do
        full_url="${prefix}${ipk_url}"
        [ -z "$prefix" ] && label="github.com" || label="$prefix"
        log_msg "Update: trying $full_url"
        # -w prints the final HTTP status; -f still suppresses the error body. Capturing
        # both the curl exit code and the HTTP code tells a 404 (asset missing) apart from
        # a connection failure (blocked/timeout) — they used to look identical in the log.
        http=$(curl -sfL $awg_bind --connect-timeout 8 --max-time 90 --speed-limit 1024 --speed-time 15 -w '%{http_code}' "$full_url" -o "$tmp" 2>/dev/null); rc=$?
        if [ "$rc" = 0 ] && [ -s "$tmp" ]; then
            log_msg "Update: downloaded $(human_size "$(wc -c < "$tmp" 2>/dev/null)") from $label (HTTP ${http:-?})"
            dl_ok=1; break
        fi
        rm -f "$tmp"
        log_msg "Update: $label failed — HTTP ${http:-000}, $(curl_err_hint "$rc")"
    done
    if [ "$dl_ok" != 1 ]; then
        log_msg "Update: ERROR download failed for v$version — none of github.com / ghproxy.net / gh-proxy.com served $ipk_file"
        log_msg "Update: if HTTP was 404 above, the v$version release/asset does not exist; if it was connection errors, GitHub is unreachable from this egress path"
        rm -f "$tmp"; update_status; return 1
    fi

    if [ -n "$expected_sha" ]; then
        local actual_sha
        actual_sha=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
        [ -z "$actual_sha" ] && actual_sha=$(openssl dgst -sha256 "$tmp" 2>/dev/null | awk '{print $NF}')
        if [ -n "$actual_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
            log_msg "Update: ERROR SHA256 mismatch — refusing to install"
            rm -f "$tmp"; update_status; return 1
        fi
        log_msg "Update: SHA256 verified"
    fi

    finalize_ipk_install "$tmp" "v$version"
}

do_wan_event(){
    local wan_if="$1" wan_state="$2"
    [ "$wan_state" != "connected" ] && return 0
    if is_running; then
        log_msg "WAN event: $wan_state on $wan_if, updating endpoint route"
        local gw endpoint
        gw=$(ip route | awk '/^default/{print $3; exit}')
        endpoint=$(get_endpoint)
        if [ -n "$endpoint" ] && [ -n "$gw" ]; then
            ip route del "$endpoint" 2>/dev/null
            ip route add "$endpoint" via "$gw" 2>/dev/null
            log_msg "Endpoint route updated: $endpoint via $gw"
        fi
    fi
}

do_firewall_restart(){
    is_running || return 0
    # Fast path (the firewall-start hook passes "fast"): if the firmware's firewall restart
    # did NOT actually clobber our mangle hook or the tunnel routes, there's nothing to
    # rebuild — skip the full teardown+rebuild and its brief leak/blackhole window. Internal
    # callers (awgupdategeo, update_geo, watchdog heal) call WITHOUT "fast" to force a full
    # rebuild (e.g. to reload a freshly downloaded ipset).
    if [ "$1" = "fast" ] \
       && iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>/dev/null \
       && ip route show table $RT_TABLE 2>/dev/null | grep -q "0.0.0.0/1"; then
        return 0
    fi
    log_msg "Firewall restart detected, re-applying routes and rules"
    acquire_lock || { log_msg "Cannot acquire lock, aborting firewall restart"; return 1; }

    # --- Tear down current routing + firewall (mirror do_stop) ---
    iptables -D INPUT -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null
    cleanup_ipv6_block
    iptables -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    iptables -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    local lan_net_old
    lan_net_old=$(get_lan_net)
    [ -n "$lan_net_old" ] && iptables -t nat -D POSTROUTING -s "$lan_net_old" -o "$IFACE" -j MASQUERADE 2>/dev/null
    iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null
    cleanup_firewall
    ip route flush table $RT_TABLE 2>/dev/null
    local endpoint_old
    endpoint_old=$(get_endpoint)
    [ -n "$endpoint_old" ] && ip route del "$endpoint_old" 2>/dev/null
    restore_rp_filter

    # --- Rebuild routing + firewall (mirror do_start); routes are the part the
    #     old version missed, so GeoSite/VPN routing broke after a firewall event ---
    local lan_net gw endpoint
    lan_net=$(get_lan_net)
    gw=$(ip route | awk '/^default/{print $3; exit}')
    endpoint=$(get_endpoint)
    [ -n "$endpoint" ] && [ -n "$gw" ] && ip route add "$endpoint" via "$gw" 2>/dev/null
    ip route add 0.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    ip route add 128.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    [ -n "$lan_net" ] && ip route add "$lan_net" dev br0 table $RT_TABLE 2>/dev/null
    # Kill-switch (opt-in) — see do_start for rationale; survives awg0 disappearing.
    [ "$(get_setting awg_killswitch)" = "1" ] && ip route add blackhole default table $RT_TABLE metric 1000 2>/dev/null

    save_and_set_rp_filter

    iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -o "$IFACE" -j ACCEPT
    setup_ipv6_block
    iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    if [ -n "$lan_net" ]; then
        iptables -t nat -I POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    else
        iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE
    fi

    setup_firewall

    release_lock
    log_msg "Firewall/routes re-applied"
}

# --- Service event dispatcher ---

do_service_event(){
    local event="$2"
    case "$event" in
        awgstart|awgstop|awgrestart|awgforceapply|awgsaveconf|awgupdategeo|awgdoupdate) ui_log_reset ;;
    esac
    case "$event" in
        # Manual upload: append one base64 chunk. Kept out of the ui_log_reset list above
        # (it fires once per chunk — would wipe the log repeatedly). Idempotent by seq so a
        # retried/duplicated POST never double-appends; ack is written for the UI to poll.
        awgupload)
            local seq first chunk tok st exp
            seq=$(get_setting awg_ipk_seq)
            first=$(get_setting awg_ipk_first)
            chunk=$(get_setting awg_ipk_chunk)
            tok=$(get_setting awg_ipk_token)
            # Token identifies this upload run; the UI ignores acks whose token doesn't
            # match, so a stale awg_upload.htm from a previous attempt can't be mistaken
            # for a fresh ack. Keep only the safe charset (alnum/_/-) in the echoed JSON.
            tok=$(printf '%s' "$tok" | tr -cd 'A-Za-z0-9_-')
            case "$seq" in ''|*[!0-9]*)
                echo "{\"status\":\"err\",\"tok\":\"$tok\",\"msg\":\"bad seq\"}" > "$AWG_UPLOAD_STATUS"; return ;;
            esac
            if [ "$first" = "1" ]; then : > "$AWG_UPLOAD_B64"; echo "-1" > "$AWG_UPLOAD_SEQ"; fi
            st=$(cat "$AWG_UPLOAD_SEQ" 2>/dev/null)
            case "$st" in ''|*[!0-9-]*) st="-1" ;; esac
            exp=$((st + 1))
            if [ "$seq" -le "$st" ]; then
                : # duplicate -> re-ack current state, do not append again
            elif [ "$seq" -eq "$exp" ]; then
                # Guard the append: /tmp is a small tmpfs, and a silent short-write here
                # would only surface much later as a confusing size mismatch. Fail fast.
                if ! printf '%s' "$chunk" >> "$AWG_UPLOAD_B64"; then
                    echo "{\"status\":\"err\",\"tok\":\"$tok\",\"msg\":\"write failed (disk full?)\"}" > "$AWG_UPLOAD_STATUS"
                    return
                fi
                st="$seq"; echo "$st" > "$AWG_UPLOAD_SEQ"
            else
                echo "{\"status\":\"gap\",\"tok\":\"$tok\",\"have\":$st,\"got\":$seq}" > "$AWG_UPLOAD_STATUS"
                return
            fi
            echo "{\"status\":\"ok\",\"tok\":\"$tok\",\"seq\":$st,\"bytes\":$(wc -c < "$AWG_UPLOAD_B64" 2>/dev/null)}" > "$AWG_UPLOAD_STATUS"
            ;;
        awgmanualinstall)
            do_manual_install
            ;;
        awgstart)       do_start ;;
        awgstop)        do_stop user ;;
        awgrestart)     do_stop; wait_for_pid_exit amneziawg-go 10; do_start ;;
        awgforceapply)
            # Force Apply: persist settings, then full restart (re-runs setconf +
            # complete route/firewall/geo rebuild via do_start)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(get_setting awg_privatekey)" ]; do sleep 1; _wt=$((_wt+1)); done
            do_stop 2>/dev/null
            wait_for_pid_exit amneziawg-go 10
            do_start
            ensure_geo   # download configured-but-missing geo lists (bg), then re-apply
            ;;
        awgsaveconf)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(get_setting awg_privatekey)" ]; do sleep 1; _wt=$((_wt+1)); done
            generate_config
            # Apply WITHOUT a VPN restart, but under the operation lock so this rebuild can't
            # race the firewall-start hook's do_firewall_restart, and with the LAN deadman
            # armed so a config that kills dnsmasq still rolls back (same net as do_start).
            if is_running && acquire_lock; then
                arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
                setup_firewall
                release_lock
            fi
            ensure_geo   # download configured-but-missing geo lists (bg), then re-apply
            update_status
            ;;
        awgupdategeo)
            touch "$GEO_BUSY_FLAG"
            update_status            # let the UI show "downloading…" immediately (sync download blocks update_status)
            update_geo_lists
            rm -f "$GEO_BUSY_FLAG"
            do_firewall_restart
            update_status
            ;;
        awgcheckupdate)
            check_update > /www/user/awg_update.htm
            ;;
        awgdoupdate)
            do_update
            ;;
        awgdiag)
            # Diagnostic dump into a SEPARATE file — does NOT touch the on-page log. The UI
            # shows it in a modal and can copy it together with the log. The [DIAG_DONE] marker
            # tells the UI the (possibly multi-second) dump has finished.
            do_diag > "$DIAG_FILE" 2>&1
            echo "[DIAG_DONE]" >> "$DIAG_FILE"
            ;;
    esac
}

# --- Main ---

# Geo ipset name is configurable (so it can be shared with other connections/tools). Default
# awg_dst; sanitize to a valid ipset name (letters/digits/_.-, <=31 chars), else keep default.
_ipn=$(get_setting awg_ipset_name)
case "$_ipn" in ''|*[!A-Za-z0-9_.-]*) _ipn="" ;; esac
[ -n "$_ipn" ] && [ ${#_ipn} -le 31 ] && IPSET_NAME="$_ipn"

case "$1" in
    start)          do_start ;;
    stop)           do_stop user ;;
    stop_auto)      do_stop ;;          # internal: auto-rollback stop (deadman); keeps watchdog cron
    restart)        do_stop; wait_for_pid_exit amneziawg-go 10; do_start ;;
    status)         update_status ;;
    diag|diagnostics) do_diag ;;
    update_geo)     update_geo_lists; do_firewall_restart; update_status ;;
    check_update)   check_update ;;
    update)         do_update "$2" ;;
    manual_install) do_manual_install ;;
    watchdog)       do_watchdog ;;
    install_page)   do_install_page ;;
    mount_ui)       do_mount_ui ;;
    uninstall)      do_uninstall ;;
    service_event)  do_service_event "$2" "$3" ;;
    wan_event)      do_wan_event "$2" "$3" ;;
    firewall_restart) do_firewall_restart fast ;;
    download_geo)   download_all_geo ;;
    ensure_geo)     ensure_geo ;;
    *)              echo "Usage: $0 {start|stop|restart|status|diag|update_geo|download_geo|install_page|uninstall}" ;;
esac
