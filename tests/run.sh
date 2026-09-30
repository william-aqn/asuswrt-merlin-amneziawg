#!/bin/sh
# Entry point for the whole suite:  ./tests/run.sh
#
# Plain POSIX sh, no framework, no dependency beyond coreutils — matching the rest of the
# repository, which has no build system and no package manager.
#
# The suite list below is LITERAL on purpose. Discovering suites with a glob would mean that
# renaming or losing a file silently reduces coverage to zero while the run stays green, which
# is the exact failure this harness is built to make impossible. In a repo this small the
# explicit list doubles as documentation.
#
# The behavioural shell suite is run once per available shell. That is the highest-value thing
# here: it exercises the real product code under busybox ash, which is what the router runs,
# rather than only under whatever the developer's /bin/sh happens to be.
#
# Exit status is 0 only if every suite exited 0 AND every plan matched its result count AND no
# suite printed "not ok" or "Bail out!". Set AWG_TEST_KEEP=1 to keep the sandbox for debugging.

set -eu

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$TESTS_DIR/.."

AWG_TEST_SANDBOX=$(mktemp -d)
export AWG_TEST_SANDBOX
cleanup(){ [ -n "${AWG_TEST_KEEP:-}" ] || rm -rf "$AWG_TEST_SANDBOX"; }
trap cleanup EXIT INT TERM

TOTAL=0
BAD=0
SUMMARY=""

# $1 label, then the command to run the suite.
run_suite(){
    _label=$1; shift
    TOTAL=$((TOTAL + 1))
    printf '\n=== %s ===\n' "$_label"
    _out=$("$@" 2>&1) && _rc=0 || _rc=$?
    printf '%s\n' "$_out"

    _plan=$(printf '%s\n' "$_out" | sed -n 's/^1\.\.\([0-9][0-9]*\)$/\1/p' | head -1)
    _ok=$(printf '%s\n' "$_out" | grep -c '^ok ' || true)
    _notok=$(printf '%s\n' "$_out" | grep -c '^not ok ' || true)
    _bail=$(printf '%s\n' "$_out" | grep -c '^Bail out!' || true)

    _why=""
    [ "$_rc" -eq 0 ]            || _why="$_why exit=$_rc"
    [ "${_bail:-0}" -eq 0 ]     || _why="$_why bail"
    [ "${_notok:-0}" -eq 0 ]    || _why="$_why not-ok=$_notok"
    if [ -z "$_plan" ]; then
        _why="$_why нет строки плана"
    elif [ $(( ${_ok:-0} + ${_notok:-0} )) -ne "$_plan" ]; then
        # An early exit or a loop whose body never ran lands here even when nothing printed
        # "not ok" — a suite that quietly stopped testing must not read as success.
        _why="$_why план=$_plan выполнено=$(( ${_ok:-0} + ${_notok:-0} ))"
    fi

    if [ -n "$_why" ]; then
        BAD=$((BAD + 1))
        SUMMARY="$SUMMARY
  ПРОВАЛ  $_label —$_why"
    else
        SUMMARY="$SUMMARY
  ok      $_label ($_ok проверок)"
    fi
}

have(){ type "$1" >/dev/null 2>&1; }

# A tool missing locally narrows the run; missing in CI is a failure, so the day a runner image
# drops one the build goes red instead of quietly testing less.
missing_tool(){
    if [ -n "${CI:-}" ]; then
        printf 'ОШИБКА: в CI нет обязательного инструмента: %s\n' "$1" >&2
        exit 1
    fi
    printf 'SKIP: %s не установлен — локальный прогон будет уже\n' "$1"
}

# 1) Syntax net. Runs under the shell we were invoked with; it drives the other parsers itself.
run_suite "syntax.sh" sh tests/syntax.sh

# 2) Behavioural shell suite, once per interpreter.
_ran_mem=0
if have dash; then
    run_suite "mem_envelope.sh [dash]" dash tests/mem_envelope.sh
    _ran_mem=1
else
    missing_tool dash
fi
if have busybox; then
    run_suite "mem_envelope.sh [busybox ash]" busybox ash tests/mem_envelope.sh
    _ran_mem=1
else
    missing_tool busybox
fi
[ "$_ran_mem" = 1 ] || { printf 'ОШИБКА: не нашлось ни одной оболочки для поведенческого набора\n' >&2; exit 1; }

# 3) Page-polling suite.
if have node; then
    run_suite "diag_poll.js" node tests/diag_poll.js
else
    missing_tool node
fi

printf '\n=== итог ===%s\n' "$SUMMARY"
if [ "$BAD" -eq 0 ]; then
    printf '\nвсе наборы пройдены (%d)\n' "$TOTAL"
else
    printf '\nпровалено наборов: %d из %d\n' "$BAD" "$TOTAL"
fi
[ "$BAD" -eq 0 ]
