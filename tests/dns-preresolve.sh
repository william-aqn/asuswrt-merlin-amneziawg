#!/bin/sh
# Изолированные регрессии DNS/геосетов: sh tests/dns-preresolve.sh
# BusyBox: TEST_SHELL='busybox ash' busybox ash tests/dns-preresolve.sh
# Функции извлекаются из рабочего скрипта; роутер, DNS и реальные ipset не используются.
set -eu
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SRC=${TEST_SOURCE:-"$REPO/addon/amneziawg.sh"}
TEST_SHELL=${TEST_SHELL:-sh}
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
trap 'exit 1' HUP INT TERM

fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_eq(){ [ "$1" = "$2" ] || fail "$3: expected [$2], got [$1]"; }
extract(){ sed -n "/^$1(){/,/^}/p" "$SRC"; }
run_case(){ $TEST_SHELL "$TEST_TMP/case.sh" > "$TEST_TMP/result" 2> "$TEST_TMP/errors" || { cat "$TEST_TMP/errors" >&2; fail 'case exited'; }; }

extract resolve_domain_v4 > "$TEST_TMP/parser.sh"
cat > "$TEST_TMP/case.sh" <<EOF
. "$TEST_TMP/parser.sh"
nslookup(){ printf '%s\n' "\$DNS_FIXTURE"; }
resolve_domain_v4 example.test -querytype=A
EOF
export DNS_FIXTURE
for err in REFUSED SERVFAIL; do
    DNS_FIXTURE="** server can't find example.test: $err"
    run_case
    assert_eq "$(cat "$TEST_TMP/result")" '!R' "$err must be retried"
done
DNS_FIXTURE="** server can't find example.test: NXDOMAIN"
run_case
assert_eq "$(cat "$TEST_TMP/result")" '' 'NXDOMAIN is a terminal answer'
DNS_FIXTURE="** server can't find REFUSED.example.test: NXDOMAIN"
run_case
assert_eq "$(cat "$TEST_TMP/result")" '' 'an error word inside a domain is not a status'
DNS_FIXTURE='Server: 127.0.0.1
Address: 127.0.0.1#53
Name: example.test
Address 1: 203.0.113.10 198.51.100.99
Address 2: 0.0.0.0
Address 3: 127.0.0.2
Address 4: 2001:db8::1'
run_case
assert_eq "$(cat "$TEST_TMP/result")" '203.0.113.10' 'only usable answer addresses'
echo 'PASS: DNS errors, negative answers and IPv4 parsing'

# Сценарий прогона целиком, включая повторы, сохранение курсора и следующий reload.
awk '
    /^reload_dnsmasq\(\)\{/ { inreload=1 }
    inreload && $0 == "            _beat preresolve" { keep=1 }
    keep && $0 == "        fi" { exit }
    keep { print }
' "$SRC" | sed "s|/tmp/.awg_dnsreload|$TEST_TMP/lock|g" > "$TEST_TMP/feed.sh"
[ -s "$TEST_TMP/feed.sh" ] || fail 'pre-resolve body not found'
mkdir "$TEST_TMP/lock"
cat > "$TEST_TMP/mock.sh" <<'EOF'
PRERSLV_FRESH_S=86400
_me=42
_beat(){ :; }
_dr_up(){ read -r _ux _uy < /proc/uptime; _ux=${_ux%%.*}; }
_dr_done(){ exit 0; }
dnsreload_deferred(){ return 1; }
agh_present(){ return 1; }
geo_ipset_total(){ echo 0; }
dns_ok(){ return 0; }
log_msg(){ echo "$*"; }
nslookup(){
    name=$2
    [ "$name" = localhost ] && return 0
    echo "$name" >> "$TEST_ROOT/queries"
    case "$name" in
        first.test) address=203.0.113.10 ;;
        second.test)
            address=203.0.113.20
            if [ "$DNS_ERROR" != none ]; then
                if [ "$DNS_ERROR" = persistent ] || [ ! -f "$TEST_ROOT/answered" ]; then
                    touch "$TEST_ROOT/answered"
                    _rcode=$DNS_ERROR
                    [ "$_rcode" = persistent ] && _rcode=SERVFAIL
                    printf "** server can't find second.test: %s\n" "$_rcode"
                    return 1
                fi
            fi ;;
        *) address=203.0.113.30 ;;
    esac
    printf 'Name: %s\nAddress: %s\n' "$name" "$address"
}
ipset(){
    case "$1" in
        add)
            [ "$IPSET_ERROR" = new ] && return 0
            return 1 ;; # EEXIST; third.test models an expired entry / a failed add.
        save)
            echo "create $2 hash:net family inet timeout 86400"
            echo "add $2 203.0.113.10 timeout 1"
            echo "add $2 203.0.113.20 timeout 0"
            [ "$IPSET_ERROR" != save ] ;;
        restore)
            cat > "$TEST_ROOT/restored"
            [ "$IPSET_ERROR" != restore ] ;;
    esac
}
EOF
export TEST_ROOT="$TEST_TMP" DNS_ERROR IPSET_ERROR
cat > "$TEST_TMP/case.sh" <<EOF
DNSMASQ_AWG_CONF="$TEST_TMP/conf"
GEOSET_GEN="$TEST_TMP/gen"
PRERSLV_STATE="$TEST_TMP/state"
PRERSLV_EEX="$TEST_TMP/eex"
PRERSLV_RETRY="$TEST_TMP/retry"
. "$TEST_TMP/mock.sh"
. "$TEST_TMP/parser.sh"
. "$TEST_TMP/feed.sh"
EOF
reset_feed(){
    rm -f "$TEST_TMP/state" "$TEST_TMP/eex" "$TEST_TMP/retry" "$TEST_TMP/retry.strike" \
        "$TEST_TMP/queries" "$TEST_TMP/answered" "$TEST_TMP/restored" "$TEST_TMP/lock/"*
    echo generation1 > "$TEST_TMP/gen"
    printf 'ipset=/first.test/awg_dst\nipset=/second.test/awg_dst\nipset=/third.test/awg_dst\n' > "$TEST_TMP/conf"
}
assert_complete(){
    read -r sg sm sd st ss < "$TEST_TMP/state"
    assert_eq "$sd" "$st" 'completed cursor'
}
assert_pending(){
    read -r sg sm sd st ss < "$TEST_TMP/state"
    [ "$sd" -lt "$st" ] || fail 'failed run was marked complete'
}
for err in REFUSED SERVFAIL; do
    reset_feed
    DNS_ERROR=$err; IPSET_ERROR=new
    run_case
    assert_complete
    assert_eq "$(grep -c '^second.test$' "$TEST_TMP/queries")" 2 "$err retry count"
    count=$(wc -l < "$TEST_TMP/queries")
    run_case
    assert_eq "$(wc -l < "$TEST_TMP/queries")" "$count" 'completed run must skip lookups'
done
reset_feed
DNS_ERROR=persistent; IPSET_ERROR=new
run_case
assert_pending
[ -s "$TEST_TMP/retry" ] || fail 'unanswered DNS retry was lost'
DNS_ERROR=none
run_case
assert_complete
[ ! -f "$TEST_TMP/retry" ] || fail 'successful DNS retry was not cleared'
echo 'PASS: transient DNS recovery, outage resume and completed-run skip'

for err in save restore; do
    reset_feed
    DNS_ERROR=none; IPSET_ERROR=$err
    run_case
    assert_pending
    [ -s "$TEST_TMP/eex" ] || fail "$err lost the refresh queue"
    if [ "$err" = save ]; then
        [ ! -f "$TEST_TMP/restored" ] || fail 'failed save reached restore'
    fi
    IPSET_ERROR=ok
    run_case
    assert_complete
    [ ! -f "$TEST_TMP/eex" ] || fail 'successful refresh did not clear queue'
    grep -q '^add awg_dst 203.0.113.10$' "$TEST_TMP/restored" || fail 'dynamic entry not refreshed'
    grep -q '^add awg_dst 203.0.113.30$' "$TEST_TMP/restored" || fail 'expired entry not restored'
    if grep -q '203.0.113.20' "$TEST_TMP/restored"; then fail 'permanent entry demoted'; fi
    assert_eq "$(sed -n '1p' "$TEST_TMP/restored")" 'add awg_dst 203.0.113.10' 'present entries must precede missing ones'
done
echo 'PASS: save/restore failures preserve work; recovery preserves permanent entries'

# Обновляется файл по тому же URL: настройки и список доменов не меняются.
for f in geo_static_sig geo_swap_window_close geoset_gen_bump; do extract "$f"; done \
    | sed "s|/tmp/.awg_dnsreload|$TEST_TMP/lock|g" > "$TEST_TMP/static.sh"
mkdir -p "$TEST_TMP/geo/geoip" "$TEST_TMP/geo/antifilter"
cat > "$TEST_TMP/case.sh" <<EOF
GEO_DIR="$TEST_TMP/geo"
GEOSET_GEN="$TEST_TMP/gen"
PRERSLV_STATE="$TEST_TMP/state"
PRERSLV_EEX="$TEST_TMP/eex"
PRERSLV_RETRY="$TEST_TMP/retry"
GEOSTATIC_SIG="$TEST_TMP/static_sig"
geo_ids(){ echo 1; }
geo_key(){ echo "awg_geo_\$2"; }
get_setting(){ case "\$1" in awg_geo_antifilter_lists) echo ipresolve ;; esac; }
log_msg(){ :; }
. "$TEST_TMP/static.sh"
geo_swap_window_close "\$(cat "\$GEOSET_GEN")|\$(cat "\$PRERSLV_STATE")" "\$(geo_static_sig)"
EOF
for file in antifilter/af_ipresolve.cidr geoip/v2fly_test.cidr geoip/userurl_test.cidr; do
    printf '203.0.113.10/32\n' > "$TEST_TMP/geo/$file"
    rm -f "$TEST_TMP/static_sig"
    run_case
    echo 'generation1 same-list 3 3 100' > "$TEST_TMP/state"
    echo generation1 > "$TEST_TMP/gen"
    run_case
    [ -f "$TEST_TMP/state" ] || fail 'unchanged static content invalidated cursor'
    # Same byte length, different content: mtime/size checks would miss this.
    printf '203.0.113.20/32\n' > "$TEST_TMP/geo/$file"
    run_case
    [ ! -f "$TEST_TMP/state" ] || fail "$file update retained the old cursor"
    echo 'generation1 same-list 3 3 100' > "$TEST_TMP/state"
    rm -f "$TEST_TMP/geo/$file"
    run_case
    [ ! -f "$TEST_TMP/state" ] || fail "$file removal retained the old cursor"
done
echo 'generation1 same-list 3 3 100' > "$TEST_TMP/state"
# Неудачный fingerprint тоже не должен оставлять прогон завершённым.
sed '/^geo_swap_window_close/i\md5sum(){ return 1; }' "$TEST_TMP/case.sh" > "$TEST_TMP/hash-fail.sh"
$TEST_SHELL "$TEST_TMP/hash-fail.sh" > "$TEST_TMP/result" 2> "$TEST_TMP/errors" || fail 'hash-failure case exited'
[ ! -f "$TEST_TMP/state" ] || fail 'failed fingerprint retained the old cursor'
echo 'PASS: unchanged sources skip; updated/removed static content invalidates progress'
echo 'All DNS pre-resolve regressions passed.'
