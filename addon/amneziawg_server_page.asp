<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>AmneziaWG Server</title>
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
.awg-status { padding: 8px 16px; border-radius: 4px; font-weight: bold; display: inline-block; font-size: 13px; letter-spacing: 0.5px; text-transform: uppercase; }
.awg-status.running { background: #1a6e2e; color: #fff; border: 1px solid #2a8b42; }
.awg-status.stopped { background: #8b0000; color: #fff; border: 1px solid #a00; }
.awg-status.connecting { background: #b8860b; color: #fff; border: 1px solid #daa520; }
.awg-section { margin: 14px 0 6px 0; padding-left: 5px; font-size: 14px; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px; }
.awg-log { font-family: "Courier New", "Lucida Console", monospace; font-size: 12px; padding: 10px; height: 240px; min-height: 100px; resize: vertical; overflow-y: auto; border: 1px solid #444; border-radius: 3px; white-space: pre-wrap; word-wrap: break-word; }
.awg-btn { margin: 0 4px; }
.awg-hint { color: #b6bdc7; font-size: 11px; line-height: 1.5; margin-top: 4px; }
.awg-hint code, .awg-hint b { color: #d7dce3; }
.awg-hint code { font-family: "Courier New", "Lucida Console", monospace; background: rgba(255,255,255,0.07); padding: 1px 5px; border-radius: 3px; }
/* Masked key fields: same embedded disc-font trick as the client page (no -webkit-text-security,
   no type=password — keeps Safari/Chromium password managers away from WG keys). */
@font-face { font-family: 'awg-disc'; src: url(data:font/woff2;base64,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) format('woff2'); }
.awg-dotted { font-family: 'awg-disc', "Courier New", "Lucida Console", monospace; }
.awg-dotted::placeholder { font-family: "Courier New", "Lucida Console", monospace; }
#awgs_peer_table { width: 100%; table-layout: fixed; }
#awgs_peer_table thead td { font-weight: bold; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }
#awgs_peer_table td { word-wrap: break-word; overflow: hidden; }
#awgs_peer_table input[type="text"], #awgs_peer_table select { width: 96%; }
.awg-banner { margin: 8px 0; padding: 10px 14px; border-radius: 5px; font-size: 12px; line-height: 1.55; }
.awg-banner.red { background: #33191b; border: 1px solid #c0392b; }
.awg-banner.yellow { background: #332d19; border: 1px solid #c7a22e; }
.awg-banner.blue { background: #1b2a33; border: 1px solid #2e88c7; }
.awg-mini {
    font-size: 11px; line-height: 1.5;
    padding: 4px 12px; margin: 2px 0; cursor: pointer;
    border-radius: 4px; border: 1px solid #5a6a72;
    background: linear-gradient(#3d4b52, #2c363b); color: #e6ebf0;
    transition: background .12s, border-color .12s;
}
.awg-mini:hover { background: linear-gradient(#4a5a62, #364248); border-color: #7f909a; }
.awg-mini:active { background: #2c363b; }
.awg-mini.accent { background: linear-gradient(#c8324a, #9e2438); border-color: #d9536a; color: #fff; font-weight: bold; }
.awg-mini.accent:hover { background: linear-gradient(#d64258, #b02a42); }
.awg-mini.danger { color: #ffb3bd; }
.awg-mini.danger:hover { background: linear-gradient(#7a2a30, #5a1e22); border-color: #c0392b; color: #fff; }
/* Peer-row action buttons: uniform, tidy, centred in the cell */
#awgs_peer_table td:last-child { text-align: center; white-space: nowrap; }
#awgs_peer_table .awg-mini { display: block; width: 80%; min-width: 54px; margin: 3px auto; }
#awgs_qr_modal { display: none; position: fixed; z-index: 600; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.75); }
#awgs_qr_inner { background: #21333e; border: 1px solid #4d595d; border-radius: 6px; max-width: 720px; margin: 4% auto; padding: 18px 22px; max-height: 88%; overflow-y: auto; }
#awgs_qr_svg { background: #fff; padding: 10px; border-radius: 6px; width: 320px; max-width: 90%; margin: 10px auto; display: block; }
#awgs_qr_conf { width: 100%; height: 220px; font-family: "Courier New", monospace; font-size: 11px; background: #101c24; color: #cfd8de; border: 1px solid #444; border-radius: 3px; white-space: pre; overflow: auto; padding: 8px; box-sizing: border-box; }
</style>
<script>
var custom_settings = <% get_custom_settings(); %>;
var statusTimer = null;
var awgsActionGen = 0;          // generation token: stale in-flight polls must not repaint the UI
var awgsStatus = null;
var awgsPeers = [];             // working copy of the peer store (saved on Apply)
var awgsDirty = false;
var awgsQrLibLoaded = false;
var awgsTick = null;

function escHtml(s){
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

// Neutralize the firmware's global loading overlay. Our form submits to hidden_frame (no full
// page reload), but the firmware's apply path still fires showLoading() and greys the whole
// page — and hideLoading() never runs without the reload, so the page stays frozen after
// «Apply» (field-reported). The client page stubs these the same way; do it here too.
function showLoading(){}
function hideLoading(){}

/* ---- i18n (firmware language: RU -> ru, else en) ---- */
var AWG_LANG = (function(){
    try { return (httpApi.nvramGet(["preferred_lang"]).preferred_lang === 'RU') ? 'ru' : 'en'; }
    catch(e){ return 'en'; }
})();
var AWG_I18N = {
en: {
    LBL_ROLE: "VPN server (inbound connections)",
    STAT_LOADING_BADGE: "&#9679; Loading…",
    STAT_RUNNING: "Running",
    STAT_STOPPED: "Stopped",
    STAT_STARTING: "Starting…",
    STAT_STOPPING: "Stopping…",
    TH_STATUS: "Status",
    TH_ENDPOINT: "Server address",
    BTN_START: "Start server",
    BTN_STOP: "Stop",
    BTN_RESTART: "Restart",
    BTN_APPLY: "Apply",
    BTN_APPLYING: "Applying…",
    ACK_SAVED: "Saved ✓",
    SEC_SETTINGS: "Server settings",
    SEC_OBFS: "Obfuscation parameters (shared by all peer configs)",
    SEC_PEERS: "Peers (devices that connect to this router)",
    SEC_LOG: "Log",
    LBL_PRIVKEY: "Server private key",
    LBL_PUBKEY: "Server public key",
    BTN_GENKEYS: "Generate",
    LBL_PORT: "Listen port (UDP)",
    LBL_SUBNET: "Tunnel subnet",
    LBL_MTU: "MTU",
    LBL_ENDPOINT_OVR: "Endpoint host override",
    HINT_ENDPOINT_OVR: "Leave empty to use DDNS/WAN address automatically: <code>{0}</code>",
    LBL_DNS_MODE: "DNS for peers",
    OPT_DNS_ROUTER: "Router (recommended — LAN names + domain Geo work)",
    OPT_DNS_CUSTOM: "Custom servers",
    LBL_DNS_CUSTOM: "DNS servers (comma-separated)",
    LBL_NAT_LAN: "NAT to LAN (peers appear as the router — fixes Windows firewall silence)",
    LBL_AUTOSTART: "Start server automatically after reboot",
    HINT_SUBNET: "Format <code>x.y.z.0/24</code>. Router takes .1, peers .2–.254. Avoid your LAN subnet.",
    BTN_GEN_OBFS: "Generate random",
    HINT_OBFS: "These values are embedded into every peer config — clients must match the server exactly. Changing them disconnects peers until they re-import configs.",
    LBL_IPARAMS: "I1–I5 (advanced, AWG 2.x signature packets)",
    HINT_IPARAMS: "Optional. Junk/signature packets sent before the handshake to camouflage the flow. «Generate» fills I1–I2 with a unique random signature. Tags: <code>&lt;b 0xHEX&gt;</code> fixed bytes, <code>&lt;r N&gt;</code> random bytes, <code>&lt;rc N&gt;</code> random letters, <code>&lt;rd N&gt;</code> random digits, <code>&lt;t&gt;</code> timestamp. Requires AmneziaWG 2.x clients (embedded into every peer config automatically).",
    BTN_GEN_IPARAMS: "Generate",
    TH_PEER_NAME: "Name",
    TH_PEER_IP: "IP",
    TH_PEER_POLICY: "Routing policy",
    TH_PEER_MODE: "Tunnel scope",
    TH_PEER_ON: "On",
    TH_PEER_STATE: "Handshake / traffic",
    TH_PEER_ACT: "Config",
    OPT_MODE_FULL: "All traffic",
    OPT_MODE_LAN: "Home network only",
    BYPASS_XRAY: "bypass Xray",
    BYPASS_XRAY_TT: "Force this peer into the client tunnel (double hop) even while Xray runs — a rule is inserted ahead of Xray's transparent proxy so this peer's traffic isn't captured by it. Needs the client tunnel up. Direct peers are unaffected.",
    OPT_DIRECT: "Direct",
    OPT_VPN_ALL: "VPN: all traffic",
    OPT_VPN_GEO: "VPN: Geo only",
    OPT_VPN_GEO_PREFIX: "VPN: ",
    BTN_ADD_PEER: "+ Add peer",
    BTN_QR: "QR",
    BTN_DL: ".conf",
    BTN_DEL: "✕",
    HS_NEVER: "never",
    AGO_SEC: "{0} s ago",
    AGO_MIN: "{0} min ago",
    AGO_HOUR: "{0} h ago",
    QR_TITLE: "Peer configuration — {0}",
    BTN_COPY: "Copy",
    BTN_CLOSE: "Close",
    MSG_COPIED: "Copied ✓",
    MSG_DEL_PEER: "Delete peer «{0}»? Its device will no longer be able to connect (after Apply).",
    MSG_NEED_SAVE: "There are unsaved changes — click «Apply» first, then the server will hand out the new peer list.",
    MSG_KEYS_REQUIRED: "Generate or enter the server private key first.",
    MSG_BAD_SUBNET: "Tunnel subnet must look like 10.9.0.0/24 (a /24 ending in .0).",
    MSG_BAD_PORT: "Port must be 1–65535.",
    MSG_SUBNET_IS_LAN: "The tunnel subnet must differ from your LAN subnet ({0}).",
    MSG_PEERS_FULL: "No free addresses left in the subnet (.2–.254 are taken).",
    MSG_GEN_CONFIRM: "Generate new obfuscation parameters? All existing peers will need to re-import their configs.",
    MSG_REGEN_KEYS: "Generate a NEW server key pair? Every existing peer config becomes invalid (clients must re-import).",
    MSG_APPLY_RESTART_HINT: "Settings are applied live where possible; subnet/key changes restart the server.",
    BAN_FIRSTRUN: "<b>Server is not configured yet.</b><br>Click «Generate» for the server keys, check the port and subnet, add a peer, then press «Apply» and «Start server».",
    BAN_WAN_PRIVATE: "<b>WAN address is private/CGNAT ({0}).</b> Peers from the internet cannot reach this router directly — you need a public IP from your ISP or a port forward (UDP {1}) on the upstream router.",
    BAN_PORT_CONFLICT: "<b>The firmware WireGuard server uses the same UDP port {0}.</b> Change this server's port or disable the firmware WG server (VPN → WireGuard).",
    BAN_CLIENT_DOWN: "The AmneziaWG <b>client</b> tunnel is not running — peers with a «VPN…» policy currently go <b>directly</b> to the internet through your WAN (fail-open). Start the client tunnel on the AmneziaWG page for the policies to apply.",
    BAN_UNSAVED: "Unsaved changes — press «Apply».",
    BAN_XRAY_POLICY: "⛔ <b>Xray / XRAYUI</b> is running in transparent-proxy mode («redirect all»), and some peers have a «VPN…» policy <b>without «bypass Xray»</b>. For those peers the double hop doesn't happen — Xray captures their traffic in PREROUTING before AmneziaWG's routing rule (ip-rule 19 vs 99), so they exit through Xray, not the client tunnel. Fixes:<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li><b>Want the double hop</b> — tick <b>«bypass Xray»</b> on the peer: a rule is placed ahead of Xray so this peer goes into the client tunnel (which must be up). Xray keeps running for everything else.</li><li><b>Fine with Xray</b> — switch the peer to «Direct»: its traffic flows through Xray anyway (DPI bypass).</li><li>Or stop Xray entirely (button below).</li></ul>",
    BAN_XRAY_INFO: "<b>Xray / XRAYUI</b> is running in transparent-proxy mode («redirect all») — peer traffic automatically flows <b>through Xray</b> (DPI bypass), non-proxied destinations go straight to WAN. This is a working setup. For a peer that should instead double-hop through the client tunnel, give it a «VPN…» policy and tick «bypass Xray».",
    BAN_XRAY_UNCOVERED: "<b>Xray / XRAYUI</b> is running, but the peer subnet <code>{0}</code> is <b>not in its capture rules</b> — peer traffic bypasses Xray and goes straight to WAN (no DPI bypass). This usually means XRAYUI started before this server did. Fix: <b>restart XRAYUI</b> (it picks up existing interfaces at start), or add the subnet to its transparent-proxy settings.",
    XRAY_STOP_BTN: "Stop Xray",
    XRAY_STOPPING: "Stopping Xray…",
    XRAY_STOP_CONFIRM: "Stop Xray / XRAYUI now? This is a regular stop via XRAYUI's own command — same as the Stop button on its page. Only the active TPROXY firewall rules are removed so AmneziaWG can route peer traffic; XRAYUI's saved settings and rules are not touched. Start it again from its page (VPN → X-RAY) and it will come back with all its previous settings.",
    DONATE_LABEL: "Support the project",
    DONATE_COPY_TITLE: "Click to copy the address",
    ADDR_COPIED: "Copied ✓",
    LOG_EMPTY: "(empty)",
    QR_LIB_FAIL: "Could not load the QR generator (awg_qr.js). Use the .conf download instead."
},
ru: {
    LBL_ROLE: "VPN-сервер (входящие подключения)",
    STAT_LOADING_BADGE: "&#9679; Загрузка…",
    STAT_RUNNING: "Работает",
    STAT_STOPPED: "Остановлен",
    STAT_STARTING: "Запуск…",
    STAT_STOPPING: "Остановка…",
    TH_STATUS: "Статус",
    TH_ENDPOINT: "Адрес сервера",
    BTN_START: "Запустить сервер",
    BTN_STOP: "Остановить",
    BTN_RESTART: "Перезапустить",
    BTN_APPLY: "Применить",
    BTN_APPLYING: "Применение…",
    ACK_SAVED: "Сохранено ✓",
    SEC_SETTINGS: "Настройки сервера",
    SEC_OBFS: "Параметры обфускации (общие для всех конфигов пиров)",
    SEC_PEERS: "Пиры (устройства, подключающиеся к роутеру)",
    SEC_LOG: "Журнал",
    LBL_PRIVKEY: "Приватный ключ сервера",
    LBL_PUBKEY: "Публичный ключ сервера",
    BTN_GENKEYS: "Сгенерировать",
    LBL_PORT: "Порт (UDP)",
    LBL_SUBNET: "Подсеть туннеля",
    LBL_MTU: "MTU",
    LBL_ENDPOINT_OVR: "Адрес сервера (переопределение)",
    HINT_ENDPOINT_OVR: "Оставьте пустым — подставится DDNS/WAN-адрес автоматически: <code>{0}</code>",
    LBL_DNS_MODE: "DNS для пиров",
    OPT_DNS_ROUTER: "Роутер (рекомендуется — работают имена LAN и доменный Гео)",
    OPT_DNS_CUSTOM: "Свои серверы",
    LBL_DNS_CUSTOM: "DNS-серверы (через запятую)",
    LBL_NAT_LAN: "NAT в LAN (пиры видны как роутер — лечит молчание Windows-фаервола)",
    LBL_AUTOSTART: "Автозапуск сервера после перезагрузки",
    HINT_SUBNET: "Формат <code>x.y.z.0/24</code>. Роутер получает .1, пиры .2–.254. Не совпадать с подсетью LAN.",
    BTN_GEN_OBFS: "Сгенерировать случайные",
    HINT_OBFS: "Эти значения встраиваются в конфиг каждого пира — клиент должен совпадать с сервером точь-в-точь. Смена параметров отключит пиров, пока они не переимпортируют конфиги.",
    LBL_IPARAMS: "I1–I5 (продвинутое, сигнатурные пакеты AWG 2.x)",
    HINT_IPARAMS: "Необязательно. Junk/сигнатурные пакеты перед handshake — маскируют поток. «Сгенерировать» заполнит I1–I2 уникальной случайной подписью. Теги: <code>&lt;b 0xHEX&gt;</code> фикс. байты, <code>&lt;r N&gt;</code> случайные байты, <code>&lt;rc N&gt;</code> случайные буквы, <code>&lt;rd N&gt;</code> случайные цифры, <code>&lt;t&gt;</code> таймстамп. Нужны клиенты AmneziaWG 2.x (встраиваются в конфиг каждого пира автоматически).",
    BTN_GEN_IPARAMS: "Сгенерировать",
    TH_PEER_NAME: "Имя",
    TH_PEER_IP: "IP",
    TH_PEER_POLICY: "Политика маршрутизации",
    TH_PEER_MODE: "Что в туннель",
    TH_PEER_ON: "Вкл",
    TH_PEER_STATE: "Handshake / трафик",
    TH_PEER_ACT: "Конфиг",
    OPT_MODE_FULL: "Весь трафик",
    OPT_MODE_LAN: "Только домашняя сеть",
    BYPASS_XRAY: "мимо Xray",
    BYPASS_XRAY_TT: "Заворачивать трафик этого пира в клиентский туннель (двойной хоп) даже при работающем Xray — правило ставится перед перехватом Xray, чтобы трафик пира в него не попадал. Нужен поднятый клиентский туннель. На Direct-пиров не влияет.",
    OPT_DIRECT: "Напрямую",
    OPT_VPN_ALL: "VPN: весь трафик",
    OPT_VPN_GEO: "VPN: только Гео",
    OPT_VPN_GEO_PREFIX: "VPN: ",
    BTN_ADD_PEER: "+ Добавить пира",
    BTN_QR: "QR",
    BTN_DL: ".conf",
    BTN_DEL: "✕",
    HS_NEVER: "никогда",
    AGO_SEC: "{0} с назад",
    AGO_MIN: "{0} мин назад",
    AGO_HOUR: "{0} ч назад",
    QR_TITLE: "Конфигурация пира — {0}",
    BTN_COPY: "Копировать",
    BTN_CLOSE: "Закрыть",
    MSG_COPIED: "Скопировано ✓",
    MSG_DEL_PEER: "Удалить пира «{0}»? Его устройство больше не сможет подключиться (после «Применить»).",
    MSG_NEED_SAVE: "Есть несохранённые изменения — сначала нажмите «Применить», чтобы сервер раздал новый список пиров.",
    MSG_KEYS_REQUIRED: "Сначала сгенерируйте или введите приватный ключ сервера.",
    MSG_BAD_SUBNET: "Подсеть туннеля должна быть вида 10.9.0.0/24 (/24, оканчивается на .0).",
    MSG_BAD_PORT: "Порт должен быть 1–65535.",
    MSG_SUBNET_IS_LAN: "Подсеть туннеля должна отличаться от подсети LAN ({0}).",
    MSG_PEERS_FULL: "В подсети не осталось свободных адресов (.2–.254 заняты).",
    MSG_GEN_CONFIRM: "Сгенерировать новые параметры обфускации? Всем существующим пирам придётся переимпортировать конфиги.",
    MSG_REGEN_KEYS: "Сгенерировать НОВУЮ пару ключей сервера? Все существующие конфиги пиров перестанут работать (переимпорт на клиентах).",
    MSG_APPLY_RESTART_HINT: "Настройки применяются на лету, где возможно; смена подсети/ключей перезапускает сервер.",
    BAN_FIRSTRUN: "<b>Сервер ещё не настроен.</b><br>Нажмите «Сгенерировать» для ключей сервера, проверьте порт и подсеть, добавьте пира, затем «Применить» и «Запустить сервер».",
    BAN_WAN_PRIVATE: "<b>WAN-адрес приватный/CGNAT ({0}).</b> Пиры из интернета не достучатся до роутера напрямую — нужен белый IP от провайдера или проброс порта (UDP {1}) на вышестоящем роутере.",
    BAN_PORT_CONFLICT: "<b>Встроенный WireGuard-сервер прошивки использует тот же UDP-порт {0}.</b> Смените порт этого сервера или выключите WG-сервер прошивки (VPN → WireGuard).",
    BAN_CLIENT_DOWN: "<b>Клиентский</b> туннель AmneziaWG не запущен — пиры с политикой «VPN…» сейчас ходят в интернет <b>напрямую</b> через WAN (fail-open). Запустите клиентский туннель на странице AmneziaWG, чтобы политики заработали.",
    BAN_UNSAVED: "Есть несохранённые изменения — нажмите «Применить».",
    BAN_XRAY_POLICY: "⛔ <b>Xray / XRAYUI</b> работает в режиме прозрачного прокси («весь трафик»), и у части пиров стоит политика «VPN…» <b>без галочки «мимо Xray»</b>. Для таких пиров двойной хоп не происходит — Xray перехватывает их трафик в PREROUTING раньше правила маршрутизации AmneziaWG (приоритет ip-rule 19 против 99), поэтому они выходят через Xray, а не через клиентский туннель. Что делать:<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li><b>Нужен двойной хоп</b> — включите у пира галочку <b>«мимо Xray»</b>: правило ставится перед Xray, и этот пир уходит в клиентский туннель (он должен быть поднят). Xray для остального продолжает работать.</li><li><b>Xray устраивает</b> — переведите пира на «Напрямую»: его трафик и так пойдёт через Xray (обход DPI).</li><li>Либо остановите Xray целиком (кнопка ниже).</li></ul>",
    BAN_XRAY_INFO: "<b>Xray / XRAYUI</b> работает в режиме прозрачного прокси («весь трафик») — трафик пиров автоматически идёт <b>через Xray</b> (обход DPI), непроксируемые адреса — напрямую в WAN. Это штатная рабочая схема. Если какому-то пиру нужен именно двойной хоп через клиентский туннель — поставьте ему политику «VPN…» и галочку «мимо Xray».",
    BAN_XRAY_UNCOVERED: "<b>Xray / XRAYUI</b> запущен, но подсети пиров <code>{0}</code> <b>нет в его правилах перехвата</b> — трафик пиров идёт мимо Xray, напрямую в WAN (без обхода DPI). Обычно так бывает, когда XRAYUI стартовал раньше этого сервера. Решение: <b>перезапустите XRAYUI</b> (при старте он подхватывает существующие интерфейсы) или добавьте подсеть в его настройки прозрачного прокси.",
    XRAY_STOP_BTN: "Остановить Xray",
    XRAY_STOPPING: "Останавливаю Xray…",
    XRAY_STOP_CONFIRM: "Остановить Xray / XRAYUI сейчас? Это штатная остановка командой самого XRAYUI — то же, что кнопка «Стоп» на его странице. Из файрвола снимаются только действующие правила TPROXY, чтобы AmneziaWG мог маршрутизировать трафик пиров; сохранённые настройки и правила XRAYUI не затрагиваются. Включите его снова на странице VPN → X-RAY — он поднимется со всеми прежними настройками.",
    DONATE_LABEL: "Поддержать проект",
    DONATE_COPY_TITLE: "Нажмите, чтобы скопировать адрес",
    ADDR_COPIED: "Скопировано ✓",
    LOG_EMPTY: "(пусто)",
    QR_LIB_FAIL: "Не удалось загрузить генератор QR (awg_qr.js). Используйте скачивание .conf."
}
};
function T(key){
    var d = AWG_I18N[AWG_LANG] || AWG_I18N.en;
    var s = (d[key] !== undefined) ? d[key] : (AWG_I18N.en[key] !== undefined ? AWG_I18N.en[key] : key);
    for (var i = 1; i < arguments.length; i++) s = s.split('{' + (i - 1) + '}').join(arguments[i]);
    return s;
}
function applyI18n(){
    var i, els;
    els = document.querySelectorAll('[data-i18n]');
    for (i = 0; i < els.length; i++) els[i].textContent = T(els[i].getAttribute('data-i18n'));
    els = document.querySelectorAll('[data-i18n-html]');
    for (i = 0; i < els.length; i++) els[i].innerHTML = T(els[i].getAttribute('data-i18n-html'));
    els = document.querySelectorAll('[data-i18n-val]');
    for (i = 0; i < els.length; i++) els[i].value = T(els[i].getAttribute('data-i18n-val'));
    els = document.querySelectorAll('[data-i18n-title]');
    for (i = 0; i < els.length; i++) els[i].title = T(els[i].getAttribute('data-i18n-title'));
}

/* ---- settings helpers ---- */
function gs(key){ return (custom_settings[key] !== undefined) ? String(custom_settings[key]) : ''; }
function ss(key, val){
    if (val === '' || val === undefined || val === null) delete custom_settings[key];
    else custom_settings[key] = String(val);
}
// chunk a long value across key, key1, key2… (<=2900 chars each — the firmware caps one
// custom_settings value at ~3000 and silently truncates the rest; same scheme as awg_initdata)
var CHUNK = 2900;
function setChunked(baseKey, val, maxChunks){
    for (var i = 1; i <= maxChunks; i++) delete custom_settings[baseKey + i];
    if (!val) { delete custom_settings[baseKey]; return; }
    if (val.length <= CHUNK) { custom_settings[baseKey] = val; return; }
    custom_settings[baseKey] = val.substr(0, CHUNK);
    for (var j = 1; j * CHUNK < val.length && j <= maxChunks; j++)
        custom_settings[baseKey + j] = val.substr(j * CHUNK, CHUNK);
}
function getChunked(baseKey, maxChunks){
    var v = gs(baseKey);
    for (var i = 1; i <= maxChunks; i++) {
        var c = gs(baseKey + i);
        if (!c) break;
        v += c;
    }
    return v;
}

/* ---- peer store (name|ip|policy|mode|enabled|pubkey|privkey|psk ; entries ';'-joined) ---- */
function sanitizeName(n){
    return String(n || '').replace(/[|;,"\\<>&]/g, '').replace(/^\s+|\s+$/g, '').substr(0, 24);
}
function loadPeers(){
    awgsPeers = [];
    var raw = getChunked('awgs_peers', 10);
    if (!raw) return;
    var entries = raw.split(';');
    for (var i = 0; i < entries.length; i++) {
        var f = entries[i].split('|');
        if (f.length < 8) continue;
        // 9th field (xbypass) is optional — old 8-field records default it to false.
        awgsPeers.push({ name: f[0], ip: f[1], policy: f[2] || 'direct', mode: f[3] || 'full',
                         enabled: f[4] === '1', pub: f[5], priv: f[6], psk: f[7], xbypass: f[8] === '1' });
    }
}
function serializePeers(){
    var parts = [];
    for (var i = 0; i < awgsPeers.length; i++) {
        var p = awgsPeers[i];
        parts.push([sanitizeName(p.name), p.ip, p.policy, p.mode, p.enabled ? '1' : '0',
                    p.pub, p.priv, p.psk, p.xbypass ? '1' : '0'].join('|'));
    }
    return parts.join(';');
}

/* ---- subnet / ip helpers ---- */
function subnetBase(){
    var s = gv('awgs_subnet_f') || '10.9.0.0/24';
    var m = s.match(/^(\d+\.\d+\.\d+)\.0\/24$/);
    return m ? m[1] : null;
}
function routerTunnelIp(){ var b = subnetBase(); return b ? b + '.1' : '10.9.0.1'; }
function nextFreeIp(){
    var b = subnetBase();
    if (!b) return null;
    for (var host = 2; host <= 254; host++) {
        var ip = b + '.' + host, used = false;
        for (var i = 0; i < awgsPeers.length; i++) if (awgsPeers[i].ip === ip) { used = true; break; }
        if (!used) return ip;
    }
    return null;
}
function lanCidr(){
    try {
        var nv = httpApi.nvramGet(["lan_ipaddr", "lan_netmask"]);
        var ip = nv.lan_ipaddr, mask = nv.lan_netmask;
        if (!ip || !mask) return '192.168.1.0/24';
        var mp = mask.split('.'), bits = 0, net = [];
        var ipp = ip.split('.');
        for (var i = 0; i < 4; i++) {
            var m = parseInt(mp[i], 10) || 0;
            net.push((parseInt(ipp[i], 10) || 0) & m);
            while (m & 128) { bits++; m = (m << 1) & 255; }
        }
        return net.join('.') + '/' + bits;
    } catch(e){ return '192.168.1.0/24'; }
}

/* ---- form value helpers ---- */
function gv(id){ var e = document.getElementById(id); return e ? e.value.replace(/^\s+|\s+$/g, '') : ''; }
function sv(id, v){ var e = document.getElementById(id); if (e) e.value = (v === undefined || v === null) ? '' : v; }
function gchk(id){ var e = document.getElementById(id); return e ? e.checked : false; }
function schk(id, on){ var e = document.getElementById(id); if (e) e.checked = !!on; }
function markDirty(){ awgsDirty = true; var b = document.getElementById('awgs_unsaved'); if (b) b.style.display = ''; }

/* ---- load settings into the form ---- */
function loadSettings(){
    sv('awgs_priv_f', gs('awgs_privkey'));
    sv('awgs_pub_f', gs('awgs_pubkey'));
    sv('awgs_port_f', gs('awgs_port') || '51821');
    sv('awgs_subnet_f', gs('awgs_subnet') || '10.9.0.0/24');
    sv('awgs_mtu_f', gs('awgs_mtu') || '1420');
    sv('awgs_endpoint_f', gs('awgs_endpoint'));
    var dnsMode = gs('awgs_dns_mode') || 'router';
    document.getElementById('awgs_dnsmode_f').value = dnsMode;
    sv('awgs_dnscustom_f', gs('awgs_dns_custom'));
    toggleDnsCustom();
    schk('awgs_natlan_f', gs('awgs_nat_lan') !== '0');
    schk('awgs_autostart_f', gs('awgs_autostart') === '1');
    // obfuscation
    sv('awgs_jc_f', gs('awgs_jc')); sv('awgs_jmin_f', gs('awgs_jmin')); sv('awgs_jmax_f', gs('awgs_jmax'));
    sv('awgs_s1_f', gs('awgs_s1')); sv('awgs_s2_f', gs('awgs_s2'));
    sv('awgs_h1_f', gs('awgs_h1')); sv('awgs_h2_f', gs('awgs_h2'));
    sv('awgs_h3_f', gs('awgs_h3')); sv('awgs_h4_f', gs('awgs_h4'));
    // I1-I5 from chunked base64 (lines "In = value")
    var b64 = getChunked('awgs_initdata', 30);
    if (b64) {
        try {
            var txt = atob(b64.replace(/[^A-Za-z0-9+/=]/g, ''));
            var lines = txt.split('\n');
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/^I([1-5])\s*=\s*(.*)$/);
                if (m) sv('awgs_i' + m[1] + '_f', m[2]);
            }
        } catch(e){}
    }
    loadPeers();
    renderPeers();
    var firstrun = document.getElementById('awgs_firstrun');
    if (firstrun) firstrun.style.display = gs('awgs_privkey') ? 'none' : '';
}

function toggleDnsCustom(){
    var mode = document.getElementById('awgs_dnsmode_f').value;
    document.getElementById('awgs_dnscustom_row').style.display = (mode === 'custom') ? '' : 'none';
}

/* ---- key generation (in-browser Curve25519, see awg_qr.js) ---- */
function loadQrLib(cb){
    if (awgsQrLibLoaded && window.AWGQR && window.AWGKeys) { cb(true); return; }
    var s = document.createElement('script');
    s.src = '/user/awg_qr.js?v=' + ((awgsStatus && awgsStatus.version) || '0');
    s.onload = function(){ awgsQrLibLoaded = true; cb(!!(window.AWGQR && window.AWGKeys)); };
    s.onerror = function(){ cb(false); };
    document.head.appendChild(s);
}
function genServerKeys(){
    if (gv('awgs_priv_f') && !confirm(T('MSG_REGEN_KEYS'))) return;
    loadQrLib(function(ok){
        if (!ok) { alert(T('QR_LIB_FAIL')); return; }
        var priv = AWGKeys.genPrivkey();
        sv('awgs_priv_f', priv);
        sv('awgs_pub_f', AWGKeys.pubFromPriv(priv));
        document.getElementById('awgs_firstrun').style.display = 'none';
        markDirty();
    });
}
function privKeyEdited(){
    loadQrLib(function(ok){
        if (!ok) return;
        var priv = gv('awgs_priv_f');
        sv('awgs_pub_f', AWGKeys.isValidKey(priv) ? AWGKeys.pubFromPriv(priv) : '');
        markDirty();
    });
}
function genObfs(){
    if (!confirm(T('MSG_GEN_CONFIRM'))) return;
    function ri(min, max){ return Math.floor(Math.random() * (max - min + 1)) + min; }
    sv('awgs_jc_f', ri(3, 10));
    var jmin = ri(10, 60); sv('awgs_jmin_f', jmin); sv('awgs_jmax_f', jmin + ri(20, 60));
    sv('awgs_s1_f', ri(15, 120)); sv('awgs_s2_f', ri(15, 120));
    // H1-H4: AWG 2.0 magic-header RANGES (start-end). The daemon rolls a random header value
    // inside each range for every packet and the receiver validates it falls in-range — a
    // moving header instead of one fixed number, harder for DPI to fingerprint. The 4 ranges
    // MUST be disjoint (they distinguish the 4 WG message types) and > 4 (1-4 are reserved):
    // split the 32-bit space into 4 bands and take a random sub-range within each, so they can
    // never overlap. Both peers get identical H1-H4 (embedded into every peer config).
    var HMAX = 4294967295, band = Math.floor((HMAX - 16) / 4);
    for (var k = 0; k < 4; k++) {
        var lo = 16 + k * band, hi = 16 + (k + 1) * band - 1;
        var width = ri(100000, 5000000);
        var start = ri(lo, hi - width);
        sv('awgs_h' + (k + 1) + '_f', start + '-' + (start + width));
    }
    markDirty();
}

// Generate AWG 2.0 signature packets for I1-I5. Grammar (verified against the daemon's
// newObfChain, our router-build v0.2.19): a chain of <tag val> tokens — <b 0xHEX> fixed
// bytes, <r N> N random bytes, <rc N> random letters, <rd N> random digits, <t> timestamp.
// The I-packets are standalone junk datagrams sent BEFORE the handshake init (src is nil),
// so <d>/<ds>/<dz> data-wrapping tags don't apply here, and the receiver just drops them
// (they carry no H1 magic) — pure sender-side DPI camouflage. We emit two packets: a fixed
// random byte signature (unique per server, defeats signature-DB matching of the default AWG
// fingerprint) + a random tail for entropy. Both peers get identical params — the server
// embeds these into every peer's .conf — so nothing to sync manually.
function awgsRandHex(nBytes){
    var b = new Uint8Array(nBytes), i, s = '';
    if (window.crypto && window.crypto.getRandomValues) window.crypto.getRandomValues(b);
    else for (i = 0; i < nBytes; i++) b[i] = Math.floor(Math.random() * 256);
    for (i = 0; i < b.length; i++) s += ('0' + b[i].toString(16)).slice(-2);
    return s;
}
function genIparams(){
    if (!confirm(T('MSG_GEN_CONFIRM'))) return;
    function ri(min, max){ return Math.floor(Math.random() * (max - min + 1)) + min; }
    // I1: fixed byte signature + random byte padding. I2: another signature + random letters.
    sv('awgs_i1_f', '<b 0x' + awgsRandHex(ri(8, 16)) + '><r ' + ri(4, 16) + '>');
    sv('awgs_i2_f', '<b 0x' + awgsRandHex(ri(8, 16)) + '><rc ' + ri(4, 12) + '>');
    sv('awgs_i3_f', ''); sv('awgs_i4_f', ''); sv('awgs_i5_f', '');
    markDirty();
}

/* ---- peers UI ---- */
function policyOptions(sel){
    var opts = [
        { v: 'direct',  t: T('OPT_DIRECT') },
        { v: 'vpn_all', t: T('OPT_VPN_ALL') },
        { v: 'vpn_geo', t: T('OPT_VPN_GEO') }
    ];
    // named extra geo policies from the client page's registry: "id:uriName;…"
    var reg = gs('awg_geo_policies');
    if (reg) {
        var parts = reg.split(';');
        for (var i = 0; i < parts.length; i++) {
            var kv = parts[i].split(':');
            var id = (kv[0] || '').replace(/[^0-9]/g, '');
            if (!id || id === '1') continue;
            var nm = kv[1] ? decodeURIComponent(kv[1]) : ('Geo ' + id);
            opts.push({ v: 'vpn_geo_' + id, t: T('OPT_VPN_GEO_PREFIX') + nm });
        }
    }
    var html = '';
    for (var j = 0; j < opts.length; j++)
        html += '<option value="' + opts[j].v + '"' + (opts[j].v === sel ? ' selected' : '') + '>' + escHtml(opts[j].t) + '</option>';
    return html;
}
function renderPeers(){
    var tb = document.getElementById('awgs_peer_rows');
    if (!tb) return;
    var html = '';
    for (var i = 0; i < awgsPeers.length; i++) {
        var p = awgsPeers[i];
        html += '<tr>' +
          '<td width="16%"><input type="text" maxlength="24" value="' + escHtml(p.name) + '" onchange="peerEdit(' + i + ',\'name\',this.value)"></td>' +
          '<td width="12%" style="font-family:monospace; font-size:12px;">' + escHtml(p.ip) + '</td>' +
          '<td width="20%"><select onchange="peerEdit(' + i + ',\'policy\',this.value)">' + policyOptions(p.policy) + '</select>' +
              (p.policy !== 'direct' ? '<label style="display:block; font-size:10px; color:#b6bdc7; margin-top:3px; cursor:pointer;" title="' + escHtml(T('BYPASS_XRAY_TT')) + '"><input type="checkbox"' + (p.xbypass ? ' checked' : '') + ' onchange="peerEdit(' + i + ',\'xbypass\',this.checked)" style="vertical-align:middle;"> ' + escHtml(T('BYPASS_XRAY')) + '</label>' : '') +
          '</td>' +
          '<td width="16%"><select onchange="peerEdit(' + i + ',\'mode\',this.value)">' +
              '<option value="full"' + (p.mode !== 'lan' ? ' selected' : '') + '>' + escHtml(T('OPT_MODE_FULL')) + '</option>' +
              '<option value="lan"' + (p.mode === 'lan' ? ' selected' : '') + '>' + escHtml(T('OPT_MODE_LAN')) + '</option>' +
          '</select></td>' +
          '<td width="5%" align="center"><input type="checkbox"' + (p.enabled ? ' checked' : '') + ' onchange="peerEdit(' + i + ',\'enabled\',this.checked)"></td>' +
          '<td width="17%" id="awgs_pstate_' + i + '" style="font-size:11px; color:#b6bdc7;">—</td>' +
          '<td width="14%">' +
              '<input type="button" class="awg-mini accent" value="' + escHtml(T('BTN_QR')) + '" onclick="showQr(' + i + ')">' +
              '<input type="button" class="awg-mini" value="' + escHtml(T('BTN_DL')) + '" onclick="dlConf(' + i + ')">' +
              '<input type="button" class="awg-mini danger" value="' + escHtml(T('BTN_DEL')) + '" onclick="delPeer(' + i + ')">' +
          '</td></tr>';
    }
    tb.innerHTML = html;
    paintPeerStates();
}
function peerEdit(i, field, val){
    if (!awgsPeers[i]) return;
    if (field === 'name') val = sanitizeName(val);
    awgsPeers[i][field] = val;
    markDirty();
    // The «Bypass Xray» checkbox only shows for a VPN policy — re-render on a policy change
    // so it appears/disappears; a peer switched to Direct drops the (now meaningless) flag.
    if (field === 'policy') { if (val === 'direct') awgsPeers[i].xbypass = false; renderPeers(); }
}
function addPeer(){
    loadQrLib(function(ok){
        if (!ok) { alert(T('QR_LIB_FAIL')); return; }
        var ip = nextFreeIp();
        if (!ip) { alert(T('MSG_PEERS_FULL')); return; }
        var priv = AWGKeys.genPrivkey();
        awgsPeers.push({ name: 'peer-' + ip.split('.')[3], ip: ip, policy: 'direct', mode: 'full',
                         enabled: true, pub: AWGKeys.pubFromPriv(priv), priv: priv, psk: AWGKeys.genPsk(), xbypass: false });
        renderPeers();
        markDirty();
    });
}
function delPeer(i){
    var p = awgsPeers[i];
    if (!p) return;
    if (!confirm(T('MSG_DEL_PEER', p.name))) return;
    awgsPeers.splice(i, 1);
    renderPeers();
    markDirty();
}
function awgAgo(epoch){
    if (!epoch) return T('HS_NEVER');
    var ago = Math.max(0, Math.floor(Date.now() / 1000) - epoch);
    if (ago < 60) return T('AGO_SEC', ago);
    if (ago < 3600) return T('AGO_MIN', Math.floor(ago / 60));
    return T('AGO_HOUR', Math.floor(ago / 3600));
}
function humanBytes(n){
    n = n || 0;
    if (n >= 1073741824) return (n / 1073741824).toFixed(1) + ' GiB';
    if (n >= 1048576) return (n / 1048576).toFixed(1) + ' MiB';
    if (n >= 1024) return (n / 1024).toFixed(1) + ' KiB';
    return n + ' B';
}
function paintPeerStates(){
    if (!awgsStatus || !awgsStatus.peers) return;
    var byPub = {};
    for (var j = 0; j < awgsStatus.peers.length; j++) byPub[awgsStatus.peers[j].pub] = awgsStatus.peers[j];
    for (var i = 0; i < awgsPeers.length; i++) {
        var el = document.getElementById('awgs_pstate_' + i);
        if (!el) continue;
        var live = byPub[awgsPeers[i].pub];
        if (!awgsStatus.running || !live) { el.textContent = '—'; continue; }
        var txt = awgAgo(live.hs_epoch);
        if (live.rx_bytes || live.tx_bytes) txt += ' · ↓' + humanBytes(live.rx_bytes) + ' ↑' + humanBytes(live.tx_bytes);
        el.textContent = txt;
        el.style.color = (live.hs_epoch && (Date.now() / 1000 - live.hs_epoch) < 180) ? '#7fd48a' : '#b6bdc7';
    }
}

/* ---- peer config text / QR / download ---- */
function buildPeerConf(p){
    var lines = ['[Interface]', 'PrivateKey = ' + p.priv, 'Address = ' + p.ip + '/32'];
    var dnsMode = document.getElementById('awgs_dnsmode_f').value;
    if (dnsMode === 'custom') {
        var d = gv('awgs_dnscustom_f');
        if (d) lines.push('DNS = ' + d);
    } else {
        lines.push('DNS = ' + routerTunnelIp());
    }
    var mtu = gv('awgs_mtu_f');
    if (mtu && mtu !== '1420') lines.push('MTU = ' + mtu);
    var fields = [['Jc', 'awgs_jc_f'], ['Jmin', 'awgs_jmin_f'], ['Jmax', 'awgs_jmax_f'],
                  ['S1', 'awgs_s1_f'], ['S2', 'awgs_s2_f'],
                  ['H1', 'awgs_h1_f'], ['H2', 'awgs_h2_f'], ['H3', 'awgs_h3_f'], ['H4', 'awgs_h4_f']];
    for (var i = 0; i < fields.length; i++) {
        var v = gv(fields[i][1]);
        if (v) lines.push(fields[i][0] + ' = ' + v);
    }
    for (var n = 1; n <= 5; n++) {
        var iv = gv('awgs_i' + n + '_f');
        if (iv) lines.push('I' + n + ' = ' + iv);
    }
    lines.push('');
    lines.push('[Peer]');
    lines.push('PublicKey = ' + gv('awgs_pub_f'));
    if (p.psk) lines.push('PresharedKey = ' + p.psk);
    if (p.mode === 'lan') {
        lines.push('AllowedIPs = ' + lanCidr() + ', ' + (subnetBase() || '10.9.0') + '.0/24');
    } else {
        lines.push('AllowedIPs = 0.0.0.0/0');
    }
    var host = gv('awgs_endpoint_f') || (awgsStatus && awgsStatus.endpoint_hint) || '';
    lines.push('Endpoint = ' + host + ':' + (gv('awgs_port_f') || '51821'));
    lines.push('PersistentKeepalive = 25');
    return lines.join('\n');
}
function showQr(i){
    var p = awgsPeers[i];
    if (!p) return;
    if (awgsDirty) { /* still allow — QR is built from the CURRENT form values */ }
    loadQrLib(function(ok){
        var conf = buildPeerConf(p);
        document.getElementById('awgs_qr_title').textContent = T('QR_TITLE', p.name);
        document.getElementById('awgs_qr_conf').value = conf;
        var box = document.getElementById('awgs_qr_svg');
        if (ok) {
            try {
                var qr = AWGQR.encodeText(conf, AWGQR.Ecc.M);
                box.innerHTML = AWGQR.toSvgString(qr, 3);
                box.style.display = '';
            } catch(e){ box.style.display = 'none'; }
        } else {
            box.style.display = 'none';
        }
        // Must be an explicit value: '' would revert to the stylesheet's `display:none`
        // default for #awgs_qr_modal and the modal would never appear (field-found).
        document.getElementById('awgs_qr_modal').style.display = 'block';
    });
}
function closeQr(){ document.getElementById('awgs_qr_modal').style.display = 'none'; }
function copyConf(){
    var ta = document.getElementById('awgs_qr_conf');
    ta.select();
    try { document.execCommand('copy'); } catch(e){}
    var b = document.getElementById('awgs_qr_copy');
    var old = b.value; b.value = T('MSG_COPIED');
    setTimeout(function(){ b.value = old; }, 1500);
}
function dlConf(i){
    var p = awgsPeers[i];
    if (!p) return;
    var conf = buildPeerConf(p);
    var name = (sanitizeName(p.name) || 'peer').replace(/\s+/g, '_') + '.conf';
    var a = document.createElement('a');
    a.href = 'data:application/octet-stream;charset=utf-8,' + encodeURIComponent(conf);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}

/* ---- save / apply ---- */
function validateForm(){
    if (!gv('awgs_priv_f')) { alert(T('MSG_KEYS_REQUIRED')); return false; }
    var port = gv('awgs_port_f');
    if (!/^\d+$/.test(port) || +port < 1 || +port > 65535) { alert(T('MSG_BAD_PORT')); return false; }
    if (!subnetBase()) { alert(T('MSG_BAD_SUBNET')); return false; }
    var lan = lanCidr();
    if ((subnetBase() + '.0/24') === lan) { alert(T('MSG_SUBNET_IS_LAN', lan)); return false; }
    return true;
}
function saveSettings(){
    if (!validateForm()) return;
    ss('awgs_privkey', gv('awgs_priv_f'));
    ss('awgs_pubkey', gv('awgs_pub_f'));
    ss('awgs_port', gv('awgs_port_f'));
    ss('awgs_subnet', gv('awgs_subnet_f'));
    ss('awgs_mtu', gv('awgs_mtu_f'));
    ss('awgs_endpoint', gv('awgs_endpoint_f'));
    ss('awgs_dns_mode', document.getElementById('awgs_dnsmode_f').value);
    ss('awgs_dns_custom', gv('awgs_dnscustom_f'));
    ss('awgs_nat_lan', gchk('awgs_natlan_f') ? '1' : '0');
    ss('awgs_autostart', gchk('awgs_autostart_f') ? '1' : '0');
    ss('awgs_jc', gv('awgs_jc_f')); ss('awgs_jmin', gv('awgs_jmin_f')); ss('awgs_jmax', gv('awgs_jmax_f'));
    ss('awgs_s1', gv('awgs_s1_f')); ss('awgs_s2', gv('awgs_s2_f'));
    ss('awgs_h1', gv('awgs_h1_f')); ss('awgs_h2', gv('awgs_h2_f'));
    ss('awgs_h3', gv('awgs_h3_f')); ss('awgs_h4', gv('awgs_h4_f'));
    // I1-I5 -> chunked base64 text (ASCII-only, same as the client page)
    var itxt = '';
    for (var n = 1; n <= 5; n++) {
        var iv = gv('awgs_i' + n + '_f');
        if (iv) itxt += 'I' + n + ' = ' + iv + '\n';
    }
    if (itxt && /[^\x00-\x7F]/.test(itxt)) { alert('I1-I5: ASCII only'); return; }
    setChunked('awgs_initdata', itxt ? btoa(itxt) : '', 30);
    setChunked('awgs_peers', serializePeers(), 10);

    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = 'start_awgsrvsave';
    var btn = document.getElementById('btn_apply');
    btn.value = T('BTN_APPLYING'); btn.disabled = true;
    document.form.submit();
    awgsDirty = false;
    document.getElementById('awgs_unsaved').style.display = 'none';
    setTimeout(function(){
        btn.value = T('ACK_SAVED');
        setTimeout(function(){ btn.value = T('BTN_APPLY'); btn.disabled = false; refreshStatus(); }, 1600);
    }, 2500);
}

/* ---- start/stop/restart with transitional UI (no buttons during transitions) ---- */
function srvAction(action){
    if (awgsDirty && action === 'start_awgsrvstart') { alert(T('MSG_NEED_SAVE')); return; }
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = action;
    document.form.submit();
    var kind = action.indexOf('stop') !== -1 ? 'stop' : (action.indexOf('restart') !== -1 ? 'restart' : 'start');
    enterTransition(kind);
}
function enterTransition(kind){
    awgsActionGen++;
    var myGen = awgsActionGen;
    var expect = (kind !== 'stop');
    var badge = document.getElementById('awgs_badge');
    setButtons('none', 'none', 'none');   // transitions show ONLY the badge — no buttons, no cancel
    badge.className = 'awg-status connecting';
    badge.innerHTML = '&#9679; ' + escHtml(kind === 'stop' ? T('STAT_STOPPING') : T('STAT_STARTING'));
    var attempts = 0;
    var poll = setInterval(function(){
        if (myGen !== awgsActionGen) { clearInterval(poll); return; }
        attempts++;
        fetchStatus(function(st){
            if (myGen !== awgsActionGen) { clearInterval(poll); return; }
            if (st && st.running === expect && !st.starting && !st.stopping) {
                clearInterval(poll);
                renderStatus(st);
            } else if (attempts > 40) {
                clearInterval(poll);
                if (st) renderStatus(st);
            }
        });
    }, 1500);
}
function setButtons(start, stop, restart){
    document.getElementById('btn_srv_start').style.display = start;
    document.getElementById('btn_srv_stop').style.display = stop;
    document.getElementById('btn_srv_restart').style.display = restart;
}

/* ---- status polling ---- */
function fetchStatus(cb){
    var x = new XMLHttpRequest();
    x.open('GET', '/user/awgs_status.htm?_=' + Date.now(), true);
    x.timeout = 4000;
    x.onload = function(){
        var j = null;
        try { j = JSON.parse(x.responseText); } catch(e){}
        cb(j);
    };
    x.onerror = x.ontimeout = function(){ cb(null); };
    x.send();
}
function refreshStatus(){
    var myGen = awgsActionGen;
    fetchStatus(function(st){
        if (myGen !== awgsActionGen) return;   // an action started while this read was in flight
        if (st) renderStatus(st);
    });
}
function renderStatus(st){
    awgsStatus = st;
    var badge = document.getElementById('awgs_badge');
    if (st.starting) {
        badge.className = 'awg-status connecting';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STARTING'));
        setButtons('none', 'none', 'none');
    } else if (st.stopping) {
        badge.className = 'awg-status connecting';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPING'));
        setButtons('none', 'none', 'none');
    } else if (st.running) {
        badge.className = 'awg-status running';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_RUNNING'));
        setButtons('none', '', '');
    } else {
        badge.className = 'awg-status stopped';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPED'));
        setButtons('', 'none', 'none');
    }
    // endpoint / port summary
    var host = gs('awgs_endpoint') || st.endpoint_hint || '—';
    document.getElementById('awgs_endpoint_show').textContent = host + ':' + (st.port || '');
    var hint = document.getElementById('awgs_ephint');
    if (hint) hint.innerHTML = T('HINT_ENDPOINT_OVR', escHtml(st.endpoint_hint || '—'));
    // banners
    showBanner('awgs_ban_wan', !!st.wan_private, st.wan_private ? T('BAN_WAN_PRIVATE', escHtml(st.endpoint_hint || ''), escHtml(st.port || '')) : '');
    showBanner('awgs_ban_port', !!st.port_conflict, st.port_conflict ? T('BAN_PORT_CONFLICT', escHtml(st.port || '')) : '');
    // Classify peers by what they expect: a VPN policy WITH «bypass Xray» goes into the client
    // tunnel past Xray (1.3.10); WITHOUT it, Xray grabs it first; Direct goes through Xray.
    var vpnNoBypass = false, vpnBypass = false, anyDirect = false;
    for (var i = 0; i < awgsPeers.length; i++) {
        var pp = awgsPeers[i];
        if (!pp.enabled) continue;
        if (pp.policy && pp.policy !== 'direct') { if (pp.xbypass) vpnBypass = true; else vpnNoBypass = true; }
        else anyDirect = true;
    }
    // Coverage guard (backend srv_xray_covers_peers): xray is capturing, but its TPROXY
    // rules miss the peer subnet (typical when XRAYUI started before awgs0 existed) —
    // peers then bypass xray straight to WAN, so the INFO banner's "peers flow through
    // Xray" claim would be false. Separate yellow banner names the fix (restart XRAYUI).
    var uncov = !!(st.xray_capture && st.xray_peers_uncovered);
    showBanner('awgs_ban_xraycov', uncov, T('BAN_XRAY_UNCOVERED', escHtml(st.subnet || '')));
    // Fail-open: a peer that WANTS the client tunnel (a «bypass Xray» peer, or a vpn peer while
    // Xray isn't grabbing it) but the tunnel is down → its traffic falls open to WAN.
    var wantsTunnel = vpnBypass || (vpnNoBypass && (!st.xray_capture || uncov));
    showBanner('awgs_ban_client', st.running && wantsTunnel && !st.client_running, T('BAN_CLIENT_DOWN'));
    // Xray coexistence banner (verified live on a box running XRAYUI):
    //  - RED: some vpn peer has NO «bypass Xray» while Xray captures → its double hop doesn't
    //    happen (Xray grabs it first). Banner offers the fix (tick bypass / Direct / stop Xray).
    //  - YELLOW info: Xray captures and there are Direct peers (they flow through Xray) with no
    //    red case. Both suppressed while uncovered — the coverage banner is the story then. A
    //    box with only «bypass Xray» peers gets no banner (they're all in the client tunnel).
    var redPolicy = st.xray_capture && !uncov && vpnNoBypass;
    var xb = document.getElementById('awgs_ban_xray');
    if (xb) xb.className = 'awg-banner ' + (redPolicy ? 'red' : 'yellow');
    var xrayHtml = T(redPolicy ? 'BAN_XRAY_POLICY' : 'BAN_XRAY_INFO');
    if (st.xray_capture && st.xray_ctl)
        xrayHtml += '<div style="margin-top:7px;"><input type="button" class="awg-mini danger" value="' +
                    escHtml(awgsXrayStopping ? T('XRAY_STOPPING') : T('XRAY_STOP_BTN')) + '"' +
                    (awgsXrayStopping ? ' disabled' : '') + ' onclick="stopXray(this);"></div>';
    showBanner('awgs_ban_xray', st.xray_capture && !uncov && (redPolicy || anyDirect), xrayHtml);
    // log
    var logEl = document.getElementById('awgs_log');
    if (logEl && typeof st.log === 'string') {
        var txt = st.log.replace(/\\n/g, '\n');
        if (logEl.textContent !== txt) {
            logEl.textContent = txt || T('LOG_EMPTY');
            logEl.scrollTop = logEl.scrollHeight;
        }
    }
    paintPeerStates();
}
function showBanner(id, on, html){
    var el = document.getElementById(id);
    if (!el) return;
    el.style.display = on ? '' : 'none';
    if (on && html) el.innerHTML = html;
}

// "Stop Xray": routed to the client script's do_xray_stop (start_awgxraystop service event),
// which calls XRAYUI's own cleanup so the TPROXY/fwmark rules are removed, not just the process.
var awgsXrayStopping = false;
function stopXray(btn){
    if (!confirm(T('XRAY_STOP_CONFIRM'))) return;
    awgsXrayStopping = true;
    if (btn) { btn.disabled = true; btn.value = T('XRAY_STOPPING'); }
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = 'start_awgxraystop';
    document.form.submit();
    setTimeout(function(){ awgsXrayStopping = false; refreshStatus(); }, 6000);
}

// Copy a text (USDT donate address) to the clipboard with brief inline feedback.
function awgCopyAddr(addr, el){
    var done = function(){ var o = el.textContent; el.textContent = T('ADDR_COPIED'); setTimeout(function(){ el.textContent = o; }, 1200); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(addr).then(done, done);
    else { try { var ta = document.createElement('textarea'); ta.value = addr; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); document.body.removeChild(ta); } catch(e){} done(); }
}

function initial(){
    applyI18n();
    show_menu();
    loadSettings();
    refreshStatus();
    statusTimer = setInterval(refreshStatus, 4000);
    if (!awgsTick) awgsTick = setInterval(paintPeerStates, 1000);
}
</script>
</head>
<body onload="initial();" onunload="if(statusTimer)clearInterval(statusTimer);">
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

            <table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
            <tr><td bgcolor="#4D595D" valign="top">
                <div>&nbsp;</div>
                <div class="formfonttitle" style="display:flex; flex-wrap:wrap; align-items:center; gap:10px;">
                    <span style="font-size:20px; font-weight:bold; letter-spacing:1px;">AmneziaWG Server</span>
                    <span style="font-size:13px; font-weight:normal;" data-i18n="LBL_ROLE">VPN server (inbound connections)</span>
                </div>
                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                <!-- Status & actions -->
                <table width="100%" border="0" cellpadding="4" cellspacing="0">
                <tr>
                    <th width="20%" data-i18n="TH_STATUS">Status</th>
                    <td>
                        <span id="awgs_badge" class="awg-status connecting" data-i18n-html="STAT_LOADING_BADGE">&#9679; Loading…</span>
                        <input type="button" id="btn_srv_start" class="button_gen awg-btn" value="Start server" data-i18n-val="BTN_START" style="display:none;" onclick="srvAction('start_awgsrvstart');">
                        <input type="button" id="btn_srv_stop" class="button_gen awg-btn" value="Stop" data-i18n-val="BTN_STOP" style="display:none;" onclick="srvAction('start_awgsrvstop');">
                        <input type="button" id="btn_srv_restart" class="button_gen awg-btn" value="Restart" data-i18n-val="BTN_RESTART" style="display:none;" onclick="srvAction('start_awgsrvrestart');">
                    </td>
                </tr>
                <tr>
                    <th width="20%" data-i18n="TH_ENDPOINT">Server address</th>
                    <td><span id="awgs_endpoint_show" style="font-family:monospace;">—</span></td>
                </tr>
                </table>

                <div id="awgs_firstrun" class="awg-banner blue" style="display:none;">
                    <span data-i18n-html="BAN_FIRSTRUN"></span>
                </div>
                <div id="awgs_ban_wan" class="awg-banner red" style="display:none;"></div>
                <div id="awgs_ban_port" class="awg-banner red" style="display:none;"></div>
                <div id="awgs_ban_client" class="awg-banner yellow" style="display:none;"></div>
                <div id="awgs_ban_xray" class="awg-banner red" style="display:none;"></div>
                <div id="awgs_ban_xraycov" class="awg-banner yellow" style="display:none;"></div>
                <div id="awgs_unsaved" class="awg-banner yellow" style="display:none;" data-i18n="BAN_UNSAVED"></div>

                <!-- Server settings -->
                <div class="awg-section" data-i18n="SEC_SETTINGS">Server settings</div>
                <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
                <tr>
                    <th width="30%" data-i18n="LBL_PRIVKEY">Server private key</th>
                    <td>
                        <input type="text" id="awgs_priv_f" class="input_32_table awg-dotted" style="width:340px;" maxlength="44" autocomplete="off" autocapitalize="off" spellcheck="false" onchange="privKeyEdited();">
                        <input type="button" class="button_gen awg-mini" value="Generate" data-i18n-val="BTN_GENKEYS" onclick="genServerKeys();">
                    </td>
                </tr>
                <tr>
                    <th data-i18n="LBL_PUBKEY">Server public key</th>
                    <td><input type="text" id="awgs_pub_f" class="input_32_table" style="width:340px; font-family:monospace;" readonly></td>
                </tr>
                <tr>
                    <th data-i18n="LBL_PORT">Listen port (UDP)</th>
                    <td><input type="text" id="awgs_port_f" class="input_6_table" maxlength="5" onchange="markDirty();"></td>
                </tr>
                <tr>
                    <th data-i18n="LBL_SUBNET">Tunnel subnet</th>
                    <td>
                        <input type="text" id="awgs_subnet_f" class="input_20_table" maxlength="18" onchange="markDirty(); renderPeers();">
                        <div class="awg-hint" data-i18n-html="HINT_SUBNET"></div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="LBL_MTU">MTU</th>
                    <td><input type="text" id="awgs_mtu_f" class="input_6_table" maxlength="4" onchange="markDirty();"></td>
                </tr>
                <tr>
                    <th data-i18n="LBL_ENDPOINT_OVR">Endpoint host override</th>
                    <td>
                        <input type="text" id="awgs_endpoint_f" class="input_32_table" style="width:280px;" maxlength="64" onchange="markDirty();">
                        <div class="awg-hint" id="awgs_ephint"></div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="LBL_DNS_MODE">DNS for peers</th>
                    <td>
                        <select id="awgs_dnsmode_f" class="input_option" onchange="toggleDnsCustom(); markDirty();">
                            <option value="router" data-i18n="OPT_DNS_ROUTER">Router (recommended)</option>
                            <option value="custom" data-i18n="OPT_DNS_CUSTOM">Custom servers</option>
                        </select>
                    </td>
                </tr>
                <tr id="awgs_dnscustom_row" style="display:none;">
                    <th data-i18n="LBL_DNS_CUSTOM">DNS servers</th>
                    <td><input type="text" id="awgs_dnscustom_f" class="input_20_table" maxlength="48" placeholder="1.1.1.1, 8.8.8.8" onchange="markDirty();"></td>
                </tr>
                <tr>
                    <th><label for="awgs_natlan_f" data-i18n="LBL_NAT_LAN">NAT to LAN</label></th>
                    <td><input type="checkbox" id="awgs_natlan_f" onchange="markDirty();"></td>
                </tr>
                <tr>
                    <th><label for="awgs_autostart_f" data-i18n="LBL_AUTOSTART">Autostart</label></th>
                    <td><input type="checkbox" id="awgs_autostart_f" onchange="markDirty();"></td>
                </tr>
                </table>

                <!-- Obfuscation -->
                <div class="awg-section" data-i18n="SEC_OBFS">Obfuscation parameters</div>
                <div class="awg-hint" style="margin:0 0 6px 5px;" data-i18n-html="HINT_OBFS"></div>
                <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
                <tr>
                    <th width="30%">Jc / Jmin / Jmax</th>
                    <td>
                        <input type="text" id="awgs_jc_f" class="input_6_table" maxlength="4" onchange="markDirty();">
                        <input type="text" id="awgs_jmin_f" class="input_6_table" maxlength="5" onchange="markDirty();">
                        <input type="text" id="awgs_jmax_f" class="input_6_table" maxlength="5" onchange="markDirty();">
                        <input type="button" class="button_gen awg-mini" value="Generate random" data-i18n-val="BTN_GEN_OBFS" onclick="genObfs();">
                    </td>
                </tr>
                <tr>
                    <th>S1 / S2</th>
                    <td>
                        <input type="text" id="awgs_s1_f" class="input_6_table" maxlength="4" onchange="markDirty();">
                        <input type="text" id="awgs_s2_f" class="input_6_table" maxlength="4" onchange="markDirty();">
                    </td>
                </tr>
                <tr>
                    <th>H1–H4</th>
                    <td>
                        <input type="text" id="awgs_h1_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H1" onchange="markDirty();">
                        <input type="text" id="awgs_h2_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H2" onchange="markDirty();">
                        <input type="text" id="awgs_h3_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H3" onchange="markDirty();">
                        <input type="text" id="awgs_h4_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H4" onchange="markDirty();">
                    </td>
                </tr>
                <tr>
                    <th data-i18n="LBL_IPARAMS">I1–I5 (advanced)</th>
                    <td>
                        <input type="button" class="button_gen awg-mini" value="Generate" data-i18n-val="BTN_GEN_IPARAMS" onclick="genIparams();" style="margin-bottom:5px;">
                        <div class="awg-hint" data-i18n-html="HINT_IPARAMS"></div>
                        <input type="text" id="awgs_i1_f" class="input_32_table" style="width:96%;" placeholder="I1" onchange="markDirty();">
                        <input type="text" id="awgs_i2_f" class="input_32_table" style="width:96%;" placeholder="I2" onchange="markDirty();">
                        <input type="text" id="awgs_i3_f" class="input_32_table" style="width:96%;" placeholder="I3" onchange="markDirty();">
                        <input type="text" id="awgs_i4_f" class="input_32_table" style="width:96%;" placeholder="I4" onchange="markDirty();">
                        <input type="text" id="awgs_i5_f" class="input_32_table" style="width:96%;" placeholder="I5" onchange="markDirty();">
                    </td>
                </tr>
                </table>

                <!-- Peers -->
                <div class="awg-section" data-i18n="SEC_PEERS">Peers</div>
                <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable_table" id="awgs_peer_table">
                <thead>
                <tr>
                    <td width="16%" data-i18n="TH_PEER_NAME">Name</td>
                    <td width="12%" data-i18n="TH_PEER_IP">IP</td>
                    <td width="20%" data-i18n="TH_PEER_POLICY">Routing policy</td>
                    <td width="16%" data-i18n="TH_PEER_MODE">Tunnel scope</td>
                    <td width="5%" data-i18n="TH_PEER_ON">On</td>
                    <td width="17%" data-i18n="TH_PEER_STATE">Handshake / traffic</td>
                    <td width="14%" data-i18n="TH_PEER_ACT">Config</td>
                </tr>
                </thead>
                <tbody id="awgs_peer_rows"></tbody>
                </table>
                <div style="margin:8px 0;">
                    <input type="button" class="button_gen" value="+ Add peer" data-i18n-val="BTN_ADD_PEER" onclick="addPeer();">
                </div>

                <!-- Apply -->
                <div style="text-align:center; margin:14px 0;">
                    <input type="button" id="btn_apply" class="button_gen" value="Apply" data-i18n-val="BTN_APPLY" onclick="saveSettings();">
                    <div class="awg-hint" data-i18n="MSG_APPLY_RESTART_HINT"></div>
                </div>

                <!-- Log -->
                <div class="awg-section" data-i18n="SEC_LOG">Log</div>
                <div id="awgs_log" class="awg-log"></div>

                <!-- Footer: donate + copyright (DCRM) -->
                <div style="display:flex; align-items:center; flex-wrap:wrap; gap:2px 10px; font-size:11px; opacity:0.55; margin-top:8px;">
                    <span style="margin-right:auto;">
                        <span data-i18n="DONATE_LABEL" style="color:#ffd24a; font-weight:bold;">Support the project</span>&nbsp;&middot;&nbsp;USDT (TRC-20):
                        <code onclick="awgCopyAddr('TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr', this);" title="Click to copy the address" data-i18n-title="DONATE_COPY_TITLE" style="cursor:pointer; padding:1px 4px; border:1px solid #555; border-radius:3px; font-size:11px;">TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr</code>
                    </span>
                    <span style="text-align:right;">
                        <a href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" style="text-decoration:none;">&copy; DCRM</a>
                    </span>
                </div>

            </td></tr>
            </table>
            </td>
        </tr>
        </table>
    </td>
    <td width="10" align="center" valign="top"></td>
</tr>
</table>
</form>

<!-- QR / config modal -->
<div id="awgs_qr_modal" onclick="if(event.target===this)closeQr();">
    <div id="awgs_qr_inner">
        <div class="formfonttitle" id="awgs_qr_title" style="font-size:16px;"></div>
        <div style="margin:6px 0 10px 0;" class="splitLine"></div>
        <div id="awgs_qr_svg"></div>
        <textarea id="awgs_qr_conf" readonly spellcheck="false"></textarea>
        <div style="text-align:center; margin-top:10px;">
            <input type="button" id="awgs_qr_copy" class="button_gen awg-btn" value="Copy" data-i18n-val="BTN_COPY" onclick="copyConf();">
            <input type="button" class="button_gen awg-btn" value="Close" data-i18n-val="BTN_CLOSE" onclick="closeQr();">
        </div>
    </div>
</div>

<div id="footer"></div>
</body>
</html>
