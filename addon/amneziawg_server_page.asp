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
/* Protocol-version badge next to an obfuscation parameter. Which AmneziaWG version first
   shipped a param decides whether the PEER understands it at all, so it belongs on the
   label rather than buried in a hint. */
.awg-ver { display:inline-block; margin-left:6px; padding:0 5px; border-radius:8px;
           font-size:9px; font-weight:normal; line-height:15px; vertical-align:middle;
           background:#3a4548; border:1px solid #5a6b70; color:#b6bdc7; }
.awg-ver.v3 { background:#4a4230; border-color:#7a6a3a; color:#e8dfc8; }
.awg-hint { color: #b6bdc7; font-size: 11px; line-height: 1.5; margin-top: 4px; }
.awg-hint code, .awg-hint b { color: #d7dce3; }
.awg-hint code { font-family: "Courier New", "Lucida Console", monospace; background: rgba(255,255,255,0.07); padding: 1px 5px; border-radius: 3px; }
/* Masked key fields: same embedded disc-font trick as the client page (no -webkit-text-security,
   no type=password — keeps Safari/Chromium password managers away from WG keys). */
@font-face { font-family: 'awg-disc'; src: url(data:font/woff2;base64,d09GMgABAAAAAAjoAAsAAAAAMGgAAAidAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHFQGVgDWYgpQdQE2AiQDCAsGAAQgBYUOBy4bvi8lYxtWw7BxAPB87x5FmeAMlf3/96RzDN74RcXUcjTKmrJ3T2VDSShiPhfiIJxxS7DiLkHFfQV33CM4427mAred74pWur/J3dyVsKy7coREA8fzvPvpfUk+tB3R8YTCzE0SCLepejmJ2u1yqp+kC7W4Rc/tDTs3GpNJ8ttRPOSTPhsXlwbi4kVYWQmAcXmlrqYHMMsBwP/zHMz7fkF1gijOKuFQIxjwlGa2lkARhYaBxFHT54IOgBMQADi3LipIMAA3geO41EUkBTCO2gkxnOwnKYBx1E6p5WS+QUCMq50rNch6MwUCAAiAcdgttYVSIfPJ5kn6ApRFQ6I88BxLvvIC/maHUHS3TIoKiwLbbM8nEFWgE1oDz3woSxpagWbBXcQWhKtPeIlg6tK+7vX57QOszwU3sGUJrA7h2Mx1IWCNr9BKxsYo+pzS/OCO0OG9mwBkx337+lcuSxRdBcc+fJxlcAjK/zCfdgtBzuxQcTqfY4Yn6EB/Az3JS/RMu5f6B8wrn55S0IxdlLn+4Yb/ctIT+ocWYPcGAOvxSjEjpSiVMqSgFWVjzpCCXjAIRirTABpEQ2gYjaBRNIbG0QSaRFNoGs2gWTSH5tECWkRLaBmtoFW0htbRBtpEW2gb7aBdtIf20QE6REdFDlkZEh2jE3SKztA5ukCX6Apdoxt0i+7QPXpAj+gJPaMX9Ire0Dv6QJ/oC/qKvqHv6Af6iX6h3+gP+ov+of+I+ECMxETMiDmxIJbEilgTG2JL7Ig9cSCOxIk4ExfiStyIO/EgnsSLeBMf4kv8iD/taQANoiE0jEbQKBpD42gCTaIpNI1m0CyaQ/NoAS2iJbSMVtAqWkPraANtoi20jXbQLtpD++gAHaIjdIxO0Ck6Q+foAl2iK3SNbtAtukP36AE9oif0jF7QK3pD79B79AF9RJ/QZ/QFfUXf0Hf0A/1Ev9Bv9Af9Rf/Qf9DQABpEQ2gYjaBRNIbG0QSaRFNoGs2gWTSH5tECWkRLaBmtoFW0htbRBtpEW2gb7aBdtIf20QE6REfoGJ2gU3SGztEFukRX6BrdoFt0h+7RA3pET+gZvaBX9Aa9Re/Qe/QBfUSf0Gf0BX1F39B39AP9RL/Qb/QH/UX/0P8l9vq9gXwDIUCliyAhRAgTIoQoIUaIExKEJCFFSBMyhCwhR8gTCoQioUQoEyqEKqFGqBMahCahRWgTOoQuoUfoEwaEIWFEGBMmhClhRpgTFoQlYUVYEzaELWFH2BMOhGPCCeGUcEY4J1wQLglXhGvCDeGWcEe4JzwQHglPhGfCC+GV8EZ4J3wQPglfhG/CD+GX8Ef4p9sdgoQQIUyIEKKEGCFOSBCShBQhTcgQsoQcIU8oEIqEEqFMqBCqhBqhTmgkNBGaCS2EVkIboZ3QQegkdBG6CT2EXkIfoZ8wQBgkDBGGCSOEUcIYYZwwQZgkTBGmCTOEWcIcYZ6wQFgkLBGWCSuEVcIaYZ2wQdgkbBG2CTuEXcIeYZ9wQDgkHBGOCSeEU8IZ4ZxwQbgkXBGuCTeEW8Id4Z7wQHgkPBGeCS+EV8Ib4Z3wQfgkfBG+CT+EX8If4Z8AZpAQIoQJEUKUECPECQlCkpAipAkZQpaQI+QJBUKRUCKUCRVClVAj1AkNQpPQIrQJHUKX0CP0CQPCkDAijAkTwpQwI8wJC8KSsCKsCRvClrAj7AkHwpFwIpwJF8IV4ZpwQ7gl3BHuCQ+ER8IT4ZnwQnglvBHeCR+ET8IX4ZvwQ/gl/BH+lzv+AmMkTYAmSBOiCdNEaKI0MZo4TYImSZOiSdNkaLI0OZo8TYGmSFOiKdNUaKo0NZo6TYOmSdOiadN0aLo0PZo+zYBmSDOiGdNMaKY0M5o5zYJmSbOiWdNsaLY0O5o9zYHmmOaE5pTmjOac5oLmkuaK5prmhuaW5o7mnuaB5pHmieaZ5oXmleaN5p3mg+aT5ovmm+aH5pfmj2ZRAqCCoEKgwqAioKKgYqDioBKgkqBSoNKgMqCyoHKg8qAKoIqgSqDKoCqgqqBqoOqgGkE1gWoG1QKqFVQbqHZQHaA6QXWB6gbVA6oXVB+oflADoAZBDYH+uxaEWDBiIYiFIhaGWDhiEYhFIhaFWDRiMYjFIhaHWDxiCYglIpaEWDJiKYilIpaGWDpiGYhlIpaFWDZiOYjlIpaHWD5iBYgVIlaEWDFiJYiVIlaGWDliFYhVIlaFWDViNYjVIlaHWD1iDYg1ItaEWDNiLYi1ItaGWDtiHYh1ItaFWDdiPYj1ItaHWD9iA4gNIjaE2DBiI4iNIjaG2DhiE4hNIjaF2DRiM4jNIjaH2DxiC4gtIraE2DJiK4itIraG2DpiG4htIraF2DZiO4jtIraH2D5iB4gdInaE2DFiJ4idInaG2DliF4hdInaF2DViN4jdInaH2D1iD4g9IvaE2DNiL4i9IvaG2DvE3iP2AbGPiH1C7DNiXxD7itg3xL4j9gOxn4j9Quw3Yn8Q+4vYP8T+M6cIDBz9EXfeUHR1JyygPL/++I3R1cRvdDr+E12Jfh3Q0EN/fHn2mXptpJxUkIqu/Cs2egM33OjSLcT33I82+B9nP37X/c0W52623s45CYCo03QIBCVrAFAycnSYSqvO4YJt/NP73YqA/giNZhJ6sBbmql+0SQZaxNOZudJbc2nqxNvpM+veq7Sz2LUgFEu+VLs+Ay3yp7MVertp6i23v2Rmv5gmHDhSQ6t5GmTaqTsqhpWwmbOk3uKJrNOmwSSMC17jghqygilDOUU3KlLmHHNrajw3DVNVGWytGZDisM/cbkdRnvfIUJkaGJlgAYcoQ5bGptTmGc1R7pBC3XhFsLXnXR54qrMc+dGNBkqE4laBi4KmZYGom8vIy0lTyBkppBjLoTndMmrofIRORirsNlCbXzCgulmo36KztS2iV8rrNoRUL5VdkMSGoSXroC1KOQAA) format('woff2'); }
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
// Save baseline (1.5.26): the store exactly as THIS page loaded it, copied before anything
// mutates the model. A save compares the LIVE store against it and refuses when a key this page
// owns (awgs_*) changed since — another tab or SSH — instead of silently reverting that change
// (see awgsSave). It only ever advances to what this page itself wrote.
var awgsCsBase = awgsCopy(custom_settings);
var statusTimer = null;
// Last AmneziaWG 3.0 capability verdict: true / false / null while unknown. Three-state on
// purpose — only an explicit false means "this build cannot do 3.0" (see
// applyAwg3CapabilitySrv); unknown must NOT disable anything. Declared here, next to the other
// page state, because genHpk() and the peer-config export both read it.
var awgs3Cap = null;
var awgs31Cap = null;
var awgsActionGen = 0;          // generation token: stale in-flight polls must not repaint the UI
var awgsStatus = null;
var awgsPeers = [];             // working copy of the peer store (saved on Apply)
var awgsDirty = false;
var awgsEditSeq = 0;            // bumped by markDirty: an edit made while a save is in flight stays unsaved
var awgsSaveBusy = false;       // form lock: a settings save is between its pre-fetch and its read-back
var awgsCsStale = false;        // a save's outcome was 'unknown': every later save is a conflict until reload
var awgsCsRetained = null;      // the pre-fetched store kept after a TRUNCATED write (see awgsSave)
var awgsPeersCut = false;       // the peer store read back cut — server saves are refused (loadPeers)
var awgsPeersCutWhy = '';       // why: 'space' | 'oversize' (the backend repairs both) | 'lost' (the data is gone)
var awgsPeersLost = [];         // labels of the damaged entries — a confirmed 'lost' save drops them
var awgsPeersPending = false;   // 'space' while the file may still hold the full list: awgsPeersSettle decides
var awgsPeersKnown = null;      // this page's view of the store ({keys, n}) for the backend comparison
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
    BTN_CHECKING: "Checking…",
    ACK_SAVED: "Saved ✓",
    ACK_SAVED_BUSY: "Saved; the router was busy — the action may not have run, check the log.",
    SEC_SETTINGS: "Server settings",
    SEC_OBFS: "Obfuscation parameters (shared by all peer configs)",
    SEC_AWG3: "AmneziaWG 3.0 — peers need a 3.0-capable client",
    AWG3_UNSUPPORTED: "AmneziaWG 3.0 parameters are not supported by the installed binaries — the fields below are disabled.",
    BTN_GENERATE: "Generate",
    HINT_S_ALL: "S3/S4 are optional for AWG 2.0, but Header protection (AWG 3.0) needs all four ≥ 12.",
    HINT_AWG3_HPK_SRV: "Written into every peer config and QR code — server and clients must share it. Requires S1–S4 ≥ 12.",
    HINT_AWG3_CPA: "A single number or a \"lo-hi\" range: extra bytes per data packet. A padded packet never exceeds the largest one sent since the peer's last reply (500 B minimum), so the biggest packets go unpadded.",
    HINT_AWG3_REKEY: "Seconds. Defaults 120 / 5.",
    HINT_AWG3_REJECT: "Seconds. Defaults 180 / 10. RejectAfterTime must stay above RekeyAfterTime.",
    HINT_AWG3_MHA: "Handshake retries before giving up. Default 18.",
    AWG31_UNSUPPORTED: "AmneziaWG 3.1 parameters (RandomTrailers / DisableCookies) are not supported by the installed binaries — those two fields are disabled.",
    OPT_AWG31_UNSET: "— (default: off)",
    HINT_AWG31_RT_SRV: "SYMMETRIC: \"on\" is written into every peer config/QR — peers need an AmneziaWG 3.1+ client app and must re-import after changing this, or the server's handshakes are dropped.",
    HINT_AWG31_DC_SRV: "Server-side only: never send cookie replies (a DPI-visible message). Not written into peer configs. Trade-off: no protection against a flood of valid handshakes — each costs the router an X25519 operation, so anyone holding a peer config (or replaying a captured handshake) can max out its CPU. Keep off unless DPI demands it.",
    MSG_HPK_S_BUMPED: "Header protection needs S1–S4 ≥ 12, so %s were raised automatically. Re-export the peer configs / QR codes — clients must use the same values.",
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
    BYPASS_XRAY_TT: "Force this peer into the client tunnel (double hop) even while Xray runs — a rule is inserted ahead of Xray's transparent proxy so this peer's traffic isn't captured by it. Needs the client tunnel up. Available for «VPN: all traffic» peers only: the rule works by terminating packet processing early, which would skip the marking a geo policy needs.",
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
    MSG_SETTINGS_TOO_BIG: "Settings don't fit the firmware's store: {0} of {1} bytes. Asuswrt-Merlin does not save a larger set at all (the whole save is discarded), and this budget is shared with the client's profiles and every other addon. Remove a peer or shorten the I1-I5 junk data.",
    MSG_WAIT_SAVE: "Please wait — the settings are being saved.",
    MSG_CS_CONFLICT: "The server settings changed after this page was loaded (another tab or SSH). The save was cancelled so as not to overwrite those changes. Reload the page now? Unsaved edits on this page will be lost.",
    MSG_ROUTER_BUSY: "The router is not responding (a tunnel restart or a list download is in progress) — try again in a few seconds.",
    MSG_SESSION_EXPIRED: "Your router login session has expired — log in in another tab and try again; your edits on this page are kept.",
    MSG_SAVE_DISCARDED: "The router did not write the settings (the firmware rejected the save). Reload the page to see the current state.",
    MSG_SAVE_DISCARDED_SRV: "The server changes were not applied.",
    MSG_CS_UNKNOWN: "Another page saved the settings at the same moment as this save — the result is unknown. Reload the page.",
    MSG_STORE_TRUNCATED: "The router wrote the settings only partially (/jffs is probably full). Do not reload the page: free some space and press «Apply» again.",
    MSG_PEERS_CUT: "Saving is blocked: the peer list was read back incomplete (see the red message at the top), and saving now would erase the missing peers. Reload the page in a minute.",
    BAN_PEERS_CUT: "<b>The peer list was read back incomplete.</b> The stored list contains a peer name with a space (saved by an older version), and the firmware hands this page only the part before it. Saving the server settings is blocked so the remaining peers are not erased — the server itself keeps using the full list. The addon repairs such a name automatically: reload the page in a minute.",
    BAN_PEERS_OVERSIZE: "<b>The peer list was read back incomplete.</b> An older version of this page split the stored list into pieces by characters, and with long non-Latin peer names a piece came out longer than the firmware hands back to this page (2999 bytes). Saving the server settings is blocked so the peers in the unread part are not erased or damaged — the server itself keeps using the stored list. The addon re-splits such a list automatically: reload the page in a minute.",
    BAN_PEERS_LOST: "<b>Damaged peer entries in the stored list: {0}.</b> An older version of this page saved the list in pieces too long for the firmware, and the firmware cut such a piece short in the settings file itself — that data is gone, and waiting will not bring it back. The other peers are intact. «Apply» saves the settings without the damaged entries (it asks first); then re-create the affected peer and give it its new config.",
    MSG_PEERS_LOST_CONFIRM: "These peer entries are damaged beyond repair (their data was cut off in the stored settings): {0}.\n\nSave the settings WITHOUT them? The other peers are kept. Afterwards re-create the affected peer and give it its new config.\n\n(If you saved the peers from an older version of this page a moment ago, press Cancel, wait a minute and reload the page instead.)",
    MSG_APPLY_RESTART_HINT: "Settings are applied live where possible; subnet/key changes restart the server.",
    BAN_FIRSTRUN: "<b>Server is not configured yet.</b><br>Click «Generate» for the server keys, check the port and subnet, add a peer, then press «Apply» and «Start server».",
    BAN_WAN_PRIVATE: "<b>WAN address is private/CGNAT ({0}).</b> Peers from the internet cannot reach this router directly — you need a public IP from your ISP or a port forward (UDP {1}) on the upstream router.",
    BAN_PORT_CONFLICT: "<b>The firmware WireGuard server uses the same UDP port {0}.</b> Change this server's port or disable the firmware WG server (VPN → WireGuard).",
    BAN_CLIENT_DOWN: "The AmneziaWG <b>client</b> tunnel is not running — peers with a «VPN…» policy currently go <b>directly</b> to the internet through your WAN (fail-open). Start the client tunnel on the AmneziaWG page for the policies to apply.",
    BAN_UNSAVED: "Unsaved changes — press «Apply».",
    BAN_XRAY_POLICY: "⛔ <b>Xray / XRAYUI</b> is running in transparent-proxy mode («redirect all»), and some peers have a «VPN…» policy <b>without «bypass Xray»</b>. For those peers the double hop doesn't happen — Xray captures their traffic in PREROUTING before AmneziaWG's routing rule (ip-rule 19 vs 99), so they exit through Xray, not the client tunnel. Fixes:<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li><b>Want the double hop</b> — on a <b>«VPN: all traffic»</b> peer tick <b>«bypass Xray»</b>: a rule is placed ahead of Xray so this peer goes into the client tunnel (which must be up). Xray keeps running for everything else.</li><li><b>Fine with Xray</b> — switch the peer to «Direct»: its traffic flows through Xray anyway (DPI bypass).</li><li>Or stop Xray entirely (button below).</li></ul>",
    BAN_XRAY_GEO: "<div style=\"margin-top:6px;\">Peers on a <b>geo policy</b> have no «bypass Xray» option: that rule works by ending packet processing early, which would skip the marking a geo policy needs — it would send the peer straight out of the WAN instead. For a geo peer, either switch it to <b>«VPN: all traffic»</b> and tick «bypass Xray», or accept that Xray handles it (its DPI bypass still applies), or stop Xray.</div>",
    BAN_XRAY_INFO: "<b>Xray / XRAYUI</b> is running in transparent-proxy mode («redirect all») — peer traffic automatically flows <b>through Xray</b> (DPI bypass), non-proxied destinations go straight to WAN. This is a working setup. For a peer that should instead double-hop through the client tunnel, give it a «VPN…» policy and tick «bypass Xray».",
    BAN_XRAY_UNCOVERED: "<b>Xray / XRAYUI</b> is running, but the peer subnet <code>{0}</code> is <b>not in its capture rules</b> — peer traffic bypasses Xray and goes straight to WAN (no DPI bypass). This usually means XRAYUI started before this server did. Fix: <b>restart XRAYUI</b> (it picks up existing interfaces at start), or add the subnet to its transparent-proxy settings.",
    XRAY_STOP_BTN: "Stop Xray",
    XRAY_STOPPING: "Stopping Xray…",
    XRAY_STOP_CONFIRM: "Stop Xray / XRAYUI now? This is a regular stop via XRAYUI's own command — same as the Stop button on its page. Only the active TPROXY firewall rules are removed so AmneziaWG can route peer traffic; XRAYUI's saved settings and rules are not touched. Start it again from its page (VPN → X-RAY) and it will come back with all its previous settings.",
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
    BTN_CHECKING: "Проверка…",
    ACK_SAVED: "Сохранено ✓",
    ACK_SAVED_BUSY: "Сохранено; роутер был занят — действие могло не выполниться, проверьте журнал.",
    SEC_SETTINGS: "Настройки сервера",
    SEC_OBFS: "Параметры обфускации (общие для всех конфигов пиров)",
    SEC_AWG3: "AmneziaWG 3.0 — пирам нужен клиент с поддержкой 3.0",
    AWG3_UNSUPPORTED: "Параметры AmneziaWG 3.0 не поддерживаются установленными бинарниками — поля ниже отключены.",
    BTN_GENERATE: "Сгенерировать",
    HINT_S_ALL: "S3/S4 необязательны для AWG 2.0, но для Header protection (AWG 3.0) нужны все четыре ≥ 12.",
    HINT_AWG3_HPK_SRV: "Попадает в каждый конфиг пира и QR-код — на сервере и клиентах должен совпадать. Требует S1–S4 ≥ 12.",
    HINT_AWG3_CPA: "Одно число или диапазон «lo-hi»: добавочные байты к пакету данных. Пакет с добавкой не больше самого крупного, отправленного с последнего ответа пира (минимум 500 Б), поэтому самые крупные пакеты уходят без добавки.",
    HINT_AWG3_REKEY: "Секунды. По умолчанию 120 / 5.",
    HINT_AWG3_REJECT: "Секунды. По умолчанию 180 / 10. RejectAfterTime должен быть больше RekeyAfterTime.",
    HINT_AWG3_MHA: "Сколько раз повторять хендшейк перед сдачей. По умолчанию 18.",
    AWG31_UNSUPPORTED: "Параметры AmneziaWG 3.1 (RandomTrailers / DisableCookies) не поддерживаются установленными бинарниками — эти два поля отключены.",
    OPT_AWG31_UNSET: "— (по умолчанию off)",
    HINT_AWG31_RT_SRV: "Симметричный: при «on» попадает в каждый конфиг пира и QR — пирам нужно приложение с AmneziaWG 3.1+, и после изменения конфиг надо переимпортировать, иначе рукопожатия сервера отбрасываются.",
    HINT_AWG31_DC_SRV: "Только на сервере: не отправлять cookie-ответы (служебное сообщение, заметное для DPI). В конфиги пиров не записывается. Цена: нет защиты от флуда настоящими рукопожатиями — каждое стоит роутеру операции X25519, и любой, у кого есть конфиг пира (или кто повторяет перехваченное рукопожатие), может загрузить его процессор. Без нужды не включайте.",
    MSG_HPK_S_BUMPED: "Для Header protection нужны S1–S4 ≥ 12, поэтому %s подняты автоматически. Переэкспортируйте конфиги пиров / QR — на клиентах должны быть те же значения.",
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
    BYPASS_XRAY_TT: "Заворачивать трафик этого пира в клиентский туннель (двойной хоп) даже при работающем Xray — правило ставится перед перехватом Xray, чтобы трафик пира в него не попадал. Нужен поднятый клиентский туннель. Доступно только для пиров с политикой «VPN: весь трафик»: правило работает через раннее прекращение обработки пакета, а это пропустило бы простановку метки, без которой гео-политика не работает.",
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
    MSG_SETTINGS_TOO_BIG: "Настройки не помещаются в хранилище прошивки: {0} из {1} байт. Больший набор Asuswrt-Merlin не сохраняет вообще (сохранение отбрасывается целиком), а этот лимит общий с профилями клиента и всеми другими аддонами. Удалите пира или сократите мусорные данные I1-I5.",
    MSG_WAIT_SAVE: "Подождите — идёт сохранение настроек.",
    MSG_CS_CONFLICT: "Настройки сервера изменились после загрузки этой страницы (другая вкладка или SSH). Чтобы не перезаписать эти изменения, сохранение отменено. Обновить страницу сейчас? Несохранённые правки на этой странице будут потеряны.",
    MSG_ROUTER_BUSY: "Роутер не отвечает (идёт перезапуск туннеля или загрузка списков) — повторите через несколько секунд.",
    MSG_SESSION_EXPIRED: "Сеанс входа в роутер истёк — войдите в другой вкладке и повторите; правки на этой странице сохранены.",
    MSG_SAVE_DISCARDED: "Роутер не записал настройки (прошивка отклонила сохранение). Обновите страницу, чтобы увидеть текущее состояние.",
    MSG_SAVE_DISCARDED_SRV: "Изменения сервера не применены.",
    MSG_CS_UNKNOWN: "Одновременно с этим сохранением настройки записала другая страница — результат неизвестен. Обновите страницу.",
    MSG_STORE_TRUNCATED: "Роутер записал настройки не полностью (вероятно, заполнен /jffs). Не перезагружайте страницу: освободите место и нажмите «Применить» ещё раз.",
    MSG_PEERS_CUT: "Сохранение заблокировано: список пиров прочитан не полностью (см. красное сообщение вверху), и сохранение сейчас стёрло бы недостающих пиров. Обновите страницу через минуту.",
    BAN_PEERS_CUT: "<b>Список пиров прочитан не полностью.</b> В сохранённом списке есть имя пира с пробелом (запись старой версии), а прошивка отдаёт странице только часть до него. Сохранение настроек сервера заблокировано, чтобы не стереть остальных пиров — сам сервер при этом работает с полным списком. Такое имя аддон исправляет автоматически: обновите страницу через минуту.",
    BAN_PEERS_OVERSIZE: "<b>Список пиров прочитан не полностью.</b> Старая версия этой страницы делила сохранённый список на части по символам, и из-за длинных имён пиров не латиницей часть получилась длиннее, чем прошивка отдаёт странице (2999 байт). Сохранение настроек сервера заблокировано, чтобы не стереть и не повредить пиров из непрочитанной части — сам сервер при этом работает с сохранённым списком. Такой список аддон переразбивает автоматически: обновите страницу через минуту.",
    BAN_PEERS_LOST: "<b>В сохранённом списке пиров есть повреждённые записи: {0}.</b> Старая версия этой страницы сохраняла список частями длиннее, чем принимает прошивка, и прошивка обрезала такую часть прямо в файле настроек — эти данные потеряны, и ожидание их не вернёт. Остальные пиры целы. «Применить» сохранит настройки без повреждённых записей (сначала спросит); затем создайте этого пира заново и передайте ему новый конфиг.",
    MSG_PEERS_LOST_CONFIRM: "Эти записи пиров повреждены безвозвратно (их данные обрезаны в сохранённых настройках): {0}.\n\nСохранить настройки БЕЗ них? Остальные пиры сохранятся. Затем создайте этого пира заново и передайте ему новый конфиг.\n\n(Если вы только что сохраняли пиров со старой версии этой страницы, нажмите «Отмена», подождите минуту и обновите страницу.)",
    MSG_APPLY_RESTART_HINT: "Настройки применяются на лету, где возможно; смена подсети/ключей перезапускает сервер.",
    BAN_FIRSTRUN: "<b>Сервер ещё не настроен.</b><br>Нажмите «Сгенерировать» для ключей сервера, проверьте порт и подсеть, добавьте пира, затем «Применить» и «Запустить сервер».",
    BAN_WAN_PRIVATE: "<b>WAN-адрес приватный/CGNAT ({0}).</b> Пиры из интернета не достучатся до роутера напрямую — нужен белый IP от провайдера или проброс порта (UDP {1}) на вышестоящем роутере.",
    BAN_PORT_CONFLICT: "<b>Встроенный WireGuard-сервер прошивки использует тот же UDP-порт {0}.</b> Смените порт этого сервера или выключите WG-сервер прошивки (VPN → WireGuard).",
    BAN_CLIENT_DOWN: "<b>Клиентский</b> туннель AmneziaWG не запущен — пиры с политикой «VPN…» сейчас ходят в интернет <b>напрямую</b> через WAN (fail-open). Запустите клиентский туннель на странице AmneziaWG, чтобы политики заработали.",
    BAN_UNSAVED: "Есть несохранённые изменения — нажмите «Применить».",
    BAN_XRAY_POLICY: "⛔ <b>Xray / XRAYUI</b> работает в режиме прозрачного прокси («весь трафик»), и у части пиров стоит политика «VPN…» <b>без галочки «мимо Xray»</b>. Для таких пиров двойной хоп не происходит — Xray перехватывает их трафик в PREROUTING раньше правила маршрутизации AmneziaWG (приоритет ip-rule 19 против 99), поэтому они выходят через Xray, а не через клиентский туннель. Что делать:<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li><b>Нужен двойной хоп</b> — у пира с политикой <b>«VPN: весь трафик»</b> включите галочку <b>«мимо Xray»</b>: правило ставится перед Xray, и этот пир уходит в клиентский туннель (он должен быть поднят). Xray для остального продолжает работать.</li><li><b>Xray устраивает</b> — переведите пира на «Напрямую»: его трафик и так пойдёт через Xray (обход DPI).</li><li>Либо остановите Xray целиком (кнопка ниже).</li></ul>",
    BAN_XRAY_GEO: "<div style=\"margin-top:6px;\">У пиров с <b>гео-политикой</b> галочки «мимо Xray» нет: это правило работает через раннее прекращение обработки пакета, из-за чего пропускается простановка метки, без которой гео-политика не работает — пир ушёл бы прямо в WAN. Для гео-пира: либо переведите его на <b>«VPN: весь трафик»</b> и включите «мимо Xray», либо примите, что им занимается Xray (обход DPI при этом работает), либо остановите Xray.</div>",
    BAN_XRAY_INFO: "<b>Xray / XRAYUI</b> работает в режиме прозрачного прокси («весь трафик») — трафик пиров автоматически идёт <b>через Xray</b> (обход DPI), непроксируемые адреса — напрямую в WAN. Это штатная рабочая схема. Если какому-то пиру нужен именно двойной хоп через клиентский туннель — поставьте ему политику «VPN…» и галочку «мимо Xray».",
    BAN_XRAY_UNCOVERED: "<b>Xray / XRAYUI</b> запущен, но подсети пиров <code>{0}</code> <b>нет в его правилах перехвата</b> — трафик пиров идёт мимо Xray, напрямую в WAN (без обхода DPI). Обычно так бывает, когда XRAYUI стартовал раньше этого сервера. Решение: <b>перезапустите XRAYUI</b> (при старте он подхватывает существующие интерфейсы) или добавьте подсеть в его настройки прозрачного прокси.",
    XRAY_STOP_BTN: "Остановить Xray",
    XRAY_STOPPING: "Останавливаю Xray…",
    XRAY_STOP_CONFIRM: "Остановить Xray / XRAYUI сейчас? Это штатная остановка командой самого XRAYUI — то же, что кнопка «Стоп» на его странице. Из файрвола снимаются только действующие правила TPROXY, чтобы AmneziaWG мог маршрутизировать трафик пиров; сохранённые настройки и правила XRAYUI не затрагиваются. Включите его снова на странице VPN → X-RAY — он поднимется со всеми прежними настройками.",
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
// chunk a long value across key, key1, key2… (<=2900 bytes each — the firmware caps one
// custom_settings value at ~3000 and silently truncates the rest; same scheme as awg_initdata)
// The cap is in BYTES (the page reads back <=2999 bytes of a value), so chunks are cut by UTF-8
// length since 1.5.26 (2900 CHARS before): ~17 peers with long Cyrillic names made a chunk ~3300 bytes,
// which the page then read back cut. ASCII content (keys, base64 I1-I5) chunks exactly as before;
// the backend just concatenates the chunks, so their boundaries are free to move.
var CHUNK = 2900;
function setChunked(baseKey, val, maxChunks){
    for (var i = 1; i <= maxChunks; i++) delete custom_settings[baseKey + i];
    if (!val) { delete custom_settings[baseKey]; return; }
    var parts = awgsSplitBytes(val, CHUNK);
    custom_settings[baseKey] = parts[0];
    for (var j = 1; j < parts.length && j <= maxChunks; j++)
        custom_settings[baseKey + j] = parts[j];
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
// Inner whitespace becomes '_' (1.5.26): the firmware's reader cuts a stored value at its first
// whitespace, and the whole peer list is ONE value — a peer named «My Phone» made this page read
// back just "My", show no peers at all, and the next save of either page persisted that cut,
// erasing every peer. (The backend migrates names already stored with spaces.)
function sanitizeName(n){
    return String(n || '').replace(/[|;,"\\<>&]/g, '').replace(/^\s+|\s+$/g, '').replace(/\s+/g, '_').substr(0, 24);
}
function loadPeers(){
    awgsPeers = [];
    awgsPeersCut = false; awgsPeersCutWhy = ''; awgsPeersLost = []; awgsPeersPending = false;
    awgsPeersKnown = { keys: {}, n: 0 };
    var raw = getChunked('awgs_peers', 10);
    if (!raw) return;
    // Chunk boundaries. The 1.5.25 writer ended every non-last chunk at exactly 2900 CHARS; this
    // one (and the backend's re-split) cuts by bytes and ends a chunk short of 2900 bytes ONLY
    // where the next character would not fit (cb + w > 2900). Anything else is a cut, and the
    // reassembled list glues two pieces together at that junction without failing the field
    // count below (a 2897-2899-byte ASCII chunk is a cut too: its next char would have fit):
    //  - over 2900 bytes: an old char-sized chunk the reader capped at 2999 bytes ('oversize' —
    //    the backend re-splits the list by bytes). The LAST chunk counts too once it reads back
    //    capped (2999-3001 bytes: 2999, plus a U+FFFD for a character cut in half) — the hidden
    //    part is then the end of the final entry, usually inside its psk: 8 fields, no alarm;
    //  - shorter: the value ended at a whitespace in a legacy peer name ('space' — the backend
    //    rewrites it to '_'), or a page already re-saved that cut view (then it is lost: see
    //    awgsPeersSettle).
    // A chunk that ends the way a byte splitter ends one is only PROBABLY that (sigs): a
    // whitespace cut of an old 2900-CHAR chunk can leave exactly 2897-2900 bytes too, when the
    // names before the space are multi-byte (an ASCII kept part is always under 2900 bytes and
    // the rule above catches it). The entry across such a junction decides it, below.
    var oversize = false, space = false, byteSplit = false, cuts = [], sigs = [], off = 0, c, i, j, f;
    for (c = 0; c <= 10; c++) {
        var ck = gs('awgs_peers' + (c ? c : '')), nx = (c < 10) ? gs('awgs_peers' + (c + 1)) : '';
        if (!ck) break;
        var cb = awgsUtf8Len(ck);
        off += ck.length;
        if (!nx) { if (cb >= 2999 && ck.length < CHUNK) oversize = true; break; }
        if (ck.length === CHUNK) continue;
        var w = awgsUtf8Len(/^[\uD800-\uDBFF][\uDC00-\uDFFF]/.test(nx) ? nx.substr(0, 2) : nx.charAt(0));
        if (cb <= CHUNK && cb + w > CHUNK) { byteSplit = true; sigs.push(off); continue; }   // a byte splitter's end — probably (sigs)
        if (cb > CHUNK) oversize = true; else space = true;
        cuts.push(off);
    }
    var entries = raw.split(';'), bad = [], last = -1, pos, e;
    for (i = entries.length - 1; i >= 0 && last < 0; i--) if (entries[i] !== '') last = i;
    for (i = 0, pos = 0; i < entries.length; pos += entries[i].length + 1, i++) {
        e = entries[i];
        if (e === '') continue;
        f = e.split('|');
        // What the backend can see of this entry too (its status lists every 6+-field entry).
        if (f.length >= 6) { awgsPeersKnown.n++; if (f[5]) awgsPeersKnown.keys[awgsPeerKey(f[5], f[0])] = 1; }
        // Fewer than 8 fields = a value that was cut, and an entry across a cut junction is glued
        // from two pieces whatever its field count: flag them rather than show them, so
        // saveSettings never persists a peer list that lost its tail without asking.
        var jn = -1;
        for (j = 0; jn < 0 && j < cuts.length; j++) if (cuts[j] > pos && cuts[j] < pos + e.length) jn = cuts[j];
        // A byte splitter's junction lies inside whole entries only. One whose entry does not
        // parse whole (the page's own shape: 8+ fields, a dotted-quad IP, a 0/1 flag) was a
        // whitespace cut after all: glued, and 'space' — pending, awgsPeersSettle decides from the
        // backend's view — never 'lost' at once, which offered to delete a peer the file holds
        // whole. Such a glued entry begins before the junction (a legacy name is trimmed: its
        // first whitespace is never its first character) and may END at it (the old boundary
        // sat right before a ';'). Where the old boundary fell sets its shape: past the IP gives
        // fewer than 8 fields; inside the IP of a 9-field record gives 8 SHIFTED ones (policy as
        // the IP, the private key as the pubkey) — shown as a peer, and a plain Apply saved them.
        // Exempt: the backend's cut-down stubs "name|IP" and "name|" (a head whose IP did not
        // survive) — its re-split store has these junctions too. A glued entry's 2nd field is an
        // IP only when it kept 8+ fields, and it is never empty (every record ends with a flag or
        // a psk), so a 2-field entry of either shape is a stub, lost at once as before.
        for (j = 0; jn < 0 && j < sigs.length; j++)
            if (sigs[j] > pos && sigs[j] <= pos + e.length && !awgsPeerWhole(f) && !(f.length === 2 && (f[1] === '' || AWGS_IP4.test(f[1])))) {
                jn = sigs[j]; space = true;
            }
        if (f.length < 8 || jn >= 0) {
            bad.push({ f: f, tail: i === last });
            // Named from the HEAD alone — the characters before the junction. What follows it
            // belongs to another place in the list (often inside a key: the private one too), so
            // it names nothing and must never reach the banner or the confirm. The IP only when
            // the head holds it whole (its closing '|').
            var hf = (jn >= 0) ? raw.substring(pos, jn).split('|') : f;
            awgsPeersLost.push(awgsPeerLabel((jn >= 0 && hf.length < 3) ? [hf[0]] : hf, jn >= 0 && hf.length === 1));
            continue;
        }
        // 9th field (xbypass) is optional — old 8-field records default it to false.
        awgsPeers.push({ name: f[0], ip: f[1], policy: f[2] || 'direct', mode: f[3] || 'full',
                         enabled: f[4] === '1', pub: f[5], priv: f[6], psk: f[7], xbypass: f[8] === '1' });
    }
    if (oversize) awgsPeersCutWhy = 'oversize';
    else if (space) awgsPeersCutWhy = 'space';
    else if (bad.length) {
        // A reader cut at a legacy name's whitespace ends the value INSIDE that name, which leaves
        // exactly one field, in the list's final entry (such a cut in an earlier chunk shows up
        // above as a short chunk). Every other damaged entry — 2-7 fields, or one in the middle
        // of the list — was cut by the pre-1.5.26 WRITER: it stored chunks by characters and the
        // firmware cut a record over 3039 bytes in the file itself (the backend's re-split only
        // moves that damage off the old boundary). Nothing can restore it. A one-field final
        // entry can be either — unless a byte splitter wrote the store, which never holds a space.
        var t = bad[bad.length - 1];
        awgsPeersCutWhy = (t.tail && t.f.length === 1 && !byteSplit) ? 'space' : 'lost';
    }
    awgsPeersPending = (awgsPeersCutWhy === 'space');
    awgsPeersCut = (awgsPeersCutWhy !== '');
}
// A damaged entry as the banner and the confirm name it: its (partial) name, plus the tunnel IP
// when that field survived. `cut`: the name is a fragment (an entry glued across a junction
// that falls inside its name) — marked with '…' like a long one.
var AWGS_IP4 = /^\d+\.\d+\.\d+\.\d+$/;
function awgsPeerLabel(f, cut){
    var nm = f[0] || '?';
    if (nm.length > 24) { nm = nm.substr(0, 24); cut = true; }
    return '«' + nm + (cut ? '…' : '') + '»' + (AWGS_IP4.test(f[1] || '') ? ' (' + f[1] + ')' : '');
}
// The entry parses whole in the page's own shape (serializePeers: the IP from nextFreeIp, the
// enabled flag as 0/1) — only judged at a junction a byte splitter may have made (loadPeers).
function awgsPeerWhole(f){
    return f.length >= 8 && AWGS_IP4.test(f[1]) && /^[01]$/.test(f[4]);
}
// A 'space' cut is only a PENDING repair while the file still holds the whitespace: a page that
// saved the cut view since (the client page or another addon re-posts what it read back) made
// it permanent, and the backend's migration has nothing left to fix. The BACKEND's own view tells
// them apart: the status lists every stored entry with 6+ fields as srv_peers_raw reads it (whole
// records: no whitespace cut, no 2999-byte cap). A peer there that this page's view lacks = the
// file still holds more: keep refusing. Nothing more = the backend holds the same damaged list,
// so waiting fixes nothing: 'lost'. Re-run on every status; a status without a peer list (the
// synthetic "stopped" one) decides nothing.
// "Lacks" compares pubkey AND name, never the pubkey alone: when the cut drops only the rest of a
// spaced name (an old chunk boundary inside «Laptop Vasi», after the space), the entry glued across
// the junction still carries that peer's real pubkey — a pubkey-only match read "nothing more",
// settled to 'lost' and offered to delete a peer the file held whole. The glued name always lacks
// the dropped whitespace (or, once migrated, its '_'), so it never equals the backend's record; a
// cut some page persisted is the identical record on both sides and still settles.
function awgsPeerKey(pub, name){
    // the status strips '\' and '"' from a name (amneziawg_server.sh): mirror it, or a hand-edited
    // name holding one could never match and a persisted cut would stay refused for good
    return pub + '|' + String(name == null ? '' : name).replace(/[\\"]/g, '');
}
function awgsPeersSettle(st){
    if (!awgsPeersPending || !st || Object.prototype.toString.call(st.peers) !== '[object Array]') return;
    // Only a status srv_update_status wrote is the backend's view of the store: install_page seeds
    // awgs_status.htm with "peers":[] after every reboot (tmpfs) until the server's first status
    // run, and an empty list would settle a pending whitespace cut to 'lost' — the Apply confirm
    // would then drop peers the file still holds whole. The real writer always emits "subnet".
    if (st.subnet === undefined) return;
    var more = st.peers.length > awgsPeersKnown.n;
    for (var i = 0; !more && i < st.peers.length; i++)
        more = !!(st.peers[i] && st.peers[i].pub && !awgsPeersKnown.keys[awgsPeerKey(st.peers[i].pub, st.peers[i].name)]);
    var why = more ? 'space' : 'lost';
    if (why !== awgsPeersCutWhy) { awgsPeersCutWhy = why; awgsPeersBanner(); }
}
// The red banner names the actual cause: only 'space' and 'oversize' promise the automatic repair
// (the backend's migrate_server_peers rewrites a stored whitespace to '_' and re-splits a chunk
// over 2900 bytes — exactly those two; a cut some page already persisted settles to 'lost');
// 'lost' offers the save without the damaged entries instead of refusing forever.
function awgsPeersBanner(){
    var why = awgsPeersCutWhy;
    showBanner('awgs_ban_peers', why !== '', why === 'lost' ? T('BAN_PEERS_LOST', escHtml(awgsPeersLost.join(', ')))
               : T(why === 'oversize' ? 'BAN_PEERS_OVERSIZE' : 'BAN_PEERS_CUT'));
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
// A DNS server list split on whitespace AND commas, empty tokens dropped, comma-joined:
// «1.1.1.1, 8.8.8.8» / «1.1.1.1 8.8.8.8» / « 1.1.1.1 ,, 8.8.8.8, » all give "1.1.1.1,8.8.8.8".
function awgsDnsList(s){
    return String(s || '').split(/[\s,]+/).filter(function(t){ return t !== ''; }).join(',');
}
function markDirty(){ awgsDirty = true; awgsEditSeq++; var b = document.getElementById('awgs_unsaved'); if (b) b.style.display = ''; }

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
    sv('awgs_s3_f', gs('awgs_s3')); sv('awgs_s4_f', gs('awgs_s4'));
    sv('awgs_h1_f', gs('awgs_h1')); sv('awgs_h2_f', gs('awgs_h2'));
    sv('awgs_h3_f', gs('awgs_h3')); sv('awgs_h4_f', gs('awgs_h4'));
    // AmneziaWG 3.0
    sv('awgs_hpk_f', gs('awgs_hpk')); sv('awgs_cpa_f', gs('awgs_cpa'));
    sv('awgs_rat_f', gs('awgs_rat')); sv('awgs_rto_f', gs('awgs_rto'));
    sv('awgs_rjt_f', gs('awgs_rjt')); sv('awgs_kat_f', gs('awgs_kat'));
    sv('awgs_mha_f', gs('awgs_mha'));
    // AmneziaWG 3.1 ('' | 'on' | 'off')
    sv('awgs_rt_f', gs('awgs_rt')); sv('awgs_dc_f', gs('awgs_dc'));
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
    awgsPeersSettle(awgsStatus);
    awgsPeersBanner();
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
// HeaderProtectionKey is 32 raw random bytes in base64 — the same shape as a PSK (no
// curve25519 clamping involved), which is why `awg genkey` output is also accepted.
// Generated in the browser like every other key on this page: it never transits the backend.
function genHpk(){
    // The 3.0 INPUTS were disabled when the gate is closed, but this button was not — and
    // setting .value on a disabled input works fine, so a user could still mint a key the
    // backend then refuses to emit. The result was a server running WITHOUT header protection
    // while every generated peer config demanded it (1.5.14). It also silently bumped S1-S4.
    if (awgs3Cap === false) { alert(T('AWG3_UNSUPPORTED')); return; }
    if (gv('awgs_hpk_f') && !confirm(T('MSG_REGEN_KEYS'))) return;
    loadQrLib(function(ok){
        if (!ok) { alert(T('QR_LIB_FAIL')); return; }
        sv('awgs_hpk_f', AWGKeys.genPsk());
        // Header protection takes its nonce from the first 12 bytes of each message's
        // S-padding, so the daemon refuses the config unless ALL FOUR S params are >= 12 —
        // S3 included, which this page did not even expose before. Raise anything short
        // instead of letting the user hit a rejection whose own error text is wrong
        // (upstream reports a 0-based index and says "8" while enforcing 12).
        var bumped = [];
        for (var n = 1; n <= 4; n++) {
            var id = 'awgs_s' + n + '_f';
            var cur = parseInt(gv(id), 10);
            if (!(cur >= 12)) {
                sv(id, String(Math.floor(Math.random() * 21) + 12)); // 12..32
                bumped.push('S' + n);
            }
        }
        if (bumped.length) alert(T('MSG_HPK_S_BUMPED').replace('%s', bumped.join(', ')));
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
          '<td width="16%"><input type="text" maxlength="24" value="' + escHtml(p.name) + '" onchange="peerEdit(' + i + ',\'name\',this.value,this)"></td>' +
          '<td width="12%" style="font-family:monospace; font-size:12px;">' + escHtml(p.ip) + '</td>' +
          '<td width="20%"><select onchange="peerEdit(' + i + ',\'policy\',this.value)">' + policyOptions(p.policy) + '</select>' +
              /* vpn_all ONLY (1.5.12): the bypass is a blanket mangle ACCEPT at PREROUTING
                 position 1, which terminates the chain before the mark that a GEO policy
                 depends on — ticking it on a geo peer sent it straight out of the WAN. The
                 stored flag is left alone so switching back to vpn_all restores the intent. */
              (p.policy === 'vpn_all' ? '<label style="display:block; font-size:10px; color:#b6bdc7; margin-top:3px; cursor:pointer;" title="' + escHtml(T('BYPASS_XRAY_TT')) + '"><input type="checkbox"' + (p.xbypass ? ' checked' : '') + ' onchange="peerEdit(' + i + ',\'xbypass\',this.checked)" style="vertical-align:middle;"> ' + escHtml(T('BYPASS_XRAY')) + '</label>' : '') +
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
function peerEdit(i, field, val, el){
    if (!awgsPeers[i]) return;
    if (field === 'name') {
        val = sanitizeName(val);
        if (el) el.value = val;   // show the name as it will be stored («My Phone» → «My_Phone»)
    }
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
        var d = awgsDnsList(gv('awgs_dnscustom_f'));   // same form as the stored list, even before «Apply»
        if (d) lines.push('DNS = ' + d);
    } else {
        lines.push('DNS = ' + routerTunnelIp());
    }
    var mtu = gv('awgs_mtu_f');
    if (mtu && mtu !== '1420') lines.push('MTU = ' + mtu);
    // S3/S4 are copied too: they used to be server-only, but Header protection (AWG 3.0)
    // derives its nonce from the S-padding of EVERY message type, so a peer whose S3/S4 differ
    // from the server's cannot talk to it at all.
    var fields = [['Jc', 'awgs_jc_f'], ['Jmin', 'awgs_jmin_f'], ['Jmax', 'awgs_jmax_f'],
                  ['S1', 'awgs_s1_f'], ['S2', 'awgs_s2_f'], ['S3', 'awgs_s3_f'], ['S4', 'awgs_s4_f'],
                  ['H1', 'awgs_h1_f'], ['H2', 'awgs_h2_f'], ['H3', 'awgs_h3_f'], ['H4', 'awgs_h4_f']];
    for (var i = 0; i < fields.length; i++) {
        var v = gv(fields[i][1]);
        if (v) lines.push(fields[i][0] + ' = ' + v);
    }
    for (var n = 1; n <= 5; n++) {
        var iv = gv('awgs_i' + n + '_f');
        if (iv) lines.push('I' + n + ' = ' + iv);
    }
    // AmneziaWG 3.0. HeaderProtectionKey is the one that MUST match; the rest are mirrored so
    // the peer behaves like the server the admin configured.
    // Gated on the CAPABILITY, not on "the fields are disabled hence empty" as this used to
    // assume (1.5.14): the fields are populated from saved settings on load — 1.5.7 promised
    // stored 3.0 values are never wiped — so with the gate closed the server emits no
    // HeaderProtectionKey while every peer config here would still demand one, and no peer
    // could connect. Emit them only when the build actually supports them.
    var awg3f = (awgs3Cap === false) ? [] :
                [['HeaderProtectionKey', 'awgs_hpk_f'], ['ContentPaddingAddition', 'awgs_cpa_f'],
                 ['RekeyAfterTime', 'awgs_rat_f'], ['RekeyTimeout', 'awgs_rto_f'],
                 ['RejectAfterTime', 'awgs_rjt_f'], ['KeepaliveTimeout', 'awgs_kat_f'],
                 ['MaxHandshakeAttempts', 'awgs_mha_f']];
    for (var a = 0; a < awg3f.length; a++) {
        var av = gv(awg3f[a][1]);
        if (av) lines.push(awg3f[a][0] + ' = ' + av);
    }
    // AmneziaWG 3.1. RandomTrailers is SYMMETRIC: a server with it on still ACCEPTS plain
    // handshakes, but every handshake IT sends (responses included) carries a random trailer,
    // which a peer WITHOUT the flag rejects — so "on" must ride into every peer config (and
    // demands an AmneziaWG 3.1+ client app). "off"/unset is deliberately NOT written: older
    // client apps abort the import on an unknown key, and absent == off anyway.
    // DisableCookies is a server-local policy (never send cookie replies) — mirroring it to
    // peers would buy nothing and cost the same compatibility, so it stays out.
    if (awgs31Cap !== false && gv('awgs_rt_f') === 'on') lines.push('RandomTrailers = on');
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

/* ---- live-store save pipeline (1.5.26; the client page's awgSave runs the same contract) ----
 * The firmware keeps EVERY addon's settings in one file (custom_settings.txt), and a POST of
 * amng_custom REPLACES that file whole, one "key value" line per JSON key in the posted order.
 * This page used to post the object it had loaded, so a save silently reverted whatever the
 * client page, another tab or SSH had changed since. A save now:
 *  1. reads the LIVE store — /user/awg_cs.htm, which the backend writes as a framed copy of the
 *     firmware's "< % get_custom_settings() % >" tag (falls back to re-reading this page);
 *  2. refuses as a conflict when a key this page OWNS (awgs_*) changed since the page loaded;
 *  3. posts every other key from the live store and ours from the page, plus a fresh save token
 *     as the LAST key — a write cut short by a full /jffs loses it, so it reads as not saved;
 *  4. reads the store back after the iframe load and reports what actually landed.
 * The firmware says nothing itself: an over-long POST is dropped whole with the event still
 * firing, and an expired session answers every request with a login redirect. */
var AWGS_CS_TOTAL_MAX = 8192;   // httpd: amng_custom is CKN_STR8192, larger = the save is discarded
var AWGS_CS_URL = '/user/awg_cs.htm';
var awgsCsSeq = 0, awgsTokSeq = 0;
// This page's keys. Everything else (the client's awg_*, the shared awg_save_tok, other addons)
// is taken from the live store on every save, never from this page's load-time copy.
function awgsOwned(k){ return /^awgs_/.test(k); }
function awgsCopy(o){
    var c = {}, k;
    for (k in o) { if (o.hasOwnProperty(k)) c[k] = o[k]; }
    return c;
}
function awgsUtf8Len(s){
    s = String(s == null ? '' : s);
    try { return unescape(encodeURIComponent(s)).length; } catch(e){ return s.length * 3; }
}
// Split into pieces of at most `max` UTF-8 bytes, never inside a character (surrogate pairs
// included). Used for the byte-capped chunks and for the reader's 2999-byte cut.
function awgsSplitBytes(s, max){
    var out = [], start = 0, bytes = 0, i = 0, c, d, w, n;
    s = String(s);
    while (i < s.length) {
        c = s.charCodeAt(i); n = 1;
        if (c < 0x80) w = 1;
        else if (c < 0x800) w = 2;
        else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length &&
                 (d = s.charCodeAt(i + 1)) >= 0xDC00 && d <= 0xDFFF) { w = 4; n = 2; }
        else w = 3;
        if (bytes + w > max && i > start) { out.push(s.substring(start, i)); start = i; bytes = 0; }
        bytes += w; i += n;
    }
    out.push(s.substring(start));
    return out;
}
// The firmware reader's view of a stored value: ej_get_custom_settings parses each line with
// sscanf("%29s%*[ ]%2999s"), so leading blanks are skipped, the value ends at its first
// whitespace and at 2999 bytes, and a line whose value is empty (or starts with a newline) is
// not emitted at all. undefined = ABSENT. Every comparison against a read-back goes through
// this, so a value the firmware itself cut never reads as "changed by somebody else".
function awgsNorm(v){
    if (v === undefined || v === null) return undefined;
    var s = String(v).replace(/^[ \t\v\f\r]+/, '');
    if (s === '' || s.charAt(0) === '\n') return undefined;
    var m = /[ \t\n\v\f\r]/.exec(s);
    if (m) s = s.substring(0, m.index);
    if (awgsUtf8Len(s) > 2999) s = awgsSplitBytes(s, 2999)[0];
    return s === '' ? undefined : s;
}
// Classify one response body (fixed order): the framed endpoint → a store; else this page as
// rendered by httpd, found by its own settings line — the pattern is built by concatenation so
// it can never match the source text of this very function; else a login redirect, only for a
// SHORT body (the page carries the pattern too, and the literal is split for the same reason:
// the whole page must never contain it contiguously); else unusable.
var AWGS_CS_PAGE_RE = new RegExp('var custom' + '_settings =\\s*(\\{|new Object\\(\\))');
var AWGS_CS_LOGIN_RE = new RegExp('top\\.location\\.href\\s*=\\s*[\'"]/Main_' + 'Login\\.asp');
function awgsCsObj(txt){
    var o = null;
    try { o = JSON.parse(txt); } catch(e){}
    if (o && typeof o === 'object' && !(o instanceof Array)) return { kind: 'store', obj: o };
    return { kind: 'unusable' };
}
function awgsCsClassify(body){
    body = String(body == null ? '' : body);
    var t = body.replace(/^\s+|\s+$/g, ''), m, mid;
    if (t.length >= 10 && t.substr(0, 5) === 'AWGCS' && t.substr(t.length - 5) === 'AWGCS') {
        mid = t.substring(5, t.length - 5).replace(/^\s+|\s+$/g, '');
        // The firmware's own "no settings file yet" answer.
        return (mid === 'new Object()') ? { kind: 'store', obj: {} } : awgsCsObj(mid);
    }
    if ((m = AWGS_CS_PAGE_RE.exec(body))) {
        if (m[1] !== '{') return { kind: 'store', obj: {} };
        // String/escape-aware brace scan from that '{' to its matching '}'.
        var i = m.index + m[0].length - 1, depth = 0, inStr = false, esc = false, j, c;
        for (j = i; j < body.length; j++) {
            c = body.charAt(j);
            if (inStr) {
                if (esc) esc = false;
                else if (c === '\\') esc = true;
                else if (c === '"') inStr = false;
            } else if (c === '"') inStr = true;
            else if (c === '{') depth++;
            else if (c === '}' && --depth === 0) return awgsCsObj(body.substring(i, j + 1));
        }
        return { kind: 'unusable' };
    }
    if (body.length < 512 && AWGS_CS_LOGIN_RE.test(body)) return { kind: 'login' };
    return { kind: 'unusable' };
}
// One GET → cb({kind:'store'|'login'|'unusable'|'timeout', obj}). The cache buster is unique
// per REQUEST (never per page load, never the save token): on 3006.102+ httpd sends .htm files
// with an ETag and no Cache-Control, so a repeated URL may be answered from the browser cache —
// awg_cs.htm's FILE never changes, only what httpd renders from it does.
function awgsCsGet(url, ms, cb){
    var x, fired = false;
    function fin(r){ if (!fired) { fired = true; cb(r); } }
    try {
        x = new XMLHttpRequest();
        x.open('GET', url + (url.indexOf('?') === -1 ? '?' : '&') + '_=' + Date.now() + '_' + (++awgsCsSeq), true);
        x.timeout = ms;
        x.onload = function(){ fin(x.status ? awgsCsClassify(x.responseText) : { kind: 'timeout' }); };
        x.onerror = x.ontimeout = x.onabort = function(){ fin({ kind: 'timeout' }); };
        x.send();
    } catch(e){ fin({ kind: 'timeout' }); }
}
// The pre-save read → cb(kind, live, url): 'store'; 'legacy' when neither the endpoint nor the
// page itself yields a store (no framed endpoint on this install: save the old way, unverified);
// 'login'; or 'busy' when only timeouts came back within 25 s — rc runs our service-event
// handlers in the foreground for up to two minutes and httpd queues behind them.
function awgsCsPrefetch(cb){
    var t0 = Date.now(), urls = [AWGS_CS_URL, location.pathname], u = 0;
    function attempt(){
        var left = 25000 - (Date.now() - t0);
        if (left <= 0) { cb('busy'); return; }
        awgsCsGet(urls[u], Math.min(6000, left), function(r){
            if (r.kind === 'store') { cb('store', r.obj, urls[u]); return; }
            if (r.kind === 'login') { cb('login'); return; }
            if (r.kind === 'unusable') {
                if (++u >= urls.length) { cb('legacy'); return; }
                attempt();
                return;
            }
            setTimeout(attempt, 1000);   // timeout / status 0: the same URL again, within the budget
        });
    }
    attempt();
}
// The read-back after the submit: up to 3 attempts of 20 s, 1.5 s apart → cb(store or null).
function awgsCsVerify(url, cb){
    var n = 0;
    function attempt(){
        awgsCsGet(url, 20000, function(r){
            if (r.kind === 'store') { cb(r.obj); return; }
            if (++n >= 3) { cb(null); return; }
            setTimeout(attempt, 1500);
        });
    }
    attempt();
}
// What gets posted: the store's own keys in the store's order (so the file barely moves) — ours
// from the page, everyone else's from the live store — then our new keys. Our values are trimmed
// and '' dropped: the reader never returns an empty value, and a blank would only eat budget.
function awgsBuildFinal(src, mine){
    var f = {}, k, v;
    if (src) {
        for (k in src) {
            if (!src.hasOwnProperty(k)) continue;
            if (!awgsOwned(k)) f[k] = src[k];
            else if (mine.hasOwnProperty(k)) f[k] = mine[k];
        }
    }
    for (k in mine) {
        if (mine.hasOwnProperty(k) && !f.hasOwnProperty(k) && (!src || awgsOwned(k))) f[k] = mine[k];
    }
    for (k in f) {
        if (!f.hasOwnProperty(k) || !awgsOwned(k)) continue;
        v = String(f[k]).replace(/^\s+|\s+$/g, '');
        if (v === '') delete f[k]; else f[k] = v;
    }
    return f;
}
function awgsKeysOf(){
    var seen = {}, out = [], a, k;
    for (a = 0; a < arguments.length; a++) {
        for (k in arguments[a]) {
            if (arguments[a].hasOwnProperty(k) && !seen.hasOwnProperty(k)) { seen[k] = 1; out.push(k); }
        }
    }
    return out;
}
// Does any key we own differ between the two stores? (the reader's view on both sides)
function awgsOwnedDiffer(a, b){
    var ks = awgsKeysOf(a, b), i;
    for (i = 0; i < ks.length; i++) {
        if (awgsOwned(ks[i]) && awgsNorm(a[ks[i]]) !== awgsNorm(b[ks[i]])) return true;
    }
    return false;
}
// Classify the read-back. A store without any token whose keys are a strict in-order prefix of
// what we posted is a write cut short (the file is written in posted order and the token is
// last) — unless it is simply the untouched old store (the very first save, before any page set
// a token), which is a discard. Not so for a retry after a cut write (`retried`): there the old
// store is itself the cut one, and reading it back unchanged means /jffs is still full.
function awgsSaveOutcome(live2, tok, live, fin, late, retried){
    if (!live2) return 'unverified';
    if (live2.awg_save_tok === tok) return late ? 'verified-late' : 'verified';
    if (!live2.hasOwnProperty('awg_save_tok')) {
        var ka = awgsKeysOf(live2), kb = awgsKeysOf(live), i, same = (ka.length === kb.length);
        for (i = 0; same && i < ka.length; i++) same = (ka[i] === kb[i] && awgsNorm(live2[ka[i]]) === awgsNorm(live[ka[i]]));
        if (same && !retried && !live.hasOwnProperty('awg_save_tok')) return 'discarded';
        var vis = [], kf = awgsKeysOf(fin);
        for (i = 0; i < kf.length; i++) {
            if (kf[i].length <= 29 && awgsNorm(fin[kf[i]]) !== undefined) vis.push(kf[i]);
        }
        var prefix = (ka.length < vis.length);
        for (i = 0; prefix && i < ka.length; i++) prefix = (ka[i] === vis[i]);
        if (prefix) return 'truncated';
        if (!live.hasOwnProperty('awg_save_tok')) return 'unknown';   // changed, but not by us
    }
    return (live2.awg_save_tok === live.awg_save_tok) ? 'discarded' : 'unknown';
}
// Save the page's model (custom_settings, frozen HERE) through the live store.
// opts: action (service event), button (shows «Проверка…» while the store is read), onSubmit().
// cb(result, info) runs after the form lock is released and MUST handle every result:
//   verified | verified-late (the router was busy: the event may have been dropped) | unverified
//   | unknown | truncated | discarded | conflict | busy | login | overflow (info.total).
// Nothing is posted for conflict / busy / login / overflow.
function awgsSave(opts, cb){
    var mine = awgsCopy(custom_settings);
    awgsSaveBusy = true;
    if (opts.button) { opts.button.value = T('BTN_CHECKING'); opts.button.disabled = true; }
    function done(res, info){ awgsSaveBusy = false; cb(res, info || {}); }
    awgsCsPrefetch(function(kind, live, url){
        if (kind === 'login' || kind === 'busy') { done(kind); return; }
        var legacy = (kind === 'legacy'), retained = legacy ? null : awgsCsRetained;
        // A write cut short last time left `retained` (the full store as it was before): take
        // everyone else's keys from it once more instead of from the cut live store, and skip the
        // conflict check — the cut store is expected to differ.
        if (!legacy && !retained && (awgsCsStale || awgsOwnedDiffer(live, awgsCsBase))) { done('conflict'); return; }
        var fin = awgsBuildFinal(legacy ? null : (retained || live), mine);
        var tok = Date.now().toString(36) + (++awgsTokSeq).toString(36);
        delete fin.awg_save_tok;
        fin.awg_save_tok = tok;          // LAST: a partial write loses it
        var json = JSON.stringify(fin), total = awgsUtf8Len(json);
        if (total > AWGS_CS_TOTAL_MAX) { done('overflow', { total: total }); return; }
        if (retained) awgsCsRetained = null;
        document.getElementById('amng_custom').value = json;
        document.form.action_script.value = opts.action;
        if (opts.onSubmit) opts.onSubmit();
        // The load listener and the timer belong to THIS submit only. A load 10 s or more after
        // the submit (or none within 20 s) means httpd sat behind a busy rc: the store was
        // written, but notify_rc waited ~15 s and may have DROPPED our event.
        var frame = document.getElementById('hidden_frame'), t0 = Date.now(), settled = false, timer = null;
        function onLoad(){ arrived(false); }
        function arrived(timedOut){
            if (settled) return;
            settled = true;
            if (timer) clearTimeout(timer);
            if (frame && frame.removeEventListener) frame.removeEventListener('load', onLoad, false);
            var late = timedOut || (Date.now() - t0) >= 10000;
            if (legacy) { finish('unverified', null); return; }
            awgsCsVerify(url, function(live2){ finish(awgsSaveOutcome(live2, tok, live, fin, late, !!retained), live2); });
        }
        function finish(res, live2){
            var k;
            if (res === 'verified' || res === 'verified-late' || res === 'unverified' || res === 'truncated') {
                // The baseline advances only to what THIS page wrote (our keys).
                for (k in awgsCsBase) { if (awgsCsBase.hasOwnProperty(k) && awgsOwned(k) && !fin.hasOwnProperty(k)) delete awgsCsBase[k]; }
                for (k in fin) {
                    if (!fin.hasOwnProperty(k) || !awgsOwned(k)) continue;
                    if (awgsNorm(fin[k]) === undefined) delete awgsCsBase[k]; else awgsCsBase[k] = awgsNorm(fin[k]);
                }
                // Our own key reads back different from what we wrote: somebody wrote in between.
                if (live2 && res !== 'truncated' && awgsOwnedDiffer(live2, fin)) awgsCsStale = true;
            }
            if (res === 'unknown') awgsCsStale = true;
            if (res === 'truncated') awgsCsRetained = retained || live;
            if (res !== 'discarded') {
                // The model now equals what was posted: our trimmed values, the dropped ones gone.
                for (k in custom_settings) { if (custom_settings.hasOwnProperty(k) && awgsOwned(k) && !fin.hasOwnProperty(k)) delete custom_settings[k]; }
                for (k in fin) { if (fin.hasOwnProperty(k) && awgsOwned(k)) custom_settings[k] = fin[k]; }
            }
            done(res);
        }
        if (frame && frame.addEventListener) frame.addEventListener('load', onLoad, false);
        timer = setTimeout(function(){ arrived(true); }, 20000);
        document.form.submit();
    });
}
function awgsSaveNote(txt){
    var el = document.getElementById('awgs_save_note');
    if (!el) return;
    el.textContent = txt || '';
    el.style.display = txt ? '' : 'none';
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
    if (awgsSaveBusy) return;
    // The peer list read back cut (loadPeers), 'space' / 'oversize': the file still holds the
    // full list and the backend repairs it within a minute, while saving now would persist the
    // cut and erase every peer after it — so refuse; the server keeps serving the stored list.
    if (awgsPeersCut && awgsPeersCutWhy !== 'lost') { alert(T('MSG_PEERS_CUT')); return; }
    if (!validateForm()) return;
    // 'lost': the damaged entries' data is gone from the file too, so refusing would lock every
    // server save forever. Saving drops them (loadPeers never put them into awgsPeers) — only
    // on an explicit yes that names them.
    var dropLost = awgsPeersCut;
    if (dropLost && !confirm(T('MSG_PEERS_LOST_CONFIRM', awgsPeersLost.join(', ')))) return;
    // The model before this save: every failure that posted nothing (or nothing that landed)
    // puts it back, so a refused value never rides along on a later save. The form keeps the
    // user's edits either way.
    var snap = awgsCopy(custom_settings), editSeq = awgsEditSeq;
    // The DNS list is normalized by TOKENS and stored comma-joined without whitespace: the
    // firmware reader cuts a value at its first whitespace, so «1.1.1.1, 8.8.8.8» (like the
    // placeholder) came back as "1.1.1.1," — and so did every peer config built after a reload.
    // Whitespace is a separator like the comma: deleting it glued «1.1.1.1 8.8.8.8» into one
    // invalid "1.1.1.18.8.8.8".
    var dnsList = awgsDnsList(gv('awgs_dnscustom_f'));
    sv('awgs_dnscustom_f', dnsList);
    ss('awgs_privkey', gv('awgs_priv_f'));
    ss('awgs_pubkey', gv('awgs_pub_f'));
    ss('awgs_port', gv('awgs_port_f'));
    ss('awgs_subnet', gv('awgs_subnet_f'));
    ss('awgs_mtu', gv('awgs_mtu_f'));
    ss('awgs_endpoint', gv('awgs_endpoint_f'));
    ss('awgs_dns_mode', document.getElementById('awgs_dnsmode_f').value);
    ss('awgs_dns_custom', dnsList);
    ss('awgs_nat_lan', gchk('awgs_natlan_f') ? '1' : '0');
    ss('awgs_autostart', gchk('awgs_autostart_f') ? '1' : '0');
    ss('awgs_jc', gv('awgs_jc_f')); ss('awgs_jmin', gv('awgs_jmin_f')); ss('awgs_jmax', gv('awgs_jmax_f'));
    ss('awgs_s1', gv('awgs_s1_f')); ss('awgs_s2', gv('awgs_s2_f'));
    ss('awgs_s3', gv('awgs_s3_f')); ss('awgs_s4', gv('awgs_s4_f'));
    ss('awgs_h1', gv('awgs_h1_f')); ss('awgs_h2', gv('awgs_h2_f'));
    ss('awgs_h3', gv('awgs_h3_f')); ss('awgs_h4', gv('awgs_h4_f'));
    // AmneziaWG 3.0
    ss('awgs_hpk', gv('awgs_hpk_f')); ss('awgs_cpa', gv('awgs_cpa_f'));
    ss('awgs_rat', gv('awgs_rat_f')); ss('awgs_rto', gv('awgs_rto_f'));
    ss('awgs_rjt', gv('awgs_rjt_f')); ss('awgs_kat', gv('awgs_kat_f'));
    ss('awgs_mha', gv('awgs_mha_f'));
    // AmneziaWG 3.1
    ss('awgs_rt', gv('awgs_rt_f')); ss('awgs_dc', gv('awgs_dc_f'));
    // I1-I5 -> chunked base64 text (ASCII-only, same as the client page)
    var itxt = '';
    for (var n = 1; n <= 5; n++) {
        var iv = gv('awgs_i' + n + '_f');
        if (iv) itxt += 'I' + n + ' = ' + iv + '\n';
    }
    if (itxt && /[^\x00-\x7F]/.test(itxt)) { awgsRestoreModel(snap); alert('I1-I5: ASCII only'); return; }
    setChunked('awgs_initdata', itxt ? btoa(itxt) : '', 30);
    setChunked('awgs_peers', serializePeers(), 10);

    // Whole-store size guard (inside awgsSave, on the object actually posted): httpd declares
    // amng_custom CKN_STR8192 — a JSON over 8192 bytes fails nvram_check and the WHOLE save is
    // discarded (syslog "nvram_check fail: nvram amng_custom over length"), while the service
    // event still fires. (The ~64 KB body cap this guard used to assume was wrong — 1.5.24.) The
    // budget is shared with the client's profiles and every other addon; peers (pub/priv/psk
    // each) plus chunked I1-I5 junk can reach it. Refused with a named cause, not a silent no-save.
    var btn = document.getElementById('btn_apply');
    awgsSaveNote('');
    awgsSave({
        action: 'start_awgsrvsave',
        button: btn,
        onSubmit: function(){
            btn.value = T('BTN_APPLYING');
            var u = document.getElementById('awgs_unsaved');
            if (u) u.style.display = 'none';
        }
    }, function(res, info){
        var u = document.getElementById('awgs_unsaved');
        if (res === 'verified' || res === 'verified-late' || res === 'unverified' || res === 'unknown') {
            // Saved (or as good as we can tell). An edit made while the save was in flight was
            // not part of it and stays marked.
            if (awgsEditSeq === editSeq) { awgsDirty = false; if (u) u.style.display = 'none'; }
            else if (u) u.style.display = '';
            // The confirmed 'lost' save wrote the list without the damaged entries: nothing
            // is cut any more.
            if (dropLost) {
                awgsPeersCut = false; awgsPeersCutWhy = ''; awgsPeersLost = []; awgsPeersPending = false;
                awgsPeersBanner();
            }
            btn.value = T('ACK_SAVED');
            awgsSaveNote(res === 'verified-late' ? T('ACK_SAVED_BUSY') : '');
            setTimeout(function(){ if (!awgsSaveBusy) { btn.value = T('BTN_APPLY'); btn.disabled = false; } refreshStatus(); }, 1600);
            if (res === 'unknown') alert(T('MSG_CS_UNKNOWN'));
            return;
        }
        // Not saved. A write cut short keeps the model (the next «Apply» re-posts everything);
        // every other outcome puts the model back as it was before this save.
        if (res !== 'truncated') awgsRestoreModel(snap);
        btn.value = T('BTN_APPLY'); btn.disabled = false;
        awgsDirty = true;
        if (u) u.style.display = '';
        if (res === 'overflow') alert(T('MSG_SETTINGS_TOO_BIG', info.total, AWGS_CS_TOTAL_MAX));
        else if (res === 'conflict') { if (confirm(T('MSG_CS_CONFLICT'))) location.reload(); }
        else if (res === 'busy') alert(T('MSG_ROUTER_BUSY'));
        else if (res === 'login') alert(T('MSG_SESSION_EXPIRED'));
        else if (res === 'discarded') alert(T('MSG_SAVE_DISCARDED') + ' ' + T('MSG_SAVE_DISCARDED_SRV'));
        else if (res === 'truncated') alert(T('MSG_STORE_TRUNCATED'));
    });
}
function awgsRestoreModel(snap){
    var k;
    for (k in custom_settings) { if (custom_settings.hasOwnProperty(k)) delete custom_settings[k]; }
    for (k in snap) { if (snap.hasOwnProperty(k)) custom_settings[k] = snap[k]; }
}

/* ---- start/stop/restart with transitional UI (no buttons during transitions) ---- */
function srvAction(action){
    // One shared form + iframe: submitting now would cancel the in-flight save's iframe load and
    // race its awgsrvsave event in rc (where one of the two gets dropped).
    if (awgsSaveBusy) { alert(T('MSG_WAIT_SAVE')); return; }
    if (awgsDirty && action === 'start_awgsrvstart') { alert(T('MSG_NEED_SAVE')); return; }
    // Start/stop/restart carry NO settings, so clear the hidden field instead of posting a
    // snapshot (1.5.13 — the client page's awgAction was fixed the same way in 1.4.0).
    // `custom_settings` is the object captured when THIS page loaded; re-posting it makes the
    // firmware write the whole thing back, silently reverting anything changed since — by the
    // client page in another tab, or by the CLI. Both roles share one custom_settings file, so
    // pressing «Запустить сервер» could undo a client profile switch. Empty = write nothing.
    var ac = document.getElementById('amng_custom');
    if (ac) ac.value = '';
    document.form.action_script.value = action;
    document.form.submit();
    var kind = action.indexOf('stop') !== -1 ? 'stop' : (action.indexOf('restart') !== -1 ? 'restart' : 'start');
    enterTransition(kind);
}
// Restart the steady 4 s poll after a transition resolves. Suspending it for the duration is
// what the client page does (and documents): without that, the steady poll keeps firing DURING
// the transition, and renderStatus() repaints «Остановлен» plus a live Start button over the
// «Запуск…» badge — a restart is stop-then-start, so there is always a moment where the backend
// honestly reports fully stopped. The generation token alone does not help here: it only
// discards reads that were already IN FLIGHT when the action began, not the ones the interval
// starts afterwards. (1.5.14; the client page fixed the same class in 1.2.13.)
function resumeSteadyPoll(){
    if (statusTimer) clearInterval(statusTimer);
    statusTimer = setInterval(refreshStatus, 4000);
}
function enterTransition(kind){
    awgsActionGen++;
    if (statusTimer) { clearInterval(statusTimer); statusTimer = null; }
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
                resumeSteadyPoll();
            } else if (attempts > 40) {
                clearInterval(poll);
                if (st) renderStatus(st);
                resumeSteadyPoll();   // give up on the transition, but never leave the page unpolled
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
var awgsStatusMisses = 0;
function refreshStatus(){
    var myGen = awgsActionGen;
    fetchStatus(function(st){
        if (myGen !== awgsActionGen) return;   // an action started while this read was in flight
        if (st) { awgsStatusMisses = 0; renderStatus(st); return; }
        // No status file at all (404/unparsable). /www/user is tmpfs: after a reboot the file
        // only reappears when the server starts or its status cron runs — with the server
        // stopped (or autostart never fired, e.g. the Entware init race) NOTHING writes it,
        // and the badge used to sit on «Загрузка…» forever. After 2 consecutive misses with
        // no real status ever seen, render a synthetic "stopped" so the page shows the
        // actionable Start button. A real status (or an in-flight action) always wins:
        // awg3 stays undefined => the 1.5.5 three-state logic keeps the 3.0 fields enabled.
        if (!awgsStatus && ++awgsStatusMisses >= 2)
            renderStatus({ running: false, starting: false, stopping: false, port: gs('awgs_port') || '51821' });
    });
}
// Mirrors applyAwg3Capability() on the client page: the AmneziaWG 3.0 fields are disabled
// unless the installed daemon + awg CLI actually parse them, because an older awg aborts the
// whole setconf on the first unknown key. Stored values are never cleared — they survive
// until the binaries catch up. Undefined => unsupported (fail closed).
var AWGS3_FIELDS = ['hpk','cpa','rat','rto','rjt','kat','mha'];
function applyAwg3CapabilitySrv(cap){
    // See applyAwg3Capability() on the client page. The server status is only written in full
    // by srv_update_status, which runs from the server's own cron — so on a router where the
    // server role was never configured the page used to read undefined and wrongly announce
    // "not supported by the installed binaries". Only an explicit false says that now.
    var known = (cap === true || cap === false);
    var ok = (cap !== false);
    awgs3Cap = known ? cap : null;
    var note = document.getElementById('awgs3_unsupported');
    if (note) note.style.display = (known && !ok) ? '' : 'none';
    for (var i = 0; i < AWGS3_FIELDS.length; i++) {
        var el = document.getElementById('awgs_' + AWGS3_FIELDS[i] + '_f');
        if (!el) continue;
        el.disabled = !ok;
        el.style.opacity = ok ? '' : '0.5';
    }
    // The Generate button too — disabling only the inputs left the one control that can still
    // WRITE into them fully live (1.5.14).
    var gb = document.getElementById('awgs_hpk_gen');
    if (gb) { gb.disabled = !ok; gb.style.opacity = ok ? '' : '0.5'; }
}
// The AmneziaWG 3.1 pair — same three-state contract, its own gate (a 3.0-capable pair keeps
// the seven fields above live while these two stay disabled).
var AWGS31_FIELDS = ['rt','dc'];
function applyAwg31CapabilitySrv(cap){
    var known = (cap === true || cap === false);
    var ok = (cap !== false);
    awgs31Cap = known ? cap : null;
    var note = document.getElementById('awgs31_unsupported');
    if (note) note.style.display = (known && !ok) ? '' : 'none';
    for (var i = 0; i < AWGS31_FIELDS.length; i++) {
        var el = document.getElementById('awgs_' + AWGS31_FIELDS[i] + '_f');
        if (!el) continue;
        el.disabled = !ok;
        el.style.opacity = ok ? '' : '0.5';
    }
}
function renderStatus(st){
    awgsStatus = st;
    awgsPeersSettle(st);
    applyAwg3CapabilitySrv(st.awg3);
    applyAwg31CapabilitySrv(st.awg31);
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
    // Since 1.5.12 «bypass Xray» exists for vpn_all peers only (a geo peer needs the packet mark
    // the bypass would skip), so a geo peer is its own bucket: it can never satisfy the red
    // banner by ticking a box, and telling it to would be advice that breaks its routing.
    var vpnNoBypass = false, vpnBypass = false, anyDirect = false, geoNoBypass = false;
    for (var i = 0; i < awgsPeers.length; i++) {
        var pp = awgsPeers[i];
        if (!pp.enabled) continue;
        if (pp.policy === 'vpn_all') { if (pp.xbypass) vpnBypass = true; else vpnNoBypass = true; }
        else if (pp.policy && pp.policy !== 'direct') geoNoBypass = true;
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
    var wantsTunnel = vpnBypass || ((vpnNoBypass || geoNoBypass) && (!st.xray_capture || uncov));
    showBanner('awgs_ban_client', st.running && wantsTunnel && !st.client_running, T('BAN_CLIENT_DOWN'));
    // Xray coexistence banner (verified live on a box running XRAYUI):
    //  - RED: some vpn peer has NO «bypass Xray» while Xray captures → its double hop doesn't
    //    happen (Xray grabs it first). Banner offers the fix (tick bypass / Direct / stop Xray).
    //  - YELLOW info: Xray captures and there are Direct peers (they flow through Xray) with no
    //    red case. Both suppressed while uncovered — the coverage banner is the story then. A
    //    box with only «bypass Xray» peers gets no banner (they're all in the client tunnel).
    //  - A GEO-policy peer also loses its double hop under Xray, but «bypass Xray» is NOT the
    //    fix for it (1.5.12) — so it turns the banner red too and gets its own sentence.
    var redPolicy = st.xray_capture && !uncov && (vpnNoBypass || geoNoBypass);
    var xb = document.getElementById('awgs_ban_xray');
    if (xb) xb.className = 'awg-banner ' + (redPolicy ? 'red' : 'yellow');
    var xrayHtml = T(redPolicy ? 'BAN_XRAY_POLICY' : 'BAN_XRAY_INFO')
                 + (redPolicy && geoNoBypass ? T('BAN_XRAY_GEO') : '');
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
    if (awgsSaveBusy) { alert(T('MSG_WAIT_SAVE')); return; }   // same shared form as srvAction
    if (!confirm(T('XRAY_STOP_CONFIRM'))) return;
    awgsXrayStopping = true;
    if (btn) { btn.disabled = true; btn.value = T('XRAY_STOPPING'); }
    // Same as srvAction: a plain action, no settings — and this one is reachable straight from
    // the banner we tell the user to click, so it must not revert their settings behind them.
    var acx = document.getElementById('amng_custom');
    if (acx) acx.value = '';
    document.form.action_script.value = 'start_awgxraystop';
    document.form.submit();
    setTimeout(function(){ awgsXrayStopping = false; refreshStatus(); }, 6000);
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
                <div id="awgs_ban_peers" class="awg-banner red" style="display:none;"></div>
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
                    <th width="30%">Jc / Jmin / Jmax<span class="awg-ver">AWG 1.0</span></th>
                    <td>
                        <input type="text" id="awgs_jc_f" class="input_6_table" maxlength="4" onchange="markDirty();">
                        <input type="text" id="awgs_jmin_f" class="input_6_table" maxlength="5" onchange="markDirty();">
                        <input type="text" id="awgs_jmax_f" class="input_6_table" maxlength="5" onchange="markDirty();">
                        <input type="button" class="button_gen awg-mini" value="Generate random" data-i18n-val="BTN_GEN_OBFS" onclick="genObfs();">
                    </td>
                </tr>
                <tr>
                    <th>S1 / S2<span class="awg-ver">AWG 1.0</span> / S3 / S4<span class="awg-ver">AWG 1.5</span></th>
                    <td>
                        <input type="text" id="awgs_s1_f" class="input_6_table" maxlength="4" placeholder="S1" onchange="markDirty();">
                        <input type="text" id="awgs_s2_f" class="input_6_table" maxlength="4" placeholder="S2" onchange="markDirty();">
                        <input type="text" id="awgs_s3_f" class="input_6_table" maxlength="4" placeholder="S3" onchange="markDirty();">
                        <input type="text" id="awgs_s4_f" class="input_6_table" maxlength="4" placeholder="S4" onchange="markDirty();">
                        <div class="awg-hint" data-i18n="HINT_S_ALL">S3/S4 are optional for AWG 2.0, but Header protection (AWG 3.0) needs all four ≥ 12.</div>
                    </td>
                </tr>
                <tr>
                    <th>H1–H4<span class="awg-ver">AWG 1.0</span></th>
                    <td>
                        <input type="text" id="awgs_h1_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H1" onchange="markDirty();">
                        <input type="text" id="awgs_h2_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H2" onchange="markDirty();">
                        <input type="text" id="awgs_h3_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H3" onchange="markDirty();">
                        <input type="text" id="awgs_h4_f" class="input_12_table" style="width:46%; margin:2px 1%; font-family:monospace; box-sizing:border-box;" maxlength="21" placeholder="H4" onchange="markDirty();">
                    </td>
                </tr>
                <tr>
                    <th><span data-i18n="LBL_IPARAMS">I1–I5 (advanced)</span><span class="awg-ver">AWG 1.5</span></th>
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

                <!-- AmneziaWG 3.0 -->
                <div class="awg-section" data-i18n="SEC_AWG3">AmneziaWG 3.0 — peers need a 3.0-capable client</div>
                <div id="awgs3_unsupported" class="awg-hint" style="display:none; margin:0 0 6px 5px; padding:6px 10px; border:1px solid #7a6a3a; background:#4a4230; border-radius:3px; color:#e8dfc8;"
                     data-i18n="AWG3_UNSUPPORTED">AmneziaWG 3.0 parameters are not supported by the installed binaries — the fields below are disabled.</div>
                <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
                <tr>
                    <th width="30%">HeaderProtectionKey</th>
                    <td>
                        <input type="text" id="awgs_hpk_f" class="input_32_table" style="width:70%; font-family:monospace;" maxlength="44" placeholder="(optional)" onchange="markDirty();">
                        <input type="button" id="awgs_hpk_gen" class="button_gen awg-mini" value="Generate" data-i18n-val="BTN_GENERATE" onclick="genHpk();">
                        <div class="awg-hint" data-i18n="HINT_AWG3_HPK_SRV">Written into every peer config and QR code — server and clients must share it. Requires S1–S4 ≥ 12.</div>
                    </td>
                </tr>
                <tr>
                    <th>ContentPaddingAddition</th>
                    <td><input type="text" id="awgs_cpa_f" class="input_6_table" maxlength="21" placeholder="10-40" onchange="markDirty();">
                        <div class="awg-hint" data-i18n="HINT_AWG3_CPA">A single number or a "lo-hi" range: extra bytes per data packet. A padded packet never exceeds the largest one sent since the peer's last reply (500 B minimum), so the biggest packets go unpadded.</div></td>
                </tr>
                <tr>
                    <th>RekeyAfterTime / RekeyTimeout</th>
                    <td>
                        <input type="text" id="awgs_rat_f" class="input_6_table" maxlength="21" placeholder="120" onchange="markDirty();">
                        <input type="text" id="awgs_rto_f" class="input_6_table" maxlength="21" placeholder="5" onchange="markDirty();">
                        <div class="awg-hint" data-i18n="HINT_AWG3_REKEY">Seconds. Defaults 120 / 5.</div>
                    </td>
                </tr>
                <tr>
                    <th>RejectAfterTime / KeepaliveTimeout</th>
                    <td>
                        <input type="text" id="awgs_rjt_f" class="input_6_table" maxlength="21" placeholder="180" onchange="markDirty();">
                        <input type="text" id="awgs_kat_f" class="input_6_table" maxlength="21" placeholder="10" onchange="markDirty();">
                        <div class="awg-hint" data-i18n="HINT_AWG3_REJECT">Seconds. Defaults 180 / 10. RejectAfterTime must stay above RekeyAfterTime.</div>
                    </td>
                </tr>
                <tr>
                    <th>MaxHandshakeAttempts</th>
                    <td><input type="text" id="awgs_mha_f" class="input_6_table" maxlength="21" placeholder="18" onchange="markDirty();">
                        <div class="awg-hint" data-i18n="HINT_AWG3_MHA">Handshake retries before giving up. Default 18.</div></td>
                </tr>
                <tr>
                    <th>RandomTrailers <span style="opacity:.6; font-size:10px;">AWG 3.1</span></th>
                    <td><select id="awgs_rt_f" class="input_option" style="font-size:12px;" onchange="markDirty();">
                            <option value="" data-i18n="OPT_AWG31_UNSET">— (default: off)</option>
                            <option value="on">on</option>
                            <option value="off">off</option>
                        </select>
                        <div class="awg-hint" data-i18n="HINT_AWG31_RT_SRV">SYMMETRIC: "on" is written into every peer config/QR — peers need an AmneziaWG 3.1+ client app and must re-import after changing this, or the server's handshakes are dropped.</div></td>
                </tr>
                <tr>
                    <th>DisableCookies <span style="opacity:.6; font-size:10px;">AWG 3.1</span></th>
                    <td><select id="awgs_dc_f" class="input_option" style="font-size:12px;" onchange="markDirty();">
                            <option value="" data-i18n="OPT_AWG31_UNSET">— (default: off)</option>
                            <option value="on">on</option>
                            <option value="off">off</option>
                        </select>
                        <div class="awg-hint" data-i18n="HINT_AWG31_DC_SRV">Server-side only: never send cookie replies (a DPI-visible message). Not written into peer configs. Trade-off: no protection against a flood of valid handshakes — each costs the router an X25519 operation, so anyone holding a peer config (or replaying a captured handshake) can max out its CPU. Keep off unless DPI demands it.</div></td>
                </tr>
                </table>
                <div id="awgs31_unsupported" class="awg-hint" style="display:none; margin:6px 0 0 5px; padding:6px 10px; border:1px solid #7a6a3a; background:#4a4230; border-radius:3px; color:#e8dfc8;"
                     data-i18n="AWG31_UNSUPPORTED">AmneziaWG 3.1 parameters (RandomTrailers / DisableCookies) are not supported by the installed binaries — those two fields are disabled.</div>

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
                    <div id="awgs_save_note" class="awg-hint" style="display:none; color:#e8c46a;"></div>
                    <div class="awg-hint" data-i18n="MSG_APPLY_RESTART_HINT"></div>
                </div>

                <!-- Log -->
                <div class="awg-section" data-i18n="SEC_LOG">Log</div>
                <div id="awgs_log" class="awg-log"></div>

                <!-- Footer: copyright (DCRM) -->
                <div style="display:flex; align-items:center; flex-wrap:wrap; gap:2px 10px; font-size:11px; opacity:0.55; margin-top:8px;">
                    <span style="margin-left:auto; text-align:right;">
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
