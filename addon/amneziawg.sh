#!/bin/sh
# =============================================================
# AmneziaWG addon backend for Asuswrt-Merlin
# Userspace amneziawg-go, per-device policy routing, GeoIP/GeoSite
# =============================================================

AWG_VERSION="1.5.26"
ADDON_DIR="/jffs/addons/amneziawg"
AWG_DIR="/opt/amneziawg"
CONF="$AWG_DIR/awg0.conf"
AWG_GO="$AWG_DIR/amneziawg-go"
# Canonical daemon path for CAPABILITY probing only. The server role re-points AWG_GO at
# its own `awgs-go` hardlink, and srv_generate_config runs BEFORE srv_ensure_binary creates
# that link — so probing $AWG_GO there finds nothing on a first start and silently drops
# every AmneziaWG 3.0 param from the generated server config (field-reproduced on the
# RT-AC66U_B1: "parameters are set but this build does not support them"). The hardlink is
# the same inode anyway, so its capabilities are identical. Never override this.
AWG_GO_CANON="$AWG_DIR/amneziawg-go"
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
STARTING_FLAG="/tmp/.awg_starting"
STOPPING_FLAG="/tmp/.awg_stopping"
GEO_BUSY_FLAG="/tmp/.awg_geo_busy"
# Boot-init liveness protocol (1.5.8). do_boot_start touches BOOT_MARKER FIRST THING — before
# any toggle/running check — so it answers "did the Entware init path invoke S99amneziawg at
# all this boot", which is what the services-start fallback (do_boot_guard) and diag need to
# tell a SKIPPED Entware start from a declined autostart. Field case (RT-BE92U @ Merlin
# 3006.102.8): the firmware-native Entware starter and the amtm/post-mount hook collided
# ("Entware: Not starting Entware services … Entware is already started" in syslog) and
# NEITHER ran the /opt/etc/init.d/S* start scripts — autostart silently dead, no status/
# watchdog crons, server tab stuck on «Загрузка…». tmpfs => both reset every boot.
BOOT_MARKER="/tmp/.awg_boot_start_ran"
BOOT_GUARD_STATE="/tmp/.awg_boot_guard_state"   # do_boot_guard verdict, shown in diag
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
AWG_PRIO_CHAIN="AWG_PRIO"   # priority-over-xray chain, hooked FIRST in mangle PREROUTING
LOCKDIR="/tmp/.awg_lock"
# Per-instance daemon telemetry files. Variables (not literals) so the SERVER role script
# (amneziawg_server.sh), which sources this file in lib mode and overrides IFACE/LOCKDIR/
# UI_LOG/…, gets its own copies — two concurrent daemons (client awg0 + server awgs0) must
# never truncate each other's launch log or overwrite each other's exit-status file.
DAEMON_LOG="/tmp/awg_daemon.log"
DAEMON_RC="/tmp/awg_daemon.rc"
# "<GOMEMLIMIT>|<pool cap>" the running daemon was ACTUALLY launched with (written by
# launch_daemon). A recompute while the tunnel is up would count the daemon's own commit
# against itself and quote a ceiling it never got — readers use this file instead.
DAEMON_TUNE="/tmp/awg_daemon.tune"
# Excerpt of the last Go crash trace (panic / fault). DAEMON_LOG is truncated on every
# launch, and the watchdog relaunches within minutes — without this copy the traceback of
# a crash worth reporting is gone before anyone reads the incident.
DAEMON_CRASH="/tmp/awg_daemon.crash"
# --- AWG server role (amneziawg_server.sh) — read-only coexistence constants ---
# The client script needs limited visibility into the server instance: per-peer policy
# routing (server peers are policy sources exactly like LAN devices), the mangle
# "peer-subnet -> direct" exclusion and the table-300 hairpin route. Server settings live
# under the awgs_ prefix — deliberately NOT matched by any `^awg_` pattern (4th char). The
# server script itself sources this file in lib mode (AWG_LIB_MODE=1) and overrides the
# instance globals; see the guard above the main dispatch.
AWGS_IFACE="awgs0"
AWGS_SCRIPT="$ADDON_DIR/amneziawg_server.sh"
GEOLOCK="/tmp/.awg_geolock"   # long-running background geo-download mutex (separate from LOCKDIR)
V2FLY_GEOIP_BASE="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text"

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
    # Neutralize ASP-tag openers ("<" followed by "%" or "#") ONCE, for both sinks: the journal
    # lands in /www/user/awg_log.htm directly and, via syslog, in the status JSON and the diag —
    # every .htm/.asp under /www/user runs through the firmware's ASP evaluator, which LIVELOCKS
    # the single-threaded httpd on an unterminated "< %" and swaps "< #...# >" for dictionary text.
    # User text reaches this function (profile names, pasted endpoints, dnsmasq errors). Fork-free
    # in the common (clean) case: the case-guard runs before any sed.
    local _m="$1"
    case "$_m" in *\<[%#]*) _m=$(printf '%s' "$_m" | sed 's/<\([%#]\)/< \1/g') ;; esac
    logger -t "$SCRIPT_NAME" "$_m"
    # Real-time on-page log (web-readable, polled by the UI); reset per user action.
    echo "$(date '+%Y-%m-%d %H:%M:%S') $_m" >> "$UI_LOG" 2>/dev/null
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

# Read one custom_settings value exactly as the FIRMWARE's own reader sees it. Merlin writes each
# record with snprintf(line, 3040, "%s %s\n"): a key+value longer than 3037 bytes is cut at 3039
# bytes AND LOSES ITS NEWLINE, so the NEXT key lands glued onto the same physical line. The page's
# reader (fgets(line, 3040)) re-syncs exactly at that 3039-byte boundary and still sees the glued
# key; a plain per-line `$1==key` never did (field 2026-09, 1.5.22: a long «Свои файлы» value
# swallowed awg_geo_custom_urls — the page showed the URL, the router never fetched it). So split
# every over-long physical line into 3039-byte records first, then match "key " at record start.
# A key present twice resolves to the LAST copy, like the page (json-c: the later add replaces).
# LC_ALL=C: byte offsets, whichever awk (busybox / Entware gawk) is first on PATH.
get_setting(){
    LC_ALL=C awk -v key="$1" '
        function hit(r) { if (index(r, key " ") == 1) { v = substr(r, length(key) + 2); f = 1 } }
        { r = $0
          while (length(r) > 3039) { hit(substr(r, 1, 3039)); r = substr(r, 3040) }
          hit(r) }
        END { if (f) print v }' "$SETTINGS" 2>/dev/null
}

# Is $2 (the value of setting $1) one the firmware cut? Two fingerprints: its writer cuts a record
# at 3039 bytes, leaving exactly 3038-len(key) value bytes; and the pre-1.5.24 page, which could
# only read back 2999 bytes, re-saved such a cut view re-encoded — 2999..3001 chars. (An intact
# 3000/3001-char value is flagged too; the page itself can only show it cut, so nothing is lost
# that the next page save wouldn't lose anyway.)
setting_is_cut(){
    case "${#2}" in 2999|3000|3001) return 0 ;; esac
    [ "${#2}" -eq $((3038 - ${#1})) ]
}

# Base64-decode stdin -> stdout. Merlin's busybox is built WITHOUT the base64 applet (config_base:
# "# CONFIG_BASE64 is not set", every branch) and a default Entware adds none — so the bare
# `base64 -d 2>/dev/null` this script used to call decoded NOTHING on such boxes, silently:
# GeoCustom URL sources were never fetched, pasted files never loaded, and I1-I5 never reached
# awg0.conf (bench GT-AX6000 @ 3006.102.8: "base64: not found"). Chain: base64 -> the firmware's
# own openssl (always shipped) -> a pure-awk decoder. Non-alphabet bytes are ignored, the stream
# ends at its first '=' (openssl reads interior padding differently from base64/awk), and the
# padding is then REPAIRED ("forgiving base64": a 2/3-char tail gets its '='s back, a lone
# 1-char tail is dropped) — so a value the firmware truncated, even between its two '=', still
# decodes every byte it holds, identically on all three. The awk path is text-only (a NUL byte may be lost on some
# busybox builds) — every caller decodes text. Callers that decode in a pipeline or $( ) should
# run b64d_init first in their own shell, so the probe result is inherited, not re-run per call.
b64d_init(){
    [ -n "$AWG_B64D" ] && return 0
    if [ "$(echo aGk= | base64 -d 2>/dev/null)" = hi ]; then AWG_B64D=base64
    elif [ "$(echo aGk= | openssl base64 -d -A 2>/dev/null)" = hi ]; then AWG_B64D=openssl
    else AWG_B64D=awk; fi
}
b64d(){
    b64d_init
    LC_ALL=C awk '{ gsub(/[^A-Za-z0-9+\/=]/, ""); s = s $0 }
        END { p = index(s, "="); if (p > 0) s = substr(s, 1, p - 1)
              n = length(s); r = n % 4
              if (r == 1) s = substr(s, 1, n - 1); else if (r == 2) s = s "=="; else if (r == 3) s = s "="
              if (s != "") print s }' |
    case "$AWG_B64D" in
        base64)  base64 -d 2>/dev/null ;;
        openssl) openssl base64 -d -A 2>/dev/null ;;
        *) LC_ALL=C awk '
            BEGIN { a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
                    for (i = 0; i < 64; i++) v[substr(a, i + 1, 1)] = i }
            { s = s $0 }
            END { n = length(s)
                  for (i = 1; i + 3 <= n; i += 4) {
                      c3 = substr(s, i + 2, 1); c4 = substr(s, i + 3, 1)
                      x = v[substr(s, i, 1)] * 262144 + v[substr(s, i + 1, 1)] * 4096 + v[c3] * 64 + v[c4]
                      printf "%c", int(x / 65536)
                      if (c3 != "=") printf "%c", int(x / 256) % 256
                      if (c4 != "=") printf "%c", x % 256
                  } }' ;;
    esac
}

# First 16 hex of sha256("<url>\n") — the shared-pool file name of a GeoCustom URL source. Falls
# back to the firmware's openssl where busybox has no sha256sum applet; same digest, so files
# already downloaded under the old names keep them.
url_key(){
    local h
    h=$(echo "$1" | sha256sum 2>/dev/null | awk '{print $1}')
    [ -n "$h" ] || h=$(echo "$1" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}')
    echo "$h" | cut -c1-16
}

# Install the rewritten settings file $1 only if it holds exactly $2 lines. busybox grep/awk can
# exit 0 after a FAILED write (ENOSPC on a full JFFS), and a blind `> tmp && mv` then installed a
# truncated or empty custom_settings.txt — every addon's settings gone. Refuse, keep the original.
settings_commit(){
    local tmp="$1" want="$2" got
    got=$(wc -l < "$tmp" 2>/dev/null)
    if [ -n "$got" ] && [ "$got" -eq "${want:-0}" ] 2>/dev/null && mv "$tmp" "$SETTINGS" 2>/dev/null; then
        return 0
    fi
    rm -f "$tmp" 2>/dev/null
    log_msg "WARNING: could not rewrite $SETTINGS (disk full?) — left it unchanged"
    return 1
}

# The writers below edit custom_settings.txt by PHYSICAL line (grep -v "^key "), but get_setting
# also sees a key the firmware glued onto an over-long line (see get_setting) — which a per-line
# writer can never match: clear_setting was a no-op for it, and set_setting/migrate_watchdog_hosts
# appended a second copy, so migrate_watchdog_hosts would have rewritten the file on every run,
# i.e. every minute. Before editing, re-frame the file the way the firmware reader does: every line
# over 3039 bytes becomes 3039-byte records, one per line. A cut value stays cut (that data never
# reached the flash), but each glued key is a normal line again — exactly what the page already
# sees. No rewrite at all when nothing is glued. The re-framed copy must carry every byte of the
# original (only newlines are added) or it is not installed — see settings_commit for why.
settings_unglue(){
    local tmp
    [ -f "$SETTINGS" ] || return 0
    LC_ALL=C awk 'length($0) > 3039 { f = 1; exit } END { exit !f }' "$SETTINGS" 2>/dev/null || return 0
    tmp="$SETTINGS.awgtmp.$$"
    LC_ALL=C awk '{ r = $0; while (length(r) > 3039) { print substr(r, 1, 3039); r = substr(r, 3040) }
                    if (r != "") print r }' "$SETTINGS" > "$tmp" 2>/dev/null
    if [ -s "$tmp" ] && [ "$(tr -d '\n' < "$tmp" | wc -c)" -eq "$(tr -d '\n' < "$SETTINGS" | wc -c)" ] \
       && mv "$tmp" "$SETTINGS" 2>/dev/null; then
        return 0
    fi
    rm -f "$tmp" 2>/dev/null
    log_msg "WARNING: could not re-frame $SETTINGS (disk full?) — left it unchanged"
    return 1
}

# Remove a custom-settings line. Used for one-shot keys (e.g. awg_update_version) so a
# version pinned for a single update can never pin a later automatic update.
clear_setting(){
    local key="$1" tmp
    [ -f "$SETTINGS" ] || return 0
    settings_unglue || return 1
    grep -q "^$key " "$SETTINGS" 2>/dev/null || return 0
    tmp="$SETTINGS.awgtmp.$$"
    grep -v "^$key " "$SETTINGS" > "$tmp" 2>/dev/null
    settings_commit "$tmp" "$(grep -vc "^$key " "$SETTINGS" 2>/dev/null)"
}

# Rename one custom_settings key, carrying its value to $new (only if $new isn't already
# set) and dropping the old line so the value isn't left duplicated. Idempotent.
_awg_rename_setting(){
    local old="$1" new="$2" val tmp
    [ -f "$SETTINGS" ] || return 0
    grep -q "$old " "$SETTINGS" 2>/dev/null || return 0     # nothing stored under the old key (glued included)
    settings_unglue || return 1
    grep -q "^$old " "$SETTINGS" 2>/dev/null || return 0
    if grep -q "^$new " "$SETTINGS" 2>/dev/null; then
        clear_setting "$old"                               # new key already set -> just drop the stale line
        return 0
    fi
    val=$(get_setting "$old")
    tmp="$SETTINGS.awgtmp.$$"
    { grep -v "^$old " "$SETTINGS"; echo "$new $val"; } > "$tmp" 2>/dev/null
    settings_commit "$tmp" $(( $(grep -vc "^$old " "$SETTINGS" 2>/dev/null) + 1 ))
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
    settings_unglue || return 1   # a glued copy would survive the grep -v below and re-trigger this forever
    tmp="$SETTINGS.awgtmp.$$"
    { grep -v "^awg_watchdog_hosts " "$SETTINGS"; echo "awg_watchdog_hosts $val"; } > "$tmp" 2>/dev/null
    settings_commit "$tmp" $(( $(grep -vc "^awg_watchdog_hosts " "$SETTINGS" 2>/dev/null) + 1 ))
}

# The store rescues that must land before a page reads the store back and re-saves a cut view
# (every page POSTs the whole object it loaded). ONE framing-aware awk pass detects all three, so
# a clean store costs a single awk per invocation — both dispatches run this first, i.e. every
# minute from the status crons. It prints a flag per defect found; nothing = a no-op:
#  w  whitespace inside the AWG-server peer store (awgs_peers + its awgs_peers1..10 chunks),
#     rewritten to '_' below. Same class as migrate_watchdog_hosts, with a worse blast radius: the
#     firmware stores a spaced value intact, but the page's read-back (sscanf "%2999s") cuts it at
#     the FIRST whitespace — one peer named "My phone" cut the WHOLE store at "My", and the next
#     save of EITHER page persisted the cut. The server page now maps whitespace in names to '_';
#     this rescues stores saved before that. LENGTH-PRESERVING (one byte for one byte), so it
#     never moves a chunk boundary — the o pass below judges the sizes.
#  o  a peer-store chunk over 2900 bytes — the last one included: nothing since 1.5.26 writes one,
#     and a last chunk over 2999 bytes is read back cut too (silently: its tail is e.g. the psk) —
#     see _srv_peers_rechunk. Walks the chunks the way the readers do (awgs_peers, then 1..10 up
#     to the first empty one); last copy wins. A too-SHORT chunk is left alone on purpose: no
#     writer makes one, it is a cut view some page re-saved, and the page's chunk check is the
#     only thing that still notices that — re-splitting would hide the damage, not repair it.
#  n  a raw config-profile name holding whitespace — see migrate_profile_names.
# `grep -c ''` counts an unterminated last line too (a record the firmware cut at 3039 bytes
# loses its newline) — awk newline-terminates every line it prints, so the counts must match.
migrate_server_peers(){
    local tmp flags
    [ -f "$SETTINGS" ] || return 0
    flags=$(LC_ALL=C awk '
        function scan(r,   sp, k, v) { sp = index(r, " "); if (sp < 2) return; k = substr(r, 1, sp - 1)
                                       if (k ~ /^awgs_peers([1-9]|10)?$/) { v = substr(r, sp + 1); pk[k] = v; if (v ~ /[[:space:]]/) w = "w" }
                                       else if (k ~ /^awg_pf[1-5]_name$/ && substr(r, sp + 1) ~ /[[:space:]]/) n = "n" }
        { r = $0; while (length(r) > 3039) { scan(substr(r, 1, 3039)); r = substr(r, 3040) }
          scan(r) }
        END { for (i = 0; i <= 10; i++) { k = "awgs_peers" (i ? i : ""); if (pk[k] == "") break
                  if (length(pk[k]) > 2900) o = "o" }
              printf "%s%s%s", w, o, n }' "$SETTINGS" 2>/dev/null)
    [ -n "$flags" ] || return 0
    case "$flags" in *n*) migrate_profile_names ;; esac
    case "$flags" in *w*)
        settings_unglue || return 1   # a glued chunk must be its own line before the per-line rewrite
        tmp="$SETTINGS.awgtmp.$$"
        LC_ALL=C awk '{ sp = index($0, " "); k = (sp > 1) ? substr($0, 1, sp - 1) : ""
                        if (k ~ /^awgs_peers([1-9]|10)?$/) { v = substr($0, sp + 1); gsub(/[[:space:]]/, "_", v); print k " " v }
                        else print }' "$SETTINGS" > "$tmp" 2>/dev/null
        settings_commit "$tmp" "$(grep -c '' "$SETTINGS" 2>/dev/null)" || return 1
        log_msg "AWG server peer store: whitespace in peer names replaced by '_' (the settings read-back cut the store at the first space)"
    esac
    case "$flags" in *o*) _srv_peers_rechunk ;; esac
    return 0
}

# Re-split the peer store into chunks of at most 2900 BYTES, never inside a UTF-8 character —
# byte for byte what the 1.5.26 page writes (awgsSplitBytes: greedy, so every chunk but the last
# is 2897-2900 bytes, the only sizes its chunk check accepts). Pages up to 1.5.25 cut the store
# every 2900 CHARACTERS: ~17 peers with Cyrillic names made a chunk over 2999 bytes, which the
# page reads back cut, so the boundary peer (in the last chunk: e.g. its psk) lost its tail on
# the next save of either page — and the 1.5.26 page's chunk check refuses every server save
# instead, a lockout only SSH could lift. The readers (srv_peers_raw, server_peer_policy_entries,
# the page) just concatenate the chunks, so moving the boundaries is lossless for an intact store.
# A store the firmware already cut lost that data for good — and the re-split would erase the only
# evidence the page has of it: the page finds a cut junction (and flags the entry across it,
# whatever its field count) from the chunk SIZES alone, which this pass normalizes. So the cut is
# judged HERE, per chain chunk, by the fingerprints setting_is_cut uses: its writer left exactly
# 3038-len(key) bytes, or a page (a client Apply) re-saved the 2999-byte read-back view — a
# character that view split re-encoded as U+FFFD, up to 3001 bytes; that U+FFFD is dropped. The
# entry spanning such a junction (the chunk's end, the list's end for the last one) glues its HEAD
# (what the cut chunk kept) to a TAIL resumed past the lost bytes — from anywhere in a peer, a
# private key or psk included. Whole, it must meet the page's own shape (serializePeers: 8-9
# fields, a dotted-quad IP, the policy/mode/flag tokens, 44-char keys); one that does is KEPT, with
# a softer WARNING: a cut inside the name still leaves a working peer, and the fingerprint can hit
# an intact chunk too (3028 bytes that only lost the record's newline, a 3000-byte one the page
# could not read whole). One that does not is split at the junction and each side is judged ON ITS
# OWN — a stub, a label, a journal line takes nothing from the tail unless the tail meets the shape
# by itself (then its text up to the first '|' is provably a name: every other field is followed
# by a token, a key or the flag, never by a dotted-quad IP. Found in the 1.5.26 review: a head
# holding no '|' took the private key after the junction as its name — into the store, the
# journal and the syslog the diag carries):
#  - the head is CUT DOWN to its name and IP — the IP only when its closing '|' survived too (one
#    the cut ran into may read as a wrong address: 10.9.0.1 of 10.9.0.18), a lone name fragment
#    gets a '|' so the page cannot take it for a whitespace cut. Left whole, the page showed it as
#    a healthy peer (a 36-char psk, two peers merged into one) and its next save persisted it;
#    with fewer than 8 fields its own damaged-entry check takes over again — the red banner names
#    it (same label: name + IP) and the next server save drops it once the user confirms. Removing
#    it here instead would delete user data with no trace but a journal line the next user action
#    resets. A head that meets the shape with all three keys (the cut fell after its psk) is kept;
#  - the tail is KEPT as a peer of its own when it meets the shape: the lost bytes ended inside
#    the next peer's name, its IP and keys all survived (glued to the head, it was cut down with it
#    and no line named it). Anything else is DROPPED: it holds no name or whole IP of its own — at
#    most keys and an IP fragment, which no peer can be rebuilt from.
# Each judgement is a WARNING. Bytes that are not valid UTF-8 (a character the writer's cut split
# in two) are DROPPED: the page would decode each to U+FFFD, 3 bytes on its next save, and read
# the chunk as oversize again. Leftover chunk keys (orphans past the first empty one included) are
# removed. Refuses — store untouched — when the result would need more than the 11 chunk keys
# (impossible under the 8 KB POST cap).
_srv_peers_rechunk(){
    local out rc tmp n keep notes
    settings_unglue || return 1   # after this every record is its own line: no framing needed below
    out=$(LC_ALL=C awk '
        BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
        function key_ok(x) { return length(x) == 44 && x ~ /^[A-Za-z0-9+\/]+=$/ }   # a cut changes the length, not the alphabet
        function ip_ok(x,   q, j) { if (split(x, q, ".") != 4) return 0
                                    for (j = 1; j <= 4; j++) if (q[j] !~ /^[0-9]+$/ || length(q[j]) > 3 || q[j] + 0 > 255) return 0
                                    return 1 }
        function peer_ok(e,   f, m) { m = split(e, f, "|")
                                      return (m == 8 || m == 9) && ip_ok(f[2]) && f[3] ~ /^(direct|vpn_all|vpn_geo(_[0-9]+)?)?$/ &&
                                             f[4] ~ /^(full|lan)?$/ && f[5] ~ /^[01]$/ && key_ok(f[6]) &&
                                             (f[7] == "" || key_ok(f[7])) && (f[8] == "" || key_ok(f[8])) && (m == 8 || f[9] ~ /^[01]?$/) }
        # A head cut right after the "|" that ends its privkey meets the shape too (the psk is optional): kept only with a psk.
        function keys_whole(e,   f) { return peer_ok(e) && split(e, f, "|") >= 8 && f[8] != "" }
        # The page label (awgsPeerLabel): the (partial) name, 24 characters at most, + the IP if it survived.
        function label(e,   f, nm, i, x, cn) { split(e, f, "|"); nm = ""; cn = 0
                                          for (i = 1; i <= length(f[1]); i++) { x = substr(f[1], i, 1)
                                              if ((ord[x] < 128 || ord[x] >= 192) && ++cn > 24) { nm = nm "..."; break }
                                              nm = nm x }
                                          return "\047" (nm == "" ? "?" : nm) "\047" (ip_ok(f[2]) ? " (" f[2] ")" : "") }
        { sp = index($0, " "); if (sp < 2) next; k = substr($0, 1, sp - 1)
          if (k ~ /^awgs_peers([1-9]|10)?$/) pk[k] = substr($0, sp + 1) }
        END { s = ""; nj = 0
              for (i = 0; i <= 10; i++) { k = "awgs_peers" (i ? i : ""); v = pk[k]; if (v == "") break
                  L = length(v); cut = (L == 3038 - length(k) || (L >= 2999 && L <= 3001))
                  if (cut && L <= 3001 && substr(v, L - 2) == "\357\277\275") v = substr(v, 1, L - 3)
                  s = s v
                  if (cut) { jk[++nj] = k; jl[nj] = L; jb[nj] = length(s)   # jb: bytes of s before the junction
                             # ju: UTF-16 units kept (what the old page split by: a 4-byte char counts 2).
                             # A non-last 1.5.25 chunk that lost nothing holds exactly 2900 of them.
                             u = 0; nb = length(v)
                             for (x = 1; x <= nb; x++) { o = ord[substr(v, x, 1)]; if (o >= 240) u += 2; else if (o < 128 || o >= 192) u++ }
                             ju[nj] = u } }
              if (s == "") exit 1
              # Validity as a browser decodes it (WHATWG): the lead byte sets the length and the
              # range of the 2nd byte (no overlongs, no surrogates, nothing past U+10FFFF).
              n = split(s, b, ""); nc = 0; kb = 0; bad = 0; q = 1
              for (i = 1; i <= n; ) {
                  while (q <= nj && jb[q] < i) jc[q++] = nc   # jc: characters kept before the junction
                  o = ord[b[i]]; w = (o < 128) ? 1 : (o < 194) ? 0 : (o < 224) ? 2 : (o < 240) ? 3 : (o < 245) ? 4 : 0
                  lo = 128; hi = 191
                  if (o == 224) lo = 160; else if (o == 237) hi = 159; else if (o == 240) lo = 144; else if (o == 244) hi = 143
                  ok = (w > 0 && i + w - 1 <= n)
                  for (j = 1; ok && j < w; j++) { c = ord[b[i + j]]; if (c < lo || c > hi) ok = 0; lo = 128; hi = 191 }
                  if (!ok) { bad++; i++; continue }
                  ch = b[i]; for (j = 1; j < w; j++) ch = ch b[i + j]
                  i += w; cs[++nc] = ch; kb += w
              }
              if (kb > 11 * 2900) exit 1   # can never fit the 11 keys: refuse before the per-junction scans
              while (q <= nj) jc[q++] = nc
              # The entry across each cut junction, the last junction first (gone[] = chars cut off,
              # add[i] = ASCII put in after char i, nosep[a] = the ";" at a taken out). Entries at two
              # junctions never overlap: a cut chunk holds 750+ chars, a judged entry at most 600.
              nn = 0
              for (q = nj; q >= 1; q--) {
                  j = jc[q]
                  for (a = j; a > 0 && (cs[a] != ";" || (a in gone)); a--) ;
                  for (z = j + 1; z <= nc && (cs[z] != ";" || (z in gone)); z++) ;
                  what = "chunk " jk[q] " (" jl[q] " bytes)"
                  # a real entry is under 300 bytes; a longer one is no peer (and building it would cost O(n^2))
                  if (z - a > 600) { note[++nn] = what " looks cut by the firmware inside an entry too long to be a peer — check the list on the AWG server page"; continue }
                  h = ""; for (i = a + 1; i <= j; i++) if (!(i in gone)) h = h cs[i]   # the head: what the cut chunk kept
                  t = ""; for (i = j + 1; i < z; i++) if (!(i in gone)) t = t cs[i]    # the tail: past the lost bytes
                  if (h t == "") { note[++nn] = what " looks cut by the firmware between two peers — a peer missing from the list is gone; re-create it on the AWG server page"; continue }
                  # A whole-looking entry is kept as it is only when it cannot be a splice of two
                  # peers: nothing after it (t empty), nothing lost at the junction (an intact chunk
                  # that merely matches the cut fingerprint), or a junction inside the NAME (no "|"
                  # in the head: the IP and every key then come from one peer). Otherwise a pass
                  # means the lost bytes were exactly one entry and the fields past the junction
                  # belong to the NEXT peer (its privkey/psk under the pubkey of this one) — judge apart.
                  if (peer_ok(h t) && (t == "" || ju[q] == 2900 || index(h, "|") == 0)) { note[++nn] = what " looks cut by the firmware, but the peer at that point, " label(h t) ", still reads as complete — if its name or tunnel IP is wrong, re-create it on the AWG server page"; continue }
                  # Apart from here on: nothing of the tail may reach the stub or the label of the head.
                  tn = ""
                  if (h == "") m = what " had been cut by the firmware between two peers"
                  else if (keys_whole(h)) m = what " had been cut by the firmware right after peer " label(h) ", which still reads as complete — kept it; check its settings on the AWG server page"
                  else {
                      # Cut down to name|ip — fewer than 8 fields is the shape the page flags itself
                      # (same label, but listed as damaged, not healthy). p1/p2: the 1st/2nd "|" of the head.
                      p1 = p2 = 0
                      for (i = a + 1; i <= j && !p2; i++) if (!(i in gone) && cs[i] == "|") { if (p1) p2 = i; else p1 = i }
                      for (i = (p2 ? p2 : p1 ? p1 + 1 : j + 1); i <= j; i++) gone[i] = 1
                      st = ""; for (i = a + 1; i <= j; i++) if (!(i in gone)) st = st cs[i]
                      if (!p1) { add[j] = "|"; st = st "|" }
                      m = what " had been cut by the firmware inside peer " label(st) " — cut that entry down to its name and IP, so the AWG server page lists it as damaged (its next save drops it once you confirm); re-create the peer there"
                  }
                  if (h != "" && peer_ok(t)) {
                      add[j] = add[j] ";"
                      tn = what ": the peer right after that cut, " label(t) ", still reads as complete — kept it as a peer of its own (its name may have lost its beginning); check it on the AWG server page"
                  } else if (t != "") {
                      for (i = j + 1; i < z; i++) gone[i] = 1
                      if (h == "") nosep[a] = 1   # a = j here: the ";" the cut chunk ended with (else an empty entry is left)
                      m = m "; the rest after the cut held no name or whole IP of its own and was dropped — " (h == "" ? "a peer missing from the list is gone; re-create it on the AWG server page" : "re-create any other peer missing from the list too")
                  }
                  note[++nn] = m; if (tn != "") note[++nn] = tn
              }
              np = 0; p = ""; pl = 0
              for (i = 1; i <= nc; i++) {
                  if (!(i in gone) && !(i in nosep)) { w = length(cs[i]); if (pl + w > 2900) { pc[np++] = p; p = ""; pl = 0 }
                                                       p = p cs[i]; pl += w }
                  if (i in add) for (x = 1; x <= length(add[i]); x++) { if (pl + 1 > 2900) { pc[np++] = p; p = ""; pl = 0 }
                                                                        p = p substr(add[i], x, 1); pl++ } }
              if (p != "") pc[np++] = p
              if (np < 1 || np > 11) exit 1
              for (i = 0; i < np; i++) print "awgs_peers" (i ? i : "") " " pc[i]
              for (i = 1; i <= nn; i++) print "! WARNING: AWG server peer store: " note[i]
              exit (bad ? 3 : 0) }' "$SETTINGS" 2>/dev/null); rc=$?
    { [ "$rc" = 0 ] || [ "$rc" = 3 ]; } || return 0
    notes=$(printf '%s\n' "$out" | sed -n 's/^! //p')
    out=$(printf '%s\n' "$out" | grep '^awgs_peers')
    case "$out" in "awgs_peers "*) ;; *) return 0 ;; esac
    n=$(printf '%s\n' "$out" | grep -c '')
    # The lines kept, counted BEFORE the rewrite: an unreadable store must not turn into a store
    # holding nothing but the new chunks (settings_commit only checks the count it is given).
    keep=$(LC_ALL=C grep -Evc '^awgs_peers([1-9]|10)? ' "$SETTINGS" 2>/dev/null)
    case "$keep" in ''|*[!0-9]*) return 1 ;; esac
    tmp="$SETTINGS.awgtmp.$$"
    { LC_ALL=C grep -Ev '^awgs_peers([1-9]|10)? ' "$SETTINGS"; printf '%s\n' "$out"; } > "$tmp" 2>/dev/null
    settings_commit "$tmp" $((keep + n)) || return 1
    log_msg "AWG server peer store: re-split into $n chunk(s) of at most 2900 bytes (pages up to 1.5.25 split it by characters; a chunk over 2999 bytes reads back cut)"
    [ "$rc" = 3 ] && log_msg "WARNING: AWG server peer store: dropped bytes that were not valid UTF-8 (a character the firmware cut in two) — check the peer list on the AWG server page"
    [ -n "$notes" ] && printf '%s\n' "$notes" | while IFS= read -r l; do [ -n "$l" ] && log_msg "$l"; done
    return 0
}

# Rewrite legacy RAW config-profile names (awg_pf1..5_name) to the page's C4 encoding: '%' ->
# %25, trimmed, every whitespace run -> %20. Same class as migrate_watchdog_hosts: the firmware
# stores "Home NL" intact, but its read-back cuts the value at the first whitespace, so the next
# save of any page but the client page (the server page, another addon — each POSTs the whole
# store it read back) wrote "Home" and the tail was gone for good; the client page's own recovery
# (pfRecoverLegacyNames) only helps while that page is the first to save. No "already encoded"
# skip: the encoder never emits whitespace, so a stored name holding any is raw text and is
# encoded WHOLE — a raw '%' ("50% off") must become %25, else the decode (pf_scan: %20 then %25;
# the page: one pass) would turn a raw "%20" into a space. Detection lives in migrate_server_peers'
# shared pass; this is the rewrite, run only when that pass flagged a name. Line count is kept (an
# all-blank name keeps its line with an empty value — the reader skips it like an absent key).
migrate_profile_names(){
    local tmp
    settings_unglue || return 1   # a glued name must be its own line before the per-line rewrite
    tmp="$SETTINGS.awgtmp.$$"
    LC_ALL=C awk '{ sp = index($0, " "); k = (sp > 1) ? substr($0, 1, sp - 1) : ""
                    if (k ~ /^awg_pf[1-5]_name$/) { v = substr($0, sp + 1)
                        if (v ~ /[[:space:]]/) { gsub(/%/, "%25", v); sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
                                                 gsub(/[[:space:]]+/, "%20", v); print k " " v; next } }
                    print }' "$SETTINGS" > "$tmp" 2>/dev/null
    settings_commit "$tmp" "$(grep -c '' "$SETTINGS" 2>/dev/null)" \
        && log_msg "Config profile names: spaces now stored as %20 (the settings read-back cut a name at its first space)"
}

# Write (add or replace) one custom-settings line — the backend counterpart of the page's
# Apply for the FEW keys the router itself owns (today: awg_profile_active from the CLI
# profile switch). Same temp+rename shape as clear_setting; on the rare race with an httpd
# settings POST the last writer wins — acceptable for a manual, one-shot key.
set_setting(){
    local key="$1" val="$2" tmp n=0
    settings_unglue || return 1
    tmp="$SETTINGS.awgtmp.$$"
    { grep -v "^$key " "$SETTINGS" 2>/dev/null; echo "$key $val"; } > "$tmp" 2>/dev/null
    [ -f "$SETTINGS" ] && n=$(grep -vc "^$key " "$SETTINGS" 2>/dev/null)
    settings_commit "$tmp" $(( ${n:-0} + 1 ))
}

# =============================================================
# Config profiles (multi-config client)
# A "profile" is a numbered slot holding ONE complete client config (keys, endpoint, DNS,
# obfuscation incl. the chunked initdata). Slot 1 stores its DATA under the legacy
# unsuffixed keys (awg_iface_p1, …) so existing installs need ZERO migration; slots
# 2..AWG_PF_MAX use the awg_pf<N>_ prefix — still matched by every ^awg_ pattern, so the
# save/uninstall machinery is untouched. Per-slot META (name, failover participation) always
# lives under awg_pf<N>_, slot 1 included: pf_key() is the ONLY place that knows the split.
# ACTIVE slot resolution: awg_profile_active is the USER's persisted choice (written by the
# page's switch POST / the CLI); /tmp/.awg_profile_override is the FAILOVER engine's runtime
# pointer — deliberately kept OFF the settings file, so an auto-switch never fights the
# page's full-object settings POST (a stale open tab would silently revert a persisted
# pointer) and a reboot naturally falls back to the user's primary profile.
# NUMBERING: stored slot numbers are STABLE — nothing ever renumbers them. Everything a USER
# reads (journal, incidents, CLI) names a profile by its ORDINAL instead: the 1-based position
# among CONFIGURED slots in slot order — exactly what the page's profile bar shows (slot 3 is
# "#2" while slot 2 is empty). Only diag prints the slot next to it ("slot 3 = #2"). Printing
# slot numbers ("profile 3", the status row's "(3/2)") named things the user could not find.
AWG_PF_MAX=5
PF_OVERRIDE="/tmp/.awg_profile_override"    # "<slot> <fp>" — see profile_resolve
FAILOVER_STATE="/tmp/.awg_failover_state"   # "<circle_start_slot> <hops>" while a failover incident is walking the circle
RUNNING_PF="/tmp/.awg_running_pf"           # "<slot> <fp>" the RUNNING daemon was built from (do_start; do_stop removes it)
SWITCH_REQ="/tmp/.awg_switch_req"           # "<slot> <epoch>" while an ACCEPTED profile switch restarts (status "switch_req")

pf_key(){
    # $1 = slot, $2 = field. META fields are always slot-prefixed; DATA fields of slot 1 keep
    # their legacy unsuffixed names (initdata chunk fields like initdata7 included).
    case "$2" in
        name|fo) echo "awg_pf$1_$2" ;;
        *) if [ "$1" = "1" ]; then echo "awg_$2"; else echo "awg_pf$1_$2"; fi ;;
    esac
}

pf_slot_get(){ get_setting "$(pf_key "$1" "$2")"; }

# A slot is "configured" when it has the two fields no tunnel can exist without.
profile_configured(){
    [ -n "$(pf_slot_get "$1" iface_p1)" ] && [ -n "$(pf_slot_get "$1" peer_endpoint)" ]
}

# One pass over the store for the per-slot profile view — the ONLY reader of profile NAMES.
# Prints one line per slot (or only slot $1): "<slot> TAB <cfg 0|1> TAB <fo 0|1> TAB <name>".
# Same record framing and last-copy-wins rule as get_setting; cfg matches profile_configured
# (iface_p1 AND peer_endpoint non-empty); fo is 0 only for a stored "0" (absent = in the circle).
# <name> is DECODED and SANITIZED here, once for every consumer (status JSON, journal, incidents,
# CLI, diag). The page stores ' ' as %20 and '%' as %25 because the firmware's settings read-back
# cuts a value at its first whitespace ("Home NL" came back as "Home" and the next save of any
# page persisted the cut); %20-then-%25 replacement equals the page's single-pass decode for
# everything its encoder emits ("%2520" -> "%20"), and a legacy raw name decodes to itself.
# '<' and '>' become spaces (a legacy name must never carry an ASP tag into a /www/user file) and
# control bytes are dropped (they would break the status JSON) — the page's sanitizer never lets
# either through. A missing store reads as /dev/null so every slot still gets its line.
pf_scan(){
    local _src="$SETTINGS"
    [ -f "$_src" ] || _src=/dev/null
    LC_ALL=C awk -v max="$AWG_PF_MAX" -v only="$1" '
        function hit(r,   sp, k) { sp = index(r, " "); if (sp < 2) return
                                   k = substr(r, 1, sp - 1); if (k in want) val[k] = substr(r, sp + 1) }
        BEGIN { for (n = 1; n <= max; n++) { d = (n == 1) ? "awg_" : "awg_pf" n "_"; m = "awg_pf" n "_"
                    want[d "iface_p1"] = 1; want[d "peer_endpoint"] = 1; want[m "name"] = 1; want[m "fo"] = 1 }
                for (i = 1; i < 32; i++) ctl[i] = sprintf("%c", i)
                ctl[32] = sprintf("%c", 127) }
        { r = $0
          while (length(r) > 3039) { hit(substr(r, 1, 3039)); r = substr(r, 3040) }
          hit(r) }
        END { for (n = 1; n <= max; n++) {
                  if (only != "" && n != only + 0) continue
                  d = (n == 1) ? "awg_" : "awg_pf" n "_"; m = "awg_pf" n "_"
                  nm = val[m "name"]
                  gsub(/%20/, " ", nm); gsub(/%25/, "%", nm); gsub(/[<>]/, " ", nm)
                  if (nm ~ /[^ -~]/)
                      for (i = 1; i <= 32; i++) while ((p = index(nm, ctl[i])) > 0) nm = substr(nm, 1, p - 1) substr(nm, p + 1)
                  printf "%d\t%d\t%d\t%s\n", n, (val[d "iface_p1"] != "" && val[d "peer_endpoint"] != ""), (val[m "fo"] != "0"), nm } }' "$_src" 2>/dev/null
}

# Everything the user-facing labels need about slot $1, from ONE pf_scan, into globals (no
# subshell, so callers read them directly): AWG_PI_CFG (0|1), AWG_PI_ORD (ordinal, empty when the
# slot is unconfigured), AWG_PI_NAME (decoded name, empty when unset), AWG_PI_COUNT (configured
# profiles in total). NB the heredoc-fed loop runs in THIS shell — a pipe would lose the globals.
profile_info(){
    local n c f nm k=0
    AWG_PI_CFG=0; AWG_PI_ORD=""; AWG_PI_NAME=""
    while IFS='	' read -r n c f nm; do
        [ "$c" = 1 ] && k=$((k + 1))
        if [ "$n" = "$1" ]; then
            AWG_PI_CFG=$c; AWG_PI_NAME=$nm
            [ "$c" = 1 ] && AWG_PI_ORD=$k
        fi
    done <<EOF
$(pf_scan)
EOF
    AWG_PI_COUNT=$k
}

# The label formats, from the AWG_PI_* of the last profile_info. None of them may print a BARE
# slot number (the user cannot find slot numbers anywhere): an unconfigured slot says so.
#   label: the name, "Profile #<ord>" when unnamed        (CLI, diag)
#   desc:  "#<ord> (<name>)", "#<ord>" when unnamed       (journal lines)
#   iref:  "#<ord> «<name>» (slot N)"                     (incident log — survives renames/deletes)
_pi_label(){
    if [ "$AWG_PI_CFG" != 1 ]; then printf 'slot %s (not configured)\n' "$1"
    elif [ -n "$AWG_PI_NAME" ]; then printf '%s\n' "$AWG_PI_NAME"
    else printf 'Profile #%s\n' "$AWG_PI_ORD"; fi
}
_pi_desc(){
    if [ "$AWG_PI_CFG" != 1 ]; then printf 'slot %s (not configured)\n' "$1"
    elif [ -n "$AWG_PI_NAME" ]; then printf '#%s (%s)\n' "$AWG_PI_ORD" "$AWG_PI_NAME"
    else printf '#%s\n' "$AWG_PI_ORD"; fi
}
_pi_iref(){
    if [ "$AWG_PI_CFG" != 1 ]; then printf 'slot %s (not configured)\n' "$1"
    elif [ -n "$AWG_PI_NAME" ]; then printf '#%s «%s» (slot %s)\n' "$AWG_PI_ORD" "$AWG_PI_NAME" "$1"
    else printf '#%s (slot %s)\n' "$AWG_PI_ORD" "$1"; fi
}
profile_label(){ profile_info "$1"; _pi_label "$1"; }
profile_desc(){ profile_info "$1"; _pi_desc "$1"; }
profile_iref(){ profile_info "$1"; _pi_iref "$1"; }
# Decoded, sanitized stored name of slot $1 — EMPTY when unset (the status JSON's profile.name
# and list items; the page renders its own localized "unnamed" text).
profile_name_raw(){ profile_info "$1"; [ -n "$AWG_PI_NAME" ] && printf '%s\n' "$AWG_PI_NAME"; return 0; }
# Ordinal of slot $1 — EMPTY for an unconfigured slot.
profile_ordinal(){ profile_info "$1"; [ -n "$AWG_PI_ORD" ] && echo "$AWG_PI_ORD"; return 0; }
# Slot of the <n>-th configured profile (the number the user typed, e.g. CLI `profile 2`).
profile_slot_of_ordinal(){
    local n c f nm k=0
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    while IFS='	' read -r n c f nm; do
        [ "$c" = 1 ] || continue
        k=$((k + 1))
        [ "$k" -eq "$1" ] && { echo "$n"; return 0; }
    done <<EOF
$(pf_scan)
EOF
    return 1
}
# Space-separated configured slots in slot order.
profile_configured_slots(){
    local n c f nm out=""
    while IFS='	' read -r n c f nm; do
        [ "$c" = 1 ] && out="$out${out:+ }$n"
    done <<EOF
$(pf_scan)
EOF
    echo "$out"
}

# The user's persisted choice. A pointer at an UNCONFIGURED slot (a deleted profile, a store
# edited by hand or by another page) resolves to the LOWEST configured slot instead of
# materializing an empty config; the store itself is never written here (do_start says so once
# in the journal). The fallback scan only runs when the pointer is dead — the steady-state cost
# over the old reader is the one profile_configured check.
profile_user(){
    local p s
    p=$(get_setting awg_profile_active)
    case "$p" in ''|*[!0-9]*) p=1 ;; esac
    { [ "$p" -ge 1 ] && [ "$p" -le "$AWG_PF_MAX" ]; } || p=1
    if ! profile_configured "$p"; then
        for s in $(profile_configured_slots); do p=$s; break; done
    fi
    echo "$p"
}

# Fingerprint of a profile's IDENTITY: "<first 12 hex of md5(private key)>@<peer public key>".
# Pins the failover override (and the running-profile record) to the CONFIG, not to a slot
# number: a slot deleted and re-used for a different provider must not silently inherit an
# override pointing at "slot 3". The endpoint is deliberately NOT part of it — editing the
# running backup's endpoint must keep the override. Not secret-bearing (48 bits of a digest of
# the key, plus a public key); no spaces. pf_fp_of <priv> <pub> is the one formatter (do_start
# records the conf it materialized with it); pf_fp <slot> reads the store — empty for an
# unconfigured slot.
pf_fp_of(){
    local h
    h=$(printf '%s' "$1" | md5sum 2>/dev/null)
    h=${h%% *}
    [ ${#h} -ge 12 ] || return 0
    printf '%s@%s\n' "${h%"${h#????????????}"}" "$2"
}
pf_fp(){
    local pre v
    case "$1" in [1-9]) [ "$1" -le "$AWG_PF_MAX" ] || return 0 ;; *) return 0 ;; esac
    pre="awg_pf$1_"; [ "$1" = 1 ] && pre="awg_"
    [ -f "$SETTINGS" ] || return 0
    v=$(LC_ALL=C awk -v a="${pre}iface_p1" -v b="${pre}peer_p1" -v c="${pre}peer_endpoint" '
        function hit(r) { if (index(r, a " ") == 1) va = substr(r, length(a) + 2)
                          else if (index(r, b " ") == 1) vb = substr(r, length(b) + 2)
                          else if (index(r, c " ") == 1) vc = substr(r, length(c) + 2) }
        { r = $0
          while (length(r) > 3039) { hit(substr(r, 1, 3039)); r = substr(r, 3040) }
          hit(r) }
        END { if (va != "" && vc != "") { gsub(/[ \t]/, "", vb); printf "%s\t%s\n", va, vb } }' "$SETTINGS" 2>/dev/null)
    [ -n "$v" ] || return 0
    pf_fp_of "${v%%	*}" "${v#*	}"
}

# The slot the tunnel actually materializes: a valid failover override wins, else the user's
# choice. Override format "<slot> <fp>": honored only while that slot is configured AND still
# holds the SAME config (pf_fp) — a deleted-and-reused slot, or a backup whose keys were swapped,
# drops back to the user's choice instead of silently running a different config. A bare "<slot>"
# (written before 1.5.26) keeps the old rule: honored while the slot is configured.
# profile_resolve sets AWG_PF_EFF (and AWG_PF_EFF_FP when the check already computed the
# fingerprint — update_status reuses it) WITHOUT a subshell; profile_effective echoes the slot.
profile_resolve(){
    local p="" fp="" cur
    AWG_PF_EFF=""; AWG_PF_EFF_FP=""
    if [ -f "$PF_OVERRIDE" ]; then
        # `read` reports failure on a file without a trailing newline AFTER filling the vars
        # (the /proc/<pid>/cmdline trap) — never gate on its status.
        { read -r p fp < "$PF_OVERRIDE"; } 2>/dev/null
        case "$p" in [1-9]) [ "$p" -le "$AWG_PF_MAX" ] || p="" ;; *) p="" ;; esac
        if [ -n "$p" ] && [ -z "$fp" ]; then
            profile_configured "$p" && AWG_PF_EFF=$p
        elif [ -n "$p" ]; then
            cur=$(pf_fp "$p")
            [ -n "$cur" ] && [ "$cur" = "$fp" ] && { AWG_PF_EFF=$p; AWG_PF_EFF_FP=$cur; }
        fi
    fi
    [ -n "$AWG_PF_EFF" ] || AWG_PF_EFF=$(profile_user)
}
profile_effective(){ profile_resolve; echo "$AWG_PF_EFF"; }

# One field of the EFFECTIVE profile — for single-shot callers. Multi-field consumers
# (generate_config) resolve the slot once and use pf_slot_get to keep the fork count down.
pf_get(){ pf_slot_get "$(profile_effective)" "$1"; }

# --- Profile failover (auto-switch on health-check failure) ---
# Called ONLY from the post-start health check's failure branch — the single point where
# "this profile's tunnel demonstrably passes no traffic" is known (DNS-only failures fail
# open upstream and never reach it; the update window and the CTF gate live in do_start,
# which every hop goes through anyway). A PURE PICKER: it writes nothing. The hop itself (the
# override, the circle state, the journal line and the incident) is committed by do_stop UNDER
# THE OPERATION LOCK, and only if the failing start is still the current one (the health check
# passes its generation) — an unlocked write here once let a stale health check re-point a
# tunnel a newer switch/start already owned.
# $1 = the slot the FAILING start materialized (not profile_effective at failure time: a switch
# saved meanwhile would move the circle). Echoes the next configured, failover-enabled slot after
# it (circular by slot number); "giveup" when the circle is complete — wrapped back to the slot
# the incident started on, or every candidate tried once (the start slot need not be a
# candidate, e.g. an fo=0 profile); nothing when failover does not apply (off / <2 candidates).
failover_next_profile(){
    [ "$(get_setting awg_failover)" = "1" ] || return 0
    local cur="$1" cands="" cand=0 next="" n c f nm i start="" hops=""
    case "$cur" in [1-9]) ;; *) cur=$(profile_effective) ;; esac
    while IFS='	' read -r n c f nm; do
        [ "$c" = 1 ] && [ "$f" = 1 ] && { cands="$cands $n "; cand=$((cand + 1)); }
    done <<EOF
$(pf_scan)
EOF
    [ "$cand" -ge 2 ] || return 0
    i=1
    while [ "$i" -lt "$AWG_PF_MAX" ]; do
        n=$(( (cur - 1 + i) % AWG_PF_MAX + 1 ))
        case "$cands" in *" $n "*) next=$n; break ;; esac
        i=$((i + 1))
    done
    [ -n "$next" ] || return 0
    # NB: `< file 2>/dev/null` would NOT silence a missing file (redirections apply left to
    # right) — guard on existence instead.
    if [ -f "$FAILOVER_STATE" ]; then read start hops < "$FAILOVER_STATE" 2>/dev/null; fi
    case "$start" in ''|*[!0-9]*) start=$cur; hops=0 ;; esac
    case "$hops" in ''|*[!0-9]*) hops=0 ;; esac
    if [ "$next" = "$start" ] || [ "$hops" -ge "$cand" ]; then
        echo giveup
    else
        echo "$next"
    fi
}

# --- Profile CLI (`amneziawg.sh profile …`) — SSH-side switching ---
# Numbers are ORDINALS (what the page shows); `diag` mode adds the stable slot ("slot 3 = #2").
profile_cli_list(){
    local mode="$1" n c f nm k=0 eff usr eo uo ep mark fol lbl
    eff=$(profile_effective)
    usr=$(profile_user)
    profile_info "$eff"; eo=$AWG_PI_ORD
    profile_info "$usr"; uo=$AWG_PI_ORD
    if [ -z "$eo" ]; then
        echo "Config profiles: none configured"
    elif [ "$eff" != "$usr" ]; then
        # eff differs from the user's choice only while a VALID failover override is in effect.
        echo "Config profiles (active: #$eo — failover override; user's primary: #${uo:-?}):"
    else
        echo "Config profiles (active: #$eo):"
    fi
    while IFS='	' read -r n c f nm; do
        [ "$c" = 1 ] || continue
        k=$((k + 1))
        ep=$(pf_slot_get "$n" peer_endpoint)
        mark=" "; [ "$n" = "$eff" ] && mark="*"
        fol=""; [ "$f" = 0 ] && fol=" [failover: off]"
        lbl=$nm; [ -n "$lbl" ] || lbl="Profile #$k"
        if [ "$mode" = diag ]; then
            printf '%s slot %s = #%s «%s» — %s%s\n' "$mark" "$n" "$k" "$lbl" "$ep" "$fol"
        else
            printf '%s %s. %s — %s%s\n' "$mark" "$k" "$lbl" "$ep" "$fol"
        fi
    done <<EOF
$(pf_scan)
EOF
    [ "$(get_setting awg_failover)" = "1" ] && echo "Auto-failover: on" || echo "Auto-failover: off"
}

# The restart half of a profile switch (the service event and the CLI). $1 = the target slot —
# already the user's SAVED choice; $2 = journal suffix. Publishes SWITCH_REQ while the restart
# runs (the page's switch transition waits on it — see update_status), and names a failed
# restart in the journal AND in AWG_SWITCH_ERR (the CLI prints it). Returns do_restart's rc:
# 3 = could not stop (lock), 1 = the new profile did not start, 2 = superseded.
profile_switch_restart(){
    local slot="$1" sfx="$2" run="" rx rc tdesc rdesc=""
    AWG_SWITCH_ERR=""
    # What runs NOW — for the "still running" wording if the stop cannot take the lock. From the
    # running record only: the store's pointer already names the TARGET at this point.
    if is_running; then
        [ -f "$RUNNING_PF" ] && { read -r run rx < "$RUNNING_PF"; } 2>/dev/null
        case "$run" in
            [1-9]) rdesc="profile $(profile_desc "$run")" ;;
            *)     rdesc="the current profile" ;;   # started by a pre-1.5.26 version: no record
        esac
    fi
    tdesc=$(profile_desc "$slot")
    log_msg "Switching to config profile $tdesc$sfx"
    echo "$slot $(date +%s)" > "$SWITCH_REQ" 2>/dev/null
    do_restart switch; rc=$?
    rm -f "$SWITCH_REQ"
    case $rc in
        3) if [ -n "$rdesc" ]; then
               AWG_SWITCH_ERR="ERROR: could not stop (another operation holds the lock) — $rdesc still running, $tdesc is saved"
           else
               AWG_SWITCH_ERR="ERROR: could not stop (another operation holds the lock) — nothing switched now; $tdesc is saved and comes up with the next start"
           fi ;;
        1) AWG_SWITCH_ERR="ERROR: profile $tdesc failed to start — the tunnel is DOWN, see above; the watchdog will retry" ;;
    esac
    [ -n "$AWG_SWITCH_ERR" ] && log_msg "$AWG_SWITCH_ERR"
    # Republish now that the marker is gone. Every status write above ran while it still existed
    # (do_restart's rc-3 branch, do_start's own write before a CTF / no-autostart / is_running
    # return — all of them ahead of its EXIT trap), and nothing else may write one soon: the */1
    # status cron is gone on a user-stopped box. A published "switch_req":<slot> with no restart
    # behind it holds the page's switch transition «in progress» (no buttons) until its poll cap,
    # and it never reports the failure. After the error line, so the status log tail carries it.
    update_status
    return $rc
}

# `profile <N>` = the N-th CONFIGURED profile (the ordinal the page and `profile list` show);
# `profile slot:<S>` = the stable slot (for scripts: ordinals shift when a profile is deleted);
# `profile next` = the next configured one after the active. The resolved target is echoed
# before anything changes.
profile_cli_switch(){
    local tgt="$1" slot="" cur i n cfgs rc
    cfgs=" $(profile_configured_slots) "
    case "$tgt" in
        next)
            cur=$(profile_effective)
            i=1
            while [ "$i" -lt "$AWG_PF_MAX" ]; do
                n=$(( (cur - 1 + i) % AWG_PF_MAX + 1 ))
                case "$cfgs" in *" $n "*) slot=$n; break ;; esac
                i=$((i + 1))
            done
            [ -n "$slot" ] || { echo "No other configured profile to switch to."; return 1; }
            ;;
        slot:*)
            slot=${tgt#slot:}
            case "$slot" in ''|*[!0-9]*) echo "Bad slot: $tgt (expected slot:1-$AWG_PF_MAX)"; return 1 ;; esac
            { [ "$slot" -ge 1 ] && [ "$slot" -le "$AWG_PF_MAX" ]; } || { echo "Slot must be 1-$AWG_PF_MAX"; return 1; }
            case "$cfgs" in *" $slot "*) ;; *) echo "Slot $slot is not configured (need at least a private key + endpoint)."; return 1 ;; esac
            ;;
        *)
            case "$tgt" in ''|*[!0-9]*) echo "Bad profile number: $tgt"; return 1 ;; esac
            slot=$(profile_slot_of_ordinal "$tgt")
            if [ -z "$slot" ]; then
                set -- $cfgs
                echo "No profile #$tgt — $# configured (see: profile list)"
                return 1
            fi
            ;;
    esac
    profile_info "$slot"
    echo "#$AWG_PI_ORD = «$(_pi_label "$slot")» (slot $slot)"
    set_setting awg_profile_active "$slot" || { echo "Could not save the profile choice (JFFS full?) — nothing switched"; return 1; }
    # The override + circle are dropped by do_stop's `switch` token, under the lock.
    profile_switch_restart "$slot" " [CLI]"; rc=$?
    [ -n "$AWG_SWITCH_ERR" ] && echo "$AWG_SWITCH_ERR"
    return $rc
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
# Decoded URL list of policy <id>'s channel <kind> (inc=custom_urls, exc=exc_urls), as stored. A
# value the firmware cut (setting_is_cut) loses its last, partial URL — fetching "https://raw.gith"
# could only fail and then sit in the 6h back-off forever. Run b64d_init in the caller first.
policy_urls(){
    local k v
    if [ "${2:-inc}" = exc ]; then k=$(geo_key "$1" exc_urls); else k=$(geo_key "$1" custom_urls); fi
    v=$(get_setting "$k"); [ -n "$v" ] || return 0
    if setting_is_cut "$k" "$v"; then { printf '%s' "$v" | b64d; echo; } | sed '$d'; else printf '%s' "$v" | b64d; fi
    printf '\n'
}
# Union of ALL policies' URLs across both channels (custom_urls + exc_urls), decoded, one valid
# http(s) URL per line, deduped — every URL (include or exclusion) is fetched once into the
# shared userurl_<hash> pool.
geo_union_urls(){
    local id
    b64d_init
    for id in $(geo_ids); do
        policy_urls "$id" inc
        policy_urls "$id" exc
    done | tr ' \t\r' '\n\n\n' | grep -E '^https?://' | sort -u
}
# sha256[:16] keys of policy <id>'s URLs for channel <kind> (inc=custom_urls, exc=exc_urls), one
# per line — for per-policy/per-channel load + dnsmasq enumeration.
policy_url_keys(){
    local id="$1" kind="${2:-inc}" u
    b64d_init
    policy_urls "$id" "$kind" | tr ' \t\r' '\n\n\n' | grep -E '^https?://' | while read -r u; do
        url_key "$u"
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

# A FOREIGN dnsmasq ipset=/nftset= directive — hand-written in the user's OWN custom config, not
# our generated conf — that dumps EVERY resolved domain into one of our geo sets. dnsmasq turns an
# empty domain segment (or a bare '#') into a zero-length "match everything" domain (option.c: an
# empty /-segment and '#' take the SAME branch), so a line like `ipset=/https://foo/awg_dst` (the
# `//` in the scheme is an empty segment) silently routes the WHOLE internet into awg_dst — in Geo
# mode that pushes ALL LAN traffic through the tunnel (field report 2026-07-13: geo "broke", every
# site showed the VPN IP, geo-blocked TV apps died; the fix was removing the `https://`). We can't
# stop dnsmasq honouring the user's own line, so we surface it loudly. Scans the include file
# (dnsmasq.conf.add) + the conf-file= includes it declares, NEVER our own conf (whose domain
# normaliser strips schemes/empties, so it can't emit this). Echoes the first offending line
# (trimmed) when found, nothing otherwise. Only the TYPO signature (empty segment / http(s): scheme)
# is flagged — a deliberate `/#/awg_dst` is a conscious "route everything" choice, left alone.
geo_foreign_matchall(){
    [ -f "$DNSMASQ_INCLUDE" ] || return 0
    local _sets="" _gid _f _scan="$DNSMASQ_INCLUDE"
    for _gid in $(geo_ids); do _sets="$_sets $(geo_ipset "$_gid") $(geo_exc_ipset "$_gid")"; done
    for _f in $(awk -F= '/conf-file=/{print $2}' "$DNSMASQ_INCLUDE" 2>/dev/null); do
        [ "$_f" = "$DNSMASQ_AWG_CONF" ] && continue
        [ -f "$_f" ] && _scan="$_scan $_f"
    done
    awk -v sets="$_sets" '
        BEGIN{ n=split(sets,a," "); for(i=1;i<=n;i++) if(a[i]!="") OUR[a[i]]=1 }
        /^[[:space:]]*(ipset|nftset)=/{
            line=$0; sub(/^[[:space:]]*/,"",line); sub(/[[:space:]]+$/,"",line)
            val=line; sub(/^(ipset|nftset)=/,"",val); sub(/[[:space:]].*$/,"",val)
            m=split(val,f,"/"); if(m<3) next
            # last /-field is the comma-joined set list (nftset: table#..#set — set is after last #)
            nset=split(f[m],ss,","); hit=0
            for(i=1;i<=nset;i++){ t=ss[i]; sub(/.*#/,"",t); if(t in OUR){ hit=1; break } }
            if(!hit) next
            # domains are f[2]..f[m-1]; an empty segment or an http(s): scheme colon = match-all typo
            for(i=2;i<m;i++) if(f[i]=="" || f[i] ~ /^https?:$/){ print line; exit }
        }' $_scan 2>/dev/null
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

# Idempotent, transient-proof iptables add. The bare `-C … || -I/-A …` pattern has a hidden
# failure mode: `-C` exits non-zero not only for "rule absent" (rc=1) but ALSO when the PROBE
# ITSELF fails — Entware iptables (1.4.21) takes the global xtables lock for EVERY operation
# including -C, nothing here passes -w (firmware builds don't know it), so a collision with a
# concurrent iptables (the every-minute status cron, a firewall event, another addon) exits
# rc=4 "Another app is currently holding the xtables lock" — and the `||` then ADDS A
# DUPLICATE of a rule that was there all along. A duplicate :53 DNAT is the nasty case:
# cleanup used to delete ONE copy, so the leftover kept hijacking LAN DNS after a stop.
# So: retry the probe through transient failures (rc>=2), add only on a confirmed rc=1
# (absent — kernel table reads are atomic, rc=1 is trustworthy), and give the add itself one
# retry too (it takes the same lock). On a persistently sick probe, do NOT add (better a
# missing rule that the next apply/reconcile re-asserts than a dup that outlives cleanup).
# Usage: ipt_add_once <table> <-I|-A> <chain> <rule tokens…>
ipt_add_once(){
    local _tbl="$1" _how="$2" _chain="$3" _n=0 _rc
    shift 3
    while :; do
        iptables -t "$_tbl" -C "$_chain" "$@" 2>/dev/null
        _rc=$?
        [ $_rc -eq 0 ] && return 0        # already in place — the whole point of the guard
        [ $_rc -eq 1 ] && break           # confirmed absent -> add below
        _n=$((_n + 1))
        if [ $_n -ge 3 ]; then
            log_msg "WARNING: iptables probe kept failing (rc=$_rc) — NOT adding to $_tbl/$_chain this pass (the next apply/reconcile re-asserts it)"
            return 1
        fi
        sleep 1
    done
    iptables -t "$_tbl" "$_how" "$_chain" "$@" && return 0
    sleep 1
    iptables -t "$_tbl" "$_how" "$_chain" "$@"
}

# Full-table mangle dump that survives firmware-proprietary targets. Entware iptables
# (1.4.21, first on our PATH) aborts `-t mangle -S` at ASUS's SKIPLOG target ("Can't find
# library for target", rc=1), truncating the dump mid-PREROUTING — in a field diag
# (RT-BE88U @1.3.8) our own PREROUTING jump and the whole AWG chain vanished from the
# "mangle marks" section while the watchdog's -C probes saw every rule. Same pattern as
# the server's srv_mangle_dump: firmware binary first (it knows its own targets), keep a
# dump only on rc=0, else fall back to the possibly-truncated PATH-resolved one.
mangle_dump(){
    local _b _out
    for _b in /usr/sbin/iptables /sbin/iptables; do
        [ -x "$_b" ] || continue
        if _out=$("$_b" -t mangle -S 2>/dev/null); then
            printf '%s\n' "$_out"
            return 0
        fi
    done
    iptables -t mangle -S 2>/dev/null
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
    # The ghproxy mirrors proxy GitHub ONLY — for any other host (antifilter, a user's GeoCustom
    # URL) they can't help, and they'd receive the user's private list URL (tokens included).
    case "$url" in
        https://github.com/*|https://raw.githubusercontent.com/*|https://gist.githubusercontent.com/*|https://objects.githubusercontent.com/*)
            list="$list https://ghproxy.net/$url https://gh-proxy.com/$url" ;;
    esac
    for u in $list; do
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

# Selected GeoIP services for policy <id> (default id 1) — read from settings ONLY: an empty
# field means "nothing selected" for EVERY policy, id 1 included. The legacy implicit default
# (telegram google facebook twitter netflix cloudflare fastly cloudfront) was removed in 1.4.2:
# in exclude (direct) mode it silently forced those services + three major CDNs DIRECT past the
# VPN, and the user couldn't turn it off — a cleared field just re-armed the fallback (field
# case: TUF-AX3000_V2 @1.4.1, "banks direct, rest via VPN" broken by it). Whoever wants the old
# set types it into the field explicitly.
selected_geoip(){
    local id="${1:-1}"
    echo $(get_setting "$(geo_key "$id" v2fly_ip)" | tr ',' ' ' | tr 'A-Z' 'a-z')
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
    if fetch_with_mirrors "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml" "$tmp_yml" 120 && [ -s "$tmp_yml" ] && grep -q '^ *- name: ' "$tmp_yml"; then
        mv "$tmp_yml" "$GEO_DIR/v2fly_all.yml"
        # 2026-07: upstream switched to quoting the name scalars (`- name: "xai"`) — strip the
        # quotes here, or the UI autocomplete offers `"xai"` and users save quote-polluted
        # category lists into custom_settings (field-seen; harmless to the sanitized read
        # paths but it pollutes settings and eats the value-length budget).
        grep '^ *- name: ' "$GEO_DIR/v2fly_all.yml" | sed 's/.*- name: *//; s/^["'\'' ]*//; s/["'\'' ]*$//' | grep -v '^$' | sort -u > "$GEO_DIR/v2fly_categories.txt"
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
    sel=" $(geo_union_urls | while read -r u; do u=$(echo "$u" | tr -d ' \r'); [ -z "$u" ] && continue; url_key "$u"; done | tr '\n' ' ') "
    for f in "$GEO_DIR"/domains/userurl_*.txt "$GEO_DIR"/geoip/userurl_*.cidr; do
        [ -f "$f" ] || continue
        fkey=$(basename "$f"); fkey=${fkey#userurl_}; fkey=${fkey%.txt}; fkey=${fkey%.cidr}
        case "$sel" in *" $fkey "*) ;; *) rm -f "$f" ;; esac
    done
}

# Download the UNION of every policy's URL sources into the shared pool (one fetch per unique
# URL). Each is classified into domains/userurl_<key>.txt + geoip/userurl_<key>.cidr,
# key = first 16 hex of sha256(URL). Same URL in two policies => one download/file.
# The download is classified into temp files first and only replaces the previous copy when it
# yields usable entries: an HTML page (a github.com/…/blob/… link instead of the raw file, a
# captive/error page served with HTTP 200) or a list with nothing routable used to be logged as a
# success while it silently loaded zero entries — and it deleted the last good copy on the way.
download_custom_urls(){
    local mode="$1" urls url key tmp prev
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
        key=$(url_key "$url")
        if [ -z "$key" ]; then
            log_msg "Custom URL skipped: neither sha256sum nor openssl is available to name its files — $url"
            continue
        fi
        tmp="$GEO_DIR/.url_${key}.tmp"
        rm -f "$tmp.d" "$tmp.c"
        prev="No previous copy to fall back on"
        { [ -f "$GEO_DIR/domains/userurl_${key}.txt" ] || [ -f "$GEO_DIR/geoip/userurl_${key}.cidr" ]; } && prev="Previous copy kept"
        # "missing" (ensure_geo after an Apply): only URLs with no copy yet and not in their 6h
        # back-off — log_url_backoff has just told the user they are paused.
        if [ "$mode" = missing ]; then
            [ "$prev" = "Previous copy kept" ] && continue
            dl_recently_failed "url_${key}" && continue
        fi
        if fetch_with_mirrors "$url" "$tmp" 60 && [ -s "$tmp" ]; then
            if awk 'NR <= 30' "$tmp" | grep -qiE '<(!doctype|html|head|body)[ >]'; then
                dl_mark_failed "url_${key}"
                log_msg "Custom URL rejected: $url returned an HTML page, not a list — use the direct link to the raw file (for GitHub: raw.githubusercontent.com/…, not github.com/…/blob/…). $prev; retries paused for 6h ('Update now' retries at once)"
            else
                # shellcheck disable=SC2046
                set -- $(classify_user_list "$tmp" "$tmp.d" "$tmp.c")
                # Usable = IPv4 + real domains; bare whole-TLD words ($5) alone don't make a list
                # (a plain-text "Page not found" body must not replace a good copy).
                if [ $((${1:-0} + ${2:-0} - ${5:-0})) -gt 0 ]; then
                    rm -f "$GEO_DIR/domains/userurl_${key}.txt" "$GEO_DIR/geoip/userurl_${key}.cidr"
                    [ -f "$tmp.d" ] && mv "$tmp.d" "$GEO_DIR/domains/userurl_${key}.txt"
                    [ -f "$tmp.c" ] && mv "$tmp.c" "$GEO_DIR/geoip/userurl_${key}.cidr"
                    rm -f "$(dl_fail_stamp "url_${key}")" 2>/dev/null
                    log_msg "Custom URL: $url ($key): $(user_list_summary "$@")"
                else
                    dl_mark_failed "url_${key}"
                    log_msg "Custom URL rejected: $url has no usable entries: $(user_list_summary "$@") — expected one IPv4/CIDR or domain per line. $prev; retries paused for 6h ('Update now' retries at once)"
                fi
            fi
        else
            dl_mark_failed "url_${key}"
            log_msg "Custom URL download failed: $url ($(echo "$prev" | tr 'PN' 'pn'); retries paused for 6h — 'Update now' retries at once)"
        fi
        rm -f "$tmp" "$tmp.d" "$tmp.c"
    done
    prune_custom_urls
}

# Tell the user why an Apply did NOT (re)fetch a GeoCustom URL: a failed or rejected download is
# negative-cached for 6h (dl_recently_failed), and until now that silence looked exactly like "the
# URL is ignored". One line per URL that has no copy on disk and is waiting out its back-off.
log_url_backoff(){
    local u key f _then _left
    for u in $(geo_union_urls); do
        key=$(url_key "$u"); [ -n "$key" ] || continue
        [ -f "$GEO_DIR/domains/userurl_${key}.txt" ] || [ -f "$GEO_DIR/geoip/userurl_${key}.cidr" ] && continue
        dl_recently_failed "url_${key}" || continue
        f=$(dl_fail_stamp "url_${key}"); _then=$(cat "$f" 2>/dev/null)
        _left=$(( (21600 - ($(date +%s) - ${_then:-0})) / 60 ))
        [ "$_left" -lt 0 ] && _left=0; [ "$_left" -gt 360 ] && _left=360   # clock steps (NTP) can skew it
        log_msg "Custom URL $u: the last download failed or was rejected — retries paused for ~${_left} more min (then the next Apply retries; 'Update now' retries at once)"
    done
}

# "120 IPv4, 3 domains[, N IPv6 skipped …][, M unrecognized skipped]" from classify_user_list's
# counts ($1 IPv4, $2 domains, $3 IPv6, $4 unrecognized; $5 = how many of $2 are bare TLD rules).
user_list_summary(){
    local s="${1:-0} IPv4, ${2:-0} domains"
    [ "${5:-0}" -gt 0 ] 2>/dev/null && s="$s (${5} of them whole-TLD rules like 'ru')"
    [ "${3:-0}" -gt 0 ] 2>/dev/null && s="$s, ${3} IPv6 skipped (only IPv4 is routed)"
    [ "${4:-0}" -gt 0 ] 2>/dev/null && s="$s, ${4} unrecognized entries skipped"
    echo "$s"
}

download_all_geo(){
    b64d_init
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
    local page="$1" srv_page="$2"
    # Firmware UI language at mount time — gives the header widget a zero-flicker first paint
    # (it self-corrects from the status JSON "lang" field on its first poll if this goes stale).
    local pref_lang=$(nvram get preferred_lang 2>/dev/null)
    [ -z "$pref_lang" ] && pref_lang="EN"
    [ ! -f /tmp/menuTree.js ] && cp /www/require/modules/menuTree.js /tmp/
    # Remove our previous tab lines (substring match — also catches 'AmneziaWG Server';
    # does not touch the widget block)
    sed -i '/tabName: "AmneziaWG/d' /tmp/menuTree.js
    # Remove our previous widget block (marker range; independent of the word "AmneziaWG")
    sed -i '/\/\* AWG_WIDGET_START \*\//,/\/\* AWG_WIDGET_END \*\//d' /tmp/menuTree.js
    # Insert the tabs. TWO menuTree layouts ship in the field:
    #  - Merlin-proper builds (386.x…3006.x) carry Merlin's own VPN pages — anchor on the
    #    OpenVPN entry so our tabs sit next to the other VPN clients. Both `a` commands
    #    anchor on the same line: SERVER goes in first, the client entry lands above it —
    #    final menu order: AmneziaWG, then AmneziaWG Server.
    #  - gnuton builds (TUF/DSL models) ship the STOCK ASUS VPN menu (VPN Fusion:
    #    Advanced_VPNServer/VPNClient_Content) — no Advanced_VPN_OpenVPN.asp at all, so the
    #    anchored sed silently no-oped and the tab never appeared (page itself still worked
    #    via the header widget, shown under the firmware's "Others" fallback tab; field case
    #    TUF-AX3000_V2 @ 3004.388.10_2-gnuton1). Fall back to a structural insert: before the
    #    menu_VPN section terminator {url: "NULL", tabName: "__INHERIT__"}, which exists in
    #    EVERY firmware variant (same approach as XRAYUI — why X-RAY showed while we didn't).
    if grep -q 'url: "Advanced_VPN_OpenVPN.asp"' /tmp/menuTree.js; then
        [ -n "$srv_page" ] && sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$srv_page\", tabName: \"AmneziaWG Server\"}," /tmp/menuTree.js
        sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$page\", tabName: \"AmneziaWG\"}," /tmp/menuTree.js
    else
        log_msg "menuTree: stock-style VPN menu (gnuton/TUF) — inserting tab before section terminator"
        awk -v pg="$page" -v srv="$srv_page" '
            /index:[[:space:]]*"menu_VPN"/ { invpn=1 }
            invpn && /"NULL"/ && /__INHERIT__/ {
                print "{url: \"" pg "\", tabName: \"AmneziaWG\"},"
                if (srv != "") print "{url: \"" srv "\", tabName: \"AmneziaWG Server\"},"
                invpn=0
            }
            { print }
        ' /tmp/menuTree.js > /tmp/menuTree.js.awg && mv /tmp/menuTree.js.awg /tmp/menuTree.js
    fi
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

# stdin (IPv4/CIDR/range entries, one or more per line) -> `ipset restore` add-lines (permanent,
# timeout 0) into set $1, for VALID IPv4 only: octets <=255, prefix 1-32 (hash:net can't hold a
# /0), a-b ranges with start <= end, leading zeros normalized. This is not cosmetic — `ipset
# restore` ABORTS at the first line it can't parse and silently discards that line's whole
# uncommitted batch plus everything after it, so one IPv6 address (a family-inet set), a /33 or a
# 300.x in a user list used to load zero or a fraction of it (reproduced on ipset 6.34-7.24: a
# mixed v4/v6 list like Telegram's cidr.txt loaded 0). A clean canonical line (the 150K-line
# antifilter list on every rebuild) is fully validated by ONE regex and printed as is — split()
# per line was 4-8x slower on the bench; everything else is tokenized (inline `#` comments,
# spaces/tabs/commas/semicolons/pipes) and each token validated, junk skipped.
ipv4_restore_lines(){
    LC_ALL=C awk -v s="$1" '
        function ip4(t,   a) {
            if (t !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) return ""
            split(t, a, ".")
            if (a[1] + 0 > 255 || a[2] + 0 > 255 || a[3] + 0 > 255 || a[4] + 0 > 255) return ""
            return (a[1] + 0) "." (a[2] + 0) "." (a[3] + 0) "." (a[4] + 0)
        }
        function num(t,   a) { split(t, a, "."); return ((a[1] * 256 + a[2]) * 256 + a[3]) * 256 + a[4] }
        function dq(n) { return int(n / 16777216) % 256 "." int(n / 65536) % 256 "." int(n / 256) % 256 "." n % 256 }
        # An a-b range is emitted as its minimal CIDR cover (<= 62 lines, widest /1): the kernel
        # rejects or mis-walks wide ranges in hash:net ("covers the whole address space", "Hash is
        # full" for spans >= 2^31) and that one line aborted the whole restore.
        function range(x, y,   lo, hi, bits, blk) {
            lo = num(x); hi = num(y)
            while (lo <= hi) {
                bits = 0; blk = 1
                while (bits < 31 && lo % (blk * 2) == 0 && lo + blk * 2 - 1 <= hi) { blk *= 2; bits++ }
                print "add " s " " dq(lo) "/" (32 - bits) " timeout 0"
                lo += blk
            }
        }
        function emit(t,   a, p, x, y) {
            if (t ~ /^[0-9.]+-[0-9.]+$/) {
                split(t, a, "-"); x = ip4(a[1]); y = ip4(a[2])
                if (x != "" && y != "" && num(x) <= num(y)) range(x, y)
                return
            }
            p = split(t, a, "/"); if (p > 2) return
            x = ip4(a[1]); if (x == "") return
            if (p == 2) { if (a[2] !~ /^[0-9]+$/ || a[2] + 0 < 1 || a[2] + 0 > 32) return; x = x "/" (a[2] + 0) }
            print "add " s " " x " timeout 0"
        }
        /^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\/([1-9]|[12][0-9]|3[0-2]))?$/ {
            print "add " s " " $0 " timeout 0"; next
        }
        {
            gsub(/\r/, ""); sub(/#.*/, "")
            n = split($0, t, /[ \t,;|]+/)
            for (i = 1; i <= n; i++)
                if (t[i] ~ /^[0-9][0-9.\/-]*$/) emit(t[i])
        }'
}

# Bulk-load CIDR file into ipset using restore (much faster than individual adds)
ipset_load_file(){
    local file="$1"
    local setname="$2"
    [ ! -f "$file" ] && return
    ipv4_restore_lines "$setname" < "$file" | ipset restore -! 2>/dev/null
}

# Split a user-supplied list (GeoCustom pasted file or downloaded URL) into a domains file and an
# IPv4 file (CIDRs and a-b ranges), tolerating what real-world lists contain: CRLF, a UTF-8 BOM,
# comments (`#` anywhere; `;`, `//`, `!` at line start), several entries per line (space/tab/
# comma/semicolon/pipe separated), quotes and [ ] { } (JSON arrays), v2fly `domain:`/`full:`
# prefixes, pasted URLs (reduced to their host: scheme, user@, :port, path dropped), `*.`/`+.`/
# leading-dot wildcards, ip:port. Only VALID IPv4 reaches cidr_out (see ipv4_restore_lines for
# why that matters); IPv6 is counted and skipped (the geo sets are family inet). A domain needs a
# dot and a letter in its last label, labels <=63 and names <=253 chars (a longer one fails
# `dnsmasq --test`, which drops ALL domain routing for that round). A bare single label is taken
# as a whole-TLD rule ("ru", "xn--p1ai") ONLY when it is the line's sole entry: a word next to data
# ("91.108.4.0/22,RU", "Hetzner Online GmbH", a "Page not found" body) must never become
# `ipset=/ru/` — that routes an entire TLD. Such TLD rules are counted separately so a download
# consisting only of them doesn't pass as a usable list. Output files are created only when
# non-empty. Echoes "<IPv4> <domains> <IPv6> <unrecognized> <single-label domains>".
classify_user_list(){
    local infile="$1" dom_out="$2" cidr_out="$3"
    [ -f "$infile" ] || { echo "0 0 0 0 0"; return 0; }
    LC_ALL=C awk -v dout="$dom_out" -v cout="$cidr_out" -v bom="$(printf '\357\273\277')" '
        function v4ok(t,   a, p) {
            p = split(t, a, /[.\/]/)
            if (p < 4 || p > 5 || t !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/) return 0
            if (a[1] + 0 > 255 || a[2] + 0 > 255 || a[3] + 0 > 255 || a[4] + 0 > 255) return 0
            if (p == 5 && (a[5] + 0 < 1 || a[5] + 0 > 32)) return 0
            return 1
        }
        function num(t,   a) { split(t, a, "."); return ((a[1] * 256 + a[2]) * 256 + a[3]) * 256 + a[4] }
        NR == 1 && index($0, bom) == 1 { $0 = substr($0, length(bom) + 1) }
        {
            gsub(/\r/, ""); sub(/#.*/, ""); sub(/^[ \t]*(;|\/\/|!).*/, "")
            n = split($0, tok, /[ \t,;|]+/); nt = 0
            for (i = 1; i <= n; i++) if (tok[i] != "") nt++
            for (i = 1; i <= n; i++) {
                t = tolower(tok[i]); q = (t ~ /["'\''`]/ || index(t, "[") || index(t, "]") || index(t, "{") || index(t, "}"))
                gsub(/["'\''`]/, "", t)
                gsub(/\[/, "", t); gsub(/\]/, "", t); gsub(/\{/, "", t); gsub(/\}/, "", t)
                if (t == "") continue
                if (t ~ /^(domain|full):/) sub(/^(domain|full):/, "", t)
                else if (t ~ /^(regexp|keyword|include|geosite|geoip|ext):/) { nbad++; continue }
                else if (t ~ /^[a-z][a-z0-9+.-]*:\/\//) {
                    sub(/^[a-z][a-z0-9+.-]*:\/\//, "", t); sub(/[\/?#].*$/, "", t); sub(/^.*@/, "", t)
                }
                if (t ~ /^[^:]+:[0-9]+$/) sub(/:[0-9]+$/, "", t)
                if (t ~ /^[0-9.]+-[0-9.]+$/) {
                    split(t, rg, "-")
                    if (v4ok(rg[1]) && v4ok(rg[2]) && num(rg[1]) <= num(rg[2])) { print t > cout; nv4++ } else nbad++
                    continue
                }
                if (t ~ /^[0-9.\/]+$/) { if (v4ok(t)) { print t > cout; nv4++ } else nbad++; continue }
                if (t ~ /:/) { if (t ~ /^[0-9a-f:.\/]+$/ && t ~ /:.*:/) nv6++; else nbad++; continue }
                sub(/^(\*|\+)?\./, "", t); sub(/\.$/, "", t)
                if (length(t) > 253 || t ~ /[^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.][^.]/) { nbad++; continue }
                lab = t; sub(/^.*\./, "", lab)
                if (t ~ /^[a-z0-9_-]+(\.[a-z0-9_-]+)+$/ && lab ~ /[a-z]/) { print t > dout; ndom++ }
                else if (nt == 1 && !q && (t ~ /^[a-z][a-z]+$/ || t ~ /^xn--[a-z0-9-]+$/)) { print t > dout; ndom++; ntld++ }
                else nbad++
            }
        }
        END { printf "%d %d %d %d %d\n", nv4, ndom, nv6, nbad, ntld }' "$infile"
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
    b64d_init
    mkdir -p "$GEO_DIR/domains" "$GEO_DIR/geoip"
    # A cut value (setting_is_cut: the firmware's own truncation fingerprints) lost the tail of its
    # LAST file, usually mid-line (the page now refuses to save over 2900). That half-line must not
    # load: a /24 cut to "/2" is a VALID CIDR routing a quarter of IPv4. If the cut fell inside the
    # NEXT file's name, that whole file is gone — say so instead of skipping it silently.
    local trunc=0 chan="" prev="" tailcut=0
    setting_is_cut "$(geo_key "$id" "$key")" "$blob" && trunc=1
    # Cut exactly after a ';' — the last file is intact and the NEXT one is gone entirely (IFS
    # splitting drops the trailing empty field, so it must not be mistaken for a cut last file).
    [ "$trunc" = 1 ] && case "$blob" in *';'|*'=') tailcut=1; trunc=0 ;; esac
    [ "$kind" = exc ] && chan=", exclusions"
    local oldifs="$IFS" entry name b64 tmp base n seen=" " idx=0 last=0 cnt
    IFS=';'; set -f
    # shellcheck disable=SC2086
    set -- $blob
    set +f; IFS="$oldifs"
    for entry in "$@"; do idx=$((idx + 1)); [ -n "$entry" ] && last=$idx; done
    idx=0
    for entry in "$@"; do
        idx=$((idx + 1))
        [ -z "$entry" ] && continue
        name=${entry%%,*}
        b64=${entry#*,}
        case "$entry" in *,*) ;; *) name="" ;; esac   # need a name,content pair
        # Sanitized AND capped: the name becomes part of file names (.uc_<pfx><name>.tmp, ...), and
        # a very long one exceeded NAME_MAX, so the file silently failed to load.
        name=$(echo "$name" | sed 's/[^a-zA-Z0-9]/_/g' | cut -c1-48)
        if [ -z "$name" ]; then
            if [ "$trunc" = 1 ] && [ "$idx" = "$last" ]; then
                local _after="the start"; [ -n "$prev" ] && _after="file '$prev'"
                log_msg "WARNING: GeoCustom files (policy $id$chan): the firmware settings store (~3000 chars per value, about 2 KB of list) cut off everything after $_after — a file after it was lost entirely. Re-add it smaller, or put a big list online and add it under URL sources"
            fi
            continue
        fi
        # Uniquify on sanitized-name collision (e.g. "my.list" and "my-list" both -> "my_list"),
        # else the second file's classify output would truncate/overwrite the first's — data loss.
        base="$name"; n=1
        while case "$seen" in *" $name "*) true ;; *) false ;; esac; do
            n=$((n + 1)); name="${base}_${n}"
        done
        seen="$seen$name "
        tmp="$GEO_DIR/.uc_${pfx}${name}.tmp"
        printf '%s' "$b64" | b64d > "$tmp"
        if [ "$trunc" = 1 ] && [ "$idx" = "$last" ]; then
            # Only a PARTIAL last line goes (echo first: a complete newline-terminated line stays).
            { cat "$tmp"; echo; } | sed '$d' > "$tmp.t" 2>/dev/null && mv "$tmp.t" "$tmp"
            if [ -s "$tmp" ]; then
                log_msg "WARNING: GeoCustom file '$name' (policy $id$chan) was cut off by the firmware settings store (~3000 chars per value, about 2 KB of list) — only its first part loads, the partial last line is dropped. Shrink it, or put a big list online and add it under URL sources"
            else
                log_msg "WARNING: GeoCustom file '$name' (policy $id$chan) was lost to the firmware settings store's cut (~3000 chars per value, about 2 KB of list) — nothing of it survived. Re-add it smaller, or put a big list online and add it under URL sources"
            fi
        fi
        if [ -s "$tmp" ]; then
            cnt=$(classify_user_list "$tmp" "$GEO_DIR/domains/${pfx}${name}.txt" "$GEO_DIR/geoip/${pfx}${name}.cidr")
            # shellcheck disable=SC2086
            log_msg "GeoCustom file '$name' (policy $id$chan): $(user_list_summary $cnt)"
        fi
        rm -f "$tmp"
        prev="$name"
    done
    [ "$tailcut" = 1 ] && log_msg "WARNING: GeoCustom files (policy $id$chan): the firmware settings store (~3000 chars per value, about 2 KB of list) cut off everything after file '$prev' — a file after it was lost entirely. Re-add it smaller, or put a big list online and add it under URL sources"
    return 0
}

# Extract the UNION of every policy's GeoSite categories from the shared v2fly DB into shared
# domains/v2fly_<cat>.txt files (one extraction per unique category; two policies sharing a
# category share the file). Stale category files no longer selected by anyone are removed.
build_geosite_domains(){
    mkdir -p "$GEO_DIR/domains"
    local union=" $(geo_union_geosite) " f cat _gs_cats=0 _gs_ok=0
    for f in "$GEO_DIR"/domains/v2fly_*.txt; do
        [ -f "$f" ] || continue
        cat=$(basename "$f" .txt); cat=${cat#v2fly_}
        case "$union" in *" $cat "*) ;; *) rm -f "$f" ;; esac
    done
    [ -f "$GEO_DIR/v2fly_all.yml" ] || return 0
    for cat in $(geo_union_geosite); do
        [ -z "$cat" ] && continue
        # 2026-07: upstream switched dlc.dat_plain.yml to quoted name scalars (`- name: "xai"`;
        # rule lines were always quoted) — the old exact `$NF==c` match kept the quotes and
        # silently wrote EMPTY files for every category (only custom domains reached dnsmasq,
        # plus a misleading "pre-resolve: ipset UNCHANGED" warning). Accept quoted AND unquoted
        # names/rules at any list indent; c arrives quote-free (geo_union_geosite sanitizes).
        # Trailing ":@attr" tags are kept as before — the dnsmasq conf builder strips them.
        awk -v c="$cat" '
            /^ *- name:/ {
                if (found) exit
                name=$0; sub(/^ *- name: */,"",name)
                sub(/^["'\'' ]*/,"",name); sub(/["'\'' ]*$/,"",name)
                found=(name==c); next
            }
            found && /^ *- ["'\'' ]*domain:/ { sub(/^ *- ["'\'' ]*domain:/,""); sub(/["'\'' ]*$/,""); print }
            found && /^ *- ["'\'' ]*full:/ { sub(/^ *- ["'\'' ]*full:/,""); sub(/["'\'' ]*$/,""); print }
        ' "$GEO_DIR/v2fly_all.yml" > "$GEO_DIR/domains/v2fly_${cat}.txt"
        _gs_cats=$((_gs_cats+1))
        [ -s "$GEO_DIR/domains/v2fly_${cat}.txt" ] && _gs_ok=$((_gs_ok+1))
    done
    # Self-diagnosis (the fingerprint of the 2026-07 breakage): DB present, categories selected,
    # yet EVERY extraction came out empty — the upstream YAML format changed again, or none of
    # the selected names exist anymore. One empty file among non-empty ones is NOT flagged
    # (that's just a single renamed/typo'd category).
    if [ "$_gs_cats" -gt 0 ] && [ "$_gs_ok" -eq 0 ]; then
        log_msg "WARNING: GeoSite extraction produced 0 domains for ALL $_gs_cats selected categories — the v2fly DB format may have changed (check for an addon update), or the selected category names no longer exist"
    fi
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
        key=$(url_key "$u"); [ -n "$key" ] || continue
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
    geo_urls_missing && download_custom_urls missing
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

# True on a 2.6.x/2.4.x kernel (RT-AC68U class). These boxes are now SUPPORTED — both historical
# blockers are fixed and the start guard was removed (1.2.61):
#   1. sendmmsg() ENOSYS — amneziawg-go's batched UDP send landed in Linux 3.0, so the daemon
#      couldn't send a single packet. FIXED (1.2.58): the fork daemon falls back to per-packet
#      sendmsg (version suffix -smfix); proven to send + handshake on a real AC68U.
#   2. Policy-routing bring-up "bricked" the box — traced (1.2.61) to drain_ip_rules' blind
#      `ip rule del`, which on Broadcom 2.6.36 + Entware iproute2 deletes the SYSTEM routing rules
#      (there a no-match `del` removes a foreign rule instead of failing) -> "Network unreachable"
#      -> the daemon's own handshake couldn't egress (TX>0/RX=0) -> reboot. FIXED by draining only
#      our own rules by confirmed priority. Verified end-to-end: handshake, bidirectional transfer,
#      system rules intact, no reboot.
# No longer a start guard — kept ONLY to LABEL old kernels in `diag` (the name is legacy). CTF, if
# present, must still be disabled first (that's the separate ctf_active guard, a Broadcom issue).
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
    local line prio tbl dflt en="" u
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
    # ONE `nvram show` instead of five `nvram get` calls. Every nvram invocation is a chance to
    # wedge forever on the firmware's envrams IPC (see reap_stale_status — three of the five
    # wedged runs found in the field were exactly this loop), and this runs on the */1 status
    # cron: five chances per minute became one. Semantics are unchanged — still NUMBERED keys
    # only, so the bare `wgc_enable` VPN-Fusion edit-buffer leftover still cannot false-alarm,
    # and a key that does not exist at all simply never matches (it used to read back empty).
    for u in $(nvram show 2>/dev/null | sed -n 's/^wgc\([1-5]\)_enable=1$/\1/p'); do
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
    # ipt_add_once (not bare `-C || -I`): an xtables-lock blip on the -C used to add a
    # DUPLICATE DNAT that single-shot cleanup couldn't fully remove (see the helper's comment).
    ipt_add_once nat -I PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip"
    ipt_add_once nat -I PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip"
    ipt_add_once filter -I FORWARD -i br0 -p tcp --dport 853 -j REJECT
    local doh_ip
    for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
        ipt_add_once filter -I FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT
        ipt_add_once filter -I FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT
    done
    log_msg "DNS interception enabled"
}

# Validated tunnel-DNS servers from awg_dns (comma/space separated): echoes up to 3 IPv4s.
# IPv6 and hostnames are dropped — the @interface upstream binding + the awg0 policy rule
# need literal v4 here (a hostname upstream would need resolving, a chicken-and-egg).
# Read from the MATERIALIZED side-file (generate_config writes the dns field of the slot it
# actually built awg0.conf from into $AWG_DIR/awg0.dns, same raw comma-joined format), NOT from
# the effective slot: while a switch is saved but its restart was dropped, or a failover
# override stopped matching, the effective slot is not what the daemon runs — and binding
# dnsmasq to the OTHER profile's resolver can point the whole LAN at an address this tunnel
# does not reach.
tunnel_dns_ips(){
    local raw="" ip out="" n=0
    [ -f "$AWG_DIR/awg0.dns" ] && raw=$(tr ',' ' ' < "$AWG_DIR/awg0.dns" 2>/dev/null)
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

# All IPv4 answers for one name via the router's own dnsmasq (127.0.0.1), one per line. Feeds the
# self-feeding geo pre-resolve (1.4.3). Format-agnostic across the fleet's THREE nslookup flavors
# (old busybox "Address 1: <ip> <host>", new busybox "Address: <ip>", Entware BIND "Address: <ip>"
# — /opt/bin can shadow busybox, and the AWG_PATH_SANE=0 fallback swaps flavors again): only lines
# AFTER the first "Name:" marker count — that skips the resolver's own Server/Address header —
# then every token is shape+octet-validated. dns_ok's `^Name:` grep is proof the marker exists on
# every flavor here. AAAA tokens fail the IPv4 shape test naturally; 0.0.0.0 and loopback answers
# are dropped (AdGuard-family upstreams answer 0.0.0.0 for blocked names — routing those would
# just add noise entries). No busybox-awk landmines: no {n,m} intervals, no gawk-isms.
resolve_domain_v4(){
    nslookup "$1" 127.0.0.1 2>/dev/null | awk '
        /^Name:/ { seen = 1; next }
        seen && $1 ~ /^Address/ {
            for (i = 2; i <= NF; i++) {
                if ($i !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) continue
                split($i, o, ".")
                if (o[1]+0 > 255 || o[2]+0 > 255 || o[3]+0 > 255 || o[4]+0 > 255) continue
                if (o[1] == "127" || $i == "0.0.0.0") continue
                print $i
            }
        }'
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
    # Drain EVERY copy (ipt_drain), not a single -D: a duplicate added by a past lock-blip
    # race (pre-1.3.8) must not outlive the teardown and keep hijacking LAN DNS.
    ipt_drain -t nat -D PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip"
    ipt_drain -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip"
    ipt_drain -D FORWARD -i br0 -p tcp --dport 853 -j REJECT
    local doh_ip
    for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
        ipt_drain -D FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT
        ipt_drain -D FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT
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
    # DANGER on old kernels: `ip rule del <partial-selector>` (e.g. `del prio 97`, `del lookup
    # 300`) does NOT fail when nothing matches on Broadcom 2.6.36 + Entware iproute2 — it deletes
    # a NON-matching rule instead (same RTM netlink mismatch family as the 1.2.40 `ip link show`
    # false-negative). A blind delete-while-success loop then drains the ENTIRE table, system
    # `local`/`main`/`default` included, leaving the router "Network is unreachable" — no egress,
    # so the tunnel handshake can't even leave and RX stays 0 (root cause of the RT-AC68U
    # "full start bricks the box", found 2026-07-13). Fix: NEVER blind-loop a bare `ip rule del`.
    # Enumerate `ip rule show` (RTM_GETRULE is fine on this kernel — it lists rules correctly),
    # pick only OUR rules — priority band 97-100 AND referencing our table/fwmark, PLUS the
    # prio-97 `... lookup main` direct-exclusion rules (97 is ours by the documented band
    # contract; nothing else creates lookup-main rules there) — and delete each by its exact,
    # confirmed-present priority. System rules (prio 0/32766/32767) can never be selected, so
    # they can never be drained.
    #
    # The prio-97/main clause was ADDED in 1.3.16: without it a device's stale Direct rule
    # survived every cleanup/rebuild (it references neither our table nor our fwmark), so
    # switching a device/peer direct -> vpn_all left the old prio-97 rule OUTRANKING the new
    # prio-99 one — the policy change looked applied but the device kept egressing via WAN
    # until a reboot (field: RT-BE88U server peer, 2026-07-17).
    local _pr _guard=0
    while [ $_guard -lt 60 ]; do
        _guard=$((_guard + 1))
        _pr=$(ip rule show 2>/dev/null | awk -F: '{p=$1+0} p>=97 && p<=100 && (/lookup '"$RT_TABLE"'([^0-9]|$)/ || /fwmark '"$FWMARK"'([^0-9]|$)/ || (p==97 && / lookup main$/)){print p; exit}')
        case "$_pr" in ''|*[!0-9]*) break ;; esac
        ip rule del prio "$_pr" 2>/dev/null || break
    done
}

# Idempotent single-rule add: drain every existing copy of THIS exact rule, then add exactly
# one. Used at the setup_firewall add sites so a second setup pass can't duplicate — and,
# unlike draining everything up-front, each rule is absent only for the microseconds between
# its own drain and re-add, so a live re-apply never opens a policy-routing gap across the
# whole rebuild. $@ = the spec after `ip rule` (e.g. `from 1.2.3.4 lookup main prio 97`).
ip_rule_replace(){
    # Same old-kernel hazard as drain_ip_rules: a bare `ip rule del "$@"` when this exact rule
    # doesn't exist mis-deletes a system rule on Broadcom 2.6.36 — so deletion happens ONLY
    # after this exact rule is confirmed present (then `del <full spec>` removes exactly
    # itself; the no-match hazard never fires). "This exact rule" = same priority AND the
    # same from/fwmark selector.
    #
    # 1.3.17 FIX: 1.2.61-1.3.16 drained by PRIORITY ALONE (`ip rule del prio N` while any
    # `^N:` existed) — but several vpn_all devices SHARE prio 99 (direct exclusions share 97),
    # so each device's replace wiped the previous device's rule and only the LAST one in
    # clients.list kept routing. Field: RT-AX88U — journal said "PS5 -> VPN (all)" while
    # `ip rule` had only the Switch's rule; the PS5 leaked to WAN ("works only when the
    # DEFAULT policy is vpn_all" — the fwmark path needs no per-device rule).
    local _pr _sel _g=0
    _pr=$(printf '%s ' "$@" | sed -n 's/.*[[:space:]]prio[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p')
    # Selector = the leading `from <ip>` / `fwmark <mark>` pair, dots escaped for grep.
    # (Two plain seds, not one with \| alternation — busybox sed support for \| is shaky.)
    _sel=$(printf '%s ' "$@" | sed -n 's/^\(from[[:space:]][^ ]*\).*/\1/p')
    [ -z "$_sel" ] && _sel=$(printf '%s ' "$@" | sed -n 's/^\(fwmark[[:space:]][^ ]*\).*/\1/p')
    _sel=$(printf '%s' "$_sel" | sed 's/\./\\./g')
    if [ -n "$_pr" ] && [ -n "$_sel" ]; then
        # Hot-apply short-circuit (1.4.5): exactly ONE copy of this rule already present ->
        # nothing to do. Prio+selector uniquely identify our rules (97 -> main, 98/99/100 ->
        # our table), so present-once means present-correct — and an unchanged Apply no longer
        # even blips the rule with a drain/re-add.
        [ "$(ip rule show 2>/dev/null | grep "^$_pr:" | grep -c "[[:space:]]${_sel}[[:space:]]")" = "1" ] && return 0
        while [ $_g -lt 60 ] && ip rule show 2>/dev/null | grep "^$_pr:" | grep -q "[[:space:]]${_sel}[[:space:]]"; do
            ip rule del "$@" 2>/dev/null || break
            _g=$((_g + 1))
        done
    elif [ -n "$_pr" ]; then
        # No from/fwmark selector in the spec (not used by current call sites): fall back to
        # prio-scoped draining — correct while such a priority hosts only one rule.
        while [ $_g -lt 60 ] && ip rule show 2>/dev/null | grep -q "^$_pr:[[:space:]]"; do
            ip rule del prio "$_pr" 2>/dev/null || break
            _g=$((_g + 1))
        done
    fi
    ip rule add "$@" 2>/dev/null || log_msg "WARNING: ip rule add failed: $*"
}

# =============================================================
# Hot-apply machinery (1.4.5). setup_firewall no longer tears everything down first: the old
# cleanup-then-rebuild left the LAN with NO marking rules and EMPTY sets for the whole rebuild
# (~17-21 s on a loaded armv7 with ~16K static entries — field TUF-AX3000_V2: every Apply
# visibly "reconnected" the VPN devices and leaked them to the WAN past the kill-switch, whose
# blackhole only catches MARKED traffic). Now: new set content is STAGED into temp sets while
# the old ones keep routing, then atomically ipset-swapped into place (kernel swaps the index
# slots, so live iptables references flip to the new content in one syscall); the mangle chain
# is rebuilt only when its DESIRED content actually changed (fingerprint below); ip rules are
# reconciled in place (heal missing, drop stale) instead of drained wholesale. cleanup_firewall
# keeps the full teardown for stop/rollback/uninstall.
# =============================================================
CHAIN_SIG_FILE="/tmp/.awg_chain_sig"   # fingerprint of the AWG chain's desired content (tmpfs)
RUNNING_CONF_SIG="/tmp/.awg_running_conf_sig"   # md5 of the conf the RUNNING daemon was launched with

# Remove one exact name from the owned-set registry (counterpart of register_owned_set).
unregister_owned_set(){
    [ -f "$OWNED_SETS" ] || return 0
    grep -vxF "$1" "$OWNED_SETS" > "${OWNED_SETS}.tmp" 2>/dev/null
    mv "${OWNED_SETS}.tmp" "$OWNED_SETS"
}

# Replay the DYNAMIC (timeout>0: dnsmasq/pre-resolve-fed) entries of live set $1 into staging
# set $2, keeping each entry's REMAINING timeout — so a rebuild no longer wipes the warm
# domain->IP state and excluded/geo domains keep routing through the swap with zero gap.
# Permanent (timeout 0) entries are skipped: statics are re-loaded from their source files
# right after this, and ipset_load_file's `restore -!` (exist flag) then upgrades any replayed
# duplicate back to permanent. Replay goes FIRST into the empty staging set for that reason.
ipset_replay_dynamic(){
    ipset save "$1" 2>/dev/null | awk -v o="$1" -v n="$2" '
        $1 == "add" && $2 == o {
            if ($0 ~ / timeout 0( |$)/) next
            $2 = n; print
        }' | ipset restore -! 2>/dev/null
    return 0
}

# Atomically put staging set $2 into service under final name $1. Existing final (ours) ->
# `ipset swap` (the kernel exchanges the two sets' index slots, so rules bound to the final
# set's index see the new content the same instant) and the old content is destroyed under the
# temp name. No final yet (first build) -> `ipset rename`. Registry follows the outcome.
ipset_commit_staged(){
    local final="$1" tmp="$2"
    if ipset list "$final" -t >/dev/null 2>&1; then
        if ipset swap "$tmp" "$final" 2>/dev/null; then
            ipset destroy "$tmp" 2>/dev/null
            unregister_owned_set "$tmp"
            register_owned_set "$final"
            return 0
        fi
        return 1
    fi
    if ipset rename "$tmp" "$final" 2>/dev/null; then
        unregister_owned_set "$tmp"
        register_owned_set "$final"
        return 0
    fi
    return 1
}

# Destroy every registry-owned set NOT named in $* — deleted policies, an awg_ipset_name
# rename's old family, and crashed staging leftovers. Runs AFTER the chain reconcile, so a
# still-referenced set can only be one the kernel refuses to destroy (silently retried on the
# next apply; stays registered). The while-read keeps the ORIGINAL fd while unregister rewrites
# the file, so the walk is stable.
reconcile_owned_sets(){
    [ -f "$OWNED_SETS" ] || return 0
    local _keep=" $* " _s
    while read -r _s; do
        [ -z "$_s" ] && continue
        case "$_keep" in *" $_s "*) continue ;; esac
        ipset flush "$_s" 2>/dev/null
        if ipset destroy "$_s" 2>/dev/null; then
            unregister_owned_set "$_s"
            log_msg "Removed obsolete geo ipset: $_s"
        fi
    done < "$OWNED_SETS"
    return 0
}

# Fingerprint of everything that determines the AWG chain's rule content: header exclusions
# (lan/srv/endpoint), the device list + policies, the default policy, and each geo policy's
# mode + set availability (emit_geo_rules skips a missing/foreign set, which changes the chain
# — so availability is part of the identity). Same inputs -> same chain, so a matching
# fingerprint lets setup_firewall keep the LIVE chain untouched (the sets under it were already
# swapped to the new content). $1=default_policy $2=lan_net $3=srv_net $4=endpoint.
chain_state_sig(){
    {
        echo "v1|$1|$2|$3|$4|$FWMARK|$RT_TABLE|$AWG_CHAIN"
        cat "$CLIENTS_FILE" 2>/dev/null
        local _gid _set _exc
        for _gid in $(geo_ids); do
            _set=$(geo_ipset "$_gid"); _exc=$(geo_exc_ipset "$_gid")
            printf 'geo|%s|%s|%s|' "$_gid" "$(geo_mode "$_gid")" "$_set"
            if ipset list "$_set" -t >/dev/null 2>&1 && geo_set_ours "$_gid" "$_set"; then printf 'ok|'; else printf 'no|'; fi
            if ipset list "$_exc" -t >/dev/null 2>&1 && geo_set_ours "$_gid" "$_exc"; then echo "exc"; else echo "noexc"; fi
        done
    } | md5sum | awk '{print $1}'
}

# Is ANY geo policy actually routed (a client or the default references vpn_geo* whose set is
# live and ours)? Mirrors the emit_geo_rules gating — used by the hot-apply skip path to set
# has_geo without walking the chain-build loops (geo_in_use is broader: it also counts mere
# configured content, which must not force DNS interception on).
any_geo_routed(){
    local _dp _ip _n _pol _mac _id _s
    _dp=$(get_setting awg_default_policy)
    case "$_dp" in
        vpn_geo|vpn_geo_*)
            _id=$(geo_policy_of_ref "$_dp"); _s=$(geo_ipset "$_id")
            ipset list "$_s" -t >/dev/null 2>&1 && geo_set_ours "$_id" "$_s" && return 0 ;;
    esac
    [ -f "$CLIENTS_FILE" ] || return 1
    while IFS=',' read -r _ip _n _pol _mac || [ -n "$_ip" ]; do
        _pol=$(echo "$_pol" | tr -d ' ')
        case "$_pol" in
            vpn_geo|vpn_geo_*)
                _id=$(geo_policy_of_ref "$_pol"); _s=$(geo_ipset "$_id")
                ipset list "$_s" -t >/dev/null 2>&1 && geo_set_ours "$_id" "$_s" && return 0 ;;
        esac
    done < "$CLIENTS_FILE"
    return 1
}

# Reconcile our policy ip rules against the desired list in file $1 (one exact `ip rule add`
# spec per line): ensure each desired rule exists (ip_rule_replace short-circuits when it
# already does), then delete OUR band rules that are no longer desired — a removed device /
# flipped policy used to rely on cleanup_firewall's wholesale drain, which is exactly the gap
# this replaces. Selection mirrors drain_ip_rules (prio 97-100 + our table/fwmark + the prio-97
# lookup-main direct rules), so system rules can never be touched; deletes are exact-spec on a
# rule we JUST enumerated — the old-kernel no-match mis-delete can't fire.
reconcile_ip_rules(){
    local _f="$1" _line _spec
    while read -r _line; do
        [ -n "$_line" ] && ip_rule_replace $_line
    done < "$_f"
    ip rule show 2>/dev/null | awk -v t="$RT_TABLE" -v m="$FWMARK" '
        {
            p = $1 + 0
            if (p < 97 || p > 100) next
            line = $0; sub(/^[0-9]+:[ \t]+/, "", line)
            ours = 0
            if (line ~ ("lookup " t "([^0-9]|$)")) ours = 1
            if (line ~ ("fwmark " m "([^0-9a-fA-F]|$)")) ours = 1
            if (p == 97 && line ~ / lookup main$/) ours = 1
            if (!ours) next
            sel = ""
            if (match(line, /^from [^ ]+/)) sel = substr(line, RSTART, RLENGTH)
            if (sel == "from all") sel = ""
            fw = ""
            if (match(line, /fwmark [^ ]+/)) fw = substr(line, RSTART, RLENGTH)
            tbl = ""
            if (match(line, /lookup [^ ]+/)) tbl = substr(line, RSTART, RLENGTH)
            spec = ""
            if (sel != "") spec = sel " "
            if (fw != "") spec = spec fw " "
            print spec tbl " prio " p
        }' | while read -r _spec; do
            [ -z "$_spec" ] && continue
            grep -qxF "$_spec" "$_f" && continue
            ip rule del $_spec 2>/dev/null && log_msg "Removed stale policy rule: $_spec"
        done
    return 0
}

cleanup_firewall(){
    # Unhook from PREROUTING (drain: a duplicate jump left by a past lock-blip race would
    # keep the chain referenced and make the -X below fail silently), flush, delete.
    ipt_drain -t mangle -D PREROUTING -j "$AWG_CHAIN"
    iptables -t mangle -F "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -X "$AWG_CHAIN" 2>/dev/null

    # Remove the Xray-priority chain (hooked ahead of XRAYUI) too — it lives and dies with our
    # firewall.
    cleanup_xray_priority

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

    # The chain fingerprint describes a chain that no longer exists.
    rm -f "$CHAIN_SIG_FILE"

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
        # geo selection, no domains) has nothing to pre-resolve.
        if [ -f "$DNSMASQ_AWG_CONF" ] && grep -q '^ipset=' "$DNSMASQ_AWG_CONF" 2>/dev/null; then
            # SELF-FEEDING pre-resolve (1.4.3). It used to only fire queries through dnsmasq and
            # count on dnsmasq's ipset hook to populate the sets — but that hook runs ONLY on
            # FORWARDED (upstream) answers, never on cache hits. Every firewall rebuild destroys
            # + re-creates the sets with STATIC content only, and when the geo conf is unchanged
            # the restart above is rightly skipped (md5 sig) — so with a warm dnsmasq cache the
            # wiped domain IPs could NOT return until their TTLs expired: excluded domains leaked
            # into the VPN (exclude mode) / geo domains fell out of it (include mode) for minutes
            # to hours after every Apply. Field case TUF-AX3000_V2 @1.4.1: the cold-cache run fed
            # +213 entries, the warm-cache rebuild 17 min later only +42 — the other ~170 bank
            # domains routed via VPN. (The old "a restart usually fixes it" advice worked ONLY
            # because a restart cools the cache — it misdiagnosed the cause as an unloaded conf.)
            # Now each answer is parsed (resolve_domain_v4) and added to the line's own target
            # set(s) BY US, cache hit or not; dnsmasq's hook still covers live client traffic
            # afterwards. Adds are one-by-one WITHOUT -exist/`restore -!`: the exist flag RESETS
            # the timeout of an already-present entry, which would demote the user's permanent
            # (timeout 0) custom IPs to expiring 24h ones — a plain add's EEXIST is swallowed
            # instead, exactly how dnsmasq's own hook behaves. Parallel jobs append to ONE shared
            # O_APPEND file (each echo is a single short atomic write — no interleaving, no
            # per-job file fan that a huge domain list would turn into a giant cat glob).
            _pre_ips=$(geo_ipset_total)
            _prl="/tmp/.awg_prerslv.$$"
            # Pre-clean: .out below is APPENDED to, and $$ here is the PARENT's pid (the known
            # subshell gotcha) — a killed-mid-run predecessor from the same parent must not leak
            # its half-written pairs into this run.
            rm -f "${_prl}".* 2>/dev/null
            # "domain set1,set2" pairs straight from the conf we just built ($NF = the comma-set
            # target list; domains were charset-validated at emit time, so plain read splits
            # safely — and the list file, not a pipe, keeps the loop in THIS shell so the final
            # `wait` really covers the last sub-10 batch (the piped version orphaned it).
            awk -F/ '/^ipset=/{for(i=2;i<NF;i++)print $i " " $NF}' "$DNSMASQ_AWG_CONF" > "${_prl}.lst"
            bg_count=0
            while read -r domain dsets; do
                [ -z "$domain" ] && continue
                (
                    for _rip in $(resolve_domain_v4 "$domain"); do
                        for _rst in $(echo "$dsets" | tr ',' ' '); do
                            [ -n "$_rst" ] && echo "$_rst $_rip"
                        done
                    done >> "${_prl}.out"
                ) &
                bg_count=$((bg_count + 1))
                [ $bg_count -ge 10 ] && { wait; bg_count=0; }
            done < "${_prl}.lst"
            wait
            sort -u "${_prl}.out" 2>/dev/null > "${_prl}.add"
            _fed=0; _tried=0
            while read -r _rst _rip; do
                [ -n "$_rip" ] || continue
                _tried=$((_tried + 1))
                ipset add "$_rst" "$_rip" 2>/dev/null && _fed=$((_fed + 1))
            done < "${_prl}.add"
            rm -f "${_prl}".* 2>/dev/null
            _post_ips=$(geo_ipset_total)
            if [ "$_tried" -gt 0 ]; then
                # _fed = entries the add actually created; the rest of _tried already existed
                # (EEXIST) — e.g. a second run right after a successful one legitimately logs
                # "0 new of N". Live count ("Firewall configured: N IPs" is a build-time tally,
                # not proof of population — THIS line is the proof).
                log_msg "Geo domain pre-resolve: self-fed $_fed new of $_tried resolved set entries (ipset ${_pre_ips} -> ${_post_ips}) — cache-proof, domain routing active without a dnsmasq restart"
            elif dns_ok; then
                log_msg "Geo domain pre-resolve: resolver answers real names but returned no usable IPv4 for any geo domain (upstream blocking/empty answers?) — domains will fill on later client queries"
            else
                log_msg "Geo domain pre-resolve: router DNS not resolving real names yet (WAN/upstream/DoT not ready); domains will fill on later client queries"
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

# --- Priority over a co-resident xray transparent proxy (XRAYUI «redirect all») ---
# xray captures LAN traffic in mangle PREROUTING (TPROXY -> fwmark 0x10000 -> ip-rule prio 19),
# BEFORE the routing decision — ahead of our fwmark 0x100 (prio 98) and source rules (prio 99).
# So a device the user assigned to AmneziaWG (vpn_all / vpn_geo) is grabbed by xray, not the
# tunnel. This chain, hooked at the TOP of PREROUTING (before XRAYUI), marks such a device's
# tunnel-bound packets 0x100 and ACCEPTs them — ACCEPT ends the mangle traversal, so xray never
# sees them and prio-98 routes them into awg0. Built ONLY while xray is actually capturing;
# direct devices RETURN (they keep flowing through xray). We never touch xray's own rules — this
# is our chain, ahead of its. Verified on a live RT-BE88U (server-peer twin of this, 1.3.10).
# Geo priority is include-mode only for now; an exclude-mode policy is left to xray (logged).
_xray_prio_geo(){
    local pgid="$1"; shift
    local incset
    incset=$(geo_ipset "$pgid")
    ipset list "$incset" >/dev/null 2>&1 && geo_set_ours "$pgid" "$incset" || return 1
    if [ "$(geo_mode "$pgid")" = direct ]; then
        log_msg "NOTE: geo policy $pgid is exclude-mode — Xray-priority not applied to it (its traffic keeps using Xray)"
        return 1
    fi
    iptables -t mangle -A "$AWG_PRIO_CHAIN" "$@" -m set --match-set "$incset" dst -j MARK --set-mark "$FWMARK"
    iptables -t mangle -A "$AWG_PRIO_CHAIN" "$@" -m set --match-set "$incset" dst -j ACCEPT
    # Per-device only (a selector was passed): RETURN the device's NON-geo traffic so it can't
    # inherit a vpn_all default blanket below and be forced into the tunnel — it keeps going to
    # Xray/direct, exactly as emit_geo_rules does for the main chain. The default-geo case (no
    # selector) intentionally has no RETURN: unmatched traffic falls off the chain end to Xray.
    [ "$#" -gt 0 ] && iptables -t mangle -A "$AWG_PRIO_CHAIN" "$@" -j RETURN
    return 0
}

setup_xray_priority(){
    # Only meaningful while a transparent-proxy xray is actually grabbing LAN traffic.
    if ! xray_redirect_active; then
        cleanup_xray_priority
        return 0
    fi

    local lan_net endpoint srv_net default_policy
    lan_net=$(get_lan_net); endpoint=$(get_endpoint)
    srv_net=$(get_setting awgs_subnet); case "$srv_net" in */*) ;; *) srv_net="" ;; esac
    default_policy=$(get_setting awg_default_policy); [ -z "$default_policy" ] && default_policy="direct"

    iptables -t mangle -N "$AWG_PRIO_CHAIN" 2>/dev/null || iptables -t mangle -F "$AWG_PRIO_CHAIN"

    # Same exclusions as the main chain: LOCAL / LAN / server-subnet / DHCP-NTP / multicast /
    # endpoint must NEVER be diverted to awg0 — RETURN them (they cascade to xray's own RETURNs
    # and to normal routing).
    iptables -t mangle -A "$AWG_PRIO_CHAIN" -m addrtype --dst-type LOCAL -j RETURN
    [ -n "$lan_net" ] && iptables -t mangle -A "$AWG_PRIO_CHAIN" -d "$lan_net" -j RETURN
    [ -n "$srv_net" ] && iptables -t mangle -A "$AWG_PRIO_CHAIN" -d "$srv_net" -j RETURN 2>/dev/null
    # AWG-SERVER PEERS defer to their OWN Xray control (the per-peer «bypass Xray» option,
    # amneziawg_server.sh, default OFF) — never let this LAN-device chain force a peer into the
    # tunnel and override that choice. Peers ride the client engine (their IPs land in
    # clients.list), so RETURN peer-SOURCED traffic here BEFORE the device loop can mark it; the
    # server's own PREROUTING rule (if «bypass Xray» is on for that peer) still sits ahead of us.
    [ -n "$srv_net" ] && iptables -t mangle -A "$AWG_PRIO_CHAIN" -s "$srv_net" -j RETURN 2>/dev/null
    iptables -t mangle -A "$AWG_PRIO_CHAIN" -p udp -m multiport --dports 67,68,123 -j RETURN
    iptables -t mangle -A "$AWG_PRIO_CHAIN" -d 224.0.0.0/4 -j RETURN
    [ -n "$endpoint" ] && iptables -t mangle -A "$AWG_PRIO_CHAIN" -d "$endpoint" -j RETURN

    local dev_id name policy mac sel
    if [ -f "$CLIENTS_FILE" ] && [ -s "$CLIENTS_FILE" ]; then
        # Pass 1: direct devices -> RETURN, so the default blanket below can't sweep them into
        # the tunnel; they keep flowing to xray.
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' '); policy=$(echo "$policy" | tr -d ' '); mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue
            [ "$policy" = "direct" ] || continue
            if [ -n "$mac" ]; then iptables -t mangle -A "$AWG_PRIO_CHAIN" -m mac --mac-source "$mac" -j RETURN
            else iptables -t mangle -A "$AWG_PRIO_CHAIN" -s "$dev_id" -j RETURN; fi
        done < "$CLIENTS_FILE"
        # Pass 2: vpn devices -> priority into the tunnel, ahead of xray.
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' '); policy=$(echo "$policy" | tr -d ' '); mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue
            if [ -n "$mac" ]; then sel="-m mac --mac-source $mac"; else sel="-s $dev_id"; fi
            case "$policy" in
                vpn_all)
                    iptables -t mangle -A "$AWG_PRIO_CHAIN" $sel -j MARK --set-mark "$FWMARK"
                    iptables -t mangle -A "$AWG_PRIO_CHAIN" $sel -j ACCEPT
                    ;;
                vpn_geo|vpn_geo_*)
                    _xray_prio_geo "$(geo_policy_of_ref "$policy")" $sel
                    ;;
            esac
        done < "$CLIENTS_FILE"
    fi
    # Default policy blanket (after the per-device rules): a non-direct default means unlisted
    # devices go to VPN too — give them priority over xray as well.
    case "$default_policy" in
        vpn_all)
            iptables -t mangle -A "$AWG_PRIO_CHAIN" -j MARK --set-mark "$FWMARK"
            iptables -t mangle -A "$AWG_PRIO_CHAIN" -j ACCEPT
            ;;
        vpn_geo|vpn_geo_*)
            _xray_prio_geo "$(geo_policy_of_ref "$default_policy")"
            ;;
    esac

    # Hook FIRST in PREROUTING (before XRAYUI). ipt_add_once appends; we need position 1, so
    # guard + insert-at-1 by hand. The subsequent flush_conntrack in setup_firewall re-paths the
    # (IP-keyed) vpn devices' live xray sessions, so no separate flush is needed here.
    iptables -t mangle -C PREROUTING -j "$AWG_PRIO_CHAIN" 2>/dev/null \
        || iptables -t mangle -I PREROUTING 1 -j "$AWG_PRIO_CHAIN"
    log_msg "Xray active — non-direct devices given priority into the tunnel ahead of Xray (AWG_PRIO)"
}

cleanup_xray_priority(){
    ipt_drain -t mangle -D PREROUTING -j "$AWG_PRIO_CHAIN"
    iptables -t mangle -F "$AWG_PRIO_CHAIN" 2>/dev/null
    iptables -t mangle -X "$AWG_PRIO_CHAIN" 2>/dev/null
}

setup_firewall(){
    b64d_init   # once here, so every $(geo_union_urls)/$(policy_url_keys) below inherits the probe
    # HOT-APPLY (1.4.5): no cleanup_firewall here anymore. The old teardown-then-rebuild left
    # the LAN unmarked + the sets empty for the whole rebuild (~17-21 s on a loaded armv7 —
    # every Apply looked like a VPN reconnect AND leaked geo devices to the WAN past the
    # kill-switch, whose blackhole only catches marked traffic). Everything below is now
    # idempotent-or-staged: sets are built aside and atomically swapped in, the chain is
    # rebuilt only when its desired content changed, ip rules are reconciled in place, and
    # obsolete sets are reaped via the registry. Full teardown lives on in cleanup_firewall
    # for stop/rollback/uninstall. NB transient ipset RAM peaks at old+new during the stage —
    # bounded by the same divided maxelem budget, and the swap frees the old copy right after.

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

    # Obsolete sets (deleted policies, an awg_ipset_name rename's old family, crashed staging
    # temps) are reaped by reconcile_owned_sets AFTER the chain reconcile below — here we only
    # GC per-policy content files for policies deleted in the UI.
    prune_orphan_policies

    # Sync the SHARED pool to the union of all policies' selections (drop de-selected files) and
    # extract the union of GeoSite categories once. Per-policy loading below picks each subset.
    migrate_geocustom_layout   # one-time: drop pre-shared-pool flat usercustom_*/custom.txt
    prune_geoip
    prune_antifilter
    prune_custom_urls
    build_geosite_domains

    # Staged build: load each policy's NEW content into a "_t" staging set while the live set
    # keeps routing, then ipset_commit_staged swaps it into place atomically. Dynamic (dnsmasq/
    # pre-resolve-fed) entries are replayed first with their remaining timeouts, so domain
    # routing survives the rebuild with no gap at all. Shared-base semantics preserved: a
    # pre-existing set we don't own is loaded IN PLACE for id 1 (documented shared behavior —
    # we must never destroy/swap another tool's set) and skipped for id>=2 (foreign collision).
    local gid gset tset _ldt _staged _desired_sets=""
    for gid in $(geo_ids); do
        gset=$(geo_ipset "$gid")
        local _cerr _crc
        _staged=1; _ldt=""
        if ipset list "$gset" -t >/dev/null 2>&1 && ! geo_set_ours 2 "$gset"; then
            # Set exists but is not in our registry (geo_set_ours with a non-1 id = pure
            # registry test). id 1 -> shared-base in-place load; id>=2 -> foreign, skip.
            if [ "$gid" = 1 ]; then
                _staged=0; _ldt="$gset"
            else
                log_msg "WARNING: ipset $gset pre-exists and isn't ours — skipping geo policy $gid (foreign-name collision)"
                continue
            fi
        else
            tset="${gset}_t"
            ipset destroy "$tset" 2>/dev/null
            _cerr=$(ipset create "$tset" hash:net family inet hashsize 4096 maxelem "$maxelem" timeout 86400 2>&1)
            _crc=$?
            if [ "$_crc" -ne 0 ] || ! ipset list "$tset" -t >/dev/null 2>&1; then
                log_msg "ERROR: ipset $tset creation failed, geo policy $gid disabled${_cerr:+: $_cerr}"
                continue
            fi
            register_owned_set "$tset"
            # Warm state first (empty set -> no -exist conflicts), statics after: their
            # `timeout 0` restore -! lines upgrade any replayed duplicate back to permanent.
            ipset_replay_dynamic "$gset" "$tset"
            _ldt="$tset"
        fi

        # Load THIS policy's selected subset from the shared pool into the target set.
        local _svc _f _ak _uk
        for _svc in $(selected_geoip "$gid"); do
            _f="$GEO_DIR/geoip/v2fly_${_svc}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$_ldt"
        done
        for _ak in $(selected_antifilter "$gid"); do
            antifilter_is_domain "$_ak" && continue
            _f="$GEO_DIR/antifilter/af_${_ak}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$_ldt"
        done
        # Custom URL CIDRs this policy references (shared files keyed by URL hash).
        for _uk in $(policy_url_keys "$gid"); do
            _f="$GEO_DIR/geoip/userurl_${_uk}.cidr"; [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$_ldt"
        done
        # Custom IPs (field) -> permanent entries, batched through ONE `ipset restore` (the old
        # per-IP `ipset add` loop forked a process per entry — 100+ execs on big fields).
        get_setting "$(geo_key "$gid" custom_ips)" | tr ',' '\n' | ipv4_restore_lines "$_ldt" \
            | ipset restore -! 2>/dev/null
        # GeoCustom pasted files (per-policy content): regenerate, then load this policy's CIDRs.
        apply_custom_geo "$gid"
        for _f in "$GEO_DIR"/geoip/usercustom_p${gid}_*.cidr; do
            [ -f "$_f" ] || continue
            ipset_load_file "$_f" "$_ldt"
        done
        # This policy's own custom-domains file (consumed by the dnsmasq builder below).
        build_custom_domains "$gid"

        if [ "$_staged" = 1 ]; then
            if ! ipset_commit_staged "$gset" "$tset"; then
                log_msg "ERROR: could not activate rebuilt ipset $gset (swap/rename failed) — geo policy $gid keeps its previous entries this round"
                ipset destroy "$tset" 2>/dev/null
                unregister_owned_set "$tset"
                # A previous live set (if any) keeps routing; fall through so exc/domains still build.
            fi
        fi
        _desired_sets="$_desired_sets $gset"

        # --- Exclusions channel (pointwise exceptions) ---
        # Always (re)generate this policy's exclusion content files (self-clean when empty), so a
        # cleared exclusions block leaves nothing behind. Only build the EXC ipset when used: it's
        # small (pointwise) and gets a fixed cap, so it never erodes the divided main budget.
        apply_custom_geo "$gid" exc
        build_custom_domains "$gid" exc
        if policy_has_exc "$gid"; then
            local _exset _etmp _exldt _exstaged
            _exset=$(geo_exc_ipset "$gid")
            _exstaged=1; _exldt=""
            if ipset list "$_exset" -t >/dev/null 2>&1 && ! geo_set_ours 2 "$_exset"; then
                # Ownership guard mirrors the main set (id 1's shared base proceeds in place).
                if [ "$gid" = 1 ]; then _exstaged=0; _exldt="$_exset"; else _exldt=""; fi
            else
                _etmp="${_exset}_t"
                ipset destroy "$_etmp" 2>/dev/null
                if ipset create "$_etmp" hash:net family inet hashsize 1024 maxelem 8192 timeout 86400 2>/dev/null; then
                    register_owned_set "$_etmp"
                    ipset_replay_dynamic "$_exset" "$_etmp"
                    _exldt="$_etmp"
                fi
            fi
            if [ -n "$_exldt" ]; then
                get_setting "$(geo_key "$gid" exc_ips)" | tr ',' '\n' | ipv4_restore_lines "$_exldt" \
                    | ipset restore -! 2>/dev/null
                for _f in "$GEO_DIR"/geoip/excustom_p${gid}_*.cidr; do
                    [ -f "$_f" ] && ipset_load_file "$_f" "$_exldt"
                done
                for _uk in $(policy_url_keys "$gid" exc); do
                    _f="$GEO_DIR/geoip/userurl_${_uk}.cidr"; [ -f "$_f" ] && ipset_load_file "$_f" "$_exldt"
                done
                if [ "$_exstaged" = 1 ]; then
                    if ! ipset_commit_staged "$_exset" "$_etmp"; then
                        log_msg "ERROR: could not activate rebuilt exclusion ipset $_exset — policy $gid keeps its previous exclusions this round"
                        ipset destroy "$_etmp" 2>/dev/null
                        unregister_owned_set "$_etmp"
                    fi
                fi
                _desired_sets="$_desired_sets $_exset"
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

    # Warn (journal) if the user's OWN dnsmasq config carries a match-all ipset line that dumps
    # every domain into a geo set — in Geo mode that silently routes ALL traffic through the VPN.
    # We never touch their line; the page also shows a red banner (status.geo_matchall_warn).
    # Gated on geo_in_use — matches the status-banner gate, so a box with the line but Geo OFF
    # doesn't get a scary "Geo will send EVERY site through the VPN" journal entry for an inert line.
    local _fmatch=""
    if geo_in_use; then _fmatch=$(geo_foreign_matchall); fi
    [ -n "$_fmatch" ] && log_msg "WARNING: a dnsmasq directive in your custom config routes ALL domains into a geo set — Geo mode will send EVERY site through the VPN. Offending line: $_fmatch (remove the 'https://' / empty segment, keep only the bare domain)"

    # --- Device list first: clients.list is a chain-fingerprint input ---
    save_clients

    # --- Chain-rule inputs (fingerprint inputs too) ---
    local lan_net endpoint srv_net
    lan_net=$(get_lan_net)
    endpoint=$(get_endpoint)
    srv_net=$(get_setting awgs_subnet)
    case "$srv_net" in */*) ;; *) srv_net="" ;; esac

    # --- HOT APPLY: rebuild the chain ONLY when its desired content changed. The sets under
    #     the live chain were already swapped to fresh content above, so a matching fingerprint
    #     means the existing rules are byte-for-byte what we would emit — leave them completely
    #     alone: no flush, no marking gap, no conntrack flush. The two probes catch external
    #     damage (chain gone / unhooked by a firmware firewall restart): either failing forces
    #     a rebuild — the safe direction (a lock-blip rc>=2 on -C just means one extra rebuild).
    #     NB the rebuild body below keeps its original one-level indentation to keep the diff
    #     reviewable — it is the `if [ "$_chain_dirty" = 1 ]` block until the matching `fi`. ---
    local _chain_sig _chain_dirty=1
    _chain_sig=$(chain_state_sig "$default_policy" "$lan_net" "$srv_net" "$endpoint")
    if [ "$(cat "$CHAIN_SIG_FILE" 2>/dev/null)" = "$_chain_sig" ] \
        && iptables -t mangle -S "$AWG_CHAIN" >/dev/null 2>&1 \
        && iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>/dev/null; then
        _chain_dirty=0
        any_geo_routed && has_geo=true
        log_msg "Policies unchanged — marking rules left untouched (hot apply)"
    fi
    if [ "$_chain_dirty" = 1 ]; then
    rm -f "$CHAIN_SIG_FILE"   # stale the moment we start touching the chain

    # --- Create custom chain in mangle table ---
    iptables -t mangle -N "$AWG_CHAIN" 2>/dev/null || iptables -t mangle -F "$AWG_CHAIN"

    # --- Exclusion rules (evaluated first) ---
    iptables -t mangle -A "$AWG_CHAIN" -m addrtype --dst-type LOCAL -j RETURN
    [ -n "$lan_net" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$lan_net" -j RETURN
    # AWG-server peer subnet: LAN->peer and peer->peer traffic must never be pulled into the
    # client tunnel by a device/default policy — RETURN it like the LAN net. Emitted whenever
    # a subnet is configured (cheap, and the rule is correct even while the server is down).
    [ -n "$srv_net" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$srv_net" -j RETURN 2>/dev/null
    iptables -t mangle -A "$AWG_CHAIN" -p udp -m multiport --dports 67,68,123 -j RETURN
    iptables -t mangle -A "$AWG_CHAIN" -d 224.0.0.0/4 -j RETURN
    [ -n "$endpoint" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$endpoint" -j RETURN

    # --- Per-device rules (two passes for correct ordering) ---
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

    # Chain now matches the fingerprint computed above — record it so the next unchanged
    # Apply skips this whole block (and its marking gap) entirely.
    printf '%s' "$_chain_sig" > "$CHAIN_SIG_FILE"
    fi   # end of the _chain_dirty rebuild block (hot apply)

    # --- Hook chain into PREROUTING (ipt_add_once: a lock-blip on the -C guard must not
    #     stack a duplicate jump — packets would traverse AWG twice and cleanup's single
    #     -D used to leave the extra copy behind) ---
    ipt_add_once mangle -A PREROUTING -j "$AWG_CHAIN"

    # --- Single fwmark rule for all marked traffic ---
    ip_rule_replace fwmark "$FWMARK" lookup $RT_TABLE prio 98

    # Hairpin route for the AWG-server peer subnet: a vpn_all source (LAN device or a
    # policied peer) looks up table $RT_TABLE for EVERYTHING via its from-rule, and without
    # this route its traffic to 10.9.x peers would follow the /1 defaults into the tunnel.
    # Dev-scoped, so the kernel purges it automatically when awgs0 goes away; the server's
    # own start re-adds it symmetrically (whichever side comes up second wins).
    [ -n "$srv_net" ] && iface_exists "$AWGS_IFACE" && ip route add "$srv_net" dev "$AWGS_IFACE" table $RT_TABLE 2>/dev/null

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

    # --- Give AmneziaWG-assigned devices priority over a co-resident xray transparent proxy.
    #     Built (and hooked ahead of XRAYUI) ONLY while xray is actually capturing; otherwise it
    #     tears itself down. Placed BEFORE flush_conntrack so the flush re-paths those devices'
    #     live xray-captured sessions onto the new chain in one shot. ---
    setup_xray_priority

    # --- Flush conntrack of already-marked flows so they re-establish through the tunnel.
    #     NOTE: this re-routes only flows that ALREADY carry our fwmark; a device just
    #     switched direct->VPN keeps its in-flight (unmarked) flows on their old path until
    #     they close. New connections route correctly immediately.
    #     HOT APPLY: skipped when the chain (policies) did not change — marking never paused,
    #     so live flows need no re-path; set-content changes take effect per-packet anyway
    #     (no CONNMARK). This also stops an unchanged Apply from resetting every VPN device's
    #     established sessions, which was its own source of "connection reloads on Apply". ---
    [ "$_chain_dirty" = 1 ] && flush_conntrack

    # --- Policy route for router-originated traffic. Re-asserted here (not only in do_start)
    #     so it survives a firmware firewall-restart; ip_rule_replace makes it a no-op while
    #     the rule is already in place (hot apply). ---
    local awg_self
    awg_self=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -n "$awg_self" ] && ip_rule_replace from "$awg_self" lookup $RT_TABLE prio 100

    # --- Reconcile policy ip rules: heal missing ones (cheap — ip_rule_replace short-circuits
    #     on present) and DROP stale ones (removed device / policy flip) — the wholesale drain
    #     that used to do this lived in cleanup_firewall, which the hot apply no longer calls.
    #     Desired specs mirror the ip_rule_replace call sites exactly: 98 fwmark, 100 self,
    #     97 direct exclusions (only under a non-direct default), 99 vpn_all — IP-keyed clients
    #     only (MAC clients live in the chain, not in ip rules). ---
    local _iprf="/tmp/.awg_want_iprules.$$"
    {
        echo "fwmark $FWMARK lookup $RT_TABLE prio 98"
        [ -n "$awg_self" ] && echo "from $awg_self lookup $RT_TABLE prio 100"
        if [ -f "$CLIENTS_FILE" ]; then
            while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
                dev_id=$(echo "$dev_id" | tr -d ' '); policy=$(echo "$policy" | tr -d ' '); mac=$(echo "$mac" | tr -d ' ')
                [ -z "$dev_id" ] && continue
                [ -n "$mac" ] && continue
                case "$dev_id" in *[!0-9.]*) continue ;; esac
                case "$policy" in
                    direct)  [ "$default_policy" != "direct" ] && echo "from $dev_id lookup main prio 97" ;;
                    vpn_all) echo "from $dev_id lookup $RT_TABLE prio 99" ;;
                esac
            done < "$CLIENTS_FILE"
        fi
    } > "$_iprf"
    reconcile_ip_rules "$_iprf"
    rm -f "$_iprf"

    # --- Reap obsolete registry-owned sets (deleted policies, renamed base, crashed temps) —
    #     safe only now: the chain reconcile above dropped any rule that referenced them. ---
    reconcile_owned_sets $_desired_sets

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

# Server-role peers that carry an explicit routing policy, emitted as clients.list lines
# ("ip,name,policy," — no MAC; peer tunnel IPs are stable per AllowedIPs). Source of truth:
# awgs_peers (+ awgs_peers1..N overflow chunks, same ~2900-char convention as awg_initdata) —
# entries ';'-separated, fields '|'-separated:
#   name|ip|policy|allowed_mode|enabled|pubkey|privkey|psk      (see amneziawg_server.sh)
# Only enabled peers with a known policy token are emitted. Names are sanitized on save, but
# re-sanitize here (strip , ; ") so a hand-edited setting can't break the CSV parse or the
# status JSON downstream. base64 key fields can't collide with either separator.
server_peer_policy_entries(){
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
    printf '%s\n' "$raw" | tr ';' '\n' | awk -F'|' '
        NF>=5 && $5=="1" && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            # strict octets (0-255): a hand-edited 999.x IP must not reach ip_rule_replace
            n=split($2, oct, "."); ok=1
            for (i=1; i<=4; i++) if (oct[i]+0 > 255) ok=0
            if (!ok) next
            pol=$3
            if (pol!="direct" && pol!="vpn_all" && pol!="vpn_geo" && pol !~ /^vpn_geo_[0-9]+$/) next
            name=$1; gsub(/[,;"]/,"",name)
            print $2 "," name "," pol ","
        }'
}

save_clients(){
    local clients=$(get_setting awg_clients)
    if [ -n "$clients" ]; then
        echo "$clients" | tr ';' '\n' > "$CLIENTS_FILE"
    else
        > "$CLIENTS_FILE"
    fi
    # AWG-server peers ride the SAME per-device policy machinery: appended here, they get
    # vpn_all/vpn_geo/direct via the very pass-1/pass-2 rules below (and flush_conntrack
    # covers them automatically). Deliberate v1 kill-switch semantics: these rules live and
    # die with the CLIENT tunnel's firewall, so when it is down peer traffic fails OPEN to
    # the WAN — same fail-open the LAN devices have (документировано; строгий per-peer
    # blackhole — отдельной опцией позже).
    server_peer_policy_entries >> "$CLIENTS_FILE" 2>/dev/null
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
    b64d_init   # inherited by the $( ) subshells and the background download below
    # Sync the shared pool to the UNION of all policies' selections (drop de-selected files),
    # and GC sets/files of deleted policies.
    prune_geoip
    prune_antifilter
    prune_custom_urls
    prune_orphan_policies
    geo_in_use || return 0
    log_url_backoff
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

# S1-S4 padding. AmneziaWG 3.0 parses these with ParseUint(value, 10, 16), i.e. they became
# 16-BIT — v0.2.19 used a plain Atoi and accepted anything. A config carrying S > 65535 used to
# work and is now refused by the daemon with the generic "Invalid argument", so name it here.
validate_padding(){
    validate_uint "$1" || return 1
    [ "${#1}" -le 5 ] || return 1
    [ "$1" -le 65535 ] 2>/dev/null || return 1
    return 0
}

# An AmneziaWG 3.0 "range" param: "N" or "lo-hi", both uint32, hi >= lo.
# The daemon's UintRange.FromString splits on '-' and ParseUint's each half, so a NEGATIVE
# value becomes an empty low bound and dies with the useless `parsing "": invalid syntax`;
# a reversed range dies with "wrong range specified". Both are caught here with a named
# error instead. NB "0" IS legal and means "unset" to the daemon (UintRange.IsZero) —
# it falls back to the stock WireGuard constant, so we pass it through untouched.
validate_range(){
    local v="$1" lo hi
    echo "$v" | grep -qE '^[0-9]+(-[0-9]+)?$' || return 1
    case "$v" in
        *-*) lo="${v%%-*}"; hi="${v##*-}" ;;
        *)   lo="$v"; hi="$v" ;;
    esac
    # uint32 ceiling: 10 digits max, and reject anything above 4294967295 before the
    # shell's own arithmetic has to deal with it.
    [ "${#lo}" -le 10 ] && [ "${#hi}" -le 10 ] || return 1
    [ "$lo" -le 4294967295 ] 2>/dev/null || return 1
    [ "$hi" -le 4294967295 ] 2>/dev/null || return 1
    [ "$lo" -le "$hi" ] 2>/dev/null || return 1
    return 0
}

# An AmneziaWG 3.1 boolean param (RandomTrailers / DisableCookies). The page writes only
# "on"/"off", but a hand-edited settings line may carry the numeric form — amneziawg-tools'
# parse_bool accepts strcasecmp "on"/"off" plus digits, and we pass the value through verbatim,
# so accept exactly that set (lowercased by the page; reject mixed case here to keep the emitted
# conf canonical). Anything else ("true", "yes") would die inside awg with a generic parse error.
validate_onoff(){
    case "$1" in
        on|off|0|1) return 0 ;;
        *) return 1 ;;
    esac
}

# --- AmneziaWG 3.0 capability gate -------------------------------------------------------
# The 7 AWG-3.0 device params need BOTH a v3-aware `awg` CLI (amneziawg-tools gained them only
# on the feat/awg3 branch — NO released tag parses them) AND a v3 daemon. Emitting them at the
# wrong pair is NOT a soft degrade, it kills the tunnel outright:
#   * old awg    -> config.c `goto error` => "Line unrecognized" and setconf_main bails BEFORE
#                   ipc_set_device, so NOTHING is applied and the interface never comes up;
#   * old daemon -> "invalid UAPI device key" => EINVAL => the generic
#                   "Unable to modify interface: Invalid argument" we already have a section
#                   about in CLAUDE.md.
# So: FAIL CLOSED. Anything we cannot positively confirm means "no v3 keys".
# Probe = the tools' OWN parser: `awg setconf <iface-that-does-not-exist> <probe.conf>`.
# setconf parses the whole file before it touches IPC, so the parse verdict is readable with
# zero side effects. Both outcomes exit non-zero, so discriminate on the MESSAGE, never on rc.
# All matching is `case` globs — no grep/sed/awk — so a corrupted Entware coreutils or the
# httpd-inherited LD_LIBRARY_PATH cannot turn this into a false "supported".
AWG_CAPS_FILE="/tmp/.awg_caps"
# 43 base64 chars + '=' — a syntactically valid all-zero key. parse_key only checks the shape,
# and it never reaches a real interface (the probe iface is asserted absent first).
AWG_CAP_DUMMY_KEY="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
# How long a NEGATIVE capability verdict is trusted before re-probing (seconds).
# Positives are cached until the binaries change; negatives expire so a transient
# failure cannot hide the AWG 3.0 fields until the next package update.
AWG_CAPS_NEG_TTL=600

_awg3_probe(){
    local pconf perr iface="awgcap0"
    # Never let the probe touch a live netdev — it would push a zero private key into it.
    [ -e "/sys/class/net/$iface" ] && return 1
    [ -s "$AWG_BIN" ] && [ -x "$AWG_BIN" ] || return 1
    [ -s "$AWG_GO_CANON" ] && [ -x "$AWG_GO_CANON" ] || return 1

    # 1) The daemon: our CI stamps an explicit `-awg3-` marker into version.go's const Version
    #    when it builds from the v3 fork branch. Deliberately an explicit marker and not a
    #    version-number comparison — upstream hardcodes a stale const and we've been fooled by
    #    that string before (see CLAUDE.md).
    case "$("$AWG_GO_CANON" --version 2>/dev/null)" in
        *-awg3-*) ;;
        *) return 1 ;;
    esac

    # 2) The tools: does the config parser know the v3 keys?
    pconf="/tmp/.awg_capprobe.$$"
    {
        echo "[Interface]"
        echo "PrivateKey = $AWG_CAP_DUMMY_KEY"
        echo "HeaderProtectionKey = $AWG_CAP_DUMMY_KEY"
        echo "RekeyTimeout = 5"
        echo "MaxHandshakeAttempts = 3"
    } > "$pconf" 2>/dev/null || return 1
    perr=$("$AWG_BIN" setconf "$iface" "$pconf" 2>&1)
    rm -f "$pconf"
    case "$perr" in
        *"Line unrecognized"*|*"Configuration parsing error"*) return 1 ;;  # old tools
        *"Unable to"*|*"No such"*|*"not exist"*) return 0 ;;                # parsed, IPC failed
        *) return 1 ;;                                                      # unknown => closed
    esac
}

# Cached wrapper. The cache key is `ls -l` of both binaries, so an opkg update (size or mtime
# change) invalidates it for free, and /tmp means a reboot always re-probes.
awg3_supported(){
    local sig lines cached cstamp now
    # BOTH binaries must be listed. Mid-upgrade opkg has already removed one of them, and a probe
    # in that window would cache a bogus "unsupported" under a signature that looks perfectly
    # valid. Field-observed on a real 1.5.0->1.5.2 upgrade: the cached line held only the awg
    # entry, so the page said "AWG 3.0 not supported" until something re-probed. Refuse to
    # answer (and refuse to cache) while the pair is incomplete.
    sig=$(ls -l "$AWG_GO_CANON" "$AWG_BIN" 2>/dev/null)
    lines=$(echo "$sig" | grep -c .)
    [ "$lines" = "2" ] || return 1
    sig=$(echo "$sig" | tr -d ' \n')

    now=$(date +%s 2>/dev/null) || now=0
    if [ -f "$AWG_CAPS_FILE" ]; then
        cached=$(cat "$AWG_CAPS_FILE" 2>/dev/null)
        case "$cached" in
            # A positive verdict is permanent for these binaries: a CLI that parses the v3 keys
            # will not stop, and the daemon's version marker cannot change without the file
            # changing (which moves the signature).
            "awg3=1 $sig") return 0 ;;
            # A NEGATIVE is only trusted for AWG_CAPS_NEG_TTL seconds. It can be produced by a
            # transient failure (no fork memory, a full /tmp, the probe interface briefly
            # existing) and would otherwise stick until the next package update, silently
            # hiding the AWG 3.0 fields for good. Re-probing costs one exec of a static binary.
            "awg3=0 "*" $sig")
                cstamp=$(echo "$cached" | cut -d' ' -f2)
                [ -n "$cstamp" ] && [ "$now" -gt 0 ] 2>/dev/null \
                    && [ $((now - cstamp)) -lt "$AWG_CAPS_NEG_TTL" ] 2>/dev/null && return 1
                ;;
        esac
    fi
    if _awg3_probe; then
        echo "awg3=1 $sig" > "$AWG_CAPS_FILE" 2>/dev/null
        return 0
    fi
    echo "awg3=0 $now $sig" > "$AWG_CAPS_FILE" 2>/dev/null
    return 1
}

# --- AmneziaWG 3.1 capability gate (RandomTrailers / DisableCookies) ---------------------
# Same FAIL-CLOSED contract and the same failure modes as the 3.0 gate above: an old awg CLI
# aborts the whole setconf on the first unknown key, an old daemon EINVALs the UAPI set. A
# SEPARATE gate (not a widened awg3 probe) because the fleet legitimately runs mixed pairs
# mid-upgrade, and "3.0 yes / 3.1 no" must keep the 7 older params flowing.
AWG_CAPS31_FILE="/tmp/.awg_caps31"

_awg31_probe(){
    local pconf perr iface="awgcap0"
    [ -e "/sys/class/net/$iface" ] && return 1
    [ -s "$AWG_BIN" ] && [ -x "$AWG_BIN" ] || return 1
    [ -s "$AWG_GO_CANON" ] && [ -x "$AWG_GO_CANON" ] || return 1

    # CI stamps `-awg31-` next to `-awg3-` when it builds from the v3.1 fork branch. NB the
    # 3.0 gate's `*-awg3-*` glob does NOT match "-awg31-" — both markers are stamped.
    case "$("$AWG_GO_CANON" --version 2>/dev/null)" in
        *-awg31-*) ;;
        *) return 1 ;;
    esac

    pconf="/tmp/.awg_capprobe31.$$"
    {
        echo "[Interface]"
        echo "PrivateKey = $AWG_CAP_DUMMY_KEY"
        echo "RandomTrailers = on"
        echo "DisableCookies = off"
    } > "$pconf" 2>/dev/null || return 1
    perr=$("$AWG_BIN" setconf "$iface" "$pconf" 2>&1)
    rm -f "$pconf"
    case "$perr" in
        *"Line unrecognized"*|*"Configuration parsing error"*) return 1 ;;  # old tools
        *"Unable to"*|*"No such"*|*"not exist"*) return 0 ;;                # parsed, IPC failed
        *) return 1 ;;                                                      # unknown => closed
    esac
}

# Cached wrapper — the awg3_supported contract verbatim (positive pinned to the binaries'
# `ls -l` signature, negative expires after AWG_CAPS_NEG_TTL, incomplete binary pair refuses
# to answer or cache). Kept as its own file so the two verdicts never clobber each other.
awg31_supported(){
    local sig lines cached cstamp now
    sig=$(ls -l "$AWG_GO_CANON" "$AWG_BIN" 2>/dev/null)
    lines=$(echo "$sig" | grep -c .)
    [ "$lines" = "2" ] || return 1
    sig=$(echo "$sig" | tr -d ' \n')

    now=$(date +%s 2>/dev/null) || now=0
    if [ -f "$AWG_CAPS31_FILE" ]; then
        cached=$(cat "$AWG_CAPS31_FILE" 2>/dev/null)
        case "$cached" in
            "awg31=1 $sig") return 0 ;;
            "awg31=0 "*" $sig")
                cstamp=$(echo "$cached" | cut -d' ' -f2)
                [ -n "$cstamp" ] && [ "$now" -gt 0 ] 2>/dev/null \
                    && [ $((now - cstamp)) -lt "$AWG_CAPS_NEG_TTL" ] 2>/dev/null && return 1
                ;;
        esac
    fi
    if _awg31_probe; then
        echo "awg31=1 $sig" > "$AWG_CAPS31_FILE" 2>/dev/null
        return 0
    fi
    echo "awg31=0 $now $sig" > "$AWG_CAPS31_FILE" 2>/dev/null
    return 1
}

validate_ip(){
    echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || return 1
    return 0
}

# --- Generate awg0.conf ---

generate_config(){
    umask 077   # private key + config must not be world-readable
    mkdir -p "$AWG_DIR"

    # The ACTIVE config profile — resolved ONCE here; every field below reads this slot.
    # Slot 1 maps to the legacy unsuffixed keys (see pf_key), so pre-profile installs
    # materialize exactly what they always did. AWG_CFG_SLOT / AWG_CFG_FP (plain globals, set
    # only on success) tell do_start WHICH profile this conf really is — the running-profile
    # record (RUNNING_PF) and the health check's failover circle key off it, never off a
    # re-resolution that a switch/override change in between could move.
    local pf
    AWG_CFG_SLOT=""; AWG_CFG_FP=""
    pf=$(profile_effective)
    log_msg "Config profile: $(profile_desc "$pf")"

    # Neutral field names (see migrate_field_names): iface_p1 = interface private key,
    # peer_p1 = peer public key, peer_p2 = peer preshared key.
    local iface_p1=$(pf_slot_get "$pf" iface_p1)
    local listenport=$(pf_slot_get "$pf" listenport)
    local jc=$(pf_slot_get "$pf" jc)
    local jmin=$(pf_slot_get "$pf" jmin)
    local jmax=$(pf_slot_get "$pf" jmax)
    local s1=$(pf_slot_get "$pf" s1)
    local s2=$(pf_slot_get "$pf" s2)
    local s3=$(pf_slot_get "$pf" s3)
    local s4=$(pf_slot_get "$pf" s4)
    local h1=$(pf_slot_get "$pf" h1)
    local h2=$(pf_slot_get "$pf" h2)
    local h3=$(pf_slot_get "$pf" h3)
    local h4=$(pf_slot_get "$pf" h4)

    # I1-I5 from base64-encoded setting. A long I-param's base64 exceeds the firmware's
    # ~3000-char-per-value custom_settings cap, so the UI splits it across <initdata> +
    # <initdata>1 + <initdata>2 … (per slot) — reassemble the chunks in order before decoding.
    local i1="" i2="" i3="" i4="" i5=""
    local initdata=$(pf_slot_get "$pf" initdata)
    local _ic=1 _ichunk
    while [ "$_ic" -le 30 ]; do
        _ichunk=$(pf_slot_get "$pf" "initdata${_ic}")
        [ -z "$_ichunk" ] && break
        initdata="${initdata}${_ichunk}"
        _ic=$((_ic + 1))
    done
    if [ -n "$initdata" ]; then
        local decoded
        # b64d, not a bare `base64 -d`: stock Merlin has no base64 applet, and there the I-params
        # silently never reached awg0.conf at all (tunnel up, DPI camouflage absent).
        b64d_init
        decoded=$(echo "$initdata" | b64d)
        i1=$(echo "$decoded" | awk '/^I1 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i2=$(echo "$decoded" | awk '/^I2 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i3=$(echo "$decoded" | awk '/^I3 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i4=$(echo "$decoded" | awk '/^I4 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i5=$(echo "$decoded" | awk '/^I5 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
    fi

    local peer_p1=$(pf_slot_get "$pf" peer_p1)
    local peer_p2=$(pf_slot_get "$pf" peer_p2)
    local peer_endpoint=$(pf_slot_get "$pf" peer_endpoint)
    local peer_allowedips=$(pf_slot_get "$pf" peer_allowedips | sed 's/,[[:space:]]*$//;s/,/, /g')
    local peer_keepalive=$(pf_slot_get "$pf" peer_keepalive)

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
    [ -n "$s1" ] && { validate_padding "$s1" || { log_msg "ERROR: Invalid S1: $s1 (0-65535)"; return 1; }; }
    [ -n "$s2" ] && { validate_padding "$s2" || { log_msg "ERROR: Invalid S2: $s2 (0-65535)"; return 1; }; }
    [ -n "$s3" ] && { validate_padding "$s3" || { log_msg "ERROR: Invalid S3: $s3 (0-65535)"; return 1; }; }
    [ -n "$s4" ] && { validate_padding "$s4" || { log_msg "ERROR: Invalid S4: $s4 (0-65535)"; return 1; }; }
    # Jmin > Jmax is silently ACCEPTED by both daemons but is a broken config: the junk size is
    # picked as rand(jmax-jmin+1), and on v3 those are uint32, so the subtraction wraps to a
    # ~4 GiB allocation on the first handshake — instant OOM on a router. Refuse it here.
    if [ -n "$jmin" ] && [ -n "$jmax" ]; then
        [ "$jmin" -le "$jmax" ] 2>/dev/null || { log_msg "ERROR: Jmin ($jmin) must not exceed Jmax ($jmax)"; return 1; }
    fi
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

    # --- AmneziaWG 3.0 device params ---------------------------------------------------
    local hpk cpa rat rto rjt kat mha awg3=0
    hpk=$(pf_slot_get "$pf" hpk)
    cpa=$(pf_slot_get "$pf" cpa); rat=$(pf_slot_get "$pf" rat)
    rto=$(pf_slot_get "$pf" rto); rjt=$(pf_slot_get "$pf" rjt)
    kat=$(pf_slot_get "$pf" kat); mha=$(pf_slot_get "$pf" mha)

    [ -n "$hpk" ] && { validate_wgkey "$hpk" || { log_msg "ERROR: Invalid HeaderProtectionKey"; return 1; }; }
    [ -n "$cpa" ] && { validate_range "$cpa" || { log_msg "ERROR: Invalid ContentPaddingAddition: $cpa (expected \"N\" or \"lo-hi\")"; return 1; }; }
    [ -n "$rat" ] && { validate_range "$rat" || { log_msg "ERROR: Invalid RekeyAfterTime: $rat (expected \"N\" or \"lo-hi\")"; return 1; }; }
    [ -n "$rto" ] && { validate_range "$rto" || { log_msg "ERROR: Invalid RekeyTimeout: $rto (expected \"N\" or \"lo-hi\")"; return 1; }; }
    [ -n "$rjt" ] && { validate_range "$rjt" || { log_msg "ERROR: Invalid RejectAfterTime: $rjt (expected \"N\" or \"lo-hi\")"; return 1; }; }
    [ -n "$kat" ] && { validate_range "$kat" || { log_msg "ERROR: Invalid KeepaliveTimeout: $kat (expected \"N\" or \"lo-hi\")"; return 1; }; }
    [ -n "$mha" ] && { validate_range "$mha" || { log_msg "ERROR: Invalid MaxHandshakeAttempts: $mha (expected \"N\" or \"lo-hi\")"; return 1; }; }

    # HeaderProtection takes its ChaCha20 nonce from the first HeaderCipherNonceSize (=12)
    # bytes of each message's S-padding, so the daemon refuses the config unless ALL FOUR of
    # S1-S4 are >= 12 — including S3 (cookie), which almost nobody sets. Upstream's own error
    # is doubly misleading ("S%d must be more then 8" with a 0-BASED index, so a bad S4 is
    # reported as "S3", and the stated 8 is not the enforced 12), and worse: mergeWithDevice
    # commits H1-H4 BEFORE this check bails, so on a LIVE interface a REJECTED setconf still
    # swaps the magic headers and blackholes the tunnel. Verified against v3.0.1. So refuse
    # here, before awg is ever invoked.
    if [ -n "$hpk" ]; then
        local _sn _sv
        for _sn in 1 2 3 4; do
            eval "_sv=\$s$_sn"
            [ -z "$_sv" ] && _sv=0
            if [ "$_sv" -lt 12 ] 2>/dev/null; then
                log_msg "ERROR: HeaderProtectionKey requires S1-S4 >= 12 (S$_sn = $_sv) — the daemon would reject the config AND could leave a running tunnel dead"
                return 1
            fi
        done
    fi

    # PersistentKeepalive became a range in AWG 3.0 too. It is an OLD key, so an old awg CLI
    # accepts the line and then chokes on the VALUE — same dead tunnel, different message.
    # Validate the shape always, and require awg3 before letting a range through.
    if [ -n "$peer_keepalive" ]; then
        validate_range "$peer_keepalive" || { log_msg "ERROR: Invalid PersistentKeepalive: $peer_keepalive (expected \"N\" or \"lo-hi\")"; return 1; }
        case "$peer_keepalive" in
            *-*) awg3_supported || { log_msg "ERROR: PersistentKeepalive range ($peer_keepalive) needs an AmneziaWG 3.0 build — use a single number on this build"; return 1; } ;;
        esac
    fi

    # Gate the emission: an older awg CLI aborts the WHOLE setconf on the first unknown key,
    # so a v3 line on a v2 box means "tunnel never starts", not "param ignored".
    if [ -n "$hpk$cpa$rat$rto$rjt$kat$mha" ]; then
        if awg3_supported; then
            awg3=1
        else
            log_msg "WARNING: AmneziaWG 3.0 parameters are set but this build does not support them (needs the awg3 daemon + awg CLI) — they are NOT applied; the tunnel starts with the 2.0 parameters only"
        fi
    fi

    # --- AmneziaWG 3.1 device params ---------------------------------------------------
    # RandomTrailers is SYMMETRIC (the daemon only accepts trailered handshake packets when
    # its OWN flag is on, and the far side drops OUR trailered handshakes unless it has the
    # flag too) — it comes from the provider config and must be passed through verbatim.
    # DisableCookies is local-only. Same fail-closed emission gate as the 3.0 set: on an
    # older pair the keys abort the whole setconf, so unsupported means "not emitted".
    local rt dc awg31=0
    rt=$(pf_slot_get "$pf" rt)
    dc=$(pf_slot_get "$pf" dc)
    [ -n "$rt" ] && { validate_onoff "$rt" || { log_msg "ERROR: Invalid RandomTrailers: $rt (expected \"on\" or \"off\")"; return 1; }; }
    [ -n "$dc" ] && { validate_onoff "$dc" || { log_msg "ERROR: Invalid DisableCookies: $dc (expected \"on\" or \"off\")"; return 1; }; }
    if [ -n "$rt$dc" ]; then
        if awg31_supported; then
            awg31=1
        else
            log_msg "WARNING: AmneziaWG 3.1 parameters (RandomTrailers/DisableCookies) are set but this build does not support them — they are NOT applied. NB a provider endpoint that REQUIRES RandomTrailers will drop our handshakes without it."
        fi
    fi

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
        if [ "$awg3" = "1" ]; then
            [ -n "$hpk" ] && echo "HeaderProtectionKey = $hpk"
            [ -n "$cpa" ] && echo "ContentPaddingAddition = $cpa"
            [ -n "$rat" ] && echo "RekeyAfterTime = $rat"
            [ -n "$rto" ] && echo "RekeyTimeout = $rto"
            [ -n "$rjt" ] && echo "RejectAfterTime = $rjt"
            [ -n "$kat" ] && echo "KeepaliveTimeout = $kat"
            [ -n "$mha" ] && echo "MaxHandshakeAttempts = $mha"
        fi
        if [ "$awg31" = "1" ]; then
            [ -n "$rt" ] && echo "RandomTrailers = $rt"
            [ -n "$dc" ] && echo "DisableCookies = $dc"
        fi
        echo ""
        echo "[Peer]"
        echo "PublicKey = $peer_p1"
        [ -n "$peer_p2" ] && echo "PresharedKey = $peer_p2"
        [ -n "$peer_endpoint" ] && echo "Endpoint = $peer_endpoint"
        echo "AllowedIPs = ${peer_allowedips:-0.0.0.0/0}"
        [ -n "$peer_keepalive" ] && echo "PersistentKeepalive = $peer_keepalive"
    } > "$CONF"

    chmod 600 "$CONF"

    # Address/DNS side-files: always rewrite (or remove) — a profile switch must not leave the
    # previous slot's address/DNS behind for do_start to apply to the new tunnel.
    local address=$(pf_slot_get "$pf" address)
    if [ -n "$address" ]; then echo "$address" > "$AWG_DIR/awg0.addr"; else rm -f "$AWG_DIR/awg0.addr"; fi
    local dns=$(pf_slot_get "$pf" dns)
    if [ -n "$dns" ]; then echo "$dns" > "$AWG_DIR/awg0.dns"; else rm -f "$AWG_DIR/awg0.dns"; fi

    AWG_CFG_SLOT=$pf
    AWG_CFG_FP=$(pf_fp_of "$iface_p1" "$peer_p1")
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

# Mask secret values from a stream on stdin, so the dump is safe to paste into a chat/issue.
# Public keys, endpoint and obfuscation params are kept — they're needed to debug a setconf
# rejection and aren't secret. HeaderProtectionKey IS secret: knowing it lets an observer decrypt
# the packet headers, which is exactly what AmneziaWG 3.0 hides.
# Two shapes are handled, because two different producers feed this:
#   * `Key = value`   — our generated awg0.conf and any config paste;
#   * `label: value`  — the `awg show` pretty output, where v3 prints the header protection key in
#                       full (show.c uses key(), not masked_key(), unlike the preshared key).
# NOT handled: the tab-separated `awg show <if> dump`, whose interface line carries the private key
# and the header protection key. Nothing pipes that into diag — keep it that way.
redact_secrets(){
    sed -e 's/\(PrivateKey[[:space:]]*=[[:space:]]*\).*/\1<redacted>/' \
        -e 's/\(PresharedKey[[:space:]]*=[[:space:]]*\).*/\1<redacted>/' \
        -e 's/\(HeaderProtectionKey[[:space:]]*=[[:space:]]*\).*/\1<redacted>/' \
        -e '/header protection key/ s/:.*/: <redacted>/'
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
    for _t in grep sed awk sort md5sum sha256sum base64 openssl curl; do
        echo "  which $_t : $(which "$_t" 2>/dev/null || echo '(not found)')"
    done
    b64d_init
    echo "  base64 decoder  : $AWG_B64D   (base64 applet absent on stock Merlin -> openssl/awk fallback; GeoCustom URLs/files + I1-I5 depend on it)"
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
    echo "--- last amneziawg-go output ($DAEMON_LOG) ---"
    [ -f $DAEMON_LOG ] && sed 's/^/  /' $DAEMON_LOG || echo "  (none)"
    echo "  last daemon exit (this launch): $(cat $DAEMON_RC 2>/dev/null || echo '(none — daemon still running or never exited)')"
    echo "  Go runtime tune (computed now): $(go_tune_desc)"
    is_running && [ -r "$DAEMON_TUNE" ] && \
        echo "  Go runtime tune (applied at launch, GOMEMLIMIT|pool cap): $(cat "$DAEMON_TUNE" 2>/dev/null)"
    if grep -qiE 'out of memory|^fatal error: .*memory' $DAEMON_LOG 2>/dev/null; then
        echo "  >>> last daemon exit was a Go runtime OUT-OF-MEMORY: heap hit the ceiling under load (box low on RAM for this throughput) <<<"
    elif grep -qE '^(panic: |fatal error: |unexpected fault address)' $DAEMON_LOG 2>/dev/null; then
        echo "  >>> last daemon exit was a Go CRASH (panic / fault), NOT an OOM: a daemon or runtime bug, or bad RAM / USB I/O errors — please report it with this diag <<<"
    fi
    if [ -s "$DAEMON_CRASH" ]; then
        echo "--- last daemon CRASH trace ($DAEMON_CRASH — survives relaunches, not a reboot) ---"
        head -n 40 "$DAEMON_CRASH" 2>/dev/null | sed 's/^/  /'
    fi
    echo "--- runtime / network / TUN ---"
    echo "memory (free):"; free 2>/dev/null | sed 's/^/  /'
    # Free RAM is the WRONG lens under vm.overcommit_memory=2 — the budget that decides
    # whether the Go runtime can grow its heap is CommitLimit - Committed_AS. Print both,
    # plus swap (the user-side lever that raises CommitLimit), so a squeezed box is
    # diagnosable from the diag alone instead of needing an SSH session.
    _oc=$(awk '{print $1; exit}' /proc/sys/vm/overcommit_memory 2>/dev/null)
    _cl=$(awk '/^CommitLimit:/{printf "%d", $2/1024; exit}' /proc/meminfo 2>/dev/null)
    _ca=$(awk '/^Committed_AS:/{printf "%d", $2/1024; exit}' /proc/meminfo 2>/dev/null)
    echo "vm.overcommit_memory : ${_oc:-?}$([ "${_oc:-}" = 2 ] && echo ' (STRICT accounting: the heap budget is CommitLimit - Committed_AS, NOT free RAM)')"
    echo "commit budget        : CommitLimit=${_cl:-?}MiB Committed_AS=${_ca:-?}MiB swap=$(swap_total_mib)MiB"
    # Top memory users, eight lines, so a field diag answers "what is eating it" without a
    # second round-trip. The full breakdown (modules, Trend Micro switches) is `mem`.
    # Fed through `cat`, NOT as awk file operands: awk (busybox and gawk alike) aborts on the
    # first operand it cannot open, and a process exiting between the glob and the read
    # would silently truncate the list; cat skips the vanished file and goes on.
    echo "top memory users by RSS (RSS KB / VmData KB — on pre-4.5 kernels VmData also counts reserved Go heap address space; Committed_AS above is the commit authority):"
    cat /proc/[0-9]*/status 2>/dev/null \
        | awk '/^Name:/{n=$2; r=0} /^VmRSS:/{r=$2} /^VmData:/{printf "  %8d %8d  %s\n", r, $2, n}' | sort -rn | head -8
    _msq=$(mem_squeeze_state)
    [ -n "$_msq" ] && echo "  >>> MEMORY ENVELOPE AT ITS FLOOR ($_msq = state|GOMEMLIMIT MiB|pool cap|swap MiB) — strict overcommit leaves so little commit headroom that the daemon runs (or would start) with GOMEMLIMIT at the ${AWG_GOMEMLIMIT_COMMIT_FLOOR}MiB floor and the pool at its 512-buffer liveness floor; sustained load can OOM-abort it and the watchdog restarts it (reads as 'the VPN drops now and then'). Box-side levers: a swap file (raises CommitLimit 1:1) and/or fewer user-space memory consumers <<<"
    echo "amneziawg-go running : $(pidof amneziawg-go 2>/dev/null || echo no)"
    echo "dnsmasq running      : $(pidof dnsmasq 2>/dev/null || echo no)"
    echo "--- persistent incident log (survives reboot; last LAN-critical events) ---"
    if [ -s "$AWG_INCIDENTS" ]; then sed 's/^/  /' "$AWG_INCIDENTS"; else echo "  (none — no auto-rollback / dnsmasq-down / damaged-binary incident recorded)"; fi
    echo "--- connection history (last 5: start_epoch|end_epoch|dur_s|reason) ---"
    if [ -s "$CONN_HISTORY" ]; then sed 's/^/  /' "$CONN_HISTORY"; else echo "  (none recorded yet)"; fi
    [ -f "$CONN_CURRENT" ] && echo "  open session (start_epoch start_uptime_s): $(cat "$CONN_CURRENT" 2>/dev/null)"
    echo "--- config profiles (endpoint shown, keys never; slot = stable storage number, #k = the number the page shows) ---"
    profile_cli_list diag 2>/dev/null | sed 's/^/  /'
    # Every input of the slot resolution, raw, next to what it resolved to — a "wrong profile
    # came up" report is answerable from these lines alone. fp = <md5(privkey) prefix>@<peer
    # pubkey> (profile_resolve): not secret-bearing.
    _dpu=$(get_setting awg_profile_active)
    _dus=$(profile_user)
    profile_resolve; _deff=$AWG_PF_EFF
    echo "  user's choice        : awg_profile_active=${_dpu:-(unset)} -> slot $_dus = $(profile_desc "$_dus")"
    echo "  failover override    : $([ -f "$PF_OVERRIDE" ] && echo "\"$(cat "$PF_OVERRIDE" 2>/dev/null)\" ($PF_OVERRIDE)" || echo none)"
    echo "  effective profile    : slot $_deff = $(profile_desc "$_deff")$([ "$_deff" != "$_dus" ] && echo ' — failover override in effect')"
    echo "  effective fp         : $(pf_fp "$_deff")"
    echo "  running profile      : $([ -f "$RUNNING_PF" ] && echo "slot+fp = $(cat "$RUNNING_PF" 2>/dev/null)" || echo '(no record — tunnel stopped, or started by a pre-1.5.26 version)')"
    [ -f "$FAILOVER_STATE" ] && echo "  failover circle      : start+hops = $(tr '\n' ' ' < "$FAILOVER_STATE" 2>/dev/null)(incident in progress)"
    # Start/stop generation (a stale health check compares its own against this before acting),
    # the STARTING_FLAG owner and an in-flight switch request.
    echo "  start/stop gen       : $(cat "/tmp/.${IFACE}_gen" 2>/dev/null || echo none)"
    echo "  starting flag        : $([ -f "$STARTING_FLAG" ] && echo "set, owner $(cat "$STARTING_FLAG" 2>/dev/null)" || echo clear)"
    echo "  switch request       : $([ -f "$SWITCH_REQ" ] && echo "slot+epoch = $(cat "$SWITCH_REQ" 2>/dev/null)" || echo none)"
    # The pages' save token (the LAST key of every settings POST since 1.5.26): absent after a
    # page save = the firmware wrote the store only partially (full JFFS) or discarded it.
    _dtok=$(get_setting awg_save_tok)
    echo "  awg_save_tok         : $([ -n "$_dtok" ] && echo "present ($_dtok)" || echo absent)"
    echo "--- self-heal / background state ---"
    echo "awg crons (cru l):"
    _crons=$(cru l 2>/dev/null | grep -i awg)
    if [ -n "$_crons" ]; then echo "$_crons" | sed 's/^/  /'; else echo "  (NONE — watchdog/status cron not scheduled!)"; fi
    echo "watchdog last tick   : $([ -f /tmp/.awg_wd_beat ] && cat /tmp/.awg_wd_beat || echo '(never — cron not firing, or pre-1.2.31)')"
    echo "watchdog fail state  : $([ -f /tmp/.awg_wd_state ] && tr '\n' ' ' < /tmp/.awg_wd_state || echo none)"
    # A non-empty list means the */1 status cron is being wedged by the firmware's nvram IPC
    # (see reap_stale_status). The next status tick reaps them, so a count here that keeps
    # growing means the reaper itself is not running — check the cron list above first.
    _stale=$(stale_status_pids)
    if [ -n "$_stale" ]; then
        echo "stale status runs    : $(echo $_stale | wc -w) — pids$_stale (wedged 'nvram get'; reaped on the next status tick)"
    else
        echo "stale status runs    : none"
    fi
    echo "locks (a DEAD holder = operation crashed mid-flight):"
    for _L in "$LOCKDIR" "$GEOLOCK" /tmp/.awg_dnsreload; do
        if [ -d "$_L" ]; then
            _lp2=$(cat "$_L/pid" 2>/dev/null)
            if [ -n "$_lp2" ] && kill -0 "$_lp2" 2>/dev/null; then
                # Holder age makes a wedged job visible at a glance (the 2026-08-24 field diag
                # showed only "alive" — the 6-minute hang had to be inferred from timestamps).
                _la2=$(proc_age_s "$_lp2")
                echo "  $_L : held by pid $_lp2 (alive${_la2:+, ${_la2}s old})"
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
    # Boot/Entware-init forensics (1.5.8, field: RT-BE92U @ 3006.102.8): when the firmware's
    # native Entware starter and the amtm/post-mount hook collide, NEITHER runs the
    # /opt/etc/init.d/S* start scripts ("Not starting Entware services … already started" in
    # syslog) — S99amneziawg start never fires, autostart silently dies and the status/
    # watchdog crons (installed by do_start only) never appear. One glance answers it here.
    echo "--- boot / Entware init (autostart) ---"
    echo "S99 init script      : $([ -x /opt/etc/init.d/S99amneziawg ] && echo present || echo 'ABSENT — /opt not mounted (or package removed)')"
    if [ -f "$BOOT_MARKER" ]; then
        echo "boot_start invoked   : yes ($(date -r "$BOOT_MARKER" 2>/dev/null || echo 'marker present'))"
    else
        echo "boot_start invoked   : NO — the Entware init never ran 'S99amneziawg start' this boot (autostart + crons never armed; see the Entware syslog lines below)"
    fi
    echo "boot fallback (guard): $(cat "$BOOT_GUARD_STATE" 2>/dev/null || echo '(no state — hook pre-1.5.8, or not rebooted since the update)')"
    echo "services-start hook  :"
    _ss_hook=$(grep -n "amneziawg" /jffs/scripts/services-start 2>/dev/null)
    if [ -n "$_ss_hook" ]; then echo "$_ss_hook" | sed 's/^/  /'; else echo "  (MISSING — neither the page mount nor the boot fallback are armed!)"; fi
    echo "firewall-start hook  :"
    _fw_hook=$(grep -n "amneziawg" /jffs/scripts/firewall-start 2>/dev/null)
    if [ -n "$_fw_hook" ]; then echo "$_fw_hook" | sed 's/^/  /'; else echo "  (MISSING — after a firmware firewall rebuild the rules heal only on the next watchdog tick, <=5 min)"; fi
    echo "Entware start/skip (syslog):"
    _ent_log=$(grep -i "Entware services" /tmp/syslog.log-1 /tmp/syslog.log 2>/dev/null | tail -n 4)
    if [ -n "$_ent_log" ]; then echo "$_ent_log" | sed 's/^/  /'; else echo "  (no 'Starting/Not starting Entware services' lines in syslog)"; fi
    if [ -f /jffs/scripts/post-mount ]; then
        echo "post-mount Entware refs:"
        _pm_ent=$(grep -inE 'entware|rc\.unslung' /jffs/scripts/post-mount 2>/dev/null | head -n 6)
        if [ -n "$_pm_ent" ]; then echo "$_pm_ent" | sed 's/^/  /'; else echo "  (post-mount exists but has no Entware lines)"; fi
    else
        echo "post-mount           : (no /jffs/scripts/post-mount)"
    fi
    echo "--- co-resident DPI / coexistence ---"
    _dpi_tool=$(detect_dpi_tool 2>/dev/null)
    echo "co-resident DPI tool : ${_dpi_tool:-none}"
    echo "b4 process           : $(pidof b4 >/dev/null 2>&1 && echo yes || echo no)"
    _b4_be=""
    if iptables-save 2>/dev/null | grep -q 'NFQUEUE'; then _b4_be="iptables"; fi
    if nft list ruleset 2>/dev/null | grep -qE 'queue (num|to)'; then _b4_be="${_b4_be:+$_b4_be+}nft"; fi
    echo "NFQUEUE backend seen : ${_b4_be:-none}"
    echo "compat (no DNS hijack): $([ "$(get_setting awg_no_dns_intercept)" = "1" ] && echo "ON (coexist)" || echo off)"
    echo "geo match-all ipset  : $(_fm=$(geo_foreign_matchall); [ -n "$_fm" ] && echo "FOREIGN line routes ALL domains into a geo set -> Geo sends EVERY site via VPN: $_fm" || echo none)"
    echo "kernel / sendmmsg    : $(uname -r) -> $(kernel_pre_sendmmsg && echo 'pre-3.0 (2.6.x): no native sendmmsg — daemon uses the bundled smfix per-packet fallback; SUPPORTED since 1.2.61 (guard removed; disable CTF first if present)' || echo 'ok (>=3.0)')"
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
        # EVERY secret-bearing field must be matched with the OPTIONAL profile-slot prefix. The
        # anchors used to be bare `^awg_iface_p1` / `^awg_peer_p2`, which matched slot 1 only —
        # slots 2-5 are `awg_pf<N>_iface_p1` / `awg_pf<N>_peer_p2` (see pf_key), so every
        # secondary profile's PRIVATE and PRESHARED key was printed in clear into a file users
        # routinely paste into chats. `hpk` (HeaderProtectionKey) needs the same treatment and
        # matches none of the generic /priv/ /psk/ /preshar/ /secret/ globs — note /psk/ does NOT
        # match "hpk". Neutral field names come from migrate_field_names: iface_p1 = interface
        # private key, peer_p2 = peer preshared key.
        # Records are split exactly like get_setting (the firmware glues the NEXT key onto an
        # over-long line — a glued private key used to print in clear under the previous key's
        # name), and long blobs (file/initdata base64) are shortened to their length: noise in a
        # pasted diag.
        LC_ALL=C awk '
            function emit(r,   k, v) {
                k = r; sub(/ .*/, "", k)
                if (k !~ /^awg_/) return
                if (++shown > 120) { more++; return }   # capped HERE, so the glued note below always prints
                if (k ~ /^awg_(pf[0-9]+_)?iface_p1/ || k ~ /^awg_(pf[0-9]+_)?peer_p2/ || k ~ /^awg_(pf[0-9]+_)?hpk/ || k ~ /priv/ || k ~ /psk/ || k ~ /preshar/ || k ~ /secret/) { print k " <redacted>"; return }
                v = (index(r, " ") ? substr(r, index(r, " ") + 1) : "")
                if (length(v) > 160) v = substr(v, 1, 48) "...(" length(v) " chars)"
                print k " " v
            }
            { r = $0
              if (length(r) > 3039) glued = glued " " NR
              while (length(r) > 3039) { emit(substr(r, 1, 3039)); r = substr(r, 3040) }
              emit(r) }
            END { if (more) print "... (" more " more awg_ keys not shown)"
                  if (glued != "") print "!! custom_settings line(s)" glued ": a record overflowed the firmware 3039-byte cap and the next key got glued onto it" }' "$SETTINGS" 2>/dev/null | sed 's/^/  /'
    else echo "  (no $SETTINGS)"; fi
    echo "--- awg show (live UAPI state, secrets redacted) ---"
    # Through redact_secrets: an AmneziaWG 3.0 daemon makes `awg show` print the header protection
    # key in full, and this output goes straight into the pasteable diag.
    if pidof amneziawg-go >/dev/null 2>&1; then "$AWG_BIN" show "$IFACE" 2>&1 | redact_secrets | sed 's/^/  /'; else echo "  (daemon not running)"; fi
    echo "--- routing (rule / table $RT_TABLE / fwmark marks) ---"
    echo "ip rule:"; ip rule show 2>/dev/null | sed 's/^/  /'
    echo "ip route table $RT_TABLE:"; ip route show table "$RT_TABLE" 2>/dev/null | sed 's/^/  /'
    echo "mangle marks:"; mangle_dump | grep -iE 'awg|0x100|MARK' | head -60 | sed 's/^/  /'
    # Copy counters scoped to OUR rules. The old bare `grep -c TCPMSS` also counted FOREIGN
    # clamps (field RT-BE92U: xrayui_custom's PPTP MSS rule kept the counter at 1 with both
    # tunnels down), and the server role's rules matched the client substrings — its
    # double-hop NAT `-s <subnet> -o awg0 -j MASQUERADE` ends in the client's exact rule, so
    # a healthy dual-role box read "MASQUERADE: 2" and looked like duplicates. Expected per
    # ACTIVE role: client = 2 TCPMSS (awg0) + 1 INPUT accept + 1 exact MASQ; server = 2
    # TCPMSS (awgs0) + 1 double-hop MASQ (its WAN/br0-scoped MASQs and the udp-port accept
    # live in the server's own diag). Duplicates = one of OUR counts above its expectation;
    # the foreign line is informational. TCPMSS counts ride mangle_dump (firmware binary
    # first) so an Entware iptables aborting on a proprietary target (SKIPLOG) can't
    # truncate them mid-table. printf '%s' (no \n) keeps an empty capture at 0 lines —
    # `printf '%s\n' ""` would feed grep -cv one empty line and fake a count of 1.
    _fwd_mss=$(mangle_dump | grep '^-A FORWARD' | grep TCPMSS)
    _nat_post=$(iptables -t nat -S POSTROUTING 2>/dev/null)
    echo "rule copy counts (expected per ACTIVE role: client TCPMSS=2 accept=1 masq=1, server TCPMSS=2 double-hop-masq=1; more of OURS = duplicates):"
    echo "  TCPMSS clamp awg0  : $(printf '%s' "$_fwd_mss" | grep -c "awg0 ")"
    echo "  TCPMSS clamp awgs0 : $(printf '%s' "$_fwd_mss" | grep -c "awgs0 ")"
    echo "  TCPMSS foreign     : $(printf '%s' "$_fwd_mss" | grep -v "awg0 " | grep -cv "awgs0 ") (other tools' clamps, e.g. a PPTP MSS fix — not ours)"
    echo "  INPUT accept awg0  : $(iptables -S INPUT 2>/dev/null | grep -c -- "-i $IFACE -j ACCEPT")"
    echo "  MASQ awg0 exact    : $(printf '%s' "$_nat_post" | grep -c -- "^-A POSTROUTING -o awg0 -j MASQUERADE$")"
    echo "  MASQ double-hop    : $(printf '%s' "$_nat_post" | grep -- "-o awg0 -j MASQUERADE" | grep -cv -- "^-A POSTROUTING -o awg0 -j MASQUERADE$") (server peers: -s <subnet> -o awg0)"
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

# `mem` — who is eating what, split by the TWO budgets that actually decide whether the
# daemon survives (1.5.23). They are NOT the same budget, and conflating them sends people
# after the wrong knob — which is the whole reason this subcommand exists:
#
#   * PHYSICAL RAM (MemFree/MemAvailable, RSS, slab, kernel modules). This is what makes the
#     box feel full and what makes small helpers die oddly (a field diag showed busybox grep
#     taking SIGSEGV mid-apply, which silently zeroed that run's domain list).
#   * COMMIT BUDGET (CommitLimit - Committed_AS). Under vm.overcommit_memory=2 this — not
#     free RAM — is what compute_go_memlimit clamps GOMEMLIMIT against, so it is what pins a
#     box to the 64MiB floor. CommitLimit = overcommit_ratio% x MemTotal + SwapTotal, so
#     SWAP raises it 1:1, while freeing memory helps only as far as it lowers Committed_AS.
#     Kernel-module memory (the tdts/IDPfw Trend Micro engine behind AiProtection, Traffic
#     Analyzer and Adaptive QoS) costs physical RAM but is NOT charged to Committed_AS —
#     the features' USER-SPACE services are. So unloading the engine alone frees RAM
#     without lifting the ceiling; stopping the services behind it does lift it.
#
# Per-process numbers come from one awk pass over /proc/<pid>/status (VmData appears AFTER
# VmRSS there, so a single forward scan has both by the time it prints), fed through `cat`
# so a process that exits mid-scan can't abort awk. There is no per-process Committed_AS in
# /proc, and VmData is not one: on pre-4.5 kernels (BCM675x 4.1) it also counts reserved
# PROT_NONE address space — the Go daemon's heap reservation, hundreds of MB — so the report
# reconciles the two totals out loud rather than implying they should match. Kernel threads
# have neither line and drop out on their own. This is a MANUAL command, so the fork
# discipline that governs the every-minute paths (see reap_stale_status) does not apply here.
do_mem_report(){
    local _oc _ratio _cl _ca _hr _msq _need
    echo "================= AmneziaWG memory report ================="
    echo "addon version    : $AWG_VERSION"
    echo "date             : $(date)"
    echo "model / firmware : $(nvram get productid 2>/dev/null) / $(nvram get buildno 2>/dev/null).$(nvram get extendno 2>/dev/null)"
    echo "--- budgets ---"
    awk '/^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Slab|SReclaimable|SUnreclaim|CommitLimit|Committed_AS):/{printf "  %-16s %8.1f MB\n",$1,$2/1024}' /proc/meminfo 2>/dev/null
    _oc=$(awk '{print $1; exit}' /proc/sys/vm/overcommit_memory 2>/dev/null)
    _ratio=$(awk '{print $1; exit}' /proc/sys/vm/overcommit_ratio 2>/dev/null)
    echo "  overcommit_memory ${_oc:-?} (ratio ${_ratio:-?})$([ "${_oc:-}" = 2 ] && echo ' — STRICT: the daemon ceiling follows CommitLimit - Committed_AS, NOT free RAM')"
    _cl=$(awk '/^CommitLimit:/{printf "%d", $2/1024; exit}' /proc/meminfo 2>/dev/null)
    _ca=$(awk '/^Committed_AS:/{printf "%d", $2/1024; exit}' /proc/meminfo 2>/dev/null)
    # Both counters validated SEPARATELY — "$_cl$_ca" as one word would pass with one empty.
    _hr=''
    case "$_cl" in ''|*[!0-9]*) : ;; *) case "$_ca" in ''|*[!0-9]*) : ;; *)
        _hr=$(( _cl - _ca )); echo "  commit headroom  $(printf '%8d' $_hr) MB  (CommitLimit - Committed_AS: the pool the daemon ceiling is cut from)" ;; esac ;; esac
    echo "--- what the addon does with that ---"
    echo "  $(go_tune_desc)   [computed now]"
    is_running && [ -r "$DAEMON_TUNE" ] && \
        echo "  running daemon was launched with (GOMEMLIMIT|pool cap): $(cat "$DAEMON_TUNE" 2>/dev/null)"
    _msq=$(mem_squeeze_state)
    if [ -n "$_msq" ]; then
        echo "  >>> ENVELOPE AT ITS FLOOR ($_msq = state|GOMEMLIMIT MiB|pool cap|swap MiB) <<<"
        # The clamp is (CommitLimit - Committed_AS) x COMMIT_PCT%, so the ceiling leaves the
        # floor once the headroom exceeds FLOOR x 100 / COMMIT_PCT — print that target and
        # both ways to reach it (swap adds to CommitLimit 1:1; the rest must come off
        # Committed_AS), instead of a rule of thumb that only fits one box size.
        _need=$(( AWG_GOMEMLIMIT_COMMIT_FLOOR * 100 / AWG_GOMEMLIMIT_COMMIT_PCT ))
        if [ -n "$_hr" ] && [ "$_hr" -lt "$_need" ]; then
            echo "      the ceiling leaves its floor once the commit headroom exceeds ~${_need}MB (now ${_hr}MB): raise CommitLimit by ~$(( _need - _hr ))MB or more (SwapTotal adds 1:1 — amtm's usual swap file is 1GB), or cut Committed_AS by as much (to under ~$(( _cl - _need ))MB). A running tunnel picks up the new ceiling on its next restart."
        fi
    fi
    echo "--- processes: top 20 by RSS (Data = VmData, see the caveat below) ---"
    printf '  %8s %8s  %s\n' "RSS KB" "Data KB" "process"
    cat /proc/[0-9]*/status 2>/dev/null \
        | awk '/^Name:/{n=$2; r=0} /^VmRSS:/{r=$2} /^VmData:/{printf "%8d %8d  %s\n", r, $2, n}' \
        | sort -rn | head -20 | sed 's/^/  /'
    # VmData is not a process's commit contribution. On pre-4.5 kernels it also counts
    # reserved (PROT_NONE) address space, and the Go runtime reserves a large heap-arena
    # range it never commits, so amneziawg-go can show hundreds of MB of Data against
    # single-digit MB of RSS. Print the reconciliation instead of hiding it — Committed_AS
    # is the authority, and a wide gap is normal on a box running a Go daemon, NOT a leak.
    # (Field report, 1.5.23: sum(VmData)=689MB vs Committed_AS=253MB, all of the gap one
    # amneziawg-go.)
    cat /proc/[0-9]*/status 2>/dev/null | awk -v ca="$_ca" '/^VmRSS:/{s+=$2} /^VmData:/{d+=$2; n++} END{
            printf "  TOTAL: RSS %.1f MB, Data %.1f MB across %d processes\n", s/1024, d/1024, n
            if (ca+0 > 0 && d/1024 > ca*1.3)
                printf "  NB: Data totals %.1f MB against Committed_AS %d MB — the gap is address space\n      reserved but never committed (older kernels count the Go heap reservation in VmData). Committed_AS rules.\n", d/1024, ca
        }'
    # Unreclaimable slab is kernel memory no process owns and no process list can explain —
    # on Broadcom boxes the wl driver's packet pools alone run to a third of RAM. Call it out
    # so it isn't hunted for in the process table above.
    awk '/^SUnreclaim:/{ if ($2/1024 > 80) printf "  NB: %.1f MB of unreclaimable kernel slab — owned by no process (Broadcom wl/flow-cache pools,\n      conntrack, the Trend Micro engine). Breakdown: sort -k3 -rn /proc/slabinfo | head\n", $2/1024 }' /proc/meminfo 2>/dev/null
    echo "--- kernel modules: top 12 by size (cost RAM, invisible to Committed_AS) ---"
    awk '{printf "  %8.0f KB  %s\n", $2/1024, $1}' /proc/modules 2>/dev/null | sort -rn | head -12
    awk '{s+=$2} END{printf "  TOTAL modules: %.1f MB\n", s/1048576}' /proc/modules 2>/dev/null
    echo "--- Trend Micro engine (tdts/IDPfw): which switch keeps it resident ---"
    # The AiProtection toggles are only one of its consumers — Traffic Analyzer, App
    # analysis, Web History and Adaptive QoS (qos_type=1) load the same engine, so a user
    # who "turned AiProtection off" in the GUI can still be paying for it. ONE nvram show
    # (never a per-key `nvram get` loop — see the 1.5.10 hang note).
    if awk '{print $1}' /proc/modules 2>/dev/null | grep -qE '^(tdts|IDPfw)$'; then
        echo "  engine LOADED"
    else
        echo "  engine not loaded"
    fi
    nvram show 2>/dev/null \
        | awk -F= '/^(wrs_enable|wrs_app_enable|wrs_cc_enable|wrs_vp_enable|bwdpi_db_enable|bwdpi_wh_enable|apps_analysis|qos_enable|qos_type|TM_EULA)=/{print "  "$0}' \
        | sort
    echo "==========================================================="
    echo "Tip: run this twice — once idle, once while heavy traffic (video) flows through the"
    echo "tunnel. amneziawg-go's Data column grows by the buffer pool; the delta is what the"
    echo "tunnel actually needs under your load."
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
# LOW-RAM-ONLY GATE (1.3.13): the GC tune — GOMEMLIMIT + GOGC=50 — applies only when
# MemTotal is BELOW this many MiB; roomier boxes launch the daemon with stock Go GC.
# Why: GOGC=50 makes the collector run twice as often as stock and that CPU comes
# straight out of the crypto workers — a measurable throughput cut on boxes that were
# never at OOM risk (field report: strong boxes got slower after the tune). Low-RAM
# boxes keep the caps: every field OOM was a <=512MB box (RT-AX82U 512MB, RT-AC68U
# 256MB — MemTotal reads ~440-510MB there), while 1GB-class boxes report ~880MB+.
#
# The BUFFER POOL CAP (PreallocatedBuffersPerPool=1024, compiled into the daemon) stays
# on ALL boxes — it is NOT just low-RAM armor, it is load-bearing FLOW CONTROL. 1.3.13
# un-capped it on roomy boxes (WG_PREALLOCATED_BUFFERS_PER_POOL=0) and a 2GB RT-BE88U
# field-crashed within minutes: awgs-go's UDP-TX leg to a Wi-Fi peer drains far slower
# than local RX fills (the "10 Mbit down / 364 Mbit up" asymmetry), so without the cap
# the heap ballooned at line rate and the Go runtime OOM-aborted — 3 incidents in 6 min
# (2026-07-16, incidents.log), watchdog crash-looped the server. With the cap the same
# imbalance just throttles (WaitPool.Get blocks the reader): slow but ALIVE. Reverted in
# 1.3.14: the launcher never RAISES the cap, and 0 (= UNBOUNDED to the daemon) is never
# emitted; the -poolcfg daemon keeps honoring WG_PREALLOCATED_BUFFERS_PER_POOL for
# manual experiments.
#
# 1.5.22: on CONSTRAINED boxes the launcher now LOWERS the cap (compute_pool_cap below).
# Strict-overcommit firmwares (vm.overcommit_memory=2 — seen on gnuton 388.11 / 512MB
# RT-AX82U_V2 and stock 3006.102 / 2GB RT-BE88U) shrink the commit budget so far that
# GOMEMLIMIT lands at its 64MiB overcommit floor while the compiled pool cap ALONE may
# pin 1024x64KB = 64MB — the entire ceiling. Under an RX burst the pool fills toward its
# cap, blows through the SOFT limit (GOMEMLIMIT never refuses an allocation) and the
# next heap-arena mmap exceeds the commit budget -> `runtime: out of memory` rc=2 abort
# seconds after start (field 2026-08-26, AX82U_V2 @1.5.21: 25+ OOM incidents in 2 days,
# one crash 8 s after a watchdog restart; user-visible as «рвётся каждую минуту на
# ~30 сек» — OOM -> health-check/watchdog restart -> OOM). A TIGHTER cap is MORE flow
# control, so the 1.3.14 lesson stands untouched; roomy boxes keep the compiled 1024
# (env not exported at all).
AWG_GOTUNE_BELOW_MIB=768

# STRICT-OVERCOMMIT GUARD (1.3.15): MemTotal is the WRONG lens when the kernel runs
# vm.overcommit_memory=2 (strict accounting): the budget that matters is CommitLimit -
# Committed_AS, and a Go runtime aborts with `runtime: out of memory` the moment a
# heap-arena mmap exceeds it — REGARDLESS of free physical RAM. Field (2026-07-16): the
# same 2GB RT-BE88U that OOM-looped in 1.3.13 turned out to run overcommit=2 with
# CommitLimit ~1GB and only ~190MiB headroom while IDLE — 1.3.14's "roomy => stock GC"
# verdict left its daemons one speedtest away from OOM, and even launching two tiny test
# daemons failed at startup. So: overcommit=2 => NOT roomy (the full GC tune applies),
# and compute_go_memlimit additionally clamps GOMEMLIMIT to a fraction of the LIVE
# commit headroom (floor 64MiB), so the ceiling fits the budget that actually exists
# instead of quoting 448MiB the box cannot commit.
AWG_GOMEMLIMIT_COMMIT_PCT=50  # % of (CommitLimit - Committed_AS) usable per daemon
# Lowest GOMEMLIMIT the strict-overcommit clamp may emit (MiB). Named rather than inlined
# because mem_squeeze_state compares against it: a ceiling that LANDED on this floor means
# the clamp ran out of budget, not that it picked a ceiling that fits.
# NB unlike compute_pool_cap's 512-buffer floor this is NOT a liveness minimum: it came in
# with 1.3.15 as a bare "floor 64MiB" when the pool was 1024 x 64KB = 64MB, and was not
# re-derived when 1.5.22 halved the pool floor to 32MB. Headroom <= 64MiB puts the soft
# limit at or above the whole budget. Re-deriving it needs a measurement on a Cortex-A7
# box (GC CPU vs survival), so it stays until then.
AWG_GOMEMLIMIT_COMMIT_FLOOR=64

# TRUE when the box has enough RAM to run the daemon with stock Go GC
# (MemTotal readable AND >= AWG_GOTUNE_BELOW_MIB, and NOT under strict overcommit
# accounting). Unreadable meminfo => NOT roomy — fail toward the OOM protections,
# the pre-1.3.13 status quo.
box_is_roomy(){
    [ "$(awk '{print $1; exit}' /proc/sys/vm/overcommit_memory 2>/dev/null)" = "2" ] && return 1
    _bmt_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    case "$_bmt_kb" in ''|*[!0-9]*) return 1 ;; esac
    [ "$_bmt_kb" -ge $(( AWG_GOTUNE_BELOW_MIB * 1024 )) ]
}

# Compute a GOMEMLIMIT for amneziawg-go as an integer MiB clamped to [96, 448].
# Empty output (high-RAM box per AWG_GOTUNE_BELOW_MIB, or meminfo parse failure) =>
# launch_daemon leaves the whole Go env untouched (stock runtime, full throughput).
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
    # High-RAM boxes are exempt from the whole tune — empty output, stock Go runtime.
    # (Unreadable meminfo => box_is_roomy is false => the arithmetic below runs and, with
    # MemTotal unparsable, computes from MemAvailable alone — the pre-1.3.13 behaviour.)
    box_is_roomy && return 0
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
    # Strict-overcommit clamp (see AWG_GOMEMLIMIT_COMMIT_PCT): under vm.overcommit=2 the
    # RAM-based ceiling can vastly exceed what the box can actually commit — refit it to
    # the live commit headroom, floor 64MiB (unreadable counters => RAM ceiling stands).
    # Readable counters with ZERO or negative headroom (Committed_AS >= CommitLimit, the
    # most starved state there is) land on the floor too — 1.3.15-1.5.22 skipped the clamp
    # there and handed the daemon its LOOSEST ceiling (178-448MiB) at the worst moment.
    if [ "$(awk '{print $1; exit}' /proc/sys/vm/overcommit_memory 2>/dev/null)" = "2" ]; then
        _cl_kb=$(awk '/^CommitLimit:/{print $2; exit}' /proc/meminfo 2>/dev/null)
        _ca_kb=$(awk '/^Committed_AS:/{print $2; exit}' /proc/meminfo 2>/dev/null)
        case "$_cl_kb" in ''|*[!0-9]*) _cl_kb='' ;; esac
        case "$_ca_kb" in ''|*[!0-9]*) _cl_kb='' ;; esac
        if [ -n "$_cl_kb" ]; then
            _hr_mib=0
            [ "$_cl_kb" -gt "$_ca_kb" ] && _hr_mib=$(( (_cl_kb - _ca_kb) * AWG_GOMEMLIMIT_COMMIT_PCT / 100 / 1024 ))
            [ "$_hr_mib" -lt "$AWG_GOMEMLIMIT_COMMIT_FLOOR" ] && _hr_mib=$AWG_GOMEMLIMIT_COMMIT_FLOOR
            [ "$_hr_mib" -lt "$_lim_mib" ] && _lim_mib=$_hr_mib
        fi
    fi
    printf '%dMiB' "$_lim_mib"
}

# Scale the daemon's buffer-pool cap DOWN to the memory envelope on constrained boxes
# (1.5.22 — see the strict-overcommit paragraph above AWG_GOTUNE_BELOW_MIB). $1 =
# compute_go_memlimit's output ("NNNMiB" or empty). Empty/unparsable in => empty out:
# launch_daemon leaves the env unset and the compiled default (1024) applies — roomy
# boxes never reach a reduced cap. Otherwise: 4 buffers per limit-MiB (buffers are 64KB,
# so the message pool may pin ~25% of GOMEMLIMIT), clamped to [512, 1024].
#
# WHY 512 IS THE FLOOR (liveness, not tuning): the message-buffer pool feeds THREE
# rolling consumers that PRE-HOLD one full batch (conn.IdealBatchSize=128 buffers) each
# even while idle — the v4 receive routine, the v6 receive routine and the TUN reader
# (verified in the fork: receive.go fills bufsArrs before blocking in recv, send.go
# pre-fills its elems) — plus up to one staged batch per peer awaiting a handshake.
# 384 pre-held + one batch in flight = 512 is the minimum that keeps every path able to
# make progress; WaitPool.Get BLOCKS at the cap (backpressure, not drops), so below that
# the pipeline serializes to a crawl while idle paths sit on their batches.
#
# WHY 1024 IS THE CEILING: that is the compiled default — this helper only ever TIGHTENS
# flow control (raising/un-capping is forbidden, see the 1.3.14 field crash above), and
# 0 (= unbounded to the daemon) must never be emitted. Honored by -poolcfg daemons
# (>= 1.3.13, incl. the 3.1 fork); older -pool1024 builds ignore the env — harmless.
compute_pool_cap(){
    case "$1" in *MiB) : ;; *) return 0 ;; esac
    _pcl_mib=${1%MiB}
    case "$_pcl_mib" in ''|*[!0-9]*) return 0 ;; esac
    _pcl=$(( _pcl_mib * 4 ))
    [ "$_pcl" -lt 512 ]  && _pcl=512
    [ "$_pcl" -gt 1024 ] && _pcl=1024
    printf '%d' "$_pcl"
}

# SwapTotal in MiB, 0 when the box is swapless — which is the fleet default: routers ship
# without swap, and the only practical place for a swap file is the USB stick /opt already
# lives on (amtm creates one). Unreadable meminfo => 0.
swap_total_mib(){
    local _sw
    _sw=$(awk '/^SwapTotal:/{printf "%d", $2/1024; exit}' /proc/meminfo 2>/dev/null)
    case "$_sw" in ''|*[!0-9]*) _sw=0 ;; esac
    printf '%d' "$_sw"
}

# "The memory envelope ran out of room" probe (1.5.23). Prints
# "<state>|<GOMEMLIMIT MiB>|<pool cap>|<SwapTotal MiB>", or NOTHING when the box is fine.
#
# WHY THIS EXISTS: compute_go_memlimit's strict-overcommit clamp has a FLOOR
# (AWG_GOMEMLIMIT_COMMIT_FLOOR = 64MiB) and compute_pool_cap has one too (512 buffers — a
# LIVENESS minimum, see its header: three rolling consumers pre-hold a 128-buffer batch
# each). On a box where the clamp LANDS on its floor the two floors collide: up to 512 x
# 64KB = 32MB of message buffers inside a 64MiB soft ceiling. A sustained inbound burst
# then walks straight through the SOFT limit (GOMEMLIMIT never refuses an allocation) until
# a heap-arena mmap exceeds the commit budget -> `runtime: out of memory` rc=2, the
# watchdog restarts the daemon, and the user sees "the VPN drops every few minutes".
# (A Go "unexpected fault address"/panic is NOT this — see record_daemon_oom.)
#
# 1.5.22 scales the pool cap down for exactly this shape and can go no lower; the heap
# floor is not a liveness minimum (see AWG_GOMEMLIMIT_COMMIT_FLOOR) but is not re-derived
# yet either. The levers that work today are box-side — swap raises CommitLimit 1:1,
# stopping user-space memory consumers lowers Committed_AS — so this surfaces as a status
# flag/banner instead of yet another silent retune.
#
# Field case (RT-AX58U 512MB, 388.12_2, diag 2026-09-20): GOMEMLIMIT=64MiB + pool cap 512,
# no swap, 392 of 512MB already in use with the tunnel DOWN (AiProtection/tdts resident) —
# ~30 OOM aborts and 9 health-check rollbacks in a single day. The user saw only "the VPN
# drops now and then", and only while YouTube played through a geo policy (the one thing
# routed into the tunnel, and the one workload that sustains a line-rate inbound burst).
# After a 1GB swap file: GOMEMLIMIT ~180-190MiB, pool ~730-760 (exact figures depend on
# MemTotal).
#
# WHICH CEILING: $1, when given, is the GOMEMLIMIT to judge (record_daemon_oom passes what
# the dead daemon was launched with; do_start passes what it is about to launch with —
# explicitly empty = roomy/untuned = fine). With no argument and this instance's tunnel UP
# it judges what the running daemon was ACTUALLY launched with ($DAEMON_TUNE) — a recompute
# would count the daemon's own commit (>= 24MB of pre-held buffers, only ratcheting up)
# against it and claim "pinned to 64MiB" for a daemon launched at 70-96MiB — and only while
# the live budget is STILL at the floor (swap added since => the commit wall has moved
# away; the next restart picks up the higher ceiling, no banner needed). Tunnel down: a
# prediction for the next start.
#
# State tokens: "floor" = at the floor with NO swap (adding swap is the actionable fix);
# "tight" = at the floor WITH swap present (enlarge it, or cut other memory consumers).
mem_squeeze_state(){
    local _lim _mib _sw _pool="" _live
    # Only strict accounting has a commit floor to be pinned against (overcommit=2 is also
    # never box_is_roomy, so that check is implied).
    [ "$(awk '{print $1; exit}' /proc/sys/vm/overcommit_memory 2>/dev/null)" = "2" ] || return 0
    if [ $# -gt 0 ]; then
        _lim=$1
    elif iface_exists "$IFACE" && [ -r "$DAEMON_TUNE" ]; then
        IFS='|' read -r _lim _pool < "$DAEMON_TUNE"
        _live=$(compute_go_memlimit)
        _live=${_live%MiB}
        case "$_live" in ''|*[!0-9]*) : ;; *) [ "$_live" -gt "$AWG_GOMEMLIMIT_COMMIT_FLOOR" ] && return 0 ;; esac
    else
        _lim=$(compute_go_memlimit)
    fi
    case "$_lim" in *MiB) : ;; *) return 0 ;; esac
    _mib=${_lim%MiB}
    case "$_mib" in ''|*[!0-9]*) return 0 ;; esac
    [ "$_mib" -le "$AWG_GOMEMLIMIT_COMMIT_FLOOR" ] || return 0
    case "$_pool" in ''|*[!0-9]*) _pool=$(compute_pool_cap "$_lim") ;; esac
    _sw=$(swap_total_mib)
    if [ "$_sw" -gt 0 ]; then
        printf 'tight|%s|%s|%s' "$_mib" "${_pool:-1024}" "$_sw"
    else
        printf 'floor|%s|%s|0' "$_mib" "${_pool:-1024}"
    fi
}

# One-line description of the Go-runtime tuning decision for logs/diag. Every site that
# names the tune goes through this helper, so the wording cannot drift from what
# launch_daemon actually applies (client and server share both).
go_tune_desc(){
    if box_is_roomy; then
        printf 'stock Go GC (MemTotal >= %sMiB: no GOMEMLIMIT/GOGC caps) + buffer pool capped at 1024 (compiled default — flow control that keeps a slow egress path from ballooning the heap)' "$AWG_GOTUNE_BELOW_MIB"
    else
        _gtd=$(compute_go_memlimit)
        _gtp=$(compute_pool_cap "$_gtd")
        printf 'GOMEMLIMIT=%s GOGC=%s + buffer pool capped at %s (constrained box: MemTotal < %sMiB or strict vm.overcommit — OOM protection under load)' "${_gtd:-unset}" "$AWG_GOGC" "${_gtp:-1024}" "$AWG_GOTUNE_BELOW_MIB"
    fi
}

# Launch amneziawg-go detached, stdout+stderr into $DAEMON_LOG and — critically — its
# EXIT STATUS appended as a final "[daemon exited rc=N]" line. A daemon that dies WITHOUT
# printing anything (SIGILL/SIGSEGV, or a Go runtime that just aborts on an unsupported ancient
# kernel — RT-AC68U's 2.6.36 is below Go 1.24's Linux 3.2 floor) used to be indistinguishable
# from a hang; the rc line names it (132=SIGILL, 139=SIGSEGV, plain N = clean error exit).
# $1 = optional LOG_LEVEL (e.g. "verbose").
launch_daemon(){
    # Exit status goes to a PER-LAUNCH file ($DAEMON_RC, truncated here): parsing the
    # rc out of awg_daemon.log was ambiguous during restarts — the PREVIOUS daemon's wrapper
    # could append its "[daemon exited rc=0]" a beat after this launch truncated the log, and
    # a later create-failure would then misreport a stale rc for a daemon that actually hung.
    # The log line stays for humans; code reads the rc file.
    rm -f $DAEMON_RC 2>/dev/null
    # Soft heap ceiling for the Go runtime — LOW-RAM boxes only, empty (no env, stock
    # runtime) on roomy ones (see compute_go_memlimit / AWG_GOTUNE_BELOW_MIB): caps heap
    # growth so a heavy inbound burst can't drive the daemon into `fatal error: runtime:
    # out of memory` and crash-loop the tunnel. Exported INSIDE the subshell (not as a
    # literal prefix) so it never leaks to the parent and so an empty value simply leaves
    # the env untouched.
    _glim=$(compute_go_memlimit)
    # Buffer-pool cap: NEVER raised or un-capped from here (the 1.3.14 lesson — 0 or
    # >1024 field-crashed a 2GB box in minutes; the cap is flow control, not a RAM
    # knob), but on constrained boxes it is LOWERED to fit the memory envelope
    # (1.5.22, compute_pool_cap — strict-overcommit firmwares leave GOMEMLIMIT at a
    # floor the compiled 1024x64KB pool alone can fill). Empty on roomy boxes => env
    # untouched, compiled 1024.
    _gpool=$(compute_pool_cap "$_glim")
    # Record what THIS launch applies (empty|empty on roomy boxes): status/diag judge the
    # running daemon by it instead of recomputing against a budget the daemon now eats into.
    printf '%s|%s\n' "$_glim" "$_gpool" > $DAEMON_TUNE 2>/dev/null
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
          [ -n "$_gpool" ] && export WG_PREALLOCATED_BUFFERS_PER_POOL="$_gpool"
          WG_PROCESS_FOREGROUND=1 LOG_LEVEL="$1" "$AWG_GO" "$IFACE" > $DAEMON_LOG 2>&1
          _rc=$?
          echo "rc=$_rc at $(date '+%H:%M:%S')" > $DAEMON_RC
          echo "[daemon exited rc=$_rc at $(date '+%H:%M:%S')]" >> $DAEMON_LOG
          record_daemon_oom "$_rc" "$_glim" "$_gpool" ) &
    else
        ( [ -n "$_glim" ] && export GOMEMLIMIT="$_glim" GOGC="$AWG_GOGC"
          [ -n "$_gpool" ] && export WG_PREALLOCATED_BUFFERS_PER_POOL="$_gpool"
          WG_PROCESS_FOREGROUND=1 "$AWG_GO" "$IFACE" > $DAEMON_LOG 2>&1
          _rc=$?
          echo "rc=$_rc at $(date '+%H:%M:%S')" > $DAEMON_RC
          echo "[daemon exited rc=$_rc at $(date '+%H:%M:%S')]" >> $DAEMON_LOG
          record_daemon_oom "$_rc" "$_glim" "$_gpool" ) &
    fi
}

# Called from the launch wrapper after the daemon exits: if it aborted with a Go-runtime
# out-of-memory (heavy-load heap blowout), crashed (panic / fault, 1.5.23) or was taken by
# the kernel oom-killer, drop a persistent breadcrumb so the cause is still visible in the
# diag after the watchdog restarts it and after a reboot (RAM logs don't survive). Gated on
# strings only the Go runtime's own fatal paths print — an intentional kill (SIGTERM/SIGKILL
# on stop/restart) never matches, so this can't false-fire on a normal teardown.
# $1 = rc, $2 = GOMEMLIMIT and $3 = pool cap this daemon was launched with.
record_daemon_oom(){
    local _kind _sq _adv="" _why _sig _frame _dn="${AWG_GO##*/}"
    # Classify FIRST, so a clean exit (the common case) costs two greps and nothing more.
    if grep -qiE 'out of memory|^fatal error: .*memory' $DAEMON_LOG 2>/dev/null; then
        # The Go runtime's OWN fatal-OOM (heap-commit refused). rc is typically 2. The
        # anchored half catches its other memory throws ("runtime: cannot allocate memory",
        # "failed to reserve page summary memory") while an ordinary ENOMEM error LINE
        # ("…sendmsg: cannot allocate memory") can't turn a later clean stop into an OOM.
        _kind=oom
    elif grep -qE '^(panic: |fatal error: |unexpected fault address)' $DAEMON_LOG 2>/dev/null; then
        # Any other Go crash: panic (nil deref, index out of range, …) or runtime fault.
        # NOT memory pressure: strict overcommit refuses at mmap time (-> the OOM branch
        # above) and physical exhaustion at first touch goes to the kernel OOM-killer
        # (SIGKILL, rc=137, the branch below). "unexpected fault address" is a wild or
        # corrupted pointer — a daemon/runtime bug, bad RAM, or (SIGBUS) an I/O error
        # reading pages back from the USB. Recorded as nothing until 1.5.23.
        _kind=crash
    elif [ "${1:-}" = 137 ] && dmesg 2>/dev/null | grep -iE 'killed process|out of memory' | grep -qi "$_dn"; then
        # rc=137 = 128+SIGKILL. That's ALSO how do_stop/do_start's `kill -9` fallback exits
        # the daemon, so rc alone must NOT be trusted — only record when the kernel log shows
        # the OOM-KILLER named the daemon (a box-wide-pressure kill, a DIFFERENT OOM than the
        # Go-runtime one above and invisible in the daemon's own log). Without that corroboration
        # a plain forced teardown would false-flag an incident. This catches the failure mode
        # GOMEMLIMIT can shift residual crashes toward (per-daemon cap holds, box still starves).
        _kind=oomkill
    else
        return 0
    fi
    # Envelope verdict (1.5.23) for the ceiling THIS daemon ran with ($2, from the launch),
    # not a re-probe of the box after its commit was released.
    _sq=$(mem_squeeze_state "${2:-}")
    case "${_sq%%|*}" in
        floor) _adv=" — it ran at the strict-overcommit floor with NO swap: a swap file on the USB (amtm) raises CommitLimit 1:1 and lifts the ceiling on the next start" ;;
        tight) _adv=" — it ran at the strict-overcommit floor even with ${_sq##*|}MiB swap: enlarge the swap file or stop other user-space memory consumers" ;;
    esac
    case "$_kind" in
        oom)
            awg_incident "$_dn OOM-crashed (rc=${1:-?}) — Go heap hit its ceiling under load (GOMEMLIMIT=${2:-unset}, pool cap ${3:-1024}); box is low on memory for this throughput${_adv}" ;;
        oomkill)
            awg_incident "$_dn killed by the KERNEL oom-killer (rc=137) under box-wide memory pressure — not a Go-runtime OOM; free RAM / reduce co-resident load (GOMEMLIMIT=${2:-unset}, pool cap ${3:-1024})${_adv}" ;;
        crash)
            # Keep the evidence: the next launch truncates DAEMON_LOG, and the watchdog
            # relaunches within minutes. The trace goes to $DAEMON_CRASH (RAM, until reboot;
            # diag prints it) and its two decisive lines into the incident itself (/jffs):
            # the [signal …] line (SIGSEGV vs SIGBUS, code, addr, pc) and the first
            # non-runtime frame of the crashing goroutine.
            { echo "# $_dn crash, rc=${1:-?}, $(date '+%Y-%m-%d %H:%M:%S'), GOMEMLIMIT=${2:-unset} pool=${3:-1024}"
              awk '/^(panic: |fatal error: |unexpected fault address)/{f=1} f' $DAEMON_LOG 2>/dev/null | head -n 150
            } > $DAEMON_CRASH 2>/dev/null
            _why=$(awk '/^(panic: |fatal error: |unexpected fault address)/{print; exit}' $DAEMON_LOG 2>/dev/null | cut -c1-120)
            _sig=$(awk '/^\[signal /{print; exit}' $DAEMON_LOG 2>/dev/null | cut -c1-120)
            _frame=$(awk '
                /^goroutine [0-9]+ /   { g = 1; fn = ""; next }
                g && /^$/              { exit }
                g && /^[^ \t]/         { fn = $0; next }
                g && fn != ""          { x = fn; sub(/\([^()]*\)$/, "", x); sub(/^.*\//, "", x)
                                         if (x !~ /^runtime\./ && x != "panic") {
                                             f = $1; sub(/^.*\//, "", f); print x " " f; exit }
                                         fn = "" }' $DAEMON_LOG 2>/dev/null | cut -c1-120)
            [ -n "$_sq" ] && _adv=" (box is also at its memory floor — that explains OOM aborts, not a crash like this)" || _adv=""
            awg_incident "$_dn CRASHED (rc=${1:-?}): ${_why:-Go crash}${_sig:+ $_sig}${_frame:+ at $_frame} — NOT an OOM: a daemon/runtime bug, bad RAM or USB I/O errors; trace in $DAEMON_CRASH until reboot — please report it with the diag (GOMEMLIMIT=${2:-unset}, pool cap ${3:-1024})${_adv}" ;;
    esac
}

# Daemon log minus the harmless wireguard-go "kernel has first class support" banner box, so
# error paths quote the ACTUAL failure lines instead of 10 lines of box-drawing. $1 = max lines.
daemon_log_gist(){
    grep -av '─\|│\|┌\|└\|first class support\|amneziawg-linux-kernel-module' $DAEMON_LOG 2>/dev/null \
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
    # Liveness marker FIRST — before any toggle/running check (see BOOT_MARKER): even a
    # declined autostart proves the Entware init path ran, so the boot fallback stands down.
    touch "$BOOT_MARKER" 2>/dev/null
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

# services-start fallback for the Entware init race (1.5.8; field: RT-BE92U @ Merlin
# 3006.102.8). On 3006.102.x Entware services get started by TWO parties — the firmware
# itself (its shutdown counterpart is visible as `sh /opt/S99amneziawg.1 stop` in syslog)
# and the classic amtm/post-mount hook. On a bad boot they collide: one bind-mounts /opt,
# the other sees it populated and logs "Not starting Entware services on …, Entware is
# already started" — and NEITHER runs the S* start scripts. S99amneziawg start is then never
# invoked: no tunnel/server autostart, no status/watchdog crons (do_start installs them),
# the server tab sits on «Загрузка…». services-start is firmware-owned and runs on EVERY
# boot regardless of Entware, so do_install_page arms this guard there:
#   1. wait for /opt (the S99 script) to appear — a slow USB + fsck can take minutes;
#   2. grace-wait for BOOT_MARKER (do_boot_start touches it before any toggle check) so a
#      healthy rc.unslung/native start wins and the guard stands down;
#   3. only if nobody invoked the init within the grace — run `S99amneziawg start` ourselves
#      (both roles: client boot_start honors awg_autostart, server's honors awgs_autostart).
# Idempotent by construction: do_start re-checks is_running UNDER the lock (1.2.31), so a
# late-racing rc.unslung start just no-ops with "Already running". BOOT_GUARD_STATE records
# the verdict for diag. NOTE for hook authors: the hook line backgrounds this (`… boot_guard &`)
# — the waits below would otherwise stall the firmware's services-start for minutes.
do_boot_guard(){
    local waited=0 grace=0
    echo "waiting for /opt" > "$BOOT_GUARD_STATE"
    while [ ! -x /opt/etc/init.d/S99amneziawg ] && [ "$waited" -lt 600 ]; do
        sleep 5; waited=$((waited+5))
    done
    if [ ! -x /opt/etc/init.d/S99amneziawg ]; then
        # No Entware / package gone this boot — nothing to start, and deliberately no syslog
        # noise (a pulled USB must not log an error line on every boot).
        echo "stand down: no /opt/etc/init.d/S99amneziawg after ${waited}s (Entware not mounted or package removed)" > "$BOOT_GUARD_STATE"
        return 0
    fi
    while [ ! -f "$BOOT_MARKER" ] && [ "$grace" -lt 90 ]; do
        sleep 5; grace=$((grace+5))
    done
    if [ -f "$BOOT_MARKER" ]; then
        echo "stand down: Entware init ran S99amneziawg itself (waited ${waited}s for /opt, ${grace}s for the init)" > "$BOOT_GUARD_STATE"
        return 0
    fi
    echo "FIRED at uptime $(cut -d. -f1 /proc/uptime 2>/dev/null)s: Entware init never ran S99amneziawg (native-vs-post-mount double-starter race?)" > "$BOOT_GUARD_STATE"
    log_msg "Boot fallback: Entware init did not run S99amneziawg within ${grace}s of /opt appearing (firmware-native vs post-mount Entware race — look for 'Not starting Entware services' in syslog) — starting it from the services-start guard"
    /opt/etc/init.d/S99amneziawg start
}

# --- Start/stop generations + STARTING_FLAG ownership ---
# Every do_stop and every COMMITTED do_start writes a fresh generation id to /tmp/.<iface>_gen
# under the operation lock. Whoever acts on "the tunnel I just stopped/started" LATER, outside
# the lock, carries the id it saw and hands it back as the expected generation — do_restart's
# start half, the watchdog's start half, the health check's rollback / failover / DNS fail-open
# — and do_stop/do_start re-check it UNDER the lock, standing down (rc 2, touching nothing)
# when a newer stop/start happened in between. Closes: a 60-s health check of an OLD start
# rolling back or failing over the tunnel a newer switch had just brought up; a restart whose
# stop half raced a user Stop resurrecting the tunnel. Ids come from the kernel's uuid source
# (a fork-free `read`; every kernel in the fleet incl. 2.6.36 has it). Instance-scoped by IFACE:
# the server role (awgs0) never reads or writes the client's file.
awg_new_id(){
    AWG_NEW_ID=""
    { read -r AWG_NEW_ID < /proc/sys/kernel/random/uuid; } 2>/dev/null
    if [ -z "$AWG_NEW_ID" ]; then
        local _c=""
        { read -r _c < /tmp/.awg_id_ctr; } 2>/dev/null
        case "$_c" in ''|*[!0-9]*) _c=0 ;; esac
        _c=$((_c + 1))
        echo "$_c" > /tmp/.awg_id_ctr 2>/dev/null
        AWG_NEW_ID="$(date +%s)-$_c"
    fi
}
# Write a fresh generation (the caller holds the lock) and leave it in AWG_GEN_NEW — EMPTY when
# the write did not stick (full /tmp). Callers then hand on no expected generation, i.e. the old
# unconditional behaviour, instead of a token nothing will ever match (which would, e.g., make
# the health check of a dead tunnel stand down instead of rolling it back).
awg_gen_bump(){
    local _gf="/tmp/.${IFACE}_gen" _rb=""
    awg_new_id
    AWG_GEN_NEW="$AWG_NEW_ID"
    echo "$AWG_GEN_NEW" > "$_gf" 2>/dev/null
    { read -r _rb < "$_gf"; } 2>/dev/null
    [ "$_rb" = "$AWG_GEN_NEW" ] || AWG_GEN_NEW=""
}
# True when $1 is empty (no expectation) or still the current generation. Fork-free: the
# health check runs it every 2 s.
gen_current_is(){
    local _g=""
    [ -n "$1" ] || return 0
    { read -r _g < "/tmp/.${IFACE}_gen"; } 2>/dev/null
    [ "$_g" = "$1" ]
}
# STARTING_FLAG holds its OWNER's id (AWG_FLAG_ID: one per do_restart / standalone do_start; the
# do_start a do_restart runs reuses the restart's). A starter removes the flag only while it is
# still ITS OWN: the old unconditional rm let a second actor that bailed out (lock timeout,
# superseded restart) wipe the flag of the start actually in progress, and the page flashed a
# fully-stopped «Запустить» in the middle of it. do_stop still removes it unconditionally — under
# the lock, a stop ends every start. Readers only test existence.
flag_clear_mine(){
    local _f=""
    { read -r _f < "$STARTING_FLAG"; } 2>/dev/null
    [ -n "$_f" ] && [ "$_f" = "$AWG_FLAG_ID" ] && rm -f "$STARTING_FLAG"
    return 0
}

do_start(){
    # $1 = expected generation (see awg_gen_bump): do_restart and the watchdog pass the one their
    #      do_stop wrote, so a stop/start in between wins (rc 2, nothing started). Empty = the
    #      unconditional start every other caller wants.
    # $2 = STARTING_FLAG owner id to reuse (do_restart passes its own); empty = take a fresh one.
    # rc: 0 started (or nothing to do), 1 failed, 2 superseded.
    local _exp_gen="$1" _run_sig="" _pu=""
    if [ -n "$2" ]; then AWG_FLAG_ID="$2"; else awg_new_id; AWG_FLAG_ID="$AWG_NEW_ID"; fi
    # Skip if update in progress (opkg triggers S99amneziawg start)
    [ -f /tmp/.awg_no_autostart ] && { log_msg "Start blocked: update in progress"; return 0; }

    if is_running; then
        log_msg "Already running"
        update_status
        return 0
    fi

    # No unsupported-kernel guard here anymore (see kernel_pre_sendmmsg). Old kernels (Linux 2.6.x
    # — RT-AC68U class) are SUPPORTED as of 1.2.61: the daemon carries the sendmmsg→sendmsg fallback
    # (1.2.58) AND drain_ip_rules no longer wipes the system routing table on Broadcom 2.6.36 +
    # Entware iproute2 (the blind `ip rule del` bug — THE reason the full start "bricked" the
    # AC68U). Verified end-to-end on a real RT-AC68U: handshake completes, RX/TX both flow, inbound
    # stays up, no reboot. CTF (if present) must still be off first — the ctf guard below handles
    # that. If a NEW 2.6.x-specific issue turns up, autostart-off still makes a bad start
    # self-recover (reboot → tunnel stopped).

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

    # Mark start-in-progress so the UI shows "Connecting" even across a page refresh; the trap
    # clears it (while it is still ours — see flag_clear_mine) and writes the final status on any
    # exit path. A STANDALONE start does not take over a flag another starter already holds: it
    # would then be the one to remove it — possibly on its own lock timeout, in the middle of the
    # other start. It claims the flag at its commit point below instead, under the lock, if it
    # really starts. (The flag of a do_restart is already this start's own.)
    if [ -n "$2" ] || [ ! -f "$STARTING_FLAG" ]; then echo "$AWG_FLAG_ID" > "$STARTING_FLAG"; fi
    trap 'flag_clear_mine; update_status' EXIT INT TERM
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

    acquire_lock || { log_msg "Cannot acquire lock, aborting start"; flag_clear_mine; update_status; return 1; }

    # The stop/start this restart was paired with is no longer the latest (a user Stop, another
    # restart or the watchdog got the lock in between): starting now would undo THEIR outcome.
    if ! gen_current_is "$_exp_gen"; then
        log_msg "Restart superseded by a newer stop/start — not starting"
        release_lock; flag_clear_mine; update_status
        return 2
    fi

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

    # COMMIT POINT: this start owns the "Connecting" flag and a fresh generation — the one its
    # health check carries, so any later stop/start supersedes that check.
    echo "$AWG_FLAG_ID" > "$STARTING_FLAG"
    awg_gen_bump; AWG_GEN_STARTED=$AWG_GEN_NEW

    generate_config || { update_status; release_lock; return 1; }
    [ ! -f "$CONF" ] && { log_msg "ERROR: No config"; update_status; release_lock; return 1; }
    # Fingerprint of the conf THIS launch runs, taken here — under the lock, before setconf — so
    # it is exactly the file the daemon gets (written to RUNNING_CONF_SIG at the success point).
    _run_sig=$(md5sum "$CONF" 2>/dev/null | awk '{print $1}')
    # A saved pointer at an EMPTY slot resolved to the lowest configured one (profile_user) —
    # say so once per start; the store is not rewritten.
    _pu=$(get_setting awg_profile_active)
    case "$_pu" in
        [1-9]) if [ "$_pu" -le "$AWG_PF_MAX" ] && ! profile_configured "$_pu"; then
                   log_msg "WARNING: saved profile (slot $_pu) is empty — started $(profile_desc "$AWG_CFG_SLOT")"
               fi ;;
    esac
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
    log_msg "Go runtime: $(go_tune_desc)"
    # The envelope can be at its floor BEFORE a single packet flows (1.5.23) — say so at
    # start, not only in the incident log after the first crash-loop. Advice, never a
    # refusal: the tunnel still starts. Judged on the ceiling launch_daemon is about to
    # apply (explicit arg), never on a previous launch's $DAEMON_TUNE.
    local _msq _msf
    _msq=$(mem_squeeze_state "$(compute_go_memlimit)")
    _msf=${_msq#*|}   # "<GOMEMLIMIT MiB>|<pool cap>|<swap MiB>"
    case "${_msq%%|*}" in
        floor) log_msg "  WARNING: memory envelope at its floor (GOMEMLIMIT=${_msf%%|*}MiB, pool cap $(echo "$_msf" | cut -d'|' -f2), strict vm.overcommit, NO swap) — sustained load (video through the tunnel) can OOM-abort the daemon and the watchdog will restart it. Fix: a swap file on the USB (amtm) — it raises CommitLimit 1:1, which is what sets this ceiling." ;;
        tight) log_msg "  WARNING: memory envelope at its floor (GOMEMLIMIT=${_msf%%|*}MiB, pool cap $(echo "$_msf" | cut -d'|' -f2), strict vm.overcommit) even with ${_msf##*|}MiB swap — enlarge the swap file or stop other user-space memory consumers if the tunnel drops under load." ;;
    esac
    launch_daemon
    if ! wait_for_iface "$IFACE" 10; then
        # Name the failure mode from the captured exit status: a SILENT death (banner only, no
        # error line — the RT-AC68U/kernel-2.6.36 signature) vs a clean error exit vs a hang.
        local drc dgist
        drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' $DAEMON_RC 2>/dev/null)
        log_msg "ERROR: amneziawg-go failed to create interface"
        case "$drc" in
            "")  log_msg "  daemon is still running but $IFACE never appeared after 10s (hung in TUN create?)" ;;
            132) log_msg "  daemon exited rc=132 (SIGILL — this CPU can't run this build)" ;;
            139) log_msg "  daemon exited rc=139 (SIGSEGV — daemon crashed; on kernels older than 3.2 (e.g. RT-AC68U 2.6.36) the Go runtime is unsupported and dies like this)" ;;
            *)   if grep -qiF 'out of memory' $DAEMON_LOG 2>/dev/null; then
                     log_msg "  daemon exited rc=$drc (Go runtime OUT OF MEMORY — box too low on RAM; Go tune: $(go_tune_desc); free some memory or reduce load)"
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
            drc=$(sed -n 's/^rc=\([0-9]*\).*/\1/p' $DAEMON_RC 2>/dev/null)
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
            [ -s $DAEMON_LOG ] && log_msg "  daemon log: $(tr '\n' '|' < $DAEMON_LOG)"
            # A non-SIGILL setconf failure is almost always the daemon REJECTING an obfuscation
            # parameter (EINVAL → "Unable to modify interface: Invalid argument"). Two probes name
            # it, neither leaks secrets:
            #  (1) dump the non-secret advanced params actually sent — long I-hex is collapsed to
            #      "<head…tail>" so a malformed/unterminated tag (e.g. an I-param missing its
            #      closing '>') is visible in the journal without dumping a kilobyte of hex;
            #      The AmneziaWG 3.0 params are listed too — a rejected one is otherwise invisible
            #      here, which is the worst case to debug blind. HeaderProtectionKey is EXCLUDED ON
            #      PURPOSE: it is a secret and this line goes to the journal. Do not "complete" the
            #      3.0 set by adding it.
            local adv
            adv=$(awk '
                /^(Jc|Jmin|Jmax|S[1-4]|H[1-4]) /{ print; next }
                /^(ContentPaddingAddition|RekeyAfterTime|RekeyTimeout|RejectAfterTime|KeepaliveTimeout|MaxHandshakeAttempts|PersistentKeepalive|RandomTrailers|DisableCookies) /{ print; next }
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
                vrej=$(grep -iE 'fail|invalid|error|parse|unable|reject|must be|overlap|not.*valid' $DAEMON_LOG 2>/dev/null \
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
    # MTU: configurable via awg_mtu / the active profile's mtu field (default 1280) — of the
    # profile generate_config MATERIALIZED, not a fresh resolution (see AWG_CFG_SLOT).
    local mtu=$(pf_slot_get "$AWG_CFG_SLOT" mtu)
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
    # MASQUERADE everything leaving the tunnel, NOT just the LAN subnet. The provider's
    # server accepts only our tunnel address (AllowedIPs / cryptokey routing), so ANY source
    # egressing awg0 unNATed is silently dropped on the far end — and the default
    # vpn_geo/vpn_all policy marks EVERY unlisted source (the PREROUTING chain is
    # interface-agnostic), including firmware VPN-server clients (stock WireGuard wgs1
    # 10.6.0.x, OpenVPN/IPSec subnets). The old lan_net-scoped rule left exactly those dead
    # for geo destinations while the router web UI (dst-type LOCAL -> RETURN) kept working
    # (field case RT-BE88U @1.3.8). Router-local egress already sources the tunnel IP, so
    # the unconditional rule is a no-op for it.
    iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE

    # Arm the LAN deadman BEFORE the risky part: setup_firewall does the ipset load, DNS
    # interception and dnsmasq reload — the steps that can lock the router out. If they
    # kill dnsmasq, the deadman rolls everything back within ~90s even if we hang here.
    arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
    setup_firewall

    # Fingerprint of the config the DAEMON is actually running (this launch's $CONF, hashed
    # right after generate_config above). The status builder compares it against the current
    # generated conf: a later Apply that edits tunnel params (keys/endpoint/obfuscation)
    # regenerates the file but deliberately does NOT restart the daemon — the mismatch drives the
    # page's "изменения применятся после Перезапустить" badge instead of leaving the user to guess
    # (field case: a user swapped the whole provider config, pressed Apply and kept riding the OLD
    # tunnel unaware). RUNNING_PF records WHICH profile that conf is ("<slot> <fp>"): a switch
    # whose restart was dropped/aborted leaves the conf untouched, so only the slot/fp comparison
    # can still tell the user the saved profile is not the one running.
    echo "$_run_sig" > "$RUNNING_CONF_SIG"
    printf '%s %s\n' "$AWG_CFG_SLOT" "$AWG_CFG_FP" > "$RUNNING_PF"

    conn_record_start
    log_msg "Started, verifying tunnel connectivity (probing: $(watchdog_hosts))..."
    update_status
    release_lock

    # Health check (detached): verify the tunnel passes traffic and roll back if not.
    # Backgrounded so the service-event handler returns promptly — otherwise
    # rc_service stays busy for up to ~60s and silently drops other events.
    # It carries THIS start's generation (hc_gen) and the slot it materialized (hc_slot): every
    # act below is re-checked against the generation — cheaply at the top of each round (a newer
    # stop/start makes this check moot: exit silently) and again UNDER THE LOCK inside
    # do_stop/do_restart (rc 2 = superseded in the gap) — so a stale check can never roll back,
    # fail over or DNS-fail-open a tunnel it did not start.
    (
        hc_gen="$AWG_GEN_STARTED"
        hc_slot="$AWG_CFG_SLOT"
        hc_ok=false
        hc_try=0
        hc_dns_fails=0
        hc_reason="not passing traffic (probed: $(watchdog_hosts))"
        while [ $hc_try -lt 30 ]; do
            gen_current_is "$hc_gen" || exit 0
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
                    # Re-check right before acting: the probes above take seconds, and dropping
                    # the :53 interception a NEWER start just installed is not ours to do.
                    gen_current_is "$hc_gen" || exit 0
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
            gen_current_is "$hc_gen" || exit 0
            if [ "$hc_pass" = "handshake" ]; then
                log_msg "Tunnel verified: handshake completing — but the probe hosts ($(watchdog_hosts)) answer neither ICMP nor TCP; point awg_watchdog_hosts at ping-able hosts (e.g. 8.8.8.8) for faster checks"
            else
                log_msg "Tunnel verified: traffic passing"
            fi
            # A verified tunnel ends any failover incident: clear the circle so a LATER
            # failure starts a fresh circle from this (now proven) profile. The override
            # stays — the auto-switched profile keeps running until a reboot/manual switch.
            # "Auto-switch complete" only when what THIS start ran is not the user's own choice
            # (a hop that came back around to the primary is no auto-switch).
            if [ -f "$FAILOVER_STATE" ]; then
                rm -f "$FAILOVER_STATE"
                [ -n "$hc_slot" ] && [ "$hc_slot" != "$(profile_user)" ] \
                    && log_msg "FAILOVER: profile $(profile_desc "$hc_slot") verified working — auto-switch complete (a reboot or manual switch returns to the primary profile)"
            fi
            update_status
        else
            # A newer stop/start owns the tunnel: its own health check decides — not a word here.
            gen_current_is "$hc_gen" || exit 0
            log_msg "ERROR: Tunnel $hc_reason after 60s"
            # Snapshot the live UAPI state BEFORE the rollback kills the daemon — the single most
            # useful signal for "up but no traffic". A present "latest handshake" + non-zero
            # received bytes means the tunnel IS established and the fault is downstream (routing /
            # MTU / a co-resident tool stealing egress); no handshake means the handshake UDP never
            # got a reply (endpoint unreachable, obfuscation mismatch, or egress hijacked). The diag
            # runs after rollback so `awg show` there is empty — capture it here while it's alive
            # (ONCE: the incident below is written only after the stop, from this same text).
            hc_show=$("$AWG_BIN" show "$IFACE" 2>&1)
            log_msg "  awg show: $(printf '%s\n' "$hc_show" | grep -iE 'latest handshake|transfer|endpoint' | tr '\n' '|' | sed 's/|$//')"
            xray_redirect_active && log_msg "  HINT: XRAYUI transparent-proxy (TPROXY 'redirect all') is active — it captures the router's egress incl. our handshake; turn off XRAYUI's redirect-all mode or run one VPN at a time"
            # Profile failover (opt-in): try the next configured profile instead of rolling
            # back — do_restart re-runs the FULL start (config, routes, firewall) on the new
            # slot and spawns a fresh health check that decides whether to hop again. When
            # failover is off / out of candidates, the classic rollback below keeps the exact
            # pre-1.4.0 behavior (stop, watchdog keeps retrying with backoff). The hop (or the
            # give-up) is COMMITTED by do_stop under the lock, gated on hc_gen — see there.
            hc_next=$(failover_next_profile "$hc_slot")
            case "$hc_next" in
                ''|giveup)
                    do_stop "" rollback "$hc_gen" "$hc_next" "$hc_reason" 2>/dev/null
                    case $? in
                        0)  awg_incident "health-check rollback: $hc_reason (awg show: $(printf '%s\n' "$hc_show" | grep -iE 'latest handshake|transfer' | tr '\n' '|' | sed 's/|$//'))"
                            log_msg "VPN stopped automatically. Check server config and endpoint reachability."
                            update_status ;;
                        1)  log_msg "Health-check rollback skipped: another operation holds the lock" ;;
                        # 2 = superseded under the lock: silent, the newer operation owns it.
                    esac ;;
                *)
                    do_restart failover "$hc_gen" "$hc_next $(pf_fp "$hc_next")" "$hc_reason" 2>/dev/null ;;
            esac
        fi
    ) </dev/null >/dev/null 2>&1 &
}

# --- Stop ---

do_stop(){
    local user_stop="$1"   # "user" = deliberate user stop/uninstall; removes the watchdog cron
    local stop_reason="$2" # connection-history token; empty → derived from $1 (user/auto)
    # $3 = expected generation (the health check's rollback / failover pass the one their start
    #      wrote): a newer stop/start in between → rc 2 with NOTHING touched. Empty = unconditional.
    # $4 = failover commit, done here under the lock (so only the check of the CURRENT start can
    #      do it): "<slot> <fp>" = hop to that profile, "giveup" = the circle is complete.
    # $5 = the health-check failure reason, for the failover journal/incident lines.
    # rc: 0 stopped, 1 could not take the lock (nothing done), 2 superseded (nothing done).
    # Leaves the fresh generation in AWG_GEN_STOPPED (do_restart / the watchdog hand it to
    # do_start) and, when do_restart set AWG_FLAG_BRIDGE, re-writes the restart's STARTING_FLAG
    # before its final status write — no fully-stopped status between the two halves.
    local _fs="" _fh="" _fcur="" _fx="" _fnext
    acquire_lock || { log_msg "Cannot acquire lock, aborting stop"; return 1; }
    if ! gen_current_is "$3"; then
        release_lock
        return 2
    fi
    awg_gen_bump; AWG_GEN_STOPPED=$AWG_GEN_NEW
    rm -f "$STARTING_FLAG"
    # A manual switch ends any failover incident: the user's pick beats the override + circle,
    # and a later failure starts a fresh circle from it. Under the lock — the page/CLI switch
    # used to drop them BEFORE the restart, where a health check still running for the old
    # start could write them back.
    [ "$stop_reason" = "switch" ] && rm -f "$PF_OVERRIDE" "$FAILOVER_STATE"
    if [ -n "$4" ]; then
        # The failing start's own profile (its RUNNING_PF record — the generation matched, so the
        # record is that start's) is the default circle start for a first hop.
        [ -f "$RUNNING_PF" ] && { read -r _fcur _fx < "$RUNNING_PF"; } 2>/dev/null
        case "$_fcur" in [1-9]) ;; *) _fcur=$(profile_effective) ;; esac
        [ -f "$FAILOVER_STATE" ] && { read -r _fs _fh < "$FAILOVER_STATE"; } 2>/dev/null
        case "$_fs" in ''|*[!0-9]*) _fs=$_fcur; _fh=0 ;; esac
        case "$_fh" in ''|*[!0-9]*) _fh=0 ;; esac
        if [ "$4" = "giveup" ]; then
            # Both state files go, so the watchdog's backoff retries start from the user's
            # primary profile and may walk a fresh circle.
            log_msg "FAILOVER: profile circle complete ($_fh switches, none passed the health check) — giving up; the watchdog keeps retrying the primary profile with backoff"
            awg_incident "failover gave up: all candidate profiles failed the health check (${5:-health check failed})"
            rm -f "$FAILOVER_STATE" "$PF_OVERRIDE"
        else
            _fnext=${4%% *}
            echo "$4" > "$PF_OVERRIDE"
            printf '%s %s\n' "$_fs" "$((_fh + 1))" > "$FAILOVER_STATE"
            log_msg "FAILOVER: switching to config profile $(profile_desc "$_fnext") — hop $((_fh + 1))"
            awg_incident "health-check failover: profile $(profile_iref "$_fcur") -> $(profile_iref "$_fnext") (${5:-health check failed})"
        fi
    fi
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
    # The lan_net-scoped masq is the pre-1.3.9 layout — keep draining it so the first
    # stop after an upgrade clears rules installed by the old version.
    [ -n "$lan_net" ] && ipt_drain -t nat -D POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE
    ipt_drain -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE

    cleanup_firewall
    # On a deliberate user stop/uninstall, also drop the self-heal watchdog so the VPN stays
    # down. Auto-rollbacks (health-check, deadman) call do_stop withOUT "user", so the
    # watchdog survives and can still recover the tunnel on its own.
    [ "$user_stop" = "user" ] && cru d awg_watchdog 2>/dev/null
    # A deliberate stop also resets the profile-failover state: the next manual start should
    # come up on the user's chosen primary, not a leftover auto-switched slot.
    [ "$user_stop" = "user" ] && rm -f "$PF_OVERRIDE" "$FAILOVER_STATE" 2>/dev/null
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
    # No daemon -> no "running config" (conf md5 + which profile) to compare against.
    rm -f "$RUNNING_CONF_SIG" "$RUNNING_PF"

    reload_dnsmasq

    log_msg "Stopped"
    # do_restart's bridge: its start half follows — show "Connecting" from here on, not a
    # stopped tunnel with no flags (see do_restart).
    [ -n "$AWG_FLAG_BRIDGE" ] && echo "$AWG_FLAG_BRIDGE" > "$STARTING_FLAG"
    rm -f "$STOPPING_FLAG"
    update_status
    release_lock
    return 0
}

# Stop then start as ONE operation, keeping the "Connecting" marker set across the stop->start
# gap so the status never flashes a fully-stopped state mid-restart. Without it, the brief
# running=false / no-flags window between do_stop and do_start made every status reader (page
# steady poll, header widget, watchdog) see "stopped" and surface a clickable «Запустить» that
# raced the restart's own start. The flag carries this restart's own id (see flag_clear_mine):
# do_stop writes it before its last status write, do_start reuses it, and it is removed here —
# only if still ours — whatever do_start returned (its early returns come BEFORE its trap).
#   $1 = connection-history stop token (switch/failover); default "restart"
#   $2 = expected generation, $3 = failover commit, $4 = reason — passed to do_stop (see there)
# rc: 3 = the stop half could not take the lock (nothing restarted; do_stop logged it, and the
#     flag is left alone — it belongs to whoever holds the lock), 2 = superseded, else do_start's.
do_restart(){
    local _rc
    awg_new_id; AWG_FLAG_ID="$AWG_NEW_ID"
    AWG_FLAG_BRIDGE="$AWG_FLAG_ID"
    do_stop "" "${1:-restart}" "$2" "$3" "$4"; _rc=$?
    AWG_FLAG_BRIDGE=""
    case $_rc in
        0) ;;
        2) return 2 ;;
        *) log_msg "ERROR: could not stop: another operation holds the lock — nothing restarted"
           update_status
           return 3 ;;
    esac
    echo "$AWG_FLAG_ID" > "$STARTING_FLAG"
    update_status
    wait_for_pid_exit amneziawg-go 10
    do_start "$AWG_GEN_STOPPED" "$AWG_FLAG_ID"; _rc=$?
    flag_clear_mine
    update_status
    return $_rc
}

# --- Stale `status` reaper ---------------------------------------------------------------
# `nvram get` can block FOREVER. It waits on a reply from the firmware's envrams daemon over a
# socket and has NO timeout, so when that reply is lost the caller sits in the kernel
# (__skb_wait_for_more_packets) until it is killed. Field-found 2026-08-03 on a GT-AX6000 with
# 17 days uptime: FIVE `status` runs wedged 7, 9.6, 12.9, 16.8 and 17.0 days, each on
# `nvram get wgc<N>_enable` (fw_vpn_client_state) or `nvram get preferred_lang` (update_status).
# Every event leaks THREE processes — the cron wrapper, the script, and the nvram child — and
# nothing ever cleaned them up: `status` deliberately takes no lock (see the cru comment in
# setup_firewall), so nothing else stalls and the pile is invisible until someone reads `ps`.
# Rate on that box was ~1 hang per 30k nvram calls, i.e. one every few days — harmless per
# event, unbounded across a long uptime, and only a reboot cleared it.
# A healthy status run finishes in well under a second, so anything older than STATUS_STALE_S
# is wedged by definition. The reaper is deliberately FORK-FREE (`read` builtin + parameter
# expansion, no tr/awk/ps per /proc entry) because it runs on the */1 cron.
STATUS_STALE_S=600

# Echo the pids of status runs older than STATUS_STALE_S. Used by the reaper and by diag.
stale_status_pids(){
    local up d p c sline st age out=""
    { read -r up < /proc/uptime; } 2>/dev/null || return 0
    up=${up%%.*}
    case "$up" in ''|*[!0-9]*) return 0 ;; esac
    for d in /proc/[0-9]*; do
        p=${d#/proc/}
        [ "$p" = "$$" ] && continue
        # The redirect is wrapped so a process that exits between the glob and the read cannot
        # print "can't open ..." — this runs every minute and its stderr is a shared log.
        # NB gate on the VARIABLE, never on read's exit status: /proc/<pid>/cmdline has no
        # trailing newline, so `read` returns 1 even when it filled the variable perfectly.
        # `read` drops the NUL separators, so argv arrives concatenated ("…/amneziawg.shstatus")
        # — the glob still matches, and so does the cron wrapper's `sh -c '…/amneziawg.sh' status`.
        c=""
        { read -r c < "$d/cmdline"; } 2>/dev/null
        [ -n "$c" ] || continue
        # BOTH roles: the server has its own */1 status cron with its own nvram reads, and
        # "amneziawg_server.sh" does NOT contain the substring "amneziawg.sh", so 1.5.10 left it
        # unprotected. Anchored on $ADDON_DIR rather than a bare script name — a user's own
        # /jffs/scripts/amneziawg.sh taking a `status` argument must never be kill -9'd by us
        # (1.5.10's pattern would have). Verified against 11 cmdline shapes under busybox.
        case "$c" in
            *"$ADDON_DIR"/amneziawg.sh*status*|*"$ADDON_DIR"/amneziawg_server.sh*status*) ;;
            *) continue ;;
        esac
        sline=""
        { read -r sline < "$d/stat"; } 2>/dev/null
        [ -n "$sline" ] || continue
        # `set -f` ONLY around the split: it must NOT be on for the `for` glob above, and the
        # positional params are already assigned by the time globbing is restored.
        set -f; set -- $sline; set +f
        [ $# -ge 22 ] || continue
        shift 21                # field 22 = starttime, in clock ticks (USER_HZ = 100)
        st=$1
        case "$st" in ''|*[!0-9]*) continue ;; esac
        age=$(( up - st / 100 ))
        [ "$age" -gt "$STATUS_STALE_S" ] && out="$out $p"
    done
    echo $out
}

reap_stale_status(){
    local victims kids="" d p sline v n
    victims=$(stale_status_pids)
    [ -n "$victims" ] || return 0
    for d in /proc/[0-9]*; do
        p=${d#/proc/}
        sline=""
        { read -r sline < "$d/stat"; } 2>/dev/null
        [ -n "$sline" ] || continue
        set -f; set -- $sline; set +f
        [ $# -ge 4 ] || continue    # pid (comm) state ppid — comm is `sh`/`nvram`, never spaced
        for v in $victims; do
            [ "$4" = "$v" ] && { kids="$kids $p"; break; }
        done
    done
    # Children FIRST: killing only the shells would free the wedged `nvram get` to write into a
    # closed pipe, and killing only the nvram child would let the shell resume and publish a
    # status file assembled from data that is DAYS old.
    kill -9 $kids 2>/dev/null
    kill -9 $victims 2>/dev/null
    n=$(echo $victims $kids | wc -w)
    log_msg "Reaped $n stale 'status' process(es) — a firmware 'nvram get' had wedged them (envrams IPC has no timeout)"
}

# Age of one process in seconds — /proc/<pid>/stat field 22 (starttime, USER_HZ=100 ticks)
# against /proc/uptime, no forks. Prints nothing when either read fails (gone pid, bad stat).
proc_age_s(){
    local pp="$1" up sline
    { read -r up < /proc/uptime; } 2>/dev/null || return 0
    up=${up%%.*}
    case "$up" in ''|*[!0-9]*) return 0 ;; esac
    sline=""
    { read -r sline < "/proc/$pp/stat"; } 2>/dev/null
    [ -n "$sline" ] || return 0
    # `set -f` only around the split (the stale_status_pids lesson); field 2 = (comm) — ours
    # are `sh`/`nvram`, never spaced, so field 22 really is starttime.
    set -f; set -- $sline; set +f
    [ $# -ge 22 ] || return 0
    shift 21
    case "$1" in ''|*[!0-9]*) return 0 ;; esac
    echo $(( up - $1 / 100 ))
}

# --- Stale dnsmasq-reload-job reaper (1.5.21) --------------------------------------------
# Second incarnation of the wedged-`nvram get` disease (see reap_stale_status above): the
# DETACHED reload_dnsmasq job polls a bare `nvram get rc_service` once a second inside
# _rc_settle, and ONE lost envrams reply parks the whole job in the kernel forever — while it
# HOLDS /tmp/.awg_dnsreload. Every later reload then waits its 240 s and self-skips ("another
# reload job still running"), so dnsmasq never picks up refreshed DOMAIN geo rules again until
# a reboot. Field-caught 2026-08-24 (TUF-AX3000_V2 @1.5.20 diag): holder alive 6+ minutes, rc
# idle the whole time, not one further journal/syslog line from the job — parked before its
# `service` call, i.e. inside the nvram read. Unlike a status run, this job's lifetime is
# LEGITIMATELY minutes (up to 240 s in the lock queue, a 150 s rc-settle budget, and up to 30
# notify_rc attempts that can each block ~15 s on a busy rc), so the threshold sits far above
# all of that combined. Age is measured on the holder PROCESS (proc_age_s), not on a lock
# file — so locks taken by a pre-1.5.21 addon are covered the moment this version lands.
DNSRELOAD_STALE_S=1200

reap_stale_dnsreload(){
    local hp age victims kids more d p sline v pass
    [ -d /tmp/.awg_dnsreload ] || return 0
    hp=$(cat /tmp/.awg_dnsreload/pid 2>/dev/null)
    if [ -z "$hp" ]; then
        # mkdir won but the pid write never landed (writer killed in that instant). The
        # queue's dead-holder reclaim keys on the pid FILE, so a pidless dir blocks every
        # reload forever. Same age discipline as the watchdog's LOCKDIR reclaim: touch it
        # only once the dir is demonstrably old — mid-acquire is a moment, not minutes.
        [ -n "$(find /tmp/.awg_dnsreload -maxdepth 0 -mmin +5 2>/dev/null)" ] || return 0
        rm -rf /tmp/.awg_dnsreload 2>/dev/null
        log_msg "WATCHDOG: removed an orphaned pidless dnsmasq-reload lock (it was blocking every reload)"
        return 0
    fi
    case "$hp" in *[!0-9]*) return 0 ;; esac
    if ! kill -0 "$hp" 2>/dev/null; then
        # Dead holder. The reload queue reclaims these itself, but only when the NEXT reload
        # actually queues up behind it — clear it now so that one starts instantly instead.
        rm -rf /tmp/.awg_dnsreload 2>/dev/null
        return 0
    fi
    age=$(proc_age_s "$hp")
    [ -n "$age" ] || return 0
    [ "$age" -gt "$DNSRELOAD_STALE_S" ] || return 0
    # Collect the holder's descendants TRANSITIVELY: the wedged `nvram get` runs inside a
    # $(…) command-substitution subshell, i.e. it is usually a GRANDchild of the holder — a
    # single-level PPid pass would kill the middle shell and orphan the nvram process, still
    # wedged, onto init. Deepest generation lands FIRST in $kids, and children die BEFORE
    # the holder (the reap_stale_status lesson: freeing the shell alone lets it resume and
    # act on a world that moved on minutes ago).
    victims=" $hp"; kids=""; pass=0
    while [ $pass -lt 4 ]; do
        more=""
        for d in /proc/[0-9]*; do
            p=${d#/proc/}
            case "$victims$more " in *" $p "*) continue ;; esac
            sline=""
            { read -r sline < "$d/stat"; } 2>/dev/null
            [ -n "$sline" ] || continue
            set -f; set -- $sline; set +f
            [ $# -ge 4 ] || continue    # pid (comm) state ppid — our victims' comms are never spaced
            for v in $victims; do
                [ "$4" = "$v" ] && { more="$more $p"; break; }
            done
        done
        [ -n "$more" ] || break
        kids="$more$kids"
        victims="$victims$more"
        pass=$((pass + 1))
    done
    [ -n "$kids" ] && kill -9 $kids 2>/dev/null
    kill -9 "$hp" 2>/dev/null
    rm -rf /tmp/.awg_dnsreload 2>/dev/null
    log_msg "WATCHDOG: reaped a wedged dnsmasq-reload job (pid $hp, ${age}s old — a firmware 'nvram get' with no timeout had parked it; reloads were being skipped) — re-queuing the reload"
    # The killed job's reload never happened; run a fresh one so refreshed domain rules reach
    # dnsmasq now rather than at the next Apply. It detaches itself and self-skips via the
    # conf md5 signature when there is genuinely nothing to load.
    reload_dnsmasq
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

    # JSON-escape: backslash FIRST, then quotes; tabs -> spaces and other control bytes dropped. A
    # lone backslash (a pasted Windows path in a log line) or a raw tab made awg_status.htm invalid
    # JSON and the page showed the router as offline until that line scrolled out of the tail.
    log_text=$(grep "amneziawg" /tmp/syslog.log 2>/dev/null | tail -20 | tr '\t' ' ' | tr -d '\000-\010\013-\037' | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

    # "Daemon up but the tunnel isn't established" flag for the UI. True only while running and NO
    # peer has EVER completed a handshake (peer_hs_max==0 → endpoint unreachable / obfuscation
    # mismatch). The page uses this to replace a bare "Connected" with an honest "no handshake"
    # state — critical with kill-switch ON, where geo traffic is silently blackholed. The
    # "handshaked once, then went stale" case needs no new field: the page derives age client-side
    # from each peer's hs_epoch. The page must gate any banner on !starting && !stopping (the brief
    # post-start window before the first handshake legitimately reads true).
    local no_handshake=false
    [ "$running" = "true" ] && [ "$peer_hs_max" -eq 0 ] && no_handshake=true

    # Saved config differs from what the RUNNING daemon carries (Apply saves + regenerates the
    # conf but deliberately never restarts the tunnel) — drives the page's yellow "изменения
    # применятся после «Перезапустить»" badge. Primary signal: the launch-time md5 recorded by
    # do_start vs the current conf. Fallback (upgrade over a running tunnel, no sig recorded
    # yet): compare the live first-peer public key from `awg show dump` against the conf's —
    # solid for the real field case (a swapped provider config always swaps the peer key);
    # param-only edits are caught once the sig exists, i.e. from the first restart on.
    # Does this build support the AmneziaWG 3.0 device params? Drives the page's v3 fields
    # (disabled + explained when false) so the user cannot enter values that generate_config
    # would then refuse to emit. Cached in /tmp, keyed on the binaries — cheap per poll.
    local awg3_cap=false
    awg3_supported && awg3_cap=true
    # Same, one protocol step up: the AmneziaWG 3.1 pair (RandomTrailers/DisableCookies).
    local awg31_cap=false
    awg31_supported && awg31_cap=true

    # The profile the tunnel materializes NOW (a VALID failover override honored), resolved ONCE
    # per tick — conf_pending below and the profile block further down share it (and its
    # fingerprint, when the override check already computed one).
    local pf_active _eff_fp="" _rpf_slot="" _rpf_fp=""
    profile_resolve; pf_active=$AWG_PF_EFF

    local conf_pending=false _rc_sig _cf_sig _pk_live _pk_conf
    if [ "$running" = "true" ]; then
        if [ -f "$CONF" ]; then
            _cf_sig=$(md5sum "$CONF" 2>/dev/null | awk '{print $1}')
            _rc_sig=$(cat "$RUNNING_CONF_SIG" 2>/dev/null)
            if [ -n "$_rc_sig" ]; then
                [ "$_rc_sig" != "$_cf_sig" ] && conf_pending=true
            elif [ -n "$dump" ]; then
                _pk_live=$(printf '%s\n' "$dump" | awk -F'	' 'NR==1{print $1}')
                _pk_conf=$(awk -F' *= *' '/^PublicKey/{print $2; exit}' "$CONF" 2>/dev/null)
                [ -n "$_pk_live" ] && [ -n "$_pk_conf" ] && [ "$_pk_live" != "$_pk_conf" ] && conf_pending=true
            fi
        fi
        # ...OR the profile now in effect is not the one running. A switch whose restart never
        # happened (the firmware dropped the event, the lock was held, the stop failed) leaves
        # the conf untouched — the md5 alone says "nothing pending" while the page's pointer
        # names another profile. RUNNING_PF (do_start) records the slot + fingerprint the daemon
        # was built from; an edited identity of the SAME slot counts too. A tunnel started before
        # 1.5.26 has no record, which skips this test.
        if [ "$conf_pending" = false ] && [ -f "$RUNNING_PF" ]; then
            { read -r _rpf_slot _rpf_fp < "$RUNNING_PF"; } 2>/dev/null
            if [ -n "$_rpf_slot" ]; then
                if [ "$_rpf_slot" != "$pf_active" ]; then
                    conf_pending=true
                else
                    _eff_fp=${AWG_PF_EFF_FP:-$(pf_fp "$pf_active")}
                    [ "$_rpf_fp" != "$_eff_fp" ] && conf_pending=true
                fi
            fi
        fi
    fi

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
    # A FOREIGN match-all dnsmasq directive (hand-written in the user's own custom config) that
    # dumps EVERY domain into one of our geo sets — dnsmasq treats the empty //-segment left by a
    # `https://` scheme (or a bare `#`) as "match all", so Geo mode routes the WHOLE LAN through the
    # tunnel (field report 2026-07-13). We only surface it (the line is the user's to fix). Gated on
    # geo actually being in use — otherwise our sets don't route and the line is inert.
    local geo_matchall_warn=""
    if geo_in_use; then
        # Strip control chars (CR/TAB/etc — unescaped they'd make JSON.parse throw) and truncate
        # BEFORE the backslash/quote escaping, so `cut` can never split an escape pair in half.
        geo_matchall_warn=$(geo_foreign_matchall | head -1 | tr -d '\000-\037' | cut -c1-200 | sed 's/\\/\\\\/g; s/"/\\"/g')
    fi

    # Can we offer a "Stop Xray" button? Only if XRAYUI's own entry point is present (so the stop
    # goes through its cleanup_firewall and actually removes the TPROXY rules).
    local xray_ctl=false
    [ -x /jffs/scripts/xrayui ] && xray_ctl=true

    # Old-kernel banner retired in 1.2.61 — 2.6.x is supported again (sendmmsg fallback + the
    # drain_ip_rules fix). Field kept (always false) so the page's dormant renderer just hides it.
    local kernel_unsup=false

    # Broadcom CTF hard-wedges the box on policy-routing bring-up (see ctf_active) — surfaced so the
    # page renders a banner with a one-click "disable CTF + reboot". Shown on 2.6.x too now (since
    # 1.2.60 the kernel guard is a warning, not a block, so a 2.6.x user CAN try the tunnel — but
    # must disable CTF first, else it hard-wedges). False on every non-CTF box.
    local ctf_block=false
    ctf_active && ctf_block=true

    # Memory envelope at its floor (see mem_squeeze_state): the RUNNING daemon was launched
    # with GOMEMLIMIT on the strict-overcommit floor and the live budget is still there,
    # which OOM-aborts it under sustained inbound load and reads to the user as "the VPN
    # drops every few minutes". The levers are box-side (swap / fewer memory consumers), so
    # the page renders them. Only while the tunnel runs — the banner is about the daemon in
    # service; the prediction for a stopped tunnel lives in diag/`mem` and the start log.
    # mem_detail = "<GOMEMLIMIT MiB>|<pool cap>|<SwapTotal MiB>"; the page formats it, so
    # the numbers stay machine-readable and the wording stays bilingual.
    local mem_squeeze="" mem_detail="" _msq=""
    [ "$running" = true ] && _msq=$(mem_squeeze_state)
    if [ -n "$_msq" ]; then
        mem_squeeze=${_msq%%|*}
        mem_detail=${_msq#*|}
    fi

    # Config profiles for the UI: the slot the tunnel materializes (active — resolved above),
    # the user's persisted choice (user; differs from active only under a VALID failover
    # override) and a compact per-slot list for the profile bar, all from ONE pf_scan. Names
    # arrive decoded and sanitized (no control bytes, no '<' '>') and EMPTY when unset — the page
    # renders its own localized "unnamed" label with the ordinal; they are only JSON-escaped here.
    # No byte cut any more: the old 48-byte cut split Cyrillic mid-character (the page caps
    # names at 32 characters itself).
    local pf_user pf_auto pf_name="" pf_list="" pf_failover=false
    local _pfn _pfc _pff _pfnm _pfsep=""
    pf_user=$(profile_user)
    pf_auto=false
    [ "$pf_active" != "$pf_user" ] && pf_auto=true
    while IFS='	' read -r _pfn _pfc _pff _pfnm; do
        [ -n "$_pfn" ] || continue
        case "$_pfnm" in *[\\\"]*) _pfnm=$(printf '%s' "$_pfnm" | sed 's/\\/\\\\/g; s/"/\\"/g') ;; esac
        [ "$_pfn" = "$pf_active" ] && pf_name=$_pfnm
        if [ "$_pfc" = 1 ]; then _pfc=true; else _pfc=false; fi
        if [ "$_pff" = 0 ]; then _pff=false; else _pff=true; fi
        pf_list="${pf_list}${_pfsep}{\"n\":${_pfn},\"name\":\"${_pfnm}\",\"cfg\":${_pfc},\"fo\":${_pff}}"
        _pfsep=","
    done <<EOF
$(pf_scan)
EOF
    [ "$(get_setting awg_failover)" = "1" ] && pf_failover=true

    # An ACCEPTED profile switch is restarting (profile_switch_restart publishes it): the page's
    # switch transition counts this as "in progress" even in the instants no start/stop flag is
    # up. Ignored once older than 150 s (a switch restart that long has died), then 0.
    local switch_req=0 _sq_slot="" _sq_at="" _sq_age
    if [ -f "$SWITCH_REQ" ]; then
        { read -r _sq_slot _sq_at < "$SWITCH_REQ"; } 2>/dev/null
        case "$_sq_slot" in
            [1-9]) case "$_sq_at" in
                       ''|*[!0-9]*) ;;
                       *) _sq_age=$(( $(date +%s) - _sq_at ))
                          [ "$_sq_age" -ge 0 ] && [ "$_sq_age" -lt 150 ] && switch_req=$_sq_slot ;;
                   esac ;;
        esac
    fi

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
    # Every '<' leaves as its JSON unicode escape (backslash-u003c — the same string after
    # JSON.parse): this .htm is served through the firmware's ASP evaluator, and user text
    # rides in it — device names, hand-written dnsmasq lines, syslog. One sed, whatever field a
    # stray tag opener hides in.
    rm -f "${STATUS_FILE}.tmp" "${STATUS_FILE}".[0-9]* 2>/dev/null
    sed 's/</\\u003c/g' > "${STATUS_FILE}.$$" << STATUSEOF
{"running":${running},"starting":${starting},"stopping":${stopping},"version":"${AWG_VERSION}","lang":"${pref_lang}","public_key":"${pub_key}","listen_port":"${listen_port}","interface_addr":"${iface_addr}","peers":${peers_json},"no_handshake":${no_handshake},"conf_pending":${conf_pending},"awg3":${awg3_cap},"awg31":${awg31_cap},"conn_start":${conn_start},"conn_uptime":${conn_uptime},"conn_history":${conn_hist},"profile":{"active":${pf_active},"user":${pf_user},"auto":${pf_auto},"name":"${pf_name}","failover":${pf_failover},"list":[${pf_list}]},"switch_req":${switch_req},"default_policy":"${default_policy}","dpi_tool":"${dpi_tool}","killswitch":${killswitch},"agh":${agh},"coexist_warn":${coexist_warn},"xray_capture":${xray_capture},"xray_ctl":${xray_ctl},"fwvpn_state":"${fwvpn_state}","fwvpn_detail":"${fwvpn_detail}","ctf_block":${ctf_block},"mem_squeeze":"${mem_squeeze}","mem_detail":"${mem_detail}","kernel_unsup":${kernel_unsup},"dnsgeo_warn":"${dnsgeo_warn}","geo_matchall_warn":"${geo_matchall_warn}","clients":"${clients_data}","active_rules":${active_rules},"ipset_count":${ipset_count},"geo_domains":${geo_domains},"geo_stats":{${geo_stats}},"geo_downloaded":${geo_downloaded},"geo_busy":${geo_busy},"analyze_active":${analyze_active},"log":"${log_text}"}
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
    # '<' as its JSON unicode escape, like the status file: a queried domain name is LAN-client
    # text, and this .htm goes through the firmware's ASP evaluator (a stray tag opener livelocks
    # httpd).
    sed 's/</\\u003c/g' > "${ANALYZE_FILE}.$$" <<ANEOF
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

# The pages' LIVE-STORE endpoint (1.5.26). A .htm under /www/user goes through the firmware's
# ASP evaluator, so this 38-byte file's OUTPUT is the current custom_settings object between
# two AWGCS markers — the client and server pages GET it right before every settings save
# (conflict check: did another tab / the other page / SSH change the store since this page
# loaded?) and right after it (did the firmware actually write this save?). Its template tag
# is the ONE ASP-tag opener in this script and lives only in printf's ARGUMENT (a format
# string would reinterpret the '%'): the same evaluator livelocks httpd on a stray opener in
# any served file, which is why log_msg/diag/status all neutralize them. /www/user is tmpfs,
# so it is re-published with every page copy (install_page, and mount_ui at each boot).
awg_cs_publish(){
    printf '%s' 'AWGCS<% get_custom_settings(); %>AWGCS' > /www/user/awg_cs.htm 2>/dev/null
}

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
    local cli_page="$am_webui_page"

    cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$cli_page"
    awg_cs_publish
    # Publish the global header widget to the web root before binding the loader
    [ -f "$ADDON_DIR/amneziawg_widget.js" ] && cp "$ADDON_DIR/amneziawg_widget.js" /www/user/awg_widget.js 2>/dev/null

    # AWG-server role page (its own slot + the in-browser QR generator asset). Guarded per
    # step: a missing server page (older/partial install) must never fail the client install.
    [ -f "/tmp/amneziawg_server_page.asp" ] && cp /tmp/amneziawg_server_page.asp "$ADDON_DIR/amneziawg_server_page.asp"
    local srv_page=""
    if [ -f "$ADDON_DIR/amneziawg_server_page.asp" ]; then
        am_get_webui_page "$ADDON_DIR/amneziawg_server_page.asp"
        if [ "$am_webui_page" != "none" ]; then
            srv_page="$am_webui_page"
            cp "$ADDON_DIR/amneziawg_server_page.asp" "/www/user/$srv_page"
            awg_cs_publish
        else
            log_msg "WARNING: no free page slot for the AmneziaWG Server page — client page installed alone"
        fi
    fi
    [ -f "$ADDON_DIR/awg_qr.js" ] && cp "$ADDON_DIR/awg_qr.js" /www/user/awg_qr.js 2>/dev/null
    [ -f "$AWGS_SCRIPT" ] && chmod +x "$AWGS_SCRIPT" 2>/dev/null

    mount_menu_tree "$cli_page" "$srv_page"

    # Both seeds carry "awg3"/"awg31" for the same reason: until the role's own status pass
    # runs, this stub IS what the page polls, and a missing field reads as "capability unknown".
    _seed_awg3=false; awg3_supported && _seed_awg3=true
    _seed_awg31=false; awg31_supported && _seed_awg31=true
    echo "{\"running\":false,\"starting\":false,\"stopping\":false,\"version\":\"${AWG_VERSION}\",\"awg3\":${_seed_awg3},\"awg31\":${_seed_awg31},\"killswitch\":false,\"coexist_warn\":false,\"dpi_tool\":\"\",\"peers\":[],\"log\":\"Installed.\"}" > "$STATUS_FILE"
    # Seed the server status file too, so the server page's first poll isn't a 404.
    # It MUST carry "awg3": the full status is only written by srv_update_status, which runs
    # from the server's own */1 cron and therefore never on a router where the server role was
    # never configured. Without the field the page reads undefined and — failing closed — told
    # the user "AmneziaWG 3.0 parameters are not supported by the installed binaries", which is
    # simply false on a box whose daemon and CLI both handle 3.0 (field-reported on the RT-AX).
    [ -f /www/user/awgs_status.htm ] || echo "{\"running\":false,\"starting\":false,\"stopping\":false,\"version\":\"${AWG_VERSION}\",\"awg3\":${_seed_awg3},\"awg31\":${_seed_awg31},\"peers\":[],\"log\":\"\"}" > /www/user/awgs_status.htm 2>/dev/null

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

    # Firewall restart hook. Rewritten idempotently on every install_page (sed-delete +
    # re-append, the postconf-hook convention) so upgrades gain the SERVER line too — the
    # old grep-not-found gate would have frozen existing installs on the client-only line.
    # Both lines contain "amneziawg" (the path), so uninstall's `sed /amneziawg/d` drops both.
    [ ! -f /jffs/scripts/firewall-start ] && echo "#!/bin/sh" > /jffs/scripts/firewall-start
    chmod +x /jffs/scripts/firewall-start 2>/dev/null
    sed -i '/amneziawg/d' /jffs/scripts/firewall-start 2>/dev/null
    echo '/jffs/addons/amneziawg/amneziawg.sh firewall_restart  # AmneziaWG' >> /jffs/scripts/firewall-start
    echo '[ -f /jffs/addons/amneziawg/amneziawg_server.sh ] && sh /jffs/addons/amneziawg/amneziawg_server.sh firewall_restart  # AmneziaWG server' >> /jffs/scripts/firewall-start

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
    # 3rd guard (server role): serve DNS to AWG-server peers by appending interface=awgs0 —
    # but ONLY while the interface actually exists at this dnsmasq (re)start. This is why the
    # line lives in the POSTCONF hook and not in a persistent include: it re-evaluates on
    # every dnsmasq start, so a crashed/stopped server can never leave a dangling
    # `interface=` that would be fatal to the firmware's dnsmasq (the conf-file= lesson).
    echo '. /usr/sbin/helper.sh; [ -f /tmp/.awg_tunnel_dns ] && { pc_delete "servers-file=" "$1"; pc_delete "resolv-file=" "$1"; }; [ -f /opt/amneziawg/dnsmasq_awg.conf ] || pc_delete "conf-file=/opt/amneziawg/dnsmasq_awg.conf" "$1"; [ -f /opt/amneziawg/dnsmasq_analyze.conf ] || pc_delete "conf-file=/opt/amneziawg/dnsmasq_analyze.conf" "$1"; [ -d /sys/class/net/awgs0 ] && pc_append "interface=awgs0" "$1"  # amneziawg dnsmasq guard' >> /jffs/scripts/dnsmasq.postconf

    [ ! -f /jffs/scripts/services-start ] && echo "#!/bin/sh" > /jffs/scripts/services-start
    chmod +x /jffs/scripts/services-start 2>/dev/null
    # Rewrite OUR lines idempotently on every install (same pattern as dnsmasq.postconf above)
    # so upgrades gain new hooks. Two delete patterns cover history: the legacy untagged
    # mount_ui line (pre-1.5.8) and the '# amneziawg-addon' tag on everything since. Do NOT
    # gate the append on a bare `grep -q amneziawg` (the pre-1.5.8 shape): any USER-added line
    # mentioning amneziawg — e.g. a manual S99 autostart workaround from the support chat —
    # used to suppress installing our hooks entirely.
    sed -i '/amneziawg.sh mount_ui/d;/# amneziawg-addon$/d' /jffs/scripts/services-start 2>/dev/null
    # A user file whose last line lacks \n would glue our first line onto it — pad once.
    [ -n "$(tail -c1 /jffs/scripts/services-start 2>/dev/null)" ] && echo "" >> /jffs/scripts/services-start
    echo "/jffs/addons/amneziawg/amneziawg.sh mount_ui & # amneziawg-addon" >> /jffs/scripts/services-start
    # Boot fallback for the Entware init race (firmware-native vs post-mount double-starter
    # skipping ALL S* start scripts) — see do_boot_guard. Backgrounded: it sleeps for minutes.
    echo "/jffs/addons/amneziawg/amneziawg.sh boot_guard & # amneziawg-addon" >> /jffs/scripts/services-start

    [ -f "$GEO_DIR/v2fly_categories.txt" ] && cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null

    log_msg "Page installed: $cli_page${srv_page:+ + server page: $srv_page}"
    echo "Installed. Access: VPN > AmneziaWG${srv_page:+ (server mode: VPN > AmneziaWG Server)}"
}

do_mount_ui(){
    source /usr/sbin/helper.sh
    # Clean old slots
    for f in /www/user/user*.asp; do
        grep -q "AmneziaWG" "$f" 2>/dev/null && rm -f "$f"
    done
    am_get_webui_page "$ADDON_DIR/amneziawg_page.asp"
    if [ "$am_webui_page" != "none" ]; then
        local cli_page="$am_webui_page" srv_page=""
        cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$cli_page"
        awg_cs_publish
        [ -f "$ADDON_DIR/amneziawg_widget.js" ] && cp "$ADDON_DIR/amneziawg_widget.js" /www/user/awg_widget.js 2>/dev/null
        # AWG-server role page (second slot) + the QR generator asset — mirrors do_install_page.
        if [ -f "$ADDON_DIR/amneziawg_server_page.asp" ]; then
            am_get_webui_page "$ADDON_DIR/amneziawg_server_page.asp"
            if [ "$am_webui_page" != "none" ]; then
                srv_page="$am_webui_page"
                cp "$ADDON_DIR/amneziawg_server_page.asp" "/www/user/$srv_page"
                awg_cs_publish
            fi
        fi
        [ -f "$ADDON_DIR/awg_qr.js" ] && cp "$ADDON_DIR/awg_qr.js" /www/user/awg_qr.js 2>/dev/null
        mount_menu_tree "$cli_page" "$srv_page"
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

    # AWG-server role first (its own daemon awgs-go, firewall rules, crons, status files).
    # 'stop user' mirrors the client semantics: deliberate stop -> drop the server crons too.
    [ -f "$AWGS_SCRIPT" ] && sh "$AWGS_SCRIPT" stop user 2>/dev/null

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

    # Remove EVERY page slot we own (client + server pages both contain "AmneziaWG").
    local page
    for page in /www/user/user*.asp; do
        grep -q "AmneziaWG" "$page" 2>/dev/null && rm -f "$page"
    done
    rm -f "$STATUS_FILE" /www/user/awg_widget.js /www/user/v2fly_categories.htm /www/user/awg_changelog.htm /www/user/awg_update.htm /www/user/awg_log.htm /www/user/awg_diag.htm
    rm -f /www/user/awg_qr.js /www/user/awgs_status.htm /www/user/awgs_log.htm /www/user/awg_cs.htm
    rm -f "$ANALYZE_FILE" "$ANALYZE_DNS_CONF" "$ANALYZE_DNS_LOG" /tmp/.awg_analyze_*

    rm -f "$AWG_INCIDENTS"
    rm -f "$CONN_HIST_BAK"   # update-time stash lives OUTSIDE $AWG_DIR — the package rm -rf misses it
    rm -rf "$ADDON_DIR"

    if [ -f /tmp/menuTree.js ]; then
        # Substring match (no closing quote) — removes BOTH tabs: "AmneziaWG" and "AmneziaWG Server"
        sed -i '/tabName: "AmneziaWG/d' /tmp/menuTree.js
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

# One-shot probe of the two things a firmware firewall restart clobbers ON SOME BUILDS while
# the tunnel stays up: our mangle PREROUTING hook (the packet marking) and the table-$RT_TABLE
# policy route. NB this is NOT the whole wipe surface: 3006.102.x rebuilds were field-caught
# SPARING both of these while wiping the filter/nat/mangle-FORWARD base rules instead — that
# class is covered by heal_base_rules below, not by this probe.
# THREE-way verdict, because `iptables -C` exit codes are NOT binary:
#   0 = both present; 1 = something is genuinely ABSENT (kernel table reads are atomic, so
#       rc=1 is trustworthy; it also covers "chain gone" — same thing for us);
#   2 = the PROBE ITSELF failed — table state UNKNOWN. iptables rc>=2 is lock/exec trouble,
#       not absence: Entware iptables 1.4.21 takes the global xtables lock for EVERY op
#       including -C (and no -w is available across the fleet), so a collision with any
#       concurrent iptables exits rc=4 "Another app is currently holding the xtables lock";
#       a sick binary gives 139, fork pressure its own codes.
# Detail for the journal lands in AWG_MARKS_MISSING / AWG_MARKS_ERR (reset on each call).
awg_marks_state(){
    AWG_MARKS_MISSING=""; AWG_MARKS_ERR=""
    local _rc _err
    _err=$(iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>&1); _rc=$?
    if [ $_rc -ge 2 ]; then
        AWG_MARKS_ERR="iptables -C rc=$_rc: $(printf '%s' "$_err" | tr '\n' ' ' | cut -c1-160)"
        return 2
    fi
    if [ $_rc -eq 1 ]; then AWG_MARKS_MISSING="mangle PREROUTING hook"; return 1; fi
    ip route show table $RT_TABLE 2>/dev/null | grep -q "0.0.0.0/1"
    _rc=$?
    if [ $_rc -ge 2 ]; then AWG_MARKS_ERR="route probe rc=$_rc"; return 2; fi
    if [ $_rc -eq 1 ]; then AWG_MARKS_MISSING="policy route in table $RT_TABLE"; return 1; fi
    return 0
}

# One rule for heal_base_rules: -C probe with the 3-way rc discipline (rc=1 is the only
# trustworthy "absent"; rc>=2 is xtables-lock/exec noise — NEVER add on it, the dup would
# outlive stop), add on confirmed absence only, record what happened for the caller's
# journal line. One re-probe on a sick read, one retry on the add (both take the same lock).
# Usage: _heal_base_rule <label> <table> <-I|-A> <chain> <rule tokens…>
_heal_base_rule(){
    local _lbl="$1" _tbl="$2" _how="$3" _chain="$4" _rc
    shift 4
    iptables -t "$_tbl" -C "$_chain" "$@" 2>/dev/null; _rc=$?
    if [ $_rc -ge 2 ]; then
        sleep 1
        iptables -t "$_tbl" -C "$_chain" "$@" 2>/dev/null; _rc=$?
    fi
    case $_rc in
        0) return 0 ;;
        1) AWG_BASE_MISSING="${AWG_BASE_MISSING}${AWG_BASE_MISSING:+, }${_lbl}"
           iptables -t "$_tbl" "$_how" "$_chain" "$@" 2>/dev/null && return 0
           sleep 1
           iptables -t "$_tbl" "$_how" "$_chain" "$@" 2>/dev/null ;;
        *) AWG_BASE_SICK=1; return 1 ;;
    esac
}

# The client-side twin of the server watchdog's "firewall rules missing (firewall
# restarted?)" reconcile. A firmware firewall rebuild does NOT reliably clobber what
# awg_marks_state watches: on 3006.102.x (field: RT-BE88U @1.5.18 — the firmware's own
# WireGuard client wgc1 starting 1 s after our boot start finished) the rebuild wiped the
# filter accepts, both TCPMSS clamps AND the nat MASQUERADE while SPARING the mangle
# PREROUTING hook and the table-300 routes — the only two things the firewall-start fast
# path and the watchdog checked. Every marked LAN packet then left awg0 unNATed and was
# silently dropped by the provider (cryptokey routing), with a fresh handshake and growing
# TX the whole time (142 KiB RX vs 5.8 MiB TX after 3 h) — "the whole internet hung" for
# every geo destination until a manual restart, and the journal stayed empty because the
# watchdog probe pings FROM the tunnel IP (needs no NAT) and the marks probe saw its hook.
# So: re-assert the base rules whenever the marks look intact. All adds mirror do_start's
# base block exactly; a wipe that actually healed is logged LOUDLY + recorded as an incident.
# Arg 1 names the caller for the journal/incident line. Returns 1 only on a sick probe pass
# (nothing asserted — the next tick/hook re-checks).
heal_base_rules(){
    local _ctx="${1:-reconcile}"
    is_running || return 0
    # An operation in flight (live lock holder — start/stop/apply) asserts or removes these
    # rules itself; don't interleave writes with it. (A dup from that race would be benign —
    # identical rules, drained at stop — but it's cheaper to not create it. A DEAD holder's
    # lock does not stand down the heal: the crashed op may be exactly why rules are missing.)
    if [ -d "$LOCKDIR" ]; then
        local _hp
        _hp=$(cat "$LOCKDIR/pid" 2>/dev/null)
        [ -n "$_hp" ] && kill -0 "$_hp" 2>/dev/null && return 0
    fi
    AWG_BASE_MISSING=""; AWG_BASE_SICK=""
    _heal_base_rule "INPUT accept"       filter -I INPUT   -i "$IFACE" -j ACCEPT
    _heal_base_rule "FORWARD accept in"  filter -I FORWARD -i "$IFACE" -j ACCEPT
    _heal_base_rule "FORWARD accept out" filter -I FORWARD -o "$IFACE" -j ACCEPT
    _heal_base_rule "TCPMSS clamp out"   mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    _heal_base_rule "TCPMSS clamp in"    mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    _heal_base_rule "MASQUERADE"         nat    -I POSTROUTING -o "$IFACE" -j MASQUERADE
    if [ -n "$AWG_BASE_MISSING" ]; then
        log_msg "Base firewall rules were wiped (firmware firewall restart?) — re-added: $AWG_BASE_MISSING [$_ctx]"
        awg_incident "base rules wiped ($AWG_BASE_MISSING) — re-added by $_ctx"
        # The same wipe class takes the ip6tables leak-block with it; setup_ipv6_block is
        # -C-guarded itself. Called ONLY here (not every tick): its ipv6_service nvram read
        # must stay off the periodic path — `nvram get` can wedge forever (the 1.5.10 lesson),
        # and a v6-only wipe with all six v4 rules intact does not occur.
        setup_ipv6_block
        case "$AWG_BASE_MISSING" in *MASQUERADE*)
            # Cut flows conntrack'd while MASQUERADE was missing: the un-NATed NAT decision is
            # cached per-connection, so a same-tuple retrier (QUIC) would stay dead even now.
            # Targeted (explicit VPN clients only); unlisted default-policy flows sit UNREPLIED
            # and age out in <=30-120 s on their own.
            flush_conntrack ;;
        esac
        return 0
    fi
    [ -n "$AWG_BASE_SICK" ] && return 1
    return 0
}

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

    # The dnsmasq-reload lock is INDEPENDENT of the main operation lock, so reap a wedged
    # reload job BEFORE the busy-gate below — a stuck holder must not ride out a busy spell.
    # Cheap until it actually fires: one cat + kill -0 + two /proc reads.
    reap_stale_dnsreload

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
        # The start half carries the generation this stop wrote: a user Stop (or any other
        # stop/start) landing in the gap wins — the watchdog must not resurrect a tunnel the
        # user just stopped. A stop that could not take the lock (a live holder — an operation
        # already acting on the tunnel) restarts nothing; the next tick re-evaluates.
        local _wrc
        do_stop "" watchdog 2>/dev/null; _wrc=$?
        [ "$_wrc" = 0 ] || return
        wait_for_pid_exit amneziawg-go 10
        do_start "$AWG_GEN_STOPPED"; _wrc=$?
        [ "$_wrc" = 2 ] && log_msg "WATCHDOG: restart superseded by a newer stop/start — leaving the tunnel as that operation left it"
        return
    fi
    rm -f "$wd_state" 2>/dev/null   # healthy: reset backoff counter

    # A firewall restart wipes our mangle chain/hook (the packet marking) while the
    # tunnel and route table stay up — the checks above still pass. Detect the
    # missing PREROUTING hook (what restart_firewall actually drops) OR a lost policy
    # route and rebuild — lighter than a full restart, self-heals within ~5 min even
    # if the firewall-start hook didn't fire. (Old code checked only the route and
    # missed the far more common mangle-reset case.)
    # CONFIRM before healing — the heal is expensive and user-visible: full teardown +
    # ~5 s ipset/policy rebuild + flush_conntrack cutting the VPN clients' live flows =
    # "VPN vanishes for 10-15 s". The old single-shot `iptables -C` here false-fired on
    # xtables-lock collisions with the every-minute status cron (crond starts both jobs
    # in the same second on every 5th minute; a collision exits 4, which a bare `!`
    # reads as "rules gone" — see awg_marks_state) — field case TUF-AX3000_V2 @1.2.61:
    # several phantom re-applies an evening, each a 10-15 s VPN drop. Rules now:
    #   - heal only on TWO "absent" reads 2 s apart (a real firewall wipe is still gone
    #     2 s later; a lock blip is not; absent reads are atomic, so they need not be
    #     consecutive — an unknown between two absents doesn't un-confirm them);
    #   - a sick probe (rc>=2) = state UNKNOWN: never tear down a possibly-working
    #     firewall on it — log the reason (visible in the journal, so the field can
    #     confirm the mechanism) and let the next tick re-check.
    local _mstate=0 _mabsent=0 _mtry=1 _mblip=""
    while [ $_mtry -le 3 ]; do
        awg_marks_state; _mstate=$?
        case $_mstate in
            0) break ;;                                              # intact — done
            1) _mabsent=$((_mabsent + 1)); [ $_mabsent -ge 2 ] && break ;;
            *) [ -z "$_mblip" ] && _mblip="$AWG_MARKS_ERR" ;;        # probe sick — retry
        esac
        _mtry=$((_mtry + 1))
        [ $_mtry -le 3 ] && sleep 2
    done
    if [ $_mabsent -ge 2 ]; then
        log_msg "WATCHDOG: routing/marking incomplete ($AWG_MARKS_MISSING, confirmed by re-read), re-applying firewall/routes"
        do_firewall_restart
    elif [ $_mstate -ne 0 ]; then
        # Never reached a clean "intact" read, but couldn't confirm a wipe either
        # (persistent lock blips / a single unconfirmed absent). Nothing destructive.
        log_msg "WATCHDOG: marking probe inconclusive (${AWG_MARKS_ERR:-$AWG_MARKS_MISSING unconfirmed}) — NOT healing on a sick probe; next tick re-checks"
    elif [ -n "$_mblip" ]; then
        log_msg "WATCHDOG: transient marking-probe failure ($_mblip) — cleared on retry, firewall intact, no action"
    fi

    # Base-rule reconcile — the client twin of the server watchdog's "rules missing" check,
    # and the safety net for firewall rebuilds whose firewall-start hook didn't fire (or
    # whose fast-path heal hit a sick probe). Intact marks above prove NOTHING about these:
    # the 3006.102.x wipe class leaves the mangle hook + routes alone (see heal_base_rules).
    # If the marks heal already ran the full do_firewall_restart, everything is freshly
    # asserted and this is six no-op -C probes. Safe under an inconclusive marks probe too:
    # each per-rule probe carries its own rc discipline (add only on a confirmed rc=1).
    is_running && heal_base_rules "watchdog"

    # Xray-priority reconcile (only while the tunnel is up). xray may have started AFTER our
    # firewall was built (so non-direct devices are being grabbed by xray with no priority chain
    # present) or stopped since (a stale chain hooked ahead of nothing). Act only on the drift —
    # cheap and idempotent — so we don't flush/rebuild the chain on every tick. (If the marking
    # heal above already ran do_firewall_restart, setup_xray_priority ran with it and this is a
    # no-op.)
    if is_running; then
        if xray_redirect_active; then
            iptables -t mangle -C PREROUTING -j "$AWG_PRIO_CHAIN" 2>/dev/null || {
                log_msg "WATCHDOG: xray now capturing but AWG_PRIO absent — installing tunnel priority"
                setup_xray_priority
            }
        elif iptables -t mangle -C PREROUTING -j "$AWG_PRIO_CHAIN" 2>/dev/null; then
            log_msg "WATCHDOG: xray no longer capturing — removing stale AWG_PRIO chain"
            cleanup_xray_priority
        fi
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
# GitHub's API is not): first its data API (newest git tag), then AWG_VERSION read straight
# off this very script on the CDN. Echoes the version, or nothing if every source is
# unreachable. NB data.jsdelivr.com and cdn.jsdelivr.net are DIFFERENT hosts — one can be
# reachable while the other is not, which is the whole reason the third rung exists.
#
# That third rung used to read PKG_VERSION from build-ipk.sh, and it was DEAD from 1.1.85 to
# 1.5.10: that release switched the file to `PKG_VERSION="${AWG_VERSION}-1"` (single-sourcing
# the version), so the value starts with `$` and the `[0-9]` pattern could never match again.
# Twenty-five releases with a silently broken last resort — nobody noticed, because the two
# rungs above it kept working. Read a LITERAL now: AWG_VERSION sits at byte ~272 of this
# script, so a range request pulls ~1.2 KB instead of a whole file, and if some middlebox
# ignores Range the pattern still matches inside the first bytes of the full body.
# The build asserts this pattern still matches what ships — see release.yml.
awg_resolve_version(){
    local repo="$1" skip_api="$2" v=""
    local awg_bind=$(awg_dl_iface_opt update)
    # api.github.com first (freshest), unless the caller already found it unreachable
    # — re-trying a blocked API just adds another connect timeout to the wait.
    if [ "$skip_api" != "skip_api" ]; then
        v=$(curl -sfL $awg_bind --connect-timeout 5 --max-time 12 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//;s/^v//;s/".*//')
    fi
    [ -z "$v" ] && v=$(curl -sfL $awg_bind --connect-timeout 6 --max-time 15 "https://data.jsdelivr.com/v1/packages/gh/${repo}/resolved" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -z "$v" ] && v=$(curl -sfL $awg_bind --connect-timeout 6 --max-time 15 -r 0-1200 "https://cdn.jsdelivr.net/gh/${repo}@latest/addon/amneziawg.sh" 2>/dev/null | sed -n 's/^AWG_VERSION="\([0-9][0-9.]*\)".*/\1/p' | head -1)
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
# Shared by do_update (after a verified download) and do_install_ipk (after a
# verified local package). Preserves geo lists across the opkg upgrade, stops the VPN, installs,
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

    # AWG-server role: remember whether it was serving, then stop it deterministically for
    # the package swap (the prerm's uninstall would kill it anyway). It is RESTARTED on every
    # post-commit exit path — unlike the client tunnel (left stopped by design), a stopped
    # server locks out the remote peer who launched this very update through it.
    local _srv_restore=0
    if [ -f "$AWGS_SCRIPT" ] && iface_exists "$AWGS_IFACE"; then
        _srv_restore=1
        sh "$AWGS_SCRIPT" stop 2>/dev/null
    fi

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
        [ "$_srv_restore" = 1 ] && [ -f "$AWGS_SCRIPT" ] && sh "$AWGS_SCRIPT" start 2>/dev/null
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
            [ "$_srv_restore" = 1 ] && [ -f "$AWGS_SCRIPT" ] && sh "$AWGS_SCRIPT" start 2>/dev/null
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
    # Bring the AWG server back if it was serving before the update (NEW script version) —
    # the remote peer who launched this update through it gets access back automatically.
    [ "$_srv_restore" = 1 ] && [ -f "$AWGS_SCRIPT" ] && sh "$AWGS_SCRIPT" start 2>/dev/null
    log_msg "Update: complete — now on $label. Start VPN from the UI."
    # Refresh status with the NEW script (this process still runs the old code in memory,
    # so calling update_status directly would re-write the OLD version number).
    /jffs/addons/amneziawg/amneziawg.sh status 2>/dev/null
    # If geo wasn't preserved (wipe option on, or restore failed), re-download with the NEW script.
    /jffs/addons/amneziawg/amneziawg.sh ensure_geo 2>/dev/null
    return 0
}

# Install a local .ipk that the user copied to the router over SSH (WinSCP / scp -O) — CLI
# `amneziawg.sh install_ipk <file>`, also `S99amneziawg install_ipk <file>`. This replaces the
# web UI's "upload a file" mode (1.1.52-1.5.23), which could NEVER work on Asuswrt-Merlin: httpd
# declares amng_custom CKN_STR8192 and discards a larger settings POST whole (nvram_check), and
# each upload chunk was ~45 KB — so the very first one vanished and the router answered "bad seq".
# At the firmware's real limits (<=2900 chars per value, <=8192 bytes per whole-store POST) a
# 2-3 MB package would need ~1000 round trips, each rewriting custom_settings.txt on the JFFS
# flash — not a transport worth keeping. Same safety as before: the whole gzip stream is
# decompressed (trailing CRC32/length verified, so a truncated/corrupt copy is caught BEFORE opkg
# is touched), it must be an opkg package (control.tar.gz member), and it goes through the same
# install core as the in-app update (finalize_ipk_install: geo lists preserved, watchdog stood
# down, page re-installed). Works on a private copy (finalize removes its input), so the user's
# file is left where they put it. The operation log is printed to the terminal at the end.
do_install_ipk(){
    local src="$1" tmp="/tmp/.awg_install_ipk.$$" sz rc=0 err
    if [ -z "$src" ] || [ ! -f "$src" ] || [ ! -s "$src" ]; then
        echo "Usage: /opt/etc/init.d/S99amneziawg install_ipk /tmp/<package>.ipk"
        echo "  Copy the package to the router first: WinSCP (file protocol SCP), or"
        echo "  scp -O <package>.ipk <login>@<router>:/tmp/   (-O = legacy SCP, the router has no SFTP; drop -O if your scp rejects it)"
        [ -n "$src" ] && echo "  ERROR: '$src' is not a file or is empty."
        return 1
    fi
    # The install stops the VPN (and a running AWG server): an SSH session carried by it drops, and
    # the SIGHUP must not kill opkg halfway through replacing the binaries.
    trap '' HUP
    ui_log_reset
    echo "Installing $src — this stops the VPN for a moment; progress is also shown in the web UI log."
    log_msg "Manual install: checking $src"
    rm -f "$tmp"
    if ! err=$(cp "$src" "$tmp" 2>&1); then
        rm -f "$tmp"
        log_msg "Manual install: ERROR could not copy $src to $tmp (${err:-is /tmp full?}) — nothing changed"
        cat "$UI_LOG" 2>/dev/null; return 1
    fi
    sz=$(wc -c < "$tmp" 2>/dev/null)
    # gzip/gunzip is always present (opkg itself needs it); try both applet spellings.
    if ! gzip -dc "$tmp" > /dev/null 2>&1 && ! gunzip -c "$tmp" > /dev/null 2>&1; then
        log_msg "Manual install: ERROR $src is corrupt or not an .ipk (gzip check failed) — nothing changed"
        rm -f "$tmp"; cat "$UI_LOG" 2>/dev/null; return 1
    fi
    if ! tar tzf "$tmp" 2>/dev/null | grep -q 'control\.tar\.gz'; then
        log_msg "Manual install: ERROR $src is not an opkg package (no control.tar.gz) — nothing changed"
        rm -f "$tmp"; cat "$UI_LOG" 2>/dev/null; return 1
    fi
    log_msg "Manual install: package OK ($(human_size "$sz")) — installing"
    finalize_ipk_install "$tmp" "local package $(basename "$src")" || rc=1
    rm -f "$tmp" 2>/dev/null
    cat "$UI_LOG" 2>/dev/null
    return $rc
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
    # awg_marks_state (not a bare -C): an xtables-lock blip used to read as "clobbered" and
    # burn a needless full rebuild. Verified-present (0) skips; a sick probe retries once,
    # then falls through to the rebuild — the safe default right after a REAL firewall
    # restart, when the rules are most likely genuinely gone.
    # Marks intact does NOT mean nothing was wiped: 3006.102.x rebuilds spare the mangle
    # hook + routes and clobber the filter/nat base rules instead (field: RT-BE88U @1.5.18,
    # MASQUERADE gone → geo LAN one-way-dead for 3 h while this path kept skipping). The
    # skip therefore re-asserts the base rules inline — six -C probes when nothing is wrong,
    # a targeted re-add (no teardown, no blackhole window) when the firmware ate them.
    if [ "$1" = "fast" ]; then
        awg_marks_state
        case $? in
            0) heal_base_rules "firewall-start"; return 0 ;;
            2) sleep 1
               awg_marks_state && { heal_base_rules "firewall-start"; return 0; } ;;
        esac
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
    # (lan_net-scoped variant = pre-1.3.9 layout; drained for upgrades)
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
    # Unconditional masq — see do_start for why the lan_net-scoped variant broke
    # firmware-VPN-server clients (wgs1/OpenVPN subnets riding the default policy).
    iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE

    setup_firewall

    release_lock
    log_msg "Firewall/routes re-applied"
}

# --- Service event dispatcher ---

do_service_event(){
    local event="$2"
    # AWG-server role events (awgsrv*) are owned by amneziawg_server.sh — hand the whole
    # event over (the dispatcher hook line in /jffs/scripts/service-event matches ^awg, so
    # they all arrive here first). Kept out of the client ui_log_reset list below: the
    # server script resets ITS OWN on-page log.
    case "$event" in
        awgsrv*)
            [ -f "$AWGS_SCRIPT" ] && sh "$AWGS_SCRIPT" service_event "$1" "$2"
            return 0
            ;;
    esac
    case "$event" in
        awgstart|awgstop|awgrestart|awgswitch|awgswitch[1-9]|awgforceapply|awgsaveconf|awgupdategeo|awgdoupdate) ui_log_reset ;;
    esac
    case "$event" in
        # (awgupload / awgmanualinstall — the browser .ipk upload — are gone since 1.5.24: the
        # firmware discards any settings POST over 8 KB, so it never worked. See do_install_ipk.)
        awgstart)       do_start ;;
        awgstop)        do_stop user ;;
        awgrestart)     do_restart ;;
        awgswitch|awgswitch[1-9])
            # Manual profile switch. The page's POST stored the new awg_profile_active (plus any
            # pending edits) BEFORE the firmware fired this event (validate_apply writes the store,
            # THEN notify_rc), and since 1.5.26 the event names its target slot
            # (start_awgswitch<SLOT>). A switch whose save never reached the store — discarded by
            # the firmware's 8 KB cap, or overwritten by another page saving at the same moment —
            # is therefore REFUSED here instead of restarting whatever profile the store still
            # points at (the old settle-wait could not tell those cases apart, and a restart of
            # the CURRENT profile read to the user as "the switch worked"). Bare `awgswitch`
            # (older pages) restarts onto the stored pointer as before. The failover override +
            # circle are dropped by do_stop's `switch` token, under the lock.
            local _sw="${event#awgswitch}"
            if [ -n "$_sw" ]; then
                if ! profile_configured "$_sw"; then
                    log_msg "WARNING: switch target is not configured — nothing switched"
                    update_status
                    return 0
                fi
                if [ "$(profile_user)" != "$_sw" ]; then
                    log_msg "WARNING: the profile switch did not reach the router's settings store (another page saved at the same moment, or the firmware discarded the save) — nothing switched"
                    update_status
                    return 0
                fi
            else
                _sw=$(profile_user)
            fi
            profile_switch_restart "$_sw" ""
            ensure_geo   # download configured-but-missing geo lists (bg), then re-apply
            ;;
        awgpfsave)
            # The page saved the profile LIST (an immediate delete) — no tunnel change, no
            # journal reset; just refresh the status so the bar reflects the store.
            profile_info 1
            log_msg "Config profiles saved ($AWG_PI_COUNT configured)"
            update_status
            ;;
        awgforceapply)
            # Force Apply: persist settings, then full restart (re-runs setconf +
            # complete route/firewall/geo rebuild via do_start)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(pf_get iface_p1)" ]; do sleep 1; _wt=$((_wt+1)); done
            do_restart
            ensure_geo   # download configured-but-missing geo lists (bg), then re-apply
            ;;
        awgsaveconf)
            local _wt=0; while [ $_wt -lt 5 ] && [ -z "$(pf_get iface_p1)" ]; do sleep 1; _wt=$((_wt+1)); done
            # Apply WITHOUT a VPN restart, under the operation lock — taken BEFORE generate_config
            # now, so a start/stop/switch in flight can't have the conf regenerated under it —
            # and with the LAN deadman armed so a config that kills dnsmasq still rolls back
            # (same net as do_start).
            # While the tunnel runs, $CONF (and the awg0.addr/awg0.dns side-files) must keep
            # describing the RUNNING daemon: do_stop reads the endpoint route from it and
            # tunnel_dns_ips the resolver. So regenerate only when the effective profile is still
            # the one running — the Apply's edits then show as "pending restart" (conf_pending).
            # When it differs (a switch saved but its restart dropped, an override that stopped
            # matching) say so and apply only the firewall/policy side.
            if acquire_lock; then
                if is_running; then
                    local _rs="" _rx=""
                    [ -f "$RUNNING_PF" ] && { read -r _rs _rx < "$RUNNING_PF"; } 2>/dev/null
                    if [ -z "$_rs" ] || [ "$(profile_effective)" = "$_rs" ]; then
                        generate_config
                    else
                        log_msg "Profile saved but not applied yet — the tunnel still runs profile $(profile_desc "$_rs"); press «Перезапустить» (Restart) to switch"
                    fi
                    arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
                    setup_firewall
                else
                    generate_config
                fi
                release_lock
            else
                log_msg "Settings are saved, but applying them was skipped: another operation holds the lock — press «Применить» (Apply) again in a moment"
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
            # tells the UI the (possibly multi-second) dump has finished. Filtered as a STREAM at
            # this, its one web-served writer: the dump quotes syslog, dnsmasq output and user
            # settings, and an ASP-tag opener in a /www/user .htm livelocks httpd (see log_msg).
            do_diag 2>&1 | sed 's/<\([%#]\)/< \1/g' > "$DIAG_FILE"
            echo "[DIAG_DONE]" >> "$DIAG_FILE"
            ;;
        awganalyzestart) do_analyze_start ;;
        awganalyzestop)  do_analyze_stop ;;
        awgxraystop)     do_xray_stop ;;
        awgctfdisable)   do_ctf_disable ;;
    esac
}

# --- Main ---

# Library mode: amneziawg_server.sh (the AWG-server role) sources this file for the hardened
# shared helpers (launch_daemon, locks, waits, reload_dnsmasq, validate_*, …) and then
# overrides the instance globals (IFACE/LOCKDIR/UI_LOG/CONF/DAEMON_LOG/DAEMON_RC/…) for its
# own awgs0 instance. It must NOT run the client migrations or the dispatch below. `return`
# at top level is valid ONLY in a sourced script — the guard condition keeps normal
# executions (AWG_LIB_MODE unset) from ever reaching it.
[ -n "$AWG_LIB_MODE" ] && return 0

# Rename any pre-1.1.89 credential-flavored config keys to neutral names before any command
# reads them (cheap no-op once migrated), so existing installs keep working after upgrade.
migrate_field_names
# Normalize a space-separated watchdog-hosts value (pre-1.2.54 saves) to commas before the
# page can read a truncated copy back and re-save it without the tail hosts.
migrate_watchdog_hosts
# Same rescue for the AWG-server peer store (whitespace in a peer name cut the WHOLE store on
# the pages' read-back; chunks a pre-1.5.26 page sized by characters read back cut) and for raw
# spaced profile names (migrate_profile_names — its detection shares this one awk pass). Every
# server-page event passes through this dispatch first (awgsrv*).
migrate_server_peers

# Geo ipset name is configurable (so it can be shared with other connections/tools). Default
# awg_dst; sanitize to a valid ipset name (letters/digits/_.-, <=31 chars), else keep default.
_ipn=$(get_setting awg_ipset_name)
case "$_ipn" in ''|*[!A-Za-z0-9_.-]*) _ipn="" ;; esac
[ -n "$_ipn" ] && [ ${#_ipn} -le 31 ] && IPSET_NAME="$_ipn"

case "$1" in
    start)          do_start ;;
    boot_start)     do_boot_start ;;   # S99 init (boot/opkg): honors the awg_autostart toggle
    boot_guard)     do_boot_guard ;;   # services-start fallback: starts S99 if the Entware init never did
    stop)           do_stop user ;;
    stop_auto)      do_stop "" deadman ;;   # internal: auto-rollback stop (deadman); keeps watchdog cron
    restart)        do_restart ;;
    # Reap before refreshing: this is the ONLY path that runs every minute, so it is where a
    # wedged predecessor gets noticed. See reap_stale_status for what wedges and why.
    status)         reap_stale_status; update_status ;;
    diag|diagnostics) do_diag ;;
    update_geo)     update_geo_lists; do_firewall_restart; update_status ;;
    check_update)   check_update ;;
    update)         do_update "$2" ;;
    install_ipk)    do_install_ipk "$2" ;;
    watchdog)       do_watchdog ;;
    install_page)   do_install_page ;;
    mount_ui)       do_mount_ui ;;
    uninstall)      do_uninstall ;;
    service_event)  do_service_event "$2" "$3" ;;
    wan_event)      do_wan_event "$2" "$3" ;;
    firewall_restart) do_firewall_restart fast ;;
    apply_policies)
        # Re-apply device/peer policies WITHOUT a VPN restart — same guarded path the
        # awgsaveconf event uses. Called by amneziawg_server.sh when its peer list (or a
        # peer's policy) changes / on server start-stop, so setup_firewall re-reads
        # server_peer_policy_entries. No-op while the client tunnel is down.
        if is_running && acquire_lock; then
            arm_lan_deadman "$(pidof amneziawg-go 2>/dev/null | awk '{print $1}')"
            setup_firewall
            release_lock
        fi
        update_status
        ;;
    download_geo)   download_all_geo ;;
    ensure_geo)     ensure_geo ;;
    analyze_start)  do_analyze_start ;;
    analyze_stop)   do_analyze_stop ;;
    mem|memory)     do_mem_report ;;
    ctf_status)     ctf_active && echo "CTF active (ctf_disable=$(nvram get ctf_disable 2>/dev/null))" || echo "CTF not active" ;;
    ctf_disable)    do_ctf_disable ;;
    profile)
        # N = the N-th configured profile (the number the page and `profile list` show);
        # slot:S = the stable storage slot (for scripts — ordinals shift when a profile is deleted).
        case "$2" in
            ''|list)             profile_cli_list ;;
            next|[0-9]*|slot:*)  profile_cli_switch "$2" ;;
            *)                   echo "Usage: $0 profile [list|<N>|slot:<1-$AWG_PF_MAX>|next]" ;;
        esac
        ;;
    *)              echo "Usage: $0 {start|stop|restart|status|diag|mem|profile [list|N|slot:S|next]|update [version]|install_ipk <file.ipk>|update_geo|download_geo|install_page|uninstall}" ;;
esac
