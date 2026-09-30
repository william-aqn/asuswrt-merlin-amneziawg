#!/bin/sh
# Shared helpers for the suites in tests/. POSIX sh only: the shell suites run under dash
# AND under busybox ash, because busybox ash is what the router actually uses.
#
# Output is TAP-shaped — "1..N" first, then "ok N - label" / "not ok N - label", diagnostics
# on "#" lines, "Bail out!" for broken plumbing. Nothing consumes TAP; run.sh does its own
# parsing. The shape is chosen because it stays readable in a raw Actions log.
#
# ---------------------------------------------------------------------------------------
# THE SEAM
#
# The shell suites reach the product by SOURCING it in lib mode, exactly the way
# addon/amneziawg_server.sh already does (`AWG_LIB_MODE=1`, source, then override the
# instance globals). That is deliberate: the seam is not invented for tests, it is a
# contract the product already ships and the AWG-server role already depends on. Nothing in
# production changes, and if lib-mode sourcing ever breaks, the server role breaks with it.
#
# Sourcing does run the top level first (addon/amneziawg.sh:123-180): it unsets
# LD_LIBRARY_PATH, rewrites PATH, runs a grep/sed/awk self-test that caches its verdict, and
# probes ipset. sandbox_script() below contains that: the cache path is a variable
# (AWG_PATH_SANE_CACHE, :138) so it is redirected into the sandbox and pre-seeded with "1",
# which keeps the failure branch — logger, /tmp/.awg_path_warned, the UI-log append — from
# ever running. Verified hermetic: a full run touches nothing outside its temp dir.
#
# ---------------------------------------------------------------------------------------
# WHY THERE ARE FOUR SEAM GUARDS
#
# A harness that reaches into code through names and path literals will eventually stop
# reaching anything. The failure that matters is not "breaks" — it is "quietly tests nothing
# and still reports success". Four independent guards, each catching a different break:
#
#   L1 presence   — a renamed function is named, before and after sourcing.
#   L2 accounting — the /proc rewrite must bite (>=1 substitution) and leave ZERO surviving
#                   literals, so a reshaped path can never silently fall through to the real
#                   /proc of the machine.
#   L3 liveness   — before any real assertion, prove the mock is the input by getting two
#                   OPPOSITE answers out of the same host. This is the guard that actually
#                   closes the hole: on a dev box with no /proc at all (macOS), a completely
#                   dead rewrite would still produce the "unreadable /proc" answer and look
#                   fine, so the negative scenario alone proves nothing.
#   L4 counting   — the plan line, the assertion total and the suite list are all checked, so
#                   an early exit or a loop that never ran cannot pass as green.
#
# Corollary rule, the one that is easy to forget: ANY stub that overrides a real symbol must
# first assert the symbol exists. Overriding a name the product no longer has is a hard
# error, not a silent no-op — otherwise renaming e.g. awgFormBusy turns the form-lock
# scenario into a test of a function the page never calls, and it passes.

T_PLANNED=0
T_RUN=0
T_FAILS=0

t_plan(){
    T_PLANNED=$1
    printf '1..%d\n' "$1"
}

t_diag(){ printf '# %s\n' "$*"; }

# Broken plumbing: everything after it would be noise, so stop the suite now. Exit 2 keeps it
# distinguishable from an ordinary failed expectation (exit 1).
t_bail(){
    printf 'Bail out! %s\n' "$*"
    exit 2
}

_t_result(){
    T_RUN=$((T_RUN + 1))
    if [ "$1" = ok ]; then
        printf 'ok %d - %s\n' "$T_RUN" "$2"
    else
        T_FAILS=$((T_FAILS + 1))
        printf 'not ok %d - %s\n' "$T_RUN" "$2"
    fi
}

# $1 expected, $2 actual, $3 label
assert_eq(){
    if [ "$1" = "$2" ]; then
        _t_result ok "$3"
    else
        _t_result notok "$3"
        t_diag "  ожидалось: [$1]"
        t_diag "  получено:  [$2]"
    fi
}

# $1 haystack, $2 needle, $3 label
assert_contains(){
    case "$1" in
        *"$2"*) _t_result ok "$3" ;;
        *) _t_result notok "$3"; t_diag "  нет подстроки: [$2]"; t_diag "  в: [$1]" ;;
    esac
}

# Close the suite: the plan must match what actually ran, so a scenario that died halfway or
# a loop whose body never executed (the documented `set -f` glob hazard bit this project
# before) turns red instead of passing with fewer checks.
t_done(){
    if [ "$T_RUN" -ne "$T_PLANNED" ]; then
        printf 'Bail out! выполнено %d проверок из заявленных %d — набор оборвался или цикл не отработал\n' \
            "$T_RUN" "$T_PLANNED"
        exit 2
    fi
    [ "$T_FAILS" -eq 0 ] || t_diag "провалено проверок: $T_FAILS"
    [ "$T_FAILS" -eq 0 ]
}

# `type`, not `command -v`: CLAUDE.md documents command -v as missing on the target busybox,
# and matching the house habit keeps the harness readable to the same eyes.
have_tool(){ type "$1" >/dev/null 2>&1; }

# NB every `grep -c` below is wrapped in `|| true`, not `|| echo 0`: grep -c already prints
# "0" on no match AND exits 1, so the echo would append a second line and every numeric test
# downstream would blow up with "Illegal number: 0\n0".

# A tool missing locally is a skip; missing in CI is a failure. Otherwise the day a runner
# image drops busybox, the most valuable check in the suite disappears while CI stays green.
require_tool(){
    have_tool "$1" && return 0
    if [ -n "${CI:-}" ]; then
        t_bail "в CI нет обязательного инструмента: $1"
    fi
    t_diag "SKIP: $1 не установлен (локальный прогон; в CI это было бы ошибкой)"
    return 1
}

# --- L1: the symbol must exist in the source, by name, before we rely on it ---------------
# $1 file, then one or more shell function names.
seam_require_sh_funcs(){
    _sr_file=$1; shift
    [ -f "$_sr_file" ] || t_bail "нет файла $_sr_file"
    for _sr_n in "$@"; do
        _sr_c=$(grep -c "^${_sr_n}()" "$_sr_file" 2>/dev/null || true)
        [ "$_sr_c" = 1 ] || t_bail "шов: в $_sr_file ожидалось одно объявление ${_sr_n}(), найдено $_sr_c — переименовали? тест перестал бы что-либо проверять"
    done
}

# L1, after sourcing: the name must now be a live function in this shell.
seam_require_loaded(){
    for _sl_n in "$@"; do
        _sl_t=$(type "$_sl_n" 2>/dev/null) || t_bail "шов: после source нет функции $_sl_n"
        case "$_sl_t" in
            *function*) : ;;
            *) t_bail "шов: $_sl_n загрузился, но это не функция: $_sl_t" ;;
        esac
    done
}

# --- L2: build the sandboxed copy and account for every rewrite --------------------------
# $1 source script, $2 destination copy, $3 mock dir (must NOT contain "/proc/" in its path,
# or the survivor check below would count the rewritten paths as survivors), $4 sandbox tmp.
sandbox_script(){
    _ss_src=$1; _ss_dst=$2; _ss_proc=$3; _ss_tmp=$4
    case "$_ss_proc" in
        */proc/*) t_bail "каталог-мок $_ss_proc содержит /proc/ — проверка выживших литералов стала бы бессмысленной" ;;
    esac
    for _ss_lit in /proc/meminfo /proc/sys/vm/overcommit_memory; do
        _ss_n=$(grep -c "$_ss_lit" "$_ss_src" 2>/dev/null || true)
        [ "${_ss_n:-0}" -ge 1 ] || t_bail "шов: в $_ss_src нет ни одного вхождения $_ss_lit — подменять нечего"
    done
    sed -e "s#/proc/sys/vm/overcommit_memory#${_ss_proc}/overcommit_memory#g" \
        -e "s#/proc/meminfo#${_ss_proc}/meminfo#g" \
        -e "s#^AWG_PATH_SANE_CACHE=.*#AWG_PATH_SANE_CACHE=${_ss_tmp}/.awg_path_sane#" \
        "$_ss_src" > "$_ss_dst" || t_bail "не удалось собрать песочную копию $_ss_dst"
    # The strong half: zero survivors. A path written as ${PROC}/meminfo or /proc//meminfo
    # would slip past the rewrite and make the suite read the runner's real /proc.
    for _ss_lit in /proc/meminfo /proc/sys/vm/overcommit_memory; do
        _ss_left=$(grep -c "$_ss_lit" "$_ss_dst" 2>/dev/null || true)
        [ "${_ss_left:-0}" -eq 0 ] || t_bail "шов: в копии осталось ${_ss_left} ссылок на настоящий $_ss_lit"
    done
    grep -q "^AWG_PATH_SANE_CACHE=${_ss_tmp}/" "$_ss_dst" \
        || t_bail "шов: AWG_PATH_SANE_CACHE не перенаправлен в песочницу — прогон писал бы в /tmp"
    # Pre-seed the verdict so the coreutils self-test branch (logger, /tmp/.awg_path_warned,
    # the UI-log append) never runs.
    echo 1 > "${_ss_tmp}/.awg_path_sane"
}
