'use strict';
// Diag-polling suite: awgRunDiag / awgDiagSubmit / awgDiagIsFresh / awgDiagMarkOf, driven by
// a virtual clock and a scripted XMLHttpRequest.
//
// WHAT THIS GUARDS
// The "Diagnostics" button used to hand back the PREVIOUS run's report. The page polled
// /www/user/awg_diag.htm for a bare [DIAG_DONE] right after submitting the event; that marker
// is identical between runs, so the already-finished file answered the first poll — before the
// backend had even started. Field 2026-09-28: a report downloaded as "...-20260928-220746.txt"
// carried a body dated Sep 23, and only the journal tail was fresh, which is what hid it. Only
// the first dump of each boot was ever honest, because /www/user is cleared on reboot.
//
// THE SEAM
// The whole inline <script> block of the page is loaded into a vm context, not a hand-picked
// set of functions. That way the scenarios exercise the real awgDiagFinish, the real
// awgDiagMarkOf regex and the real T() against the real i18n tables — a suite that stubbed
// awgDiagFinish could not notice the marker-stripping regex regressing.
//
// Two stubs are installed AFTER load — awgSubmitForm and awgFormBusy — and each one first
// asserts the symbol it replaces exists. Overriding a name the page no longer has would
// otherwise turn the form-lock scenario into a test of a function nothing calls, and it would
// pass. That boundary is deliberate: the suite proves "the page asked the form to submit", not
// "the form submitted correctly" (the real awgSubmitForm does custom_settings chunking, which
// is a different suite's problem).
//
// Run standalone:  node tests/diag_poll.js

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');
const PAGE = path.join(ROOT, 'addon', 'amneziawg_page.asp');
const SCRIPT = path.join(ROOT, 'addon', 'amneziawg.sh');

let planned = 0, run = 0, fails = 0;
const plan = n => { planned = n; console.log('1..' + n); };
const diag = s => console.log('# ' + s);
const bail = s => { console.log('Bail out! ' + s); process.exit(2); };
const result = (ok, label) => {
    run++;
    console.log((ok ? 'ok ' : 'not ok ') + run + ' - ' + label);
    if (!ok) fails++;
};
const assertEq = (expected, actual, label) => {
    const ok = expected === actual;
    result(ok, label);
    if (!ok) { diag('  ожидалось: [' + expected + ']'); diag('  получено:  [' + actual + ']'); }
};
const done = () => {
    if (run !== planned) bail('выполнено ' + run + ' проверок из заявленных ' + planned);
    if (fails) diag('провалено проверок: ' + fails);
    process.exit(fails ? 1 : 0);
};

plan(11);

// --- L2 for the page: extract the one inline block, accounting for what we assume ---------
const pageLines = fs.readFileSync(PAGE, 'utf8').split('\n');
const openIdx = pageLines.reduce((acc, l, i) => (l.trim() === '<script>' ? acc.concat(i) : acc), []);
if (openIdx.length !== 1) bail('шов: ожидался ровно один голый <script>, найдено ' + openIdx.length);
const start = openIdx[0];
const close = pageLines.findIndex((l, i) => i > start && l.indexOf('</script>') !== -1);
if (close < 0) bail('шов: не найден закрывающий </script> после строки ' + (start + 1));
let block = pageLines.slice(start + 1, close).join('\n');
if (close - start < 4000) bail('шов: блок всего ' + (close - start) + ' строк — извлеклось не то');

// The block carries exactly one ASP tag (line 384, `var custom_settings = <% ... %>;`).
// Substituting an empty object keeps the load-time initialisers working; substituting a
// number would break the IIFE that prunes awg_ipk_* keys out of it.
const aspTags = block.match(/<%[\s\S]*?%>/g) || [];
if (aspTags.length !== 1) bail('шов: внутри <script> ожидался один тег <% %>, найдено ' + aspTags.length);
if (aspTags[0].indexOf('get_custom_settings') === -1) bail('шов: тег <% %> внутри <script> больше не get_custom_settings: ' + aspTags[0]);
block = block.replace(/<%[\s\S]*?%>/g, '{}');

// --- virtual clock + scripted XHR ---------------------------------------------------------
let NOW = 0;
let timers = [];
const server = { text: '', publishAt: Infinity, newText: '', failUntil: -1 };

function advance(ms) {
    const target = NOW + ms;
    while (NOW < target) {
        NOW += 10;
        if (NOW >= server.publishAt) server.text = server.newText;
        const due = timers.filter(t => t.at <= NOW);
        timers = timers.filter(t => t.at > NOW);
        due.forEach(t => t.fn());
    }
}

let submitted = 0, refused = 0, busyFrom = Infinity;
let finished; // {txt, timedOut} once awgDiagFinish runs

function FakeXHR() {}
FakeXHR.prototype.open = function (m, u) { this.url = u; };
FakeXHR.prototype.send = function () {
    const self = this;
    timers.push({ at: NOW + 20, fn: function () {          // ~20 ms of "network"
        if (NOW <= server.failUntil) { if (self.ontimeout) self.ontimeout(); return; }
        self.responseText = server.text;
        if (self.onload) self.onload();
    } });
};

const el = () => ({ value: '', textContent: '', innerHTML: '', style: {}, scrollTop: 0, disabled: false });
const sandbox = {
    console,
    window: {},
    navigator: { userAgent: 'test' },
    location: { href: '' },
    localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} },
    document: {
        form: { action_script: { value: '' }, submit: () => {} },
        getElementById: () => el(),
        querySelector: () => null,
        querySelectorAll: () => [],
        addEventListener: () => {},
        createElement: () => el(),
        head: { appendChild: () => {} },
        documentElement: { appendChild: () => {} },
        body: { appendChild: () => {} }
    },
    XMLHttpRequest: FakeXHR,
    setTimeout: (fn, ms) => { timers.push({ at: NOW + (ms || 0), fn: fn }); },
    clearTimeout: () => {},
    setInterval: () => 0,
    clearInterval: () => {},
    Date: { now: () => NOW },
    alert: () => {},
    confirm: () => true,
    httpApi: { nvramGet: () => ({}) }
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;

const ctx = vm.createContext(sandbox);
try {
    // lineOffset makes any stack trace point at real .asp line numbers.
    new vm.Script(block, { filename: 'amneziawg_page.asp', lineOffset: start + 1 }).runInContext(ctx);
} catch (e) {
    bail('шов: блок <script> страницы не выполнился: ' + e.message);
}

// --- L1: every symbol the suite leans on, including the two it replaces --------------------
['awgRunDiag', 'awgDiagSubmit', 'awgDiagIsFresh', 'awgDiagMarkOf', 'awgDiagFinish',
 'awgOpenDiag', 'awgCloseDiag', 'T', 'awgFormBusy', 'awgSubmitForm', 'awgFormBusyRefuse']
    .forEach(n => { if (typeof ctx[n] !== 'function') bail('шов: на странице нет функции ' + n); });

ctx.awgSubmitForm = () => { submitted++; };
ctx.awgFormBusy = () => NOW >= busyFrom;
ctx.awgFormBusyRefuse = () => { refused++; };
ctx.awgOpenDiag = () => {};
ctx.awgCloseDiag = () => {};
const realFinish = ctx.awgDiagFinish;
ctx.awgDiagFinish = function (btn, txt, timedOut) {
    finished = { txt: txt, timedOut: timedOut };
    return realFinish.call(ctx, btn, txt, timedOut);   // keep exercising the real stripping
};

// --- L3: prove the virtual clock is in control, not the real one --------------------------
// If setTimeout had not been stubbed, the polling scenarios would hang or race instead of
// failing cleanly, and every later result would be meaningless.
let ticked = false;
ctx.setTimeout(() => { ticked = true; }, 1500);
advance(1400);
assertEq(false, ticked, 'L3: виртуальные часы управляют таймерами (до срока не сработал)');
advance(200);
assertEq(true, ticked, 'L3: виртуальные часы управляют таймерами (после срока сработал)');

// --- scenarios -----------------------------------------------------------------------------
const OLD_BARE = 'date: Sep 23 (СТАРЫЙ)\n[DIAG_DONE]';
const FRESH = 'date: Sep 28 (НОВЫЙ)\n[DIAG_DONE 1700500000-222]\n[DIAG_DONE]';

function scenario(opts) {
    NOW = 0; timers = []; finished = undefined; submitted = 0; refused = 0;
    busyFrom = opts.busyFrom === undefined ? Infinity : opts.busyFrom;
    server.text = opts.initial;
    server.publishAt = opts.publishAt;
    server.newText = opts.fresh || FRESH;
    server.failUntil = opts.failPreUntil === undefined ? -1 : opts.failPreUntil;
    ctx.awgRunDiag(null);
    advance(60000);
    if (refused) return 'ОТКАЗ';
    if (!finished) return 'не завершилось';
    return finished.txt === null ? 'ТАЙМАУТ-БЕЗ-ОТЧЁТА' : String(finished.txt).split('\n')[0];
}

assertEq('date: Sep 28 (НОВЫЙ)',
    scenario({ initial: OLD_BARE, publishAt: 6000 }),
    '1. полевой случай: старый дамп на коробке, новый публикуется через 6 с');

assertEq('date: Sep 28 (НОВЫЙ)',
    scenario({ initial: '', publishAt: 4000 }),
    '2. первый запуск после перезагрузки: файла ещё нет');

assertEq('date: Sep 28 (НОВЫЙ)',
    scenario({ initial: OLD_BARE, publishAt: 8000, failPreUntil: 100 }),
    '3. предчтение не удалось: база берётся с первого опроса');

// The one that matters most after the review: with no baseline AND a dropped event, the only
// thing on disk is the previous dump. It must never be handed over.
assertEq('ТАЙМАУТ-БЕЗ-ОТЧЁТА',
    scenario({ initial: OLD_BARE, publishAt: Infinity, failPreUntil: 100 }),
    '4. предчтение не удалось и событие потеряно: старый отчёт НЕ отдаётся');

assertEq('ТАЙМАУТ-БЕЗ-ОТЧЁТА',
    scenario({ initial: OLD_BARE, publishAt: Infinity }),
    '5. бэкенд не ответил вовсе: старый отчёт НЕ отдаётся');

const refusal = scenario({ initial: OLD_BARE, publishAt: 6000, busyFrom: 10 });
assertEq('ОТКАЗ|0', refusal + '|' + submitted,
    '6. сохранение стартовало во время предчтения: отказ и НИ ОДНОЙ отправки формы');

// --- the paired-marker contract -------------------------------------------------------------
// A browser tab cached on pre-1.5.27 JS looks for the literal [DIAG_DONE] and would never
// match [DIAG_DONE <token>]: it would wait out its full 45 s timeout and then render the dump
// with a "may be incomplete" warning. The backend therefore emits the tokenized marker FIRST
// (the current page's regex takes the first match, so it still reads the token) and a bare one
// second. Asserting this here keeps the guarantee without pinning the suite to a git revision
// so it can replay the old page — that code will never change again, and a test that can only
// ever pass is a proof already delivered, not a regression test.
const shell = fs.readFileSync(SCRIPT, 'utf8');
const tokenIdx = shell.indexOf('echo "[DIAG_DONE $(date +%s)-$$]"');
const bareIdx = shell.indexOf('echo "[DIAG_DONE]"');
assertEq(true, tokenIdx !== -1, '7. бэкенд печатает маркер с токеном');
assertEq(true, bareIdx !== -1 && bareIdx > tokenIdx,
    '8. бэкенд печатает голый маркер ПОСЛЕ токена (иначе старая вкладка читала бы пустой токен)');
assertEq(' 1700500000-222', ctx.awgDiagMarkOf(FRESH),
    '9. на паре маркеров страница читает именно токен, а не пустую строку');

done();
