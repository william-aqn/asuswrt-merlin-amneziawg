#!/bin/sh
# Shared, fail-closed base64 decoder for the client and server backends.
#
# Asuswrt firmware does not always expose the busybox base64 applet.  Entware's
# coreutils-base64 is the package dependency, but a damaged/unmounted /opt must
# not turn a decode into partial data.  Resolve only fixed native paths, prove
# the selected decoder with known bytes, and stage every result before publish.

AWG_BASE64_PROVIDER_KIND=""
AWG_BASE64_PROVIDER_BIN=""

_awg_base64_workdir(){
    local parent="$1" n=0 dir
    [ -d "$parent" ] || return 1
    while [ "$n" -lt 100 ]; do
        dir="$parent/.awg-base64.$$.$n"
        if (umask 077; mkdir "$dir") 2>/dev/null; then
            printf '%s\n' "$dir"
            return 0
        fi
        n=$((n + 1))
    done
    return 1
}

_awg_base64_run_provider(){
    case "$1" in
        base64) "$2" -d ;;
        openssl) "$2" base64 -d -A ;;
        *) return 1 ;;
    esac
}

_awg_base64_provider_selftest(){
    local kind="$1" bin="$2" dir rc=1
    [ -x "$bin" ] || return 1
    dir=$(_awg_base64_workdir /tmp) || return 1
    if printf '%s' 'YXdnLWJhc2U2NC1vaw==' \
        | _awg_base64_run_provider "$kind" "$bin" > "$dir/out" 2>/dev/null \
        && [ "$(cat "$dir/out" 2>/dev/null)" = 'awg-base64-ok' ]; then
        rc=0
    fi
    rm -f "$dir/out" 2>/dev/null
    rmdir "$dir" 2>/dev/null
    return "$rc"
}

# Resolve independently of the caller's PATH.  Prefer a firmware base64 applet,
# then the declared Entware dependency, then firmware OpenSSL.  /opt OpenSSL is
# deliberately excluded: it is not a dependency and can share a broken /opt.
awg_base64_provider_resolve(){
    local force="${1:-}" bin
    if [ -n "$AWG_BASE64_PROVIDER_KIND" ] && [ -n "$AWG_BASE64_PROVIDER_BIN" ]; then
        if [ "$force" != force ] \
            || _awg_base64_provider_selftest "$AWG_BASE64_PROVIDER_KIND" "$AWG_BASE64_PROVIDER_BIN"; then
            return 0
        fi
        AWG_BASE64_PROVIDER_KIND=""
        AWG_BASE64_PROVIDER_BIN=""
    fi
    for bin in /bin/base64 /usr/bin/base64 /sbin/base64 /usr/sbin/base64; do
        if _awg_base64_provider_selftest base64 "$bin"; then
            AWG_BASE64_PROVIDER_KIND=base64
            AWG_BASE64_PROVIDER_BIN="$bin"
            return 0
        fi
    done
    if _awg_base64_provider_selftest base64 /opt/bin/base64; then
        AWG_BASE64_PROVIDER_KIND=base64
        AWG_BASE64_PROVIDER_BIN=/opt/bin/base64
        return 0
    fi
    for bin in /usr/sbin/openssl /usr/bin/openssl /sbin/openssl /bin/openssl; do
        if _awg_base64_provider_selftest openssl "$bin"; then
            AWG_BASE64_PROVIDER_KIND=openssl
            AWG_BASE64_PROVIDER_BIN="$bin"
            return 0
        fi
    done
    return 1
}

# Remove allowed whitespace and validate the complete standard-base64 envelope
# before invoking OpenSSL (which may otherwise accept malformed input as empty).
# Output is private staging data and is never published on validation failure.
_awg_base64_normalize(){
    awk '
        {
            line=$0
            gsub(/[ \t\r\n]/, "", line)
            if (line ~ /[^A-Za-z0-9+\/=]/) bad=1
            for (i=1; i<=length(line); i++) {
                c=substr(line, i, 1)
                if (c == "=") { pad++; seen_pad=1 }
                else if (seen_pad) bad=1
                count++
            }
            printf "%s", line
        }
        END {
            if ((count % 4) != 0 || pad > 2) bad=1
            if (bad) exit 1
        }
    ' "$1" > "$2"
}

# Decode one regular file and atomically replace $2 only after validation and a
# successful provider exit.  The staging directory is on the destination's own
# filesystem, so mv is a rename rather than a partial cross-filesystem copy.
awg_base64_decode_file(){
    local input="$1" output="$2" parent dir rc=1
    [ -f "$input" ] || return 1
    [ -n "$output" ] && [ ! -d "$output" ] || return 1
    awg_base64_provider_resolve || return 1

    case "$output" in
        */*) parent=${output%/*}; [ -n "$parent" ] || parent=/ ;;
        *) parent=. ;;
    esac
    dir=$(_awg_base64_workdir "$parent") || return 1
    if _awg_base64_normalize "$input" "$dir/input.b64" \
        && _awg_base64_run_provider "$AWG_BASE64_PROVIDER_KIND" "$AWG_BASE64_PROVIDER_BIN" \
            < "$dir/input.b64" > "$dir/output" 2>/dev/null \
        && mv -f "$dir/output" "$output"; then
        rc=0
    fi
    rm -f "$dir/input.b64" "$dir/output" 2>/dev/null
    rmdir "$dir" 2>/dev/null
    return "$rc"
}

# Decode stdin to a file without truncating/replacing that file on failure.
awg_base64_decode_to_file(){
    local output="$1" dir rc=1
    dir=$(_awg_base64_workdir /tmp) || return 1
    if cat > "$dir/input" && awg_base64_decode_file "$dir/input" "$output"; then
        rc=0
    fi
    rm -f "$dir/input" 2>/dev/null
    rmdir "$dir" 2>/dev/null
    return "$rc"
}

# Decode stdin to stdout without exposing provider partial output on failure.
awg_base64_decode(){
    local dir rc=1
    dir=$(_awg_base64_workdir /tmp) || return 1
    if cat > "$dir/input" \
        && awg_base64_decode_file "$dir/input" "$dir/output" \
        && cat "$dir/output"; then
        rc=0
    fi
    rm -f "$dir/input" "$dir/output" 2>/dev/null
    rmdir "$dir" 2>/dev/null
    return "$rc"
}
