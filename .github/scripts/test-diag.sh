#!/bin/sh
# Run with sh or BusyBox ash; execute only the extracted web publisher/dispatcher.
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

# The real dispatcher must pass the entire request ID and leave the legacy file alone.
printf 'OLD LEGACY REPORT\n' > "$DIAG_FILE"
do_service_event start awgdiagabc-1-test
result="$work/awg_diag_abc-1-test.htm"
[ "$(cat "$DIAG_FILE")" = 'OLD LEGACY REPORT' ] || fail 'token request overwrote legacy file'
[ "$(head -n 1 "$result")" = 'report < % tag < # tag' ] || fail 'ASP opener not sanitized'
[ "$(tail -n 2 "$result")" = "$(printf '[DIAG_DONE abc-1-test]\n[DIAG_DONE]')" ] || fail 'wrong footer'
[ ! -e "$result.$$" ] || fail 'published temp survived'
echo 'PASS: event token, separate result, ASP sanitization and completion footer'

do_service_event start awgdiag
grep -q '^\[DIAG_DONE legacy-[0-9]*-[0-9]*\]$' "$DIAG_FILE" || fail 'legacy token missing'
[ "$(tail -n 1 "$DIAG_FILE")" = '[DIAG_DONE]' ] || fail 'legacy completion missing'
echo 'PASS: legacy page event and marker'

for token in '../outside' 'abc/def' 'abc def' 'abc;def' 'UPPERCASE' 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklm'; do
    if do_service_event start "awgdiag$token"; then fail "accepted invalid token: $token"; fi
done
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
[ -f "$result" ] || fail 'recent result deleted'
echo 'PASS: bounded result retention and live/dead temp cleanup'

# A reader sees the old complete result throughout generation, never the partial temp.
do_diag(){
    [ "$(cat "$DIAG_FILE")" = 'PREVIOUS COMPLETE REPORT' ] || exit 1
    printf 'NEW COMPLETE REPORT'
}
printf 'PREVIOUS COMPLETE REPORT\n' > "$DIAG_FILE"
do_service_event start awgdiag
[ "$(head -n 1 "$DIAG_FILE")" = 'NEW COMPLETE REPORT' ] || fail 'publication was not atomic'
echo 'PASS: atomic publication'

# Finishing a previous request after a newer one must preserve both results.
do_diag(){ printf 'NEWER REPORT'; }
do_service_event start awgdiagnewer
do_diag(){ printf 'OLDER REPORT'; }
do_service_event start awgdiagolder
[ "$(head -n 1 "$work/awg_diag_newer.htm")" = 'NEWER REPORT' ] || fail 'late old run overwrote new result'
[ "$(head -n 1 "$work/awg_diag_older.htm")" = 'OLDER REPORT' ] || fail 'old result missing'
echo 'PASS: out-of-order completion keeps separate results'

# A failed rename must be observable and its unpublished temp removed.
mv(){ return 1; }
if do_service_event start awgdiagfail; then fail 'failed publish reported success'; fi
[ ! -e "$work/awg_diag_fail.htm.$$" ] || fail 'failed temp kept'
[ ! -e "$work/awg_diag_fail.htm" ] || fail 'failed result published'
grep -q 'ERROR: diag dump could not be written or published' "$work/errors.log" || fail 'publish failure not logged'
unset -f mv
echo 'PASS: failed publication logs an error and removes its temp'

# A failed stream write must not publish only a misleading completion marker.
sed(){ return 1; }
if do_service_event start awgdiagwritefail; then fail 'failed write reported success'; fi
[ ! -e "$work/awg_diag_writefail.htm" ] || fail 'failed stream published'
unset -f sed
echo 'PASS: failed write never publishes a completion marker'
