// Run with: node --test .github/scripts/test-diag.js
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const page = fs.readFileSync(path.join(__dirname, '../../addon/amneziawg_page.asp'), 'utf8');
const source = page.slice(page.indexOf("var awgDiagText = '';"), page.indexOf('// Diagnostics modal open/close'));
const dump = (token, body = 'CURRENT REPORT') => `${body}\n[DIAG_DONE ${token}]\n[DIAG_DONE]\n`;

function browser(options = {}) {
    let now = 100000, serial = 0, requests = 0, refused = 0;
    const queue = [], submits = [], results = [], urls = [], files = new Map();
    const fields = { amng_custom: { value: 'STALE SETTINGS' }, awg_diag_body: {}, awg_diag_note: {} };
    const button = { value: 'Diagnostics', disabled: false };
    const later = (fn, delay) => queue.push({ at: now + delay, id: ++serial, fn });
    function XHR() {}
    XHR.prototype.open = function (method, url) { this.url = url; urls.push(url); };
    XHR.prototype.send = function () {
        const spec = options.responses?.[requests++] || {};
        if (spec.error || spec.timeout) {
            later(() => spec.timeout ? this.ontimeout() : this.onerror(), spec.timeout ? this.timeout : 20);
            return;
        }
        later(() => {
            const token = submits.at(-1)?.token;
            const file = files.get(this.url.split('?')[0]);
            this.status = spec.status ?? (file ? 200 : 404);
            this.responseText = typeof spec.text === 'function' ? spec.text(token) : (spec.text ?? file ?? '<html>404</html>');
            this.onload();
        }, spec.delay ?? 20);
    };
    const context = {
        Date: { now: () => now }, Math: { random: () => 0.123456789 },
        setTimeout: later, XMLHttpRequest: XHR, T: key => key,
        awgFormBusy: () => !!options.busy, awgFormBusyRefuse: () => refused++,
        awgOpenDiag: () => {},
        document: { getElementById: key => fields[key], form: { action_script: { value: '' } } },
        awgSubmitForm: () => {
            const event = context.document.form.action_script.value;
            assert.match(event, /^start_awgdiag[a-z0-9-]+$/);
            assert.equal(fields.amng_custom.value, '');
            const token = event.slice('start_awgdiag'.length);
            assert.ok(token.length <= 48);
            const url = `/user/awg_diag_${token}.htm`;
            const submission = { token, url, at: now };
            submits.push(submission);
            if (options.onSubmit) options.onSubmit({ ...submission, files, later, number: submits.length });
            else if (!options.drop) later(() => files.set(url, dump(token)), options.publishAfter ?? 6000);
        }
    };
    vm.createContext(context);
    vm.runInContext(source, context);
    const finish = context.awgDiagFinish;
    context.awgDiagFinish = (btn, text, timedOut) => {
        finish(btn, text, timedOut);
        results.push({ at: now, timedOut, report: context.awgDiagText });
    };
    return {
        context, submits, results, urls, fields, button, files,
        run: () => context.awgRunDiag(button),
        refused: () => refused,
        untilResult(count = 1) {
            let budget = 200;
            while (queue.length && results.length < count && budget-- > 0) {
                queue.sort((a, b) => a.at - b.at || a.id - b.id);
                const next = queue.shift(); now = next.at; next.fn();
            }
            assert.equal(results.length, count, 'polling must terminate');
            assert.equal(button.disabled, false);
            return results.at(-1);
        }
    };
}

test('inline page JavaScript parses after substituting firmware ASP expressions', () => {
    let count = 0;
    for (const [, code] of page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
        if (code.trim()) { new vm.Script(code.replace(/<%[\s\S]*?%>/g, 'null')); count++; }
    }
    assert.ok(count > 0);
});

test('first run and a stale legacy file both return the requested report', () => {
    for (const oldFile of [false, true]) {
        const b = browser();
        if (oldFile) b.files.set('/user/awg_diag.htm', 'OLD REPORT\n[DIAG_DONE]\n');
        b.run();
        const result = b.untilResult();
        assert.equal(result.report, 'CURRENT REPORT');
        assert.equal(result.timedOut, false);
        assert.ok(result.at >= b.submits[0].at + 6000);
        assert.ok(b.urls.every(url => url.startsWith(b.submits[0].url + '?')));
    }
});

test('HTTP 500 and a foreign completion marker are ignored', () => {
    const b = browser({ responses: [
        { status: 500, text: token => dump(token, 'HTTP ERROR') },
        { status: 200, text: dump('previous-run', 'OLD REPORT') }
    ] });
    b.run();
    assert.equal(b.untilResult().report, 'CURRENT REPORT');
});

test('a report published during several request timeouts is accepted on recovery', () => {
    const b = browser({ responses: [{ timeout: true }, { timeout: true }, { error: true }] });
    b.run();
    const result = b.untilResult();
    assert.equal(result.report, 'CURRENT REPORT');
    assert.equal(result.timedOut, false);
    assert.ok(result.at > b.submits[0].at + 10000);
});

test('a dropped event times out without exposing old reports or error pages', () => {
    const b = browser({ drop: true, responses: [
        { status: 200, text: dump('previous-run', 'OLD REPORT') },
        { status: 500, text: '<html>SERVER ERROR</html>' }
    ] });
    b.run();
    assert.equal(b.untilResult().report, '');
    assert.equal(b.results[0].timedOut, true);
    assert.equal(b.fields.awg_diag_body.textContent, 'DIAG_TIMEOUT');
});

test('continuous network failure terminates and restores the button', () => {
    const b = browser({ drop: true, responses: Array.from({ length: 20 }, () => ({ timeout: true })) });
    b.run();
    assert.equal(b.untilResult().timedOut, true);
    assert.equal(b.button.value, 'Diagnostics');
});

test('an in-flight settings save prevents all diagnostic requests', () => {
    const b = browser({ busy: true });
    b.run();
    assert.equal(b.refused(), 1);
    assert.equal(b.submits.length, 0);
    assert.equal(b.urls.length, 0);
    assert.equal(b.fields.amng_custom.value, 'STALE SETTINGS');
});

test('retry ignores a previous slow run completing before or after the new run', () => {
    for (const firstDelay of [50000, 55000]) {
        const b = browser({ onSubmit({ token, url, later, files, number }) {
            later(() => files.set(url, dump(token, `REPORT ${number}`)), number === 1 ? firstDelay : 8000);
        } });
        b.run();
        assert.equal(b.untilResult().timedOut, true);
        b.run();
        assert.equal(b.untilResult(2).report, 'REPORT 2');
        assert.notEqual(b.submits[0].url, b.submits[1].url);
    }
});

test('footer must be complete and at the end, including when a marker appears in the body', () => {
    const b = browser();
    assert.equal(b.context.awgDiagMarkOf(dump('valid-token')), 'valid-token');
    assert.equal(b.context.awgDiagMarkOf(dump('valid-token').replace(/\n/g, '\r\n')), 'valid-token');
    assert.equal(b.context.awgDiagMarkOf('[DIAG_DONE valid-token]\nmore output'), null);
    assert.equal(b.context.awgDiagMarkOf(dump('valid-token') + 'more output'), null);
    assert.equal(b.context.awgDiagMarkOf('legacy\n[DIAG_DONE]\n'), null);
    const fake = browser({ drop: true, responses: [{ status: 200, text: token => dump(token) + 'still writing' }] });
    fake.run();
    assert.equal(fake.untilResult().timedOut, true);
});
