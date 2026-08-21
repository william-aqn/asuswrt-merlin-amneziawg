#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/addon/awg_base64.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail(){ printf 'FAIL: %s\n' "$1" >&2; exit 1; }
reset_provider(){ AWG_BASE64_PROVIDER_KIND=""; AWG_BASE64_PROVIDER_BIN=""; }

# Exercise the exact action classifier embedded before the runtime-init gate.
# Recovery/read-only actions must remain available when no decoder can load;
# start/update and every unlisted action must fail closed instead.
classifier=$(sed -n '/^awg_base64_action_required(){/,/^}/p' "$ROOT/addon/amneziawg.sh")
[ -n "$classifier" ] || fail 'base64 action classifier missing'
eval "$classifier"
for recovery in stop stop_auto status diag diagnostics uninstall analyze_stop check_update ctf_status; do
    if awg_base64_action_required "$recovery"; then
        fail "recovery/read-only action unexpectedly requires provider: $recovery"
    fi
done
for event in awgstop awgdiag awganalyzestop awgsrvstop awgsrvdiag awgsrvstatus; do
    if awg_base64_action_required service_event ignored "$event"; then
        fail "recovery/read-only service event unexpectedly requires provider: $event"
    fi
done
for gated in start update restart watchdog install_page; do
    awg_base64_action_required "$gated" \
        || fail "mutating/decode-capable action bypasses provider: $gated"
done
awg_base64_action_required service_event ignored awgstart \
    || fail 'mutating service event bypasses provider'
grep -Fq "if [ \"\$AWG_BASE64_REQUIRED\" = 1 ]; then" "$ROOT/addon/amneziawg.sh" \
    || fail 'action classifier is not wired to the provider gate'

# Normal and firmware-only PATHs must produce the same bytes; provider lookup is
# by fixed absolute path rather than whichever command a caller injected first.
for test_path in "$PATH" /bin:/usr/bin:/sbin:/usr/sbin; do
    (
        PATH=$test_path; export PATH
        reset_provider
        printf '%s' 'Tm9ydGhicmlkZ2U=' | awg_base64_decode_to_file "$TMP/out"
        [ "$(cat "$TMP/out")" = 'Northbridge' ]
    ) || fail "decode under PATH=$test_path"
done

printf 'Tm9y\ndGg=\n' | awg_base64_decode_to_file "$TMP/out"
[ "$(cat "$TMP/out")" = North ] || fail 'whitespace-separated base64 decode'

# Model a multi-MiB manual UI upload: the backend stores one ~50 KiB record per
# chunk.  Whitespace normalization must remain streaming/bounded by that record
# size and must reproduce the concatenated payload exactly.
awk 'BEGIN {
    chars=2 * 1024 * 1024
    chunk=50000
    alphabet="QUJD"
    for (i=0; i<chars; i++) {
        printf "%s", substr(alphabet, (i % 4) + 1, 1)
        if (((i + 1) % chunk) == 0) printf "\n"
    }
    printf "\n"
}' > "$TMP/large.b64"
awk 'BEGIN { for (i=0; i<524288; i++) printf "ABC" }' > "$TMP/large.want"
awg_base64_decode_file "$TMP/large.b64" "$TMP/large.out" \
    || fail 'large multiline upload decode'
cmp -s "$TMP/large.want" "$TMP/large.out" \
    || fail 'large multiline upload bytes differ'

# Whitespace is accepted, but malformed input must fail without replacing a
# previous good output (including with OpenSSL's otherwise-permissive decoder).
printf '%s' sentinel > "$TMP/out"
if printf 'Tm9y%%%%dGg=' | awg_base64_decode_to_file "$TMP/out"; then
    fail 'malformed input accepted'
fi
[ "$(cat "$TMP/out")" = sentinel ] || fail 'malformed input replaced output'

printf '%s' sentinel > "$TMP/out"
(
    awg_base64_provider_resolve(){ return 1; }
    if printf '%s' 'Tm9ydGg=' | awg_base64_decode_to_file "$TMP/out"; then
        exit 1
    fi
) || fail 'missing provider did not fail closed'
[ "$(cat "$TMP/out")" = sentinel ] || fail 'missing provider replaced output'

# A runnable command is not enough: wrong decoded bytes must fail the provider
# self-test and can never enter the resolver cache.
printf '%s\n' '#!/bin/sh' 'printf wrong' > "$TMP/fake-base64"
chmod 700 "$TMP/fake-base64"
if _awg_base64_provider_selftest base64 "$TMP/fake-base64"; then
    fail 'invalid provider passed self-test'
fi

# A provider can fail after it was selected (for example, /opt disappears).
# Its partial stdout must remain private staging data and never replace output.
# shellcheck disable=SC2016 # The following lines are literal contents of the fake provider.
printf '%s\n' \
    '#!/bin/sh' \
    'data=$(cat)' \
    'if [ "$data" = YXdnLWJhc2U2NC1vaw== ]; then printf awg-base64-ok; exit 0; fi' \
    'printf partial' \
    'exit 1' > "$TMP/flaky-base64"
chmod 700 "$TMP/flaky-base64"
_awg_base64_provider_selftest base64 "$TMP/flaky-base64" \
    || fail 'flaky provider did not pass initial self-test'
AWG_BASE64_PROVIDER_KIND=base64
AWG_BASE64_PROVIDER_BIN=$TMP/flaky-base64
printf '%s' sentinel > "$TMP/out"
if printf '%s' 'Tm9ydGg=' | awg_base64_decode_to_file "$TMP/out"; then
    fail 'provider partial failure reported success'
fi
[ "$(cat "$TMP/out")" = sentinel ] || fail 'provider partial output escaped staging'
reset_provider

# Exercise the permissive OpenSSL fallback explicitly when the host provides a
# firmware-shaped absolute path. Syntax validation must still protect output.
for ssl in /usr/sbin/openssl /usr/bin/openssl /sbin/openssl /bin/openssl; do
    [ -x "$ssl" ] || continue
    _awg_base64_provider_selftest openssl "$ssl" || fail 'OpenSSL provider self-test'
    AWG_BASE64_PROVIDER_KIND=openssl
    AWG_BASE64_PROVIDER_BIN=$ssl
    printf '%s' sentinel > "$TMP/out"
    if printf '%s' '%%%%' | awg_base64_decode_to_file "$TMP/out"; then
        fail 'OpenSSL accepted malformed input'
    fi
    [ "$(cat "$TMP/out")" = sentinel ] || fail 'OpenSSL failure replaced output'
    reset_provider
    break
done

# Static regression gates: package dependency, no raw runtime decodes, and the
# update provider preflight must remain before the first VPN stop.
grep -q '^Depends: coreutils-base64$' "$ROOT/build-ipk.sh" || fail 'package dependency missing'
if grep -nE '(^|[|;&[:space:]])base64[[:space:]]+-d' \
    "$ROOT/addon/amneziawg.sh" "$ROOT/addon/amneziawg_server.sh" >/dev/null; then
    fail 'raw runtime base64 decoder remains'
fi
grep -q 'cp addon/awg_base64.sh' "$ROOT/build-ipk.sh" || fail 'helper is absent from package'
grep -q "printf '%s\\\\n' \"\$chunk\" >> \"\$AWG_UPLOAD_B64\"" "$ROOT/addon/amneziawg.sh" \
    || fail 'manual upload is not newline-bounded for streaming validation'
grep -q 'scp addon/awg_base64.sh addon/amneziawg.sh' "$ROOT/README.md" \
    || fail 'Russian addon-only update omits helper'
grep -q 'scp addon/awg_base64.sh addon/amneziawg.sh' "$ROOT/README_EN.md" \
    || fail 'English addon-only update omits helper'
grep -q 'opkg install coreutils-base64' "$ROOT/README.md" \
    || fail 'Russian addon-only update omits decoder dependency'
grep -q 'opkg install coreutils-base64' "$ROOT/README_EN.md" \
    || fail 'English addon-only update omits decoder dependency'
initial=$(grep -n 'if ! awg_base64_provider_resolve; then' "$ROOT/addon/amneziawg.sh" | head -1 | cut -d: -f1)
ipset_init=$(grep -n '# Resolve a WORKING' "$ROOT/addon/amneziawg.sh" | head -1 | cut -d: -f1)
[ -n "$initial" ] && [ -n "$ipset_init" ] && [ "$initial" -lt "$ipset_init" ] \
    || fail 'provider is not resolved before runtime initialization'
preflight=$(grep -n 'if ! awg_base64_provider_resolve force' "$ROOT/addon/amneziawg.sh" | head -1 | cut -d: -f1)
stop=$(grep -n 'log_msg "Update: stopping VPN"' "$ROOT/addon/amneziawg.sh" | head -1 | cut -d: -f1)
[ -n "$preflight" ] && [ -n "$stop" ] && [ "$preflight" -lt "$stop" ] \
    || fail 'update preflight is not before VPN stop'

printf 'PASS: base64 provider and atomic decode gates\n'
