#!/bin/sh
# Memory-envelope suite: box_is_roomy / compute_go_memlimit / compute_pool_cap /
# swap_total_mib / mem_squeeze_state / go_tune_desc, driven by mocked /proc.
#
# These decide the soft heap ceiling and the buffer-pool cap the daemon launches with, and
# whether the page shows the "router is short on memory" banner. They are pure functions of
# /proc/meminfo plus /proc/sys/vm/overcommit_memory, which makes them the one part of the
# addon that can be tested honestly off-router.
#
# The numbers in scenarios 1 and 2 are the real field case behind CHANGELOG 1.5.23
# (RT-AX58U, 512 MB, stock 388.12_2, diag 2026-09-20): ~30 `runtime: out of memory` aborts
# and 9 health-check rollbacks in one day, cured by a 1 GB swap file on the USB stick. The
# expectations below are therefore the documented behaviour, not whatever the code does now.
#
# Run standalone:  sh tests/mem_envelope.sh   (or: busybox ash tests/mem_envelope.sh)

TESTS_DIR=$(dirname "$0")
. "$TESTS_DIR/lib.sh"

SRC="$TESTS_DIR/../addon/amneziawg.sh"
TMP=${AWG_TEST_SANDBOX:-$(mktemp -d)}/mem.$$
mkdir -p "$TMP" || t_bail "не удалось создать песочницу $TMP"
[ -n "${AWG_TEST_SANDBOX:-}" ] || trap 'rm -rf "$TMP"' EXIT INT TERM

t_plan 25

# --- L1: every name this suite leans on must exist, before we source anything ------------
seam_require_sh_funcs "$SRC" \
    box_is_roomy compute_go_memlimit compute_pool_cap swap_total_mib mem_squeeze_state \
    go_tune_desc iface_exists

# --- L2: sandboxed copy, every rewrite accounted for -------------------------------------
# NB the mock dir is called "pm", not "proc": sandbox_script refuses a path containing
# "/proc/" precisely because it would make the survivor check count its own rewrites.
PM="$TMP/pm"
mkdir -p "$PM"
sandbox_script "$SRC" "$TMP/copy.sh" "$PM" "$TMP"

# Same shape as addon/amneziawg_server.sh: source in lib mode, then override the instance
# globals. Pin the interface to a name that cannot exist so mem_squeeze_state takes its
# "tunnel not running" branch deterministically on any host, and point DAEMON_TUNE at a file
# that is never created.
AWG_LIB_MODE=1 . "$TMP/copy.sh" || t_bail "source копии в lib-режиме провалился"
unset AWG_LIB_MODE
IFACE=awg-test-absent
DAEMON_TUNE="$TMP/never-written"

seam_require_loaded box_is_roomy compute_go_memlimit compute_pool_cap swap_total_mib \
    mem_squeeze_state go_tune_desc iface_exists

# Write a mock /proc. $1 = overcommit_memory value; meminfo comes from stdin.
mkproc(){
    rm -f "$PM/meminfo" "$PM/overcommit_memory"
    [ "$1" = none ] || echo "$1" > "$PM/overcommit_memory"
    cat > "$PM/meminfo"
}

# --- L3: prove the mock is what the functions actually read -------------------------------
# Two opposite answers out of the same host in the same run. Without this, a rewrite that
# silently did nothing would still look fine on a dev box with no /proc at all (macOS), where
# every read fails and the "unreadable" expectations pass for the wrong reason.
mkproc 0 <<'EOF'
MemTotal:       999999999 kB
EOF
box_is_roomy && _live=roomy || _live=constrained
assert_eq "roomy" "$_live" "L3: мок читается — гигантский MemTotal даёт roomy"

mkproc 0 <<'EOF'
MemTotal:              1 kB
EOF
box_is_roomy && _live=roomy || _live=constrained
assert_eq "constrained" "$_live" "L3: мок читается — крошечный MemTotal даёт constrained"

# --- Scenarios ---------------------------------------------------------------------------
# 1. The field box. Strict accounting pins the ceiling to its 64 MiB floor while the pool
#    floor alone (512 x 64 KB = 32 MB) takes half of it — this is the state that OOM-looped.
mkproc 2 <<'EOF'
MemTotal:         512205 kB
MemFree:           56218 kB
MemAvailable:     144077 kB
SwapTotal:             0 kB
CommitLimit:      256094 kB
Committed_AS:     200000 kB
EOF
assert_eq "64MiB"          "$(compute_go_memlimit)"                    "1. RT-AX58U без swap: потолок на полу 64MiB"
assert_eq "512"            "$(compute_pool_cap "$(compute_go_memlimit)")" "1. RT-AX58U без swap: кап пула 512"
assert_eq "floor|64|512|0" "$(mem_squeeze_state)"                      "1. RT-AX58U без swap: вердикт floor"

# go_tune_desc must quote what the launcher would really apply. Asserting the prose would
# churn on every wording edit; asserting that it contains the live values enforces the
# invariant its own header claims ("the wording cannot drift from what launch_daemon applies").
_d=$(go_tune_desc)
assert_contains "$_d" "$(compute_go_memlimit)"                      "1. go_tune_desc называет действующий GOMEMLIMIT"
assert_contains "$_d" "$(compute_pool_cap "$(compute_go_memlimit)")" "1. go_tune_desc называет действующий кап пула"

# 2. The same box after a 1 GB swap file. Swap raises CommitLimit, which is what the ceiling
#    is cut from — the banner clears and the daemon gets its RAM-based ceiling back.
mkproc 2 <<'EOF'
MemTotal:         512205 kB
MemFree:           56218 kB
MemAvailable:     144077 kB
SwapTotal:       1048576 kB
CommitLimit:     1304670 kB
Committed_AS:     258662 kB
EOF
assert_eq "190MiB" "$(compute_go_memlimit)"                    "2. та же коробка со swap 1 ГБ: потолок 190MiB"
assert_eq "760"    "$(compute_pool_cap "$(compute_go_memlimit)")" "2. та же коробка со swap 1 ГБ: кап пула 760"
assert_eq ""       "$(mem_squeeze_state)"                      "2. та же коробка со swap 1 ГБ: предупреждения нет"

# 3. Strict accounting, but the commit headroom is genuinely large. The clamp applies and
#    lands above the floor, so this is NOT a squeeze.
mkproc 2 <<'EOF'
MemTotal:         512205 kB
MemFree:          300000 kB
MemAvailable:     400000 kB
SwapTotal:             0 kB
CommitLimit:      256094 kB
Committed_AS:      40000 kB
EOF
assert_eq "105MiB" "$(compute_go_memlimit)" "3. строгий overcommit с запасом: потолок 105MiB"
assert_eq "512"    "$(compute_pool_cap "$(compute_go_memlimit)")" "3. строгий overcommit с запасом: кап пула 512"
assert_eq ""       "$(mem_squeeze_state)"   "3. строгий overcommit с запасом: предупреждения нет"

# 4. An ordinary 512 MB box without strict accounting: the commit clamp never runs.
mkproc 0 <<'EOF'
MemTotal:         512205 kB
MemFree:           56218 kB
MemAvailable:     144077 kB
SwapTotal:             0 kB
CommitLimit:      256094 kB
Committed_AS:     200000 kB
EOF
assert_eq "190MiB" "$(compute_go_memlimit)" "4. обычная 512MB-коробка: потолок 190MiB"
assert_eq "760"    "$(compute_pool_cap "$(compute_go_memlimit)")" "4. обычная 512MB-коробка: кап пула 760"
assert_eq ""       "$(mem_squeeze_state)"   "4. обычная 512MB-коробка: предупреждения нет"

# 5. A roomy box is exempt from the whole tune — empty output means "leave the Go runtime
#    alone", and the launcher then sets no env at all.
mkproc 0 <<'EOF'
MemTotal:        2028000 kB
MemFree:          900000 kB
MemAvailable:    1400000 kB
SwapTotal:             0 kB
CommitLimit:     1014000 kB
Committed_AS:     400000 kB
EOF
assert_eq "" "$(compute_go_memlimit)" "5. просторная 2GB-коробка: тюнинг не применяется"
assert_eq "" "$(compute_pool_cap "$(compute_go_memlimit)")" "5. просторная 2GB-коробка: кап пула не выставляется"
assert_eq "" "$(mem_squeeze_state)"   "5. просторная 2GB-коробка: предупреждения нет"

# 6. Kernel 2.6 meminfo: no MemAvailable (fall back to MemFree), no SwapTotal. Must degrade,
#    not crash — this is the RT-AC68U class of box.
mkproc 0 <<'EOF'
MemTotal:         256000 kB
MemFree:           60000 kB
EOF
assert_eq "96MiB" "$(compute_go_memlimit)" "6. meminfo без MemAvailable/SwapTotal: потолок 96MiB (нижний зажим)"
assert_eq "512"   "$(compute_pool_cap "$(compute_go_memlimit)")" "6. meminfo без MemAvailable/SwapTotal: кап пула 512"
assert_eq ""      "$(mem_squeeze_state)"   "6. meminfo без MemAvailable/SwapTotal: предупреждения нет"

# 7. Nothing readable at all. Every helper must return empty quietly; the launcher then
#    leaves the Go environment untouched, which is the pre-1.3.13 status quo.
mkproc none < /dev/null
rm -f "$PM/meminfo"
assert_eq "" "$(compute_go_memlimit)" "7. нечитаемый /proc: потолок не вычисляется"
assert_eq "" "$(compute_pool_cap "$(compute_go_memlimit)")" "7. нечитаемый /proc: кап пула не выставляется"
assert_eq "" "$(mem_squeeze_state)"   "7. нечитаемый /proc: предупреждения нет"

t_done
