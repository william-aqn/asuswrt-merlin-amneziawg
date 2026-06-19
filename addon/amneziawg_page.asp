<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>AmneziaWG</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<style>
.awg-status {
    padding: 8px 16px;
    border-radius: 4px;
    font-weight: bold;
    display: inline-block;
    font-size: 13px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
}
.awg-status.running {
    background: #1a6e2e;
    color: #fff;
    border: 1px solid #2a8b42;
}
.awg-status.stopped {
    background: #8b0000;
    color: #fff;
    border: 1px solid #a00;
}
.awg-status.connecting {
    background: #b8860b;
    color: #fff;
    border: 1px solid #daa520;
}

.awg-section {
    margin: 14px 0 6px 0;
    font-size: 14px;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.awg-log {
    font-family: "Courier New", "Lucida Console", monospace;
    font-size: 11px;
    padding: 10px;
    height: 180px;
    overflow-y: auto;
    border: 1px solid #444;
    border-radius: 3px;
    white-space: pre-wrap;
    word-wrap: break-word;
}

.awg-btn { margin: 0 4px; }

#awg_peers_table { width: 100%; table-layout: fixed; }
#awg_peers_table thead td {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.5px;
}
#awg_peers_table tbody td {
    padding: 6px 8px;
    font-size: 12px;
    word-break: break-all;
    overflow-wrap: anywhere;
}

#awg_client_table { width: 100%; margin-top: 6px; }
#awg_client_table td { padding: 5px 8px; }
.awg-remove-btn {
    background: transparent; border: 1px solid #a00; color: #c00;
    padding: 3px 10px; border-radius: 3px; cursor: pointer; font-size: 14px;
}
.awg-remove-btn:hover { background: #a00; color: #fff; }
.awg-add-btn, .awg-import-btn {
    cursor: pointer;
    font-size: 12px;
}
.awg-ac-wrap { position:relative; display:inline-block; width:95%; }
.awg-ac-list { position:absolute; top:100%; left:0; right:0; max-height:200px; overflow-y:auto; border:1px solid #444; border-top:none; z-index:999; display:none; border-radius:0 0 4px 4px; background:#2f3a3e; }
.awg-ac-list div { padding:4px 8px; cursor:pointer; font-size:12px; }
.awg-ac-list div:hover, .awg-ac-list div.selected { background:#666; color:#fff; }
.awg-ac-list::-webkit-scrollbar { width:5px; }
.awg-ac-list::-webkit-scrollbar-thumb { background:#888; border-radius:3px; }
</style>
<script>
var custom_settings = <% get_custom_settings(); %>;
var statusTimer = null;
var statusFails = 0;
var awgLoaded = false;
var awgPoll = null;
var v2flyList = [];
var v2flyIpList = ['telegram','google','facebook','twitter','netflix','cloudflare','fastly','cloudfront'];
function escHtml(s){
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
function loadV2flyCategories(){
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/user/v2fly_categories.htm?_=' + Date.now(), true);
    xhr.onload = function(){
        if(xhr.status === 200 && xhr.responseText.length > 0){
            v2flyList = xhr.responseText.trim().split('\n').filter(function(s){ return s; });
        }
    };
    xhr.send();
}

function initial(){
    show_menu();
    loadSettings();
    awgRefreshStatus();
    statusTimer = setInterval(awgRefreshStatus, 5000);
    awgRefreshLog();
    setInterval(awgRefreshLog, 2500);
    loadV2flyCategories();
    initAutocomplete();
    initAutocompleteIp();
    checkForUpdate();
}

function checkForUpdate(){
    // Resolve the latest version from the browser (no backend needed). Try jsDelivr
    // first — it's reachable in regions where api.github.com is blocked — then fall
    // back to the GitHub API. Each source maps its JSON response to a version string.
    awgChecking = true; awgCheckFailed = false;
    refreshModalState();
    var repo = 'william-aqn/asuswrt-merlin-amneziawg';
    var bust = '?_=' + Date.now();   // bypass the browser cache — jsDelivr data API lags otherwise
    var sources = [
        { url: 'https://data.jsdelivr.com/v1/packages/gh/' + repo + '/resolved' + bust,
          pick: function(d){ return (d.version || ''); } },
        { url: 'https://api.github.com/repos/' + repo + '/releases/latest',
          pick: function(d){ return (d.tag_name || '').replace(/^v/, ''); } }
    ];
    var i = 0;
    (function tryNext(){
        if(i >= sources.length){ showUpdateCheckError(); return; }
        var s = sources[i++];
        var xhr = new XMLHttpRequest();
        try { xhr.open('GET', s.url, true); } catch(e){ tryNext(); return; }
        xhr.timeout = 10000;
        xhr.onload = function(){
            if(xhr.status !== 200){ tryNext(); return; }
            try {
                var latest = s.pick(JSON.parse(xhr.responseText));
                if(latest){ showVersionInfo('', latest, false); } else { tryNext(); }
            } catch(e){ tryNext(); }
        };
        xhr.onerror = function(){ tryNext(); };
        xhr.ontimeout = function(){ tryNext(); };
        xhr.send();
    })();
}

// GitHub update-check failed (api.github.com rate-limit/block/timeout). Current version
// still shows in the header button; the modal reports the failure.
function showUpdateCheckError(){
    awgChecking = false; awgCheckFailed = true;
    renderVersionButton();
    refreshModalState();
}

function showVersionInfo(currentIgnored, latest, hasUpdateIgnored){
    awgChecking = false; awgCheckFailed = false;
    if(latest) awgLatestVersion = latest;
    recomputeUpdate();
}

// Compare X.Y.Z version strings: >0 if a is newer than b, <0 if older, 0 if equal.
function cmpVersions(a, b){
    var pa = String(a).split('.'), pb = String(b).split('.');
    for(var i = 0; i < 3; i++){
        var na = parseInt(pa[i], 10) || 0, nb = parseInt(pb[i], 10) || 0;
        if(na > nb) return 1;
        if(na < nb) return -1;
    }
    return 0;
}

// Recompute "update available" from current (local status) + latest (GitHub/jsDelivr),
// then redraw. Only a STRICTLY newer latest counts — a stale/older resolve (e.g. jsDelivr
// data-API lag returning an old tag) must not be offered as an "update" (it would be a
// downgrade).
function recomputeUpdate(){
    awgUpdateAvailable = !!(awgLatestVersion && awgCurrentVersion && cmpVersions(awgLatestVersion, awgCurrentVersion) > 0);
    renderVersionButton();
    refreshModalState();
}

// Single header button: "Обновить до vX" when an update is available, else
// "Текущая версия — vX". Both open the modal (check / changelog / update happen there).
function renderVersionButton(){
    var ub = document.getElementById('awg_update_btn');
    if(!ub) return;
    ub.style.display = 'inline';
    var label = (awgUpdateAvailable && awgLatestVersion) ? ('Обновить v' + awgCurrentVersion + ' до v' + awgLatestVersion)
              : (awgCurrentVersion ? ('Текущая версия — v' + awgCurrentVersion) : 'Версия / обновления');
    ub.innerHTML = '<input type="button" class="button_gen" value="' + escHtml(label) + '" onclick="openUpdateModal();" style="font-size:11px; padding:2px 10px;">';
}

// Update the modal's status line + "Обновить" button (only while the modal is open).
function refreshModalState(){
    var m = document.getElementById('awg_update_modal');
    if(!m || m.style.display === 'none') return;
    var st = document.getElementById('awg_modal_status');
    if(st){
        if(awgChecking) st.textContent = 'Проверка обновлений…';
        else if(awgCheckFailed) st.textContent = '⚠ Не удалось проверить обновления (GitHub недоступен)';
        else if(awgUpdateAvailable && awgLatestVersion) st.textContent = 'Доступно обновление: v' + awgLatestVersion;
        else st.textContent = 'Обновлений нет' + (awgCurrentVersion ? ' — установлена v' + awgCurrentVersion : '');
    }
}

// Reload via a fresh GET (cache-busted), never location.reload() — reload() repeats
// the POST from the last form submit, which makes the browser prompt to resubmit.
function awgReload(){
    window.location.href = window.location.pathname + '?_=' + (new Date()).getTime();
}

// Mirror the two "download via VPN" checkboxes into custom_settings so update / geo
// actions carry the current choice even when the user didn't click Apply first.
function syncViaVpnToggles(){
    var g = document.getElementById('awg_geo_via_awg');
    if(g) custom_settings.awg_geo_via_awg = g.checked ? '1' : '0';
    var u = document.getElementById('awg_update_via_awg');
    if(u) custom_settings.awg_update_via_awg = u.checked ? '1' : '0';
}

function doUpdate(version){
    var badge = document.getElementById('awg_badge');
    if(badge){ badge.className = 'awg-status connecting'; badge.innerHTML = '&#9679; Updating...'; }
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }

    // Carry the current "download via VPN" choice even without a prior Apply.
    syncViaVpnToggles();
    // Pin an explicit version (one-shot) so the router installs exactly it — no backend
    // jsDelivr resolution, no crawl lag. Sent via custom_settings, then removed from
    // memory so a later "Apply" can't re-pin it (the backend also clears it after use).
    if(version) custom_settings.awg_update_version = String(version);
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    if(version) delete custom_settings.awg_update_version;
    document.form.action_script.value = "start_awgdoupdate";
    document.form.submit();

    // Wait for update to finish (VPN stopped, new version installed), then reload
    var attempts = 0;
    setTimeout(function(){
        var poll = setInterval(function(){
            attempts++;
            var xhr = new XMLHttpRequest();
            xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
            xhr.timeout = 3000;
            xhr.onload = function(){
                try {
                    var s = JSON.parse(xhr.responseText);
                    // Update done when VPN is stopped (do_update stops it)
                    if(!s.running || attempts >= 120){
                        clearInterval(poll);
                        awgReload();
                    }
                } catch(e){
                    if(attempts >= 120){ clearInterval(poll); awgReload(); }
                }
            };
            xhr.onerror = function(){ if(attempts >= 120){ clearInterval(poll); awgReload(); } };
            xhr.send();
        }, 2000);
    }, 5000);
}

var awgLatestVersion = '';
var awgCurrentVersion = '';
var awgUpdateAvailable = false;
var awgChecking = false;
var awgCheckFailed = false;

function openUpdateModal(){
    var m = document.getElementById('awg_update_modal');
    if(!m){ if(awgUpdateAvailable) doUpdate(); return; }
    var title = document.getElementById('awg_modal_title');
    var body = document.getElementById('awg_modal_body');
    // Show the changelog of the version you'd update to, or the installed one if up to date
    var ref = (awgUpdateAvailable && awgLatestVersion) ? awgLatestVersion : (awgCurrentVersion || awgLatestVersion || '');
    if(title) title.textContent = (awgUpdateAvailable && awgLatestVersion)
        ? ('Обновление до v' + awgLatestVersion)
        : ('История изменений' + (awgCurrentVersion ? ' — v' + awgCurrentVersion : ''));
    if(body) body.innerHTML = '<div style="opacity:0.7;">Загрузка списка изменений…</div>';
    m.style.display = 'block';
    awgManualUI(false);    // hide any leftover upload progress
    awgManualEnd(false);   // re-enable the install button
    awgModeUI();           // show the input matching the current mode
    refreshModalState();   // status line + "Обновить" button visibility
    loadChangelog(ref, function(text, ok){
        if(!body) return;
        if(ok && text){ body.innerHTML = mdToHtml(text); body.scrollTop = 0; }
        else { body.innerHTML = '<div style="opacity:0.7;">Не удалось загрузить список изменений.</div>'; }
    });
}

function closeUpdateModal(){
    if(awgUploading && !confirm('Идёт загрузка/установка. Закрыть окно и прекратить отслеживание?')) return;
    awgRun++;             // invalidate any in-flight upload/poll loops
    awgManualEnd(false);  // reset the install button + awgUploading flag
    var m = document.getElementById('awg_update_modal');
    if(m) m.style.display = 'none';
}

// Show the version field / file field for the selected install mode.
function awgModeUI(){
    var mode = document.getElementById('awg_install_mode').value;
    var vin = document.getElementById('awg_version_input');
    var fin = document.getElementById('awg_ipk_file');
    if(vin) vin.style.display = (mode === 'version') ? '' : 'none';
    if(fin) fin.style.display = (mode === 'file') ? '' : 'none';
}

// Install action, dispatched by the mode selector:
//   auto    -> latest published version (auto-detected)
//   version -> an exact published version X.Y.Z
//   file    -> a locally chosen .ipk, uploaded chunk-by-chunk (see awgManualStart)
function installUpdate(){
    if(awgUploading) return;
    var mode = document.getElementById('awg_install_mode').value;

    if(mode === 'file'){
        var fsel = document.getElementById('awg_ipk_file');
        var f = (fsel && fsel.files && fsel.files[0]) || null;
        if(!f){ alert('Выберите .ipk файл для установки.'); return; }
        if(!/\.ipk$/i.test(f.name) && !confirm('Файл не похож на .ipk. Всё равно установить?')) return;
        awgManualStart(f);
        return;
    }

    if(mode === 'version'){
        var inp = document.getElementById('awg_version_input');
        var v = ((inp && inp.value) || '').trim().replace(/^v/i, '');
        if(!v){ alert('Введите версию в формате X.Y.Z, например 1.1.49'); return; }
        if(!/^\d+\.\d+\.\d+$/.test(v)){ alert('Версия в формате X.Y.Z, например 1.1.49'); return; }
        if(awgCurrentVersion && v === awgCurrentVersion && !confirm('Версия v' + v + ' уже установлена. Переустановить?')) return;
        closeUpdateModal();
        doUpdate(v);
        return;
    }

    // auto -> latest. If we're already on the newest, say so instead of a no-op update.
    if(!awgUpdateAvailable){
        alert('У вас последняя версия' + (awgCurrentVersion ? ' (v' + awgCurrentVersion + ')' : '') + '.');
        return;
    }
    closeUpdateModal();
    doUpdate(awgLatestVersion || '');
}

// ---- Manual .ipk upload --------------------------------------------------------------
// The firmware's apply path can't carry a multi-MB binary (httpd caps the POST body and
// reads it line-by-line), so we base64-encode the file in the browser and stream it to
// the router as a sequence of small custom-settings writes (awg_ipk_chunk). The backend
// (awgupload event) appends each chunk by sequence number and acks via awg_upload.htm;
// once every chunk is acked we trigger awgmanualinstall, which decodes, verifies
// (length + gzip CRC + .ipk structure) and installs. A corrupt upload fails verification
// and is never installed.
var awgUploading = false;
// Generation counter: bumped when a new upload starts and when the modal is closed.
// Every poll/retry loop captures the generation it belongs to and stops itself once the
// generation changes — so a stale loop from a previous or aborted upload can never drive
// the UI (e.g. reload the page mid-install on a quick retry).
var awgRun = 0;
function awgStale(runId){ return runId !== awgRun; }

function awgManualUI(show){
    var p = document.getElementById('awg_manual_progress');
    if(p) p.style.display = show ? 'block' : 'none';
}
function awgSetProgress(frac, msg){
    var bar = document.getElementById('awg_manual_bar');
    var m = document.getElementById('awg_manual_msg');
    if(bar) bar.style.width = Math.round(Math.max(0, Math.min(1, frac)) * 100) + '%';
    if(m && msg != null) m.textContent = msg;
}
function awgManualEnd(uploading){
    awgUploading = uploading;
    var btn = document.getElementById('awg_install_btn');
    if(btn){ btn.disabled = uploading; btn.value = uploading ? 'Установка…' : 'Установить'; }
}
function awgManualFail(msg){
    awgManualEnd(false);
    awgSetProgress(0, '');
    awgManualUI(false);
    alert('Не удалось установить: ' + msg);
}

// Encode a Uint8Array to base64 without blowing the call stack on large files.
function awgBytesToB64(bytes){
    var bin = '', step = 0x8000;
    for(var i = 0; i < bytes.length; i += step){
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + step));
    }
    return btoa(bin);
}

// Submit the shared form (-> hidden_frame, proven auth path) with the current settings
// plus one-shot upload keys in `extra`. cb() fires when the POST has been processed.
function awgPostSettings(actionScript, extra, waitVal, cb){
    var fr = document.getElementById('hidden_frame');
    var done = false;
    var to = setTimeout(function(){ if(!done){ done = true; cleanup(); cb(false); } }, 12000);
    function cleanup(){ try{ fr.removeEventListener('load', onl); }catch(e){} clearTimeout(to); }
    function onl(){ if(done) return; done = true; cleanup(); cb(true); }
    fr.addEventListener('load', onl);

    var merged = {};
    for(var k in custom_settings){ if(custom_settings.hasOwnProperty(k)) merged[k] = custom_settings[k]; }
    if(extra){ for(var k2 in extra){ if(extra.hasOwnProperty(k2)) merged[k2] = extra[k2]; } }
    var ac = document.getElementById('amng_custom');
    if(ac) ac.value = JSON.stringify(merged);

    var aw = document.form.action_wait;
    var oldwait = aw ? aw.value : null;
    if(aw && waitVal != null) aw.value = String(waitVal);
    document.form.action_script.value = actionScript;
    document.form.submit();
    if(aw && oldwait != null) aw.value = oldwait;   // submit() snapshots fields synchronously
}

// Poll awg_upload.htm until the backend acks sequence `wantSeq` for this upload `token`.
// cb(ackObjOrNull): {status:'ok'} on success; {status:'gap'|'err'} is a hard failure;
// null on timeout (caller retries). Acks from other uploads (token mismatch) are ignored.
function awgPollAck(token, wantSeq, timeoutMs, runId, cb){
    var t0 = Date.now();
    (function tick(){
        if(awgStale(runId)) return;   // a newer upload (or close) superseded this one
        var x = new XMLHttpRequest();
        x.open('GET', '/user/awg_upload.htm?_=' + Date.now(), true);
        x.timeout = 3000;
        x.onload = function(){
            if(awgStale(runId)) return;
            var j = null;
            try { j = JSON.parse(x.responseText); } catch(e){}
            if(j && j.tok === token){
                if(j.status === 'ok' && j.seq === wantSeq){ cb(j); return; }
                if(j.status === 'gap' || j.status === 'err'){ cb(j); return; }
            }
            if(Date.now() - t0 > timeoutMs){ cb(null); return; }
            setTimeout(tick, 300);
        };
        x.onerror = x.ontimeout = function(){
            if(awgStale(runId)) return;
            if(Date.now() - t0 > timeoutMs){ cb(null); return; }
            setTimeout(tick, 400);
        };
        x.send();
    })();
}

function awgManualStart(file){
    var myRun = ++awgRun;   // claim a new generation; supersedes any prior upload's loops
    awgManualEnd(true);
    awgManualUI(true);
    awgSetProgress(0, 'Чтение файла…');

    var reader = new FileReader();
    reader.onerror = function(){ awgManualFail('не удалось прочитать файл.'); };
    reader.onload = function(){
        var bytes = new Uint8Array(reader.result);
        var total = bytes.length;
        if(total === 0){ awgManualFail('файл пуст.'); return; }
        var b64 = awgBytesToB64(bytes);

        // Size each chunk so the whole POST (current settings + chunk, URL-encoded) stays
        // well under the firmware's ~64 KB body cap. If the existing settings alone are
        // already too big, bail out cleanly rather than send a silently-truncated POST.
        var baseLen = encodeURIComponent(JSON.stringify(custom_settings)).length;
        // -256: the "amng_custom=" prefix, the other form fields, and the chunk key names
        // (awg_ipk_chunk/seq/token/first) that ride along in the same POST body.
        var budget = 52000 - baseLen - 256;
        if(budget < 2000){ awgManualFail('настройки слишком велики для загрузки файла через UI.'); return; }
        var chunkChars = Math.floor(budget / 1.06);
        var total_chunks = Math.ceil(b64.length / chunkChars);
        var token = 'u' + Date.now() + Math.floor(Math.random() * 1e9).toString(36);

        function sendChunk(i){
            if(awgStale(myRun)) return;
            if(i >= total_chunks){ triggerInstall(); return; }
            var piece = b64.substr(i * chunkChars, chunkChars);
            var extra = { awg_ipk_chunk: piece, awg_ipk_seq: String(i), awg_ipk_token: token };
            if(i === 0) extra.awg_ipk_first = '1';
            attemptChunk(i, extra, 0);
        }
        function attemptChunk(i, extra, attempt){
            if(awgStale(myRun)) return;
            awgSetProgress(i / total_chunks, 'Загрузка ' + (i + 1) + '/' + total_chunks + '…');
            awgPostSettings('start_awgupload', extra, 1, function(){
                awgPollAck(token, i, 15000, myRun, function(ack){
                    if(ack && ack.status === 'ok'){ sendChunk(i + 1); return; }
                    if(ack && (ack.status === 'gap' || ack.status === 'err')){
                        awgManualFail((ack.msg ? ack.msg + ' ' : 'сбой передачи ') + '(часть ' + (i + 1) + '/' + total_chunks + ').');
                        return;
                    }
                    if(attempt < 4){ attemptChunk(i, extra, attempt + 1); return; }   // timeout -> retry
                    awgManualFail('нет ответа роутера (часть ' + (i + 1) + '/' + total_chunks + ').');
                });
            });
        }
        function triggerInstall(){
            if(awgStale(myRun)) return;
            awgSetProgress(1, 'Проверка и установка пакета…');
            awgPostSettings('start_awgmanualinstall', { awg_ipk_len: String(total), awg_ipk_token: token }, 30, function(){
                awgPollManualInstall(token, myRun);
            });
        }

        awgSetProgress(0, 'Загрузка 1/' + total_chunks + '…');
        sendChunk(0);
    };
    reader.readAsArrayBuffer(file);
}

// After awgmanualinstall is triggered, poll awg_upload.htm for the final result. Both the
// generation (runId) and the per-upload token are checked, so a leaked poller can never
// act on another upload's completion.
function awgPollManualInstall(token, runId){
    var t0 = Date.now();
    (function tick(){
        if(awgStale(runId)) return;
        var x = new XMLHttpRequest();
        x.open('GET', '/user/awg_upload.htm?_=' + Date.now(), true);
        x.timeout = 3000;
        x.onload = function(){
            if(awgStale(runId)) return;
            var j = null;
            try { j = JSON.parse(x.responseText); } catch(e){}
            if(j && j.tok === token && j.status === 'installed'){
                awgSetProgress(1, 'Готово! Перезагрузка страницы…');
                setTimeout(awgReload, 1500);
                return;
            }
            if(j && j.tok === token && j.status === 'install_err'){ awgManualFail(j.msg || 'установка не удалась.'); return; }
            if(Date.now() - t0 > 180000){ awgManualEnd(false); awgReload(); return; }
            setTimeout(tick, 2000);
        };
        x.onerror = x.ontimeout = function(){
            if(awgStale(runId)) return;
            if(Date.now() - t0 > 180000){ awgManualEnd(false); awgReload(); return; }
            setTimeout(tick, 2500);
        };
        x.send();
    })();
}

// Load the changelog straight from the repo, fetched by the frontend. Use the
// VERSIONED tag (@vX.Y.Z) — NOT @main: jsDelivr caches the moving "main" ref
// aggressively (which made the list lag behind), while a tag is immutable and served
// fresh. raw.githubusercontent is a fallback for when jsDelivr is unreachable.
function loadChangelog(ref, cb){
    var repo = 'william-aqn/asuswrt-merlin-amneziawg';
    var tag = ref ? ('v' + ref) : 'main';
    var urls = [
        'https://cdn.jsdelivr.net/gh/' + repo + '@' + tag + '/CHANGELOG.md',
        'https://raw.githubusercontent.com/' + repo + '/' + tag + '/CHANGELOG.md?_=' + Date.now()
    ];
    var i = 0;
    (function tryNext(){
        if(i >= urls.length){ cb('', false); return; }
        var u = urls[i++];
        var x = new XMLHttpRequest();
        try { x.open('GET', u, true); } catch(e){ tryNext(); return; }
        x.timeout = 6000;
        x.onload = function(){ if(x.status === 200 && x.responseText){ cb(x.responseText, true); } else { tryNext(); } };
        x.onerror = function(){ tryNext(); };
        x.ontimeout = function(){ tryNext(); };
        x.send();
    })();
}

// Minimal Markdown -> HTML for the changelog (headings, bullets, bold, code, links).
function mdToHtml(md){
    var lines = String(md).split(/\r?\n/), out = [];
    for(var i = 0; i < lines.length; i++){
        var ln = escHtml(lines[i])
            .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
            .replace(/`([^`]+?)`/g, '<code style="background:rgba(255,255,255,0.12); padding:0 4px; border-radius:3px;">$1</code>')
            .replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" style="color:#5db0ff;">$1</a>');
        if(/^###\s+/.test(ln)) out.push('<div style="font-weight:bold; font-size:14px; margin:12px 0 4px; color:#ff6b6b;">' + ln.replace(/^###\s+/, '') + '</div>');
        else if(/^##\s+/.test(ln)) out.push('<div style="font-weight:bold; font-size:16px; margin:14px 0 6px;">' + ln.replace(/^##\s+/, '') + '</div>');
        else if(/^#\s+/.test(ln)) out.push('<div style="font-weight:bold; font-size:18px; margin:6px 0 8px;">' + ln.replace(/^#\s+/, '') + '</div>');
        else if(/^[-*]\s+/.test(ln)) out.push('<div style="margin:3px 0 3px 16px;">• ' + ln.replace(/^[-*]\s+/, '') + '</div>');
        else if(ln.trim() === '') out.push('<div style="height:6px;"></div>');
        else out.push('<div>' + ln + '</div>');
    }
    return out.join('');
}

function loadSettings(){
    var fields = [
        'awg_privatekey', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_peer_pubkey', 'awg_peer_psk', 'awg_peer_endpoint',
        'awg_peer_allowedips', 'awg_peer_keepalive',
        'awg_jc', 'awg_jmin', 'awg_jmax',
        'awg_s1', 'awg_s2', 'awg_s3', 'awg_s4',
        'awg_h1', 'awg_h2', 'awg_h3', 'awg_h4'
    ];
    for(var i = 0; i < fields.length; i++){
        var el = document.getElementById(fields[i]);
        if(el && custom_settings[fields[i]] != undefined){
            el.value = custom_settings[fields[i]];
        }
    }
    // Load I1-I5 from base64
    if(custom_settings.awg_initdata){
        try {
            var initLines = atob(custom_settings.awg_initdata).split('\n');
            for(var il = 0; il < initLines.length; il++){
                var ip = initLines[il].split('=');
                if(ip.length >= 2){
                    var ik = ip[0].trim().toLowerCase();
                    var ival = ip.slice(1).join('=').trim();
                    if(ik === 'i1') setVal('awg_i1', ival);
                    else if(ik === 'i2') setVal('awg_i2', ival);
                    else if(ik === 'i3') setVal('awg_i3', ival);
                    else if(ik === 'i4') setVal('awg_i4', ival);
                    else if(ik === 'i5') setVal('awg_i5', ival);
                }
            }
        } catch(e){}
    }
    // Load default policy
    var defPolicy = document.getElementById('default_policy');
    defPolicy.value = custom_settings.awg_default_policy || 'direct';
    // Load clients list
    loadClients();
    // Load geo settings
    loadGeoSettings();
    updateGeoVisibility();
}

function saveSettings(){ applyConfig('start_awgsaveconf'); }

function forceApply(){
    if(!confirm('Force Apply: сохранить настройки, перезапустить VPN и полностью пересобрать маршруты и firewall?')) return;
    applyConfig('start_awgforceapply');
}

function applyConfig(actionScript){
    var fields = [
        'awg_privatekey', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_peer_pubkey', 'awg_peer_psk', 'awg_peer_endpoint',
        'awg_peer_allowedips', 'awg_peer_keepalive',
        'awg_jc', 'awg_jmin', 'awg_jmax',
        'awg_s1', 'awg_s2', 'awg_s3', 'awg_s4',
        'awg_h1', 'awg_h2', 'awg_h3', 'awg_h4'
    ];
    for(var i = 0; i < fields.length; i++){
        var el = document.getElementById(fields[i]);
        if(el){
            var v = el.value;
            // Remove spaces from comma-separated values (Merlin truncates at spaces)
            if(fields[i] === 'awg_peer_allowedips' || fields[i] === 'awg_address' || fields[i] === 'awg_dns'){
                v = v.replace(/\s+/g, '');
            }
            custom_settings[fields[i]] = v;
        }
    }
    // Save default policy and clients
    custom_settings.awg_default_policy = document.getElementById('default_policy').value;
    custom_settings.awg_clients = serializeClients();

    // Save I1-I5 as base64 (contain HTML-unsafe chars)
    var initData = '';
    for(var ix = 1; ix <= 5; ix++){
        var iv = document.getElementById('awg_i' + ix);
        if(iv && iv.value) initData += 'I' + ix + ' = ' + iv.value + '\n';
    }
    try {
        custom_settings.awg_initdata = initData ? btoa(initData) : '';
    } catch(e){
        alert('I1-I5 contain invalid (non-ASCII) characters.');
        return;
    }

    // Save geo settings
    custom_settings.awg_geo_v2fly = document.getElementById('awg_geo_v2fly').value;
    custom_settings.awg_geo_v2fly_ip = document.getElementById('awg_geo_v2fly_ip').value;
    custom_settings.awg_geo_custom_domains = document.getElementById('geo_custom_domains').value;
    custom_settings.awg_geo_custom_ips = document.getElementById('geo_custom_ips').value;
    custom_settings.awg_geo_autoupdate = document.getElementById('geo_autoupdate').checked ? '1' : '0';
    custom_settings.awg_block_ipv6_dns = document.getElementById('awg_block_ipv6_dns').checked ? '1' : '0';
    custom_settings.awg_geo_wipe_update = document.getElementById('awg_geo_wipe_update').checked ? '1' : '0';
    // Download-via-VPN toggles (route geo / program-update downloads through the tunnel)
    custom_settings.awg_geo_via_awg = document.getElementById('awg_geo_via_awg').checked ? '1' : '0';
    custom_settings.awg_update_via_awg = document.getElementById('awg_update_via_awg').checked ? '1' : '0';
    // Antifilter lists: collect checked checkboxes -> comma-separated registry keys
    var afChecked = [];
    var afB = document.querySelectorAll('.af_list');
    for(var aj = 0; aj < afB.length; aj++){ if(afB[aj].checked) afChecked.push(afB[aj].value); }
    custom_settings.awg_antifilter_lists = afChecked.join(',');

    // Basic validation
    var pk = document.getElementById('awg_privatekey').value;
    var pubk = document.getElementById('awg_peer_pubkey').value;
    var ep = document.getElementById('awg_peer_endpoint').value;
    if(!pk || !pubk || !ep){
        alert('Required: Private Key, Peer Public Key, and Endpoint.');
        return;
    }
    if(pk.length !== 44 || pubk.length !== 44){
        alert('Invalid key format. Keys must be 44 characters (base64).');
        return;
    }
    if(!/:\d{1,5}$/.test(ep)){
        alert('Endpoint must include port (e.g. server:51820).');
        return;
    }

    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = actionScript;
    document.form.submit();
    // No full-page reload: status + log refresh live via polling. Reloading after a
    // form POST makes the browser prompt to resubmit the form ("Повторить отправку").
}

// === Routing: per-device with individual policies ===

function loadClients(){
    var data = custom_settings.awg_clients || '';
    var tbody = document.getElementById('awg_client_rows');
    tbody.innerHTML = '';
    if(!data) return;
    var entries = data.split(';');
    for(var i = 0; i < entries.length; i++){
        if(!entries[i]) continue;
        var parts = entries[i].split(',');
        var nm = parts[1] || '';
        try { nm = decodeURIComponent(nm); } catch(e){}  // tolerate old/plain names
        addClientRow(parts[0] || '', nm, parts[2] || 'vpn_all');
    }
    updateGeoVisibility();
}

function addClientRow(ip, name, policy){
    var tbody = document.getElementById('awg_client_rows');
    var tr = document.createElement('tr');
    policy = policy || 'vpn_all';
    tr.innerHTML =
        '<td><input type="text" class="client_ip input_25_table" value="' + escHtml(ip) + '" placeholder="192.168.1.100"></td>' +
        '<td><input type="text" class="client_name input_25_table" value="' + escHtml(name) + '" placeholder="iPhone, PS5, TV..."></td>' +
        '<td><select class="client_policy input_option" onchange="updateGeoVisibility();" style="width:100%;">' +
            '<option value="vpn_all"' + (policy==='vpn_all'?' selected':'') + '>VPN (All)</option>' +
            '<option value="vpn_geo"' + (policy==='vpn_geo'?' selected':'') + '>VPN (Geo)</option>' +
            '<option value="direct"' + (policy==='direct'?' selected':'') + '>Direct</option>' +
        '</select></td>' +
        '<td style="text-align:center;"><button type="button" class="awg-remove-btn" onclick="this.closest(\'tr\').remove(); updateGeoVisibility();">&times;</button></td>';
    tbody.appendChild(tr);
    updateGeoVisibility();
}

function serializeClients(){
    var rows = document.querySelectorAll('#awg_client_rows tr');
    var parts = [];
    for(var i = 0; i < rows.length; i++){
        var ip = rows[i].querySelector('.client_ip').value.trim();
        var name = rows[i].querySelector('.client_name').value.trim();
        var policy = rows[i].querySelector('.client_policy').value;
        // Encode the name: Merlin truncates custom_settings values at the first
        // space, and ',' / ';' are our delimiters — encodeURIComponent escapes all
        // three (and the backend ignores the name field anyway).
        if(ip) parts.push(ip + ',' + encodeURIComponent(name) + ',' + policy);
    }
    return parts.join(';');
}

function updateGeoVisibility(){
    // Show geo settings if ANY device uses vpn_geo or default policy is vpn_geo
    var defPolicy = document.getElementById('default_policy').value;
    var hasGeo = (defPolicy === 'vpn_geo');
    if(!hasGeo){
        var selects = document.querySelectorAll('.client_policy');
        for(var i = 0; i < selects.length; i++){
            if(selects[i].value === 'vpn_geo'){ hasGeo = true; break; }
        }
    }
    document.getElementById('geo_section').style.display = hasGeo ? '' : 'none';
}

// === GeoIP / GeoSite ===

function loadGeoSettings(){
    var v2fly = document.getElementById('awg_geo_v2fly');
    if(v2fly) v2fly.value = custom_settings.awg_geo_v2fly || '';
    var v2flyIp = document.getElementById('awg_geo_v2fly_ip');
    if(v2flyIp) v2flyIp.value = custom_settings.awg_geo_v2fly_ip || v2flyIpList.join(',');
    // Custom
    var cd = document.getElementById('geo_custom_domains');
    if(cd) cd.value = custom_settings.awg_geo_custom_domains || '';
    var ci = document.getElementById('geo_custom_ips');
    if(ci) ci.value = custom_settings.awg_geo_custom_ips || '';
    // Auto-update
    var au = document.getElementById('geo_autoupdate');
    if(au) au.checked = (custom_settings.awg_geo_autoupdate === '1');
    // Block IPv6 DNS (default on)
    var b6 = document.getElementById('awg_block_ipv6_dns');
    if(b6) b6.checked = (custom_settings.awg_block_ipv6_dns !== '0');
    var wp = document.getElementById('awg_geo_wipe_update');
    if(wp) wp.checked = (custom_settings.awg_geo_wipe_update === '1');
    // Download-via-VPN toggles (default off)
    var gva = document.getElementById('awg_geo_via_awg');
    if(gva) gva.checked = (custom_settings.awg_geo_via_awg === '1');
    var uva = document.getElementById('awg_update_via_awg');
    if(uva) uva.checked = (custom_settings.awg_update_via_awg === '1');
    // Antifilter lists (checkboxes) — value attr holds the registry key
    var afSel = (custom_settings.awg_antifilter_lists || '').split(',');
    var afBoxes = document.querySelectorAll('.af_list');
    for(var ai = 0; ai < afBoxes.length; ai++){
        afBoxes[ai].checked = afSel.indexOf(afBoxes[ai].value) !== -1;
    }
}

function updateGeoLists(){
    var btn = document.getElementById('btn_geo_update');
    var isDownload = btn && btn.value === 'Download Lists';
    var msg = isDownload
        ? 'Download all GeoIP and domain lists?\nThis may take 1-2 minutes.'
        : 'Force re-download all GeoIP and domain lists?\nThis may take 1-2 minutes.';
    if(!confirm(msg)) return;
    var log = document.getElementById('awg_log');
    if(log) log.textContent = 'Downloading geo lists... Please wait.';
    // Carry the current "download via VPN" choice even without a prior Apply.
    syncViaVpnToggles();
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = "start_awgupdategeo";
    document.form.submit();
    // No reload: geo progress and result show live in the log + status via polling.
}

function fetchDhcpClients(){
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/appGet.cgi?hook=get_clientlist()&_=' + Date.now(), true);
    xhr.onload = function(){
        if(xhr.status === 200){
            try {
                var data = JSON.parse(xhr.responseText);
                var cl = data.get_clientlist || data;
                var lines = [];
                for(var key in cl){
                    if(!cl.hasOwnProperty(key)) continue;
                    var c = cl[key];
                    if(c && typeof c === 'object' && c.ip){
                        lines.push({ip: c.ip, name: c.name || c.nickName || key});
                    }
                }
                if(lines.length > 0){
                    showClientPicker(lines);
                } else {
                    fetchDhcpLeases();
                }
            } catch(e){
                fetchDhcpLeases();
            }
        } else {
            fetchDhcpLeases();
        }
    };
    xhr.onerror = function(){ fetchDhcpLeases(); };
    xhr.send();
}

function fetchDhcpLeases(){
    // Fallback when the get_clientlist hook is unavailable: ask for IPs directly.
    // (Parsing the firmware's client pages is version-specific and unreliable.)
    var input = prompt('Could not read the DHCP client list.\nEnter device IPs to add (comma-separated):');
    if(input) addManualIPs(input);
}

function showClientPicker(clients){
    var msg = 'DHCP clients:\n\n';
    for(var i = 0; i < clients.length; i++){
        msg += (i+1) + ') ' + clients[i].ip + ' — ' + clients[i].name + '\n';
    }
    msg += '\nEnter numbers (e.g. 1,3,5) or IPs directly:';
    var input = prompt(msg);
    if(!input) return;

    var items = input.split(',');
    for(var i = 0; i < items.length; i++){
        var v = items[i].trim();
        var num = parseInt(v);
        if(!isNaN(num) && num >= 1 && num <= clients.length){
            var c = clients[num - 1];
            addClientRow(c.ip, c.name, 'vpn_all');
        } else if(v.match(/^\d+\.\d+\.\d+\.\d+$/)){
            addClientRow(v, '', 'vpn_all');
        }
    }
}

function addManualIPs(input){
    var ips = input.split(',');
    for(var i = 0; i < ips.length; i++){
        var ip = ips[i].trim();
        if(ip) addClientRow(ip, '', 'vpn_all');
    }
}

function awgAction(action){
    document.form.action_script.value = action;
    document.form.submit();
    var badge = document.getElementById('awg_badge');
    var isStop = action.indexOf('stop') !== -1;
    var expect = !isStop;

    // Stop periodic refresh and any prior in-flight action poll
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
    if(awgPoll){ clearInterval(awgPoll); awgPoll = null; }
    document.getElementById('btn_start').disabled = true;
    document.getElementById('btn_stop').disabled = true;
    document.getElementById('btn_restart').disabled = true;

    // Show transitional status
    badge.className = 'awg-status connecting';
    badge.innerHTML = isStop ? '&#9679; Stopping...' : '&#9679; Connecting...';

    // Poll until status is fully ready
    var attempts = 0;
    var poll = setInterval(function(){
        attempts++;
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
        xhr.timeout = 3000;
        xhr.onload = function(){
            try {
                var s = JSON.parse(xhr.responseText);
                // For start: wait until running AND has public key (fully ready)
                // For stop: wait until not running
                var ready = (s.running === expect);
                if(ready || attempts >= 90){
                    clearInterval(poll);
                    updateStatusUI(s);
                    statusTimer = setInterval(awgRefreshStatus, 5000);
                    document.getElementById('btn_start').disabled = false;
                    document.getElementById('btn_stop').disabled = false;
                    document.getElementById('btn_restart').disabled = false;
                }
            } catch(e){
                if(attempts >= 90){ clearInterval(poll); awgRefreshStatus(); document.getElementById('btn_start').disabled = false; document.getElementById('btn_stop').disabled = false; document.getElementById('btn_restart').disabled = false; }
            }
        };
        xhr.onerror = function(){ if(attempts >= 90){ clearInterval(poll); awgRefreshStatus(); document.getElementById('btn_start').disabled = false; document.getElementById('btn_stop').disabled = false; document.getElementById('btn_restart').disabled = false; } };
        xhr.send();
    }, 2000);
    awgPoll = poll;
}

function showLoading(){}
function hideLoading(){}

// Real-time on-page log: poll the web-readable log the backend writes per action.
function awgRefreshLog(){
    var x = new XMLHttpRequest();
    x.open('GET', '/user/awg_log.htm?_=' + Date.now(), true);
    x.timeout = 3000;
    x.onload = function(){
        if(x.status !== 200 || !x.responseText) return;
        var box = document.getElementById('awg_log');
        if(!box) return;
        var lines = x.responseText.replace(/\s+$/, '').split(/\r?\n/);
        if(lines.length > 80) lines = lines.slice(-80);
        var atBottom = (box.scrollHeight - box.scrollTop - box.clientHeight) < 30;
        box.textContent = lines.join('\n');
        if(atBottom) box.scrollTop = box.scrollHeight;
    };
    x.send();
}

function awgRefreshStatus(){
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
    xhr.timeout = 3000;
    xhr.onload = function(){
        if(xhr.status === 200){
            try {
                var status = JSON.parse(xhr.responseText);
                statusFails = 0;
                updateStatusUI(status);
            } catch(e) {
                onStatusFail();
            }
        } else {
            onStatusFail();
        }
    };
    xhr.onerror = function(){ onStatusFail(); };
    xhr.ontimeout = function(){ onStatusFail(); };
    xhr.send();
}

// Tolerate transient status-read failures: a single slow/timed-out read
// shouldn't flicker the badge to "Stopped". Only show offline after a few
// consecutive misses (a real stop returns HTTP 200 with running=false and is
// reflected immediately via updateStatusUI).
function onStatusFail(){
    statusFails++;
    if(!awgLoaded){
        // Initial load hasn't succeeded yet — keep the "loading" badge and keep
        // retrying instead of flipping to "Stopped".
        if(statusFails >= 6){
            var b = document.getElementById('awg_badge');
            b.className = 'awg-status connecting';
            b.innerHTML = '&#9679; Роутер не отвечает…';
        }
        return;
    }
    if(statusFails >= 3) setOfflineUI();
}

function updateStatusUI(s){
    awgLoaded = true;
    // Track the installed version (from local status, independent of the GitHub check)
    // and (re)draw the single header version/update button.
    if(s.version){
        awgCurrentVersion = s.version;
        recomputeUpdate();
    }
    var badge = document.getElementById('awg_badge');
    var info = document.getElementById('awg_info');
    var peers = document.getElementById('awg_peers');
    var logbox = document.getElementById('awg_log');

    if(s.stopping){
        badge.className = 'awg-status connecting';
        badge.innerHTML = '&#9679; Stopping...';
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = 'none';
        document.getElementById('btn_restart').style.display = 'none';
    } else if(s.running){
        badge.className = 'awg-status running';
        badge.innerHTML = '&#9679; Connected';
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = '';
        document.getElementById('btn_restart').style.display = '';
    } else if(s.starting){
        badge.className = 'awg-status connecting';
        badge.innerHTML = '&#9679; Connecting...';
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = '';
        document.getElementById('btn_restart').style.display = 'none';
    } else {
        badge.className = 'awg-status stopped';
        badge.innerHTML = '&#9679; Stopped';
        document.getElementById('btn_start').style.display = '';
        document.getElementById('btn_stop').style.display = 'none';
        document.getElementById('btn_restart').style.display = 'none';
    }

    info.innerHTML = '';
    if(s.interface_addr) info.innerHTML += 'Address: ' + escHtml(s.interface_addr) + '<br>';
    if(s.public_key) info.innerHTML += 'Public Key: ' + escHtml(s.public_key.substring(0,12)) + '...<br>';
    if(s.listen_port) info.innerHTML += 'Listen Port: ' + escHtml(s.listen_port) + '<br>';

    var html = '';
    if(s.peers && s.peers.length > 0){
        for(var i = 0; i < s.peers.length; i++){
            var p = s.peers[i];
            html += '<tr>';
            html += '<td>' + escHtml(p.endpoint || '-') + '</td>';
            html += '<td>' + escHtml(p.allowed_ips || '-') + '</td>';
            html += '<td>' + escHtml(p.transfer_rx || '0 B') + ' / ' + escHtml(p.transfer_tx || '0 B') + '</td>';
            html += '<td>' + escHtml(p.latest_handshake || 'never') + '</td>';
            html += '</tr>';
        }
    }
    peers.innerHTML = html;

    // on-page log is polled in real time via awgRefreshLog() (not from s.log)

    // Route info
    var rulesEl = document.getElementById('awg_active_rules');
    if(s.running){
        var infoParts = [];
        if(s.active_rules > 0) infoParts.push(s.active_rules + ' routing rule(s)');
        if(s.ipset_count > 0) infoParts.push(s.ipset_count + ' IP ranges');
        if(s.geo_domains > 0) infoParts.push(s.geo_domains + ' domain rules');
        rulesEl.innerHTML = infoParts.join(' &middot; ') || 'no rules active';
        rulesEl.style.color = '#93E7FF';
    } else {
        rulesEl.innerHTML = '';
    }

    // Update geo button text based on database availability
    var geoBtn = document.getElementById('btn_geo_update');
    if(geoBtn){
        if(s.geo_downloaded){
            geoBtn.value = 'Update Now';
        } else {
            geoBtn.value = 'Download Lists';
            geoBtn.style.fontWeight = 'bold';
        }
    }
}

function setOfflineUI(){
    var badge = document.getElementById('awg_badge');
    badge.className = 'awg-status stopped';
    badge.innerHTML = '&#9679; Stopped';
    document.getElementById('btn_start').style.display = '';
    document.getElementById('btn_stop').style.display = 'none';
    document.getElementById('btn_restart').style.display = 'none';
}

function importConfig(){
    var fileInput = document.getElementById('awg_config_file');
    if(!fileInput){
        fileInput = document.createElement('input');
        fileInput.type = 'file';
        fileInput.id = 'awg_config_file';
        fileInput.accept = '.conf,.txt';
        fileInput.style.display = 'none';
        document.body.appendChild(fileInput);
    }
    fileInput.value = '';
    fileInput.onchange = function(){
        if(!fileInput.files || !fileInput.files[0]) return;
        var reader = new FileReader();
        reader.onload = function(e){ parseConfig(e.target.result); };
        reader.readAsText(fileInput.files[0]);
    };
    fileInput.click();
}

function parseConfig(text){
    if(!text) return;

    // Reset all import-target fields first, so values absent from the imported
    // config don't keep stale values (e.g. an old S4 lingering after import).
    var clearFields = [
        'awg_privatekey', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_jc', 'awg_jmin', 'awg_jmax', 'awg_s1', 'awg_s2', 'awg_s3', 'awg_s4',
        'awg_h1', 'awg_h2', 'awg_h3', 'awg_h4',
        'awg_i1', 'awg_i2', 'awg_i3', 'awg_i4', 'awg_i5',
        'awg_peer_pubkey', 'awg_peer_psk', 'awg_peer_endpoint',
        'awg_peer_allowedips', 'awg_peer_keepalive'
    ];
    for(var ci = 0; ci < clearFields.length; ci++){ setVal(clearFields[ci], ''); }

    var lines = text.split('\n');
    var section = '';
    for(var i = 0; i < lines.length; i++){
        var line = lines[i].trim();
        if(line === '[Interface]'){ section = 'iface'; continue; }
        if(line === '[Peer]'){ section = 'peer'; continue; }
        if(!line || line.charAt(0) === '#') continue;

        var parts = line.split('=');
        if(parts.length < 2) continue;
        var key = parts[0].trim();
        var val = parts.slice(1).join('=').trim();

        if(section === 'iface'){
            switch(key){
                case 'PrivateKey': setVal('awg_privatekey', val); break;
                case 'Address':    setVal('awg_address', val); break;
                case 'ListenPort': setVal('awg_listenport', val); break;
                case 'MTU':        setVal('awg_mtu', val); break;
                case 'DNS':        setVal('awg_dns', val); break;
                case 'Jc':         setVal('awg_jc', val); break;
                case 'Jmin':       setVal('awg_jmin', val); break;
                case 'Jmax':       setVal('awg_jmax', val); break;
                case 'S1':         setVal('awg_s1', val); break;
                case 'S2':         setVal('awg_s2', val); break;
                case 'S3':         setVal('awg_s3', val); break;
                case 'S4':         setVal('awg_s4', val); break;
                case 'H1':         setVal('awg_h1', val); break;
                case 'H2':         setVal('awg_h2', val); break;
                case 'H3':         setVal('awg_h3', val); break;
                case 'H4':         setVal('awg_h4', val); break;
                case 'I1': setVal('awg_i1', val); break;
                case 'I2': setVal('awg_i2', val); break;
                case 'I3': setVal('awg_i3', val); break;
                case 'I4': setVal('awg_i4', val); break;
                case 'I5': setVal('awg_i5', val); break;
            }
        } else if(section === 'peer'){
            switch(key){
                case 'PublicKey':          setVal('awg_peer_pubkey', val); break;
                case 'PresharedKey':       setVal('awg_peer_psk', val); break;
                case 'Endpoint':           setVal('awg_peer_endpoint', val); break;
                case 'AllowedIPs':         setVal('awg_peer_allowedips', val); break;
                case 'PersistentKeepalive': setVal('awg_peer_keepalive', val); break;
            }
        }
    }
    alert('Config imported. Review the fields and click Apply.');
}

function setVal(id, val){
    var el = document.getElementById(id);
    if(el) el.value = val;
}

function initAutocomplete(){
    var input = document.getElementById('awg_geo_v2fly');
    if(!input) return;
    var wrap = document.createElement('div');
    wrap.className = 'awg-ac-wrap';
    input.parentNode.insertBefore(wrap, input);
    wrap.appendChild(input);
    var list = document.createElement('div');
    list.className = 'awg-ac-list';
    list.id = 'awg_ac_list';
    wrap.appendChild(list);
    var selIdx = -1;

    function getLastToken(){
        var val = input.value;
        var parts = val.split(',');
        return parts[parts.length - 1].trim();
    }

    function getExisting(){
        return input.value.split(',').map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    }

    function showSuggestions(){
        var q = getLastToken().toLowerCase();
        var existing = getExisting();
        list.innerHTML = '';
        selIdx = -1;
        if(q.length < 1){ list.style.display = 'none'; return; }
        var matches = v2flyList.filter(function(s){
            return s.indexOf(q) !== -1 && existing.indexOf(s) === -1;
        }).slice(0, 15);
        if(matches.length === 0){ list.style.display = 'none'; return; }
        for(var i = 0; i < matches.length; i++){
            var d = document.createElement('div');
            d.textContent = matches[i];
            d.onmousedown = function(e){ e.preventDefault(); pickItem(this.textContent); };
            list.appendChild(d);
        }
        list.style.display = 'block';
    }

    function pickItem(val){
        var parts = input.value.split(',').map(function(s){ return s.trim(); }).filter(function(s){ return s; });
        parts.pop();
        parts.push(val);
        input.value = parts.join(',') + ',';
        list.style.display = 'none';
        input.focus();
    }

    input.addEventListener('input', showSuggestions);
    input.addEventListener('focus', showSuggestions);
    input.addEventListener('blur', function(){ setTimeout(function(){ list.style.display = 'none'; }, 200); });
    input.addEventListener('keydown', function(e){
        var items = list.querySelectorAll('div');
        if(e.key === 'ArrowDown'){ e.preventDefault(); selIdx = Math.min(selIdx + 1, items.length - 1); }
        else if(e.key === 'ArrowUp'){ e.preventDefault(); selIdx = Math.max(selIdx - 1, 0); }
        else if(e.key === 'Enter' && selIdx >= 0){ e.preventDefault(); pickItem(items[selIdx].textContent); return; }
        else return;
        for(var i = 0; i < items.length; i++) items[i].className = (i === selIdx) ? 'selected' : '';
    });
}

function initAutocompleteIp(){
    var input = document.getElementById('awg_geo_v2fly_ip');
    if(!input) return;
    var wrap = document.createElement('div');
    wrap.className = 'awg-ac-wrap';
    input.parentNode.insertBefore(wrap, input);
    wrap.appendChild(input);
    var list = document.createElement('div');
    list.className = 'awg-ac-list';
    list.id = 'awg_ac_list_ip';
    wrap.appendChild(list);
    var selIdx = -1;

    function getLastToken(){
        var parts = input.value.split(',');
        return parts[parts.length - 1].trim();
    }
    function getExisting(){
        return input.value.split(',').map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    }
    function showSuggestions(){
        var q = getLastToken().toLowerCase();
        var existing = getExisting();
        list.innerHTML = '';
        selIdx = -1;
        if(q.length < 1){ list.style.display = 'none'; return; }
        var matches = v2flyIpList.filter(function(s){
            return s.indexOf(q) !== -1 && existing.indexOf(s) === -1;
        }).slice(0, 15);
        if(matches.length === 0){ list.style.display = 'none'; return; }
        for(var i = 0; i < matches.length; i++){
            var d = document.createElement('div');
            d.textContent = matches[i];
            d.onmousedown = function(e){ e.preventDefault(); pickItem(this.textContent); };
            list.appendChild(d);
        }
        list.style.display = 'block';
    }
    function pickItem(val){
        var parts = input.value.split(',').map(function(s){ return s.trim(); }).filter(function(s){ return s; });
        parts.pop();
        parts.push(val);
        input.value = parts.join(',') + ',';
        list.style.display = 'none';
        input.focus();
    }
    input.addEventListener('input', showSuggestions);
    input.addEventListener('focus', showSuggestions);
    input.addEventListener('blur', function(){ setTimeout(function(){ list.style.display = 'none'; }, 200); });
    input.addEventListener('keydown', function(e){
        var items = list.querySelectorAll('div');
        if(e.key === 'ArrowDown'){ e.preventDefault(); selIdx = Math.min(selIdx + 1, items.length - 1); }
        else if(e.key === 'ArrowUp'){ e.preventDefault(); selIdx = Math.max(selIdx - 1, 0); }
        else if(e.key === 'Enter' && selIdx >= 0){ e.preventDefault(); pickItem(items[selIdx].textContent); return; }
        else return;
        for(var i = 0; i < items.length; i++) items[i].className = (i === selIdx) ? 'selected' : '';
    });
}
</script>
</head>
<body onload="initial();" onunload="clearInterval(statusTimer);">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="about:blank" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="action_wait" value="15">
<input type="hidden" name="amng_custom" id="amng_custom" value="">

<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
    <td width="17">&nbsp;</td>
    <td valign="top" width="202">
        <div id="mainMenu"></div>
        <div id="subMenu"></div>
    </td>
    <td valign="top">
        <div id="tabMenu" class="submenuBlock"></div>
        <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
        <tr>
            <td valign="top">

            <!-- ==================== STATUS ==================== -->
            <table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
            <tr><td bgcolor="#4D595D" valign="top">
                <div>&nbsp;</div>
                <div class="formfonttitle" style="display:flex; align-items:center; gap:10px;">
                    <span style="font-size:20px; font-weight:bold; letter-spacing:1px;">AmneziaWG</span>
                    <span style="font-size:13px; font-weight:normal;">VPN Client</span>
                    <a href="https://t.me/asusxray" target="_blank" style="margin-left:auto; font-size:12px; text-decoration:none;" title="Telegram-чат">💬 Telegram</a>
                    <a href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" title="GitHub репозиторий" style="font-size:12px; text-decoration:none;"><img src="https://img.shields.io/github/v/release/william-aqn/asuswrt-merlin-amneziawg?logo=github&label=release" alt="GitHub" style="height:18px; display:block;" onerror="this.onerror=null; this.outerHTML='🐙 GitHub';"></a>
                    <span id="awg_update_btn" style="display:none;"></span>
                </div>
                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                <!-- Status & Actions -->
                <table width="100%" border="0" cellpadding="4" cellspacing="0">
                <tr>
                    <th width="20%">Status</th>
                    <td>
                        <span id="awg_badge" class="awg-status connecting">&#9679; Загрузка…</span>
                        &nbsp;&nbsp;
                        <input type="button" id="btn_start" class="button_gen awg-btn" value="Start" onclick="awgAction('start_awgstart');">
                        <input type="button" id="btn_stop" class="button_gen awg-btn" value="Stop" style="display:none;" onclick="awgAction('start_awgstop');">
                        <input type="button" id="btn_restart" class="button_gen awg-btn" value="Restart" style="display:none;" onclick="awgAction('start_awgrestart');">
                    </td>
                </tr>
                <tr>
                    <th width="20%">Interface</th>
                    <td><span id="awg_info">-</span></td>
                </tr>
                </table>

                <!-- Peers Table -->
                <div class="awg-section">Connected Peers</div>
                <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable_table" id="awg_peers_table">
                <thead><tr>
                    <td width="25%">Endpoint</td>
                    <td width="25%">Allowed IPs</td>
                    <td width="25%">Transfer (RX/TX)</td>
                    <td width="25%">Last Handshake</td>
                </tr></thead>
                <tbody id="awg_peers">
                    <tr><td colspan="4" style="text-align:center; color:#666;">No peers</td></tr>
                </tbody>
                </table>

                <div style="margin:15px 0 10px 0;" class="splitLine"></div>

                <!-- ==================== CONFIG ==================== -->
                <div class="awg-section">Configuration</div>
                <div style="margin-bottom:8px;">
                    <input type="button" class="button_gen" value="Import Config" onclick="importConfig();">
                    <span style="color:#AAA; margin-left:10px; font-size:12px;">Upload .conf file from Amnezia VPN client</span>
                </div>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable">
                <thead><tr><td colspan="2">Interface</td></tr></thead>
                <tr>
                    <th width="35%">Private Key</th>
                    <td><input type="password" class="input_32_table" id="awg_privatekey" maxlength="64" autocomplete="off"></td>
                </tr>
                <tr>
                    <th>Address</th>
                    <td><input type="text" class="input_20_table" id="awg_address" maxlength="32" placeholder="10.7.0.2/24"></td>
                </tr>
                <tr>
                    <th>Listen Port</th>
                    <td><input type="text" class="input_6_table" id="awg_listenport" maxlength="5" placeholder="51820"></td>
                </tr>
                <tr>
                    <th>MTU</th>
                    <td><input type="text" class="input_6_table" id="awg_mtu" maxlength="4" placeholder="1280">
                        <span style="color:#666; font-size:11px; margin-left:6px;">default 1280 (576–1500)</span></td>
                </tr>
                <tr>
                    <th>DNS</th>
                    <td><input type="text" class="input_20_table" id="awg_dns" maxlength="64" placeholder="1.1.1.1"></td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Peer</td></tr></thead>
                <tr>
                    <th width="35%">Public Key</th>
                    <td><input type="text" class="input_32_table" id="awg_peer_pubkey" maxlength="64"></td>
                </tr>
                <tr>
                    <th>Preshared Key</th>
                    <td><input type="password" class="input_32_table" id="awg_peer_psk" maxlength="64" autocomplete="off" placeholder="(optional)"></td>
                </tr>
                <tr>
                    <th>Endpoint</th>
                    <td><input type="text" class="input_25_table" id="awg_peer_endpoint" maxlength="64" placeholder="server.example.com:51820"></td>
                </tr>
                <tr>
                    <th>Allowed IPs</th>
                    <td><input type="text" class="input_25_table" id="awg_peer_allowedips" maxlength="128" placeholder="0.0.0.0/0"></td>
                </tr>
                <tr>
                    <th>Persistent Keepalive</th>
                    <td><input type="text" class="input_6_table" id="awg_peer_keepalive" maxlength="4" placeholder="25"> sec</td>
                </tr>
                </table>

                <!-- ==================== OBFUSCATION ==================== -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">AmneziaWG Obfuscation</td></tr></thead>
                <tr>
                    <th width="35%">Jc (junk packet count)</th>
                    <td><input type="text" class="input_6_table" id="awg_jc" maxlength="3" placeholder="4"> (0-128)</td>
                </tr>
                <tr>
                    <th>Jmin (min junk size)</th>
                    <td><input type="text" class="input_6_table" id="awg_jmin" maxlength="5" placeholder="40"> bytes</td>
                </tr>
                <tr>
                    <th>Jmax (max junk size)</th>
                    <td><input type="text" class="input_6_table" id="awg_jmax" maxlength="5" placeholder="70"> bytes</td>
                </tr>
                <tr>
                    <th>S1 (init padding)</th>
                    <td><input type="text" class="input_6_table" id="awg_s1" maxlength="3" placeholder="20"> bytes</td>
                </tr>
                <tr>
                    <th>S2 (response padding)</th>
                    <td><input type="text" class="input_6_table" id="awg_s2" maxlength="3" placeholder="30"> bytes</td>
                </tr>
                <tr>
                    <th>S3</th>
                    <td><input type="text" class="input_6_table" id="awg_s3" maxlength="3" placeholder="0"> bytes</td>
                </tr>
                <tr>
                    <th>S4</th>
                    <td><input type="text" class="input_6_table" id="awg_s4" maxlength="3" placeholder="0"> bytes</td>
                </tr>
                <tr>
                    <th>H1 (init header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h1" maxlength="32" placeholder="1234567891"></td>
                </tr>
                <tr>
                    <th>H2 (response header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h2" maxlength="32" placeholder="1987654321"></td>
                </tr>
                <tr>
                    <th>H3 (cookie header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h3" maxlength="32" placeholder="1112223334"></td>
                </tr>
                <tr>
                    <th>H4 (data header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h4" maxlength="32" placeholder="4445556667"></td>
                </tr>
                <tr>
                    <th>I1 (init junk)</th>
                    <td><input type="text" class="input_32_table" id="awg_i1" style="width:95%; font-size:11px;" maxlength="5000" placeholder="Auto-filled by Import Config"></td>
                </tr>
                <tr>
                    <th>I2</th>
                    <td><input type="text" class="input_32_table" id="awg_i2" style="width:95%; font-size:11px;" maxlength="5000" placeholder="(optional)"></td>
                </tr>
                <tr>
                    <th>I3</th>
                    <td><input type="text" class="input_32_table" id="awg_i3" style="width:95%; font-size:11px;" maxlength="5000" placeholder="(optional)"></td>
                </tr>
                <tr>
                    <th>I4</th>
                    <td><input type="text" class="input_32_table" id="awg_i4" style="width:95%; font-size:11px;" maxlength="5000" placeholder="(optional)"></td>
                </tr>
                <tr>
                    <th>I5</th>
                    <td><input type="text" class="input_32_table" id="awg_i5" style="width:95%; font-size:11px;" maxlength="5000" placeholder="(optional)"></td>
                </tr>
                </table>

                <!-- ==================== ROUTING ==================== -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Routing Policy</td></tr></thead>
                <tr>
                    <th width="35%">Default Policy</th>
                    <td>
                        <select id="default_policy" class="input_option" onchange="updateGeoVisibility();"
                                style="font-size:13px; font-weight:bold;">
                            <option value="direct">Direct (no VPN)</option>
                            <option value="vpn_all">VPN — All Traffic</option>
                            <option value="vpn_geo">VPN — Geo Only</option>
                        </select>
                        <span style="color:#666; font-size:11px; margin-left:8px;">For devices not in the list below</span>
                        <span id="awg_active_rules" style="margin-left:12px; color:#666; font-size:11px;"></span>
                    </td>
                </tr>
                <tr>
                    <th>Prevent IPv6 Leaks</th>
                    <td>
                        <label><input type="checkbox" id="awg_block_ipv6_dns"> Block IPv6 DNS resolution (filter-AAAA)</label>
                        <div style="color:#666; font-size:11px; margin-top:3px;">Critical for Geo routing reliability. Prevents dual-stack domains from bypassing the VPN.</div>
                    </td>
                </tr>
                </table>

                <div class="awg-section">Device Rules</div>
                <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable_table" id="awg_client_table">
                <thead><tr>
                    <td width="25%">IP Address</td>
                    <td width="25%">Device Name</td>
                    <td width="30%">Policy</td>
                    <td width="20%">Action</td>
                </tr></thead>
                <tbody id="awg_client_rows">
                </tbody>
                </table>
                <div style="margin-top:6px;">
                    <input type="button" class="button_gen" value="+ Add Device" onclick="addClientRow('','','vpn_all');">
                    <input type="button" class="button_gen" value="+ From DHCP List" onclick="fetchDhcpClients();" style="margin-left:6px;">
                </div>

                <!-- ==================== GEO ROUTING ==================== -->
                <div id="geo_section" style="display:none;">

                <div style="border:1px solid #fc0; border-radius:4px; padding:10px 14px; margin-top:10px; font-size:12px; color:#fc0;">
                    <b>Важно:</b> Для работы VPN Geo устройства должны использовать роутер как DNS-сервер.<br>
                    iPhone: Настройки &gt; Wi-Fi &gt; (i) &gt; DNS &gt; Вручную &gt; только <% nvram_get("lan_ipaddr"); %><br>
                    macOS/Windows: укажите <% nvram_get("lan_ipaddr"); %> как DNS в настройках сети. Отключите DNS-over-HTTPS в браузере.
                </div>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">GeoIP — Route by Service IP</td></tr></thead>
                <tr>
                    <th width="35%">GeoIP Service Lists<br><span style="font-weight:normal; font-size:11px; color:#888;">github.com/Loyalsoldier/geoip</span></th>
                    <td>
                        <input type="text" class="input_32_table" id="awg_geo_v2fly_ip" style="width:95%;" maxlength="512"
                            placeholder="telegram,google,facebook,twitter,netflix,cloudflare">
                        <br><span style="color:#888; font-size:11px;">Comma-separated. Available: telegram, google, facebook, twitter, netflix, cloudflare, fastly, cloudfront, tor + country codes (us, ru, cn, ...).</span>
                        <br><span style="color:#f0ad4e; font-size:11px;">⚠ For youtube, discord, microsoft, github, openai etc. there are NO IP lists — use GeoSite below.</span>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">GeoSite — Route by Service / Domain</td></tr></thead>
                <tr>
                    <th width="35%">GeoSite Service Lists<br><span style="font-weight:normal; font-size:11px; color:#888;">github.com/v2fly/domain-list-community</span></th>
                    <td>
                        <input type="text" class="input_32_table" id="awg_geo_v2fly" style="width:95%;" maxlength="512"
                            placeholder="youtube,google,discord,netflix,telegram,twitter,instagram,facebook,tiktok,spotify">
                        <br><span style="color:#888; font-size:11px;">Comma-separated. 1500+ lists: youtube, google, discord, netflix, telegram, twitter, instagram, facebook, tiktok, spotify, steam, apple, microsoft, amazon, openai, github, whatsapp, category-media, category-games, category-dev ...</span>
                    </td>
                </tr>
                <tr>
                    <th>Custom Domains</th>
                    <td>
                        <input type="text" class="input_32_table" id="geo_custom_domains" style="width:95%;"
                               maxlength="2000" placeholder="example.com,another.org,service.net">
                        <div style="color:#666; font-size:11px; margin-top:3px;">Comma-separated. DNS-resolved → routed through VPN</div>
                    </td>
                </tr>
                <tr>
                    <th>Custom IPs / Subnets</th>
                    <td>
                        <input type="text" class="input_32_table" id="geo_custom_ips" style="width:95%;"
                               maxlength="2000" placeholder="8.8.8.8,1.1.1.0/24,203.0.113.0/24">
                        <div style="color:#666; font-size:11px; margin-top:3px;">Comma-separated IPs or CIDR subnets</div>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Geo Antifilter — РКН-списки (antifilter.download)</td></tr></thead>
                <tr>
                    <th width="35%">Antifilter IP-списки<br><span style="font-weight:normal; font-size:11px; color:#888;">antifilter.download</span></th>
                    <td>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="allyouneed"> allyouneed — все нужные подсети (~15K) <span style="color:#5bd75b;">рекомендуется</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="community"> community — подсети сообщества (~900)</label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ipsum"> ipsum — IP, сжатые до /24 (~15K)</label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="subnet"> subnet — крупные подсети (~78)</label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ip"> ip — отдельные IP (~48K)</label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ipresolve"> ipresolve — IP из DNS-резолва (~154K) <span style="color:#f0ad4e;">⚠ очень большой</span></label>
                        <div style="color:#888; font-size:11px; margin-top:4px;">Загружаются в общий ipset awg_dst вместе с GeoIP и маршрутизируются через VPN. allyouneed = ipsum + subnet; ip/ipresolve сильно пересекаются с allyouneed — обычно достаточно allyouneed.</div>
                    </td>
                </tr>
                <tr>
                    <th>Antifilter домены</th>
                    <td>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="community_domains"> community домены (~485) → dnsmasq</label>
                        <div style="color:#888; font-size:11px; margin-top:4px;">Полный domains.lst (1.4M доменов / 27 МБ) не поддерживается — слишком большой для dnsmasq на роутере.</div>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Geo update settings</td></tr></thead>
                <tr>
                    <th width="35%">Auto-update Lists</th>
                    <td>
                        <label><input type="checkbox" id="geo_autoupdate"> Daily at 4:00 AM</label>
                        &nbsp;&nbsp;
                        <input type="button" class="button_gen" id="btn_geo_update" value="Update Now" onclick="updateGeoLists();">
                    </td>
                </tr>
                <tr>
                    <th>Wipe before update</th>
                    <td>
                        <label><input type="checkbox" id="awg_geo_wipe_update"> Delete all geo files before a full update / program upgrade</label>
                        <div style="color:#888; font-size:11px; margin-top:3px;">Off (default): keeps existing geo lists — including across a program update (no re-download). On: wipes before re-download (clean set, but a failed download leaves a list missing).</div>
                    </td>
                </tr>
                </table>

                </div>

                <!-- ==================== DOWNLOAD VIA VPN ==================== -->
                <!-- Outside geo_section: the program-update toggle must show even when no
                     device uses geo routing. -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Загрузка через VPN (обход блокировок)</td></tr></thead>
                <tr>
                    <th width="35%">Geo-списки через VPN</th>
                    <td>
                        <label><input type="checkbox" id="awg_geo_via_awg"> Загружать geo-списки через активный AWG-туннель</label>
                        <div style="color:#888; font-size:11px; margin-top:3px;">Пока туннель поднят, загрузка GeoIP / GeoSite / antifilter идёт через VPN (обход блокировок GitHub / jsDelivr). Если VPN выключен — загрузка идёт напрямую, как раньше.</div>
                    </td>
                </tr>
                <tr>
                    <th>Обновление программы через VPN</th>
                    <td>
                        <label><input type="checkbox" id="awg_update_via_awg"> Загружать обновление программы через активный AWG-туннель</label>
                        <div style="color:#888; font-size:11px; margin-top:3px;">Проверка версии и загрузка <code>.ipk</code> идут через VPN, пока туннель активен — можно ставить обновления прямо с GitHub в обход региональных блокировок (и проверять SHA256 по GitHub API). DNS-резолвинг остаётся системным; обход работает для блокировок по IP/TCP. Если VPN выключен — напрямую, как раньше.</div>
                    </td>
                </tr>
                </table>

                <!-- Apply -->
                <div style="margin-top:12px; text-align:center;">
                    <input type="button" class="button_gen" value="Apply" onclick="saveSettings();" title="Сохранить и применить без перезапуска VPN">
                    <input type="button" class="button_gen" value="Force Apply" onclick="forceApply();" style="margin-left:8px;" title="Сохранить + перезапуск VPN + полная пересборка маршрутов и firewall">
                </div>
                <div style="font-size:11px; opacity:0.7; margin:8px auto 0; max-width:640px; line-height:1.55; text-align:left;">
                    <div><b>Apply</b> — сохранить настройки и применить их «на лету»: обновляет устройства, политики маршрутизации, firewall и списки GeoIP/GeoSite <b>без разрыва VPN-соединения</b>. Если VPN остановлен — настройки просто сохранятся и применятся при следующем Start.</div>
                    <div style="margin-top:4px;"><b>Force Apply</b> — сохранить и <b>полностью перезапустить VPN</b> (stop → start): заново применяется конфиг (awg setconf), пересобираются интерфейс, маршруты и firewall. Нужен при смене ключей, сервера (Endpoint), MTU или параметров обфускации (Jc, S1, H1…H4), а также если соединение «залипло».</div>
                </div>

                <!-- ==================== LOG ==================== -->
                <div class="awg-section" style="margin-top:15px;">Log</div>
                <div id="awg_log" class="awg-log">Waiting for data...</div>
                <div style="text-align:right; font-size:11px; opacity:0.5; margin-top:4px;">
                    <a href="https://github.com/r0otx/asuswrt-merlin-amneziawg" target="_blank" style="text-decoration:none;">&copy; r0otx</a>
                    &nbsp;&middot;&nbsp;
                    <a href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" style="text-decoration:none;">mod by DCRM</a>
                </div>

            </td></tr>
            </table>

            </td>
        </tr>
        </table>
    </td>
</tr>
</table>
</form>

<!-- Update modal: changelog + confirm -->
<div id="awg_update_modal" style="display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.65); z-index:10000;">
    <div style="background:#2b3338; color:#e0e0e0; width:90%; max-width:680px; margin:4% auto; border:1px solid #444; border-radius:8px; box-shadow:0 6px 40px rgba(0,0,0,0.6); display:flex; flex-direction:column; max-height:84vh;">
        <div style="padding:14px 18px; border-bottom:1px solid #444; display:flex; align-items:center;">
            <span id="awg_modal_title" style="font-size:16px; font-weight:bold;">Обновление</span>
            <span style="margin-left:auto; cursor:pointer; font-size:22px; line-height:1; opacity:0.6;" onclick="closeUpdateModal();" title="Закрыть">&times;</span>
        </div>
        <div id="awg_modal_body" style="padding:14px 18px; overflow-y:auto; font-size:12px; line-height:1.5;"></div>
        <div style="padding:10px 18px; border-top:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:8px; font-size:12px;">
            <span style="opacity:0.75;">Установить:</span>
            <select id="awg_install_mode" onchange="awgModeUI();" style="padding:2px 6px; background:#222; color:#e0e0e0; border:1px solid #555; border-radius:4px;">
                <option value="auto">Автоматически (последняя)</option>
                <option value="version">Выбрать версию</option>
                <option value="file">Вручную через файл</option>
            </select>
            <input type="text" id="awg_version_input" placeholder="напр. 1.1.49" maxlength="12" style="width:100px; padding:2px 6px; background:#222; color:#e0e0e0; border:1px solid #555; border-radius:4px; display:none;">
            <input type="file" id="awg_ipk_file" accept=".ipk" style="display:none; color:#e0e0e0; max-width:240px;">
            <input type="button" id="awg_install_btn" class="button_gen" value="Установить" onclick="installUpdate();">
        </div>
        <div id="awg_manual_progress" style="display:none; padding:0 18px 12px;">
            <div style="height:10px; background:#1c2226; border:1px solid #555; border-radius:5px; overflow:hidden;">
                <div id="awg_manual_bar" style="height:100%; width:0%; background:#cf0a2c; transition:width 0.2s;"></div>
            </div>
            <div id="awg_manual_msg" style="font-size:11px; opacity:0.85; margin-top:5px;"></div>
        </div>
        <div style="padding:12px 18px; border-top:1px solid #444; display:flex; align-items:center;">
            <span id="awg_modal_status" style="font-size:12px; opacity:0.75; margin-right:auto;"></span>
            <input type="button" class="button_gen" value="Проверить обновления" onclick="checkForUpdate();">
            <input type="button" class="button_gen" value="Закрыть" onclick="closeUpdateModal();" style="margin-left:8px;">
        </div>
    </div>
</div>

<div id="footer"></div>
</body>
</html>
