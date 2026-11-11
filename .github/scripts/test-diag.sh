#!/bin/sh
# Run with sh or BusyBox ash; execute only the extracted web publisher/dispatcher.
# The collection runs DETACHED from the dispatcher since 1.5.30: every call is followed by
# `wait` before its result is looked at.
set -eu
repo=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
sed -n '/^file_age_s(){/,/^# --- Updater /p' "$repo/addon/amneziawg.sh" > "$work/helpers.sh"
sed -n '/^do_diag_publish(){/,/^# --- Main ---/p' "$repo/addon/amneziawg.sh" >> "$work/helpers.sh"
. "$work/helpers.sh"
DIAG_FILE="$work/awg_diag.htm"
log_msg(){ printf '%s\n' "$*" >> "$work/errors.log"; }
do_diag(){ printf '%s' 'report <% tag <# tag'; }
fail(){ echo "FAIL: $*" >&2; exit 1; }
no_temp(){ set -- "$1".[0-9]*; [ ! -e "$1" ]; }

# The real dispatcher must pass the entire request ID and leave the legacy file alone.
printf 'OLD LEGACY REPORT\n' > "$DIAG_FILE"
do_service_event start awgdiagabc-1-test
wait
result="$work/awg_diag_abc-1-test.htm"
[ "$(cat "$DIAG_FILE")" = 'OLD LEGACY REPORT' ] || fail 'token request overwrote legacy file'
[ "$(head -n 1 "$result")" = 'report < % tag < # tag' ] || fail 'ASP opener not sanitized'
[ "$(tail -n 2 "$result")" = "$(printf '[DIAG_DONE abc-1-test]\n[DIAG_DONE]')" ] || fail 'wrong footer'
no_temp "$result" || fail 'published temp survived'
echo 'PASS: event token, separate result, ASP sanitization and completion footer'

do_service_event start awgdiag
wait
grep -q '^\[DIAG_DONE legacy-[0-9]*-[0-9]*\]$' "$DIAG_FILE" || fail 'legacy token missing'
[ "$(tail -n 1 "$DIAG_FILE")" = '[DIAG_DONE]' ] || fail 'legacy completion missing'
echo 'PASS: legacy page event and marker'

# Validation stays in the dispatcher itself: a bad token is refused before anything is started.
for token in '../outside' 'abc/def' 'abc def' 'abc;def' 'UPPERCASE' 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklm'; do
    if do_service_event start "awgdiag$token"; then fail "accepted invalid token: $token"; fi
done
wait
echo 'PASS: unsafe and oversized tokens rejected'

# Keep live writers and recent completed results, sweep dead writers and expired results.
# Stock Merlin find cannot perform age/depth queries, even when a full BusyBox test image can.
find(){ return 1; }
live="$work/awg_diag_live.htm.$$"
dead="$work/awg_diag_dead.htm.2147483647"
expired="$work/awg_diag_expired.htm"
printf 'LIVE\n' > "$live"
printf 'DEAD\n' > "$dead"
printf 'EXPIRED\n' > "$expired"
touch -t 200001010000 "$expired"
do_service_event start awgdiagcleanup
[ -f "$live" ] || fail 'live temp deleted'
[ ! -e "$dead" ] || fail 'dead temp kept'
[ ! -e "$expired" ] || fail 'expired result kept'
wait
[ -f "$result" ] || fail 'recent result deleted'
echo 'PASS: bounded result retention and live/dead temp cleanup'

# A reader sees the old complete result throughout generation, never the partial temp.
do_diag(){
    [ "$(cat "$DIAG_FILE")" = 'PREVIOUS COMPLETE REPORT' ] || exit 1
    printf 'NEW COMPLETE REPORT'
}
printf 'PREVIOUS COMPLETE REPORT\n' > "$DIAG_FILE"
do_service_event start awgdiag
wait
[ "$(head -n 1 "$DIAG_FILE")" = 'NEW COMPLETE REPORT' ] || fail 'publication was not atomic'
echo 'PASS: atomic publication'

# Finishing a previous request after a newer one must preserve both results.
do_diag(){ printf 'NEWER REPORT'; }
do_service_event start awgdiagnewer
do_diag(){ printf 'OLDER REPORT'; }
do_service_event start awgdiagolder
wait
[ "$(head -n 1 "$work/awg_diag_newer.htm")" = 'NEWER REPORT' ] || fail 'late old run overwrote new result'
[ "$(head -n 1 "$work/awg_diag_older.htm")" = 'OLDER REPORT' ] || fail 'old result missing'
echo 'PASS: out-of-order completion keeps separate results'

# The handler hands the collection off and returns: a slow report must not hold rc_service
# (notify_rc drops the next event after 15 s of waiting for the one in flight).
do_diag(){ sleep 2; printf 'SLOW REPORT'; }
t0=$(date +%s)
do_service_event start awgdiagdetached
t1=$(date +%s)
[ $((t1 - t0)) -le 1 ] || fail "the dispatcher waited $((t1 - t0)) s for the collection"
[ ! -e "$work/awg_diag_detached.htm" ] || fail 'result present before the collection could finish'
wait
[ "$(head -n 1 "$work/awg_diag_detached.htm")" = 'SLOW REPORT' ] || fail 'detached collection did not publish'
echo 'PASS: collection runs detached from the service event'

# The temp carries its WRITER's pid, not the dispatcher's: on a router the dispatcher is gone
# the moment it has started the collection, and a temp named after it would look dead to the
# next request's sweep and be deleted under the writer. Reproduced with a dispatcher that
# really is a separate, short-lived shell.
cat > "$work/req.sh" <<EOF
. "$work/helpers.sh"
DIAG_FILE="$DIAG_FILE"
log_msg(){ printf '%s\n' "\$*" >> "$work/errors.log"; }
do_diag(){ sleep 2; printf 'ORPHAN WRITER REPORT'; }
do_service_event start awgdiagorphan
EOF
${TEST_SHELL:-sh} "$work/req.sh"
do_diag(){ printf 'QUICK REPORT'; }
do_service_event start awgdiagquick      # its sweep runs while the orphan's temp is being written
wait
i=0
while [ ! -e "$work/awg_diag_orphan.htm" ] && [ "$i" -lt 8 ]; do sleep 1; i=$((i + 1)); done
[ "$(head -n 1 "$work/awg_diag_orphan.htm" 2>/dev/null)" = 'ORPHAN WRITER REPORT' ] || fail "a live writer's temp was swept by the next request"
[ "$(head -n 1 "$work/awg_diag_quick.htm")" = 'QUICK REPORT' ] || fail 'the second request did not publish'
echo "PASS: a live writer's temp survives the next request's sweep"

# A failed rename must be observable and its unpublished temp removed. The dispatcher itself
# has already returned by then, so the failure is reported in the journal.
do_diag(){ printf 'REPORT'; }
mv(){ return 1; }
do_service_event start awgdiagfail || fail 'a valid request was refused'
wait
no_temp "$work/awg_diag_fail.htm" || fail 'failed temp kept'
[ ! -e "$work/awg_diag_fail.htm" ] || fail 'failed result published'
grep -q 'ERROR: diag dump could not be written or published' "$work/errors.log" || fail 'publish failure not logged'
unset -f mv
echo 'PASS: failed publication logs an error and removes its temp'

# A failed stream write must not publish only a misleading completion marker.
: > "$work/errors.log"
sed(){ return 1; }
do_service_event start awgdiagwritefail || fail 'a valid request was refused'
wait
[ ! -e "$work/awg_diag_writefail.htm" ] || fail 'failed stream published'
unset -f sed
grep -q 'ERROR: diag dump could not be written or published' "$work/errors.log" || fail 'write failure not logged'
echo 'PASS: failed write never publishes a completion marker'
