#!/bin/bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <package.ipk> [...]" >&2
    exit 2
fi

tmp_dir=""
cleanup(){
    if [ -n "$tmp_dir" ]; then
        rm -rf -- "$tmp_dir"
    fi
}
trap cleanup EXIT

assert_root_owned_archive(){
    local archive="$1"
    local label="$2"
    local owners

    gtar -tzf "$archive" > /dev/null
    owners="$(gtar --numeric-owner -tvzf "$archive" | awk '{print $2}' | sort -u)"
    if [ "$owners" != "0/0" ]; then
        echo "ERROR: $label contains non-root numeric owners: ${owners:-none}" >&2
        return 1
    fi
}

for ipk_file in "$@"; do
    [ -f "$ipk_file" ] || { echo "ERROR: package not found: $ipk_file" >&2; exit 1; }

    tmp_dir="$(mktemp -d)"
    assert_root_owned_archive "$ipk_file" "$ipk_file outer archive"
    gtar -xzf "$ipk_file" -C "$tmp_dir" ./control.tar.gz ./data.tar.gz
    assert_root_owned_archive "$tmp_dir/control.tar.gz" "$ipk_file control archive"
    assert_root_owned_archive "$tmp_dir/data.tar.gz" "$ipk_file data archive"
    rm -rf -- "$tmp_dir"
    tmp_dir=""

    echo "root-owned package archives: $ipk_file"
done
