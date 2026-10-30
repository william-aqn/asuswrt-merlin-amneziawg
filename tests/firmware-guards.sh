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
for name in lock_transition proc_start_time lock_age_s acquire_lock _acquire_lock_once release_lock _release_lock _reclaim_wedged_lock operation_lock_busy _operation_lock_busy file_age_s file_older_than kill_tree run_bounded awg_new_id awg_gen_bump gen_current_is flag_clear_mine fw_dns_redirect_active fw_dns_redirect_name setup_ipv6_block; do
    extract "$name" "$SRC/addon/amneziawg.sh" >> functions.sh
    grep -q "^$name()" functions.sh || { echo "FAIL: cannot extract $name" >&2; exit 1; }
done
. ./functions.sh
RUN_BOUNDED_TMP=/tmp/.awg_rb
LOCK_STALE_S=1800
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
    mktemp(){ echo used > "$W/mktemp-used"; return 1; }
    [ "$(run_bounded 1 echo ok)" = ok ] || fail 'capture without mktemp'
    [ ! -e "$W/mktemp-used" ] || fail 'run_bounded depends on mktemp'
    RUN_BOUNDED_TMP=$W/missing/rb
    : > log
    run_bounded 1 echo forbidden > unavailable
    [ "$?" = 124 ] && [ ! -s unavailable ] || fail 'unwritable capture'
    grep -q "^WARNING: cannot create $W/missing/rb\." log || fail 'unwritable capture not logged'
) || exit 1
pass 'capture needs no mktemp; unavailable temporary storage returns 124'

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

# A separate process holding LOCKDIR (plus one child), never this shell: a reaper aimed at $$
# would kill the suite itself and hide the failure.
cat > holder.sh <<HOLDER
#!/bin/sh
. $W/functions.sh
log_msg(){ :; }
LOCKDIR=\$1
acquire_lock || exit 1
sh -c 'echo \$\$ > $W/holder-child; exec sleep 30' &
echo ready > $W/holder-ready
wait
HOLDER
start_holder(){
    rm -f "$W/holder-ready" "$W/holder-child"
    sh "$W/holder.sh" "$1" & holder=$!
    while [ ! -f "$W/holder-ready" ] || [ ! -s "$W/holder-child" ]; do
        is_live "$holder" || fail 'lock holder fixture died'
        usleep 10000
    done
}
stop_holder(){ kill_tree "$holder"; wait "$holder" 2>/dev/null; }

LOCKDIR=$W/lock
acquire_lock || fail 'initial lock'
read -r owner_pid owner_start owner_since < "$LOCKDIR/owner"
[ "$owner_pid" = "$$" ] || fail 'wrong owner pid'
[ "$owner_start" = "$(proc_start_time "$$")" ] || fail 'wrong process identity'
lock_transition _reclaim_wedged_lock "$$" test && fail 'fresh lock reclaimed'
[ -d "$LOCKDIR" ] || fail 'fresh lock missing'
# A long-lived downloading process: its actual age is irrelevant to this just-acquired lock;
# the persisted acquisition uptime controls the decision.
(
    proc_age_s(){ echo 1900; }
    lock_transition _reclaim_wedged_lock "$$" test && fail 'process age used as lock age'
    exit 0
) || exit 1
release_lock || fail 'release own lock'
[ ! -d "$LOCKDIR" ] || fail 'own lock not released'
pass 'owner identity and acquisition time are recorded; fresh lock survives'

# A recycled numeric PID must not cause ANY signal to the new process.
acquire_lock || fail 'recycled-PID fixture'
printf '%s %s 0\n' "$$" 1 > "$LOCKDIR/owner"
(
    kill_tree(){ fail 'signalled reused PID'; }
    lock_transition _reclaim_wedged_lock "$$" test || fail 'recycled-PID stale lock not retired'
) || exit 1
[ ! -d "$LOCKDIR" ] || fail 'recycled-PID stale lock retained'
pass 'reused PID retires stale lock without signalling the new process'

# Legacy PID-only records do not authorize signals to an unidentified live owner.
sleep 30 & legacy=$!
mkdir "$LOCKDIR"; echo "$legacy" > "$LOCKDIR/pid"
(
    LOCK_STALE_S=-1
    lock_transition _reclaim_wedged_lock "$legacy" test && fail 'legacy live owner reaped'
    operation_lock_busy test || fail 'legacy live owner treated as free'
    exit 0
) || exit 1
is_live "$legacy" || fail 'legacy owner signalled'
[ -d "$LOCKDIR" ] || fail 'legacy lock removed'
kill "$legacy"; wait "$legacy" 2>/dev/null
rm -rf "$LOCKDIR"
pass 'live legacy PID-only owner is preserved'

# Dead and pidless locks: the watchdog's busy-gate semantics.
mkdir "$LOCKDIR"
operation_lock_busy WATCHDOG || fail 'young pidless lock treated as free'
(
    file_older_than(){ return 0; }
    operation_lock_busy WATCHDOG && fail 'old pidless lock kept'
    exit 0
) || exit 1
[ ! -d "$LOCKDIR" ] || fail 'old pidless lock retained'
sh -c 'exit 0' & dead=$!; wait "$dead"
mkdir "$LOCKDIR"; echo "$dead" > "$LOCKDIR/pid"
: > log
operation_lock_busy WATCHDOG && fail 'dead holder treated as busy'
[ ! -d "$LOCKDIR" ] || fail 'dead holder lock retained'
grep -q "^WATCHDOG: stale operation lock $LOCKDIR (holder $dead is gone)" log || fail 'dead holder reclaim not logged'
pass 'dead holder reclaimed; young pidless lock is busy, old one reclaimed'

# A wedged live holder (and its children) is killed once its lock is older than LOCK_STALE_S.
start_holder "$LOCKDIR"
: > log; : > incidents
operation_lock_busy WATCHDOG || fail 'fresh live holder treated as free'
(
    LOCK_STALE_S=-1
    operation_lock_busy WATCHDOG && fail 'wedged holder kept the lock'
    exit 0
) || exit 1
wait "$holder" 2>/dev/null
is_live "$holder" && fail 'wedged holder survived'
is_live "$(cat holder-child)" && fail 'wedged holder child survived'
[ ! -d "$LOCKDIR" ] || fail 'wedged lock retained'
grep -q "^WATCHDOG: operation lock held by pid $holder " log || fail 'wedged reclaim not logged'
grep -q "pid $holder" incidents || fail 'wedged reclaim not recorded'
pass 'wedged live holder and descendants killed, lock reclaimed'

# Force the original race with two reclaimers and a competing acquire. All three
# directory mutations must share the guard; only the original generation is removed.
rm -f new-owner
start_holder "$LOCKDIR"
read -r p st since < "$LOCKDIR/owner"
printf '%s %s 0\n' "$p" "$st" > "$LOCKDIR/owner"
(
    LOCK_STALE_S=-1
    kill_tree(){ sleep 1; kill -9 "$1"; }
    lock_transition _reclaim_wedged_lock "$holder" first
) & first=$!
usleep 100000
( LOCK_STALE_S=-1; lock_transition _reclaim_wedged_lock "$holder" second ) & second=$!
(
    acquire_lock || exit 1
    echo "$AWG_LOCK_PID" > "$W/new-owner"
    sleep 1
    [ "$(cat "$LOCKDIR/pid")" = "$AWG_LOCK_PID" ] || exit 1
    release_lock
) & fresh=$!
wait "$first" || fail 'first reclaim'
wait "$second" 2>/dev/null
wait "$fresh" || fail 'new lock lost during competing reclaim'
stop_holder
[ -s new-owner ] || fail 'new acquisition never finished'
pass 'concurrent reclaim/acquire preserves new ownership'

# A held transition guard means the watchdog must stand down, and a killed guard
# holder must release its kernel lock without manual filesystem cleanup.
rm -f guard-ready
(
    flock -x 9 || exit 1
    echo ready > "$W/guard-ready"
    sleep 30
) 9>"${LOCKDIR}.guard" & guard=$!
while [ ! -f guard-ready ]; do usleep 10000; done
operation_lock_busy test || fail 'contended guard treated as idle'
kill_tree "$guard"; wait "$guard" 2>/dev/null
acquire_lock || fail 'guard stayed locked after process death'
release_lock || fail 'guard recovery release'
pass 'guard contention fails safe and kernel releases dead holder'

# Missing optional flock preserves ordinary operation but disables forced live reap.
start_holder "$LOCKDIR"
(
    which(){ return 1; }
    LOCK_STALE_S=-1
    lock_transition _reclaim_wedged_lock "$holder" test && fail 'unsafe reap without flock'
    operation_lock_busy test || fail 'live holder free without flock'
    exit 0
) || exit 1
is_live "$holder" || fail 'holder signalled without flock'
stop_holder
rm -rf "$LOCKDIR"
(
    which(){ return 1; }
    acquire_lock || fail 'lock without flock'
    release_lock || fail 'unlock without flock'
    [ ! -d "$LOCKDIR" ] || fail 'lock retained without flock'
) || exit 1
pass 'legacy firmware without flock keeps normal acquire/release'

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

# The watchdog reconcile drops our :53 DNAT (and tunnel DNS with it) only for a confirmed owner.
(
    LOCKDIR="$W/reconcile-lock"
    IFACE=fwguard0
    AWG_BIN=true
    extract do_watchdog "$SRC/addon/amneziawg.sh" > watchdog.sh
    . ./watchdog.sh
    reap_stale_dnsreload(){ :; }
    file_older_than(){ return 1; }
    is_running(){ return 0; }
    dns_intercept_active(){ return 0; }
    zapret_active(){ return 1; }
    get_setting(){ :; }
    pidof(){ return 1; }
    disable_tunnel_dns(){ echo tunnel-dns >> "$W/reconcile"; }
    cleanup_dns_interception(){ echo dnat >> "$W/reconcile"; }
    iface_exists(){ return 1; }
    do_stop(){ return 1; }
    nv(){ case "$mode" in unread) return 124 ;; owner) echo 1 ;; *) echo 0 ;; esac; }
    for mode in unread none owner; do
        rm -f "$W/reconcile" /tmp/.awg_wd_state
        do_watchdog
        case "$mode" in
            owner) [ "$(cat "$W/reconcile" 2>/dev/null)" = "tunnel-dns
dnat" ] || fail 'confirmed owner kept our interception' ;;
            *) [ ! -e "$W/reconcile" ] || fail "reconcile dropped interception on $mode flags" ;;
        esac
    done
    rm -f /tmp/.awg_wd_state
) || exit 1
pass 'watchdog reconcile ignores unread DNS flags and acts on a confirmed owner'

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
            rm -f /tmp/.awg_wd_state
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

# Both watchdogs stand down behind a live operation and take over from a wedged one.
for role in client server; do
    LOCKDIR="$W/$role-busy-lock"
    start_holder "$LOCKDIR"
    (
        IFACE=fwguard0
        AWG_BIN=true
        for name in reap_stale_dnsreload wait_for_pid_exit; do eval "$name(){ :; }"; done
        is_running(){ return 1; }
        iface_exists(){ return 1; }
        if [ "$role" = client ]; then
            extract do_watchdog "$SRC/addon/amneziawg.sh" > busy.sh
            . ./busy.sh
            do_stop(){ echo restart >> "$W/busy-restart"; return 1; }
            run(){ rm -f /tmp/.awg_wd_state; do_watchdog; }
        else
            extract do_srv_watchdog "$SRC/addon/amneziawg_server.sh" > busy.sh
            . ./busy.sh
            do_srv_stop(){ :; }
            do_srv_start(){ echo restart >> "$W/busy-restart"; }
            run(){ do_srv_watchdog; }
        fi
        rm -f "$W/busy-restart"
        run
        [ ! -e "$W/busy-restart" ] || fail "$role watchdog restarted behind a live operation"
        is_live "$holder" || fail "$role watchdog killed a live operation"
        LOCK_STALE_S=-1
        run
        [ -s "$W/busy-restart" ] || fail "$role watchdog did not take over from a wedged operation"
        is_live "$holder" && fail "$role wedged operation survived"
        rm -f /tmp/.awg_wd_state
        exit 0
    ) || exit 1
    stop_holder
done
pass 'both watchdogs stand down behind a live operation and reclaim a wedged one'

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
