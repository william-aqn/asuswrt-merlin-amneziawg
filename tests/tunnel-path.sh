#!/bin/sh
# Изолированные регрессии «подключено, но ничего не открывается» (1.5.30): sh tests/tunnel-path.sh
# BusyBox: TEST_SHELL='busybox ash' busybox ash tests/tunnel-path.sh
# Функции извлекаются из рабочего скрипта; iptables, ipset, ping, curl и DNS подменены —
# роутер и сеть не нужны. Вне каталога теста пишется только рабочий каталог проб
# /tmp/.awg_diagprobe.<pid> (его создаёт и убирает сама проверяемая функция).
set -eu
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SRC=${TEST_SOURCE:-"$REPO/addon/amneziawg.sh"}
TEST_SHELL=${TEST_SHELL:-sh}
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
trap 'exit 1' HUP INT TERM
export TEST_TMP

fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_eq(){ [ "$1" = "$2" ] || fail "$3: expected [$2], got [$1]"; }
assert_has(){ case "$1" in *"$2"*) ;; *) fail "$3: [$2] not found in: $1" ;; esac; }
assert_not(){ case "$1" in *"$2"*) fail "$3: unexpected [$2] in: $1" ;; esac; }
extract(){ sed -n "/^$1(){/,/^}/p" "$SRC"; }
lib(){ : > "$TEST_TMP/lib.sh"; for _f in "$@"; do extract "$_f" >> "$TEST_TMP/lib.sh"; grep -q "^$_f(){" "$TEST_TMP/lib.sh" || fail "function $_f not found in the script"; done; }
run_case(){ $TEST_SHELL "$TEST_TMP/case.sh" > "$TEST_TMP/result" 2> "$TEST_TMP/errors" || { cat "$TEST_TMP/result" "$TEST_TMP/errors" >&2; fail "case exited ($1)"; }; }

# ---------------------------------------------------------------------------------------------
# 1. MSS для ответов из туннеля: явное значение вместо clamp-to-pmtu, миграция и дренаж.
# ---------------------------------------------------------------------------------------------
lib ipt_drain ipt_add_once tun_link_mtu tcpmss_in_values tcpmss_in_recorded tcpmss_in_drain tcpmss_in_assert _heal_tcpmss_in
cat > "$TEST_TMP/ipt-mock.sh" <<'EOF'
# Rule store: one "<table> <chain> <rule tokens>" per line. -C answers like the real thing
# (0 present, 1 absent) or with SICK's code (a lock blip / a sick binary).
STORE="$TEST_TMP/rules"; : > "$STORE"
IFACE=awg0
TCPMSS_IN_STATE="$TEST_TMP/mss_in"; rm -f "$TCPMSS_IN_STATE"
iptables(){
    _tbl=filter
    if [ "$1" = -t ]; then _tbl=$2; shift 2; fi
    _op=$1; _ch=$2; shift 2
    _key="$_tbl $_ch $*"
    case "$_op" in
        -C) if [ -n "${SICK:-}" ]; then return "$SICK"; fi
            grep -qxF -- "$_key" "$STORE" ;;
        -A|-I) echo "$_key" >> "$STORE" ;;
        -D) grep -qxF -- "$_key" "$STORE" || return 1
            awk -v k="$_key" '!d && $0 == k { d = 1; next } { print }' "$STORE" > "$STORE.n" && mv "$STORE.n" "$STORE" ;;
    esac
}
# What `iptables -t mangle -S` prints: -A lines, with the implicit "-m tcp" the real tool adds.
mangle_dump(){ sed -n 's/^mangle \([A-Z]*\) \(.*\)$/-A \1 \2/p' "$STORE" | sed 's/-p tcp --tcp-flags/-p tcp -m tcp --tcp-flags/'; }
tun_link_mtu(){ [ -n "${MTU:-}" ] || return 1; echo "$MTU"; }
log_msg(){ echo "LOG: $*"; }
sleep(){ :; }
IN="mangle FORWARD -i awg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS"
OUT="mangle FORWARD -o awg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"
count(){ grep -cxF -- "$1" "$STORE" || true; }
rec(){ cat "$TCPMSS_IN_STATE" 2>/dev/null || echo none; }
EOF
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/ipt-mock.sh"
echo "$OUT" >> "$STORE"
MTU=1380
tcpmss_in_assert; tcpmss_in_assert
echo "fresh=$(count "$IN --set-mss 1340") legacy=$(count "$IN --clamp-mss-to-pmtu") out=$(count "$OUT") rec=$(rec)"
# An upgrade in place leaves the pmtu form; a user has a LOWER clamp of the same shape of their own.
echo "$IN --clamp-mss-to-pmtu" >> "$STORE"; echo "$IN --set-mss 1200" >> "$STORE"
tcpmss_in_assert
echo "migrated=$(count "$IN --set-mss 1340") legacy=$(count "$IN --clamp-mss-to-pmtu") user=$(count "$IN --set-mss 1200")"
# The profile MTU changed across a restart: our old value goes, the new one comes, the user's stays.
MTU=1280; tcpmss_in_assert
echo "mtu_change new=$(count "$IN --set-mss 1240") old=$(count "$IN --set-mss 1340") user=$(count "$IN --set-mss 1200") rec=$(rec)"
# The server role's rules are not ours to touch either.
echo "mangle FORWARD -i awgs0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1300" >> "$STORE"
tcpmss_in_drain
echo "drained ours=$(count "$IN --set-mss 1240") user=$(count "$IN --set-mss 1200") out=$(count "$OUT") server=$(grep -c -- '-i awgs0 ' "$STORE" || true) rec=$(rec)"
# No readable link MTU: the direction is not left bare.
MTU=""; tcpmss_in_assert
echo "nomtu_legacy=$(count "$IN --clamp-mss-to-pmtu")"
# A drain with the link already gone still removes the value we recorded.
MTU=1380; tcpmss_in_assert; MTU=""; tcpmss_in_drain
echo "drained_nolink=$(count "$IN --set-mss 1340") legacy=$(count "$IN --clamp-mss-to-pmtu")"
# A -C probe that stays sick (xtables lock): the listing is the second opinion — the rule is
# added once, and not a second time while the probe is still sick.
MTU=1380; SICK=4
tcpmss_in_assert; echo "sick_first rc=$? rules=$(count "$IN --set-mss 1340") rec=$(rec)"
tcpmss_in_assert; echo "sick_again rc=$? rules=$(count "$IN --set-mss 1340")"
EOF
run_case mss-assert
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'fresh=1 legacy=0 out=1 rec=1340' 'assert adds exactly one explicit rule and records its value'
assert_has "$R" 'migrated=1 legacy=0 user=1' 'assert replaces the pmtu form and leaves a foreign clamp alone'
assert_has "$R" 'mtu_change new=1 old=0 user=1 rec=1240' 'an MTU change swaps our rule only'
assert_has "$R" 'drained ours=0 user=1 out=1 server=1 rec=none' 'drain removes only our inbound rule'
assert_has "$R" 'nomtu_legacy=1' 'no link MTU keeps the legacy form'
assert_has "$R" 'drained_nolink=0 legacy=0' 'drain without a link uses the recorded value'
assert_has "$R" 'sick_first rc=0 rules=1 rec=1340' 'a sick probe at start does not leave the direction bare'
assert_has "$R" 'sick_again rc=0 rules=1' 'a sick probe never adds a duplicate'
echo 'PASS: inbound MSS rule — explicit value, idempotent, migration, foreign clamps, sick probe'

cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/ipt-mock.sh"
MTU=1280
heal(){ AWG_BASE_MISSING=""; AWG_BASE_SICK=""; _heal_tcpmss_in; echo "$1 rc=$? missing=[$AWG_BASE_MISSING] sick=[$AWG_BASE_SICK] new=$(count "$IN --set-mss 1240") legacy=$(count "$IN --clamp-mss-to-pmtu")"; }
heal wiped
heal intact
: > "$STORE"; echo "$IN --clamp-mss-to-pmtu" >> "$STORE"
heal migrate
: > "$STORE"; SICK=4
heal sick
SICK=""; MTU=""
heal nolink
EOF
run_case mss-heal
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'wiped rc=0 missing=[TCPMSS clamp in] sick=[] new=1 legacy=0' 'a wiped rule is re-added and reported'
assert_has "$R" 'intact rc=0 missing=[] sick=[] new=1 legacy=0' 'an intact rule is left alone'
assert_has "$R" 'migrate rc=0 missing=[] sick=[] new=1 legacy=0' 'the pmtu form migrates without a wipe report'
assert_has "$R" 'sick rc=1 missing=[] sick=[1] new=0 legacy=0' 'the heal adds nothing on a sick probe'
assert_has "$R" 'nolink rc=0 missing=[] sick=[] new=0 legacy=0' 'no link, nothing asserted'
echo 'PASS: inbound MSS rule — heal (wipe, migration, sick probe)'

# ---------------------------------------------------------------------------------------------
# 2. Бюджет MTU относительно WAN.
# ---------------------------------------------------------------------------------------------
lib tun_overhead mtu_budget mtu_budget_warn
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
CONF="$TEST_TMP/awg0.conf"
tun_link_mtu(){ echo "$MTU"; }
wan_egress(){ [ -n "$WAN" ] || return 1; echo "$WAN"; }
log_msg(){ echo "LOG: $*"; }
printf '[Interface]\nS3 = 54\nS4 = 18\n[Peer]\nEndpoint = 203.0.113.9:51820\n' > "$CONF"
MTU=1380; WAN="eth0 1500"; echo "a: $(tun_overhead) | $(mtu_budget)"; mtu_budget_warn
WAN="ppp0 1452"; echo "b: $(mtu_budget)"; mtu_budget_warn
WAN=""; mtu_budget >/dev/null && echo "c: known" || echo "c: unknown"; mtu_budget_warn
printf '[Peer]\nEndpoint = [2001:db8::1]:51820\n' > "$CONF"
echo "d: $(tun_overhead)"
printf '[Interface]\nS4 = abc\n' > "$CONF"
echo "e: $(tun_overhead)"
printf '[Interface]\nS4 = 08\n' > "$CONF"
echo "f: $(tun_overhead)"
printf '[Interface]\nS4 = 010\n' > "$CONF"
echo "g: $(tun_overhead)"
EOF
run_case mtu-budget
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'a: 78 | 1380 78 eth0 1500 fits' 'S4 counted, fits a 1500 link'
assert_has "$R" 'b: 1380 78 ppp0 1452 over:6' 'over a smaller WAN link'
assert_has "$R" 'Set the profile MTU to 1374 or lower' 'the warning names the MTU that fits'
assert_eq "$(grep -c '^LOG:' "$TEST_TMP/result")" 1 'warn only when over'
assert_has "$R" 'c: unknown' 'unknown WAN is not a verdict'
assert_has "$R" 'd: 80' 'IPv6 endpoint adds 20'
assert_has "$R" 'e: 60' 'a non-numeric S4 counts as 0'
assert_has "$R" 'f: 68' 'S4 with a leading zero is decimal 8, not a bad octal'
assert_has "$R" 'g: 70' 'S4 = 010 is ten'
assert_eq "$(cat "$TEST_TMP/errors")" '' 'no arithmetic errors'
echo 'PASS: MTU budget — overhead, fit, warning'

if [ -r /sys/class/net/lo/mtu ]; then
    lib wan_egress
    cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
ip(){ printf '10.0.0.0/24 dev br0 scope link\ndefault via 10.64.0.1 dev lo \n'; }
wan_egress
ip(){ printf 'default \n\tnexthop via 10.0.0.1 dev eth0 weight 1\n'; }
wan_egress || echo multipath-unknown
EOF
    run_case wan-egress
    R=$(cat "$TEST_TMP/result")
    assert_has "$R" "lo $(cat /sys/class/net/lo/mtu)" 'default route device and its MTU'
    assert_has "$R" 'multipath-unknown' 'a multipath default is reported as unknown'
    echo 'PASS: WAN egress device'
else
    echo 'SKIP: WAN egress device (no /sys/class/net here)'
fi

# ---------------------------------------------------------------------------------------------
# 3. Health-check: HTTPS-проба до вердикта «только рукопожатие»; состояние проб.
# ---------------------------------------------------------------------------------------------
lib hc_probe_round tunnel_alive probe_state_write probe_state_note
cat > "$TEST_TMP/hc-mock.sh" <<'EOF'
PROBE_STATE="$TEST_TMP/probe_state"; rm -f "$PROBE_STATE"
TCPN=0
ping_hosts_once(){ [ "$PING" = ok ]; }
tunnel_tcp_alive(){ TCPN=$((TCPN + 1)); [ "$TCP" = ok ]; }
tunnel_handshake_fresh(){ [ "$HS" = fresh ]; }
watchdog_hosts(){ echo "8.8.8.8 1.1.1.1"; }
log_msg(){ echo "LOG: $*"; }
sleep(){ :; }
rounds(){ _r=0; _o=""; while [ "$_r" -le "$1" ]; do hc_probe_round "$_r" || true; _o="$_o$_r:${HC_PASS:--} "; _r=$((_r + 1)); done; echo "$_o| tcp probes: $TCPN, HC_TCP=$HC_TCP"; }
EOF
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/hc-mock.sh"
# The field case: pings unanswered, handshake fresh, HTTPS dead too.
PING=no; HS=fresh; TCP=no; HC_TCP=""; TCPN=0; echo "A $(rounds 4)"
# A provider that filters ICMP only.
PING=no; HS=fresh; TCP=ok; HC_TCP=""; TCPN=0; echo "B $(rounds 6)"
# No handshake at all: the HTTPS probe keeps its old slots (rounds 5 and 15).
PING=no; HS=none; TCP=no; HC_TCP=""; TCPN=0; echo "C $(rounds 16)"
PING=ok; HS=fresh; TCP=ok; HC_TCP=""; TCPN=0; echo "D $(rounds 2)"
EOF
run_case hc-rounds
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'A 0:- 1:- 2:- 3:handshake 4:handshake | tcp probes: 1, HC_TCP=fail' 'HTTPS is tried once before a handshake-only verdict'
assert_has "$R" 'B 0:- 1:- 2:- 3:tcp 4:tcp 5:tcp 6:tcp | tcp probes: 1, HC_TCP=ok' 'ICMP-filtered tunnel is verified by HTTPS, once'
assert_has "$R" 'C 0:- 1:- 2:- 3:- 4:- 5:- 6:- 7:- 8:- 9:- 10:- 11:- 12:- 13:- 14:- 15:- 16:- | tcp probes: 2' 'a dead tunnel never passes and probes HTTPS at rounds 5 and 15'
assert_has "$R" 'D 0:probe 1:probe 2:probe | tcp probes: 0' 'an ICMP reply needs nothing else'
echo 'PASS: health-check round — ICMP, HTTPS before handshake-only, dead tunnel'

cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/hc-mock.sh"
st(){ cat "$PROBE_STATE" 2>/dev/null || echo none; }
PING=no; TCP=no; HS=fresh; tunnel_alive && echo "1 alive $(st)"
tunnel_alive && echo "2 alive $(st)"
PING=ok; tunnel_alive && echo "3 alive $(st)"
PING=no; TCP=ok; tunnel_alive && echo "4 alive $(st)"
TCP=no; tunnel_alive && echo "5 alive $(st)"
HS=none; tunnel_alive || echo "6 dead $(st)"
probe_state_write bogus; echo "7 $(st)"
EOF
run_case probe-state
R=$(cat "$TEST_TMP/result")
assert_eq "$(sed -n '1p' "$TEST_TMP/result")" '1 alive handshake' 'an unknown previous state logs nothing'
assert_eq "$(sed -n '2p' "$TEST_TMP/result")" '2 alive handshake' 'an unchanged state logs nothing'
assert_has "$R" 'LOG: WATCHDOG: the probe hosts answer through the tunnel again' 'recovery is journaled'
assert_has "$R" '3 alive probe' 'ICMP verdict recorded'
assert_has "$R" '4 alive tcp' 'HTTPS verdict recorded'
assert_has "$R" 'LOG: WATCHDOG: the handshake is fresh but the probe hosts (8.8.8.8 1.1.1.1) no longer answer' 'going silent is journaled'
assert_has "$R" '5 alive handshake' 'handshake-only verdict recorded'
assert_has "$R" '6 dead handshake' 'a dead tunnel does not touch the state'
assert_has "$R" '7 handshake' 'only known states are written'
assert_eq "$(grep -c '^LOG:' "$TEST_TMP/result")" 2 'transitions only'
echo 'PASS: probe state — written by every verdict, journaled on transitions only'

# ---------------------------------------------------------------------------------------------
# 4. Адреса, выученные из DNS, переживают stop -> start — пока гео-настройки те же.
# ---------------------------------------------------------------------------------------------
lib geo_cfg_sig geodyn_stash_save geodyn_stash_replay geodyn_stash_settle
cat > "$TEST_TMP/geodyn-mock.sh" <<'EOF'
OWNED_SETS="$TEST_TMP/owned"; GEODYN_STASH="$TEST_TMP/stash"; GEODYN_BORN="$TEST_TMP/born"
GEODYN_STASH_TTL=3600; GEODYN_STASH_MAX=30000; SETTINGS="$TEST_TMP/custom_settings.txt"
rm -f "$GEODYN_STASH" "$GEODYN_BORN" "$TEST_TMP"/save.* "$TEST_TMP/restored"
AGE=0
ipset(){
    case "$1" in
        save) cat "$TEST_TMP/save.$2" 2>/dev/null ;;
        restore) cat >> "$TEST_TMP/restored" ;;
    esac
}
file_age_s(){ [ "$AGE" = gone ] && return 1; echo "$AGE"; }
printf 'awg_default_policy vpn_geo\nawg_geo_v2fly youtube,google\nawg_geo_exc_domains bank.example\nawg_clients 192.168.1.5,PC,vpn_geo\nawg_save_tok abc\n' > "$SETTINGS"
printf 'awg_dst\nawg_dst_t\nawg_dst_x\nmy_t\n\n' > "$OWNED_SETS"
cat > "$TEST_TMP/save.awg_dst" <<'S'
create awg_dst hash:net family inet hashsize 4096 maxelem 262144 timeout 86400
add awg_dst 10.0.0.0/8 timeout 0
add awg_dst 142.250.1.1 timeout 86000
add awg_dst 5.6.7.8 timeout 30
add awg_dst 9.9.9.9 timeout 4000 comment "x"
add awg_dst 203.0.113.0/24 timeout 500
S
printf 'add awg_dst_t 1.1.1.1 timeout 900\n' > "$TEST_TMP/save.awg_dst_t"
printf 'add awg_dst_x 198.51.100.7 timeout 7000\n' > "$TEST_TMP/save.awg_dst_x"
printf 'add my_t 192.0.2.9 timeout 600\n' > "$TEST_TMP/save.my_t"
stash(){ cat "$GEODYN_STASH" 2>/dev/null || echo "(no stash)"; }
lines(){ grep -c '^add ' "$GEODYN_STASH" 2>/dev/null || true; }
EOF
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/geodyn-mock.sh"
SIG=$(geo_cfg_sig); echo "sig-len ${#SIG}"
# Settings that do not shape the sets do not move the fingerprint; a geo edit does.
printf 'awg_clients 192.168.1.9,TV,vpn_all\n' >> "$SETTINGS"; [ "$(geo_cfg_sig)" = "$SIG" ] && echo "sig stable on a device edit"
# No "born" record (an upgrade in place, a lost /tmp): entries of unknown origin are not carried.
geodyn_stash_save; echo "--- no born: $(stash)"
# A clean start (everything built from scratch) opens the epoch; a stop within it parks.
geodyn_stash_settle 1 0; echo "born==sig: $([ "$(cat "$GEODYN_BORN")" = "$SIG" ] && echo yes)"
geodyn_stash_save
echo "--- parked"; stash; echo "--- end"
# Replay into the staging sets of the next start.
: > "$TEST_TMP/restored"; AGE=1000; geodyn_stash_replay awg_dst awg_dst_t; geodyn_stash_replay awg_dst_x awg_dst_x_t
echo "--- replay age=1000"; cat "$TEST_TMP/restored"; echo "--- end"
# Nothing but lines of our own shape may reach `ipset restore`.
printf 'create evil hash:ip\nadd awg_dst 8.8.8.8 timeout 999 ; flush\nadd awg_dst 300.1.1.1x timeout 700\nflush awg_dst\n' >> "$GEODYN_STASH"
: > "$TEST_TMP/restored"; AGE=0; geodyn_stash_replay awg_dst awg_dst_t; echo "--- with malformed lines in the stash"; cat "$TEST_TMP/restored"; echo "--- end"
for AGE in 3601 -5 gone; do : > "$TEST_TMP/restored"; geodyn_stash_replay awg_dst awg_dst_t; echo "--- age=$AGE: $(grep -c . "$TEST_TMP/restored" || true)"; done
# The build that read the stash consumes it; the epoch stays (same settings).
AGE=0; geodyn_stash_settle 1 0; echo "--- consumed: $(stash) | born==sig: $([ "$(cat "$GEODYN_BORN")" = "$SIG" ] && echo yes)"
# A geo edit applied HOT (live sets carried over): the epoch is NOT renewed, so the next stop
# does not park — "edit the lists, then restart" still gives clean sets.
printf 'awg_geo_exc_domains\n' >> "$SETTINGS"
geodyn_stash_settle 0 1; geodyn_stash_save; echo "--- after a hot edit: $(stash)"
# Mixed run (a new policy's set built from scratch next to carried ones): still no new epoch.
geodyn_stash_settle 1 1; geodyn_stash_save; echo "--- mixed build: $(stash)"
# A clean start under the new settings opens a new epoch; settings edited while the tunnel is
# DOWN make the parked entries stale.
geodyn_stash_settle 1 0; geodyn_stash_save; echo "--- new epoch parked: $(lines)"
printf 'awg_geo_2_v2fly netflix\n' >> "$SETTINGS"
: > "$TEST_TMP/restored"; geodyn_stash_replay awg_dst awg_dst_t; echo "--- edited while down: $(grep -c . "$TEST_TMP/restored" || true)"
geodyn_stash_settle 1 0
# The cap cuts the tail of the big sets, never the exclusions.
GEODYN_STASH_MAX=2; geodyn_stash_save; echo "--- capped"; stash; echo "--- end"
# A stop whose sets hold statics only leaves what an earlier stop parked.
GEODYN_STASH_MAX=30000; printf 'add awg_dst 10.0.0.0/8 timeout 0\n' > "$TEST_TMP/save.awg_dst"; : > "$TEST_TMP/save.awg_dst_x"; : > "$TEST_TMP/save.my_t"
geodyn_stash_save; echo "--- statics only keeps: $(lines)"
rm -f "$OWNED_SETS"; geodyn_stash_save; echo "--- no registry keeps: $(lines)"
EOF
run_case geodyn
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'sig-len 32' 'the fingerprint is an md5'
assert_has "$R" 'sig stable on a device edit' 'device policies are not part of the fingerprint'
assert_has "$R" '--- no born: (no stash)' 'entries of unknown origin are not parked'
assert_has "$R" 'born==sig: yes' 'a clean start opens the epoch'
PARKED=$(sed -n '/^--- parked/,/^--- end/p' "$TEST_TMP/result" | sed '1d;$d')
assert_eq "$(printf '%s\n' "$PARKED" | sed -n '1p' | cut -c1-6)" '# sig ' 'the stash carries its fingerprint'
assert_eq "$(printf '%s\n' "$PARKED" | sed '1d')" 'add awg_dst_x 198.51.100.7 timeout 7000
add awg_dst 142.250.1.1 timeout 86000
add awg_dst 5.6.7.8 timeout 30
add awg_dst 9.9.9.9 timeout 4000
add awg_dst 203.0.113.0/24 timeout 500
add my_t 192.0.2.9 timeout 600' 'exclusions first; statics and the staging twin left out; a final set named *_t kept'
assert_eq "$(sed -n '/^--- replay age=1000/,/^--- end/p' "$TEST_TMP/result" | sed '1d;$d')" 'add awg_dst_t 142.250.1.1 timeout 85000
add awg_dst_t 9.9.9.9 timeout 3000
add awg_dst_x_t 198.51.100.7 timeout 6000' 'replay subtracts the parked time and drops the expired'
assert_eq "$(sed -n '/^--- with malformed lines in the stash/,/^--- end/p' "$TEST_TMP/result" | sed '1d;$d')" 'add awg_dst_t 142.250.1.1 timeout 86000
add awg_dst_t 9.9.9.9 timeout 4000
add awg_dst_t 203.0.113.0/24 timeout 500' 'only well-formed lines of the asked set reach ipset restore (and the 30-second entry is not worth carrying)'
assert_has "$R" '--- age=3601: 0' 'a stash past its TTL is ignored'
assert_has "$R" '--- age=-5: 0' 'a stash dated in the future is ignored'
assert_has "$R" '--- age=gone: 0' 'an unreadable stash is ignored'
assert_has "$R" '--- consumed: (no stash) | born==sig: yes' 'the stash is consumed by the build that read it'
assert_has "$R" '--- after a hot edit: (no stash)' 'a geo edit applied hot makes the next restart clean'
assert_has "$R" '--- mixed build: (no stash)' 'a mixed build does not open a new epoch'
assert_has "$R" '--- new epoch parked: 6' 'a clean start under new settings parks again'
assert_has "$R" '--- edited while down: 0' 'settings edited while stopped invalidate the stash'
CAPPED=$(sed -n '/^--- capped/,/^--- end/p' "$TEST_TMP/result" | sed '1d;$d' | sed '1d')
assert_eq "$CAPPED" 'add awg_dst_x 198.51.100.7 timeout 7000
add awg_dst 142.250.1.1 timeout 86000' 'the cap keeps the exclusions and cuts the big set'
assert_has "$R" '--- statics only keeps: 2' 'an empty save keeps the previous stash'
assert_has "$R" '--- no registry keeps: 2' 'no registry, nothing touched'
echo 'PASS: DNS-learned entries — parked within one geo configuration, replayed once, flushed by an edit'

# ---------------------------------------------------------------------------------------------
# 5. Диагностика: цепочка без обрезания и живые пробы через туннель.
# ---------------------------------------------------------------------------------------------
lib diag_marks
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
AWG_CHAIN=AWG
mangle_dump(){ _i=0; echo "-A PREROUTING -j AWG"; while [ "$_i" -lt "$RULES" ]; do echo "-A AWG -s 192.168.10.$_i/32 -m set --match-set awg_dst dst -j MARK --set-xmark 0x100/0xffffffff"; _i=$((_i + 1)); done; echo "-A AWG -m set --match-set awg_dst dst -j MARK --set-xmark 0x100/0xffffffff"; }
# The counters reader is the script's own helper (firmware iptables first): replaced whole, so
# the host's real iptables is never consulted.
mangle_chain_counters(){
    [ "$LISTABLE" = 1 ] || return 1
    cat <<L
Chain AWG (1 references)
    pkts      bytes target     prot opt in     out     source               destination
    4500   910000 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
     $HITS  5000000000 MARK       all  --  *      *       192.168.10.100       0.0.0.0/0            match-set awg_dst dst MARK set 0x100
       0        0 MARK       all  --  *      *       192.168.10.47        0.0.0.0/0            match-set awg_dst dst MARK set 0x100
      $DEF     9000 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set awg_dst dst MARK set 0x100
L
}
RULES=68; LISTABLE=1; HITS=120; DEF=30; diag_marks
echo ===
RULES=300; LISTABLE=0; diag_marks | tail -n 3
echo ===
RULES=0; LISTABLE=1; HITS=0; DEF=0; diag_marks
EOF
run_case diag-marks
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'mangle marks (70 rule line(s)):' 'every rule line is counted'
assert_eq "$(sed -n '/^mangle marks (70/,/^marked packets/p' "$TEST_TMP/result" | grep -c -- '-A ')" 70 'a 34-device chain is printed whole (the old cut was at 60)'
assert_has "$R" 'total: 150 packet(s), 5000009000 B marked for the tunnel by 2 rule(s)' 'totals survive 32-bit byte counts'
assert_has "$R" '192.168.10.100' 'the device with hits is listed'
assert_has "$R" '(any source)               30 pkts' 'the default-policy rule is labelled, not shown as 0.0.0.0/0'
assert_not "$(sed -n '/^marked packets/,/^===/p' "$TEST_TMP/result")" '192.168.10.47' 'rules without hits are not listed'
assert_has "$R" '... (62 more line(s) not shown)' 'a cut is always announced'
assert_has "$R" 'not listable' 'an unlistable chain is said so'
assert_has "$R" "'all traffic' devices are routed by an ip rule, not marked" 'vpn_all devices are explained, not expected in the list'
assert_has "$R" 'NONE — no packet has matched a MARK rule yet' 'no hits is said so'
echo 'PASS: diag — full chain, per-rule counters, no silent cut'

lib file_age_s file_older_than _probe_job _probe_wait _curl_rc _probe_ping_line _probe_curl_line diag_tunnel_probes
cat > "$TEST_TMP/probe-mock.sh" <<'EOF'
IFACE=awg0; RT_TABLE=300; DNSMASQ_AWG_CONF="$TEST_TMP/dnsmasq_awg.conf"
is_running(){ return 0; }
which(){ [ "$1" = curl ] && [ "${NOCURL:-}" = 1 ] && return 1; return 0; }
watchdog_hosts(){ echo "8.8.8.8 1.0.0.1"; }
tun_link_mtu(){ echo 1380; }
ip(){ case "$*" in *"addr show"*) echo "    inet 10.29.80.2/32 scope global awg0" ;; *"rule show"*) echo "100:	from 10.29.80.2 lookup 300" ;; esac; }
sleep(){ command sleep 0.2; }
# busybox-style ping: "-s N" marks the tunnel-MTU packet.
ping(){
    _big=0; for _a in "$@"; do [ "$_a" = -s ] && _big=1; _host=$_a; done
    _ok=$PING_SMALL; [ "$_big" = 1 ] && _ok=$PING_BIG
    echo "PING $_host ($_host): 56 data bytes"
    if [ "$_ok" = ok ]; then
        printf '64 bytes from %s: seq=0 ttl=117 time=41.2 ms\n\n--- %s ping statistics ---\n2 packets transmitted, 2 packets received, 0%% packet loss\nround-trip min/avg/max = 40.1/41.2/42.3 ms\n' "$_host" "$_host"
    else
        printf '\n--- %s ping statistics ---\n2 packets transmitted, 0 packets received, 100%% packet loss\n' "$_host"; return 1
    fi
}
# curl: the URL is the last argument; "--interface" marks a probe bound to the tunnel.
# Each class of probe is driven by its own knob: IPTCP (HTTPS to the IP-literal check hosts),
# NAMED (by name through the tunnel), WAN (the direct baseline), DOWN / UP (the bulk pair).
_curl_small(){
    case "$1" in
        ok)      printf '204 0.051000 0.120000 0.180000 0 0 0.004000'; return 0 ;;
        dns)     printf '000 0.000000 0.000000 0.010000 0 0 0.000000'; return 6 ;;
        dnsto)   printf '000 0.000000 0.000000 5.001000 0 0 0.000000'; return 28 ;;   # the lookup itself timed out
        cert)    printf '000 0.050000 0.000000 0.110000 0 0 0.004000'; return 60 ;;
        stall)   printf '000 0.049000 0.000000 5.001000 0 0 0.004000'; return 28 ;;
        refused) printf '000 0.000000 0.000000 0.020000 0 0 0.004000'; return 7 ;;
        reset)   printf '000 0.048000 0.000000 0.090000 0 0 0.004000'; return 35 ;;
        *)       printf '000 0.000000 0.000000 3.001000 0 0 0.004000'; return 28 ;;   # name resolved, no connection
    esac
}
curl(){
    _tun=0; for _a in "$@"; do [ "$_a" = --interface ] && _tun=1; _url=$_a; done
    case "$_url" in
        *__down*)
            case "${DOWN:-ok}" in
                ok)    printf '200 0.050000 0.110000 1.300000 1048576 0 0.004000'; return 0 ;;
                slow)  printf '200 0.050000 0.110000 7.000000 733184 0 0.004000'; return 28 ;;
                stall) printf '200 0.050000 0.110000 7.000000 20000 0 0.004000'; return 28 ;;
                short) printf '403 0.050000 0.110000 0.200000 150 0 0.004000'; return 0 ;;
                *)     _curl_small "$DOWN" ;;
            esac ;;
        *__up*)
            case "${UP:-ok}" in
                ok)    printf '200 0.050000 0.110000 0.900000 0 262144 0.004000'; return 0 ;;
                slow)  printf '000 0.050000 0.110000 7.000000 0 200000 0.004000'; return 28 ;;
                stall) printf '000 0.050000 0.110000 7.000000 0 65536 0.004000'; return 28 ;;
                *)     _curl_small "$UP" ;;
            esac ;;
        https://[0-9]*) _curl_small "${IPTCP:-ok}" ;;
        *)  if [ "$_tun" = 1 ]; then _curl_small "${NAMED:-ok}"; else _curl_small "${WAN:-ok}"; fi ;;
    esac
}
resolve_domain_v4(){ case "$1" in www.youtube.com) echo 142.250.1.1 ;; www.instagram.com) echo 157.240.1.1 ;; *) echo '!R' ;; esac; }
ipset(){ [ "$1" = test ] && [ "$3" = 142.250.1.1 ]; }
printf '# AmneziaWG domain routing\nfilter-AAAA\nipset=/instagram.com/youtube.com/awg_dst\nipset=/whatsapp.net/awg_dst,awg_dst2\n' > "$DNSMASQ_AWG_CONF"
EOF
probe_case(){
    cat > "$TEST_TMP/case.sh" <<EOF
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/probe-mock.sh"
$1
diag_tunnel_probes
if [ -d "/tmp/.awg_diagprobe.\$\$" ]; then echo "LEFTOVER scratch of this run"; fi
EOF
    run_case "$2"
    R=$(cat "$TEST_TMP/result")
    assert_not "$R" 'LEFTOVER' "$2: the scratch directory is removed"
}
verdict(){ sed -n 's/^  VERDICT: //p' "$TEST_TMP/result"; }

probe_case 'PING_SMALL=no; PING_BIG=no; IPTCP=no; NAMED=no' probes-dead
assert_has "$R" 'ICMP  8.8.8.8 : NO REPLY (0/2)' 'dead: ICMP line'
assert_has "$R" 'HTTPS 8.8.8.8 : FAILED: timed out (curl 28)' 'dead: HTTPS line'
assert_has "$R" '(direct WAN, no tunnel — the baseline) : ok, http 204' 'dead: the WAN baseline still answers'
assert_has "$R" 'bulk download/upload : skipped' 'dead: no bulk wave'
assert_has "$(verdict)" 'NOTHING came back through the tunnel (the handshake aside) while the direct WAN works' 'dead: verdict'
assert_has "$R" 'www.youtube.com -> 142.250.1.1 : in awg_dst' 'domain feed: an address in the set'
assert_has "$R" 'www.instagram.com -> 157.240.1.1 : NOT in awg_dst' 'domain feed: an address that did not reach the set'
assert_has "$R" 'g.whatsapp.net : no IPv4 answer from the router DNS' 'domain feed: no answer'

probe_case 'PING_SMALL=no; PING_BIG=no; IPTCP=no; NAMED=no; WAN=no' probes-no-internet
assert_has "$(verdict)" 'nothing came back through the tunnel — and the direct WAN probe failed as well' 'no internet: the server is not blamed'
assert_not "$R" 'Look at the server side' 'no internet: no server-side verdict'

probe_case 'PING_SMALL=no; PING_BIG=no' probes-icmp-filtered
assert_has "$R" 'HTTPS www.gstatic.com (tunnel) : ok, http 204' 'filtered ICMP: HTTPS passes'
assert_has "$R" 'bulk download, 1 MiB (full-size packets towards the router) : ok, 1048576 B' 'filtered ICMP: bulk download'
assert_has "$R" 'bulk upload, 256 KiB (full-size packets from the router) : ok, 262144 B' 'filtered ICMP: bulk upload'
assert_has "$(verdict)" 'the tunnel passes HTTPS and bulk traffic from the router; ping is not answered' 'filtered ICMP: verdict'

probe_case 'PING_SMALL=ok; PING_BIG=ok' probes-healthy
assert_has "$R" 'ICMP  8.8.8.8 : 2/2 replies, avg 41.2 ms' 'healthy: ICMP line'
assert_has "$R" 'one packet of the tunnel MTU (1380 B) : 2/2 replies' 'healthy: tunnel-MTU ping'
assert_has "$(verdict)" 'the tunnel passes ICMP, HTTPS and bulk traffic from the router' 'healthy: verdict'
assert_not "$R" 'NOTE:' 'healthy: no notes'

probe_case 'PING_SMALL=ok; PING_BIG=no; DOWN=stall; UP=stall' probes-mtu
assert_has "$R" 'one packet of the tunnel MTU (1380 B) : NO REPLY' 'mtu: the tunnel-MTU ping is lost'
assert_has "$R" 'bulk download, 1 MiB (full-size packets towards the router) : STALLED after 20000 of 1048576 B' 'mtu: the download stalls after its TLS session'
assert_has "$R" 'bulk upload, 256 KiB (full-size packets from the router) : STALLED after 65536 of 262144 B' 'mtu: a socket buffer worth of upload is not a pass'
assert_has "$(verdict)" 'small exchanges pass, full-size packets do NOT' 'mtu: verdict'

probe_case 'PING_SMALL=no; PING_BIG=no; IPTCP=stall; NAMED=stall' probes-tls-stall
assert_has "$R" 'TCP connected in 0.049000 s, the TLS exchange never completed' 'stall: the line says where it stopped'
assert_has "$(verdict)" 'TCP connects through the tunnel but the TLS exchange times out' 'stall: verdict'

# --- what must NOT be read as a path-MTU problem (the review's cases) ---
probe_case 'PING_SMALL=ok; PING_BIG=ok; NAMED=dns; WAN=dns; DOWN=dns; UP=dns' probes-router-dns-down
assert_has "$R" 'NOTE: the router itself could not resolve' 'router DNS down: named in a note'
assert_has "$R" 'bulk download, 1 MiB (full-size packets towards the router) : could not run' 'router DNS down: the bulk test could not run'
assert_not "$(verdict)" 'MTU' 'router DNS down: not an MTU verdict'
assert_has "$(verdict)" 'the tunnel passes ICMP, HTTPS (the bulk transfer could not be completed' 'router DNS down: the IP-literal probes still speak for the tunnel'

probe_case 'PING_SMALL=ok; PING_BIG=ok; NAMED=dnsto; WAN=dnsto; DOWN=dnsto; UP=dnsto' probes-router-dns-timeout
assert_has "$R" "the router's DNS did not answer the name lookup in time (curl 28)" 'router DNS timeout: told apart from a tunnel timeout'
assert_has "$R" 'NOTE: the router itself could not resolve' 'router DNS timeout: named in a note'
assert_not "$(verdict)" 'MTU' 'router DNS timeout: not an MTU verdict'
assert_has "$(verdict)" 'the tunnel passes ICMP, HTTPS (the bulk transfer could not be completed' 'router DNS timeout: the IP-literal probes still speak for the tunnel'

probe_case 'PING_SMALL=ok; PING_BIG=ok; NAMED=cert; WAN=cert; DOWN=cert; UP=cert' probes-clock
assert_has "$R" 'NOTE: server certificates were not accepted' 'router clock: named in a note'
assert_has "$R" 'is the router clock right?' 'router clock: the line asks the right question'
assert_not "$(verdict)" 'MTU' 'router clock: not an MTU verdict'

probe_case 'PING_SMALL=ok; PING_BIG=ok; DOWN=slow; UP=slow' probes-slow-link
assert_has "$R" 'bulk download, 1 MiB (full-size packets towards the router) : slow — 733184 of 1048576 B within the time limit; full-size packets do pass' 'slow link: said so'
assert_not "$(verdict)" 'MTU' 'slow link: not an MTU verdict'
assert_has "$(verdict)" 'the tunnel passes ICMP, HTTPS and bulk traffic from the router' 'slow link: verdict'

probe_case 'PING_SMALL=ok; PING_BIG=no' probes-big-ping-ignored
assert_has "$R" 'one packet of the tunnel MTU (1380 B) : NO REPLY' 'big ping: the line still shows it'
assert_not "$(verdict)" 'MTU' 'big ping: a megabyte of passed bulk outranks one unanswered ping'

probe_case 'PING_SMALL=ok; PING_BIG=no; DOWN=short; UP=reset' probes-big-ping-unconfirmed
assert_has "$R" 'inconclusive — the test server answered http 403' 'unconfirmed: the test server refused the transfer'
assert_has "$(verdict)" 'possibly a path-MTU problem' 'unconfirmed: a hedged verdict, not a flat one'

probe_case 'PING_SMALL=ok; PING_BIG=ok; IPTCP=refused; NAMED=cert; WAN=cert' probes-gateway-clock
assert_has "$(verdict)" 'HTTPS through the tunnel could not be tested' 'gateway host + clock: no MTU or filtering claim'
assert_not "$(verdict)" 'MTU' 'gateway host + clock: not an MTU verdict'

probe_case 'PING_SMALL=ok; PING_BIG=ok; IPTCP=refused; NAMED=dns; WAN=dns' probes-gateway-dns
assert_has "$(verdict)" 'HTTPS through the tunnel could not be tested' 'gateway host + DNS down: TCP is not called filtered'
assert_not "$(verdict)" 'filtered' 'gateway host + DNS down: no filtering claim'

probe_case 'PING_SMALL=ok; PING_BIG=ok; IPTCP=refused; NAMED=refused' probes-tcp-refused
assert_has "$(verdict)" 'ICMP passes but no TCP connection could be made through the tunnel' 'TCP refused everywhere: verdict'

probe_case 'PING_SMALL=no; PING_BIG=no; IPTCP=reset; NAMED=reset' probes-tcp-reset
assert_has "$(verdict)" 'the HTTPS exchange is cut short' 'reset: an error, not a timeout, is not called MTU'

probe_case 'PING_SMALL=ok; PING_BIG=ok; NOCURL=1' probes-nocurl
assert_has "$R" '(curl not found — the HTTPS and bulk probes are skipped)' 'no curl: said so'
assert_has "$(verdict)" 'ICMP passes through the tunnel (TCP not tested' 'no curl: verdict does not claim TCP'

cat > "$TEST_TMP/case.sh" <<EOF
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/probe-mock.sh"
is_running(){ return 1; }
diag_tunnel_probes
EOF
run_case probes-stopped
assert_has "$(cat "$TEST_TMP/result")" 'tunnel not running' 'a stopped tunnel is not probed'

# A probe that never returns must not hold the report: the backstop kills it and says so.
# An interrupted earlier run's scratch is swept by age; a fresh one is somebody's live run.
cat > "$TEST_TMP/case.sh" <<EOF
. "$TEST_TMP/lib.sh"
. "$TEST_TMP/probe-mock.sh"
sleep(){ command sleep 0.05; }
ping(){ command sleep 3; }
PING_SMALL=no; PING_BIG=no
OLD="/tmp/.awg_diagprobe.old\$\$"; FRESH="/tmp/.awg_diagprobe.new\$\$"
mkdir -p "\$OLD" "\$FRESH"; touch -t 200001010000 "\$OLD"
_t0=\$(date +%s)
diag_tunnel_probes
echo "ELAPSED \$(( \$(date +%s) - _t0 ))"
if [ -d "\$OLD" ]; then echo "STALE-KEPT"; fi
if [ -d "\$FRESH" ]; then echo "FRESH-KEPT"; fi
rm -rf "\$OLD" "\$FRESH"
EOF
run_case probes-hung
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'ICMP  8.8.8.8 : no result (no output; did not finish in time)' 'hung: the line says it did not finish'
assert_has "$(verdict)" 'the tunnel passes HTTPS and bulk traffic' 'hung: the rest of the report is intact'
_el=$(sed -n 's/^ELAPSED //p' "$TEST_TMP/result")
[ "$_el" -lt 15 ] || fail "hung probe held the report for $_el s"
assert_not "$R" 'STALE-KEPT' 'a stale scratch directory is swept'
assert_has "$R" 'FRESH-KEPT' 'a fresh scratch directory is left alone'
echo 'PASS: diag — live probes, verdicts (incl. what is NOT an MTU problem), bounded waiting'

lib diag_net_path _diag_rule_state
cat > "$TEST_TMP/case.sh" <<'EOF'
. "$TEST_TMP/lib.sh"
IFACE=awg0; DNSMASQ_AWG_CONF="$TEST_TMP/dnsmasq_awg.conf"
is_running(){ return 0; }
tun_link_mtu(){ echo 1380; }
tun_overhead(){ echo 78; }
mtu_budget(){ echo "1380 78 ppp0 1452 over:6"; }
mangle_dump(){ printf '%s\n' '-A FORWARD -o awg0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu' '-A FORWARD -i awg0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340' '-A FORWARD -i awgs0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu'; }
iptables(){ case "$*" in *"INPUT"*) return 4 ;; *"-o awg0"*) return 1 ;; esac; return 0; }
nvram(){ echo dhcp6; }
ip(){ :; }
which(){ return 1; }
diag_net_path
EOF
run_case diag-net-path
R=$(cat "$TEST_TMP/result")
assert_has "$R" 'MTU budget           : tunnel 1380 + 78 overhead = 1458 B on the wire; WAN link ppp0 carries 1452 -> EXCEEDS by 6 B' 'net path: budget line'
assert_has "$R" 'Set the profile MTU to 1374 or lower' 'net path: the fitting MTU'
assert_has "$R" "--set-mss 1340' (tunnel MTU - 40)" 'net path: expected MSS'
assert_eq "$(grep -c -- '-j TCPMSS' "$TEST_TMP/result")" 2 'net path: only this interface rules are listed'
assert_has "$R" 'FORWARD in present, FORWARD out ABSENT, INPUT ? (probe failed)' 'net path: 3-way rule state'
assert_has "$R" 'ipv6_service=dhcp6; AAAA filtered by the router DNS: yes' 'net path: IPv6 line'
if [ -r /proc/net/snmp ]; then
    assert_has "$R" 'Ip  : ForwDatagrams=' 'net path: kernel counters'
    assert_has "$R" 'Icmp: OutDestUnreachs=' 'net path: ICMP counters'
fi
echo 'PASS: diag — tunnel path facts'
echo 'ALL PASS: tests/tunnel-path.sh'
