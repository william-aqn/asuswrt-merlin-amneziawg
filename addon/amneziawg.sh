#!/bin/sh
# =============================================================
# AmneziaWG addon backend for Asuswrt-Merlin
# Userspace amneziawg-go, per-device policy routing, GeoIP/GeoSite
# =============================================================

AWG_VERSION="1.2.59"
ADDON_DIR="/jffs/addons/amneziawg"
AWG_DIR="/opt/amneziawg"
CONF="$AWG_DIR/awg0.conf"
AWG_GO="$AWG_DIR/amneziawg-go"
AWG_BIN="$AWG_DIR/awg"
IFACE="awg0"
STATUS_FILE="/www/user/awg_status.htm"
UI_LOG="/www/user/awg_log.htm"
DIAG_FILE="/www/user/awg_diag.htm"
# --- Per-device traffic analysis (diagnostic) ---
# A user-started, per-device capture: conntrack gives the live connection stream, a temporary
# dnsmasq query log supplies domain names for the destinations, and the routing verdict per
# request is derived from the device policy + `ipset test` (NOT a conntrack mark — the fwmark
# is per-packet, never CONNMARK-saved). The UI polls ANALYZE_FILE while a capture runs.
ANALYZE_FILE="/www/user/awg_analyze.htm"          # JSON the UI polls
ANALYZE_FLAG="/tmp/.awg_analyze_run"              # presence = active; contents = target IP
ANALYZE_PID="/tmp/.awg_analyze.pid"              # PID of the background capture loop
ANALYZE_STARTED="/tmp/.awg_analyze_started"      # capture start epoch
ANALYZE_ENTRIES="/tmp/.awg_analyze_entries"      # one JSON object per line, ring-trimmed
ANALYZE_SEEN="/tmp/.awg_analyze_seen"            # seen flow keys proto:dst:dport (dedup)
ANALYZE_MAP="/tmp/.awg_analyze_map"              # ip<TAB>name from the dnsmasq query log
ANALYZE_DNS_LOG="/tmp/awg_analyze_dns.log"       # dnsmasq query log, only while capturing
ANALYZE_DNS_CONF="$AWG_DIR/dnsmasq_analyze.conf" # temp dnsmasq snippet enabling query logging
ANALYZE_MAX_SECONDS=600                           # auto-stop safety cap (10 min)
ANALYZE_MAX_ENTRIES=200                           # ring-buffer size for the on-page table
# Manual .ipk upload (web UI): base64 text is appended here chunk-by-chunk (awgupload
# event), then decoded + installed (awgmanualinstall). Progress/result the UI polls:
AWG_UPLOAD_B64="/tmp/amneziawg_manual.ipk.b64"
AWG_UPLOAD_SEQ="/tmp/.amneziawg_manual.seq"
AWG_UPLOAD_STATUS="/www/user/awg_upload.htm"
STARTING_FLAG="/tmp/.awg_starting"
STOPPING_FLAG="/tmp/.awg_stopping"
GEO_BUSY_FLAG="/tmp/.awg_geo_busy"
# "DNS via tunnel" active-marker. While it exists, our /jffs/scripts/dnsmasq.postconf hook
# strips the firmware's upstream directives (servers-file/resolv-file) from the generated
# dnsmasq conf, leaving ONLY our server=<awg_dns>@awg0 lines — so ISP DNS can't answer at all.
# INVARIANT: the flag exists ONLY while dnsmasq_awg.conf carries the AWG_TUNNEL_DNS block;
# a stray flag without those server= lines would leave dnsmasq with NO upstreams (dead LAN
# DNS) — every path that deletes/regenerates the conf must handle the flag in lockstep.
TUNNEL_DNS_FLAG="/tmp/.awg_tunnel_dns"
OWNED_SETS="/tmp/.awg_owned_sets"   # registry: one geo ipset name per line that WE created (own). Exact-name teardown — NO fragile name-pattern matching — so custom/shared base names (awg_ipset_name with '.', a trailing digit, or a prefix shared with another tool) and renames are all handled safely. /tmp is tmpfs, so it shares the ipsets' reboot-volatile lifecycle.
SETTINGS="/jffs/addons/custom_settings.txt"
CLIENTS_FILE="$AWG_DIR/clients.list"
# Connection uptime & history (page/widget "uptime" + «последние 5 подключений»). Both live in
# $AWG_DIR (NOT tmpfs) so a session cut by a power-loss/reboot is still closed into history on
# the next start instead of silently vanishing. Written only on connect/disconnect — flash-safe.
CONN_CURRENT="$AWG_DIR/conn_current"   # OPEN session marker: "<start_epoch> <start_uptime_s> <boot_id>"
CONN_HISTORY="$AWG_DIR/conn_history"   # last 5 CLOSED sessions, oldest first: start_epoch|end_epoch|dur_s|reason (dur -1 = unknown)
CONN_HIST_BAK="${AWG_DIR}_connhist"    # stash surviving the package prerm's rm -rf of $AWG_DIR during updates (sibling path, like the geo backup)
GEO_DIR="$AWG_DIR/geo"
IPSET_NAME="awg_dst"
# ipset capacity. Raised above the old 131072 so antifilter.download lists fit
# (ipresolve alone is ~154K) alongside GeoIP/GeoSite/custom entries.
IPSET_MAXELEM=262144
FWMARK="0x100"
DNSMASQ_AWG_CONF="$AWG_DIR/dnsmasq_awg.conf"
DNSMASQ_INCLUDE="/jffs/configs/dnsmasq.conf.add"
DNSRELOAD_SIG="/tmp/.awg_dnsmasq_sig"   # md5 of the geo conf last loaded into dnsmasq (skip needless restarts); tmpfs = reboot-volatile like dnsmasq's own state
DNSRELOAD_DEFER="/tmp/.awg_dnsreload_defer"     # updater window: reload jobs record PENDING + exit instead of fighting a busy rc (see dnsreload_deferred)
DNSRELOAD_PENDING="/tmp/.awg_dnsreload_pending" # >=1 reload was swallowed while DEFER was up; the updater fires exactly one at the end
SCRIPT_NAME="amneziawg"
RT_TABLE=300
AWG_CHAIN="AWG"
LOCKDIR="/tmp/.awg_lock"
GEOLOCK="/tmp/.awg_geolock"   # long-running background geo-download mutex (separate from LOCKDIR)
V2FLY_GEOIP_BASE="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text"
GEOIP_SERVICES="telegram google facebook twitter netflix cloudflare fastly cloudfront"

# ROOT-CAUSE FIX for "Entware coreutils broken" false alarms: the firmware's httpd exports
# LD_LIBRARY_PATH=/lib:/usr/lib and EVERY child inherits it (httpd → service-event → this script
# → /opt/bin/*). Recent Entware binaries bake /opt/lib into DT_RUNPATH, which the dynamic loader
# searches AFTER LD_LIBRARY_PATH — so the firmware's incompatible glibc (/usr/lib/libc.so.6) is
# loaded ahead of Entware's own /opt/lib/libc, and grep/sed/awk (and the Entware ipset — same
# mechanism) SIGSEGV / fail to link the instant they start. From an interactive SSH login the var
# isn't poisoned, so the same binary works there — the "crashes from the addon, fine over SSH"
# signature two TUF-AX3000_V2 users hit (both reformatted USBs for nothing). Our own static
# awg/amneziawg-go are immune (no ELF interpreter, no libc.so lookup). Clearing the inherited
# value lets Entware's own RUNPATH win; firmware binaries default-search /lib:/usr/lib so they're
# unaffected. Keep the original for diag. (This must precede the PATH export + self-test below.)
AWG_ORIG_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
unset LD_LIBRARY_PATH

# Ensure Entware binaries are in PATH (not set when called from httpd/service-event)
export PATH="/opt/bin:/opt/sbin:/sbin:/usr/sbin:$PATH"

# Coreutils sanity: Entware installs GNU grep/sed/awk into /opt/bin, which SHADOWS the firmware's
# busybox applets (opt is first in PATH). With the LD_LIBRARY_PATH poisoning cleared above they
# normally work now; but a genuinely dying USB / corrupted or wrong-arch Entware can still break
# them SILENTLY (field case: a segfaulting /opt grep made the br0-IP check "fail", skipped the
# dnsmasq include strip → dangling conf-file → dnsmasq fatal → LAN without DNS/DHCP). So keep the
# guard: probe the three; if ANY is broken, fall back to the firmware-only PATH (busybox lives in
# squashfs — it can't be corrupted by a bad USB). CACHE the verdict per boot in /tmp so the
# possibly-crashing probe runs at most ONCE per boot, not on every invocation — the per-minute
# status cron re-running a segfaulting /opt grep logged a kernel oops every 60s on affected boxes.
AWG_PATH_SANE=1
AWG_PATH_SANE_CACHE=/tmp/.awg_path_sane
if [ -f "$AWG_PATH_SANE_CACHE" ]; then
    # Cached 0/1 from this boot's first invocation. Read with the `read`/`[` ash builtins (never
    # shadowed by /opt), so the hot path NEVER re-runs the probe. Garbage → assume sane (1).
    read AWG_PATH_SANE < "$AWG_PATH_SANE_CACHE" 2>/dev/null
    [ "$AWG_PATH_SANE" = 0 ] || [ "$AWG_PATH_SANE" = 1 ] || AWG_PATH_SANE=1
else
    # First invocation this boot: pay the probe cost ONCE (the only place /opt coreutils can crash).
    if [ "$(echo probe 2>/dev/null | grep -c probe 2>/dev/null)" != "1" ] \
       || [ "$(echo probe 2>/dev/null | sed -n 's/probe/ok/p' 2>/dev/null)" != "ok" ] \
       || [ "$(echo probe 2>/dev/null | awk '{print "ok"}' 2>/dev/null)" != "ok" ]; then
        AWG_PATH_SANE=0
    fi
    echo "$AWG_PATH_SANE" > "$AWG_PATH_SANE_CACHE" 2>/dev/null
fi
if [ "$AWG_PATH_SANE" = 0 ]; then
    # Fall back to firmware-only PATH. Runs on EVERY invocation (PATH is per-process), cache-hit or
    # not. Entware-only tools (opkg) become unavailable for this run — the lesser evil here.
    export PATH="/bin:/usr/bin:/sbin:/usr/sbin"
    if [ ! -f /tmp/.awg_path_warned ]; then
        touch /tmp/.awg_path_warned
        logger -t "amneziawg" "NOTICE: Entware /opt grep/sed/awk failed the self-test — using firmware busybox for this boot. The addon works FULLY this way. This is often just a library-path/env quirk, NOT necessarily a bad USB; if '/opt/bin/grep --version' works from an SSH shell, ignore it. Suspect the USB/Entware install only if it ALSO crashes in SSH. Run diag for a detailed probe."
        echo "$(date '+%Y-%m-%d %H:%M:%S') NOTICE: Entware /opt grep/sed/awk failed self-test — using firmware busybox (addon works fully; often a lib-path/env quirk, not necessarily a bad USB). If '/opt/bin/grep --version' works over SSH, ignore. See diag." >> "$UI_LOG" 2>/dev/null
    fi
fi

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$UI_LOG" 2>/dev/null
}

# Clear the on-page log at the start of a user-facing operation
ui_log_reset(){
    : > "$UI_LOG" 2>/dev/null
}

# Persistent incident breadcrumb — survives a reboot (unlike the RAM logs /tmp/syslog.log +
# $UI_LOG). Called ONLY on rare, LAN-critical incidents (auto-rollback, dnsmasq-down recovery,
# damaged binaries) so a box that goes "unreachable then gets power-cycled" — leaving NO logs
# of the actual failure moment — still records WHY across the reboot; diag prints it. Lives on
# /jffs (always mounted, unlike /opt on USB). Flash-wear-safe: written only on incidents (never
# on the per-minute status cron or normal starts), capped to the last 40 lines. `uptime` is
# logged too because these boxes often have an unsynced clock (Dec-1970/2023 dates).
AWG_INCIDENTS="/jffs/addons/amneziawg/incidents.log"
awg_incident(){
    { echo "$(date '+%Y-%m-%d %H:%M:%S') (up $(cut -d. -f1 /proc/uptime 2>/dev/null)s) $1"; } >> "$AWG_INCIDENTS" 2>/dev/null
    # Trim to the last 40 lines (append-then-trim; cheap, rare).
    if [ -f "$AWG_INCIDENTS" ]; then
        tail -n 40 "$AWG_INCIDENTS" > "${AWG_INCIDENTS}.t" 2>/dev/null && mv "${AWG_INCIDENTS}.t" "$AWG_INCIDENTS" 2>/dev/null
    fi
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

# Rename one custom_settings key, carrying its value to $new (only if $new isn't already
# set) and dropping the old line so the value isn't left duplicated. Idempotent.
_awg_rename_setting(){
    local old="$1" new="$2" val tmp
    [ -f "$SETTINGS" ] || return 0
    grep -q "^$old " "$SETTINGS" 2>/dev/null || return 0   # nothing stored under the old key
    if grep -q "^$new " "$SETTINGS" 2>/dev/null; then
        clear_setting "$old"                               # new key already set -> just drop the stale line
        return 0
    fi
    val=$(get_setting "$old")
    tmp="$SETTINGS.awgtmp.$$"
    { grep -v "^$old " "$SETTINGS"; echo "$new $val"; } > "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS"
    rm -f "$tmp" 2>/dev/null
}

# One-time migration of the credential-flavored keys used up to 1.1.88 to neutral names.
# Safari's password manager treats a config field that reads like a credential as a login
# and pops "Save password?", so the whole front<->back pipeline now uses neutral field
# names (DOM id == custom_settings key == get_setting key; see AWG_LEGACY_FIELDS in
# amneziawg_page.asp). Runs on every invocation but is a cheap no-op once migrated.
migrate_field_names(){
    _awg_rename_setting awg_privatekey  awg_iface_p1
    _awg_rename_setting awg_peer_pubkey awg_peer_p1
    _awg_rename_setting awg_peer_psk    awg_peer_p2
}

# Rewrite a legacy SPACE-separated awg_watchdog_hosts value to commas. The firmware stores
# a spaced value intact, but the page's settings read-back (get_custom_settings) truncates
# it at the first space — the UI showed only the first host and the next Apply persisted
# the loss. The page now saves this key comma-joined (same convention as awg_dns); fixing
# the stored value here rescues the already-saved tail hosts before the user's next Apply.
# The probe itself (watchdog_hosts) always accepted both separators. Cheap no-op once done.
migrate_watchdog_hosts(){
    local val tmp
    val=$(get_setting awg_watchdog_hosts)
    case "$val" in *" "*) ;; *) return 0 ;; esac
    val=$(printf '%s' "$val" | tr -s ' ' ',')
    tmp="$SETTINGS.awgtmp.$$"
    { grep -v "^awg_watchdog_hosts " "$SETTINGS"; echo "awg_watchdog_hosts $val"; } > "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS"
    rm -f "$tmp" 2>/dev/null
}

# =============================================================
# Multi-policy geo helpers
# A geo "policy" is an independent combination of GeoIP / GeoSite / GeoCustom / Antifilter,
# loaded into its OWN ipset and matched per-device at the mangle layer. All policies route
# into the SAME tunnel (one FWMARK -> one RT_TABLE); only the match-set differs per device.
# Policy id 1 is the legacy/default policy: it reuses the original unsuffixed settings keys,
# the flat $GEO_DIR layout and the $IPSET_NAME ipset, so existing installs need ZERO
# migration. Policies >=2 use id-suffixed keys, $GEO_DIR/p<id>/ dirs and ${IPSET_NAME}<id>
# ipsets. Registry: awg_geo_policies = "id:uriName;id:uriName;..." (default "1" when absent).
# =============================================================
GEO_MAX_POLICIES=8

# Active policy ids (space-separated); always at least "1" (legacy/default).
geo_ids(){
    local raw out id
    raw=$(get_setting awg_geo_policies)
    [ -z "$raw" ] && { echo 1; return; }
    out=$(printf '%s\n' "$raw" | tr ';' '\n' | while IFS=: read -r id _; do
        id=$(printf '%s' "$id" | tr -cd '0-9')
        [ -n "$id" ] && printf '%s ' "$id"
    done)
    out=$(echo $out)
    [ -z "$out" ] && out=1
    echo "$out"
}

# custom_settings key for a policy field. id 1 -> legacy unsuffixed key.
# suffix: v2fly v2fly_ip custom_domains custom_ips custom_files custom_urls antifilter_lists
geo_key(){
    local id="$1" suf="$2"
    if [ "$suf" = antifilter_lists ]; then
        [ "$id" = 1 ] && echo "awg_antifilter_lists" || echo "awg_antifilter_${id}_lists"
    else
        [ "$id" = 1 ] && echo "awg_geo_${suf}" || echo "awg_geo_${id}_${suf}"
    fi
}

# ipset name for a policy. id 1 -> $IPSET_NAME (legacy "awg_dst" or user override).
geo_ipset(){
    [ "$1" = 1 ] && echo "$IPSET_NAME" || echo "${IPSET_NAME}$1"
}

# Total live entries across every policy's main geo ipset, read back from the kernel. This is the
# authoritative IP-range count (deduplicated, includes the custom_ips field, all policies) — both
# the status JSON and the setup_firewall log use it so they always agree.
geo_ipset_total(){
    local total=0 _gid _n
    for _gid in $(geo_ids); do
        _n=$(ipset list "$(geo_ipset "$_gid")" -t 2>/dev/null | awk '/Number of entries/{print $NF}')
        [ -n "$_n" ] && total=$((total + _n))
    done
    echo "$total"
}

# Total domain->set memberships in the live dnsmasq conf, counting ONLY each policy's MAIN set
# (the *_x exclusion sets are skipped — same convention geo_ipset_total uses for IPs and the per-tab
# stats use for both, so the aggregate stays equal to the sum of the per-tab domain counts even when
# a policy has exclusion domains). Per ipset= line: (domains = NF-2) * (how many of its comma-joined
# sets are main policy sets), so a domain routed to N policies counts N times. Read from the conf
# dnsmasq actually loaded (post --test gate), so the setup_firewall log and the status JSON always
# report the same number. (The build-time $domain_count is UNIQUE domains and stays for the >0
# gating; it deliberately differs when policies share domains — that's why the log used to read
# 1082 against the UI's 1271.)
geo_domain_total(){
    [ -f "$DNSMASQ_AWG_CONF" ] || { echo 0; return; }
    local _mains="" _gid
    for _gid in $(geo_ids); do _mains="$_mains $(geo_ipset "$_gid")"; done
    awk -F/ -v mains="$_mains" '
        BEGIN{ k=split(mains,a," "); for(i=1;i<=k;i++) M[a[i]]=1 }
        /^ipset=/{ n=split($NF,ss,","); m=0; for(i=1;i<=n;i++) if(ss[i] in M) m++; c+=(NF-2)*m }
        END{ print c+0 }' "$DNSMASQ_AWG_CONF" 2>/dev/null
}

# Routing mode of a policy: "vpn" (include, default — route the policy's lists via VPN) or
# "direct" (exclude — route everything EXCEPT the lists via VPN; the lists go direct).
geo_mode(){
    [ "$(get_setting "$(geo_key "$1" mode)")" = direct ] && echo direct || echo vpn
}

# Exclusion ipset name for a policy (pointwise exceptions): the main set name + "_x". Owned via
# the registry (exact-name teardown), so the suffix can never collide-destroy a foreign set.
geo_exc_ipset(){
    echo "$(geo_ipset "$1")_x"
}

# Does policy <id> have any exclusion entries (domains/IPs/files/URLs)? Gates EXC-set creation.
policy_has_exc(){
    local id="$1"
    [ -n "$(get_setting "$(geo_key "$id" exc_domains)")$(get_setting "$(geo_key "$id" exc_ips)")$(get_setting "$(geo_key "$id" exc_files)")$(get_setting "$(geo_key "$id" exc_urls)")" ]
}

# True if any active geo policy is in exclude mode — it routes everything-except-its-list via
# VPN (like vpn_all), so it shares vpn_all's coexistence caveat with a co-resident DPI/proxy tool.
any_exclude_mode(){
    local id
    for id in $(geo_ids); do [ "$(geo_mode "$id")" = direct ] && return 0; done
    return 1
}

# Geo files are stored ONCE in a shared pool ($GEO_DIR/{geoip,antifilter,domains}); a file is
# identified by its natural key (service name / list key / GeoSite category / sha256 of a URL),
# so two policies selecting the same list share a single download + on-disk copy. The per-policy
# "matrix" lives only in settings (each policy's selection); at firewall-build time each policy's
# ipset is loaded with just the subset it selected. download/prune operate on the UNION across
# policies; load/dnsmasq operate per policy. Per-policy CONTENT (pasted GeoCustom files, custom
# domains) can differ between same-named tabs, so those files are namespaced "_p<id>_".

# Union (dedup, space-separated) of GeoIP services selected across ALL policies.
geo_union_geoip(){ local id; for id in $(geo_ids); do selected_geoip "$id"; done | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' '; }
# Union of antifilter list keys across all policies.
geo_union_antifilter(){ local id; for id in $(geo_ids); do selected_antifilter "$id"; done | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' '; }
# Union of GeoSite categories across all policies.
geo_union_geosite(){ local id; for id in $(geo_ids); do get_setting "$(geo_key "$id" v2fly)" | tr ',' ' '; done | tr ' ' '\n' | sed 's/[^A-Za-z0-9_.-]//g' | grep -v '^$' | sort -u | tr '\n' ' '; }
# Union of ALL policies' URLs across both channels (custom_urls + exc_urls), decoded, one valid
# http(s) URL per line, deduped — every URL (include or exclusion) is fetched once into the
# shared userurl_<hash> pool.
geo_union_urls(){
    local id
    for id in $(geo_ids); do
        get_setting "$(geo_key "$id" custom_urls)" | base64 -d 2>/dev/null; printf '\n'
        get_setting "$(geo_key "$id" exc_urls)" | base64 -d 2>/dev/null; printf '\n'
    done | tr ' \t\r' '\n\n\n' | grep -E '^https?://' | sort -u
}
# sha256[:16] keys of policy <id>'s URLs for channel <kind> (inc=custom_urls, exc=exc_urls), one
# per line — for per-policy/per-channel load + dnsmasq enumeration.
policy_url_keys(){
    local id="$1" kind="${2:-inc}" key u
    [ "$kind" = exc ] && key=exc_urls || key=custom_urls
    get_setting "$(geo_key "$id" "$key")" | base64 -d 2>/dev/null | tr ' \t\r' '\n\n\n' | grep -E '^https?://' | while read -r u; do
        echo "$u" | sha256sum | awk '{print $1}' | cut -c1-16
    done
}

# Owned-set registry: record a geo ipset WE created, so teardown destroys it by EXACT name
# (never a name pattern). A set we did NOT create (a pre-existing/shared base set made by
# another tool) is never registered, so it's never destroyed.
register_owned_set(){
    grep -qxF "$1" "$OWNED_SETS" 2>/dev/null || echo "$1" >> "$OWNED_SETS"
}
# Flush + destroy every geo set we created (incl. old names after an awg_ipset_name rename),
# then clear the registry. Exact names only — foreign sets are untouched.
destroy_owned_sets(){
    local s
    [ -f "$OWNED_SETS" ] || return 0
    while read -r s; do
        [ -z "$s" ] && continue
        ipset flush "$s" 2>/dev/null
        ipset destroy "$s" 2>/dev/null
    done < "$OWNED_SETS"
    rm -f "$OWNED_SETS"
}
# May we load into / route via policy <id>'s set ($2)? id 1 = the base set, which MAY be a
# shared set created by another tool (documented behavior) — allowed. id>=2 names are derived
# from our base, so one we didn't create (not in the registry) is a foreign collision — never
# pollute or route into it.
geo_set_ours(){
    [ "$1" = 1 ] && return 0
    grep -qxF "$2" "$OWNED_SETS" 2>/dev/null
}

# Map a device/default policy ref to a geo policy id: vpn_geo -> 1, vpn_geo_<id> -> <id>.
geo_policy_of_ref(){
    case "$1" in
        vpn_geo)   echo 1 ;;
        vpn_geo_*) echo "${1#vpn_geo_}" ;;
        *)         echo 1 ;;
    esac
}

# Per-policy ipset maxelem = total RAM budget / active-policy count (floored), so N policies
# can't sum to N x the cap and OOM a low-RAM router. $1 = total budget for this box.
geo_maxelem(){
    local total="$1" n per floor=16384
    n=$(geo_ids | wc -w | tr -d ' '); [ -z "$n" ] && n=1
    [ "$n" -lt 1 ] 2>/dev/null && n=1
    per=$((total / n))
    # Apply the comfort floor ONLY while it doesn't push the SUM (n*floor) past the budget —
    # otherwise (many policies on a low-RAM box) it would defeat the OOM cap it sits inside.
    [ "$per" -lt "$floor" ] && [ $((floor * n)) -le "$total" ] && per=$floor
    [ "$per" -lt 1 ] && per=1
    echo "$per"
}

# Remove per-policy CONTENT files (pasted GeoCustom, custom domains) for policies deleted in
# the UI (ids no longer active). These filenames carry OUR own "_p<id>_" / "custom_p<id>" tag
# (id = digits), so id extraction is unambiguous and never collides with a foreign name. Shared
# files are pruned by union elsewhere; per-policy IPSETS are reclaimed by the owned-set registry
# (cleanup_firewall destroys + recreates each build), so this never touches ipsets.
prune_orphan_policies(){
    local active=" $(geo_ids) " id f
    # custom-domains files: custom_p<id>.txt (include) + custom_exc_p<id>.txt (exclusions)
    for f in "$GEO_DIR"/domains/custom_p*.txt; do
        [ -f "$f" ] || continue
        id=$(basename "$f" .txt); id=${id#custom_p}
        case "$active" in *" $id "*) ;; *) rm -f "$f" ;; esac
    done
    for f in "$GEO_DIR"/domains/custom_exc_p*.txt; do
        [ -f "$f" ] || continue
        id=$(basename "$f" .txt); id=${id#custom_exc_p}
        case "$active" in *" $id "*) ;; *) rm -f "$f" ;; esac
    done
    # pasted-file outputs: usercustom_p<id>_* (include) + excustom_p<id>_* (exclusions)
    for f in "$GEO_DIR"/domains/usercustom_p*.txt "$GEO_DIR"/geoip/usercustom_p*.cidr; do
        [ -f "$f" ] || continue
        id=$(basename "$f"); id=${id#usercustom_p}; id=${id%%_*}
        case "$active" in *" $id "*) ;; *) rm -f "$f" ;; esac
    done
    for f in "$GEO_DIR"/domains/excustom_p*.txt "$GEO_DIR"/geoip/excustom_p*.cidr; do
        [ -f "$f" ] || continue
        id=$(basename "$f"); id=${id#excustom_p}; id=${id%%_*}
        case "$active" in *" $id "*) ;; *) rm -f "$f" ;; esac
    done
}

# Does a network interface exist? Read the KERNEL's own netdev registry (/sys/class/net)
# instead of `ip link show`, which depends on which iproute2 is on PATH and whether that
# build's netlink dump is accepted by the running kernel. Field case (RT-AC68U, kernel
# 2.6.36): amneziawg-go created awg0 and brought it Up (daemon log + successful SIOCGIFINDEX
# prove the netdev exists and is named awg0), yet `ip link show awg0` returned non-zero for
# 10s straight — an Entware iproute2 built against modern headers issuing a RTM_GETLINK the
# old kernel rejects — so do_start killed the live daemon as "failed to create interface".
# /sys/class/net is the ground truth the kernel maintains regardless of userspace tooling;
# /proc/net/dev is the fallback for the (theoretical) box without sysfs, and `ip` is the last
# resort so nothing regresses on an exotic setup.
iface_exists(){
    [ -e "/sys/class/net/$1" ] && return 0
    grep -q "^[[:space:]]*$1:" /proc/net/dev 2>/dev/null && return 0
    ip link show "$1" >/dev/null 2>&1
}

is_running(){
    iface_exists "$IFACE"
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
    # Re-route the EXISTING flows of VPN-policied devices by deleting their conntrack entries,
    # so they re-establish through the tunnel right after an Apply/start instead of stalling
    # on the old path until they time out. History of footguns in this exact spot:
    #  - a full `conntrack -F` (pre-1.2.9) killed every LAN connection on any Apply;
    #  - `conntrack -D --mark 0x100/0x100` (until 1.2.35) NEVER matched our flows — our fwmark
    #    is per-PACKET (mangle MARK, deliberately no CONNMARK), so it never lands in the
    #    conntrack mark — but it DID match unrelated flows on AiProtection/QoS firmwares whose
    #    OWN conntrack marks carry bit 0x100 (tdts marks like 195040=0x2F9E0). Live-confirmed
    #    collateral on a GT-AX6000: random established LAN sessions cut on every Apply, with
    #    every deleted entry dumped to stdout mid-start.
    # So: delete precisely by SOURCE IP, only for devices explicitly routed via VPN, quietly.
    # Unlisted devices under a VPN default policy are NOT flushed (that would be the old
    # kill-everything problem again); their new connections route correctly immediately, and
    # stale direct-path flows just age out — same behavior they always had.
    # NB: `command -v` is NOT available on Asuswrt-Merlin's trimmed busybox (no CONFIG_ASH_CMDCMD)
    # — it returns 127, so a `command -v X` guard silently disables the code it gates. Use `which`.
    which conntrack >/dev/null 2>&1 || return 0
    [ -f "$CLIENTS_FILE" ] || return 0
    local dev_id name policy mac
    while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
        dev_id=$(echo "$dev_id" | tr -d ' ')
        policy=$(echo "$policy" | tr -d ' ')
        case "$policy" in vpn_all|vpn_geo|vpn_geo_*) ;; *) continue ;; esac
        # IPv4-keyed entries only (MAC-keyed clients have no address to flush by).
        case "$dev_id" in
            *[!0-9.]*) ;;
            *.*.*.*) conntrack -D -s "$dev_id" >/dev/null 2>&1 ;;
        esac
    done < "$CLIENTS_FILE"
    return 0
}

# Delete EVERY copy of an iptables rule, not just the first (`iptables -D` removes one match
# per call). Duplicate copies accumulated in the field (9x TCPMSS clamp pairs on one report):
# every start that raced an already-up tunnel APPENDED a fresh set while each stop removed
# exactly ONE — monotonic growth. Usage: ipt_drain <iptables args of the -D form>.
ipt_drain(){
    local _n=0
    while [ $_n -lt 25 ] && iptables "$@" 2>/dev/null; do _n=$((_n + 1)); done
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
# Kernel-native existence check (see iface_exists) — NOT `ip link show`, which false-negatived
# a live awg0 on an old kernel with a mismatched Entware iproute2 and got the daemon killed.
wait_for_iface(){
    local iface="$1" max="${2:-10}" i=0
    while [ $i -lt $max ]; do
        iface_exists "$iface" && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Wait for the daemon's UAPI control socket to be ready. Usage: wait_for_uapi <iface> <timeout>
# amneziawg-go creates the TUN netdev BEFORE it binds/listens on the UAPI control socket, so the
# link can exist (wait_for_iface passes) a beat before `awg setconf`/`awg show` can connect. On a
# slow single-core box (RT-AC68U) an immediate setconf then loses that race and dies with a generic
# exit 1. Probe via `awg show` — path-agnostic: it uses awg's OWN socket resolution, so it works
# whether the socket lives in /var/run/wireguard or /var/run/amneziawg, and confirms the daemon is
# actually accepting UAPI connections (not merely that the link exists).
wait_for_uapi(){
    local iface="$1" max="${2:-15}" i=0
    while [ $i -lt $max ]; do
        "$AWG_BIN" show "$iface" >/dev/null 2>&1 && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# NB on pids: `$$` inside a `( ) &` subshell is the PARENT shell's pid (POSIX), and several
# lock takers run exactly there (ensure_geo's rebuild, the health check's do_stop, dnsmasq
# reload jobs). Writing `echo $$` from those recorded a pid that dies seconds later — every
# liveness probe (acquire_lock reclaim, watchdog stale-reclaim, reload serialization) then
# misread a LIVE lock as stale and stole it (observed in the field: two pre-resolve jobs
# running unserialized with the lock dir gone). `sh -c 'echo $PPID' > file` — a DIRECT child
# with plain redirection, no command substitution — yields the true pid of the current
# (sub)shell in every context.
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
    sh -c 'echo $PPID' > "$LOCKDIR/pid" 2>/dev/null
    # Cache our recorded identity for release_lock — re-deriving it there could legitimately
    # differ (command-substitution forks), the file read-back cannot.
    AWG_LOCK_PID=$(cat "$LOCKDIR/pid" 2>/dev/null)
}

release_lock(){
    # Owner-aware: only free the lock if WE hold it (pid matches what WE recorded), so a
    # stray release on an error path can't free a lock another concurrent actor acquired.
    local p
    p=$(cat "$LOCKDIR/pid" 2>/dev/null)
    [ -n "$p" ] && [ "$p" != "${AWG_LOCK_PID:-$$}" ] && return 0
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

# Negative-cache for failed geo downloads. A list that does not exist upstream (e.g. GeoIP
# "strava" — no such category in Loyalsoldier/geoip) used to be re-fetched on EVERY apply:
# geo_any_pending saw the file missing forever, and each ensure_geo burned four mirror
# timeouts per list. After a failure, skip re-tries of that list for 6h; a manual/cron
# "Update now" (update_geo_lists) clears the stamps and retries everything.
dl_fail_stamp(){ echo "$GEO_DIR/.dlfail_$1"; }
dl_recently_failed(){
    local f _now _then
    f=$(dl_fail_stamp "$1")
    [ -f "$f" ] || return 1
    _now=$(date +%s); _then=$(cat "$f" 2>/dev/null)
    case "$_then" in ''|*[!0-9]*) return 1 ;; esac
    [ $((_now - _then)) -lt 21600 ]
}
dl_mark_failed(){ mkdir -p "$GEO_DIR" 2>/dev/null; date +%s > "$(dl_fail_stamp "$1")" 2>/dev/null; }
dl_clear_failed(){ rm -f "$GEO_DIR"/.dlfail_* 2>/dev/null; }

# Download a single GeoIP service list (IPv4 only) into the SHARED pool. $1=svc.
download_geoip_service(){
    local svc="$1"
    svc=$(echo "$svc" | tr -d ' ' | tr 'A-Z' 'a-z')
    [ -z "$svc" ] && return 1
    mkdir -p "$GEO_DIR/geoip"
    local tmp="$GEO_DIR/geoip/.dl_${svc}.tmp"
    if fetch_with_mirrors "${V2FLY_GEOIP_BASE}/${svc}.txt" "$tmp" 30 && [ -s "$tmp" ]; then
        grep -v ":" "$tmp" > "$GEO_DIR/geoip/v2fly_${svc}.cidr"
        rm -f "$tmp"
        # Reject garbage (e.g. a proxy HTML error page): require at least one IPv4 line
        if ! grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$GEO_DIR/geoip/v2fly_${svc}.cidr" 2>/dev/null; then
            rm -f "$GEO_DIR/geoip/v2fly_${svc}.cidr"; dl_mark_failed "geoip_${svc}"; return 1
        fi
        rm -f "$(dl_fail_stamp "geoip_${svc}")" 2>/dev/null
        return 0
    fi
    rm -f "$tmp"
    dl_mark_failed "geoip_${svc}"
    return 1
}

# Selected GeoIP services for policy <id> (default id 1). The legacy default GEOIP_SERVICES
# fallback applies ONLY to id 1 (back-compat for installs with an empty field); additional
# policies treat an empty field as "nothing selected".
selected_geoip(){
    local id="${1:-1}" s
    s=$(get_setting "$(geo_key "$id" v2fly_ip)" | tr ',' ' ' | tr 'A-Z' 'a-z')
    s=$(echo $s)
    [ -z "$s" ] && [ "$id" = 1 ] && s="$GEOIP_SERVICES"
    echo "$s"
}

# Remove shared GeoIP .cidr files no longer selected by ANY policy (prune by union).
prune_geoip(){
    local sel=" $(geo_union_geoip) " f fsvc
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

# Selected antifilter lists for policy <id> (default id 1) — UI checkboxes, comma-separated.
selected_antifilter(){
    local id="${1:-1}"
    echo $(get_setting "$(geo_key "$id" antifilter_lists)" | tr ',' ' ' | tr 'A-Z' 'a-z')
}

# Download a single antifilter list into the SHARED pool. $1=key.
# IP lists -> antifilter/af_<key>.cidr; the domain list -> domains/antifilter_<key>.lst.
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
            [ -s "$out" ] || { rm -f "$out"; dl_mark_failed "af_${key}"; return 1; }
            rm -f "$(dl_fail_stamp "af_${key}")" 2>/dev/null
            return 0
        fi
    else
        out="$GEO_DIR/antifilter/af_${key}.cidr"
        tmp="$GEO_DIR/antifilter/.dl_af_${key}.tmp"
        mkdir -p "$GEO_DIR/antifilter"
        if fetch_with_mirrors "$url" "$tmp" 60 && [ -s "$tmp" ]; then
            grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$tmp" > "$out"
            rm -f "$tmp"
            [ -s "$out" ] || { rm -f "$out"; dl_mark_failed "af_${key}"; return 1; }
            rm -f "$(dl_fail_stamp "af_${key}")" 2>/dev/null
            return 0
        fi
    fi
    rm -f "$tmp"
    dl_mark_failed "af_${key}"
    return 1
}

# Remove shared antifilter files no longer selected by ANY policy (prune by union).
prune_antifilter(){
    local sel=" $(geo_union_antifilter) " f fkey
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

# Remove shared userurl_* files whose URL key is no longer referenced by ANY policy (prune by
# the union of every policy's custom URLs).
prune_custom_urls(){
    local sel f fkey u
    sel=" $(geo_union_urls | while read -r u; do u=$(echo "$u" | tr -d ' \r'); [ -z "$u" ] && continue; echo "$u" | sha256sum | awk '{print $1}' | cut -c1-16; done | tr '\n' ' ') "
    for f in "$GEO_DIR"/domains/userurl_*.txt "$GEO_DIR"/geoip/userurl_*.cidr; do
        [ -f "$f" ] || continue
        fkey=$(basename "$f"); fkey=${fkey#userurl_}; fkey=${fkey%.txt}; fkey=${fkey%.cidr}
        case "$sel" in *" $fkey "*) ;; *) rm -f "$f" ;; esac
    done
}

# Download the UNION of every policy's URL sources into the shared pool (one fetch per unique
# URL). Each is classified into domains/userurl_<key>.txt + geoip/userurl_<key>.cidr,
# key = first 16 hex of sha256(URL). Same URL in two policies => one download/file.
download_custom_urls(){
    local urls url key tmp
    urls=$(geo_union_urls)
    if [ -z "$urls" ]; then
        prune_custom_urls
        return 0
    fi
    mkdir -p "$GEO_DIR/domains" "$GEO_DIR/geoip"
    printf '%s\n' "$urls" | while read -r url; do
        url=$(echo "$url" | tr -d ' \r')
        [ -z "$url" ] && continue
        case "$url" in http://*|https://*) ;; *) continue ;; esac
        key=$(echo "$url" | sha256sum | awk '{print $1}' | cut -c1-16)
        tmp="$GEO_DIR/.url_${key}.tmp"
        if fetch_with_mirrors "$url" "$tmp" 60 && [ -s "$tmp" ]; then
            rm -f "$GEO_DIR/domains/userurl_${key}.txt" "$GEO_DIR/geoip/userurl_${key}.cidr"
            classify_user_list "$tmp" "$GEO_DIR/domains/userurl_${key}.txt" "$GEO_DIR/geoip/userurl_${key}.cidr"
            rm -f "$(dl_fail_stamp "url_${key}")" 2>/dev/null
            log_msg "Custom URL: $url ($key)"
        else
            dl_mark_failed "url_${key}"
            log_msg "Custom URL download failed: $url (won't re-try for 6h)"
        fi
        rm -f "$tmp"
    done
    prune_custom_urls
}

download_all_geo(){
    mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains" "$GEO_DIR/antifilter"
    log_msg "Downloading all geo databases..."

    # Shared GeoSite domain DB (downloaded once; every policy extracts its categories from it).
    download_geosite

    # GC sets/files for policies deleted in the UI.
    prune_orphan_policies

    # GeoIP service lists — the UNION across all policies, one download per unique service.
    prune_geoip
    local geoip_list count=0 total=0 ok=0 svc af_key
    geoip_list=$(geo_union_geoip)
    for svc in $geoip_list; do total=$((total + 1)); done
    for svc in $geoip_list; do
        count=$((count + 1))
        log_msg "GeoIP: downloading $svc ($count/$total)..."
        if download_geoip_service "$svc"; then ok=$((ok + 1)); else log_msg "WARNING: GeoIP $svc failed"; fi
        update_status
    done
    log_msg "GeoIP: $ok/$total service lists downloaded"

    # Antifilter lists — the union, one download per unique list.
    prune_antifilter
    for af_key in $(geo_union_antifilter); do
        log_msg "Antifilter: downloading $af_key..."
        download_antifilter_list "$af_key" || log_msg "WARNING: Antifilter $af_key failed"
        update_status
    done

    # GeoCustom URL sources — the union, one download per unique URL.
    download_custom_urls

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
    # Firmware UI language at mount time — gives the header widget a zero-flicker first paint
    # (it self-corrects from the status JSON "lang" field on its first poll if this goes stale).
    local pref_lang=$(nvram get preferred_lang 2>/dev/null)
    [ -z "$pref_lang" ] && pref_lang="EN"
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
(function(){try{if(window.__awgWidget)return;window.__awgWidget=1;window.__awgPage='${page}';window.__awgLang='${pref_lang}';
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

# Split a user-supplied list (GeoCustom pasted file or downloaded URL) into a domains file and
# a CIDR file, auto-detecting each line: IPv4/CIDR or IPv6 -> cidr_out; a bare domain -> dom_out;
# blank lines, #comments and anything else are dropped. A bare IPv4 (no slash) goes to cidr_out,
# so it never lands in dnsmasq as a useless pseudo-domain.
classify_user_list(){
    local infile="$1" dom_out="$2" cidr_out="$3"
    [ -f "$infile" ] || return 0
    awk -v dout="$dom_out" -v cout="$cidr_out" '
        { gsub(/[ \t\r]/, "") }
        $0 == "" { next }
        /^#/ { next }
        /:/ { print > cout; next }
        /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/ { print > cout; next }
        /^\.?[a-zA-Z0-9._-]+$/ { sub(/^\./, ""); print > dout; next }
    ' "$infile"
}

# Regenerate policy <id>'s pasted-file lists for channel <kind> (inc=custom_files [include],
# exc=exc_files [exclusions]) from the matching key (format name,base64(content);...) into the
# SHARED pool, namespaced per policy+channel: domains/<pfx><name>.txt + geoip/<pfx><name>.cidr
# where <pfx> = usercustom_p<id>_ (inc) or excustom_p<id>_ (exc). Cleared + rebuilt each
# setup_firewall. $1 = policy id, $2 = kind (default inc).
apply_custom_geo(){
    local id="${1:-1}" kind="${2:-inc}" key pfx
    if [ "$kind" = exc ]; then key=exc_files; pfx="excustom_p${id}_"; else key=custom_files; pfx="usercustom_p${id}_"; fi
    rm -f "$GEO_DIR"/domains/${pfx}*.txt "$GEO_DIR"/geoip/${pfx}*.cidr 2>/dev/null
    local blob
    blob=$(get_setting "$(geo_key "$id" "$key")")
    [ -z "$blob" ] && return 0
    mkdir -p "$GEO_DIR/domains" "$GEO_DIR/geoip"
    local oldifs="$IFS" entry name b64 tmp base n seen=" "
    IFS=';'
    set -f
    for entry in $blob; do
        [ -z "$entry" ] && continue
        case "$entry" in *,*) ;; *) continue ;; esac   # need a name,content pair
        name=${entry%%,*}
        b64=${entry#*,}
        name=$(echo "$name" | sed 's/[^a-zA-Z0-9]/_/g')
        [ -z "$name" ] && continue
        # Uniquify on sanitized-name collision (e.g. "my.list" and "my-list" both -> "my_list"),
        # else the second file's classify output would truncate/overwrite the first's — data loss.
        base="$name"; n=1
        while case "$seen" in *" $name "*) true ;; *) false ;; esac; do
            n=$((n + 1)); name="${base}_${n}"
        done
        seen="$seen$name "
        tmp="$GEO_DIR/.uc_${pfx}${name}.tmp"
        echo "$b64" | base64 -d 2>/dev/null > "$tmp"
        [ -s "$tmp" ] && classify_user_list "$tmp" "$GEO_DIR/domains/${pfx}${name}.txt" "$GEO_DIR/geoip/${pfx}${name}.cidr"
        rm -f "$tmp"
    done
    set +f
    IFS="$oldifs"
}

# Extract the UNION of every policy's GeoSite categories from the shared v2fly DB into shared
# domains/v2fly_<cat>.txt files (one extraction per unique category; two policies sharing a
# category share the file). Stale category files no longer selected by anyone are removed.
build_geosite_domains(){
    mkdir -p "$GEO_DIR/domains"
    local union=" $(geo_union_geosite) " f cat
    for f in "$GEO_DIR"/domains/v2fly_*.txt; do
        [ -f "$f" ] || continue
        cat=$(basename "$f" .txt); cat=${cat#v2fly_}
        case "$union" in *" $cat "*) ;; *) rm -f "$f" ;; esac
    done
    [ -f "$GEO_DIR/v2fly_all.yml" ] || return 0
    for cat in $(geo_union_geosite); do
        [ -z "$cat" ] && continue
        awk -v c="$cat" '
            /^  - name: / { if(found) exit; name=$NF; found=(name==c); next }
            found && /^      - "domain:/ { sub(/.*"domain:/,""); sub(/".*/,""); print }
            found && /^      - "full:/ { sub(/.*"full:/,""); sub(/".*/,""); print }
        ' "$GEO_DIR/v2fly_all.yml" > "$GEO_DIR/domains/v2fly_${cat}.txt"
    done
}

# One-time: remove flat GeoCustom outputs from the pre-shared-pool (single-policy) layout.
# New outputs are namespaced usercustom_p<id>_* / custom_p<id>.txt; the old flat ones (no
# "_p<id>") are never read anymore and would otherwise linger on /opt forever. Guarded by a
# flag in $GEO_DIR (persistent), so it runs once per upgrade.
migrate_geocustom_layout(){
    [ -f "$GEO_DIR/.geocustom_migrated" ] && return 0
    local f b
    for f in "$GEO_DIR"/domains/usercustom_*.txt "$GEO_DIR"/geoip/usercustom_*.cidr; do
        [ -f "$f" ] || continue
        b=$(basename "$f")
        case "$b" in usercustom_p[0-9]*) ;; *) rm -f "$f" ;; esac   # keep new namespaced, drop legacy flat
    done
    rm -f "$GEO_DIR/domains/custom.txt"   # legacy single-policy custom-domains file
    touch "$GEO_DIR/.geocustom_migrated"
}

# (Re)write policy <id>'s own custom-domains file for channel <kind> (inc=custom_domains,
# exc=exc_domains). Output: custom_p<id>.txt (inc) / custom_exc_p<id>.txt (exc). $1=id $2=kind.
build_custom_domains(){
    local id="${1:-1}" kind="${2:-inc}" key out cd
    if [ "$kind" = exc ]; then key=exc_domains; out="$GEO_DIR/domains/custom_exc_p${id}.txt"; else key=custom_domains; out="$GEO_DIR/domains/custom_p${id}.txt"; fi
    cd=$(get_setting "$(geo_key "$id" "$key")")
    rm -f "$out"   # clear stale file when the field is emptied
    if [ -n "$cd" ]; then
        mkdir -p "$GEO_DIR/domains"
        echo "$cd" | tr ',' '\n' > "$out"
    fi
}

# Does ANY policy have a selected source whose shared file is missing on disk? (union check)
# A recently-FAILED download does not count as pending — otherwise a permanently-missing list
# re-triggered the whole background download pass on every apply (see dl_recently_failed).
geo_any_pending(){
    local svc af_key key
    for svc in $(geo_union_geoip); do
        [ -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ] || dl_recently_failed "geoip_${svc}" || return 0
    done
    for af_key in $(geo_union_antifilter); do
        if antifilter_is_domain "$af_key"; then
            [ -f "$GEO_DIR/domains/antifilter_${af_key}.lst" ] || dl_recently_failed "af_${af_key}" || return 0
        else
            [ -f "$GEO_DIR/antifilter/af_${af_key}.cidr" ] || dl_recently_failed "af_${af_key}" || return 0
        fi
    done
    geo_urls_missing && return 0
    return 1
}

# Does ANY policy reference a custom URL whose shared output file isn't present yet? (union)
# geo_union_urls emits one whitespace-free http(s) URL per line, so word-splitting is safe.
geo_urls_missing(){
    local u key
    for u in $(geo_union_urls); do
        key=$(echo "$u" | sha256sum | awk '{print $1}' | cut -c1-16)
        { [ ! -f "$GEO_DIR/domains/userurl_${key}.txt" ] && [ ! -f "$GEO_DIR/geoip/userurl_${key}.cidr" ]; } \
            && ! dl_recently_failed "url_${key}" && return 0
    done
    return 1
}

# Download only the MISSING shared geo files (union across policies). Used by ensure_geo's
# background fetch so adding one service to one tab doesn't re-fetch everything.
geo_fetch_missing(){
    mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains" "$GEO_DIR/antifilter"
    local svc af_key
    for svc in $(geo_union_geoip); do
        [ -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ] && continue
        dl_recently_failed "geoip_${svc}" && { log_msg "GeoIP: $svc failed recently — skipping until the next full update"; continue; }
        log_msg "GeoIP: downloading $svc..."
        download_geoip_service "$svc" || log_msg "WARNING: GeoIP $svc failed (won't re-try for 6h; check the list name exists upstream)"
        update_status
    done
    for af_key in $(geo_union_antifilter); do
        if antifilter_is_domain "$af_key"; then
            [ -f "$GEO_DIR/domains/antifilter_${af_key}.lst" ] && continue
        else
            [ -f "$GEO_DIR/antifilter/af_${af_key}.cidr" ] && continue
        fi
        dl_recently_failed "af_${af_key}" && { log_msg "Antifilter: $af_key failed recently — skipping until the next full update"; continue; }
        log_msg "Antifilter: downloading $af_key..."
        download_antifilter_list "$af_key" || log_msg "WARNING: Antifilter $af_key failed (won't re-try for 6h)"
        update_status
    done
    geo_urls_missing && download_custom_urls
}

# --- Unified firewall setup ---

# Detect a co-resident DPI-bypass / proxy tool that we must not fight: zapret/zapret2 by
# bol-van (nfqws/tpws), b4 (daniellavrushin), OR a transparent proxy daemon (xray/XRAYUI,
# v2ray, sing-box) — by process name AND by netfilter footprint (NFQUEUE/TPROXY in iptables
# OR an nft queue/tproxy rule, so we also catch nftables-backed firmware and tools we don't
# know by name). When detected we skip the global DNS hijack below so we don't collide with
# its DNS/redirect handling and lock out the LAN — the addon's marks/table/conntrack flush
# are already its own. (Name kept as zapret_active for callers.)
zapret_active(){
    { pidof nfqws || pidof tpws || pidof b4; } >/dev/null 2>&1 && return 0
    { pidof xray || pidof v2ray || pidof sing-box; } >/dev/null 2>&1 && return 0
    iptables-save 2>/dev/null | grep -qE 'NFQUEUE|TPROXY' && return 0
    nft list ruleset 2>/dev/null | grep -qE 'queue (num|to)|tproxy' && return 0
    return 1
}

# Human-readable name of a co-resident DPI-bypass / proxy tool, for the UI coexistence
# warning (status JSON "dpi_tool"). Echoes the first match, or nothing. Proxy daemons first
# (the common Xray/XRAYUI case), then zapret, then a generic NFQUEUE/TPROXY footprint.
detect_dpi_tool(){
    pidof xray     >/dev/null 2>&1 && { echo "Xray";     return; }
    pidof v2ray    >/dev/null 2>&1 && { echo "V2Ray";    return; }
    pidof sing-box >/dev/null 2>&1 && { echo "sing-box"; return; }
    pidof b4       >/dev/null 2>&1 && { echo "b4";       return; }
    { pidof nfqws || pidof tpws; } >/dev/null 2>&1 && { echo "zapret"; return; }
    iptables-save 2>/dev/null | grep -qE 'NFQUEUE|TPROXY' && { echo "DPI (NFQUEUE/TPROXY)"; return; }
    nft list ruleset 2>/dev/null | grep -qE 'queue (num|to)|tproxy' && { echo "DPI (nft queue)"; return; }
}

# True when a co-resident transparent proxy (XRAYUI/xray in TPROXY "redirect all traffic" mode)
# is capturing the router's OWN egress. Such a setup installs a catch-all policy rule
# (`from all fwmark 0x10000/0x10000 lookup 77` — XRAYUI's signature) + TPROXY mangle rules, which
# grab amneziawg-go's handshake UDP and our `ping -I awg0` probe before they reach the tunnel — so
# AWG comes up but passes no traffic and the health check rolls it back. Gated on xray actually
# running so the firmware's own WireGuard-client fwmark rules can't trip a false alarm. This is the
# OPPOSITE direction from detect_dpi_tool/coexist_warn (there AWG steals the proxy's traffic).
xray_redirect_active(){
    pidof xray >/dev/null 2>&1 || return 1
    iptables-save -t mangle 2>/dev/null | grep -q 'TPROXY' && return 0
    ip rule show 2>/dev/null | grep -q 'from all fwmark 0x10000' && return 0
    return 1
}

# Stop a co-resident XRAYUI/Xray ON EXPLICIT USER ACTION (the coexistence banner's "Stop Xray"
# button). Go through XRAYUI's OWN entry point — `/jffs/scripts/xrayui stop` runs its `stop()`
# (killall xray + its `cleanup_firewall`), which is what actually REMOVES the TPROXY/fwmark rules.
# A raw `killall xray` would leave those rules behind and the conflict would persist. We only ever
# STOP, only when the user asks — never start or reconfigure xray.
do_xray_stop(){
    if [ ! -x /jffs/scripts/xrayui ]; then
        log_msg "Stop Xray requested, but /jffs/scripts/xrayui not found — cannot control XRAYUI"
        update_status
        return 1
    fi
    log_msg "Stopping Xray (XRAYUI) at user request: /jffs/scripts/xrayui stop"
    local out
    out=$(/jffs/scripts/xrayui stop 2>&1)
    log_msg "  xrayui stop: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    if xray_redirect_active; then
        log_msg "  NOTE: XRAYUI transparent-proxy rules still present after stop — give it a moment or check XRAYUI"
    else
        log_msg "  Xray stopped — transparent-proxy rules cleared; AmneziaWG can route now"
    fi
    update_status
}

# True when Broadcom CTF (Cut-Through Forwarding, the HW-NAT flow accelerator on BCM470x boxes
# like the RT-AC68U) is ACTIVE. CTF forwards packets via a flow cache that SHORT-CIRCUITS the
# netfilter/routing path — so our policy ip-rules (prio 97-100) + fwmark marking are bypassed,
# and bringing them up corrupts the accelerator's kernel state badly enough to HANG the box →
# the hardware watchdog reboots it. Field-confirmed on a remote RT-AC68U (kernel 2.6.36): EVERY
# tunnel start wedged the router regardless of endpoint (this is NOT the loopback-endpoint red
# herring the 1.2.55 note first blamed). Merlin's own VPN-client policy routing / QoS disables
# CTF the same way — nvram ctf_disable=1 + a reboot (the old CTF, ctf_fa_cap=0, has no runtime
# `fc` toggle). Detection: the `ctf` module is loaded AND nvram hasn't already disabled it.
# No-op (returns false) on every box without the module — the AX-series fleet never trips it.
ctf_active(){
    grep -q '^ctf ' /proc/modules 2>/dev/null || return 1
    [ "$(nvram get ctf_disable 2>/dev/null)" = "1" ] && return 1
    return 0
}

# True on a 2.6.x/2.4.x kernel — where AmneziaWG does not work, so do_start refuses up front.
# TWO distinct blockers were found on the RT-AC68U (2.6.36), both real:
#   1. sendmmsg() ENOSYS — the batched UDP send amneziawg-go uses for ALL egress landed in Linux
#      3.0, so the daemon couldn't send a single packet. FIXED (1.2.58): the fork daemon falls
#      back to per-packet sendmsg (version suffix -smfix); proven to send + handshake.
#   2. Policy-routing bring-up (ip rules 97-100 + fwmark + table 300 + iptables) DESTABILISES WAN
#      on 2.6.36 — confirmed 2026-07-13 with the smfix daemon + CTF off: TX flowed (358 B sent)
#      but RX stayed 0, the box became WAN-unreachable and rebooted. UNSOLVED (likely the
#      Entware-iproute2-vs-2.6.36 fragility family). This is why the guard STAYS even though the
#      daemon is fixed — disabling CTF or fixing the daemon is not enough on these kernels.
# Detect by kernel version (ground truth). Supersedes the CTF banner here. Lift only once (2) is
# solved (isolate the breaking ip/iptables op in QEMU 2.6.32, NOT on a live box).
kernel_pre_sendmmsg(){
    case "$(uname -r 2>/dev/null)" in
        2.6.*|2.4.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Disable Broadcom CTF ON EXPLICIT USER ACTION (the CTF banner's button). Sets the persistent
# nvram flag Merlin itself uses and reboots — the only way to unload the accelerator on old-CTF
# boxes (no runtime `fc`). After the reboot ctf_active() is false, the do_start guard passes and
# the policy-routed tunnel comes up normally. We only ever DISABLE (never re-enable behind the
# user's back); a user who wants HW acceleration back can clear ctf_disable in the firmware.
do_ctf_disable(){
    if ! ctf_active; then
        log_msg "Disable-CTF requested, but Broadcom CTF is not active — nothing to do"
        update_status
        return 0
    fi
    log_msg "Disabling Broadcom CTF (hardware NAT acceleration) at user request: nvram ctf_disable_force=1 + ctf_disable=1, then reboot"
    # ctf_disable_force is the PERSISTENT knob (the GUI's LAN → Switch Control → "NAT
    # Acceleration = Disable" sets it, and the firmware's boot init respects it). Setting
    # ctf_disable=1 ALONE does NOT survive a reboot: the firmware recomputes ctf_disable at
    # boot from the features IT knows about — our policy routing is invisible to it, so it
    # resets ctf_disable=0 and CTF comes back (field-confirmed on RT-AC68U: 1 before reboot,
    # 0 after). Set the force flag so the disable sticks; ctf_disable=1 also covers this boot.
    nvram set ctf_disable_force=1
    nvram set ctf_disable=1
    nvram commit
    log_msg "CTF force-disabled in nvram (ctf_disable_force=1) — rebooting to apply. AmneziaWG will be able to start after the router comes back."
    awg_incident "CTF disabled at user request (ctf_disable=1) + reboot — enables policy-routed tunnel on this box"
    update_status
    # Detach the reboot so this service-event handler returns first (the UI reads the log/ack).
    ( sleep 3; reboot ) >/dev/null 2>&1 &
}

# Firmware VPN client coexistence probe (WireGuard wgc* / VPN Fusion). The firmware's policy
# rules sit at priorities ABOVE ours — numerically below our fwmark rule at prio 98 (e.g. VPN
# Fusion's `20: from all lookup 8437`) — so a CONNECTED firmware VPN client captures traffic
# BEFORE AmneziaWG's marking can route it, silently overriding every AWG policy. An enabled-
# but-disconnected profile is the same trap in latent form (field case: wgc_enable=1 with a
# dead endpoint — harmless until the day it connects).
# Echoes one line and returns 0 when there is something to report:
#   "active|<detail>"   — a preempting `from all` rule's table holds a default route NOW
#   "enabled|<profiles>" — wgc profile(s) enabled in nvram, nothing capturing yet
# (Per-device `from <ip>` rules of Merlin's VPN Director sit at prio >10000 — numerically
# BELOW ours — and are fine; only from-all rules above us are the hazard, so only they alarm.)
fw_vpn_client_state(){
    local line prio tbl dflt en="" u v
    while read -r line; do
        prio=${line%%:*}
        prio=$(echo "$prio" | tr -d ' ')
        case "$prio" in ''|*[!0-9]*) continue ;; esac
        [ "$prio" -gt 0 ] && [ "$prio" -lt 97 ] || continue
        # Only UNCONDITIONAL from-all rules: a `from all fwmark ... lookup N` (xray's 0x10000,
        # our own 0x100) captures only traffic ITS owner marked — that's the xray_capture
        # banner's territory, not this one's.
        case "$line" in *fwmark*) continue ;; esac
        case "$line" in *"from all lookup "*) ;; *) continue ;; esac
        tbl=$(echo "$line" | awk '{print $NF}')
        case "$tbl" in ''|local|main|default) continue ;; esac
        dflt=$(ip route show table "$tbl" 2>/dev/null | awk '/^default|^0\.0\.0\.0\/[01]/{print; exit}')
        if [ -n "$dflt" ]; then
            echo "active|prio $prio -> table $tbl ($dflt)"
            return 0
        fi
    done <<EOF
$(ip rule show 2>/dev/null)
EOF
    # Latent (yellow) case: a REAL Merlin profile (wgc1..wgc5 — numbered keys only; the bare
    # unit-less `wgc_enable` on gnuton/stock builds is a leftover of VPN Fusion's edit buffer,
    # NOT a profile — field-confirmed false positive: the VPN Director UI showed everything
    # off while `wgc_enable=1` lingered in nvram) that is enabled but has NO interface up.
    # An enabled profile WITH its interface up routes via VPN Director rules (prio >10000 —
    # numerically below ours, no conflict) and stays silent here; if anything of its ever
    # captures for real, the from-all scan above turns red on its own.
    for u in 1 2 3 4 5; do
        v=$(nvram get "wgc${u}_enable" 2>/dev/null)
        [ "$v" = "1" ] || continue
        iface_exists "wgc${u}" && continue
        en="$en wgc${u}"
    done
    en=$(echo $en)
    if [ -n "$en" ]; then
        echo "enabled|$en"
        return 0
    fi
    return 1
}

# True when a co-resident DNS OWNER is active and we must NOT slam our global :53 DNAT on top of
# it: AdGuardHome (it becomes the LAN's resolver — clients bypass dnsmasq entirely), or the
# firmware's own DNSFilter / DNS Director (dnsfilter_enable_x / dns_director_enable), or
# DoT/DNS-over-TLS via stubby (dnspriv_enable). Forcing our hijack over any of these would
# override the user's DNS policy / encrypted DNS, or fight AGH for :53. When detected we skip the
# hijack (geo-by-IP still works; only forced domain-geo is weakened for clients that resolve past
# the router) instead of fighting the resolver owner. intercept_wanted() shares this, so the
# watchdog reconciler can't drift from setup_firewall's decision.
fw_dns_redirect_active(){
    pidof AdGuardHome >/dev/null 2>&1 && return 0
    [ "$(nvram get dnsfilter_enable_x 2>/dev/null)" = "1" ] && return 0
    [ "$(nvram get dns_director_enable 2>/dev/null)" = "1" ] && return 0
    [ "$(nvram get dnspriv_enable 2>/dev/null)" = "1" ] && return 0
    return 1
}

# Name the SPECIFIC DNS owner (for the start-log diagnostics), with its process/nvram flag so a
# reader can tell WHAT disabled our :53 capture — and, crucially, distinguish the case that still
# lets geo-by-domain populate (DoT: dnsmasq stays the resolver) from the ones that DON'T:
# AdGuardHome and DNSFilter / DNS Director redirect clients PAST dnsmasq, so domains never enter
# the set. AGH is named first — it usually rides on top of one of the nvram flags below.
# Echoes nothing when no DNS owner is active.
fw_dns_redirect_name(){
    pidof AdGuardHome >/dev/null 2>&1 && { echo "AdGuardHome (DNS owner — clients bypass dnsmasq ipset)"; return; }
    [ "$(nvram get dnsfilter_enable_x 2>/dev/null)" = "1" ] && { echo "firmware DNSFilter (dnsfilter_enable_x=1)"; return; }
    [ "$(nvram get dns_director_enable 2>/dev/null)" = "1" ] && { echo "firmware DNS Director (dns_director_enable=1)"; return; }
    [ "$(nvram get dnspriv_enable 2>/dev/null)" = "1" ] && { echo "firmware DoT/DNS-over-TLS (dnspriv_enable=1)"; return; }
}

# True when AdGuardHome is the active resolver on this box (it fronts :53 and clients bypass
# dnsmasq). Used to surface the "wait for AGH" autostart option in the UI and to gate it.
agh_present(){ pidof AdGuardHome >/dev/null 2>&1; }

# Block up to $1 seconds (default 60) until AdGuardHome is up AND bound to :53, then return 0.
# With AGH fronting DNS, autostart's dnsmasq restart is what triggers AMAGHI's ipset collector —
# so waiting for AGH to be READY (not a blind sleep) guarantees the geo-ipset bridge is rebuilt
# against a live AGH. Returns 1 on timeout and proceeds anyway, so a missing/renamed AGH binary
# can never wedge autostart.
wait_for_agh(){
    local max="${1:-60}" i=0
    while [ "$i" -lt "$max" ]; do
        if pidof AdGuardHome >/dev/null 2>&1 && netstat -ln 2>/dev/null | grep -qE '[:.]53[[:space:]]'; then
            log_msg "AdGuardHome ready after ${i}s — proceeding with autostart"
            return 0
        fi
        i=$((i + 1)); sleep 1
    done
    log_msg "AdGuardHome not confirmed ready after ${max}s — proceeding with autostart anyway"
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

# Validated tunnel-DNS servers from awg_dns (comma/space separated): echoes up to 3 IPv4s.
# IPv6 and hostnames are dropped — the @interface upstream binding + the awg0 policy rule
# need literal v4 here (a hostname upstream would need resolving, a chicken-and-egg).
tunnel_dns_ips(){
    local raw ip out="" n=0
    raw=$(get_setting awg_dns | tr ',' ' ')
    for ip in $raw; do
        ip=$(echo "$ip" | tr -d ' \r')
        validate_ip "$ip" || continue
        out="$out $ip"; n=$((n + 1))
        [ $n -ge 3 ] && break
    done
    echo "${out# }"
}

# Fail-open for "DNS via tunnel": restore the firmware upstreams NOW. Drops the flag (the
# postconf hook stops stripping servers-file on the next restart), cuts the server=@awg0
# block out of the live conf and reloads dnsmasq. Called when the router can't resolve while
# the tunnel itself passes traffic — a dead/unreachable tunnel-DNS must never hold the LAN's
# resolution hostage. Deliberately NOT auto-re-enabled: the next Apply/start rebuilds it.
disable_tunnel_dns(){
    rm -f "$TUNNEL_DNS_FLAG"
    if [ -f "$DNSMASQ_AWG_CONF" ] && grep -q '^# AWG_TUNNEL_DNS_START' "$DNSMASQ_AWG_CONF" 2>/dev/null; then
        sed -i '/^# AWG_TUNNEL_DNS_START/,/^# AWG_TUNNEL_DNS_END/d' "$DNSMASQ_AWG_CONF" 2>/dev/null
        rm -f "$DNSRELOAD_SIG"   # conf changed — force a real dnsmasq restart
        log_msg "Tunnel DNS disabled (fail-open) — firmware DNS upstreams restored"
        reload_dnsmasq
    fi
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

# --- ip rule idempotency ---
# `ip rule add` has NO idempotent form (no -C/replace like iptables), so any code path that
# (re)applies our policy rules without a preceding full teardown stacks DUPLICATES. Field-
# seen after an OOM→watchdog restart loop: prio 97/98/99/100 each doubled — because
# setup_firewall runs a SECOND pass once geo finishes downloading (pass 1 has 0 domains) and
# that pass re-adds every `ip rule` on top of pass 1's. Duplicates are harmless to routing
# (identical rules) but confuse diagnosis and grow unbounded across restarts. Our rules live
# at fixed priorities 97-100.

# Drain EVERY copy of our policy ip rules — used by cleanup_firewall for a complete teardown
# (also removes rules orphaned by a since-removed client). Bounded loops: `ip rule del`
# removes ONE copy per call. Priority-scoped to our documented 97-100 range.
drain_ip_rules(){
    local _pr _i
    for _pr in 97 98 99 100; do
        _i=0; while [ $_i -lt 100 ] && ip rule del prio "$_pr" 2>/dev/null; do _i=$((_i+1)); done
    done
    # Fallbacks for a rule that somehow lost its priority tag.
    _i=0; while [ $_i -lt 100 ] && ip rule del lookup $RT_TABLE 2>/dev/null; do _i=$((_i+1)); done
    _i=0; while [ $_i -lt 100 ] && ip rule del fwmark "$FWMARK" 2>/dev/null; do _i=$((_i+1)); done
}

# Idempotent single-rule add: drain every existing copy of THIS exact rule, then add exactly
# one. Used at the setup_firewall add sites so a second setup pass can't duplicate — and,
# unlike draining everything up-front, each rule is absent only for the microseconds between
# its own drain and re-add, so a live re-apply never opens a policy-routing gap across the
# whole rebuild. $@ = the spec after `ip rule` (e.g. `from 1.2.3.4 lookup main prio 97`).
ip_rule_replace(){
    local _i=0
    while [ $_i -lt 100 ] && ip rule del "$@" 2>/dev/null; do _i=$((_i+1)); done
    ip rule add "$@"
}

cleanup_firewall(){
    # Unhook from PREROUTING, flush and delete custom chain
    iptables -t mangle -D PREROUTING -j "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -F "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -X "$AWG_CHAIN" 2>/dev/null

    # Remove every copy of our policy ip rules (prio 97-100 + table/fwmark fallback)
    drain_ip_rules

    # Remove the global :53 DNS-interception rules (DNAT + DoH/DoT REJECTs)
    cleanup_dns_interception

    # Destroy every geo ipset WE created — the registry holds their exact names (base id-1 set
    # only if we owned it, plus all per-policy ${IPSET_NAME}<id> sets, and any OLD names still
    # listed after an awg_ipset_name rename). Exact-name teardown means a pre-existing/shared set
    # or an unrelated tool's set under a colliding base name is never touched.
    destroy_owned_sets

    # Remove dnsmasq config (+ the tunnel-DNS flag in lockstep — see TUNNEL_DNS_FLAG invariant)
    rm -f "$DNSMASQ_AWG_CONF"
    rm -f "$TUNNEL_DNS_FLAG"
    # Fixed-string removal (the path contains '.', which a sed regex would treat as any-char and
    # could match an unrelated line). Gate the rewrite on the line being PRESENT, then do the
    # strip+mv UNCONDITIONALLY: the old `grep -vF ... > tmp && mv` chained the mv on grep's exit
    # code, so when our conf-file line was the ONLY line in the include, `grep -v` printed nothing,
    # exited 1, and the `&& mv` was SKIPPED — leaving the dangling `conf-file=$DNSMASQ_AWG_CONF`
    # pointed at a file we just deleted (fatal to the firmware's dnsmasq at the next boot/restart).
    # An empty result is the correct outcome here.
    if [ -f "$DNSMASQ_INCLUDE" ] && grep -qF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
        grep -vF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.tmp" 2>/dev/null
        mv "${DNSMASQ_INCLUDE}.tmp" "$DNSMASQ_INCLUDE"
    fi

    # Remove the geo-update cron (re-added by setup_firewall only when autoupdate is on, so
    # toggling it off is honored here). The self-heal watchdog cron is deliberately NOT
    # dropped here: cleanup_firewall runs on every Apply/firewall-restart AND on the
    # health-check/deadman auto-rollback, and removing the watchdog there would strand a
    # rolled-back tunnel with no way to recover. It is removed only on a user stop/uninstall.
    cru d awg_geo_update 2>/dev/null

    cleanup_ipv6_block

    log_msg "Firewall rules cleaned"
}

# --- Updater dnsmasq-reload coalescing ---
# finalize_ipk_install's stop → prerm → postinst → stop chain kicks 3-4 detached reload
# jobs while rc_service is busy with OUR OWN start_awgdoupdate service-event. None of
# their `service restart_dnsmasq` calls can execute until the update handler returns
# (notify_rc blocks ~15s waiting for it, then DROPS the request — "skip the event"), and
# each live job held finalize's/prerm's settle-waits for the full 60s (field log: two
# ~1-min stalls + 7 dropped restarts per update, then a restart tail AFTER the update).
# While DNSRELOAD_DEFER is fresh, reload jobs record PENDING and exit instantly; the
# updater fires exactly ONE reload at the end on every exit path (dnsreload_defer_end).
# Freshness-capped like .awg_no_autostart: a flag leaked by an updater that died
# mid-flight must not swallow reloads forever (geo/tunnel-DNS conf edits would silently
# stop landing in dnsmasq — the same class of harm as a stolen lock disabling self-heal).
dnsreload_deferred(){
    [ -f "$DNSRELOAD_DEFER" ] || return 1
    if [ -n "$(find "$DNSRELOAD_DEFER" -mmin +15 2>/dev/null)" ]; then
        rm -f "$DNSRELOAD_DEFER"
        return 1
    fi
    return 0
}

dnsreload_defer_begin(){
    rm -f "$DNSRELOAD_PENDING"
    touch "$DNSRELOAD_DEFER"
}

# Close the defer window; if any reload was swallowed while it was open, fire exactly one
# now. The spawned job settles rc first (we are usually STILL inside the update's
# service-event here), so dnsmasq restarts once, seconds after the handler returns — the
# "lucky last attempt" a field log showed by accident, made deterministic.
dnsreload_defer_end(){
    rm -f "$DNSRELOAD_DEFER"
    if [ -f "$DNSRELOAD_PENDING" ]; then
        rm -f "$DNSRELOAD_PENDING"
        reload_dnsmasq
    fi
}

# Reload dnsmasq so it re-reads our ipset/domain rules from dnsmasq.conf.add.
# When invoked from a service-event, rc_service is busy and a direct
# "service restart_dnsmasq" is dropped ("skip the event: restart_dnsmasq"); a
# foreground retry would deadlock (rc waits for this very handler). So defer to a
# detached job that first waits for rc_service to go IDLE (the job outlives the
# handler, so the event always ends under it), then restarts until it actually
# takes (dnsmasq PID changes), then pre-resolves geo domains to populate the ipset.
reload_dnsmasq(){
    (
        # Updater window: don't queue up behind the lock just to fight a busy rc —
        # mark that a reload is owed and let the updater fire one at the end.
        if dnsreload_deferred; then touch "$DNSRELOAD_PENDING"; exit 0; fi
        # Serialize reload jobs: wait for any prior one (so the last restart loads the
        # current on-disk config), then hold the lock. Avoids ping-ponging restarts.
        # OWNERSHIP matters here: the old code, after 60s of waiting, BROKE OUT and ran
        # anyway — unserialized — and its EXIT trap then removed the OTHER job's lock, so
        # every later job also ran unserialized (two pre-resolve storms in the same second
        # were seen in a field log). Now: reclaim only a DEAD holder's lock, concede (skip
        # this reload) if a live one still holds it after the wait — the running job loads
        # the current on-disk conf anyway, and the watchdog reconcile re-installs the :53
        # DNAT within 5 min if this call was carrying the interception flag.
        _w=0
        while ! mkdir /tmp/.awg_dnsreload 2>/dev/null; do
            _hp=$(cat /tmp/.awg_dnsreload/pid 2>/dev/null)
            if [ -n "$_hp" ] && ! kill -0 "$_hp" 2>/dev/null; then
                rm -rf /tmp/.awg_dnsreload 2>/dev/null
                continue
            fi
            # The defer window can open while we queue (update started under a running
            # job) — hand off to the updater's final reload instead of waiting it out.
            if dnsreload_deferred; then touch "$DNSRELOAD_PENDING"; exit 0; fi
            _w=$((_w + 1))
            if [ $_w -ge 240 ]; then
                log_msg "dnsmasq reload: another reload job (pid ${_hp:-?}) still running after 240s — skipping this one"
                exit 0
            fi
            sleep 1
        done
        # Real pid of THIS reload subshell — `echo $$` here would record the parent (dead in
        # seconds) and every waiter would "reclaim" our live lock; see the acquire_lock note.
        sh -c 'echo $PPID' > /tmp/.awg_dnsreload/pid 2>/dev/null
        trap 'rm -rf /tmp/.awg_dnsreload 2>/dev/null' EXIT INT TERM
        # Order-independent PID snapshot (sorted): dnsmasq runs as main + a --log-async child, so
        # pidof returns two PIDs — sort them so a mere change in listing order can't masquerade as
        # (or mask) a real restart in the comparison below.
        oldpid=$(pidof dnsmasq 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ' ')
        # A busy rc_service means `service restart_dnsmasq` is LOST, not queued: notify_rc
        # blocks ~15s inside our call waiting for the in-flight event, then DROPS ours
        # ("skip the event: restart_dnsmasq"). When that in-flight event is one of our OWN
        # service-events (start_awgstart / start_awgdoupdate), the drop is GUARANTEED — rc
        # is waiting on the very handler this detached job outlives (a circular wait broken
        # only by rc's 15s timeout; a field update log shows 7 straight block+drop cycles,
        # ~2 min stalled, zero restarts). So before each attempt, poll 1s until rc goes
        # idle — the one call that then executes beats thirty that rc throws away. The
        # budget is job-global, so a pathologically busy rc degrades to the old fire-blind
        # behavior instead of pinning this job (and the lock) forever.
        _rcbudget=150
        _rc_settle(){
            while [ $_rcbudget -gt 0 ]; do
                [ -z "$(nvram get rc_service 2>/dev/null)" ] && return 0
                # Update began while we waited: its final reload supersedes this one.
                if dnsreload_deferred; then touch "$DNSRELOAD_PENDING"; exit 0; fi
                sleep 1
                _rcbudget=$((_rcbudget - 1))
            done
            return 0
        }
        # Did dnsmasq restart since the snapshot? Any PID change counts — an external
        # restart that landed while we settled has read the SAME on-disk conf we carry.
        _reload_took(){
            newpid=$(pidof dnsmasq 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ' ')
            [ -n "$newpid" ] && [ "$newpid" != "$oldpid" ]
        }
        # Skip a pointless restart when the on-disk geo conf is byte-identical to the one we last
        # loaded AND dnsmasq is still the SAME process that loaded it — common on an Apply that
        # changed only a device->policy assignment, not the geo lists. A needless restart only widens
        # the :53-bind/OOM race window on contended boxes (co-resident Xray/b4). The conf is generated
        # deterministically, so an unchanged selection md5s the same. We store "<pid>|<md5>": pinning
        # the PID means an external dnsmasq restart (PID changed) forces a real reload, and the
        # cleanup_firewall strip/re-add of our include between Applies (which does NOT restart
        # dnsmasq) can't trick us into skipping while dnsmasq lacks the rules.
        _sig=$(md5sum "$DNSMASQ_AWG_CONF" 2>/dev/null | awk '{print $1}')
        if [ -n "$_sig" ] && [ -n "$oldpid" ] && [ "$(cat "$DNSRELOAD_SIG" 2>/dev/null)" = "${oldpid}|${_sig}" ]; then
            log_msg "dnsmasq geo conf unchanged and same resolver instance — skipping restart"
        else
            # Low-RAM backoff: restarting dnsmasq repeatedly under memory pressure can OOM-kill it,
            # so on a starved box lengthen the inter-try sleep instead of hammering restart_dnsmasq.
            _step=1
            _memav=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)
            [ -n "$_memav" ] && [ "$_memav" -lt 81920 ] && _step=4
            i=0; _took=0
            while [ $i -lt 30 ]; do
                _rc_settle
                # rc may have executed a PREVIOUS attempt while we waited for it to go
                # idle — don't fire another restart over a resolver that just reloaded
                # (a needless bounce only widens the :53 outage window).
                if _reload_took; then _took=1; break; fi
                service restart_dnsmasq >/dev/null 2>&1
                sleep 2
                if _reload_took; then _took=1; break; fi
                i=$((i + 1))
                sleep "$_step"
            done
            if [ "$_took" = 1 ]; then
                log_msg "dnsmasq reloaded (geo rules active)"
                [ -n "$_sig" ] && echo "${newpid}|${_sig}" > "$DNSRELOAD_SIG"
            else
                log_msg "WARNING: dnsmasq reload never took (rc kept dropping restart_dnsmasq); geo domains may need a manual restart"
            fi
        fi
        # Self-heal: if dnsmasq is NOT running at all now, the LAN just lost DHCP/DNS. But DON'T
        # assume our config is to blame and nuke geo routing — on a box with a co-resident resolver
        # (Xray/b4) the usual cause is a transient :53 bind race or an OOM blip, NOT our rules
        # (which were already gate-validated by `dnsmasq --test` before activation). Blindly
        # removing our conf on a transient failure permanently disables geo routing until the next
        # full Apply. So: diagnose first, retry the SAME conf if it's valid, and only as a LAST
        # resort drop our include to guarantee the resolver comes back.
        if ! pidof dnsmasq >/dev/null 2>&1; then
            # Diagnostic snapshot (so the next report pinpoints the cause instead of guessing):
            # memory, who owns :53, the live dnsmasq instances, and recent dnsmasq/OOM syslog lines.
            _mem=$(awk '/^Mem(Total|Free|Available):/{printf "%s=%s ",$1,$2}' /proc/meminfo 2>/dev/null)
            _p53=$(netstat -lnp 2>/dev/null | awk '$4 ~ /[:.]53$/{print $NF; exit}')
            _dmlog=$(logread 2>/dev/null | grep -iE 'dnsmasq|out of memory|oom' | tail -3 | tr '\n' '|')
            # Does the FULL effective conf Merlin just regenerated (it conf-file-includes our
            # snippet) actually PARSE? Our snippet was already validated in isolation, so a parse
            # FAILURE here is a combination conflict and our conf is the only lever we have; a parse
            # PASS means the death is runtime (race/OOM) and our valid conf must NOT be thrown away.
            if which dnsmasq >/dev/null 2>&1; then
                _dmtest=$(dnsmasq --test --conf-file=/etc/dnsmasq.conf 2>&1); _dmrc=$?
            else
                _dmtest="(dnsmasq not found)"; _dmrc=0
            fi
            cp "$DNSMASQ_AWG_CONF" "${DNSMASQ_AWG_CONF}.bad" 2>/dev/null
            log_msg "dnsmasq down after reload — diag: ${_mem}port53=${_p53:-?} test_rc=${_dmrc} test='$(echo "$_dmtest" | tr '\n' ' ')' recent='${_dmlog}'"
            _recovered=0
            if [ "$_dmrc" -eq 0 ]; then
                # Config is valid → transient failure suspected. Retry a few times WITHOUT touching
                # our conf, so geo routing survives a passing :53/OOM blip.
                log_msg "config parses clean — retrying dnsmasq with geo rules INTACT (transient failure suspected)"
                _r=0
                while [ $_r -lt 5 ]; do
                    _rc_settle   # a dropped attempt here = more dead-LAN time; make it count
                    service restart_dnsmasq >/dev/null 2>&1
                    sleep 2
                    if pidof dnsmasq >/dev/null 2>&1; then _recovered=1; log_msg "dnsmasq recovered WITH geo rules intact"; break; fi
                    _r=$((_r + 1)); sleep 1
                done
            fi
            if [ "$_recovered" = 0 ]; then
                # Still down (or the conf genuinely failed --test) — LAST RESORT: drop our include
                # so the LAN gets its resolver back. Degraded geo beats a dead LAN; conf kept as .bad.
                log_msg "ERROR: dnsmasq still down — removing AWG dnsmasq rules + restarting to restore DNS/DHCP (conf kept as ${DNSMASQ_AWG_CONF}.bad)"
                awg_incident "dnsmasq stayed DOWN after reload — stripped AWG dnsmasq rules to restore LAN DNS/DHCP"
                rm -f "$DNSMASQ_AWG_CONF"
                rm -f "$TUNNEL_DNS_FLAG"   # conf (incl. server=@awg0) gone — flag must fall with it
                rm -f "$DNSRELOAD_SIG"   # conf unloaded — force a real restart on the next reload
                # Reliable strip (see cleanup_firewall): a bare `grep -vF ... && mv` skips the mv
                # when our line is the only one, leaving a dangling conf-file= that breaks dnsmasq.
                if [ -f "$DNSMASQ_INCLUDE" ] && grep -qF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
                    grep -vF "$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.tmp" 2>/dev/null
                    mv "${DNSMASQ_INCLUDE}.tmp" "$DNSMASQ_INCLUDE"
                fi
                _j=0
                while [ $_j -lt 15 ]; do
                    _rc_settle
                    service restart_dnsmasq >/dev/null 2>&1
                    sleep 2
                    pidof dnsmasq >/dev/null 2>&1 && { log_msg "dnsmasq recovered (AWG dnsmasq rules removed)"; break; }
                    _j=$((_j + 1)); sleep 1
                done
                # ABSOLUTE last resort: every `service restart_dnsmasq` can be silently DROPPED
                # by a busy rc_service ("skip the event" — seen in the field while rc waited on
                # our own start_awgstart), leaving the LAN without DNS/DHCP indefinitely. If the
                # service path is exhausted and dnsmasq is STILL down, exec it directly the way
                # the firmware runs it — rc's next real restart will kill+replace this instance
                # cleanly, so we never end up fighting it.
                if ! pidof dnsmasq >/dev/null 2>&1 && which dnsmasq >/dev/null 2>&1; then
                    if dnsmasq --test >/dev/null 2>&1; then
                        log_msg "EMERGENCY: rc kept skipping restart_dnsmasq — starting dnsmasq directly to restore LAN DNS/DHCP"
                        dnsmasq --log-async >/dev/null 2>&1
                        sleep 2
                        pidof dnsmasq >/dev/null 2>&1 && log_msg "dnsmasq up (direct start)" \
                            || log_msg "ERROR: direct dnsmasq start failed too — LAN DNS still down"
                    else
                        log_msg "ERROR: /etc/dnsmasq.conf itself fails --test — not starting dnsmasq over a broken config"
                    fi
                fi
            fi
        fi
        wait_for_dns 10
        # Install the LAN :53 DNAT ONLY now that dnsmasq is confirmed answering. Doing it
        # before/while the restart_dnsmasq loop above bounces the resolver would DNAT every
        # client's DNS to a dead dnsmasq — the all-LAN "can't connect" blackout. The arg is
        # passed only by setup_firewall when interception is wanted; every other caller omits
        # it, so they never touch the DNAT. setup_dns_interception self-guards on dnsmasq up.
        [ "$1" = "1" ] && setup_dns_interception
        # Only when the conf actually carries domain rules: a filter-AAAA-only conf (CIDR-only
        # geo selection, no domains) has nothing to pre-resolve, and the "ipset UNCHANGED —
        # domain IPs are NOT landing in the set" warning it produced was pure false alarm.
        if [ -f "$DNSMASQ_AWG_CONF" ] && grep -q '^ipset=' "$DNSMASQ_AWG_CONF" 2>/dev/null; then
            # Snapshot the LIVE geo ipset entry count before/after the pre-resolve so the log shows
            # whether domains actually landed in the set — not just that the ipset= RULES were
            # written ("Firewall configured: N IPs, M domains" is a build-time snapshot + a rule
            # tally, NOT proof of population). A no-growth result is the fingerprint of "domains
            # don't route": either the resolver is down, or clients/the geo conf never feed the set.
            _pre_ips=$(geo_ipset_total)
            bg_count=0
            awk -F/ '/^ipset=/{for(i=2;i<NF;i++)print $i}' "$DNSMASQ_AWG_CONF" | while read -r domain; do
                [ -z "$domain" ] && continue
                nslookup "$domain" 127.0.0.1 >/dev/null 2>&1 &
                bg_count=$((bg_count + 1))
                [ $bg_count -ge 10 ] && { wait; bg_count=0; }
            done
            wait
            _post_ips=$(geo_ipset_total)
            if [ "$_post_ips" != "$_pre_ips" ]; then
                # "changed", not "grew": with timeout>0 domain entries the count can legitimately
                # go DOWN between snapshots (expiry outpacing adds) — the old "grew 24189 -> 22253"
                # wording confused reports. Both directions mean the resolver IS feeding the sets.
                log_msg "Geo domain pre-resolve: ipset ${_pre_ips} -> ${_post_ips} entries (resolver feeding the sets$([ "$_post_ips" -lt "$_pre_ips" ] 2>/dev/null && echo '; net shrink = old entries expiring faster than adds'))"
            elif dns_ok; then
                log_msg "Geo domain pre-resolve: ipset UNCHANGED at ${_pre_ips} — resolver answers real names but domain IPs are NOT landing in the set (geo conf not loaded into dnsmasq, or restart was skipped) — a restart usually fixes it"
            else
                log_msg "Geo domain pre-resolve: ipset UNCHANGED at ${_pre_ips} — router DNS not resolving real names yet (WAN/upstream/DoT not ready); domains will fill on later client queries"
            fi
        fi
    ) </dev/null >/dev/null 2>&1 &
}

# Append a geo policy's mangle marking rules to AWG_CHAIN, honoring its mode (include/exclude)
# and exclusion set. $1 = geo policy id; $2.. = the iptables match tokens that scope the rule to
# one device (e.g. "-m mac --mac-source AA:BB" or "-s 1.2.3.4"), or NOTHING for the default
# policy. All marking is 0x100 -> RT_TABLE (one tunnel). Verdict per the design table:
#   include (mode=vpn):   EXC -> direct (RETURN); INC -> VPN (MARK); rest -> direct
#   exclude (mode=direct): EXC -> VPN (MARK); INC -> direct (RETURN); rest -> VPN (MARK)
# A PER-DEVICE call (a selector is present) is TERMINAL: include mode ends with a RETURN so the
# device's non-matched traffic does NOT fall through to the default-policy rule (which would
# also route it by the "common" default set). The default-policy call (no selector) is the
# chain's last block and needs no terminal RETURN; it still applies to UNLISTED devices.
# Returns 1 (emits nothing) if the policy's main set is missing/foreign.
emit_geo_rules(){
    local pgid="$1"; shift
    local incset excset mode have_exc=0
    incset=$(geo_ipset "$pgid"); excset=$(geo_exc_ipset "$pgid"); mode=$(geo_mode "$pgid")
    ipset list "$incset" >/dev/null 2>&1 && geo_set_ours "$pgid" "$incset" || return 1
    ipset list "$excset" >/dev/null 2>&1 && geo_set_ours "$pgid" "$excset" && have_exc=1
    if [ "$mode" = direct ]; then
        # exclude: EXC -> VPN; INC -> direct (terminal RETURN); rest -> VPN (the trailing MARK
        # fully decides the device, so no extra terminal RETURN is needed).
        [ "$have_exc" = 1 ] && iptables -t mangle -A "$AWG_CHAIN" "$@" -m set --match-set "$excset" dst -j MARK --set-mark "$FWMARK"
        iptables -t mangle -A "$AWG_CHAIN" "$@" -m set --match-set "$incset" dst -j RETURN
        iptables -t mangle -A "$AWG_CHAIN" "$@" -j MARK --set-mark "$FWMARK"
    else
        # include: EXC -> direct; INC -> VPN; then (per-device only) RETURN so the rest stays
        # direct instead of inheriting the default policy.
        [ "$have_exc" = 1 ] && iptables -t mangle -A "$AWG_CHAIN" "$@" -m set --match-set "$excset" dst -j RETURN
        iptables -t mangle -A "$AWG_CHAIN" "$@" -m set --match-set "$incset" dst -j MARK --set-mark "$FWMARK"
        [ "$#" -gt 0 ] && iptables -t mangle -A "$AWG_CHAIN" "$@" -j RETURN
    fi
    return 0
}

setup_firewall(){
    cleanup_firewall

    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local has_geo=false

    # --- Create + populate one ipset PER geo policy ---
    # Old routers (e.g. RT-AC68U) don't autoload the ip_set kernel modules, and the
    # in-kernel auto-load needs modprobe — absent from the httpd/service-event PATH
    # context — so `ipset create` fails there. Load them explicitly (no-op if already
    # loaded or built-in). xt_set backs the `-m set --match-set` mangle rules below.
    local m
    for m in ip_set ip_set_hash_net xt_set; do
        modprobe "$m" 2>/dev/null
    done
    # Default timeout 24h: governs domain entries added by dnsmasq (GeoSite/custom domains).
    # They MUST expire — CDNs rotate IPs; dnsmasq re-adds the current IP on each resolution
    # (refreshing it), so active domains stay while stale IPs age out. Static GeoIP/custom-IP
    # entries are added with explicit "timeout 0" (permanent), overriding this default.
    # RAM-aware TOTAL budget: on low-memory routers (RT-AC68U etc., 256MB) the big lists
    # (antifilter ipresolve ~154K) can exhaust kernel memory and hang the router. With N geo
    # policies each owning a set, divide the budget by N (geo_maxelem) so they can't sum past
    # the box's ceiling. Adds past a set's cap fail harmlessly (ipset restore -!).
    local total_max="$IPSET_MAXELEM" memkb
    memkb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$memkb" ] && [ "$memkb" -lt 393216 ]; then
        total_max=98304
        log_msg "Low RAM (${memkb}KB total): geo ipset budget capped at $total_max (was $IPSET_MAXELEM) to avoid OOM"
    fi
    local maxelem; maxelem=$(geo_maxelem "$total_max")

    # NOTE: cleanup_firewall (called at the top of setup_firewall) already destroyed every set we
    # owned via the registry — including the OLD names after an awg_ipset_name rename — so there's
    # no orphaned "<oldbase>*" family to chase here. We just (re)create + re-register below.
    # GC per-policy content files for policies deleted in the UI before (re)building active ones.
    prune_orphan_policies

    # Sync the SHARED pool to the union of all policies' selections (drop de-selected files) and
    # extract the union of GeoSite categories once. Per-policy loading below picks each subset.
    migrate_geocustom_layout   # one-time: drop pre-shared-pool flat usercustom_*/custom.txt
    prune_geoip
    prune_antifilter
    prune_custom_urls
    build_geosite_domains

    local gid gset
    for gid in $(geo_ids); do
        gset=$(geo_ipset "$gid")
        local _cerr _crc
        _cerr=$(ipset create "$gset" hash:net family inet hashsize 4096 maxelem "$maxelem" timeout 86400 2>&1)
        _crc=$?
        # Register the set as ours ONLY if WE created it (rc 0). cleanup destroyed + cleared the
        # registry first, so each build re-registers exactly the sets it creates.
        [ "$_crc" -eq 0 ] && register_owned_set "$gset"
        if ! ipset list "$gset" >/dev/null 2>&1; then
            log_msg "ERROR: ipset $gset creation failed, geo policy $gid disabled${_cerr:+: $_cerr}"
            continue
        fi
        # id>=2 names are derived from our base; if one already existed (create rc!=0, so it's
        # not in our registry) it belongs to another tool — skip the policy rather than load OUR
        # entries into a foreign set. id 1 keeps the documented shared-base behavior.
        if ! geo_set_ours "$gid" "$gset"; then
            log_msg "WARNING: ipset $gset pre-exists and isn't ours — skipping geo policy $gid (foreign-name collision)"
            continue
        fi

        # Load THIS policy's selected subset from the shared pool into its own set.
        local _svc _f _ak _uk _cip
        for _svc in $(selected_geoip "$gid"); do
            _f="$GEO_DIR/geoip/v2fly_${_svc}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$gset"
        done
        for _ak in $(selected_antifilter "$gid"); do
            antifilter_is_domain "$_ak" && continue
            _f="$GEO_DIR/antifilter/af_${_ak}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$gset"
        done
        # Custom URL CIDRs this policy references (shared files keyed by URL hash).
        for _uk in $(policy_url_keys "$gid"); do
            _f="$GEO_DIR/geoip/userurl_${_uk}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$gset"
        done
        # Custom IPs (field) -> permanent entries.
        for _cip in $(get_setting "$(geo_key "$gid" custom_ips)" | tr ',' ' '); do
            _cip=$(echo "$_cip" | tr -d ' \r')
            [ -n "$_cip" ] && ipset add "$gset" "$_cip" timeout 0 2>/dev/null
        done
        # GeoCustom pasted files (per-policy content): regenerate, then load this policy's CIDRs.
        apply_custom_geo "$gid"
        for _f in "$GEO_DIR"/geoip/usercustom_p${gid}_*.cidr; do
            [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$gset"
        done
        # This policy's own custom-domains file (consumed by the dnsmasq builder below).
        build_custom_domains "$gid"

        # --- Exclusions channel (pointwise exceptions) ---
        # Always (re)generate this policy's exclusion content files (self-clean when empty), so a
        # cleared exclusions block leaves nothing behind. Only build the EXC ipset when used: it's
        # small (pointwise) and gets a fixed cap, so it never erodes the divided main budget.
        apply_custom_geo "$gid" exc
        build_custom_domains "$gid" exc
        if policy_has_exc "$gid"; then
            local _exset _ecrc
            _exset=$(geo_exc_ipset "$gid")
            ipset create "$_exset" hash:net family inet hashsize 1024 maxelem 8192 timeout 86400 2>/dev/null
            _ecrc=$?
            [ "$_ecrc" -eq 0 ] && register_owned_set "$_exset"
            # Ownership guard mirrors the main set: never load OUR entries into a foreign set that
            # happens to use the derived "<base><id>_x" name (id 1's shared base proceeds).
            if ipset list "$_exset" >/dev/null 2>&1 && geo_set_ours "$gid" "$_exset"; then
                for _cip in $(get_setting "$(geo_key "$gid" exc_ips)" | tr ',' ' '); do
                    _cip=$(echo "$_cip" | tr -d ' \r')
                    [ -n "$_cip" ] && ipset add "$_exset" "$_cip" timeout 0 2>/dev/null
                done
                for _f in "$GEO_DIR"/geoip/excustom_p${gid}_*.cidr; do
                    [ -f "$_f" ] && ipset_load_file "$_f" "$_exset"
                done
                for _uk in $(policy_url_keys "$gid" exc); do
                    _f="$GEO_DIR/geoip/userurl_${_uk}.cidr"; [ -f "$_f" ] && ipset_load_file "$_f" "$_exset"
                done
            fi
        fi

        # Fill-level warning (per set).
        local _ent
        _ent=$(ipset list "$gset" -t 2>/dev/null | awk '/Number of entries/{print $NF}')
        [ -n "$_ent" ] && [ "$_ent" -ge "$maxelem" ] 2>/dev/null && \
            log_msg "WARNING: ipset $gset full ($_ent/$maxelem) for geo policy $gid — raise RAM or trim its lists"
    done

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
    # Per policy: route ITS selected domains into ITS OWN ipset (INC -> main set, EXC -> exclusion
    # set). The exact files a policy uses are enumerated from its selection (NOT a dir glob), since
    # the pool is shared. Domain->ipset rules only work if the set exists, so re-check `ipset list`
    # per policy (mirrors the per-device mangle vpn_geo guard).
    #
    # CRITICAL (the multi-policy domain bug): dnsmasq honors only the FIRST `ipset=` directive that
    # matches a given domain — a second `ipset=/dom/otherset` line for the same domain is silently
    # ignored (verified on dnsmasq 2.93). So we must NOT emit one line per policy: a domain shared
    # by two policies (the common case — youtube/netflix/etc. in several tabs) would populate only
    # the first policy's set and starve every other policy's device of that destination. Instead we
    # collect (domain -> target set) pairs across ALL policies/channels and emit each domain ONCE
    # as `ipset=/dom/setA,setB,...` — a comma-set line fans the resolved IP to EVERY listed set.
    local dgid dgset f _cat _uk _dfiles _efiles _chan _cset _cfiles
    local _ds_tmp="$GEO_DIR/.dnsmasq_ds.$$"
    : > "$_ds_tmp"
    for dgid in $(geo_ids); do
        dgset=$(geo_ipset "$dgid")
        # INC domain files for this policy (route via its main set).
        _dfiles=""
        for _cat in $(get_setting "$(geo_key "$dgid" v2fly)" | tr ',' ' '); do
            _cat=$(echo "$_cat" | sed 's/[^A-Za-z0-9_.-]//g'); [ -z "$_cat" ] && continue
            _dfiles="$_dfiles $GEO_DIR/domains/v2fly_${_cat}.txt"
        done
        _dfiles="$_dfiles $GEO_DIR/domains/custom_p${dgid}.txt"
        case " $(selected_antifilter "$dgid") " in *" community_domains "*) _dfiles="$_dfiles $GEO_DIR/domains/antifilter_community_domains.lst" ;; esac
        for _uk in $(policy_url_keys "$dgid"); do _dfiles="$_dfiles $GEO_DIR/domains/userurl_${_uk}.txt"; done
        for f in "$GEO_DIR"/domains/usercustom_p${dgid}_*.txt; do [ -f "$f" ] && _dfiles="$_dfiles $f"; done
        # EXC domain files for this policy (the exclusions block -> its EXC set).
        _efiles="$GEO_DIR/domains/custom_exc_p${dgid}.txt"
        for _uk in $(policy_url_keys "$dgid" exc); do _efiles="$_efiles $GEO_DIR/domains/userurl_${_uk}.txt"; done
        for f in "$GEO_DIR"/domains/excustom_p${dgid}_*.txt; do [ -f "$f" ] && _efiles="$_efiles $f"; done

        # Collect each channel's (domain -> target set) pairs into the shared stream.
        for _chan in inc exc; do
            if [ "$_chan" = exc ]; then _cset="$(geo_exc_ipset "$dgid")"; _cfiles="$_efiles"; else _cset="$dgset"; _cfiles="$_dfiles"; fi
            if ! ipset list "$_cset" >/dev/null 2>&1 || ! geo_set_ours "$dgid" "$_cset"; then
                for f in $_cfiles; do [ -f "$f" ] && { log_msg "domain-geo disabled for policy $dgid ($_chan): ipset $_cset unavailable (domains configured but not routable)"; break; }; done
                continue
            fi
            for f in $_cfiles; do
                [ -f "$f" ] || continue
                # Normalize in one awk pass per file (no per-domain shell fork): strip spaces/CR,
                # drop blanks/comments, strip a leading dot and any trailing ":@attr" v2fly tag,
                # reject domains with invalid chars. Emit "<domain>\t<set>".
                awk -v set="$_cset" '
                    { d=$0; gsub(/[ \r]/,"",d)
                      if (d=="" || substr(d,1,1)=="#") next
                      sub(/^\./,"",d); sub(/:@[^ ]*$/,"",d)
                      if (d=="" || d ~ /[^a-zA-Z0-9._-]/) next
                      print d "\t" set }' "$f" >> "$_ds_tmp"
            done
        done
    done

    # Aggregate domain -> unique set list across ALL policies/channels, then emit each domain once
    # as `ipset=/dom/setA,setB` (chunked 20 domains/line, grouped by identical set list so lines
    # stay compact). This collision-free form is what dnsmasq actually honors for shared domains.
    # DETERMINISTIC: the input is sorted (so each domain's set list is built in a stable order) and
    # the emitted lines are sorted, so an unchanged selection produces a byte-identical conf — that
    # lets reload_dnsmasq md5-compare and SKIP a pointless dnsmasq restart (see reload_dnsmasq).
    if [ -s "$_ds_tmp" ]; then
        domain_count=$(cut -f1 "$_ds_tmp" | sort -u | wc -l | tr -d ' ')
        sort "$_ds_tmp" | awk -F'\t' '
            { dom=$1; set=$2
              if (!(dom in S)) { S[dom]=set; next }
              cur=S[dom]; n=split(cur,a,","); found=0
              for(i=1;i<=n;i++) if(a[i]==set){found=1;break}
              if(!found) S[dom]=cur","set }
            END {
              for (dom in S) { sig=S[dom]; G[sig]=G[sig] " " dom }
              for (sig in G) {
                cnt=0; line="ipset=/"
                m=split(G[sig], dd, " ")
                for(i=1;i<=m;i++){
                  if(dd[i]=="") continue
                  line=line dd[i] "/"; cnt++
                  if(cnt>=20){ print line sig; line="ipset=/"; cnt=0 }
                }
                if(cnt>0) print line sig
              }
            }' | sort >> "$DNSMASQ_AWG_CONF"
    fi
    rm -f "$_ds_tmp"

    # --- "DNS via tunnel" (opt-in, awg_tunnel_dns=1) ---
    # While the VPN is up AND our :53 interception is in play, resolve the WHOLE LAN through
    # the tunnel's DNS (the awg_dns field — e.g. a provider-internal 100.64.0.1 reachable
    # only inside the tunnel): `server=<ip>@awg0` binds dnsmasq's upstream socket to awg0,
    # whose source address the "from <awg0-ip> lookup $RT_TABLE prio 100" rule routes through
    # the tunnel — the same proven path update-via-VPN and the TCP probe use. `no-resolv`
    # plus the dnsmasq.postconf hook (strips servers-file/resolv-file while $TUNNEL_DNS_FLAG
    # exists) shut the firmware upstreams off, so poisoned ISP DNS can't answer first.
    # Gated on intercept_wanted: interception is the mode where we own LAN DNS and where the
    # full safety net (deadman, --test gate, dns_ok fail-open via disable_tunnel_dns) applies;
    # in compatibility mode the toggle is inert (logged). Flag and block toggle TOGETHER.
    rm -f "$TUNNEL_DNS_FLAG"
    local _tdns_on=0 _tdns_ips="" _tip
    if [ "$(get_setting awg_tunnel_dns)" = "1" ]; then
        _tdns_ips=$(tunnel_dns_ips)
        if [ -z "$_tdns_ips" ]; then
            log_msg "Tunnel DNS is on but the DNS field has no valid IPv4 — ignoring"
        elif ! intercept_wanted; then
            log_msg "Tunnel DNS is on but DNS interception is off (compat mode / co-resident DNS owner) — ignoring; enable interception to use it"
        else
            {
                echo "# AWG_TUNNEL_DNS_START"
                echo "no-resolv"
                for _tip in $_tdns_ips; do echo "server=${_tip}@${IFACE}"; done
                echo "# AWG_TUNNEL_DNS_END"
            } >> "$DNSMASQ_AWG_CONF"
            touch "$TUNNEL_DNS_FLAG"
            _tdns_on=1
            log_msg "Tunnel DNS: LAN resolves via ${_tdns_ips} through ${IFACE} (firmware upstreams off while VPN is up)"
        fi
    fi

    # SAFETY GATE: validate our generated geo conf in ISOLATION before dnsmasq is ever asked to
    # load it. A single directive dnsmasq rejects would make `service restart_dnsmasq` fail to
    # bring dnsmasq up at all — taking DNS/DHCP down for the whole LAN until the self-heal notices.
    # If invalid, log the exact dnsmasq error, keep the offending file as .bad for diagnosis, and
    # replace the live conf with a minimal valid one (filter-AAAA only) so domain routing is
    # dropped for this round while the resolver stays healthy. (Static GeoIP/CIDR routing via the
    # mangle ipsets is unaffected — it doesn't go through dnsmasq.)
    local _dconf_err
    if which dnsmasq >/dev/null 2>&1 && [ -s "$DNSMASQ_AWG_CONF" ]; then
        _dconf_err=$(dnsmasq --test --conf-file="$DNSMASQ_AWG_CONF" 2>&1)
        if [ $? -ne 0 ]; then
            log_msg "ERROR: generated geo dnsmasq config rejected by dnsmasq --test — domain routing disabled this round (DNS/DHCP preserved): $(echo "$_dconf_err" | tr '\n' ' ')"
            cp "$DNSMASQ_AWG_CONF" "${DNSMASQ_AWG_CONF}.bad" 2>/dev/null
            { echo "# AmneziaWG domain routing - DISABLED (config failed dnsmasq --test; kept as ${DNSMASQ_AWG_CONF}.bad)"
              [ "$want_aaaa" = 1 ] && echo "filter-AAAA"; } > "$DNSMASQ_AWG_CONF"
            # The replacement conf has no server=@awg0 lines — the flag MUST fall with them,
            # or the postconf hook would strip the firmware upstreams and leave dnsmasq with
            # no upstreams at all (dead LAN DNS).
            rm -f "$TUNNEL_DNS_FLAG"
            _tdns_on=0
        fi
    fi

    # Add conf-file include to dnsmasq (idempotent) — also when only filter-AAAA / tunnel-DNS is set
    if [ $domain_count -gt 0 ] || [ "$want_aaaa" = 1 ] || [ "$_tdns_on" = 1 ]; then
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
                    ip_rule_replace from "$dev_id" lookup main prio 97
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
                        ip_rule_replace from "$dev_id" lookup $RT_TABLE prio 99
                    fi
                    log_msg "Route: $dev_id ($name) -> VPN (all)"
                    ;;
                vpn_geo|vpn_geo_*)
                    # Per-device geo: include or exclude mode + optional exclusions (emit_geo_rules).
                    # Still marks 0x100 -> RT_TABLE (one tunnel). vpn_geo -> id 1, vpn_geo_<id> -> id.
                    local pgid _grc
                    pgid=$(geo_policy_of_ref "$policy")
                    if [ -n "$mac" ]; then
                        emit_geo_rules "$pgid" -m mac --mac-source "$mac"
                    else
                        emit_geo_rules "$pgid" -s "$dev_id"
                    fi
                    _grc=$?
                    if [ "$_grc" -eq 0 ]; then
                        has_geo=true
                        log_msg "Route: $dev_id ($name) -> VPN (geo $pgid, $(geo_mode "$pgid"))"
                    else
                        log_msg "WARNING: ipset $(geo_ipset "$pgid") missing/foreign, skipping geo policy $pgid for $dev_id ($name)"
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
        vpn_geo|vpn_geo_*)
            local dpgid
            dpgid=$(geo_policy_of_ref "$default_policy")
            if emit_geo_rules "$dpgid"; then
                has_geo=true
                log_msg "Default: geo $dpgid -> VPN ($(geo_mode "$dpgid"))"
            else
                log_msg "WARNING: ipset $(geo_ipset "$dpgid") missing, geo default policy not applied"
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
    ip_rule_replace fwmark "$FWMARK" lookup $RT_TABLE prio 98

    # --- Force DNS through dnsmasq whenever VPN is active ---
    # The global :53 DNAT + DoH/DoT REJECT is the one piece that collides with a co-resident
    # DPI-bypass / proxy tool (zapret/zapret2, xray/XRAYUI, v2ray, sing-box) and can lock out
    # the LAN. Skip it when the user opted out (awg_no_dns_intercept=1) OR when such a tool is
    # detected — geo-by-IP (GeoIP / antifilter CIDR) keeps working; only forced domain-geo is
    # weakened for clients that use an external resolver instead of the router. This is what
    # lets AWG coexist with xray/zapret. NOTE: this only resolves the DNS-layer clash — with
    # default_policy=vpn_all the marks/table still steal the proxy's traffic, so coexistence
    # also needs a direct/geo default policy, not all->VPN.
    # Decide whether the global :53 DNAT is wanted, but DON'T install it inline — defer it to
    # after dnsmasq is confirmed answering (the reload block below). Installing it here, before
    # reload_dnsmasq restarts dnsmasq, would DNAT all LAN DNS to a resolver that's bouncing →
    # every device loses DNS until the restart/retry loop settles (the "can't connect" hang).
    local _want_intercept=0 _fwdns=""
    if [ "$default_policy" != "direct" ] || [ "$has_geo" = true ]; then
        if [ "$(get_setting awg_no_dns_intercept)" = "1" ]; then
            log_msg "DNS interception OFF (awg_no_dns_intercept=1) — coexistence mode"
        elif zapret_active; then
            log_msg "DNS interception OFF — $(detect_dpi_tool) detected, coexisting (geo-by-IP still active)"
        elif fw_dns_redirect_active; then
            # Name the exact DNS owner + spell out the consequence for geo-by-domain, so the start
            # log alone explains "domains don't route" without any on-router commands.
            _fwdns=$(fw_dns_redirect_name)
            log_msg "DNS interception OFF — ${_fwdns} active, not overriding (geo-by-IP still active)"
            case "$_fwdns" in
                AdGuardHome*) log_msg "  note: AdGuardHome resolves clients directly — they bypass dnsmasq's ipset= directive, so geo-by-domain won't populate via dnsmasq; AGH has its own ipset feature (currently unconfigured — point it at the geo set to route domains)" ;;
                *DoT*)        log_msg "  note: DoT keeps dnsmasq as the resolver — geo-by-domain still populates for clients that use the router's DNS (not external DoH/DoT)" ;;
                *)            log_msg "  note: this redirects clients PAST dnsmasq — geo-by-domain will NOT populate unless firmware DNS is set to 'Router' (or interception is forced)" ;;
            esac
        else
            _want_intercept=1
        fi
    fi

    # Coexistence guard: a co-resident proxy/DPI tool + an "all -> VPN" policy is a config
    # footgun. NOTE the proxy's OWN egress is locally generated (OUTPUT/POSTROUTING) and is
    # NOT captured by our PREROUTING chain — but vpn_all does pull LAN forward-traffic into
    # the tunnel that a transparent-proxy setup may want for itself. Warn loudly (the status
    # JSON also exposes coexist_warn); we never silently override the user's chosen policy.
    local _dpi
    _dpi=$(detect_dpi_tool)
    if [ -n "$_dpi" ]; then
        log_msg "NOTE: co-resident DPI/proxy tool ($_dpi) shares router CPU/RAM with AWG geo ipset/dnsmasq — on low-RAM routers (<512MB) running both can exhaust memory (OOM) and hang the router"
        if [ "$default_policy" = "vpn_all" ] || get_setting awg_clients | grep -q vpn_all || any_exclude_mode; then
            log_msg "WARNING: $_dpi co-resident with an all->VPN / exclude-mode policy — the tunnel will capture most LAN traffic; use Direct or include-mode Geo to coexist"
        fi
    fi

    # Firmware VPN client (wgc*/VPN Fusion): its policy rules outrank ours (prio < 98), so a
    # connected client captures traffic BEFORE AmneziaWG's marking — and an enabled-but-idle
    # profile is the same trap waiting to spring. Named in the journal; the UI shows a banner
    # (status fields fwvpn_state/fwvpn_detail).
    local _fwvpn
    _fwvpn=$(fw_vpn_client_state 2>/dev/null)
    case "$_fwvpn" in
        active*)  log_msg "WARNING: firmware VPN client is routing traffic AHEAD of AmneziaWG (${_fwvpn#*|}) — its rule outranks ours (prio < 98); disable the firmware VPN client or unbind devices, or AWG policies won't apply" ;;
        enabled*) log_msg "NOTE: firmware VPN client profile enabled but not connected (${_fwvpn#*|}) — if it ever connects, its routing will outrank AmneziaWG's; disable the unused profile in the router's VPN UI" ;;
    esac

    # --- Reload dnsmasq if geo active (deferred + retried; see reload_dnsmasq) ---
    # When a reload runs, it installs the :53 DNAT itself AFTER dnsmasq is back up, so the DNAT
    # never points at a restarting resolver. When no reload is needed, dnsmasq is already
    # serving the current config, so install the DNAT inline.
    if [ $domain_count -gt 0 ] || [ "$has_geo" = true ] || [ "$want_aaaa" = 1 ] || [ "$_tdns_on" = 1 ]; then
        reload_dnsmasq "$_want_intercept"
    elif [ "$_want_intercept" = 1 ]; then
        setup_dns_interception
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
    [ -n "$awg_self" ] && ip_rule_replace from "$awg_self" lookup $RT_TABLE prio 100

    # --- Cron: optional geo auto-update + route self-heal watchdog. The watchdog is
    #     (re)added here so it survives firewall-restart/Apply — cleanup_firewall drops
    #     it, and previously it was only added in do_start and was silently lost ---
    if [ "$(get_setting awg_geo_autoupdate)" = "1" ]; then
        cru a awg_geo_update "0 4 * * * '$ADDON_DIR/amneziawg.sh' update_geo"
    fi
    cru a awg_watchdog "*/5 * * * * '$ADDON_DIR/amneziawg.sh' watchdog"
    # Background status refresh (every minute) so the UI peer table — handshake age and the
    # cumulative RX/TX counters — stays current WITHOUT a user action. The web page only re-reads
    # the static awg_status.htm; nothing else regenerated it between actions, so it used to freeze.
    # 'status' is read-only (awg show + file write), takes NO lock and triggers NO notify_rc, so
    # it's safe to run on a timer. Mirrors awg_watchdog's lifecycle exactly (cru is idempotent on
    # re-add, so firewall-restart/Apply won't duplicate it).
    cru a awg_status "*/1 * * * * '$ADDON_DIR/amneziawg.sh' status"

    # Re-assert the IPv6 leak block here (idempotent) so it survives a bare Apply
    # (awgsaveconf -> setup_firewall), which previously tore it down without re-adding it.
    setup_ipv6_block

    # Report the SAME metrics the UI's "Active (all policies)" row shows, via the shared helpers,
    # so log and UI can't diverge: IPs = live entries summed across every policy set; domains =
    # domain->set memberships (a domain shared by N policies counts N times — matches the UI's
    # per-tab sum). NOTE the IP count here is a build-time snapshot (sets were just rebuilt, so it's
    # ~static); the UI's IP count then grows as dnsmasq resolves domain rules and adds entries.
    log_msg "Firewall configured: $(geo_ipset_total) IPs, $(geo_domain_total) domains"
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
    dl_clear_failed   # explicit update = the user wants everything re-tried, incl. negative-cached lists
    if [ "$(get_setting awg_geo_wipe_update)" = "1" ]; then
        log_msg "Full geo refresh (wipe enabled): clearing old lists..."
        rm -rf "$GEO_DIR/geoip" "$GEO_DIR/domains" "$GEO_DIR/antifilter" 2>/dev/null
        rm -f "$GEO_DIR/v2fly_all.yml" "$GEO_DIR/v2fly_all.yml.tmp" "$GEO_DIR/v2fly_categories.txt" 2>/dev/null
    fi
    download_all_geo
}

# Is geo routing actually configured for ANY policy (so geo lists are worth downloading)?
geo_in_use(){
    case "$(get_setting awg_default_policy)" in *geo*) return 0 ;; esac
    case "$(get_setting awg_clients)" in *vpn_geo*) return 0 ;; esac
    local id
    for id in $(geo_ids); do
        [ -n "$(get_setting "$(geo_key "$id" v2fly)")$(get_setting "$(geo_key "$id" v2fly_ip)")$(get_setting "$(geo_key "$id" custom_domains)")$(get_setting "$(geo_key "$id" custom_ips)")$(get_setting "$(geo_key "$id" custom_files)")$(get_setting "$(geo_key "$id" custom_urls)")$(get_setting "$(geo_key "$id" antifilter_lists)")" ] && return 0
    done
    return 1
}

# Download geo lists if they are configured but missing on disk — e.g. wiped by an
# update (prerm removes /opt/amneziawg) or a service/category just added in the UI.
# Runs in the background so Apply/Force Apply/update return promptly; the log shows
# progress and setup_firewall is re-applied afterwards.
ensure_geo(){
    # Sync the shared pool to the UNION of all policies' selections (drop de-selected files),
    # and GC sets/files of deleted policies.
    prune_geoip
    prune_antifilter
    prune_custom_urls
    prune_orphan_policies
    geo_in_use || return 0
    # Collect ONLY what's missing across the union — adding one GeoIP service to one tab
    # shouldn't re-fetch the others or the big shared v2fly DB.
    local need=0 need_yml=0
    geo_any_pending && need=1
    [ -n "$(geo_union_geosite)" ] && [ ! -f "$GEO_DIR/v2fly_all.yml" ] && need_yml=1
    [ "$need" = 0 ] && [ "$need_yml" = 0 ] && return 0
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
        # Shared GeoSite DB first (one download feeds every policy's category extraction),
        # then the missing shared files across the union of all policies.
        [ "$need_yml" = 1 ] && download_geosite
        geo_fetch_missing
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
    # A loopback/unspecified endpoint is never a real VPN server, and it weaponizes the
    # endpoint host-route: setup adds `<endpoint> via <wan-gw>` and every cleanup deletes it,
    # and doing that against 127.0.0.0/8 broke WAN reachability outright on a 2.6.36 box
    # (2026-07, remote RT-AC68U — every start/stop re-broke it; power-cycles to recover).
    case "$host" in
        127.*|0.0.0.0|localhost)
            log_msg "ERROR: Endpoint host '$host' is loopback/unspecified — must be the VPN server's external address"
            return 1 ;;
    esac
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

# Sanity-check an AmneziaWG I1-I5 obfuscation param. Its grammar is a sequence of `<tag …>`
# tokens, so a value that contains any tag MUST start with '<', end with '>', and have matching
# bracket counts. The real-world failure was a TRUNCATED value that lost its closing '>'
# (`<b 0x…` with the tail cut by a storage cap or an incomplete paste) — which amneziawg-go then
# rejects with "failed to parse I1: missing enclosing >". Catch that here, BEFORE setconf, with a
# clear message. Conservative: only validates when a '<' is present (never blocks a tagless value).
validate_iparam(){
    local v="$1" op cl t
    case "$v" in *'<'*) ;; *) return 0 ;; esac
    op=$(printf '%s' "$v" | tr -cd '<' | wc -c | tr -d ' ')
    cl=$(printf '%s' "$v" | tr -cd '>' | wc -c | tr -d ' ')
    [ "$op" = "$cl" ] || return 1
    t=$(printf '%s' "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$t" in '<'*'>') return 0 ;; *) return 1 ;; esac
}

validate_ip(){
    echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || return 1
    return 0
}

# --- Generate awg0.conf ---

generate_config(){
    umask 077   # private key + config must not be world-readable
    mkdir -p "$AWG_DIR"

    # Neutral field names (see migrate_field_names): iface_p1 = interface private key,
    # peer_p1 = peer public key, peer_p2 = peer preshared key.
    local iface_p1=$(get_setting awg_iface_p1)
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

    # I1-I5 from base64-encoded setting. A long I-param's base64 exceeds the firmware's
    # ~3000-char-per-value custom_settings cap, so the UI splits it across awg_initdata +
    # awg_initdata1 + awg_initdata2 … — reassemble the chunks in order before decoding.
    local i1="" i2="" i3="" i4="" i5=""
    local initdata=$(get_setting awg_initdata)
    local _ic=1 _ichunk
    while [ "$_ic" -le 30 ]; do
        _ichunk=$(get_setting "awg_initdata${_ic}")
        [ -z "$_ichunk" ] && break
        initdata="${initdata}${_ichunk}"
        _ic=$((_ic + 1))
    done
    if [ -n "$initdata" ]; then
        local decoded
        decoded=$(echo "$initdata" | base64 -d 2>/dev/null)
        i1=$(echo "$decoded" | awk '/^I1 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i2=$(echo "$decoded" | awk '/^I2 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i3=$(echo "$decoded" | awk '/^I3 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i4=$(echo "$decoded" | awk '/^I4 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i5=$(echo "$decoded" | awk '/^I5 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
    fi

    local peer_p1=$(get_setting awg_peer_p1)
    local peer_p2=$(get_setting awg_peer_p2)
    local peer_endpoint=$(get_setting awg_peer_endpoint)
    local peer_allowedips=$(get_setting awg_peer_allowedips | sed 's/,[[:space:]]*$//;s/,/, /g')
    local peer_keepalive=$(get_setting awg_peer_keepalive)

    if [ -z "$iface_p1" ] || [ -z "$peer_p1" ] || [ -z "$peer_endpoint" ]; then
        log_msg "ERROR: Missing required config"
        return 1
    fi
    validate_wgkey "$iface_p1" || return 1
    validate_wgkey "$peer_p1" || return 1
    [ -n "$peer_p2" ] && { validate_wgkey "$peer_p2" || return 1; }
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
    # I1-I5: reject a truncated/malformed obfuscation tag (unbalanced <> / no closing '>') with a
    # named error instead of letting amneziawg-go fail setconf with a cryptic "Invalid argument".
    local _in _iv
    for _in in 1 2 3 4 5; do
        eval "_iv=\$i$_in"
        [ -n "$_iv" ] && { validate_iparam "$_iv" || { log_msg "ERROR: I$_in looks truncated/malformed (unbalanced <> or no closing '>') — re-import the config"; return 1; }; }
    done

    {
        echo "[Interface]"
        echo "PrivateKey = $iface_p1"
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
        echo "PublicKey = $peer_p1"
        [ -n "$peer_p2" ] && echo "PresharedKey = $peer_p2"
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

# Mask WireGuard secret values (private + preshared keys) from a config stream on stdin, so the
# dump is safe to paste into a chat/issue. Public keys, endpoint and obfuscation params are kept —
# they're needed to debug a setconf rejection and aren't secret.
redact_secrets(){
    sed -e 's/\(PrivateKey[[:space:]]*=[[:space:]]*\).*/\1<redacted>/' \
        -e 's/\(PresharedKey[[:space:]]*=[[:space:]]*\).*/\1<redacted>/'
}

# Last N lines of a file, indented, or a "(no <file>)" note. Usage: tail_clip <file> [lines]
tail_clip(){
    if [ -f "$1" ]; then
        tail -n "${2:-60}" "$1" 2>/dev/null | sed 's/^/  /'
    else
        echo "  (no $1)"
    fi
}

# One-shot debug dump: platform, CPU, installed package, binary architectures, live SIGILL
# probes, plus full system state (config/settings redacted, routing, dnsmasq, syslog, dmesg).
# Read-only — safe to run anytime. Usage: amneziawg.sh diag
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
    echo "--- shell / coreutils sanity ---"
    # A corrupted Entware (dying USB) shadows busybox grep/sed/awk with segfaulting binaries and
    # silently breaks every guard in this script — this section makes that visible in one look.
    echo "entware coreutils    : $([ "$AWG_PATH_SANE" = 0 ] && echo 'firmware busybox in use — /opt grep/sed/awk failed the addon self-test. The addon works FULLY this way; often just a lib-path/env quirk in the addon minimal env, NOT necessarily a bad USB. If /opt/bin/grep --version works over SSH, ignore it; suspect the Entware install/USB only if it also crashes in SSH. See the /opt/bin/grep probe below.' || echo 'OK')"
    echo "inherited LD_LIBRARY_PATH (httpd) : ${AWG_ORIG_LD_LIBRARY_PATH:-(empty — good)}"
    echo "PATH                 : $PATH"
    for _t in grep sed awk sort md5sum curl; do
        echo "  which $_t : $(which "$_t" 2>/dev/null || echo '(not found)')"
    done
    echo "  grep functional : $([ "$(echo probe 2>/dev/null | grep -c probe 2>/dev/null)" = "1" ] && echo yes || echo 'NO (segfault/broken!)')"
    echo "  sed functional  : $([ "$(echo probe 2>/dev/null | sed -n 's/probe/ok/p' 2>/dev/null)" = "ok" ] && echo yes || echo 'NO (broken!)')"
    echo "  awk functional  : $([ "$(echo probe 2>/dev/null | awk '{print "ok"}' 2>/dev/null)" = "ok" ] && echo yes || echo 'NO (broken!)')"
    # When the /opt coreutils failed the self-test, pin down WHY (diag runs on demand, so a
    # deliberate re-run of the possibly-crashing /opt/bin/grep is acceptable and itself telling):
    #   (a) default env works                  -> no real problem (the LD_LIBRARY_PATH unset fixed it)
    #   (b) only with LD_LIBRARY_PATH=/opt/lib  -> library-path quirk (NOT a bad USB)
    #   (c) only with /opt/etc/profile sourced  -> broader env quirk
    #   (none work / "Segmentation fault")      -> genuinely broken -> then check USB / reinstall
    if [ "$AWG_PATH_SANE" = 0 ] && [ -x /opt/bin/grep ]; then
        echo "  /opt/bin/grep (a) default env               : $(echo probe 2>/dev/null | /opt/bin/grep -c probe 2>&1 | head -1)   (expect 1)"
        echo "  /opt/bin/grep (b) +LD_LIBRARY_PATH=/opt/lib  : $(LD_LIBRARY_PATH=/opt/lib /opt/bin/grep --version 2>&1 | head -1)"
        echo "  /opt/bin/grep (c) +/opt/etc/profile sourced : $( ( . /opt/etc/profile >/dev/null 2>&1; echo probe | /opt/bin/grep -c probe ) 2>&1 | head -1 )   (expect 1)"
    fi
    echo "--- live probes (which binary raises Illegal instruction?) ---"
    probe_bin "amneziawg-go --version" "$AWG_GO" --version
    probe_bin "awg (usage)"            "$AWG_BIN"
    probe_bin "awg genkey (crypto)"    "$AWG_BIN" genkey
    echo "--- last amneziawg-go output (/tmp/awg_daemon.log) ---"
    [ -f /tmp/awg_daemon.log ] && sed 's/^/  /' /tmp/awg_daemon.log || echo "  (none)"
    echo "  last daemon exit (this launch): $(cat /tmp/awg_daemon.rc 2>/dev/null || echo '(none — daemon still running or never exited)')"
    echo "  Go runtime cap (computed now): GOMEMLIMIT=$(compute_go_memlimit) GOGC=$AWG_GOGC"
    grep -qiF 'out of memory' /tmp/awg_daemon.log 2>/dev/null && \
        echo "  >>> last daemon exit was a Go runtime OUT-OF-MEMORY: heap hit the ceiling under load (box low on RAM for this throughput) <<<"
    echo "--- runtime / network / TUN ---"
    echo "memory (free):"; free 2>/dev/null | sed 's/^/  /'
    echo "amneziawg-go running : $(pidof amneziawg-go 2>/dev/null || echo no)"
    echo "dnsmasq running      : $(pidof dnsmasq 2>/dev/null || echo no)"
    echo "--- persistent incident log (survives reboot; last LAN-critical events) ---"
    if [ -s "$AWG_INCIDENTS" ]; then sed 's/^/  /' "$AWG_INCIDENTS"; else echo "  (none — no auto-rollback / dnsmasq-down / damaged-binary incident recorded)"; fi
    echo "--- connection history (last 5: start_epoch|end_epoch|dur_s|reason) ---"
    if [ -s "$CONN_HISTORY" ]; then sed 's/^/  /' "$CONN_HISTORY"; else echo "  (none recorded yet)"; fi
    [ -f "$CONN_CURRENT" ] && echo "  open session (start_epoch start_uptime_s): $(cat "$CONN_CURRENT" 2>/dev/null)"
    echo "--- self-heal / background state ---"
    echo "awg crons (cru l):"
    _crons=$(cru l 2>/dev/null | grep -i awg)
    if [ -n "$_crons" ]; then echo "$_crons" | sed 's/^/  /'; else echo "  (NONE — watchdog/status cron not scheduled!)"; fi
    echo "watchdog last tick   : $([ -f /tmp/.awg_wd_beat ] && cat /tmp/.awg_wd_beat || echo '(never — cron not firing, or pre-1.2.31)')"
    echo "watchdog fail state  : $([ -f /tmp/.awg_wd_state ] && tr '\n' ' ' < /tmp/.awg_wd_state || echo none)"
    echo "locks (a DEAD holder = operation crashed mid-flight):"
    for _L in "$LOCKDIR" "$GEOLOCK" /tmp/.awg_dnsreload; do
        if [ -d "$_L" ]; then
            _lp2=$(cat "$_L/pid" 2>/dev/null)
            if [ -n "$_lp2" ] && kill -0 "$_lp2" 2>/dev/null; then echo "  $_L : held by pid $_lp2 (alive)"
            elif [ -n "$_lp2" ]; then echo "  $_L : held by pid $_lp2 (DEAD — stale lock!)"
            else echo "  $_L : held (no pid recorded)"; fi
        else
            echo "  $_L : free"
        fi
    done
    # Updater flags: a FRESH one during an update is normal; one older than ~15 min means the
    # updater died mid-flight (both self-reclaim on TTL, but show them so the window is visible).
    for _F in /tmp/.awg_no_autostart "$DNSRELOAD_DEFER" "$DNSRELOAD_PENDING"; do
        [ -f "$_F" ] && echo "updater flag: $_F ($([ -n "$(find "$_F" -mmin +15 2>/dev/null)" ] && echo 'STALE >15min — updater died?' || echo 'fresh'))"
    done
    echo "--- co-resident DPI / coexistence ---"
    _dpi_tool=$(detect_dpi_tool 2>/dev/null)
    echo "co-resident DPI tool : ${_dpi_tool:-none}"
    echo "b4 process           : $(pidof b4 >/dev/null 2>&1 && echo yes || echo no)"
    _b4_be=""
    if iptables-save 2>/dev/null | grep -q 'NFQUEUE'; then _b4_be="iptables"; fi
    if nft list ruleset 2>/dev/null | grep -qE 'queue (num|to)'; then _b4_be="${_b4_be:+$_b4_be+}nft"; fi
    echo "NFQUEUE backend seen : ${_b4_be:-none}"
    echo "compat (no DNS hijack): $([ "$(get_setting awg_no_dns_intercept)" = "1" ] && echo "ON (coexist)" || echo off)"
    echo "kernel / sendmmsg    : $(uname -r) -> $(kernel_pre_sendmmsg && echo 'PRE-3.0: no sendmmsg — daemon CANNOT send packets, tunnel never passes traffic (needs patched daemon); start refused' || echo 'ok (>=3.0)')"
    echo "Broadcom CTF (HW-NAT) : $(grep -q '^ctf ' /proc/modules 2>/dev/null && echo "module loaded" || echo "no module") ctf_disable=$(nvram get ctf_disable 2>/dev/null) force=$(nvram get ctf_disable_force 2>/dev/null) -> $(ctf_active && echo 'ACTIVE (BLOCKS tunnel start — disable + reboot)' || echo 'not blocking')"
    echo "conntrack count/max  : $(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo '?')/$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo '?')"
    echo "ip rule fwmark 0x100 :"; ip rule show 2>/dev/null | grep -i 'fwmark 0x100' | sed 's/^/  /'
    echo "lan_ipaddr           : $(nvram get lan_ipaddr 2>/dev/null)"
    echo "--- firmware VPN client (wgc / VPN Fusion) ---"
    echo "wgc profiles         : $(nvram show 2>/dev/null | grep -E '^wgc[0-9]*_enable=' | tr '\n' ' ')"
    _fwv_diag=$(fw_vpn_client_state 2>/dev/null)
    echo "verdict              : ${_fwv_diag:-none (no enabled profiles, no preempting from-all rules)}"
    echo "preempting rules (prio 1-96, the ones that outrank our prio-98 mark rule):"
    ip rule show 2>/dev/null | awk -F: '$1+0>0 && $1+0<97 {print "  "$0}'
    # Interface detection cross-check: /sys/class/net is the kernel's ground truth (what
    # is_running/wait_for_iface now read); `ip link show` is shown alongside so a divergence
    # (device present in /sys but `ip` says "does not exist") pinpoints a broken/mismatched
    # iproute2 — the RT-AC68U/2.6.36 failure where a live awg0 was killed as "not created".
    echo "iface detect (awg0)  : /sys/class/net=$([ -e /sys/class/net/$IFACE ] && echo present || echo absent) proc-net-dev=$(grep -qE "^[[:space:]]*$IFACE:" /proc/net/dev 2>/dev/null && echo yes || echo no) iface_exists=$(iface_exists "$IFACE" && echo yes || echo no)"
    echo "ip binaries          :"
    for _ipb in /opt/sbin/ip /opt/bin/ip /usr/sbin/ip /sbin/ip; do
        [ -x "$_ipb" ] && echo "  $_ipb : $("$_ipb" -V 2>&1 | head -1)"
    done
    echo "  ip resolved to     : $(which ip 2>/dev/null)"
    echo "awg0 link (ip)       :"; ip link show "$IFACE" 2>&1 | sed 's/^/  /'
    echo "awg0 inet            : $(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}')"
    echo "tun module loaded    : $(lsmod 2>/dev/null | grep -q '^tun ' && echo yes || echo no)"
    echo "modprobe tun         : $(modprobe tun 2>&1; echo rc=$?)"
    echo "/dev/net/tun         :"; ls -la /dev/net/tun 2>&1 | sed 's/^/  /'
    echo "--- firmware / model ---"
    echo "model            : $(nvram get productid 2>/dev/null) (odm $(nvram get odmpid 2>/dev/null))"
    echo "firmware         : $(nvram get firmver 2>/dev/null).$(nvram get buildno 2>/dev/null)_$(nvram get extendno 2>/dev/null)"
    echo "uptime/load      : $(uptime 2>/dev/null || cat /proc/loadavg 2>/dev/null)"
    echo "native WireGuard : $(nvram show 2>/dev/null | grep -E '^(wgs|wgc[0-9]*)_enable=' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    echo "disk (jffs/opt/tmp):"; df -h /jffs /opt /tmp 2>/dev/null | sed 's/^/  /'
    echo "--- generated config ($CONF, secrets redacted) ---"
    if [ -f "$CONF" ]; then redact_secrets < "$CONF" | sed 's/^/  /'; else echo "  (no config generated yet)"; fi
    echo "--- awg settings (custom_settings, secrets redacted) ---"
    if [ -f "$SETTINGS" ]; then
        grep '^awg_' "$SETTINGS" 2>/dev/null | awk '{k=$1; if(k ~ /^awg_iface_p1/||k ~ /^awg_peer_p2/||k ~ /priv/||k ~ /psk/||k ~ /preshar/||k ~ /secret/){print k" <redacted>"}else{print}}' | head -120 | sed 's/^/  /'
    else echo "  (no $SETTINGS)"; fi
    echo "--- awg show (live UAPI state, no secrets) ---"
    if pidof amneziawg-go >/dev/null 2>&1; then "$AWG_BIN" show "$IFACE" 2>&1 | sed 's/^/  /'; else echo "  (daemon not running)"; fi
    echo "--- routing (rule / table $RT_TABLE / fwmark marks) ---"
    echo "ip rule:"; ip rule show 2>/dev/null | sed 's/^/  /'
    echo "ip route table $RT_TABLE:"; ip route show table "$RT_TABLE" 2>/dev/null | sed 's/^/  /'
    echo "mangle marks:"; iptables -t mangle -S 2>/dev/null | grep -iE 'awg|0x100|MARK' | head -30 | sed 's/^/  /'
    echo "rule copy counts (running tunnel expects TCPMSS=2, ACCEPT/MASQ=1 each; more = duplicates):"
    echo "  TCPMSS clamp   : $(iptables -t mangle -S FORWARD 2>/dev/null | grep -c TCPMSS)"
    echo "  INPUT accept   : $(iptables -S INPUT 2>/dev/null | grep -c -- "-i $IFACE -j ACCEPT")"
    echo "  MASQUERADE     : $(iptables -t nat -S POSTROUTING 2>/dev/null | grep -c -- "-o $IFACE -j MASQUERADE")"
    echo "geo ipsets (per policy):"
    for _dgid in $(geo_ids); do
        _ds=$(geo_ipset "$_dgid")
        _di=$(ipset list "$_ds" -t 2>/dev/null | grep -E 'Number of entries|Size in memory' | tr '\n' ';' | tr -s ' ')
        echo "  policy $_dgid ($_ds): ${_di:-(missing)}"
    done
    echo "--- dnsmasq ---"
    echo "args   : $(tr '\0' ' ' < /proc/$(pidof dnsmasq 2>/dev/null | awk '{print $1}')/cmdline 2>/dev/null)"
    echo "conf.add (our block):"
    if [ -f /jffs/configs/dnsmasq.conf.add ]; then
        grep -nE 'AmneziaWG|amneziawg|awg' /jffs/configs/dnsmasq.conf.add 2>/dev/null | head -30 | sed 's/^/  /'
    else echo "  (no dnsmasq.conf.add)"; fi
    echo "tunnel DNS           : $([ -f "$TUNNEL_DNS_FLAG" ] && echo "ACTIVE — $(grep -c "^server=.*@$IFACE" "$DNSMASQ_AWG_CONF" 2>/dev/null) server(s) via $IFACE, firmware upstreams stripped by postconf" || echo "off")"
    echo "postconf hook        : $(grep -c amneziawg /jffs/scripts/dnsmasq.postconf 2>/dev/null || echo 0) line(s)"
    # Dangling-include check: our conf-file= is in the firmware-owned conf.add but points at /opt
    # (removable USB). If the include is present while the target is MISSING, firmware dnsmasq
    # fatally fails to start (LAN-wide DNS/DHCP loss) — the postconf guard above neutralizes it,
    # but flag the condition here so a bricked-DNS report is instantly recognizable.
    if grep -q "conf-file=$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null && [ ! -f "$DNSMASQ_AWG_CONF" ]; then
        echo "  DANGLING INCLUDE     : conf-file present but $DNSMASQ_AWG_CONF MISSING (/opt unmounted?) — would brick dnsmasq without the postconf guard"
    fi
    echo "--- processes (vpn / dpi / dns) ---"
    ps 2>/dev/null | grep -iE 'amneziawg|awg0| awg |dnsmasq|xray|zapret|/b4| b4 |adguard|tpws|nfqws' | grep -v grep | head -25 | sed 's/^/  /'
    echo "--- system log: awg / tun / OOM / segfault (filtered) ---"
    { cat /tmp/syslog.log-1 /tmp/syslog.log; } 2>/dev/null | grep -iE 'amneziawg|awg0| awg |wireguard|tun[0-9 ]|out of memory|oom-killer|segfault|illegal instruction|traps:' | tail -50 | sed 's/^/  /'
    echo "--- system log (/tmp/syslog.log, last 60 lines) ---"
    tail_clip /tmp/syslog.log 60
    echo "--- dmesg (kernel ring, last 60 lines) ---"
    dmesg 2>/dev/null | tail -60 | sed 's/^/  /' || echo "  (dmesg unavailable)"
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
        echo "$(date '+%Y-%m-%d %H:%M:%S') DEADMAN: dnsmasq down, rolling back to restore LAN access" >> "$UI_LOG" 2>/dev/null
        awg_incident "DEADMAN: dnsmasq still down ~90s after start — auto-rolling back VPN (LAN DNS/DHCP was lost)"
        # Auto-rollback (NOT a user stop) — keep the watchdog cron so recovery can continue.
        "$ADDON_DIR/amneziawg.sh" stop_auto >/dev/null 2>&1
        # Bounce dnsmasq only if it's actually still dead (do_stop's reload_dnsmasq may have
        # already revived it) — avoids fighting an in-flight reload.
        pidof dnsmasq >/dev/null 2>&1 || service restart_dnsmasq >/dev/null 2>&1
    ) </dev/null >/dev/null 2>&1 &
}

# GOGC for the daemon: lower than Go's default 100, so the heap is collected after +50%
# growth rather than +100% — a smaller sawtooth leaves more absolute headroom before a
# burst can outrun the collector on a RAM-starved box. Paired with GOMEMLIMIT below.
AWG_GOGC=50
# The soft heap ceiling is the LARGER of two bases (see compute_go_memlimit): a STABLE
# fraction of TOTAL RAM, and a fraction of what's AVAILABLE right now. Taking the max means
# a transiently-starved launch window can't depress it below the daemon's own working set.
AWG_GOMEMLIMIT_TOTAL_PCT=38   # stable floor from MemTotal (survives churn)
AWG_GOMEMLIMIT_AVAIL_PCT=60   # opportunistic ceiling from MemAvailable when the box is roomy

# Compute a GOMEMLIMIT for amneziawg-go as an integer MiB clamped to [96, 448].
# Empty output (parse failure) => launch_daemon leaves the env unset (behaviour as before).
#
# WHY THIS EXISTS: amneziawg-go inherits wireguard-go's message-buffer pool, which is
# UNBOUNDED (`const PreallocatedBuffersPerPool = 0` — literally "allow infinite memory
# growth"), buffers are 64KB (`MaxSegmentSize`), and the inbound/outbound queues are 1024
# deep. Under heavy traffic the receive routine pulls 64KB buffers faster than the (slow,
# software-crypto) consumer drains them; with Go's default GOGC=100 the heap is allowed to
# DOUBLE before a GC, so on a 32-bit low-RAM router the kernel refuses the next heap-arena
# page and the runtime aborts the WHOLE daemon with `fatal error: runtime: out of memory`
# (rc=2); the watchdog then crash-loops it — the tunnel "collapses under serious load"
# while a chat app never trips it. Field: RT-AX82U, 512MB (v1.2.45/1.2.47 diags). NB a
# GENUINE Go-runtime OOM — NOT the 1.2.42 dangling-dnsmasq-conf LAN brick.
#
# GOMEMLIMIT is a SOFT limit and only reclaims the pool's IDLE buffers (ordinary GC garbage).
# It CANNOT reclaim buffers still queued in the 1024-deep inbound path — field-confirmed on a
# settled box with the correct 190MiB ceiling (still OOM'd ~4 min into video). The REAL cure
# shipped in 1.2.50: release.yml builds the daemon with PreallocatedBuffersPerPool = 1024
# (upstream's own iOS/Windows memory-constrained profile) — the pool caps at ~64MB and the
# receiver BLOCKS when it's full (true backpressure), so the daemon can't eat itself. This env
# stays as belt-and-suspenders for the rest of the heap. Degrades gracefully (Go bounds GC at
# 50% CPU), never worse than unbounded. Works on the legacy Go-1.23 daemon too (Go >= 1.19).
#
# EARLIER BUG (1.2.47): the ceiling was 55% of MemAvailable *at launch only*. A daemon that
# (re)started during post-update churn — geo re-download + repeated dnsmasq reloads — read a
# transiently low MemAvailable and got a 110MiB ceiling BELOW its own working set, guaranteeing
# the OOM. Now the MemTotal floor keeps it stable across such windows.
compute_go_memlimit(){
    _total_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    _avail_kb=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    [ -z "$_avail_kb" ] && _avail_kb=$(awk '/^MemFree:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    # Take the LARGER of the stable MemTotal-based floor and the opportunistic MemAvailable
    # ceiling, so a transiently-starved launch (post-update churn) can't set it too low.
    _lim_mib=0
    case "$_total_kb" in ''|*[!0-9]*) : ;; *) _t=$(( _total_kb * AWG_GOMEMLIMIT_TOTAL_PCT / 100 / 1024 )); [ "$_t" -gt "$_lim_mib" ] && _lim_mib=$_t ;; esac
    case "$_avail_kb" in ''|*[!0-9]*) : ;; *) _a=$(( _avail_kb * AWG_GOMEMLIMIT_AVAIL_PCT / 100 / 1024 )); [ "$_a" -gt "$_lim_mib" ] && _lim_mib=$_a ;; esac
    [ "$_lim_mib" -le 0 ] && return 0
    [ "$_lim_mib" -lt 96 ]  && _lim_mib=96
    [ "$_lim_mib" -gt 448 ] && _lim_mib=448
    printf '%dMiB' "$_lim_mib"
}

# Launch amneziawg-go detached, stdout+stderr into /tmp/awg_daemon.log and — critically — its
# EXIT STATUS appended as a final "[daemon exited rc=N]" line. A daemon that dies WITHOUT
# printing anything (SIGILL/SIGSEGV, or a Go runtime that just aborts on an unsupported ancient
# kernel — RT-AC68U's 2.6.36 is below Go 1.24's Linux 3.2 floor) used to be indistinguishable
# from a hang; the rc line names it (132=SIGILL, 139=SIGSEGV, plain N = clean error exit).
# $1 = optional LOG_LEVEL (e.g. "verbose").
launch_daemon(){
    # Exit status goes to a PER-LAUNCH file (/tmp/awg_daemon.rc, truncated here): parsing the
    # rc out of awg_daemon.log was ambiguous during restarts — the PREVIOUS daemon's wrapper
    # could append its "[daemon exited rc=0]" a beat after this launch truncated the log, and
    # a later create-failure would then misreport a stale rc for a daemon that actually hung.
    # The log line stays for humans; code reads the rc file.
    rm -f /tmp/awg_daemon.rc 2>/dev/null
    # Soft heap ceiling for the Go runtime (see compute_go_memlimit): caps the unbounded
    # message-buffer pool so a heavy inbound burst can't drive the daemon into
    # `fatal error: runtime: out of memory` and crash-loop the tunnel on a low-RAM box.
    # Exported INSIDE the subshell (not as a literal prefix) so it never leaks to the
    # parent and so an empty value simply leaves the env untouched.
    _glim=$(compute_go_memlimit)
    # WG_PROCESS_FOREGROUND=1: without it amneziawg-go DAEMONIZES — the process we launch is
    # only a short-lived parent that forks the real daemon and exits 0 once the device is up.
    # The wrapper then recorded THAT exit ("[daemon exited rc=0]" on every successful start —
    # live-confirmed), and a crash of the forked child would surface as the parent's generic
    # rc=1 instead of the real signal (SIGSEGV=139 — the RT-AC68U telemetry this exists for).
    # Foreground keeps the daemon as our direct child, so rc below is the DAEMON's real exit.
    # NB: an expanded word is never parsed as an assignment prefix, so the env vars are set via
    # literal prefixes in explicit branches (not `${1:+LOG_LEVEL=$1} cmd`).
    if [ -n "$1" ]; then
        ( [ -n "$_glim" ] && export GOMEMLIMIT="$_glim" GOGC="$AWG_GOGC"
          WG_PROCESS_FOREGROUND=1 LOG_LEVEL="$1" "$AWG_GO" "$IFACE" > /tmp/awg_daemon.log 2>&1
          _rc=$?
          echo "rc=$_rc at $(date '+%H:%M:%S')" > /tmp/awg_daemon.rc
          echo "[daemon exited rc=$_rc at $(date '+%H:%M:%S')]" >> /tmp/awg_daemon.log
          record_daemon_oom "$_rc" "$_glim" ) &
    else
        ( [ -n "$_glim" ] && export GOMEMLIMIT="$_glim" GOGC="$AWG_GOGC"
          WG_PROCESS_FOREGROUND=1 "$AWG_GO" "$IFACE" > /tmp/awg_daemon.log 2>&1
          _rc=$?
          echo "rc=$_rc at $(date '+%H:%M:%S')" > /tmp/awg_daemon.rc
          echo "[daemon exited rc=$_rc at $(date '+%H:%M:%S')]" >> /tmp/awg_daemon.log
          record_daemon_oom "$_rc" "$_glim" ) &
    fi
}

# Called from the launch wrapper after the daemon exits: if it aborted with a Go-runtime
# out-of-memory (heavy-load heap blowout), drop a persistent breadcrumb so the cause is
# still visible in the diag after the watchdog restarts it and after a reboot (RAM logs
# don't survive). Gated on the exact `out of memory` string, which ONLY the Go runtime's
# fatal-OOM prints — an intentional kill (SIGTERM/SIGKILL on stop/restart) never matches,
# so this can't false-fire on a normal teardown.
record_daemon_oom(){
    if grep -qiF 'out of memory' /tmp/awg_daemon.log 2>/dev/null; then
        # The Go runtime's OWN fatal-OOM (heap-commit refused). rc is typically 2.
        awg_incident "amneziawg-go OOM-crashed (rc=${1:-?}) — Go heap hit its ceiling under load (GOMEMLIMIT=${2:-unset}); box is low on RAM for this throughput"
    elif [ "${1:-}" = 137 ] && dmesg 2>/dev/null | grep -iE 'killed process|out of memory' | grep -qi 'amneziawg-go'; then
        # rc=137 = 128+SIGKILL. That's ALSO how do_stop/do_start's `kill -9` fallback exits
        # the daemon, so rc alone must NOT be trusted — only record when the kernel log shows
        # the OOM-KILLER named amneziawg-go (a box-wide-pressure kill, a DIFFERENT OOM than the
        # Go-runtime one above and invisible in the daemon's own log). Without that corroboration
        # a plain forced teardown would false-flag an incident. This catches the failure mode
        # GOMEMLIMIT can shift residual crashes toward (per-daemon cap holds, box still starves).
        awg_incident "amneziawg-go killed by the KERNEL oom-killer (rc=137) under box-wide memory pressure — not a Go-runtime OOM; free RAM / reduce co-resident load (GOMEMLIMIT=${2:-unset})"
    fi
}

# Daemon log minus the harmless wireguard-go "kernel has first class support" banner box, so
# error paths quote the ACTUAL failure lines instead of 10 lines of box-drawing. $1 = max lines.
daemon_log_gist(){
    grep -av '─\|│\|┌\|└\|first class support\|amneziawg-linux-kernel-module' /tmp/awg_daemon.log 2>/dev/null \
        | grep -v '^[[:space:]]*$' | tail -n "${1:-6}"
}

# --- Connection uptime & history (последние 5 сессий для UI) ---
# conn_current holds the OPEN session ("<start_epoch> <uptime_s_at_start> <boot_id>");
# conn_history the closed ones. Duration is measured as a /proc/uptime DELTA (monotonic) so the
# NTP step at early boot can't skew it — the wall epoch is carried only for display. Reasons are
# machine tokens (user/restart/rollback/watchdog/update/deadman/reboot/interrupted/auto); the
# page localizes known ones and shows unknown ones as-is.

# Seconds since boot (integer). Empty output if /proc/uptime is unreadable — callers must treat
# non-numeric as "unknown" (every arithmetic test below is 2>/dev/null-guarded for that).
sys_uptime_s(){
    local _u _r
    read _u _r < /proc/uptime 2>/dev/null
    echo "${_u%%.*}"
}

# Kernel boot id (uuid, regenerated each boot; present on every kernel in the fleet incl.
# 2.6.36). Empty if unreadable — callers fall back to the uptime-comparison heuristic.
sys_boot_id(){
    cat /proc/sys/kernel/random/boot_id 2>/dev/null
}

# Append one CLOSED session, keeping only the last 5 lines (atomic temp+rename, like the other
# small state files). Args: start_epoch end_epoch dur_s reason.
conn_history_append(){
    local _t="${CONN_HISTORY}.$$"
    { tail -n 4 "$CONN_HISTORY" 2>/dev/null; echo "$1|$2|$3|$4"; } > "$_t" 2>/dev/null \
        && mv -f "$_t" "$CONN_HISTORY" 2>/dev/null
    rm -f "$_t" 2>/dev/null
}

# Close a session the previous run left OPEN (no clean do_stop ever ran): the box rebooted
# mid-session (boot id changed — exact; uptime-went-backwards as the fallback signal) or the
# stop path crashed within the same boot. End time and duration are unknowable — recorded as
# 0/-1, shown as "—" by the UI. NB: `read a b c` puts the REST of the line into the last var,
# so every reader takes a trailing slot for the boot id.
conn_close_stale(){
    [ -f "$CONN_CURRENT" ] || return 0
    local _se _su _sb _nu _nb _r="interrupted"
    read _se _su _sb < "$CONN_CURRENT" 2>/dev/null
    rm -f "$CONN_CURRENT"
    case "$_se" in ''|*[!0-9]*) return 0 ;; esac
    _nu=$(sys_uptime_s)
    _nb=$(sys_boot_id)
    if [ -n "$_sb" ] && [ -n "$_nb" ]; then
        [ "$_sb" != "$_nb" ] && _r="reboot"
    elif [ -n "$_su" ] && [ -n "$_nu" ] && [ "$_su" -gt "$_nu" ] 2>/dev/null; then
        _r="reboot"
    fi
    conn_history_append "$_se" 0 -1 "$_r"
}

# Mark the session OPEN — called at the single point in do_start where the tunnel is actually up.
conn_record_start(){
    conn_close_stale
    echo "$(date +%s) $(sys_uptime_s) $(sys_boot_id)" > "$CONN_CURRENT" 2>/dev/null
}

# Put back the history stashed by finalize_ipk_install across the package prerm's rm -rf of
# /opt/amneziawg (same idea as the geo backup). Safe no-op when no stash exists; never
# overwrites a history file that already exists.
conn_history_restore(){
    [ -f "$CONN_HIST_BAK" ] || return 0
    mkdir -p "$AWG_DIR" 2>/dev/null
    [ -f "$CONN_HISTORY" ] || mv -f "$CONN_HIST_BAK" "$CONN_HISTORY" 2>/dev/null
    rm -f "$CONN_HIST_BAK" 2>/dev/null
}

# Close the OPEN session into history. $1 = reason token; anything the page doesn't know is
# displayed as-is, so new tokens are safe to add. No-op when no session is open (double stop,
# stop of a tunnel that predates this version).
conn_record_stop(){
    [ -f "$CONN_CURRENT" ] || return 0
    local _se _su _sb _nu _dur
    read _se _su _sb < "$CONN_CURRENT" 2>/dev/null
    rm -f "$CONN_CURRENT"
    case "$_se" in ''|*[!0-9]*) return 0 ;; esac
    _nu=$(sys_uptime_s)
    if [ -n "$_su" ] && [ -n "$_nu" ] && [ "$_nu" -ge "$_su" ] 2>/dev/null; then
        _dur=$((_nu - _su))                     # monotonic — immune to NTP stepping the clock
    else
        _dur=$(( $(date +%s) - _se )); [ "$_dur" -ge 0 ] || _dur=-1
    fi
    conn_history_append "$_se" "$(date +%s)" "$_dur" "${1:-auto}"
}

# --- Start ---

# Boot-time entry (the .ipk's S99amneziawg init: rc.unslung at Entware start, plus opkg's
# auto-invocation of the init script on package install). Honors the UI toggle «Автозапуск
# после перезагрузки» (awg_autostart; absent/1 = start — the pre-1.2.52 behavior). A SEPARATE
# command from `start` on purpose: the UI button, `amneziawg.sh start` and the watchdog of a
# running tunnel stay unconditional — the toggle only decides whether the tunnel comes up BY
# ITSELF. (The watchdog cron doesn't survive a reboot and is only installed by do_start, so
# with autostart off nothing else will start the tunnel; do_firewall_restart/do_wan_event are
# is_running-gated.)
do_boot_start(){
    # is_running guard: with the tunnel already up, fall through to do_start's own
    # "Already running" no-op — a second `S99amneziawg start` must not claim it skipped.
    if ! is_running && [ "$(get_setting awg_autostart)" = "0" ]; then
        # logger + UI journal so "why is the VPN down after reboot" is answerable from diag;
        # echo for whoever runs `S99amneziawg start` from an interactive shell.
        log_msg "Autostart is off (awg_autostart=0) — tunnel left stopped after boot. Start it from the web UI or: $ADDON_DIR/amneziawg.sh start"
        echo "AmneziaWG: autostart is disabled in the web UI settings — tunnel not started."
        echo "  Manual start: $ADDON_DIR/amneziawg.sh start (or the web UI button)"
        update_status
        return 0
    fi
    do_start
}

do_start(){
    # Skip if update in progress (opkg triggers S99amneziawg start)
    [ -f /tmp/.awg_no_autostart ] && { log_msg "Start blocked: update in progress"; return 0; }

    if is_running; then
        log_msg "Already running"
        update_status
        return 0
    fi

    # Unsupported-kernel guard (see kernel_pre_sendmmsg): on Linux < 3.0 the daemon can't send a
    # single UDP packet (sendmmsg ENOSYS), so the tunnel can NEVER pass traffic — and starting it
    # only destabilises the box. Refuse up front with a clear reason; status kernel_unsup drives a
    # page banner. Checked BEFORE the CTF guard because it's the deeper blocker (on these boxes
    # disabling CTF wouldn't help). Removed once the daemon carries a sendmmsg fallback.
    if kernel_pre_sendmmsg; then
        log_msg "ERROR: kernel $(uname -r) (Linux 2.6.x) — AmneziaWG is not usable on this old kernel. The daemon's packet-send fix shipped (1.2.58), but bringing up the VPN's policy routing destabilises the router's own network (WAN drops) on this kernel. Refusing to start to protect the router. This is a kernel limitation, not a config issue."
        awg_incident "Unsupported kernel $(uname -r): policy-routing bring-up destabilises WAN on 2.6.x — refused start to protect the router"
        update_status
        return 1
    fi

    # Broadcom CTF guard (see ctf_active): on a CTF-accelerated box, standing up our policy
    # routing hangs the kernel and the hardware watchdog reboots the router. Refuse to start —
    # from EVERY path that reaches here (boot autostart, UI, watchdog) — until CTF is disabled.
    # The page shows a banner with a one-click "disable CTF + reboot"; the status ctf_block flag
    # drives it. Placed before STARTING_FLAG so the UI never even flashes "Connecting".
    if ctf_active; then
        log_msg "ERROR: Broadcom CTF (hardware NAT acceleration) is ON — starting the policy-routed tunnel would hang the router and force a watchdog reboot. Disable CTF (nvram ctf_disable=1) and reboot; the web UI has a one-click button. Start aborted."
        awg_incident "CTF enabled — refused tunnel start to avoid a kernel hang/reboot (disable CTF + reboot first)"
        update_status
        return 1
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

    # Optional pre-start delay + AdGuardHome-readiness wait. Out of the box the delay is 0 (start
    # immediately, as before) and is settable from the UI (awg_start_delay, 0-300s). On AGH boxes
    # the geo-by-domain ipset bridge is (re)built by AMAGHI's collector when we restart dnsmasq
    # below, so awg_wait_for_agh holds until AGH is actually up on :53 — deterministic ordering
    # instead of a fixed guess. Both are no-ops by default / when AGH is already up, so manual
    # starts and watchdog auto-recovery aren't slowed.
    local _start_delay
    _start_delay=$(get_setting awg_start_delay)
    { [ -n "$_start_delay" ] && validate_uint "$_start_delay" && [ "$_start_delay" -le 300 ]; } || _start_delay=0
    [ "$_start_delay" -gt 0 ] && { log_msg "Pre-start delay: ${_start_delay}s"; sleep "$_start_delay"; }
    [ "$(get_setting awg_wait_for_agh)" = "1" ] && agh_present && wait_for_agh 60

    acquire_lock || { log_msg "Cannot acquire lock, aborting start"; update_status; return 1; }

    # Re-check under the lock: the is_running test at the top ran BEFORE the (up to 30s) lock
    # wait, so a second queued start (double service event, watchdog racing a user click) used
    # to arrive here with the tunnel ALREADY up — kill the live daemon as "stale", re-launch it
    # and append a duplicate set of INPUT/FORWARD/TCPMSS/MASQUERADE rules (each stop removes
    # only one copy → they accumulated; 9x TCPMSS pairs seen in a field report).
    if is_running; then
        log_msg "Already running (a concurrent start finished first) — nothing to do"
        release_lock
        return 0
    fi

    generate_config || { update_status; release_lock; return 1; }
    [ ! -f "$CONF" ] && { log_msg "ERROR: No config"; update_status; release_lock; return 1; }
    # Both userspace binaries must EXIST and be NON-EMPTY before we launch anything.
    # An interrupted opkg update on a low-RAM box (power-cycle mid-write, then an e2fsck
    # truncation on the next boot) or a failing USB drive can leave amneziawg-go / awg as
    # 0-byte files (field-confirmed on RT-AC68U). The daemon then "exits rc=0" and awg0 never
    # appears, surfacing downstream as a baffling "failed to create interface". Name the real
    # cause + the fix here instead of launching an empty binary. No opkg is invoked from the
    # start path (deliberately — running opkg mid-start on a memory-pressured box is the very
    # hazard that caused this).
    local _b _b_bad=""
    for _b in "$AWG_GO" "$AWG_BIN"; do
        if [ ! -f "$_b" ]; then
            _b_bad="$_b_bad $_b(missing)"
        elif [ ! -s "$_b" ]; then
            _b_bad="$_b_bad $_b(0 bytes)"
        elif [ ! -x "$_b" ]; then
            chmod +x "$_b" 2>/dev/null
            [ -x "$_b" ] || _b_bad="$_b_bad $_b(not executable)"
        fi
    done
    if [ -n "$_b_bad" ]; then
        log_msg "ERROR: userspace binaries are damaged:$_b_bad"
        awg_incident "start aborted: userspace binaries damaged (${_b_bad# }) — interrupted update / failing USB; reinstall needed"
        log_msg "  sizes: amneziawg-go=$(elf_arch "$AWG_GO") awg=$(elf_arch "$AWG_BIN")"
        log_msg "  Likely an interrupted update or a failing USB drive left them truncated to 0"
        log_msg "  bytes (e.g. a power-cycle mid-opkg + e2fsck). Fix: reinstall the package —"
        log_msg "    curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh"
        log_msg "  or, if you kept the .ipk: opkg install --force-reinstall <pkg>.ipk"
        update_status; release_lock; return 1
    fi

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
    log_msg "Go runtime cap: GOMEMLIMIT=$(compute_go_memlimit) GOGC=$AWG_GOGC (bounds heap growth under load — prevents daemon OOM on low-RAM boxes)"
    launch_daemon
    if ! wait_for_iface "$IFACE" 10; then
        # Name the failure mode from the captured exit status: a SILENT death (banner only, no
        # error line — the RT-AC68U/kernel-2.6.36 signature) vs a clean error exit vs a hang.
        local drc dgist
        drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' /tmp/awg_daemon.rc 2>/dev/null)
        log_msg "ERROR: amneziawg-go failed to create interface"
        case "$drc" in
            "")  log_msg "  daemon is still running but $IFACE never appeared after 10s (hung in TUN create?)" ;;
            132) log_msg "  daemon exited rc=132 (SIGILL — this CPU can't run this build)" ;;
            139) log_msg "  daemon exited rc=139 (SIGSEGV — daemon crashed; on kernels older than 3.2 (e.g. RT-AC68U 2.6.36) the Go runtime is unsupported and dies like this)" ;;
            *)   if grep -qiF 'out of memory' /tmp/awg_daemon.log 2>/dev/null; then
                     log_msg "  daemon exited rc=$drc (Go runtime OUT OF MEMORY — box too low on RAM even with GOMEMLIMIT=$(compute_go_memlimit); free some memory or reduce load)"
                 else
                     log_msg "  daemon exited rc=$drc"
                 fi ;;
        esac
        dgist=$(daemon_log_gist 6 | tr '\n' '|')
        [ -n "$dgist" ] && log_msg "  daemon said: $dgist"
        # One retry under LOG_LEVEL=verbose: the device layer then narrates each creation step
        # (TUN open, vnet-hdr, UAPI socket), which names the failing step on exotic kernels.
        pidof amneziawg-go >/dev/null 2>&1 && { kill $(pidof amneziawg-go) 2>/dev/null; wait_for_pid_exit amneziawg-go 5; }
        ip link del "$IFACE" 2>/dev/null
        log_msg "  retrying once with LOG_LEVEL=verbose..."
        launch_daemon verbose
        if wait_for_iface "$IFACE" 10; then
            log_msg "  verbose retry succeeded — continuing start (transient failure)"
        else
            drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' /tmp/awg_daemon.rc 2>/dev/null)
            dgist=$(daemon_log_gist 8 | tr '\n' '|')
            log_msg "  verbose retry failed too (rc=${drc:-none}); daemon output: ${dgist:-<nothing after the banner>}"
            local dmesg_tail
            dmesg_tail=$(dmesg 2>/dev/null | tail -80 | grep -iE 'amneziawg|potentially unexpected fatal|illegal|segfault|oom' | tail -3 | tr '\n' '|')
            [ -n "$dmesg_tail" ] && log_msg "  dmesg: $dmesg_tail"
            pidof amneziawg-go >/dev/null 2>&1 && kill $(pidof amneziawg-go) 2>/dev/null
            update_status; release_lock; return 1
        fi
    fi
    log_msg "Userspace daemon started"

    # Configure interface. Two distinct failure modes, handled differently:
    #  - wrong-arch awg dies with SIGILL (shell exit 132 = 128 + signal 4) — retrying is futile,
    #    so break out immediately and name it.
    #  - a generic exit 1 on a slow box is usually a RACE: amneziawg-go creates the awg0 link
    #    (wait_for_iface passed) a moment before it is listening on the UAPI control socket, so the
    #    first setconf can't connect. So wait for UAPI readiness, then retry with a short backoff.
    # CRITICAL: capture setconf's STDERR (it used to be discarded — the old comment claimed it
    # "named the error" but only the numeric code was kept) plus the daemon log on the FINAL
    # failure, so a genuine config rejection (an obfuscation param this daemon build won't accept)
    # is spelled out in the journal instead of a bare "exit 1" we can't act on.
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
        if [ "$sc_rc" -eq 132 ]; then
            log_msg "ERROR: 'awg setconf' killed by SIGILL (Illegal instruction) — wrong-arch awg"
            log_msg "  awg=$(elf_arch "$AWG_BIN") host=$(uname -m); run '$ADDON_DIR/amneziawg.sh diag'"
        else
            log_msg "ERROR: setconf failed (exit $sc_rc) after $sc_try retries: ${sc_err:-<no stderr>}"
            [ -s /tmp/awg_daemon.log ] && log_msg "  daemon log: $(tr '\n' '|' < /tmp/awg_daemon.log)"
            # A non-SIGILL setconf failure is almost always the daemon REJECTING an obfuscation
            # parameter (EINVAL → "Unable to modify interface: Invalid argument"). Two probes name
            # it, neither leaks secrets:
            #  (1) dump the non-secret advanced params actually sent — long I-hex is collapsed to
            #      "<head…tail>" so a malformed/unterminated tag (e.g. an I-param missing its
            #      closing '>') is visible in the journal without dumping a kilobyte of hex;
            local adv
            adv=$(awk '
                /^(Jc|Jmin|Jmax|S[1-4]|H[1-4]) /{ print; next }
                /^I[1-5] /{ if(length($0)>44) $0=substr($0,1,28)"…"substr($0,length($0)-7); print }
            ' "$CONF" 2>/dev/null | tr '\n' '|')
            [ -n "$adv" ] && log_msg "  awg params: $adv"
            #  (2) amneziawg-go stays SILENT on UAPI set-rejections at the default log level, so the
            #      bare EINVAL never says which line. Relaunch once under LOG_LEVEL=verbose and retry
            #      setconf so the daemon NAMES the offender (e.g. "failed to parse I1: …").
            kill $(pidof amneziawg-go) 2>/dev/null; wait_for_pid_exit amneziawg-go 5
            ip link del "$IFACE" 2>/dev/null
            launch_daemon verbose
            if wait_for_iface "$IFACE" 5 && wait_for_uapi "$IFACE" 8; then
                "$AWG_BIN" setconf "$IFACE" "$CONF" >/dev/null 2>&1
                local vrej
                vrej=$(grep -iE 'fail|invalid|error|parse|unable|reject|must be|overlap|not.*valid' /tmp/awg_daemon.log 2>/dev/null \
                       | grep -ivF 'first class support' | head -3 | tr '\n' '|')
                [ -n "$vrej" ] && log_msg "  verbose reject: $vrej"
            fi
        fi
        ip link del "$IFACE" 2>/dev/null
        pidof amneziawg-go >/dev/null 2>&1 && kill $(pidof amneziawg-go) 2>/dev/null
        update_status; release_lock; return 1
    fi

    # Address may be dual-stack ("10.8.0.2/24,fd00::2/64" — modern provider configs). Feeding the
    # raw combined string to ONE `ip addr add` is EINVAL, so awg0 ended up with NO address at all:
    # the handshake still completes and keepalives tick the RX/TX counters (daemon-level UDP via
    # the WAN), but MASQUERADE has no source to pick and the prio-100 from-rule never installs —
    # "connected, zero traffic". Add each comma/space-separated address on its own; a failed IPv6
    # add (firmware IPv6 disabled) must not kill the start — the policy routing rides the IPv4.
    if [ -f "$AWG_DIR/awg0.addr" ]; then
        local _addr _v4_ok=0
        for _addr in $(tr ',\r' '  ' < "$AWG_DIR/awg0.addr"); do
            if ip addr add "$_addr" dev "$IFACE" 2>/dev/null; then
                case "$_addr" in *:*) ;; *) _v4_ok=1 ;; esac
            else
                case "$_addr" in
                    *:*) log_msg "WARN: IPv6 address $_addr not applied (firmware IPv6 disabled?) — tunnel continues on IPv4" ;;
                    *)   log_msg "WARN: failed to add address $_addr to $IFACE" ;;
                esac
            fi
        done
        [ "$_v4_ok" = 1 ] || log_msg "WARN: no IPv4 address on $IFACE — NAT and policy routing need one; check the Address field"
    fi
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

    # Base iptables. Every add is -C-guarded (idempotent) so no code path can stack duplicates
    # — the raw appends used to pile up whenever a start ran over remnants of a previous one.
    iptables -C INPUT -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "$IFACE" -j ACCEPT
    setup_ipv6_block
    iptables -t mangle -C FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -C FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    if [ -n "$lan_net" ]; then
        iptables -t nat -C POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -I POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    else
        iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE
    fi

    # Arm the LAN deadman BEFORE the risky part: setup_firewall does the ipset load, DNS
    # interception and dnsmasq reload — the steps that can lock the router out. If they
    # kill dnsmasq, the deadman rolls everything back within ~90s even if we hang here.
    arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
    setup_firewall

    conn_record_start
    log_msg "Started, verifying tunnel connectivity (probing: $(watchdog_hosts))..."
    update_status
    release_lock

    # Health check (detached): verify the tunnel passes traffic and roll back if not.
    # Backgrounded so the service-event handler returns promptly — otherwise
    # rc_service stays busy for up to ~60s and silently drops other events.
    (
        hc_ok=false
        hc_try=0
        hc_dns_fails=0
        hc_reason="not passing traffic (probed: $(watchdog_hosts))"
        while [ $hc_try -lt 30 ]; do
            # Reachability, cheapest first: ICMP every round; a TCP/HTTPS connect through the
            # tunnel at ~10s and ~30s in (endpoints that pass TCP but DROP ICMP — Cloudflare
            # WARP); and from ~6s in, a FRESH HANDSHAKE counts as proof of life — the pings we
            # just sent force a re-key, so a live endpoint refreshes it even when the probe
            # hosts answer nothing at all (field case: awg_watchdog_hosts=100.64.0.1, a gateway
            # ignoring ICMP and TCP — a tunnel with 333 KiB received was rolled back while the
            # journal itself printed "latest handshake: 4 seconds ago").
            hc_pass=""
            if ping_hosts_once; then
                hc_pass="probe"
            elif { [ $hc_try -eq 5 ] || [ $hc_try -eq 15 ]; } && tunnel_tcp_alive; then
                hc_pass="tcp"
            elif [ $hc_try -ge 3 ] && tunnel_handshake_fresh; then
                hc_pass="handshake"
            fi
            if [ -n "$hc_pass" ]; then
                # ICMP/TCP is up. If we hijacked LAN DNS, also require it to actually resolve:
                # an ICMP-only "verified" tunnel leaves clients pinned to a dead resolver
                # (with DoH/DoT REJECTed too) = silent LAN-wide outage that never rolls back.
                # Skip the DNS gate when dnsmasq isn't up (a dnsmasq problem, not the tunnel's
                # — the 30x2s retry covers a brief restart; don't roll back the VPN for it).
                if ! dns_intercept_active || ! pidof dnsmasq >/dev/null 2>&1 || dns_ok; then
                    hc_ok=true
                    break
                fi
                # Tunnel passes traffic; ONLY the DNS layer is failing. Rolling back a working
                # VPN never fixes DNS (a real field case chased a phantom endpoint problem for
                # hours: the router's resolver was broken by a corrupted Entware). The lockout
                # the gate exists for — clients DNAT'd to a resolver that can't answer — is
                # fully cured by dropping OUR :53 hijack (fail-open), so after a few confirmed
                # DNS-only failures do that and keep the tunnel.
                hc_dns_fails=$((hc_dns_fails + 1))
                if [ $hc_dns_fails -ge 6 ]; then
                    log_msg "WARNING: tunnel passes traffic but router DNS won't resolve — removing :53 interception (fail-open), tunnel stays up; check the router's upstream DNS/dnsmasq"
                    disable_tunnel_dns   # a dead tunnel-DNS must not pin dnsmasq to it (no-op if feature off)
                    cleanup_dns_interception
                    hc_ok=true
                    break
                fi
                hc_reason="DNS not resolving through tunnel"
            fi
            hc_try=$((hc_try + 1))
            sleep 2
        done
        if [ "$hc_ok" = true ]; then
            if [ "$hc_pass" = "handshake" ]; then
                log_msg "Tunnel verified: handshake completing — but the probe hosts ($(watchdog_hosts)) answer neither ICMP nor TCP; point awg_watchdog_hosts at ping-able hosts (e.g. 8.8.8.8) for faster checks"
            else
                log_msg "Tunnel verified: traffic passing"
            fi
            update_status
        else
            log_msg "ERROR: Tunnel $hc_reason after 60s, rolling back to prevent lockout"
            # Snapshot the live UAPI state BEFORE the rollback kills the daemon — the single most
            # useful signal for "up but no traffic". A present "latest handshake" + non-zero
            # received bytes means the tunnel IS established and the fault is downstream (routing /
            # MTU / a co-resident tool stealing egress); no handshake means the handshake UDP never
            # got a reply (endpoint unreachable, obfuscation mismatch, or egress hijacked). The diag
            # runs after rollback so `awg show` there is empty — capture it here while it's alive.
            log_msg "  awg show: $("$AWG_BIN" show "$IFACE" 2>&1 | grep -iE 'latest handshake|transfer|endpoint' | tr '\n' '|' | sed 's/|$//')"
            awg_incident "health-check rollback: $hc_reason (awg show: $("$AWG_BIN" show "$IFACE" 2>&1 | grep -iE 'latest handshake|transfer' | tr '\n' '|' | sed 's/|$//'))"
            xray_redirect_active && log_msg "  HINT: XRAYUI transparent-proxy (TPROXY 'redirect all') is active — it captures the router's egress incl. our handshake; turn off XRAYUI's redirect-all mode or run one VPN at a time"
            do_stop "" rollback 2>/dev/null
            log_msg "VPN stopped automatically. Check server config and endpoint reachability."
            update_status
        fi
    ) </dev/null >/dev/null 2>&1 &
}

# --- Stop ---

do_stop(){
    local user_stop="$1"   # "user" = deliberate user stop/uninstall; removes the watchdog cron
    local stop_reason="$2" # connection-history token; empty → derived from $1 (user/auto)
    acquire_lock || { log_msg "Cannot acquire lock, aborting stop"; return 1; }
    rm -f "$STARTING_FLAG"
    do_analyze_stop quiet   # never leave a capture (or its dnsmasq query logging) running past a stop
    # Mark stop-in-progress so the UI shows "Stopping..." even across a page refresh
    touch "$STOPPING_FLAG"
    # Close the connection-history session first, so the status write below (and everything
    # after) already shows it. No-op if no session is open.
    if [ -z "$stop_reason" ]; then
        [ "$user_stop" = "user" ] && stop_reason="user" || stop_reason="auto"
    fi
    conn_record_stop "$stop_reason"
    update_status

    # Drain-delete (every copy, not just the first): installs that lived through the old
    # double-start race carry stacked duplicates — one -D per stop never caught them up.
    ipt_drain -D INPUT -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -o "$IFACE" -j ACCEPT
    cleanup_ipv6_block
    ipt_drain -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ipt_drain -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    local lan_net
    lan_net=$(get_lan_net)
    [ -n "$lan_net" ] && ipt_drain -t nat -D POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    ipt_drain -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE

    cleanup_firewall
    # On a deliberate user stop/uninstall, also drop the self-heal watchdog so the VPN stays
    # down. Auto-rollbacks (health-check, deadman) call do_stop withOUT "user", so the
    # watchdog survives and can still recover the tunnel on its own.
    [ "$user_stop" = "user" ] && cru d awg_watchdog 2>/dev/null
    # Drop the background status-refresh cron in lockstep with the watchdog (same 'user' guard),
    # so a deliberate stop/uninstall leaves no orphaned cron; auto-rollbacks keep both.
    [ "$user_stop" = "user" ] && cru d awg_status 2>/dev/null

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

# Stop then start as ONE operation, keeping the "Connecting" marker set across the stop->start
# gap so the status never flashes a fully-stopped state mid-restart. Without it, the brief
# running=false / no-flags window between do_stop and do_start made every status reader (page
# steady poll, header widget, watchdog) see "stopped" and surface a clickable «Запустить» that
# raced the restart's own start. do_start re-touches the flag; its EXIT trap clears it at the end.
do_restart(){
    do_stop "" restart
    touch "$STARTING_FLAG"
    update_status
    wait_for_pid_exit amneziawg-go 10
    do_start
}

# --- Status JSON for web UI ---

update_status(){
    local running=false
    local pub_key=""
    local listen_port=""
    local iface_addr=""
    local peers_json="[]"
    # Freshest latest-handshake epoch across peers, summed from the SAME `awg show dump` the peer
    # loop below already parses (no extra fork). 0 = no peer has ever handshaked. Feeds the
    # top-level "no_handshake" signal so the UI can tell "daemon up but the tunnel never
    # handshaked" (endpoint unreachable / obfuscation mismatch — and with kill-switch ON all geo
    # traffic is blackholed, so "connected but nothing opens") from a tunnel actually passing data.
    local peer_hs_max=0
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
                # English fallback only (rare: used when hs_epoch is absent on an old status
                # file). The UI normally renders the live "N ago" client-side from hs_epoch and
                # localizes it; see awgAgo() in the page and awgComputeAgo() in the widget.
                local hs_text="never"
                if [ "$handshake" != "0" ] && [ -n "$handshake" ]; then
                    local ago=$(( $(date +%s) - handshake ))
                    if [ $ago -lt 60 ]; then hs_text="${ago} s ago"
                    elif [ $ago -lt 3600 ]; then hs_text="$(( ago / 60 )) min ago"
                    else hs_text="$(( ago / 3600 )) h ago"; fi
                fi
                # Track the freshest handshake across all peers (0 = a peer that never handshaked).
                case "$handshake" in
                    ''|*[!0-9]*) : ;;
                    *) [ "$handshake" -gt "$peer_hs_max" ] && peer_hs_max=$handshake ;;
                esac
                local rx_h=$(human_size "${rx:-0}")
                local tx_h=$(human_size "${tx:-0}")
                # Emit RAW machine values (hs_epoch / rx_bytes / tx_bytes) alongside the
                # pre-formatted strings. The UI computes "N ago" + human sizes from the raw
                # values so the handshake counter ticks LIVE client-side (no backend refresh),
                # and falls back to the formatted strings if a stale/old status file lacks
                # them (upgrade window). Raw fields are unquoted integers — valid JSON; awg's
                # dump always emits clean integers here, so no quoting/sanitising is needed.
                local item="{\"endpoint\":\"${endpoint}\",\"allowed_ips\":\"${aips}\",\"transfer_rx\":\"${rx_h}\",\"transfer_tx\":\"${tx_h}\",\"latest_handshake\":\"${hs_text}\",\"hs_epoch\":${handshake:-0},\"rx_bytes\":${rx:-0},\"tx_bytes\":${tx:-0}}"
                [ -n "$p_items" ] && p_items="${p_items},${item}" || p_items="$item"
            done <<EOF
$dump
EOF
            peers_json="[${p_items}]"
        fi
    fi

    log_text=$(grep "amneziawg" /tmp/syslog.log 2>/dev/null | tail -20 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

    # "Daemon up but the tunnel isn't established" flag for the UI. True only while running and NO
    # peer has EVER completed a handshake (peer_hs_max==0 → endpoint unreachable / obfuscation
    # mismatch). The page uses this to replace a bare "Connected" with an honest "no handshake"
    # state — critical with kill-switch ON, where geo traffic is silently blackholed. The
    # "handshaked once, then went stale" case needs no new field: the page derives age client-side
    # from each peer's hs_epoch. The page must gate any banner on !starting && !stopping (the brief
    # post-start window before the first handshake legitimately reads true).
    local no_handshake=false
    [ "$running" = "true" ] && [ "$peer_hs_max" -eq 0 ] && no_handshake=true

    # Current-session uptime + start epoch for the UI (0 = none: stopped, or the marker predates
    # this version — it appears on the next start). Uptime is the /proc/uptime delta (monotonic);
    # wall-clock fallback only if the marker lacks a start-uptime (older/corrupt marker).
    local conn_start=0 conn_uptime=0 _cse _csu _csb _cnu
    if [ "$running" = "true" ] && [ -f "$CONN_CURRENT" ]; then
        read _cse _csu _csb < "$CONN_CURRENT" 2>/dev/null
        case "$_cse" in
            ''|*[!0-9]*) ;;
            *)
                conn_start=$_cse
                _cnu=$(sys_uptime_s)
                if [ -n "$_csu" ] && [ -n "$_cnu" ] && [ "$_cnu" -ge "$_csu" ] 2>/dev/null; then
                    conn_uptime=$((_cnu - _csu))
                else
                    conn_uptime=$(( $(date +%s) - _cse ))
                    [ "$conn_uptime" -ge 0 ] || conn_uptime=0
                fi
            ;;
        esac
    fi
    # Last 5 closed sessions as JSON, newest first. Every numeric field is validated and the
    # reason token sanitized — a corrupt history line is dropped, never breaks the page's parse.
    local conn_hist="[]"
    if [ -f "$CONN_HISTORY" ]; then
        conn_hist=$(awk -F'|' '
            NF>=4 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^-?[0-9]+$/ {
                r=$4; gsub(/[^a-z_]/,"",r)
                a[++n]="{\"s\":"$1",\"e\":"$2",\"d\":"$3",\"r\":\""r"\"}"
            }
            END{ s="["; for(i=n;i>=1;i--) s=s a[i] (i>1?",":""); print s "]" }
        ' "$CONN_HISTORY" 2>/dev/null)
        [ -n "$conn_hist" ] || conn_hist="[]"
    fi

    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local clients_data=$(get_setting awg_clients | sed 's/"/\\"/g')
    local active_rules=$(ip rule show 2>/dev/null | grep -c "lookup $RT_TABLE\|fwmark $FWMARK")

    # Total entries across every per-policy geo ipset (awg_dst + awg_dst<id>).
    local ipset_count=$(geo_ipset_total)

    # Domain->main-set memberships (a domain shared by N policies counts N times) — equals the sum
    # of the per-tab counts. Shared with the setup_firewall log via geo_domain_total so they can't
    # drift; see that helper for the exact metric.
    local geo_domains=$(geo_domain_total)

    # Per-policy geo stats {"<id>":{"ip":N,"dom":M},...} for the UI's per-tab breakdown:
    # ip = entries in the policy's main set; dom = domains dnsmasq routes into that set.
    local geo_stats="" _gsid _gsset _gsip _gsdom _gssep=""
    for _gsid in $(geo_ids); do
        _gsset=$(geo_ipset "$_gsid")
        _gsip=$(ipset list "$_gsset" -t 2>/dev/null | awk '/Number of entries/{print $NF}'); [ -z "$_gsip" ] && _gsip=0
        _gsdom=0
        [ -f "$DNSMASQ_AWG_CONF" ] && _gsdom=$(awk -F/ -v s="$_gsset" '/^ipset=/{n=split($NF,ss,",");for(i=1;i<=n;i++)if(ss[i]==s){c+=NF-2;break}} END{print c+0}' "$DNSMASQ_AWG_CONF" 2>/dev/null)
        [ -z "$_gsdom" ] && _gsdom=0
        geo_stats="${geo_stats}${_gssep}\"${_gsid}\":{\"ip\":${_gsip},\"dom\":${_gsdom}}"
        _gssep=","
    done

    local geo_downloaded=false
    geo_available && geo_downloaded=true
    local geo_busy=false
    [ -f "$GEO_BUSY_FLAG" ] && geo_busy=true

    local starting=false
    [ -f "$STARTING_FLAG" ] && starting=true
    local stopping=false
    [ -f "$STOPPING_FLAG" ] && stopping=true
    local analyze_active=false
    [ -f "$ANALYZE_FLAG" ] && analyze_active=true

    # Co-resident DPI/proxy tool (Xray/zapret/etc.), surfaced to the UI so it can warn that
    # "all->VPN" + DNS interception will collide with it.
    local dpi_tool=$(detect_dpi_tool)
    # Kill-switch state (opt-in fail-closed routing) for the UI toggle.
    local killswitch=false
    [ "$(get_setting awg_killswitch)" = "1" ] && killswitch=true
    # AdGuardHome present? Surfaced so the page shows the "wait for AGH on autostart" option only
    # on AGH boxes (where the geo-ipset bridge depends on AGH being ready before our dnsmasq restart).
    local agh=false
    agh_present && agh=true
    # Coexistence alarm: a DPI/proxy tool present AND an all->VPN policy that pulls LAN
    # traffic into the tunnel. Surfaced so the page can render a blocking banner.
    local coexist_warn=false
    [ -n "$dpi_tool" ] && { [ "$default_policy" = "vpn_all" ] || any_exclude_mode; } && coexist_warn=true
    # Reverse coexistence alarm: a transparent proxy (XRAYUI/xray TPROXY "redirect all") capturing
    # the router's own egress, which breaks the tunnel (up but no traffic). Page renders a banner.
    local xray_capture=false
    xray_redirect_active && xray_capture=true
    # Firmware VPN client (wgc*/VPN Fusion) probe — "active" (its from-all rule outranks ours
    # and captures traffic NOW) or "enabled" (latent: profile on, not connected). UI banner.
    local fwvpn_state="" fwvpn_detail="" _fwv
    _fwv=$(fw_vpn_client_state 2>/dev/null)
    if [ -n "$_fwv" ]; then
        fwvpn_state=${_fwv%%|*}
        fwvpn_detail=$(printf '%s' "${_fwv#*|}" | sed 's/"/\\"/g')
    fi
    # Domain-geo vs DNS-interception mismatch (yellow page banner): domain lists are loaded
    # into dnsmasq and a device/default policy routes via geo, but our :53 interception is not
    # in place — domains then populate the sets ONLY for clients that voluntarily use the
    # router's dnsmasq, so devices with DoH/private DNS silently bypass the domain routing
    # (field case: "traffic didn't move until I enabled interception" — the compat-mode
    # default on fresh installs plus domain lists). Cause-aware value:
    #   "user"        — compatibility mode (awg_no_dns_intercept=1), the user's own switch;
    #   "dpi:<tool>"  — interception auto-disabled for a co-resident DPI/proxy tool;
    #   "fwdns:<who>" — a firmware DNS owner (AGH/DNSFilter/Director) redirects clients past
    #                   dnsmasq. DoT is deliberately NOT warned (dnsmasq stays the resolver),
    #                   and neither is the transient mid-start window (empty fwdns name).
    # Gated on running — with the tunnel down nothing routes anyway.
    local dnsgeo_warn=""
    if [ "$running" = "true" ] && [ "$geo_domains" -gt 0 ] 2>/dev/null && ! dns_intercept_active; then
        local _georouted=0 _fwdnsn
        case "$default_policy" in *geo*) _georouted=1 ;; esac
        case "$(get_setting awg_clients)" in *vpn_geo*) _georouted=1 ;; esac
        if [ "$_georouted" = 1 ]; then
            if [ "$(get_setting awg_no_dns_intercept)" = "1" ]; then
                dnsgeo_warn="user"
            elif zapret_active; then
                dnsgeo_warn="dpi:$(detect_dpi_tool)"
            else
                _fwdnsn=$(fw_dns_redirect_name)
                case "$_fwdnsn" in
                    ""|*DoT*) ;;
                    *) dnsgeo_warn="fwdns:${_fwdnsn%% (*}" ;;
                esac
            fi
        fi
    fi
    # Can we offer a "Stop Xray" button? Only if XRAYUI's own entry point is present (so the stop
    # goes through its cleanup_firewall and actually removes the TPROXY rules).
    local xray_ctl=false
    [ -x /jffs/scripts/xrayui ] && xray_ctl=true

    # Unsupported kernel (see kernel_pre_sendmmsg): Linux < 3.0 has no sendmmsg → the daemon can't
    # send packets → the tunnel can never pass traffic. do_start refuses; the page shows an
    # informational banner (no user action fixes it — a patched daemon is needed).
    local kernel_unsup=false
    kernel_pre_sendmmsg && kernel_unsup=true

    # Broadcom CTF blocks the tunnel (see ctf_active): a CTF-accelerated box would hang on our
    # policy-routing bring-up, so do_start refuses. Surfaced so the page renders a blocking
    # banner with a one-click "disable CTF + reboot". False on every non-CTF box, and suppressed
    # on an unsupported kernel (kernel_unsup is the real story there — disabling CTF wouldn't help).
    local ctf_block=false
    { ctf_active && ! kernel_pre_sendmmsg; } && ctf_block=true

    # Firmware UI language (preferred_lang nvram) so the page/widget can localize without a
    # round-trip. The frontend maps RU -> Russian, everything else -> English. Empty -> EN.
    local pref_lang=$(nvram get preferred_lang 2>/dev/null)
    [ -z "$pref_lang" ] && pref_lang="EN"

    # Write atomically (temp + rename) so the UI never reads a half-written file. The temp is
    # PID-unique ($$) — the 1-min awg_status cron can now run update_status concurrently with a
    # user action, and a shared ".tmp" would let them clobber each other mid-write. Sweep any
    # numeric-suffixed leftovers first (a crash/kill between cat and mv would otherwise strand
    # them in /www/user forever); the glob matches only "<status>.<digits>", never the live
    # awg_status.htm or awg_widget.js. The old ".tmp" is removed too in case an upgrade left one.
    rm -f "${STATUS_FILE}.tmp" "${STATUS_FILE}".[0-9]* 2>/dev/null
    cat > "${STATUS_FILE}.$$" << STATUSEOF
{"running":${running},"starting":${starting},"stopping":${stopping},"version":"${AWG_VERSION}","lang":"${pref_lang}","public_key":"${pub_key}","listen_port":"${listen_port}","interface_addr":"${iface_addr}","peers":${peers_json},"no_handshake":${no_handshake},"conn_start":${conn_start},"conn_uptime":${conn_uptime},"conn_history":${conn_hist},"default_policy":"${default_policy}","dpi_tool":"${dpi_tool}","killswitch":${killswitch},"agh":${agh},"coexist_warn":${coexist_warn},"xray_capture":${xray_capture},"xray_ctl":${xray_ctl},"fwvpn_state":"${fwvpn_state}","fwvpn_detail":"${fwvpn_detail}","ctf_block":${ctf_block},"kernel_unsup":${kernel_unsup},"dnsgeo_warn":"${dnsgeo_warn}","clients":"${clients_data}","active_rules":${active_rules},"ipset_count":${ipset_count},"geo_domains":${geo_domains},"geo_stats":{${geo_stats}},"geo_downloaded":${geo_downloaded},"geo_busy":${geo_busy},"analyze_active":${analyze_active},"log":"${log_text}"}
STATUSEOF
    mv "${STATUS_FILE}.$$" "$STATUS_FILE" 2>/dev/null
}

# --- Per-device traffic analysis ---

# Ground-truth routing policy for a device IP: its explicit entry in clients.list, else the
# default policy, else "direct". This is the APPLIED policy (what actually routes), not the
# unsaved dropdown in the UI — the modal shows what we return so there's no confusion.
analyze_device_policy(){
    local ip="$1" pol=""
    if [ -f "$CLIENTS_FILE" ]; then
        pol=$(awk -F',' -v ip="$ip" '
            { k=$1; gsub(/[ \t\r]/,"",k);
              if(k==ip){ p=$3; gsub(/[ \t\r]/,"",p); print p; exit } }
        ' "$CLIENTS_FILE")
    fi
    [ -z "$pol" ] && pol=$(get_setting awg_default_policy)
    [ -z "$pol" ] && pol="direct"
    echo "$pol"
}

# Routing verdict for one destination IP under a policy: vpn | geo | direct. Reproduces
# emit_geo_rules exactly — per-device rules are TERMINAL, so a listed device's verdict is decided
# solely by its OWN policy (no default fall-through); an unlisted device is analyzed with the
# default policy (analyze_device_policy returns that). EXC wins over INC (evaluated first).
#   include (mode=vpn):   EXC -> direct; INC -> geo;    else direct
#   exclude (mode=direct): EXC -> vpn;    INC -> direct; else vpn
analyze_verdict(){
    case "$1" in
        vpn_all) echo "vpn" ;;
        vpn_geo|vpn_geo_*)
            local id incset excset
            id=$(geo_policy_of_ref "$1"); incset=$(geo_ipset "$id"); excset=$(geo_exc_ipset "$id")
            if [ "$(geo_mode "$id")" = direct ]; then
                if ipset test "$excset" "$2" >/dev/null 2>&1; then echo "vpn"
                elif ipset test "$incset" "$2" >/dev/null 2>&1; then echo "direct"
                else echo "vpn"; fi
            else
                if ipset test "$excset" "$2" >/dev/null 2>&1; then echo "direct"
                elif ipset test "$incset" "$2" >/dev/null 2>&1; then echo "geo"
                else echo "direct"; fi
            fi ;;
        *)       echo "direct" ;;
    esac
}

# Turn dnsmasq query logging ON (only while a capture runs) via a dedicated conf snippet,
# registered in the include exactly like the geo conf (conf-file= line, idempotent). The log
# feeds the IP->name map. Uses the existing self-healing reload_dnsmasq.
analyze_dns_log_on(){
    : > "$ANALYZE_DNS_LOG" 2>/dev/null
    printf 'log-queries=extra\nlog-facility=%s\n' "$ANALYZE_DNS_LOG" > "$ANALYZE_DNS_CONF"
    if ! grep -qF "conf-file=$ANALYZE_DNS_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
        echo "conf-file=$ANALYZE_DNS_CONF" >> "$DNSMASQ_INCLUDE"
    fi
    reload_dnsmasq
}

# Turn dnsmasq query logging back OFF and remove the log. Only reloads dnsmasq if the snippet
# was actually registered, so a stop with nothing running is cheap (no needless restart).
analyze_dns_log_off(){
    rm -f "$ANALYZE_DNS_CONF"
    if [ -f "$DNSMASQ_INCLUDE" ] && grep -qF "$ANALYZE_DNS_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
        grep -vF "$ANALYZE_DNS_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.awgan.tmp" 2>/dev/null \
            && mv "${DNSMASQ_INCLUDE}.awgan.tmp" "$DNSMASQ_INCLUDE"
        reload_dnsmasq
    fi
    rm -f "$ANALYZE_DNS_LOG"
}

# (Re)build the IP->name map from the dnsmasq query log. Indexes from the end of each line so it
# works with or without the log-queries=extra prefix; "<name> is <ipv4>" reply/cached lines only
# (CNAME replies end in a name, not an IPv4, and are skipped). Name sanitized to a JSON-safe set.
analyze_build_map(){
    if [ ! -f "$ANALYZE_DNS_LOG" ]; then : > "$ANALYZE_MAP" 2>/dev/null; return; fi
    awk '
        / is [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            ip=$NF; name=$(NF-2);
            gsub(/[^A-Za-z0-9._-]/,"",name);
            if(name!="") map[ip]=name;
        }
        END { for(k in map) print k"\t"map[k] }
    ' "$ANALYZE_DNS_LOG" > "$ANALYZE_MAP" 2>/dev/null
}

# Publish the analysis state as JSON (atomic temp+rename, like update_status). The entries file
# holds one ready-made JSON object per line; we just splice them into an array.
analyze_write(){
    local ip="$1" policy="$2" active="$3" started="${4:-0}" arr=""
    [ -f "$ANALYZE_ENTRIES" ] && arr=$(awk 'BEGIN{ORS=""} {if(NR>1)print ","; print}' "$ANALYZE_ENTRIES" 2>/dev/null)
    rm -f "${ANALYZE_FILE}.tmp" "${ANALYZE_FILE}".[0-9]* 2>/dev/null
    cat > "${ANALYZE_FILE}.$$" <<ANEOF
{"active":${active},"device":"${ip}","policy":"${policy}","started":${started},"entries":[${arr}]}
ANEOF
    mv "${ANALYZE_FILE}.$$" "$ANALYZE_FILE" 2>/dev/null
}

# Emit "proto dst dport" for each of the device's flows, read from the kernel conntrack table in
# /proc — the `conntrack` CLI is NOT installed on stock Asuswrt-Merlin, so we parse the proc file
# directly (nf_conntrack, with the older ip_conntrack as a fallback). proto is the L4 name token
# (tcp/udp/…), and dst/dport are the ORIGINAL tuple (the FIRST dst=/dport= on the line = the real
# destination before NAT). The line carries two src= (orig + reply); grepping the device's src
# with a trailing space matches the original tuple and won't prefix-match a longer IP.
analyze_flows(){
    local ip="$1" src=""
    [ -r /proc/net/nf_conntrack ] && src=/proc/net/nf_conntrack
    [ -z "$src" ] && [ -r /proc/net/ip_conntrack ] && src=/proc/net/ip_conntrack
    [ -z "$src" ] && return 0
    grep "src=$ip " "$src" 2>/dev/null | awk '
        {
            proto=""; d=""; dp="";
            for(i=1;i<=NF;i++){
                if(proto==""&&($i=="tcp"||$i=="udp"||$i=="icmp"||$i=="icmpv6"||$i=="udplite"||$i=="sctp"||$i=="dccp")) proto=$i;
                if(d==""&&$i ~ /^dst=/)    d=substr($i,5);
                if(dp==""&&$i ~ /^dport=/)  dp=substr($i,7);
            }
            if(proto=="") proto="ip";
            if(d!="") print proto" "d" "dp;
        }'
}

# Emit "domain<TAB>ip1,ip2,…" for each domain the DEVICE asked to resolve (the request intent,
# captured before/at resolution from the dnsmasq query log). Domains are taken from query[*]
# lines whose "from" is the device (any record type, so AAAA/HTTPS-only domains still show), and
# the resolved IPv4s are correlated by the dnsmasq query id (so a CNAME chain's final A records
# attach to the original domain). The IP list is empty until the name resolves. log-queries=extra
# prints "<ts> dnsmasq[pid]: <id> <client>/<port> query[T] <domain> from <client>" and
# "… <id> … reply|cached <name> is <ipv4>".
analyze_dns_queries(){
    local ip="$1"
    [ -r "$ANALYZE_DNS_LOG" ] || return 0
    awk -v ip="$ip" '
        {
            id="";
            for(i=1;i<=NF;i++){ if($i ~ /^dnsmasq\[/){ id=$(i+1); break } }
            if(id==""){ next }
            q=""; req="";
            for(i=1;i<=NF;i++){ if($i ~ /^query\[/) q=$(i+1); if($i=="from") req=$(i+1); }
            if(q!="" && req==ip){ d[id]=q; if(!(q in seen)){ seen[q]=1; ord[++n]=q } }
            for(i=1;i<NF;i++){
                if(($i=="reply"||$i=="cached") && $(i+2)=="is" && $(i+3) ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && (id in d))
                    ips[d[id]] = ips[d[id]] "," $(i+3);
            }
        }
        END{ for(k=1;k<=n;k++){ q=ord[k]; s=ips[q]; sub(/^,/,"",s); print q"\t"s } }
    ' "$ANALYZE_DNS_LOG"
}

# Background capture worker. Every ~2s while the flag exists (and under the safety cap): refresh
# the name map, snapshot the device's NEW conntrack flows, name + verdict each, append to the
# ring buffer, publish. Self-tears-down on timeout (the no-stop path).
analyze_loop(){
    local ip="$1" policy="$2" started="$3"
    local router_ip lan_pre deadline now sz
    router_ip=$(get_router_ip)
    lan_pre=$(printf '%s' "$router_ip" | sed 's/\.[0-9]*$/./')
    deadline=$((started + ANALYZE_MAX_SECONDS))
    while [ -f "$ANALYZE_FLAG" ]; do
        now=$(date +%s)
        [ "$now" -ge "$deadline" ] && break
        # Keep the query log from growing without bound on a busy LAN.
        if [ -f "$ANALYZE_DNS_LOG" ]; then
            sz=$(wc -c < "$ANALYZE_DNS_LOG" 2>/dev/null)
            [ -n "$sz" ] && [ "$sz" -gt 262144 ] 2>/dev/null && \
                { tail -c 131072 "$ANALYZE_DNS_LOG" > "${ANALYZE_DNS_LOG}.t" 2>/dev/null && mv "${ANALYZE_DNS_LOG}.t" "$ANALYZE_DNS_LOG"; }
        fi
        analyze_build_map
        # --- DNS-request rows: domains the device is TRYING to reach (the intent), captured at
        # query time. Verdict from the resolved IPv4(s): vpn_geo -> geo if any is in the set, else
        # direct; vpn_all -> vpn; direct -> direct. For vpn_geo we DEFER a domain (don't mark it
        # seen) until it has resolved, so its verdict is real rather than a transient "unknown". ---
        analyze_dns_queries "$ip" | while IFS="$(printf '\t')" read -r dom ipscsv; do
            dom=$(printf '%s' "$dom" | tr -cd 'A-Za-z0-9._-')
            [ -z "$dom" ] && continue
            dkey="dns:$dom"
            grep -qxF "$dkey" "$ANALYZE_SEEN" 2>/dev/null && continue
            firstip=$(printf '%s' "$ipscsv" | cut -d, -f1)
            verdict="direct"
            if [ "$policy" = vpn_all ]; then
                verdict="vpn"
            elif [ -n "$ipscsv" ]; then
                # Per resolved IP, the mode/exclusion/default-aware verdict; first non-direct wins.
                for one in $(printf '%s' "$ipscsv" | tr ',' ' '); do
                    [ -z "$one" ] && continue
                    verdict=$(analyze_verdict "$policy" "$one")
                    [ "$verdict" != direct ] && break
                done
            else
                case "$policy" in vpn_geo|vpn_geo_*) continue ;; esac   # geo: not resolved yet — retry
            fi
            echo "$dkey" >> "$ANALYZE_SEEN"
            echo "{\"t\":\"$(date '+%H:%M:%S')\",\"name\":\"$dom\",\"ip\":\"$firstip\",\"proto\":\"dns\",\"port\":\"\",\"verdict\":\"$verdict\"}" >> "$ANALYZE_ENTRIES"
        done
        analyze_flows "$ip" | while read -r proto dst dport; do
            # Skip LAN-local / router / loopback / multicast / broadcast destinations.
            case "$dst" in "$router_ip"|127.*|224.*|225.*|226.*|227.*|228.*|229.*|23[0-9].*|255.*|0.*) continue ;; esac
            [ -n "$lan_pre" ] && case "$dst" in "$lan_pre"*) continue ;; esac
            key="$proto:$dst:$dport"
            grep -qxF "$key" "$ANALYZE_SEEN" 2>/dev/null && continue
            echo "$key" >> "$ANALYZE_SEEN"
            name=$(awk -F'\t' -v ip="$dst" '$1==ip{print $2; exit}' "$ANALYZE_MAP" 2>/dev/null)
            [ -z "$name" ] && name="$dst"
            verdict=$(analyze_verdict "$policy" "$dst")
            echo "{\"t\":\"$(date '+%H:%M:%S')\",\"name\":\"$name\",\"ip\":\"$dst\",\"proto\":\"$proto\",\"port\":\"$dport\",\"verdict\":\"$verdict\"}" >> "$ANALYZE_ENTRIES"
        done
        if [ -f "$ANALYZE_ENTRIES" ]; then
            tail -n "$ANALYZE_MAX_ENTRIES" "$ANALYZE_ENTRIES" > "${ANALYZE_ENTRIES}.t" 2>/dev/null && mv "${ANALYZE_ENTRIES}.t" "$ANALYZE_ENTRIES"
        fi
        analyze_write "$ip" "$policy" true "$started"
        sleep 2
    done
    # Timeout / flag-cleared path: publish final inactive state and remove the DNS log snippet.
    rm -f "$ANALYZE_FLAG"
    analyze_write "$ip" "$policy" false "$started"
    analyze_dns_log_off
    rm -f "$ANALYZE_PID"
}

# Start a capture for the device IP in the awg_analyze_device setting. Returns immediately
# (service-event context must not block) — the worker runs detached.
do_analyze_start(){
    local ip pol now
    ip=$(get_setting awg_analyze_device)
    ip=$(printf '%s' "$ip" | tr -cd '0-9.')
    if ! echo "$ip" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
        echo '{"active":false,"device":"","policy":"","started":0,"entries":[],"error":"bad_ip"}' > "$ANALYZE_FILE"
        return
    fi
    do_analyze_stop quiet          # clear any prior session first
    pol=$(analyze_device_policy "$ip")
    now=$(date +%s)
    echo "$ip" > "$ANALYZE_FLAG"
    echo "$now" > "$ANALYZE_STARTED"
    : > "$ANALYZE_ENTRIES"; : > "$ANALYZE_SEEN"; : > "$ANALYZE_MAP"
    analyze_dns_log_on
    analyze_write "$ip" "$pol" true "$now"
    analyze_loop "$ip" "$pol" "$now" </dev/null >/dev/null 2>&1 &
    echo $! > "$ANALYZE_PID"
    log_msg "Traffic analysis started for $ip ($pol)"
}

# Stop the capture: clear the flag, kill the worker, restore DNS, publish a final inactive
# state (keeping the last entries visible). $1="quiet" suppresses the log line.
do_analyze_stop(){
    local ip pol was=0 pid
    [ -f "$ANALYZE_FLAG" ] && was=1
    rm -f "$ANALYZE_FLAG"
    pid=$(cat "$ANALYZE_PID" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$ANALYZE_PID" "$ANALYZE_SEEN" "$ANALYZE_MAP"
    analyze_dns_log_off
    ip=$(get_setting awg_analyze_device); ip=$(printf '%s' "$ip" | tr -cd '0-9.')
    pol=$(analyze_device_policy "$ip")
    analyze_write "$ip" "$pol" false "$(cat "$ANALYZE_STARTED" 2>/dev/null || echo 0)"
    rm -f "$ANALYZE_STARTED"
    [ "$1" = quiet ] || [ "$was" = 0 ] || log_msg "Traffic analysis stopped"
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

    # dnsmasq.postconf hook (Merlin-native), ONE tagged "amneziawg" line, two guards:
    #   1. tunnel-DNS — while $TUNNEL_DNS_FLAG exists, strip the firmware's upstream directives
    #      so ONLY our server=<awg_dns>@awg0 lines answer (the "DNS via tunnel" feature).
    #   2. missing-conf guard — if our /opt include target is ABSENT, pc_delete its `conf-file=`
    #      directive from the generated conf ($1). Our persistent `conf-file=` lines live in the
    #      firmware-owned /jffs/configs/dnsmasq.conf.add, but the files they point at live on /opt
    #      (often a REMOVABLE/late-mounting USB). When /opt is unavailable — USB pulled/dying, or
    #      simply not mounted yet at early boot while start_dnsmasq already fires — dnsmasq treats
    #      a missing `conf-file=` as FATAL and won't start at all: the whole LAN loses DNS/DHCP
    #      and the router goes "unreachable" (field-confirmed on RT-AC68U, USB /opt). This guard
    #      makes a missing /opt non-fatal — dnsmasq starts clean. No-op when the files exist.
    # UPGRADE: rewrite the tagged line every install_page (idempotent) — do NOT gate on
    # grep-not-found, or existing installs that carry only the older tunnel-DNS-only line never
    # gain the missing-conf guard. The paths are LITERAL (the hook runs standalone with no access
    # to $AWG_DIR/$DNSMASQ_AWG_CONF/$ANALYZE_DNS_CONF — keep them in sync with lines ~9/50/30).
    [ ! -f /jffs/scripts/dnsmasq.postconf ] && printf '#!/bin/sh\n' > /jffs/scripts/dnsmasq.postconf
    chmod +x /jffs/scripts/dnsmasq.postconf 2>/dev/null
    sed -i '/# amneziawg/d' /jffs/scripts/dnsmasq.postconf 2>/dev/null
    echo '. /usr/sbin/helper.sh; [ -f /tmp/.awg_tunnel_dns ] && { pc_delete "servers-file=" "$1"; pc_delete "resolv-file=" "$1"; }; [ -f /opt/amneziawg/dnsmasq_awg.conf ] || pc_delete "conf-file=/opt/amneziawg/dnsmasq_awg.conf" "$1"; [ -f /opt/amneziawg/dnsmasq_analyze.conf ] || pc_delete "conf-file=/opt/amneziawg/dnsmasq_analyze.conf" "$1"  # amneziawg dnsmasq guard' >> /jffs/scripts/dnsmasq.postconf

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
    # NOTE: the tunnel's boot autostart is the .ipk's S99amneziawg init script (Entware rc.unslung
    # -> 'amneziawg.sh boot_start' -> do_boot_start, which honors the awg_autostart toggle), NOT
    # this hook. A pre-1.2.19 `awg_autostart` branch here was dead code and was removed; since
    # 1.2.52 the key is real again — with a UI checkbox — but it gates ONLY do_boot_start, never
    # this hook. The optional pre-start delay and the AdGuardHome-readiness wait live in do_start —
    # the single real start path hit by every trigger (boot, UI, restart, watchdog).
}

do_uninstall(){
    do_stop user   # user intent: remove the watchdog cron too

    # Belt-and-suspenders: do_stop -> cleanup_firewall already strips our dnsmasq include, but
    # do_stop can early-return on a lock-acquire failure, which would leave the persistent
    # /jffs/configs/dnsmasq.conf.add pointing at /opt/amneziawg files the package is about to
    # delete — a missing `conf-file=` is fatal to the firmware's dnsmasq at the next boot. Strip
    # both our geo include and the analyzer include here unconditionally (lock-free; the rewrite is
    # not gated on grep's exit so an empty result is honored), then make sure the resolver is alive.
    rm -f "$DNSMASQ_AWG_CONF" "$ANALYZE_DNS_CONF"
    if [ -f "$DNSMASQ_INCLUDE" ]; then
        grep -vF "conf-file=$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" > "${DNSMASQ_INCLUDE}.tmp" 2>/dev/null
        grep -vF "conf-file=$ANALYZE_DNS_CONF" "${DNSMASQ_INCLUDE}.tmp" > "${DNSMASQ_INCLUDE}.tmp2" 2>/dev/null
        mv "${DNSMASQ_INCLUDE}.tmp2" "$DNSMASQ_INCLUDE" 2>/dev/null
        rm -f "${DNSMASQ_INCLUDE}.tmp"
    fi
    pidof dnsmasq >/dev/null 2>&1 || service restart_dnsmasq >/dev/null 2>&1

    [ -f /jffs/scripts/service-event ] && sed -i '/amneziawg/d' /jffs/scripts/service-event
    [ -f /jffs/scripts/services-start ] && sed -i '/amneziawg/d' /jffs/scripts/services-start
    [ -f /jffs/scripts/wan-event ] && sed -i '/amneziawg/d' /jffs/scripts/wan-event
    [ -f /jffs/scripts/firewall-start ] && sed -i '/amneziawg/d' /jffs/scripts/firewall-start
    [ -f /jffs/scripts/dnsmasq.postconf ] && sed -i '/amneziawg/d' /jffs/scripts/dnsmasq.postconf
    rm -f "$TUNNEL_DNS_FLAG"

    local page=$(ls /www/user/ 2>/dev/null | while read f; do grep -l "AmneziaWG" "/www/user/$f" 2>/dev/null; done | head -1)
    [ -n "$page" ] && rm -f "$page"
    rm -f "$STATUS_FILE" /www/user/awg_widget.js /www/user/v2fly_categories.htm /www/user/awg_changelog.htm /www/user/awg_update.htm /www/user/awg_log.htm /www/user/awg_diag.htm
    rm -f "$ANALYZE_FILE" "$ANALYZE_DNS_CONF" "$ANALYZE_DNS_LOG" /tmp/.awg_analyze_*

    rm -f "$AWG_INCIDENTS"
    rm -f "$CONN_HIST_BAK"   # update-time stash lives OUTSIDE $AWG_DIR — the package rm -rf misses it
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

# Confirm the tunnel actually carries traffic via a short HTTPS connect THROUGH it. This catches
# endpoints that pass TCP but DROP ICMP — notably Cloudflare WARP, where ping_hosts_once false-
# negatives a perfectly working tunnel (handshake completes, data flows, but `ping -I awg0` never
# replies → the health check would roll a working tunnel back). Binds curl to the awg0 source IP;
# the "from <awg0-ip> lookup $RT_TABLE" rule (installed by setup_firewall, same path awg_dl_iface_opt
# uses) routes it out the tunnel. Returns 0 if any target's TCP/TLS connect completes. No curl / no
# tunnel routing in place -> return 1, so the ICMP verdict stands (never a false POSITIVE).
# Probes the SAME user-configured hosts as the ICMP check (`watchdog_hosts`), on HTTPS/443.
tunnel_tcp_alive(){
    which curl >/dev/null 2>&1 || return 1
    local addr h
    addr=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -n "$addr" ] || return 1
    ip rule show 2>/dev/null | grep -qF "from $addr lookup $RT_TABLE" || return 1
    for h in $(watchdog_hosts); do
        curl -k -s -o /dev/null --interface "$addr" --connect-timeout 4 --max-time 6 "https://$h" 2>/dev/null && return 0
    done
    return 1
}

# Latest-handshake age in seconds (first peer), from the machine-readable dump
# (columns: pubkey psk endpoint allowed-ips latest-handshake rx tx keepalive).
# Prints nothing / returns 1 when unknown or no handshake has ever completed.
tunnel_handshake_age(){
    local hs now
    hs=$("$AWG_BIN" show "$IFACE" dump 2>/dev/null | awk 'NR==2{print $5}')
    case "$hs" in ''|*[!0-9]*) return 1 ;; esac
    [ "$hs" -eq 0 ] && return 1
    now=$(date +%s)
    echo $((now - hs))
}

# Evidence-based liveness: a handshake completed within the last ~150s (WireGuard re-keys every
# ~120s under send pressure) proves two-way UDP with the peer. Crucially, the probe packets the
# callers just SENT through the tunnel force that re-key — so a LIVE endpoint always shows a
# fresh handshake here even when the probe hosts answer neither ICMP nor TCP (field case:
# awg_watchdog_hosts pointed at a provider gateway that ignores both — a fully-working tunnel
# with megabytes of RX was rolled back while `awg show` said "latest handshake: 4 seconds ago").
# A dead endpoint can't refresh the handshake, so genuine failures still fail.
tunnel_handshake_fresh(){
    local age
    age=$(tunnel_handshake_age) || return 1
    [ -n "$age" ] && [ "$age" -le 150 ]
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
    # ICMP all-miss — confirm via a TCP/HTTPS connect through the tunnel before declaring it dead,
    # so an ICMP-dropping endpoint (e.g. Cloudflare WARP) isn't torn down every watchdog tick.
    tunnel_tcp_alive && return 0
    # Probes may simply be ignored by this endpoint/hosts — the pings above already forced a
    # re-key attempt, so accept a fresh handshake as proof of life (see tunnel_handshake_fresh).
    tunnel_handshake_fresh && return 0
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
    # Heartbeat FIRST (before any early return): proves in diag that the cron actually fires.
    # A watchdog that silently never runs is indistinguishable from a healthy one otherwise.
    date '+%Y-%m-%d %H:%M:%S' > /tmp/.awg_wd_beat 2>/dev/null

    # An update in progress deliberately stops the VPN (finalize_ipk_install: stop → wait →
    # opkg remove+install → restart). The watchdog must NOT self-heal into that window — a tick
    # here would see awg0 missing and race a VPN restart against the installer (field-reported:
    # "auto-update kills the connection, the watchdog brings the service back up, THEN it gets
    # removed and reinstalled"). The same flag that blocks do_start's opkg-triggered S99 auto-
    # start gates us; finalize_ipk_install now sets it BEFORE its first teardown and clears it on
    # every exit path, so this covers the whole update, not just the opkg step.
    # Stale-flag guard: since the watchdog is the SELF-HEAL safety net, a flag leaked by an
    # updater that died mid-flight (crash / power-cut) must not disable it forever. The flag is
    # normally held only a few minutes (stop→opkg→install); older than 15 min ⇒ the updater is
    # gone — reclaim it (like a stale lock) and proceed. NB the long post-install geo re-download
    # runs AFTER the flag is cleared, so a slow box can't legitimately hold it that long.
    if [ -f /tmp/.awg_no_autostart ]; then
        if [ -z "$(find /tmp/.awg_no_autostart -mmin +15 2>/dev/null)" ]; then
            return 0   # fresh flag — a genuine update is in progress; stand down
        fi
        log_msg "WATCHDOG: stale update flag (>15 min) — updater likely died mid-flight; reclaiming"
        rm -f /tmp/.awg_no_autostart
    fi

    # Skip if another operation is mid-flight — but only if its holder is ALIVE. A leaked lock
    # (a process killed between acquire and release) used to silence the watchdog FOREVER
    # (every tick returned here), which is precisely when self-heal matters most. acquire_lock
    # already knows how to reclaim a dead holder's lock; give the watchdog the same knowledge.
    if [ -d "$LOCKDIR" ]; then
        local _lp
        _lp=$(cat "$LOCKDIR/pid" 2>/dev/null)
        if [ -n "$_lp" ] && kill -0 "$_lp" 2>/dev/null; then
            return 0   # genuinely busy
        fi
        if [ -z "$_lp" ]; then
            # No pid file — either mid-acquire (mkdir happened a moment ago) or a crash in that
            # window. Only treat as stale once the dir is demonstrably old.
            [ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +5 2>/dev/null)" ] || return 0
        fi
        log_msg "WATCHDOG: stale operation lock (holder ${_lp:-unknown} is gone) — reclaiming"
        rm -rf "$LOCKDIR"
    fi

    # DNS-interception coexistence reconcile (only while the tunnel is up). Our one-shot
    # decision at setup_firewall time goes stale when a DPI/proxy tool starts AFTER us, when
    # dnsmasq wasn't up yet at boot, or when the DPI tool is later removed. Re-evaluate here —
    # cheap, idempotent — and catch the br0-side ":53 collision" that dns_ok (which probes
    # 127.0.0.1, bypassing the DNAT) can't see, WITHOUT a full VPN restart.
    if is_running; then
        if dns_intercept_active && { zapret_active || fw_dns_redirect_active || [ "$(get_setting awg_no_dns_intercept)" = "1" ]; }; then
            log_msg "WATCHDOG: co-resident DNS owner detected — removing our :53 interception (coexist)"
            disable_tunnel_dns   # tunnel-DNS is intercept-gated — drop it together (no-op if off)
            cleanup_dns_interception
        elif ! dns_intercept_active && intercept_wanted && dns_ok; then
            # dns_ok gate: only (re)install the hijack when the router actually resolves —
            # otherwise this would flap against the DNS fail-open below (install → fail-open
            # remove → install) every 5 minutes while the resolver is broken.
            log_msg "WATCHDOG: DNS interception now warranted (DPI gone / dnsmasq up) — installing"
            setup_dns_interception
        fi
    fi

    local reason=""
    if ! iface_exists "$IFACE"; then
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
        # transient resolver blip doesn't trigger anything.
        sleep 5
        if pidof dnsmasq >/dev/null 2>&1 && ! dns_ok; then
            # The tunnel itself passes traffic (tunnel_alive above) — only DNS is dead. A VPN
            # restart never fixes that (the old behavior looped a healthy tunnel through
            # stop/start every 5 min while the real fault was upstream DNS / a broken local
            # resolver). The client lockout is OUR :53 DNAT pinning them to the dead resolver
            # — cure it directly: drop the interception (fail-open) and keep the tunnel. The
            # reconcile above re-installs it (dns_ok-gated) once the resolver works again.
            log_msg "WATCHDOG: router DNS not resolving (tunnel passes traffic) — removing :53 interception (fail-open); check upstream DNS/dnsmasq"
            disable_tunnel_dns   # restore firmware upstreams too (no-op if the feature is off)
            cleanup_dns_interception
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
        # Triage snapshot BEFORE the teardown wipes it: handshake age + transfer distinguish
        # "endpoint stopped answering" (stale/no handshake — DPI killed the flow, server down)
        # from "tunnel up but traffic misrouted" (fresh handshake, RX growing) in the report.
        is_running && log_msg "  awg show: $("$AWG_BIN" show "$IFACE" 2>&1 | grep -iE 'latest handshake|transfer' | tr '\n' '|' | sed 's/|$//')"
        printf '%s\n%s\n' "$((fails + 1))" "$now" > "$wd_state" 2>/dev/null
        do_stop "" watchdog 2>/dev/null
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

# Resolve the opkg PACKAGE ARCH for this box, robust to a broken opkg (corrupted Entware —
# seen in the field). Ladder: (1) opkg's own db, picking the HIGHEST-priority arch (not the
# first line); (2) opkg.conf, which usually survives a broken opkg binary; (3) uname — where
# the KERNEL decides armv7-2.6 vs armv7-3.2 (that's exactly how Entware splits them; the old
# fallback always said armv7-2.6, which now also means the legacy Go-1.23 daemon). Plus a
# final guard: an armv7-3.2 pick on a 2.6.x kernel is impossible-to-run (its daemon needs
# Linux >= 3.2) — force armv7-2.6 there. The reverse (2.6 pkg on a newer kernel) is left
# alone: it runs fine and may be deliberate. Echoes the arch, or nothing if undecidable.
resolve_pkg_arch(){
    local a kver
    a=$(opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2!="all" {if ($3+0>=p){p=$3+0; n=$2}} END{print n}')
    [ -z "$a" ] && a=$(awk '$1=="arch" && $2!="all"{print $2; exit}' /opt/etc/opkg.conf 2>/dev/null)
    kver=$(uname -r)
    if [ -z "$a" ]; then
        case "$(uname -m)" in
            aarch64) a="aarch64-3.10" ;;
            armv7l|armv6l)
                case "$kver" in 2.6.*) a="armv7-2.6" ;; *) a="armv7-3.2" ;; esac ;;
        esac
    fi
    case "$a" in
        armv7-3.2) case "$kver" in 2.6.*) a="armv7-2.6" ;; esac ;;
    esac
    echo "$a"
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

    # Resolve a RUNNABLE opkg BEFORE we touch anything. opkg is an Entware-only binary in
    # /opt/bin; when the coreutils self-test failed (AWG_PATH_SANE=0) PATH was forced to
    # firmware-only, so /opt is off PATH and a bare `opkg` is "not found" (rc 127). THIS is
    # why "update via the web UI fails but SSH works": the httpd context inherits a poisoned
    # LD_LIBRARY_PATH that segfaults Entware grep/sed/awk (cured by the `unset` at the top of
    # this script since 1.2.46), an interactive SSH login doesn't — so over SSH the self-test
    # passes, /opt stays on PATH, and opkg runs. Resolve an absolute path (works even with
    # /opt off PATH) and, if opkg genuinely can't run, bail HERE — before stopping the VPN or
    # moving geo — so a doomed update never tears down a working tunnel for 60s+ then fails.
    local opkg_bin
    opkg_bin=$(which opkg 2>/dev/null)
    [ -x "$opkg_bin" ] || opkg_bin=/opt/bin/opkg
    [ -x "$opkg_bin" ] || opkg_bin=/opt/sbin/opkg
    if [ ! -x "$opkg_bin" ]; then
        log_msg "Update: ERROR opkg is not available in this context — cannot install (nothing changed; VPN left running)."
        if [ "$AWG_PATH_SANE" = 0 ]; then
            log_msg "  Cause: Entware coreutils failed the self-test, so /opt is off PATH (opkg lives in /opt/bin)."
            log_msg "  This is the httpd LD_LIBRARY_PATH quirk fixed in 1.2.46+ — that is why the web-UI update fails while SSH works."
        else
            log_msg "  Is the Entware USB mounted? (/opt/bin/opkg missing)."
        fi
        log_msg "  Update once over SSH to break the loop: curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh"
        rm -f "$tmp"
        update_status; return 1
    fi

    # COMMIT POINT: from here we WILL stop the VPN and run opkg. Block auto-start NOW — before
    # the first teardown — so the watchdog (*/5 cron) can't catch the stopped awg0 and race a
    # restart against the installer (do_watchdog early-returns on this flag; do_start blocks the
    # opkg-triggered S99 on it too). Previously this was set only just before opkg, leaving a
    # do_stop→(up to 60s dnsreload wait)→touch window in which the watchdog DID restart the VPN
    # mid-update. Every error/success path below clears it. (The opkg-not-found bail above is
    # BEFORE this point — it leaves the VPN running, so no flag to clear there.)
    touch /tmp/.awg_no_autostart
    # Same window, dnsmasq flavor: the stop → prerm → postinst → stop chain below kicks
    # 3-4 dnsmasq reload jobs, none of which rc can execute while it waits on THIS very
    # service-event — each would only burn 15s-block+drop cycles and hold the settle-waits
    # below for their full 60s. Swallow them into ONE deferred reload fired at the end
    # (dnsreload_defer_end on every post-commit exit path).
    dnsreload_defer_begin

    # Preserve geo lists across the upgrade unless "wipe before update" is on. The
    # package prerm runs 'rm -rf /opt/amneziawg', so move geo to a sibling dir (same
    # filesystem = instant rename, no extra space) that survives, and restore it after.
    local geo_bak="${AWG_DIR}_geobak"
    rm -rf "$geo_bak" 2>/dev/null
    if [ "$(get_setting awg_geo_wipe_update)" != "1" ] && [ -d "$GEO_DIR" ]; then
        mv "$GEO_DIR" "$geo_bak" 2>/dev/null && log_msg "Update: preserving geo lists"
    fi

    log_msg "Update: stopping VPN"
    do_stop "" update 2>/dev/null
    wait_for_pid_exit amneziawg-go 10
    # Let any PRE-update dnsmasq reload job settle before opkg runs the package prerm. Jobs
    # spawned after the defer window opened never take the lock (they mark PENDING and exit),
    # and an older in-flight job retires itself at its next rc-settle check — so this normally
    # clears in a second or two; the 60s cap only guards a job stuck mid-restart. (Rationale
    # unchanged: two concurrent `service restart_dnsmasq` storms during a memory-pressured
    # opkg can OOM/blackout the LAN on a low-RAM box — RT-AC68U, 256MB.)
    _i=0; while [ -d /tmp/.awg_dnsreload ] && [ $_i -lt 60 ]; do sleep 1; _i=$((_i + 1)); done
    # Preserve the connection history across the prerm's rm -rf of /opt/amneziawg. Stashed AFTER
    # the do_stop above, so the just-recorded "update" session close survives the upgrade too.
    rm -f "$CONN_HIST_BAK" 2>/dev/null
    [ -f "$CONN_HISTORY" ] && cp "$CONN_HISTORY" "$CONN_HIST_BAK" 2>/dev/null
    log_msg "Update: installing package via opkg"
    # --force-downgrade: opkg refuses to install an older version by default and, worse,
    # exits 0 while doing nothing ("Not downgrading package ... from X to Y") — so the
    # install looked successful but left the old version in place. The UI version picker
    # (awg_update_version) and manual .ipk upload both legitimately request a specific
    # (possibly older) version, so force it. For upgrades/reinstalls the flag is a no-op.
    local _oout
    if ! _oout=$("$opkg_bin" install --force-downgrade "$tmp" 2>&1) \
       && ! _oout=$("$opkg_bin" install --force-downgrade --force-architecture "$tmp" 2>&1); then
        log_msg "Update: ERROR opkg install failed — staying on v$AWG_VERSION"
        # Capture opkg's OWN output — a bare exit code hid the real reason (opkg not found,
        # a dependency error, a segfaulting maintainer script, a failing USB) and cost a
        # tester a debugging session. Collapse to one line, cap length for the log.
        [ -n "$_oout" ] && log_msg "  opkg: $(echo "$_oout" | tr '\n' '|' | cut -c1-400)"
        rm -f "$tmp" /tmp/.awg_no_autostart
        if [ -d "$geo_bak" ]; then mkdir -p "$AWG_DIR"; mv "$geo_bak" "$GEO_DIR" 2>/dev/null; fi
        conn_history_restore
        dnsreload_defer_end
        update_status; return 1
    fi
    # Post-install integrity gate: opkg can exit 0 yet write a 0-byte binary under memory
    # pressure on a low-RAM box (or a flaky USB truncates the write). The prerm already
    # removed the OLD package (see top of this function), so a silently-truncated install
    # would leave the router with NO working binary and do_start failing cryptically
    # (field-confirmed on RT-AC68U: a hung update + power-cycle left amneziawg-go=0B awg=0B).
    # Verify both are non-empty; if not, force-reinstall the SAME .ipk exactly once ($tmp is
    # still on disk — we haven't rm'd it yet), then re-verify.
    if [ ! -s "$AWG_GO" ] || [ ! -s "$AWG_BIN" ]; then
        log_msg "Update: WARNING binaries 0-byte/missing after install (amneziawg-go=$(elf_arch "$AWG_GO") awg=$(elf_arch "$AWG_BIN")) — retrying once with --force-reinstall"
        local _reout
        _reout=$("$opkg_bin" install --force-reinstall --force-downgrade "$tmp" 2>&1)
        [ -n "$_reout" ] && log_msg "  opkg: $(echo "$_reout" | tr '\n' '|')"
        if [ ! -s "$AWG_GO" ] || [ ! -s "$AWG_BIN" ]; then
            log_msg "Update: ERROR install left binaries truncated (amneziawg-go=$(elf_arch "$AWG_GO") awg=$(elf_arch "$AWG_BIN")) — likely an interrupted write on a low-RAM box or a failing USB drive."
            log_msg "  Reinstall to recover: curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh"
            rm -f "$tmp" /tmp/.awg_no_autostart
            if [ -d "$geo_bak" ]; then mkdir -p "$AWG_DIR"; mv "$geo_bak" "$GEO_DIR" 2>/dev/null; fi
            conn_history_restore
            dnsreload_defer_end
            update_status; return 1
        fi
        log_msg "Update: force-reinstall recovered the binaries"
    fi
    rm -f "$tmp"
    # Stop VPN if opkg's init script started it
    do_stop "" update 2>/dev/null
    wait_for_pid_exit amneziawg-go 10
    # Let this reload settle too before install_page / ensure_geo run (and before the resolver is
    # confirmed for the user), so the resolver is back up by the time the update reports complete.
    _i=0; while [ -d /tmp/.awg_dnsreload ] && [ $_i -lt 60 ]; do sleep 1; _i=$((_i + 1)); done
    rm -f /tmp/.awg_no_autostart
    # Restore preserved geo lists (if we moved them aside above)
    if [ -d "$geo_bak" ]; then
        rm -rf "$GEO_DIR" 2>/dev/null
        mkdir -p "$AWG_DIR"
        mv "$geo_bak" "$GEO_DIR" 2>/dev/null && log_msg "Update: geo lists restored"
    fi
    # Restore the connection history stashed before opkg (survives the prerm's rm -rf).
    conn_history_restore
    # Install page from new version
    /jffs/addons/amneziawg/amneziawg.sh install_page
    # Fire the ONE dnsmasq reload owed for the whole update (its job settles rc first, so
    # dnsmasq restarts once, right after this service-event returns — not 3-4 times).
    dnsreload_defer_end
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
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"no_data\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$b64"; update_status; return 1
    fi

    # Decode base64 text -> binary .ipk (busybox base64 -d, openssl fallback).
    if ! base64 -d "$b64" > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
        if ! openssl base64 -d -A -in "$b64" -out "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
            log_msg "Manual install: ERROR base64 decode failed"
            echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"decode_failed\"}" > "$AWG_UPLOAD_STATUS"
            rm -f "$b64" "$tmp"; update_status; return 1
        fi
    fi
    rm -f "$b64"

    got_len=$(wc -c < "$tmp" 2>/dev/null)
    if [ -n "$want_len" ] && [ "$got_len" != "$want_len" ]; then
        log_msg "Manual install: ERROR size mismatch (got ${got_len}, expected ${want_len})"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"size_mismatch\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi

    # An .ipk is a gzip-compressed tar. Decompress the WHOLE stream (reads to EOF and
    # verifies the trailing gzip CRC32/length), so any corruption or truncation that
    # slipped through the upload is caught here, BEFORE we touch opkg. gzip/gunzip is
    # always present (opkg itself needs it); try both applet spellings.
    if ! gzip -dc "$tmp" > /dev/null 2>&1 && ! gunzip -c "$tmp" > /dev/null 2>&1; then
        log_msg "Manual install: ERROR archive is corrupt (gzip CRC check failed)"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"corrupt\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi
    # Must be an opkg .ipk: a gzip tar that contains control.tar.gz (the last member, so a
    # successful listing also proves the archive decompressed fully).
    if ! tar tzf "$tmp" 2>/dev/null | grep -q 'control\.tar\.gz'; then
        log_msg "Manual install: ERROR not an opkg package (no control.tar.gz)"
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"not_ipk\"}" > "$AWG_UPLOAD_STATUS"
        rm -f "$tmp"; update_status; return 1
    fi

    log_msg "Manual install: package OK ($(human_size "$got_len")) — installing"
    if finalize_ipk_install "$tmp" "uploaded package"; then
        echo "{\"status\":\"installed\",\"tok\":\"$tok\"}" > "$AWG_UPLOAD_STATUS"
    else
        echo "{\"status\":\"install_err\",\"tok\":\"$tok\",\"code\":\"opkg_failed\"}" > "$AWG_UPLOAD_STATUS"
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
    pkg_arch=$(resolve_pkg_arch)
    if [ -z "$pkg_arch" ]; then
        log_msg "Update: ERROR unsupported architecture: $(uname -m) (kernel $(uname -r))"
        update_status; return 1
    fi
    log_msg "Update: package architecture $pkg_arch (kernel $(uname -r))"

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

    # --- Tear down current routing + firewall (mirror do_stop; drain = remove every copy) ---
    ipt_drain -D INPUT -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -i "$IFACE" -j ACCEPT
    ipt_drain -D FORWARD -o "$IFACE" -j ACCEPT
    cleanup_ipv6_block
    ipt_drain -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ipt_drain -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    local lan_net_old
    lan_net_old=$(get_lan_net)
    [ -n "$lan_net_old" ] && ipt_drain -t nat -D POSTROUTING -s "$lan_net_old" -o "$IFACE" -j MASQUERADE
    ipt_drain -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE
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

    iptables -C INPUT -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -C FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "$IFACE" -j ACCEPT
    setup_ipv6_block
    iptables -t mangle -C FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -C FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    if [ -n "$lan_net" ]; then
        iptables -t nat -C POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -I POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    else
        iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null \
            || iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE
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
        awgrestart)     do_restart ;;
        awgforceapply)
            # Force Apply: persist settings, then full restart (re-runs setconf +
            # complete route/firewall/geo rebuild via do_start)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(get_setting awg_iface_p1)" ]; do sleep 1; _wt=$((_wt+1)); done
            do_restart
            ensure_geo   # download configured-but-missing geo lists (bg), then re-apply
            ;;
        awgsaveconf)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(get_setting awg_iface_p1)" ]; do sleep 1; _wt=$((_wt+1)); done
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
        awganalyzestart) do_analyze_start ;;
        awganalyzestop)  do_analyze_stop ;;
        awgxraystop)     do_xray_stop ;;
        awgctfdisable)   do_ctf_disable ;;
    esac
}

# --- Main ---

# Rename any pre-1.1.89 credential-flavored config keys to neutral names before any command
# reads them (cheap no-op once migrated), so existing installs keep working after upgrade.
migrate_field_names
# Normalize a space-separated watchdog-hosts value (pre-1.2.54 saves) to commas before the
# page can read a truncated copy back and re-save it without the tail hosts.
migrate_watchdog_hosts

# Geo ipset name is configurable (so it can be shared with other connections/tools). Default
# awg_dst; sanitize to a valid ipset name (letters/digits/_.-, <=31 chars), else keep default.
_ipn=$(get_setting awg_ipset_name)
case "$_ipn" in ''|*[!A-Za-z0-9_.-]*) _ipn="" ;; esac
[ -n "$_ipn" ] && [ ${#_ipn} -le 31 ] && IPSET_NAME="$_ipn"

case "$1" in
    start)          do_start ;;
    boot_start)     do_boot_start ;;   # S99 init (boot/opkg): honors the awg_autostart toggle
    stop)           do_stop user ;;
    stop_auto)      do_stop "" deadman ;;   # internal: auto-rollback stop (deadman); keeps watchdog cron
    restart)        do_restart ;;
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
    analyze_start)  do_analyze_start ;;
    analyze_stop)   do_analyze_stop ;;
    ctf_status)     ctf_active && echo "CTF active (ctf_disable=$(nvram get ctf_disable 2>/dev/null))" || echo "CTF not active" ;;
    ctf_disable)    do_ctf_disable ;;
    *)              echo "Usage: $0 {start|stop|restart|status|diag|update_geo|download_geo|install_page|uninstall}" ;;
esac
