#!/bin/sh
# Syntax safety net.
#
# Until this suite existed, nothing anywhere parsed the product before it shipped: release.yml
# only greps addon/amneziawg.sh for a version string and then packages it, so a typo in ~516 KB
# of shell — or in the ~348 KB of JavaScript inside the page — would reach a release unnoticed
# and brick the addon on every router that took the update. This is the cheapest check in the
# repo and the one with the largest blast radius.
#
# The shell scripts are parsed by every shell we can find, because the target is busybox ash
# and dash only approximates it. Neither is the router's own (older) busybox build, so a green
# tick here raises confidence without replacing the on-router check.
#
# Run standalone:  sh tests/syntax.sh

TESTS_DIR=$(dirname "$0")
. "$TESTS_DIR/lib.sh"

ADDON="$TESTS_DIR/../addon"
TMP=${AWG_TEST_SANDBOX:-$(mktemp -d)}/syntax.$$
mkdir -p "$TMP" || t_bail "не удалось создать песочницу $TMP"
[ -n "${AWG_TEST_SANDBOX:-}" ] || trap 'rm -rf "$TMP"' EXIT INT TERM

SH_FILES="amneziawg.sh amneziawg_server.sh"
JS_FILES="amneziawg_widget.js awg_qr.js"

# Which parsers are available. require_tool skips locally and bails in CI, so a runner image
# that quietly drops busybox turns the build red instead of silently narrowing the check.
SHELLS=""
require_tool dash    && SHELLS="$SHELLS dash"
require_tool busybox && SHELLS="$SHELLS busybox_ash"
require_tool node    && HAVE_NODE=1 || HAVE_NODE=0

[ -n "$SHELLS" ] || t_bail "не найдено ни одной оболочки для проверки синтаксиса (нужен dash или busybox)"

# 2 shell files per shell, plus 2 standalone JS files and the page block when node is present.
_n=0
for _s in $SHELLS; do _n=$((_n + 2)); done
[ "$HAVE_NODE" = 1 ] && _n=$((_n + 3))
t_plan "$_n"
t_diag "оболочки: $SHELLS; node: $HAVE_NODE"

# $1 shell token, $2 file
check_sh(){
    case "$1" in
        dash)        _out=$(dash -n "$2" 2>&1) ;;
        busybox_ash) _out=$(busybox ash -n "$2" 2>&1) ;;
        *)           t_bail "неизвестная оболочка: $1" ;;
    esac
    assert_eq "" "$_out" "$1 -n $(basename "$2")"
}

for _s in $SHELLS; do
    for _f in $SH_FILES; do
        [ -f "$ADDON/$_f" ] || t_bail "нет файла $ADDON/$_f"
        check_sh "$_s" "$ADDON/$_f"
    done
done

if [ "$HAVE_NODE" = 1 ]; then
    for _f in $JS_FILES; do
        [ -f "$ADDON/$_f" ] || t_bail "нет файла $ADDON/$_f"
        _out=$(node --check "$ADDON/$_f" 2>&1)
        assert_eq "" "$_out" "node --check $_f"
    done

    # The page's inline block. Its single ASP tag (`var custom_settings = <% ... %>;`) is not
    # JavaScript, so it is replaced by an empty object before parsing — see the same reasoning
    # in tests/diag_poll.js, which loads this block for real.
    node -e '
        const fs = require("fs");
        const lines = fs.readFileSync(process.argv[1], "utf8").split("\n");
        const open = lines.reduce((a, l, i) => (l.trim() === "<script>" ? a.concat(i) : a), []);
        if (open.length !== 1) { console.error("ожидался один голый <script>, найдено " + open.length); process.exit(3); }
        const close = lines.findIndex((l, i) => i > open[0] && l.indexOf("</script>") !== -1);
        if (close < 0) { console.error("не найден закрывающий </script>"); process.exit(3); }
        const body = lines.slice(open[0] + 1, close).join("\n").replace(/<%[\s\S]*?%>/g, "{}");
        fs.writeFileSync(process.argv[2], body);
    ' "$ADDON/amneziawg_page.asp" "$TMP/page_block.js" || t_bail "не удалось извлечь <script> из страницы"
    _out=$(node --check "$TMP/page_block.js" 2>&1)
    assert_eq "" "$_out" "node --check <script> страницы (348 КБ, иначе не проверяется ничем)"
fi

t_done
