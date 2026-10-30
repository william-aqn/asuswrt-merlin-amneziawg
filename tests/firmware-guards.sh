#!/bin/sh
# Run only in a disposable Linux container; see tests/README.md.
[ "${AWG_TEST_ISOLATED:-}" = 1 ] || { echo 'Run in a disposable container with AWG_TEST_ISOLATED=1' >&2; exit 2; }
# Container init (PID 1) reaps nothing and ignores default signals; run the suite as its child.
if [ "$$" -eq 1 ]; then
    sh "$0" "$@"
    exit $?
fi
SRC=${1:-/src}
W=/tmp/fw-guards
rm -rf "$W"; mkdir -p "$W"
cd "$W" || exit 1
extract(){
    awk -v name="$1" '$0 ~ "^" name "\\(\\)" {copy=1} copy {print} copy && /^[})]$/ {exit}' "$2"
}
: > functions.sh
for name in acquire_lock release_lock kill_tree run_bounded awg_new_id awg_gen_bump gen_current_is flag_clear_mine fw_dns_redirect_active fw_dns_redirect_name setup_ipv6_block; do
    extract "$name" "$SRC/addon/amneziawg.sh" >> functions.sh
    grep -q "^$name()" functions.sh || { echo "FAIL: cannot extract $name" >&2; exit 1; }
done
. ./functions.sh
log_msg(){ echo "$*" >> "$W/log"; }
awg_incident(){ echo "$*" >> "$W/incidents"; }
fail(){ echo "FAIL: $*" >&2; exit 1; }
pass(){ echo "PASS: $*"; }
is_live(){
    [ -r "/proc/$1/stat" ] || return 1
    read -r line < "/proc/$1/stat"
    line=${line##*) }
    case "$line" in Z\ *|X\ *) return 1 ;; *) return 0 ;; esac
}
no_capture_left(){
    set -- /tmp/.awg_rb.*
    [ ! -e "$1" ]
}

out=$(run_bounded 3 sh -c 'printf "%s\n" "$1"; exit 7' sh 'argument * with spaces')
rc=$?
[ "$rc" = 7 ] && [ "$out" = 'argument * with spaces' ] || fail "return code / stdout / arguments: $rc $out"
pass 'return code, stdout and literal arguments'

run_bounded 2 sh -c 'printf partial; sleep 30' > timeout.out
rc=$?
[ "$rc" = 124 ] && [ ! -s timeout.out ] || fail 'timeout must discard partial stdout and return 124'
[ -s log ] && [ -s incidents ] || fail 'timeout logging'
no_capture_left || fail 'timeout temp leaked'
pass 'timeout, empty response, logging and temp cleanup'

cat > nested.sh <<'NESTED'
#!/bin/sh
echo $$ >> /tmp/fw-guards/pids
if [ "$1" -gt 0 ]; then
    sh /tmp/fw-guards/nested.sh $(($1 - 1)) &
else
    sleep 30 &
    echo $! >> /tmp/fw-guards/pids
fi
wait
NESTED
run_bounded 2 sh ./nested.sh 2 >/dev/null
[ "$?" = 124 ] || fail 'tree timeout'
for p in $(cat pids); do is_live "$p" && fail "live descendant: $p"; done
pass 'three generations of child processes removed'

for n in 1 2 3 4 5 6 7 8; do
    (run_bounded 3 sh -c 'usleep 50000; echo "$1"' sh "$n" > "sibling.$n") &
done
wait
for n in 1 2 3 4 5 6 7 8; do [ "$(cat "sibling.$n")" = "$n" ] || fail "sibling $n"; done
no_capture_left || fail 'sibling temp leaked'
pass 'concurrent sibling calls keep independent output'

(
    mktemp(){ return 1; }
    run_bounded 1 echo forbidden > unavailable
    [ "$?" = 124 ] && [ ! -s unavailable ] || fail 'mktemp failure'
) || exit 1
pass 'unavailable temporary storage returns 124'

# Cancellation hits the supervisor itself. Its traps must clean children and the capture;
# the enclosing shell's own EXIT handler must stay intact.
cat > cancelled.sh <<'CANCEL'
#!/bin/sh
. /tmp/fw-guards/functions.sh
log_msg(){ :; }
awg_incident(){ :; }
trap 'echo parent > /tmp/fw-guards/parent-trap' EXIT
run_bounded 2 sh -c 'echo "$PPID" > /tmp/fw-guards/supervisor; echo $$ > /tmp/fw-guards/cancel-child; sleep 30'
CANCEL
sh ./cancelled.sh & caller=$!
while [ ! -s supervisor ] || [ ! -s cancel-child ]; do usleep 10000; done
kill -TERM "$(cat supervisor)"
wait "$caller" 2>/dev/null
[ "$?" = 143 ] || fail 'cancelled supervisor exit code'
is_live "$(cat cancel-child)" && fail 'cancelled child survived'
[ "$(cat parent-trap)" = parent ] || fail 'caller trap overwritten'
no_capture_left || fail 'cancelled capture leaked'
pass 'cancellation cleans descendants/capture and preserves caller trap'

(
    pidof(){ return 1; }
    nv(){ [ "$2" = "$unreadable" ] && return 124; echo "$value"; }
    value=0; unreadable=''
    fw_dns_redirect_active && fail 'disabled owner reported active'
    [ -z "$(fw_dns_redirect_name)" ] || fail 'disabled owner named'
    for unreadable in dnsfilter_enable_x dns_director_enable dnspriv_enable; do
        fw_dns_redirect_active || fail "unknown owner $unreadable must be active"
        case "$(fw_dns_redirect_name)" in "unknown DNS owner (nvram get $unreadable timed out)") ;; *) fail 'unknown owner name' ;; esac
    done
    unreadable=''; value=1
    fw_dns_redirect_active || fail 'enabled owner inactive'
    case "$(fw_dns_redirect_name)" in 'firmware DNSFilter '*) ;; *) fail 'enabled owner name' ;; esac
) || exit 1
pass 'DNS owner timeouts fail safe for each flag'

(
    nv(){ printf '%s' "$value"; return "$result"; }
    ip6tables(){ echo "$*" >> ip6; [ "$1" != -C ]; }
    IFACE=awg0
    value=disabled; result=0; : > ip6
    setup_ipv6_block
    [ ! -s ip6 ] || fail 'confirmed-disabled IPv6 modified'
    value=''; result=0
    setup_ipv6_block
    [ ! -s ip6 ] || fail 'confirmed-unset IPv6 modified'
    value=''; result=124
    setup_ipv6_block
    [ "$(grep -c '^-I' ip6)" = 2 ] || fail 'timeout missing IPv6 rejects'
) || exit 1
pass 'IPv6 timeout installs both rejects'

# Complete Stop and Watchdog bodies with every router effect mocked and every cron call timing out.
for role in client server; do
    (
        LOCKDIR="$W/$role-lock"
        STARTING_FLAG=$W/starting
        STOPPING_FLAG=$W/stopping
        PF_OVERRIDE=$W/profile
        FAILOVER_STATE=$W/failover
        RUNNING_CONF_SIG=$W/conf-sig
        RUNNING_PF=$W/running-pf
        DNSRELOAD_SIG=$W/dns-sig
        IFACE=fwguard0
        RT_TABLE=300
        for name in do_analyze_stop update_status srv_update_status conn_record_stop ipt_drain cleanup_ipv6_block get_lan_net cleanup_firewall get_endpoint restore_rp_filter reload_dnsmasq srv_cleanup_firewall wait_for_pid_exit reap_stale_dnsreload ip pidof; do
            eval "$name(){ :; }"
        done
        file_older_than(){ return 1; }
        awg_cru(){ return 124; }
        : > log
        if [ "$role" = client ]; then
            extract do_stop "$SRC/addon/amneziawg.sh" > lifecycle.sh
            extract do_watchdog "$SRC/addon/amneziawg.sh" >> lifecycle.sh
            . ./lifecycle.sh
            do_start(){ fail 'watchdog restarted deliberately stopped client'; }
            do_restart(){ fail 'watchdog restarted deliberately stopped client'; }
            do_stop user || fail 'client Stop'
            [ -f "${LOCKDIR}.stopped" ] || fail 'client stop intent absent'
            do_watchdog || fail 'stopped client watchdog'
        else
            extract do_srv_stop "$SRC/addon/amneziawg_server.sh" > lifecycle.sh
            extract do_srv_watchdog "$SRC/addon/amneziawg_server.sh" >> lifecycle.sh
            . ./lifecycle.sh
            do_srv_start(){ fail 'watchdog restarted deliberately stopped server'; }
            do_srv_stop user || fail 'server Stop'
            [ -f "${LOCKDIR}.stopped" ] || fail 'server stop intent absent'
            do_srv_watchdog || fail 'stopped server watchdog'
        fi
        grep -q 'watchdog cron removal failed' log || fail "$role cron failure not logged"
        [ ! -d "$LOCKDIR" ] || fail 'Stop retained operation lock'
    ) || exit 1
done
pass 'client/server Stop survives cron timeout; watchdog cannot restart either role'

# A stop that cannot record the user's intent must change nothing.
(
    LOCKDIR="$W/readonly/lock"
    mkdir -p "$W/readonly"
    touch(){ return 1; }
    awg_gen_bump(){ fail 'unrecorded Stop went on'; }
    extract do_stop "$SRC/addon/amneziawg.sh" > lifecycle.sh
    . ./lifecycle.sh
    do_stop user && fail 'unrecorded Stop reported success'
    [ ! -d "$LOCKDIR" ] || fail 'unrecorded Stop retained lock'
) || exit 1
pass 'Stop aborts before any teardown when the intent flag cannot be written'

# An already-running watchdog can reach Start after Stop won the lock. Start must re-check the
# intent under the lock; a subsequent explicit Start clears it.
for role in client server; do
    (
        LOCKDIR="$W/$role-start-lock"
        STARTING_FLAG=$W/start-flag
        IFACE=fwguard0
        update_status(){ :; }
        srv_update_status(){ :; }
        ctf_active(){ return 1; }
        get_setting(){ :; }
        ip(){ echo 'inet 192.0.2.1'; }
        is_running(){ calls=$((calls + 1)); [ "$calls" -gt 1 ]; }
        if [ "$role" = client ]; then
            extract do_start "$SRC/addon/amneziawg.sh" > start.sh
            start_fn=do_start
        else
            extract do_srv_start "$SRC/addon/amneziawg_server.sh" > start.sh
            start_fn=do_srv_start
        fi
        . ./start.sh
        touch "${LOCKDIR}.stopped"
        calls=0; AWG_WATCHDOG=1
        "$start_fn" || fail 'in-flight watchdog Start'
        [ -f "${LOCKDIR}.stopped" ] || fail 'in-flight watchdog cleared Stop'
        [ ! -d "$LOCKDIR" ] || fail 'in-flight watchdog retained lock'
        calls=0; AWG_WATCHDOG=0
        "$start_fn" || fail 'explicit Start'
        [ ! -f "${LOCKDIR}.stopped" ] || fail 'explicit Start retained Stop'
        [ ! -d "$LOCKDIR" ] || fail 'explicit Start retained lock'
    ) || exit 1
done
pass 'in-flight watchdog honors Stop under lock; explicit Start clears it for both roles'

# The nested rc_service settling function with slow, unavailable reads.
awk '/^        _rc_settle\(\)/{copy=1} copy{print} copy && /^        }$/{exit}' "$SRC/addon/amneziawg.sh" > settle.sh
grep -q '_rc_settle()' settle.sh || fail 'cannot extract _rc_settle'
. ./settle.sh
(
    _beat(){ :; }
    nv(){ sleep 2; return 124; }
    dnsreload_deferred(){ return 1; }
    _rcbudget=3
    read -r up rest < /proc/uptime; start=${up%%.*}
    _rc_settle
    read -r up rest < /proc/uptime; elapsed=$((${up%%.*} - start))
    [ "$_rcbudget" -le 0 ] && [ "$elapsed" -le 5 ] || fail "settle budget: $_rcbudget elapsed=$elapsed"
) || exit 1
(
    _beat(){ :; }
    nv(){ return 124; }
    dnsreload_deferred(){ return 1; }
    _rcbudget=2
    _rc_settle
    [ "$_rcbudget" -le 0 ] || fail 'timed-out read treated as idle'
) || exit 1
(
    _beat(){ :; }
    nv(){ :; }
    dnsreload_deferred(){ return 1; }
    _rcbudget=5
    _rc_settle
    [ "$_rcbudget" = 5 ] || fail 'idle rc_service waited'
) || exit 1
pass 'rc_service timeout is busy and consumes elapsed seconds'
echo 'All firmware guard checks passed.'
