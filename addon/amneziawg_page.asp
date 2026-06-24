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
    padding-left: 5px;   /* small left inset so headers don't hug the panel edge (aligns with the dividers) */
    font-size: 14px;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.awg-log {
    font-family: "Courier New", "Lucida Console", monospace;
    font-size: 12px;
    padding: 10px;
    height: 340px;
    min-height: 120px;
    resize: vertical;
    overflow-y: auto;
    border: 1px solid #444;
    border-radius: 3px;
    white-space: pre-wrap;
    word-wrap: break-word;
}

.awg-btn { margin: 0 4px; }

/* Field help text. #666 was near-invisible on the dark ROG theme; use a readable light
   gray (still secondary vs the white labels). code = the inline format/example sample. */
.awg-hint {
    color: #b6bdc7;
    font-size: 11px;
    line-height: 1.5;
    margin-top: 4px;
}
.awg-hint code, .awg-hint b { color: #d7dce3; }
.awg-hint code {
    font-family: "Courier New", "Lucida Console", monospace;
    background: rgba(255,255,255,0.07);
    padding: 1px 5px;
    border-radius: 3px;
}

/* Embedded disc font used to mask the WG key fields (see .awg-dotted below). Every glyph in
   this font renders as a filled disc, so it masks the value in ALL browsers — including
   Firefox, which ignores -webkit-text-security. We rely on the font ALONE (no
   -webkit-text-security) because WebKit treats any text-security field as a password and
   would keep offering to save it. The font is inlined below so it can never fail to load. */
@font-face {
    font-family: 'awg-disc';
    src: url(data:font/woff2;base64,d09GMgABAAAAAAjoAAsAAAAAMGgAAAidAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHFQGVgDWYgpQdQE2AiQDCAsGAAQgBYUOBy4bvi8lYxtWw7BxAPB87x5FmeAMlf3/96RzDN74RcXUcjTKmrJ3T2VDSShiPhfiIJxxS7DiLkHFfQV33CM4427mAred74pWur/J3dyVsKy7coREA8fzvPvpfUk+tB3R8YTCzE0SCLepejmJ2u1yqp+kC7W4Rc/tDTs3GpNJ8ttRPOSTPhsXlwbi4kVYWQmAcXmlrqYHMMsBwP/zHMz7fkF1gijOKuFQIxjwlGa2lkARhYaBxFHT54IOgBMQADi3LipIMAA3geO41EUkBTCO2gkxnOwnKYBx1E6p5WS+QUCMq50rNch6MwUCAAiAcdgttYVSIfPJ5kn6ApRFQ6I88BxLvvIC/maHUHS3TIoKiwLbbM8nEFWgE1oDz3woSxpagWbBXcQWhKtPeIlg6tK+7vX57QOszwU3sGUJrA7h2Mx1IWCNr9BKxsYo+pzS/OCO0OG9mwBkx337+lcuSxRdBcc+fJxlcAjK/zCfdgtBzuxQcTqfY4Yn6EB/Az3JS/RMu5f6B8wrn55S0IxdlLn+4Yb/ctIT+ocWYPcGAOvxSjEjpSiVMqSgFWVjzpCCXjAIRirTABpEQ2gYjaBRNIbG0QSaRFNoGs2gWTSH5tECWkRLaBmtoFW0htbRBtpEW2gb7aBdtIf20QE6REdFDlkZEh2jE3SKztA5ukCX6Apdoxt0i+7QPXpAj+gJPaMX9Ire0Dv6QJ/oC/qKvqHv6Af6iX6h3+gP+ov+of+I+ECMxETMiDmxIJbEilgTG2JL7Ig9cSCOxIk4ExfiStyIO/EgnsSLeBMf4kv8iD/taQANoiE0jEbQKBpD42gCTaIpNI1m0CyaQ/NoAS2iJbSMVtAqWkPraANtoi20jXbQLtpD++gAHaIjdIxO0Ck6Q+foAl2iK3SNbtAtukP36AE9oif0jF7QK3pD79B79AF9RJ/QZ/QFfUXf0Hf0A/1Ev9Bv9Af9Rf/Qf9DQABpEQ2gYjaBRNIbG0QSaRFNoGs2gWTSH5tECWkRLaBmtoFW0htbRBtpEW2gb7aBdtIf20QE6REfoGJ2gU3SGztEFukRX6BrdoFt0h+7RA3pET+gZvaBX9Aa9Re/Qe/QBfUSf0Gf0BX1F39B39AP9RL/Qb/QH/UX/0P8l9vq9gXwDIUCliyAhRAgTIoQoIUaIExKEJCFFSBMyhCwhR8gTCoQioUQoEyqEKqFGqBMahCahRWgTOoQuoUfoEwaEIWFEGBMmhClhRpgTFoQlYUVYEzaELWFH2BMOhGPCCeGUcEY4J1wQLglXhGvCDeGWcEe4JzwQHglPhGfCC+GV8EZ4J3wQPglfhG/CD+GX8Ef4p9sdgoQQIUyIEKKEGCFOSBCShBQhTcgQsoQcIU8oEIqEEqFMqBCqhBqhTmgkNBGaCS2EVkIboZ3QQegkdBG6CT2EXkIfoZ8wQBgkDBGGCSOEUcIYYZwwQZgkTBGmCTOEWcIcYZ6wQFgkLBGWCSuEVcIaYZ2wQdgkbBG2CTuEXcIeYZ9wQDgkHBGOCSeEU8IZ4ZxwQbgkXBGuCTeEW8Id4Z7wQHgkPBGeCS+EV8Ib4Z3wQfgkfBG+CT+EX8If4Z8AZpAQIoQJEUKUECPECQlCkpAipAkZQpaQI+QJBUKRUCKUCRVClVAj1AkNQpPQIrQJHUKX0CP0CQPCkDAijAkTwpQwI8wJC8KSsCKsCRvClrAj7AkHwpFwIpwJF8IV4ZpwQ7gl3BHuCQ+ER8IT4ZnwQnglvBHeCR+ET8IX4ZvwQ/gl/BH+lzv+AmMkTYAmSBOiCdNEaKI0MZo4TYImSZOiSdNkaLI0OZo8TYGmSFOiKdNUaKo0NZo6TYOmSdOiadN0aLo0PZo+zYBmSDOiGdNMaKY0M5o5zYJmSbOiWdNsaLY0O5o9zYHmmOaE5pTmjOac5oLmkuaK5prmhuaW5o7mnuaB5pHmieaZ5oXmleaN5p3mg+aT5ovmm+aH5pfmj2ZRAqCCoEKgwqAioKKgYqDioBKgkqBSoNKgMqCyoHKg8qAKoIqgSqDKoCqgqqBqoOqgGkE1gWoG1QKqFVQbqHZQHaA6QXWB6gbVA6oXVB+oflADoAZBDYH+uxaEWDBiIYiFIhaGWDhiEYhFIhaFWDRiMYjFIhaHWDxiCYglIpaEWDJiKYilIpaGWDpiGYhlIpaFWDZiOYjlIpaHWD5iBYgVIlaEWDFiJYiVIlaGWDliFYhVIlaFWDViNYjVIlaHWD1iDYg1ItaEWDNiLYi1ItaGWDtiHYh1ItaFWDdiPYj1ItaHWD9iA4gNIjaE2DBiI4iNIjaG2DhiE4hNIjaF2DRiM4jNIjaH2DxiC4gtIraE2DJiK4itIraG2DpiG4htIraF2DZiO4jtIraH2D5iB4gdInaE2DFiJ4idInaG2DliF4hdInaF2DViN4jdInaH2D1iD4g9IvaE2DNiL4i9IvaG2DvE3iP2AbGPiH1C7DNiXxD7itg3xL4j9gOxn4j9Quw3Yn8Q+4vYP8T+M6cIDBz9EXfeUHR1JyygPL/++I3R1cRvdDr+E12Jfh3Q0EN/fHn2mXptpJxUkIqu/Cs2egM33OjSLcT33I82+B9nP37X/c0W52623s45CYCo03QIBCVrAFAycnSYSqvO4YJt/NP73YqA/giNZhJ6sBbmql+0SQZaxNOZudJbc2nqxNvpM+veq7Sz2LUgFEu+VLs+Ay3yp7MVertp6i23v2Rmv5gmHDhSQ6t5GmTaqTsqhpWwmbOk3uKJrNOmwSSMC17jghqygilDOUU3KlLmHHNrajw3DVNVGWytGZDisM/cbkdRnvfIUJkaGJlgAYcoQ5bGptTmGc1R7pBC3XhFsLXnXR54qrMc+dGNBkqE4laBi4KmZYGom8vIy0lTyBkppBjLoTndMmrofIRORirsNlCbXzCgulmo36KztS2iV8rrNoRUL5VdkMSGoSXroC1KOQAA) format('woff2');
}
/* Visually mask the WG key fields as discs using ONLY the embedded disc font (every glyph
   renders as a disc), in all browsers. We deliberately do NOT use -webkit-text-security:
   WebKit treats any field with text-security != none as a password-equivalent field and
   keeps offering "Save password?" no matter how neutral the id/class/name/aria-label are.
   A custom font is invisible to that heuristic, so the field masks identically while Safari
   no longer classifies it as a credential. type=text (not password) for the same reason.
   Placeholder uses a normal font so the hint stays readable. */
.awg-dotted {
    font-family: 'awg-disc', "Courier New", "Lucida Console", monospace;
}
.awg-dotted::placeholder {
    font-family: "Courier New", "Lucida Console", monospace;
}

#awg_peers_table { width: 100%; table-layout: fixed; }
/* Shared header style for both data tables. Headers are <td> (not <th>) so they pick up the
   firmware's gradient header background AND their width="%" attrs aren't overridden by the
   firmware's `.FormTable_table thead th { width:98px }` rule. */
#awg_peers_table thead td, #awg_client_table thead td {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.5px;
    text-align: center;
    white-space: nowrap;   /* keep headers on one line (both tables sit in a scrollable wrap) */
    padding: 6px 8px;   /* override firmware's asymmetric padding-left so centered text is truly centered */
}
#awg_peers_table tbody td {
    padding: 6px 8px;
    font-size: 12px;
    word-break: break-all;
    overflow-wrap: anywhere;
    text-align: center;
}

#awg_client_table { width: 100%; margin-top: 6px; }
#awg_client_table td { padding: 5px 8px; }
/* Actions column: analyze + remove buttons grouped and centered in a single cell. */
.awg-cell-actions { display: flex; justify-content: center; align-items: center; gap: 8px; }
/* Keep every control inside its fixed-width cell so nothing overflows and forces a scrollbar. */
#awg_client_table input, #awg_client_table select { box-sizing: border-box; width: 100%; max-width: 100%; min-width: 0; }
#awg_client_table .awg-remove-btn { max-width: 100%; box-sizing: border-box; }
.awg-remove-btn {
    display: inline-flex; align-items: center; justify-content: center;
    width: 24px; height: 24px; padding: 0;
    background: transparent; border: 1px solid #a00; color: #c00;
    border-radius: 4px; cursor: pointer; font-size: 16px; line-height: 1;
}
.awg-remove-btn:hover { background: #a00; color: #fff; }
/* Per-device traffic-analysis trigger: same footprint as the remove button, neutral blue. */
.awg-analyze-btn {
    display: inline-flex; align-items: center; justify-content: center;
    width: 24px; height: 24px; padding: 0;
    background: transparent; border: 1px solid #5db0ff; color: #5db0ff;
    border-radius: 4px; cursor: pointer; line-height: 1;
}
.awg-analyze-btn:hover { background: #5db0ff; color: #15202b; }
/* Verdict badges in the analysis table. Green = goes through the VPN, gray = direct. */
.awg-verdict { display:inline-block; padding:1px 7px; border-radius:10px; font-size:11px; font-weight:bold; white-space:nowrap; }
.awg-verdict.vpn  { background:#1a6e2e; color:#fff; }
.awg-verdict.geo  { background:#1a6e2e; color:#fff; }
.awg-verdict.direct { background:#444b52; color:#cfd6dd; }
.awg-verdict.pending { background:#5a4a1a; color:#f0d28a; }
/* Marks a row as a DNS resolve request (intent) vs an actual connection. */
.awg-dns-tag { display:inline-block; padding:0 5px; border-radius:3px; font-size:10px; font-weight:bold; background:#2d4a63; color:#9ec9ee; vertical-align:middle; }
/* Live analysis table layout. */
#awg_analyze_table { width:100%; border-collapse:collapse; font-size:12px; }
#awg_analyze_table th { text-align:left; padding:5px 8px; border-bottom:1px solid #444; color:#b6bdc7; font-size:11px; text-transform:uppercase; letter-spacing:0.5px; position:sticky; top:0; background:#2b3338; }
#awg_analyze_table td { padding:4px 8px; border-bottom:1px solid #353d43; vertical-align:top; word-break:break-all; }
#awg_analyze_table td.awg-an-mono { font-family:"Courier New","Lucida Console",monospace; color:#9aa3ad; white-space:nowrap; }
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

/* ---- UX pass: responsive / focus / hierarchy / utilities ---- */
/* Keep the desktop 760px look but never force horizontal scroll on phones. */
#FormTitle { width:760px; max-width:100%; box-sizing:border-box; }
#FormTitle table, #FormTitle input, #FormTitle select, #FormTitle textarea { max-width:100%; box-sizing:border-box; }
@media (max-width:480px){ #FormTitle { width:100%; } }

/* Visible keyboard focus (firmware stylesheets often strip outlines). */
:focus-visible { outline:2px solid #5db0ff; outline-offset:1px; }

/* Secondary source caption + wide inputs — kill inline drift. */
.awg-src { color:#b6bdc7; font-weight:normal; font-size:11px; }
.awg-input-wide { width:95%; }

/* Geo service-list / custom domain+IP / GeoCustom fields: multi-line + user-resizable.
   Inherits firmware input_32_table colours; the `textarea.` prefix outranks `.input_32_table`
   so our sizing wins regardless of firmware stylesheet order. */
textarea.awg-geo-ta {
    width:95%;
    height:auto;            /* let the `rows` attribute set the default height */
    min-height:48px;        /* never collapse below ~2 lines */
    resize:vertical;
    line-height:1.5;
    white-space:pre-wrap;
    word-break:break-word;
    vertical-align:top;
}

/* Horizontal-scroll wrapper for data grids on narrow screens. */
.awg-tablewrap { overflow-x:auto; -webkit-overflow-scrolling:touch; }

/* Status badge + buttons row: flex like the header cluster. */
.awg-actions { display:flex; align-items:center; flex-wrap:wrap; gap:8px; }

/* Collapsible <details> for Obfuscation + long hints (no JS). */
.awg-details > summary { cursor:pointer; }
.awg-details > summary::-webkit-details-marker, .awg-hint summary::-webkit-details-marker { color:#b6bdc7; }
.awg-hint summary { cursor:pointer; color:#d7dce3; }

/* Inline Apply ack + invalid-field highlight. */
.awg-ack { display:inline-block; margin-left:10px; font-size:12px; opacity:0; transition:opacity .2s; }
.awg-ack.show { opacity:1; }
.awg-ack.ok { color:#5bd75b; }
.awg-ack.err { color:#f0ad4e; }
.awg-invalid { border:1px solid #c00 !important; }

/* Modal inputs aligned to the page palette (was a separate color island). */
.awg-modal-input { padding:2px 6px; background:#1c2226; color:#e0e0e0; border:1px solid #5a6b70; border-radius:4px; }
/* DHCP picker: highlight the whole row when its checkbox is ticked. */
.awg-dhcp-row.sel { background: rgba(93,176,255,0.16); }
/* Geo-policy tabs — the strip's bottom border is the panel's top edge; the active tab
   "opens" into the panel (its bottom border = panel bg, overlapping the line by 1px), so the
   tab and panel read as one connected unit instead of floating. */
.awg-geo-tabs { display:flex; flex-wrap:wrap; align-items:flex-end; gap:3px; margin:10px 0 0; padding:0 2px; border-bottom:1px solid #5db0ff; }
.awg-geo-tab { display:inline-flex; align-items:center; gap:5px; padding:6px 11px; margin-bottom:-1px; background:#222a2e; color:#b6bdc7; border:1px solid #3a4548; border-bottom:none; border-radius:6px 6px 0 0; cursor:pointer; font-size:12px; line-height:1.4; }
.awg-geo-tab:hover { background:#2b3338; color:#e0e0e0; }
.awg-geo-tab.active { background:#2b3338; color:#fff; border-color:#5db0ff; border-bottom:1px solid #2b3338; font-weight:bold; }
.awg-geo-tab-name { white-space:nowrap; max-width:160px; overflow:hidden; text-overflow:ellipsis; }
.awg-geo-tab-edit, .awg-geo-tab-del { background:transparent; border:none; color:inherit; cursor:pointer; padding:0 2px; font-size:13px; line-height:1; opacity:0.7; }
.awg-geo-tab-edit:hover { opacity:1; color:#5db0ff; }
.awg-geo-tab-del:hover { opacity:1; color:#ff6b6b; }
.awg-geo-tab-add { background:transparent; border:1px dashed #5a6b70; color:#9aa3ad; border-radius:6px; cursor:pointer; padding:5px 10px; margin-bottom:3px; font-size:12px; }
.awg-geo-tab-add:hover { color:#5db0ff; border-color:#5db0ff; }
#geo_policy_panel { border:1px solid #5db0ff; border-top:none; border-radius:0 0 6px 6px; padding:4px 8px 8px; }

/* Checkboxes: the native white box contrasts hard against the dark ROG panels. Repaint them
   in the page palette (dark fill, themed border, accent-blue tick). Scoped to the addon's own
   containers so firmware-chrome checkboxes (left menu, etc.) are left untouched. */
#FormTitle input[type="checkbox"],
#awg_analyze_modal input[type="checkbox"],
#awg_dhcp_modal input[type="checkbox"]{
    -webkit-appearance:none; -moz-appearance:none; appearance:none;
    width:16px; height:16px; margin:0 5px 0 0; padding:0;
    vertical-align:-3px; box-sizing:border-box; flex:none;
    background:#1c2226; border:1px solid #5a6b70; border-radius:3px;
    cursor:pointer; position:relative;
}
#FormTitle input[type="checkbox"]:hover,
#awg_analyze_modal input[type="checkbox"]:hover,
#awg_dhcp_modal input[type="checkbox"]:hover{ border-color:#5db0ff; }
#FormTitle input[type="checkbox"]:checked,
#awg_analyze_modal input[type="checkbox"]:checked,
#awg_dhcp_modal input[type="checkbox"]:checked,
#FormTitle input[type="checkbox"]:indeterminate,
#awg_analyze_modal input[type="checkbox"]:indeterminate,
#awg_dhcp_modal input[type="checkbox"]:indeterminate{ background:#5db0ff; border-color:#5db0ff; }
/* Checkmark (rotated border) for the checked state. */
#FormTitle input[type="checkbox"]:checked::after,
#awg_analyze_modal input[type="checkbox"]:checked::after,
#awg_dhcp_modal input[type="checkbox"]:checked::after{
    content:""; position:absolute; left:4px; top:1px;
    width:4px; height:8px; border:solid #15202b; border-width:0 2px 2px 0;
    transform:rotate(45deg);
}
/* Dash for the indeterminate (partial select-all) state. */
#FormTitle input[type="checkbox"]:indeterminate::after,
#awg_analyze_modal input[type="checkbox"]:indeterminate::after,
#awg_dhcp_modal input[type="checkbox"]:indeterminate::after{
    content:""; position:absolute; left:3px; top:6px; width:8px; height:0;
    border-top:2px solid #15202b;
}
#FormTitle input[type="checkbox"]:disabled,
#awg_analyze_modal input[type="checkbox"]:disabled,
#awg_dhcp_modal input[type="checkbox"]:disabled{ opacity:0.5; cursor:default; }
/* The firmware's form_style.css paints EVERY <span> inside a .FormTable cell gold (#FFCC00) —
   a stock-page default that turned our plain form labels (Antifilter RKN lists, auto-update,
   kill-switch, geo-policy mode toggle, «download via VPN», …) an unwanted yellow. Override it
   at the firmware's own selector (`td span`) scoped to #FormTitle so we beat it on specificity
   and match exactly the same cells — no dependency on the <label> nesting (an earlier
   `label span` rule missed the mode-toggle / download-via-VPN labels). Spans that need a colour
   set it inline (green «recommended», amber warnings, grey captions) and still win; .awg-hint /
   the section captions live in <th> or <div>, so they're untouched. */
#FormTitle .FormTable td span,
#FormTitle .FormTable_table td span { color:#e8edf2; }
/* Radio buttons: same dark treatment as the checkboxes (the geo-policy mode toggle was still
   rendering as native white circles). Round, dark fill, themed border; blue fill + dark dot
   when selected — mirrors the checked checkbox. */
#FormTitle input[type="radio"],
#awg_analyze_modal input[type="radio"],
#awg_dhcp_modal input[type="radio"]{
    -webkit-appearance:none; -moz-appearance:none; appearance:none;
    width:16px; height:16px; margin:0 5px 0 0; padding:0;
    vertical-align:-3px; box-sizing:border-box; flex:none;
    background:#1c2226; border:1px solid #5a6b70; border-radius:50%;
    cursor:pointer; position:relative;
}
#FormTitle input[type="radio"]:hover,
#awg_analyze_modal input[type="radio"]:hover,
#awg_dhcp_modal input[type="radio"]:hover{ border-color:#5db0ff; }
#FormTitle input[type="radio"]:checked,
#awg_analyze_modal input[type="radio"]:checked,
#awg_dhcp_modal input[type="radio"]:checked{ background:#5db0ff; border-color:#5db0ff; }
#FormTitle input[type="radio"]:checked::after,
#awg_analyze_modal input[type="radio"]:checked::after,
#awg_dhcp_modal input[type="radio"]:checked::after{
    content:""; position:absolute; left:50%; top:50%;
    width:6px; height:6px; border-radius:50%; background:#15202b;
    transform:translate(-50%,-50%);
}
#FormTitle input[type="radio"]:disabled,
#awg_analyze_modal input[type="radio"]:disabled,
#awg_dhcp_modal input[type="radio"]:disabled{ opacity:0.5; cursor:default; }
</style>
<script>
var custom_settings = <% get_custom_settings(); %>;
var statusTimer = null;
var statusFails = 0;
var awgLoaded = false;
var awgPoll = null;
// Bumped on every user start/stop/restart action. A status refresh (or action poll) that was
// already in flight when the user clicked carries the OLD value; its callback checks this and
// bails, so a stale "stopped" read can't repaint «Запустить» over the transitional «Отменить»/
// «Подключение…» UI (the "button comes back, tempting a second click" bug).
var awgActionGen = 0;
var awgLastPeers = [];      // last peers array from the status poll — read by the live handshake ticker
var awgTickTimer = null;    // singleton interval for awgTickHandshakes (started once)
var v2flyList = [];
var v2flyIpList = ['telegram','google','facebook','twitter','netflix','cloudflare','fastly','cloudfront'];
function escHtml(s){
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
// Device names arrive URL-encoded in the log (from the ASUS client list: %20=space,
// %27=apostrophe, multi-byte UTF-8 for Cyrillic names…). Decode %XX runs to a human-readable
// form; a stray/malformed '%' is left as-is rather than corrupting the whole line.
function awgDecodePct(s){
    return String(s).replace(/(?:%[0-9A-Fa-f]{2})+/g, function(m){
        try { return decodeURIComponent(m); } catch(e){ return m; }
    });
}

// ---- i18n: follow the firmware UI language (preferred_lang). RU -> Russian, else English. ----
var AWG_LANG = (function(){
    try { return (httpApi.nvramGet(["preferred_lang"]).preferred_lang === 'RU') ? 'ru' : 'en'; }
    catch(e){ return 'en'; }
})();
var AWG_I18N = {
en: {
    // ---- status / badge ----
    STAT_LOADING: "Loading…",
    STAT_LOADING_BADGE: "&#9679; Loading…",
    STAT_CONNECTED: "Connected",
    STAT_STOPPED: "Stopped",
    STAT_CONNECTING: "Connecting…",
    STAT_STOPPING: "Stopping…",
    STAT_ROUTER_NO_RESPONSE: "Router not responding…",
    STAT_UPDATING: "Updating…",
    // ---- time-ago ----
    AGO_SEC: "{0} s ago",
    AGO_MIN: "{0} min ago",
    AGO_HOUR: "{0} h ago",
    HS_NEVER: "never",
    // ---- version button / modal status ----
    BTN_UPDATE_TO: "Update v{0} to v{1}",
    BTN_CURRENT_VERSION: "Current version — v{0}",
    BTN_VERSION_UPDATES: "Version / updates",
    MSG_CHECKING_UPDATES: "Checking for updates…",
    MSG_CHECK_FAILED: "⚠ Could not check for updates (GitHub unavailable)",
    MSG_UPDATE_AVAILABLE: "Update available: v{0}",
    MSG_NO_UPDATES: "No updates",
    MSG_NO_UPDATES_INSTALLED: " — v{0} installed",
    // ---- update modal ----
    MODAL_UPDATE_TO: "Update to v{0}",
    MODAL_CHANGELOG: "Changelog",
    MODAL_CHANGELOG_VER: " — v{0}",
    MODAL_LOADING_CHANGELOG: "Loading changelog…",
    MODAL_CHANGELOG_FAILED: "Could not load the changelog.",
    MSG_CLOSE_DURING_UPLOAD: "An upload/install is in progress. Close the window and stop tracking it?",
    // ---- install actions ----
    MSG_PICK_IPK: "Choose an .ipk file to install.",
    MSG_NOT_IPK_CONFIRM: "The file doesn't look like an .ipk. Install anyway?",
    MSG_ENTER_VERSION: "Enter a version as X.Y.Z, e.g. 1.1.49",
    MSG_VERSION_FORMAT: "Version as X.Y.Z, e.g. 1.1.49",
    MSG_VERSION_INSTALLED_REINSTALL: "Version v{0} is already installed. Reinstall?",
    MSG_LATEST_VERSION: "You already have the latest version{0}.",
    MSG_LATEST_VERSION_VER: " (v{0})",
    BTN_INSTALLING: "Installing…",
    BTN_INSTALL: "Install",
    MSG_INSTALL_FAILED: "Installation failed: {0}",
    // ---- upload (manual .ipk) ----
    UP_READING_FILE: "Reading file…",
    UP_READ_FAILED: "could not read the file.",
    UP_FILE_EMPTY: "the file is empty.",
    UP_SETTINGS_TOO_BIG: "settings are too large to upload a file via the UI.",
    UP_PROGRESS: "Uploading {0}/{1}…",
    UP_TRANSFER_FAILED: "transfer failed ",
    UP_PART: "(part {0}/{1}).",
    UP_NO_ROUTER_RESPONSE: "no response from the router (part {0}/{1}).",
    UP_VERIFYING: "Verifying and installing the package…",
    UP_DONE_RELOADING: "Done! Reloading the page…",
    UP_INSTALL_FAILED: "installation failed.",
    // ---- upload error codes (from backend slugs) ----
    ERR_GENERIC: "Installation failed",
    ERR_NO_DATA: "No upload data",
    ERR_DECODE_FAILED: "Decoding error",
    ERR_SIZE_MISMATCH: "Size mismatch — upload corrupted",
    ERR_CORRUPT: "File corrupted or not .ipk",
    ERR_NOT_IPK: "Not an opkg package (.ipk)",
    ERR_OPKG_FAILED: "opkg install failed",
    // ---- apply / restart ----
    MSG_FORCE_RESTART_CONFIRM: "The VPN will be fully restarted (stop → start) — the connection will drop briefly (devices on a VPN policy lose access for a few seconds). Routes and the firewall will also be rebuilt. Continue?",
    BTN_APPLYING: "Applying…",
    ACK_SAVED: "Saved ✓",
    ACK_SEND_FAILED: "Could not send — try again",
    // ---- first-run / validation ----
    TITLE_IMPORT_FIRST: "Import a configuration (.conf) first",
    MSG_INIT_NON_ASCII: "Fields I1–I5 contain invalid (non-ASCII) characters.",
    MSG_REQUIRED_FIELDS: "Required fields: Private Key, Peer Public Key and Endpoint.",
    MSG_BAD_KEY_FORMAT: "Invalid key format. Keys must be 44 characters long (base64).",
    MSG_ENDPOINT_NEEDS_PORT: "Endpoint must include a port (e.g. server:51820).",
    // ---- routing policy options (shared static + JS) ----
    OPT_VPN_ALL: "VPN: all traffic",
    OPT_VPN_GEO: "VPN: Geo only",
    OPT_VPN_GEO_PREFIX: "VPN: ",
    OPT_DIRECT: "Direct",
    // ---- geo policies (tabs) ----
    GEO_TAB_DEFAULT: "Geo",
    GEO_TAB_DEFAULT_NAME: "Geo {0}",
    GEO_TAB_ADD: "+ Add geo policy",
    GEO_TAB_RENAME: "Rename",
    GEO_TAB_RENAME_PROMPT: "Geo policy name:",
    GEO_TAB_REMOVE: "Remove geo policy",
    GEO_TAB_REMOVE_CONFIRM: "Remove geo policy «{0}»? Devices using it will switch to Direct.",
    GEO_MAX_REACHED: "Maximum {0} geo policies.",
    GEO_TABS_RAM_HINT: "Each policy is a separate ipset combining only its own GeoIP / GeoSite / GeoCustom / Antifilter lists. Many large lists across several policies can exhaust RAM on low-memory routers.",
    ANALYZE_TARGET_POLICY: "Add to:",
    ANALYZE_PICK_POLICY: "— choose geo policy —",
    ANALYZE_NEED_POLICY: "Choose a geo policy to add to.",
    // ---- client rows ----
    ARIA_DEVICE_IP: "Device IP address",
    ARIA_DEVICE_NAME: "Device name",
    ARIA_DEVICE_POLICY: "Device routing policy",
    ARIA_REMOVE_DEVICE: "Remove device",
    TITLE_REMOVE: "Remove",
    // ---- traffic analysis (per-device) ----
    ARIA_ANALYZE: "Analyze device traffic",
    TITLE_ANALYZE: "Traffic analysis",
    ANALYZE_MODAL_TITLE: "Traffic analysis — {0}",
    ANALYZE_START: "Start",
    ANALYZE_STOP: "Stop",
    ANALYZE_POLICY: "Policy",
    ANALYZE_NEED_IP: "Enter the device IP first.",
    ANALYZE_WAITING: "Capturing… generate some traffic on the device.",
    ANALYZE_NO_DATA: "Press “Start” to capture this device's requests.",
    ANALYZE_COL_TIME: "Time",
    ANALYZE_COL_NAME: "Request",
    ANALYZE_COL_DEST: "Destination",
    ANALYZE_COL_VERDICT: "Route",
    VERDICT_VPN: "VPN",
    VERDICT_GEO: "VPN (Geo)",
    VERDICT_DIRECT: "Direct",
    VERDICT_PENDING: "resolving…",
    ANALYZE_NOTE_SUMMARY: "What does this analysis show?",
    ANALYZE_NOTE: "Diagnostic. Shows the device's DNS requests (tagged DNS — what it's trying to reach) and its actual connections, each labeled Direct or VPN/Geo. Starting briefly restarts DNS to capture queries; only devices that use the router as DNS are visible. Verdict reflects the device's applied policy and the current geo lists.",
    ANALYZE_ADD_SELECTED: "+ To custom domains/IPs",
    ANALYZE_ADDED_ACK: "Added: {0} domains, {1} IPs (don't forget to Apply)",
    ANALYZE_NONE_SELECTED: "Nothing selected",
    ARIA_AN_SELALL: "Select all rows",
    MSG_REMOVE_DEVICE_CONFIRM: "Remove device «{0}» from the rules?",
    MSG_DEVICE_REMOVED: "Device removed.",
    BTN_UNDO: "Undo",
    // ---- geo download ----
    MSG_DOWNLOAD_LISTS_CONFIRM: "Download all GeoIP and domain lists?\nThis may take 1–2 minutes.",
    MSG_REDOWNLOAD_LISTS_CONFIRM: "Force re-download all GeoIP and domain lists?\nThis may take 1–2 minutes.",
    MSG_WIPE_BEFORE_UPDATE: "\n\n«Wipe before update» is enabled: all downloaded geo lists will be removed before downloading. If the download fails, the lists will stay missing.",
    MSG_GEO_LOADING_WAIT: "Downloading geo lists… Please wait.",
    BTN_GEO_LOADING: "Loading…",
    BTN_GEO_UPDATE_NOW: "Update now",
    BTN_GEO_DOWNLOAD: "Download lists",
    // ---- DHCP picker ----
    MSG_DHCP_FAILED: "Could not get the DHCP client list.\nEnter the IPs of the devices to add (comma-separated):",
    DHCP_COL_IP: "IP address",
    DHCP_COL_NAME: "Name",
    ARIA_DHCP_PICK: "Pick devices from DHCP",
    DHCP_TITLE: "Devices from DHCP",
    ARIA_CLOSE: "Close",
    DHCP_POLICY_LABEL: "Policy:",
    ARIA_DHCP_POLICY: "Policy for the selected devices",
    DHCP_ADD_SELECTED: "Add selected",
    // ---- diagnostics ----
    DIAG_COLLECTING: "Collecting data…",
    DIAG_COLLECTING_WAIT: "Collecting diagnostic data… Please wait.",
    DIAG_TIMEOUT: "Could not get diagnostics (timeout). Try again.",
    DIAG_EMPTY: "Diagnostics are empty.",
    DIAG_TIMEOUT_NOTE: "⚠ Collection did not finish before the timeout — the data may be incomplete.",
    DIAG_NOT_READY: "Data hasn't been collected yet — wait for collection to finish.",
    DIAG_LOG_HEADER: "===== LOG =====",
    DIAG_COPIED: "Copied ✓",
    DIAG_COPY_FAILED: "Failed",
    DIAG_COPIED_ALERT: "Diagnostics and the log were copied to the clipboard — you can paste them straight into a Telegram message.",
    DIAG_COPY_FAILED_ALERT: "Could not copy. Select the text in the window and copy it manually (Ctrl+C).",
    // ---- status info lines ----
    INFO_ADDRESS: "Address: ",
    INFO_PUBLIC_KEY: "Public key: ",
    INFO_PORT: "Port: ",
    // ---- active rules summary ----
    RULES_ROUTING: "{0} routing rules",
    RULES_IPRANGES: "{0} IP ranges",
    RULES_DOMAINS: "{0} domains",
    ACTIVE_PREFIX: "Active: ",
    NO_RULES: "no rules",
    TH_GEO_ACTIVE: "Active (all policies)",
    HINT_GEO_ACTIVE: "Totals across all geo policies (routing rules, IP ranges, domains). The IP-range count is live and grows as domains resolve, so it can exceed the number logged right after Apply.",
    // ---- coexist warning (innerHTML) ----
    COEX_STEP_POLICY: "<li>Change the <b>Default policy</b> from <b>«VPN — all traffic»</b> to <b>«Direct»</b> or <b>«VPN — Geo only»</b> — otherwise routing will take all traffic away from {0}.</li>",
    COEX_STEP_DNS: "<li>Enable <b>«Compatibility mode»</b> — so intercepting :53 doesn't conflict with {0}.</li>",
    COEX_HEADER: "⚠ Detected <b>{0}</b> on the router. So AmneziaWG doesn't conflict with it and leave the network without internet:",
    COEX_FOOTER: "<span style=\"opacity:0.85;\">After the changes, click <b>«Apply»</b>. GeoIP routing by IP keeps working in the meantime.</span>",
    // ---- import config ----
    MSG_IMPORT_REPLACE_CONFIRM: "Import will replace the current interface and peer settings. Continue?",
    MSG_IMPORT_UNRECOGNIZED: "Could not recognize the configuration: no [Interface]/[Peer] fields found (PrivateKey, PublicKey, Endpoint). Make sure it's a .conf from the Amnezia / WireGuard app.",
    MSG_IMPORT_OK: "Config imported. Check the fields and click «Apply».",
    // ==================== STATIC HTML ====================
    LBL_VPN_CLIENT: "VPN client",
    TITLE_AMNEZIA_SITE: "Amnezia website",
    TITLE_TG_CHAT: "Telegram chat",
    LBL_CHAT: "Chat",
    TITLE_GH_REPO: "Merlin AmneziaWG GitHub repository",
    TH_STATUS: "Status",
    BTN_START: "Start",
    BTN_STOP: "Stop",
    BTN_RESTART: "Restart",
    BTN_WD_FROM_DNS: "From DNS",
    TITLE_WD_FROM_DNS: "Fill in from the Interface DNS above",
    MSG_NO_DNS_FOR_WD: "The Interface DNS field is empty — set the DNS first.",
    TH_INTERFACE: "Interface",
    FIRSTRUN_HTML: "<b>It looks like no configuration is set yet.</b><br>\n                    Start by importing a <code>.conf</code> file from the Amnezia VPN app, then check the fields and click «Apply».",
    BTN_IMPORT_CONFIG: "Import configuration",
    SEC_CONNECTED_PEERS: "Connected peers",
    TH_SERVER_ADDR: "Server address",
    TH_ALLOWED_IPS: "Allowed IPs",
    TH_TRAFFIC: "Traffic (rx/tx)",
    TH_LAST_HANDSHAKE: "Last handshake",
    LBL_NO_PEERS: "No peers",
    SEC_CONFIG: "Configuration",
    BTN_IMPORT_CONF_FILE: "Import a .conf file from the Amnezia VPN client",
    OBF_SUMMARY_HTML: "AmneziaWG Obfuscation <span style=\"font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;\">— obfuscation parameters (usually filled in by importing a config) ▾</span>",
    TBL_ROUTING_POLICY: "Routing policy",
    TH_DEFAULT_POLICY: "Default policy",
    ARIA_DEFAULT_POLICY: "Default policy",
    OPT_DIRECT_NO_VPN: "Direct (no VPN)",
    OPT_VPN_ALL_TRAFFIC: "VPN — all traffic",
    OPT_VPN_GEO_ONLY: "VPN — Geo only",
    HINT_DEFAULT_POLICY: "Applied to devices that are not in the list below.",
    HINT_GEO_DNS_DEVICE: "Geo by domains only works if the device uses the router as its DNS (configured in the Geo block below).",
    TH_IPV6_LEAK: "IPv6 leak protection",
    LBL_BLOCK_IPV6_DNS: "Block resolving IPv6 addresses in DNS (filter-AAAA)",
    HINT_IPV6_DNS: "Critical for reliable Geo routing. Stops dual-stack (IPv4+IPv6) domains from bypassing the VPN over IPv6.",
    TH_KILLSWITCH: "Kill-switch",
    LBL_KILLSWITCH: "Block VPN traffic when the tunnel goes down (strict kill-switch)",
    HINT_KILLSWITCH_HTML: "<summary>Blocks traffic of VPN devices if the tunnel goes down (instead of leaking around it to the WAN). Off by default. <u>Details</u></summary>When enabled: if the tunnel suddenly goes down (daemon crash / out of memory), traffic from devices with a «VPN» policy doesn't leak around it to the WAN in cleartext but is blocked until recovery (the watchdog brings the tunnel back within ~5 min). Off — the previous behavior (traffic may temporarily go around the VPN). Affects only devices with a VPN/Geo policy; with the default policy set to «VPN — all traffic» it affects the whole LAN.",
    TH_TUNNEL_CHECK_ADDR: "Tunnel check addresses",
    ARIA_TUNNEL_CHECK_ADDR: "Tunnel check addresses",
    HINT_WATCHDOG_HTML: "<summary>Addresses the watchdog pings <b>through the tunnel</b> every 5 minutes (if at least one replies, the tunnel is alive). <u>Format and examples</u></summary><b>Format:</b> IP or domain, several allowed — separated by a space or comma (up to 4 addresses).<br><b>Example:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Prefer IPs (no dependency on DNS). Empty = default <b>8.8.8.8</b> and <b>1.1.1.1</b>. Change it if those addresses are blocked/unreachable for you — otherwise the watchdog restarts the VPN needlessly. Which addresses are checked is shown in the log below.",
    TH_ZAPRET_COMPAT: "Compatibility mode",
    LBL_NO_DNS_INTERCEPT: "Compatibility mode — coexist with zapret2 / Xray / b4 (don't intercept DNS)",
    HINT_NO_DNS_HTML: "<summary>Compatibility mode: disables AmneziaWG's DNS interception (port :53) so it can't clash with a co-resident DPI/proxy tool. ON by default for new installs. <u>Details</u></summary>Keep it on if <b>zapret2</b>, <b>Xray/XRAYUI</b> (v2ray, sing-box) or <b>b4</b> runs alongside — otherwise a DNS conflict can leave the network without internet. Geo by IP (GeoIP/antifilter) keeps working; geo by domains keeps working for clients that use the router as their DNS — only clients with a hardcoded external resolver lose domain-geo. A nearby zapret2 / Xray / v2ray / sing-box / b4 or NFQUEUE/TPROXY (iptables or nft) footprint also disables interception automatically even without this checkbox. Note: this only resolves the DNS conflict — with the «VPN — all traffic» policy, routing still takes the proxy's traffic, so for compatibility choose «Direct» or «VPN — Geo only».",
    TH_START_DELAY: "Startup delay",
    ARIA_START_DELAY: "Startup delay in seconds",
    LBL_START_DELAY_UNIT: "sec",
    HINT_START_DELAY: "Pause before starting the tunnel on boot. 0 = start immediately (default). Increase only if the tunnel comes up before the network or a co-resident resolver is ready.",
    TH_WAIT_AGH: "AdGuardHome",
    LBL_WAIT_AGH: "On autostart, wait until AdGuardHome is up before starting the tunnel",
    HINT_WAIT_AGH_HTML: "<summary>AdGuardHome detected. With this on, on boot AmneziaWG waits until AGH is actually up on :53 before starting (capped at 60s). <u>Why</u></summary>AdGuardHome fronts DNS on this router, and AmneziaWG's geo-by-domain routing reaches AGH through AMAGHI's ipset collector, which re-scans whenever AmneziaWG restarts dnsmasq. If that restart runs before AGH is ready, the geo set may not get (re)bridged. Waiting until AGH answers on :53 makes the ordering deterministic. Off — start without waiting (set a fixed «Startup delay» above if you prefer a pause).",
    SEC_DEVICE_RULES: "Device rules",
    TH_IP_ADDRESS: "IP address",
    TH_DEVICE_NAME: "Device name",
    TH_POLICY: "Policy",
    TH_ACTIONS: "Actions",
    BTN_ADD_DEVICE: "+ Add device",
    BTN_FROM_DHCP: "+ From DHCP list",
    GEO_DNS_IMPORTANT_HTML: "<b>Important:</b> For VPN Geo to work, devices must use the router as their DNS server.<br>\n                    iPhone: Settings &gt; Wi-Fi &gt; (i) &gt; DNS &gt; Manual &gt; only ",
    GEO_DNS_MACOS_HTML: " as DNS in your network settings. Disable DNS-over-HTTPS in the browser.",
    GEO_DNS_MACOS_PREFIX: "macOS/Windows: set ",
    BANNER_LISTS_NOT_LOADED: "⚠ Lists aren't downloaded yet — without them Geo routing doesn't work.",
    BTN_DOWNLOAD_LISTS: "Download lists",
    TBL_GEOIP: "GeoIP — route by service IPs",
    TH_GEOIP_LISTS: "GeoIP service lists",
    HINT_GEOIP: "Comma- or newline-separated. Available: telegram, google, facebook, twitter, netflix, cloudflare, fastly, cloudfront, tor + country codes (us, ru, cn, …).",
    HINT_GEOIP_WARN: "⚠ There are NO IP lists for youtube, discord, microsoft, github, openai etc. — use GeoSite below.",
    TBL_GEOSITE: "GeoSite — route by services / domains",
    TH_GEOSITE_LISTS: "GeoSite service lists",
    HINT_GEOSITE: "Comma- or newline-separated. 1500+ lists: youtube, google, discord, netflix, telegram, twitter, instagram, facebook, tiktok, spotify, steam, apple, microsoft, amazon, openai, github, whatsapp, category-media, category-games, category-dev …",
    TH_CUSTOM_DOMAINS: "Custom domains",
    HINT_CUSTOM_DOMAINS: "Comma- or newline-separated. Resolved via DNS → routed into the VPN.",
    TH_CUSTOM_IPS: "Custom IPs / subnets",
    HINT_CUSTOM_IPS: "Comma- or newline-separated: individual IPs or CIDR subnets.",
    TBL_GEO_CUSTOM: "GeoCustom — your own domains / IPs / files",
    HINT_GEO_CUSTOM_FORMAT: "One entry per line. A domain (<code>example.com</code>) is routed via DNS; an IP or CIDR subnet (<code>1.2.3.0/24</code>) is added to the ipset. Lines starting with <code>#</code> are comments. A URL must return a plain-text list in this format.",
    TH_GEO_FILES: "Custom files",
    TH_GEO_URLS: "URL sources",
    TBL_GEO_MODE: "How the lists work",
    TH_GEO_MODE: "Mode",
    OPT_GEO_MODE_VPN: "Route the lists via VPN (include)",
    OPT_GEO_MODE_DIRECT: "Lists go direct, everything else via VPN (exclude)",
    GEO_MODE_HINT_VPN: "Matched destinations route via VPN; everything else goes direct.",
    GEO_MODE_HINT_DIRECT: "Matched destinations go direct; everything else routes via VPN. Note: this pulls most of the device's traffic into the tunnel.",
    TBL_GEO_EXCLUDE: "Pointwise exclusions for this policy",
    HINT_GEO_EXCLUDE: "In include mode they go DIRECT (carved out of the VPN); in exclude mode they go via VPN (carved back in). Same format as GeoCustom.",
    BTN_ADD_GEO_FILE: "+ Add file",
    BTN_ADD_GEO_URL: "+ Add URL",
    BTN_LOAD_FROM_FILE: "Load from file",
    BTN_REMOVE: "Remove",
    PH_GEO_FILE_NAME: "name (a-z, 0-9)",
    PH_GEO_URL: "https://example.com/list.txt",
    MSG_GEO_FILES_TOO_BIG: "Custom files are too large to store in settings. Reduce the content or use a URL source for big lists.",
    TBL_ANTIFILTER: "Geo Antifilter — RKN lists (antifilter.download)",
    TH_ANTIFILTER_IP: "Antifilter IP lists",
    AF_ALLYOUNEED: " allyouneed — all the needed subnets (~15K) ",
    AF_RECOMMENDED: "recommended",
    AF_COMMUNITY: " community — community subnets (~900)",
    AF_IPSUM: " ipsum — IPs compressed to /24 (~15K)",
    AF_SUBNET: " subnet — large subnets (~78)",
    AF_IP: " ip — individual IPs (~48K)",
    AF_IPRESOLVE: " ipresolve — IPs from DNS resolution (~154K) ",
    AF_IPRESOLVE_WARN: "⚠ very large",
    HINT_ANTIFILTER_IP: "Added to the GeoIP lists and routed through the VPN. allyouneed = ipsum + subnet; ip/ipresolve overlap heavily with allyouneed — allyouneed is usually enough.",
    TH_ANTIFILTER_DOMAINS: "Antifilter domains",
    AF_COMMUNITY_DOMAINS: " community domains (~485) → dnsmasq",
    HINT_ANTIFILTER_DOMAINS: "The full domains.lst (1.4M domains / 27 MB) isn't supported — too large for dnsmasq on the router.",
    TBL_GEO_UPDATE: "Geo update settings",
    TH_AUTOUPDATE: "Auto-update lists",
    LBL_DAILY_4AM: "Daily at 4:00",
    TH_WIPE_BEFORE: "Wipe before update",
    LBL_WIPE_BEFORE: "Delete all geo files before a full update / program update",
    HINT_WIPE_BEFORE: "Off (default): existing geo lists are kept, including during a program update (no re-download). On: wipe before re-downloading (a clean set, but if a download fails some list will stay missing).",
    TH_IPSET_NAME: "ipset name",
    ARIA_IPSET_NAME: "ipset name",
    HINT_IPSET_HTML: "The name of the ipset set for GeoIP/antifilter subnets (routed through the VPN). Default <code>awg_dst</code>. A set <b>created by the addon itself</b> is removed on stop, and when the name changes the old one is removed too — no leftovers/leaks. If you specify a set that's <b>already created by another connection/tool</b>, the addon only adds entries to it and doesn't touch it on stop (a shared set). Letters, digits and <code>_ . -</code> are allowed, up to 31 characters; empty = <code>awg_dst</code>.",
    TBL_DOWNLOAD_VIA_VPN: "Download via VPN (bypass blocking)",
    TH_GEO_VIA_VPN: "Geo lists via VPN",
    LBL_GEO_VIA_VPN: "Download geo lists through the active AWG tunnel",
    HINT_GEO_VIA_VPN: "While the tunnel is up, downloading GeoIP / GeoSite / antifilter goes through the VPN (bypassing GitHub / jsDelivr blocking). If the VPN is off — the download goes directly, as before.",
    TH_UPDATE_VIA_VPN: "Program update via VPN",
    LBL_UPDATE_VIA_VPN: "Download the program update through the active AWG tunnel",
    HINT_UPDATE_VIA_VPN: "Version check and <code>.ipk</code> download go through the VPN while the tunnel is active — you can install updates straight from GitHub bypassing regional blocking (and verify SHA256 via the GitHub API). DNS resolution stays system-wide; the bypass works for IP/TCP blocking. If the VPN is off — directly, as before.",
    BTN_APPLY: "Apply",
    TITLE_APPLY: "Save and apply without restarting the VPN",
    BTN_SAVE_RESTART: "Save and fully restart the VPN",
    TITLE_SAVE_RESTART: "Save + restart the VPN (stop → start) + full rebuild of routes and firewall",
    APPLY_DESC1_HTML: "<b>Apply</b> — save the settings and apply them «on the fly»: updates devices, routing policies, the firewall and the GeoIP/GeoSite lists <b>without dropping the VPN connection</b>. If the VPN is stopped — the settings are just saved and applied at the next start.",
    APPLY_DESC2_HTML: "<b>Save and fully restart the VPN</b> (stop → start) — the config is re-applied (awg setconf), the interface, routes and firewall are rebuilt, the connection drops for a couple of seconds. Needed when changing keys, the server (Endpoint), MTU or obfuscation parameters (Jc, S1, H1…H4), or if the connection is «stuck».",
    SEC_LOG: "Log",
    BTN_GET_DIAG: "Get diagnostic data and copy log",
    LOG_WAITING: "Waiting for data…",
    MODAL_UPDATE_TITLE: "Update",
    INSTALL_LABEL: "Install:",
    ARIA_INSTALL_MODE: "Install method",
    OPT_INSTALL_AUTO: "Automatic (latest)",
    OPT_INSTALL_VERSION: "Choose version",
    OPT_INSTALL_FILE: "Manually from file",
    PH_VERSION: "e.g. 1.1.49",
    ARIA_VERSION_TO_INSTALL: "Version to install",
    ARIA_IPK_FILE: ".ipk file to install",
    BTN_CHECK_UPDATES: "Check for updates",
    BTN_CLOSE: "Close",
    MODAL_DIAG_TITLE: "Diagnostic data",
    BTN_COPY_DIAG: "Copy diagnostic data",
    DIAG_COPY_NOTE: "Copied together with the log, wrapped for pasting into Telegram.",
    DONATE_LABEL: "Support the project",
    DONATE_COPY_TITLE: "Click to copy the address",
    DONATE_COPIED: "Copied!",
    DONATE_COPY_FAILED: "Copy failed"
},
ru: {
    // ---- status / badge ----
    STAT_LOADING: "Загрузка…",
    STAT_LOADING_BADGE: "&#9679; Загрузка…",
    STAT_CONNECTED: "Подключено",
    STAT_STOPPED: "Остановлено",
    STAT_CONNECTING: "Подключение…",
    STAT_STOPPING: "Остановка…",
    STAT_ROUTER_NO_RESPONSE: "Роутер не отвечает…",
    STAT_UPDATING: "Обновление…",
    // ---- time-ago ----
    AGO_SEC: "{0} с назад",
    AGO_MIN: "{0} мин назад",
    AGO_HOUR: "{0} ч назад",
    HS_NEVER: "никогда",
    // ---- version button / modal status ----
    BTN_UPDATE_TO: "Обновить v{0} до v{1}",
    BTN_CURRENT_VERSION: "Текущая версия — v{0}",
    BTN_VERSION_UPDATES: "Версия / обновления",
    MSG_CHECKING_UPDATES: "Проверка обновлений…",
    MSG_CHECK_FAILED: "⚠ Не удалось проверить обновления (GitHub недоступен)",
    MSG_UPDATE_AVAILABLE: "Доступно обновление: v{0}",
    MSG_NO_UPDATES: "Обновлений нет",
    MSG_NO_UPDATES_INSTALLED: " — установлена v{0}",
    // ---- update modal ----
    MODAL_UPDATE_TO: "Обновление до v{0}",
    MODAL_CHANGELOG: "История изменений",
    MODAL_CHANGELOG_VER: " — v{0}",
    MODAL_LOADING_CHANGELOG: "Загрузка списка изменений…",
    MODAL_CHANGELOG_FAILED: "Не удалось загрузить список изменений.",
    MSG_CLOSE_DURING_UPLOAD: "Идёт загрузка/установка. Закрыть окно и прекратить отслеживание?",
    // ---- install actions ----
    MSG_PICK_IPK: "Выберите .ipk файл для установки.",
    MSG_NOT_IPK_CONFIRM: "Файл не похож на .ipk. Всё равно установить?",
    MSG_ENTER_VERSION: "Введите версию в формате X.Y.Z, например 1.1.49",
    MSG_VERSION_FORMAT: "Версия в формате X.Y.Z, например 1.1.49",
    MSG_VERSION_INSTALLED_REINSTALL: "Версия v{0} уже установлена. Переустановить?",
    MSG_LATEST_VERSION: "У вас последняя версия{0}.",
    MSG_LATEST_VERSION_VER: " (v{0})",
    BTN_INSTALLING: "Установка…",
    BTN_INSTALL: "Установить",
    MSG_INSTALL_FAILED: "Не удалось установить: {0}",
    // ---- upload (manual .ipk) ----
    UP_READING_FILE: "Чтение файла…",
    UP_READ_FAILED: "не удалось прочитать файл.",
    UP_FILE_EMPTY: "файл пуст.",
    UP_SETTINGS_TOO_BIG: "настройки слишком велики для загрузки файла через UI.",
    UP_PROGRESS: "Загрузка {0}/{1}…",
    UP_TRANSFER_FAILED: "сбой передачи ",
    UP_PART: "(часть {0}/{1}).",
    UP_NO_ROUTER_RESPONSE: "нет ответа роутера (часть {0}/{1}).",
    UP_VERIFYING: "Проверка и установка пакета…",
    UP_DONE_RELOADING: "Готово! Перезагрузка страницы…",
    UP_INSTALL_FAILED: "установка не удалась.",
    // ---- upload error codes (from backend slugs) ----
    ERR_GENERIC: "Установка не удалась",
    ERR_NO_DATA: "Нет данных загрузки",
    ERR_DECODE_FAILED: "Ошибка декодирования",
    ERR_SIZE_MISMATCH: "Размер не совпал — загрузка повреждена",
    ERR_CORRUPT: "Файл повреждён или не .ipk",
    ERR_NOT_IPK: "Это не пакет opkg (.ipk)",
    ERR_OPKG_FAILED: "opkg install не удался",
    // ---- apply / restart ----
    MSG_FORCE_RESTART_CONFIRM: "VPN будет полностью перезапущен (stop → start) — соединение временно прервётся (устройства с политикой VPN потеряют доступ на несколько секунд). Заодно пересоберутся маршруты и firewall. Продолжить?",
    BTN_APPLYING: "Применение…",
    ACK_SAVED: "Сохранено ✓",
    ACK_SEND_FAILED: "Не удалось отправить — повторите",
    // ---- first-run / validation ----
    TITLE_IMPORT_FIRST: "Сначала импортируйте конфигурацию (.conf)",
    MSG_INIT_NON_ASCII: "Поля I1–I5 содержат недопустимые (не-ASCII) символы.",
    MSG_REQUIRED_FIELDS: "Обязательные поля: Private Key, Peer Public Key и Endpoint.",
    MSG_BAD_KEY_FORMAT: "Неверный формат ключа. Ключи должны быть длиной 44 символа (base64).",
    MSG_ENDPOINT_NEEDS_PORT: "Endpoint должен содержать порт (например, server:51820).",
    // ---- routing policy options (shared static + JS) ----
    OPT_VPN_ALL: "VPN: весь трафик",
    OPT_VPN_GEO: "VPN: только Geo",
    OPT_VPN_GEO_PREFIX: "VPN: ",
    OPT_DIRECT: "Напрямую",
    // ---- гео политики (вкладки) ----
    GEO_TAB_DEFAULT: "Гео",
    GEO_TAB_DEFAULT_NAME: "Гео {0}",
    GEO_TAB_ADD: "+ Добавить гео политику",
    GEO_TAB_RENAME: "Переименовать",
    GEO_TAB_RENAME_PROMPT: "Название гео-политики:",
    GEO_TAB_REMOVE: "Удалить гео политику",
    GEO_TAB_REMOVE_CONFIRM: "Удалить гео политику «{0}»? Устройства с ней переключатся на «Напрямую».",
    GEO_MAX_REACHED: "Максимум {0} гео-политик.",
    GEO_TABS_RAM_HINT: "Каждая политика — отдельный ipset, объединяющий только свои списки GeoIP / GeoSite / GeoCustom / Antifilter. Много больших списков в нескольких политиках могут исчерпать память на слабых роутерах.",
    ANALYZE_TARGET_POLICY: "Добавить в:",
    ANALYZE_PICK_POLICY: "— выберите гео-политику —",
    ANALYZE_NEED_POLICY: "Выберите гео-политику для добавления.",
    // ---- client rows ----
    ARIA_DEVICE_IP: "IP-адрес устройства",
    ARIA_DEVICE_NAME: "Имя устройства",
    ARIA_DEVICE_POLICY: "Политика маршрутизации устройства",
    ARIA_REMOVE_DEVICE: "Удалить устройство",
    TITLE_REMOVE: "Удалить",
    // ---- traffic analysis (per-device) ----
    ARIA_ANALYZE: "Анализ трафика устройства",
    TITLE_ANALYZE: "Анализ трафика",
    ANALYZE_MODAL_TITLE: "Анализ трафика — {0}",
    ANALYZE_START: "Старт",
    ANALYZE_STOP: "Стоп",
    ANALYZE_POLICY: "Политика",
    ANALYZE_NEED_IP: "Сначала укажите IP устройства.",
    ANALYZE_WAITING: "Идёт захват… создайте трафик на устройстве.",
    ANALYZE_NO_DATA: "Нажмите «Старт», чтобы захватить запросы устройства.",
    ANALYZE_COL_TIME: "Время",
    ANALYZE_COL_NAME: "Запрос",
    ANALYZE_COL_DEST: "Назначение",
    ANALYZE_COL_VERDICT: "Маршрут",
    VERDICT_VPN: "VPN",
    VERDICT_GEO: "VPN (Geo)",
    VERDICT_DIRECT: "Напрямую",
    VERDICT_PENDING: "резолв…",
    ANALYZE_NOTE_SUMMARY: "Что показывает этот анализ?",
    ANALYZE_NOTE: "Диагностика. Показывает DNS-запросы устройства (метка DNS — что оно пытается вызвать) и его реальные соединения, у каждого — вердикт «напрямую» или «VPN/Geo». При старте кратко перезапускается DNS для захвата запросов; видны только устройства, использующие роутер как DNS. Вердикт отражает применённую политику устройства и текущие гео-списки.",
    ANALYZE_ADD_SELECTED: "+ В свои домены/IP",
    ANALYZE_ADDED_ACK: "Добавлено: {0} доменов, {1} IP (не забудьте «Применить»)",
    ANALYZE_NONE_SELECTED: "Ничего не отмечено",
    ARIA_AN_SELALL: "Выбрать все строки",
    MSG_REMOVE_DEVICE_CONFIRM: "Удалить устройство «{0}» из правил?",
    MSG_DEVICE_REMOVED: "Устройство удалено.",
    BTN_UNDO: "Отменить",
    // ---- geo download ----
    MSG_DOWNLOAD_LISTS_CONFIRM: "Скачать все списки GeoIP и доменов?\nЭто может занять 1–2 минуты.",
    MSG_REDOWNLOAD_LISTS_CONFIRM: "Принудительно перекачать все списки GeoIP и доменов?\nЭто может занять 1–2 минуты.",
    MSG_WIPE_BEFORE_UPDATE: "\n\nВключена «Очистка перед обновлением»: все скачанные geo-списки будут удалены перед загрузкой. При сбое загрузки списки останутся отсутствующими.",
    MSG_GEO_LOADING_WAIT: "Загрузка geo-списков… Подождите.",
    BTN_GEO_LOADING: "Загрузка…",
    BTN_GEO_UPDATE_NOW: "Обновить сейчас",
    BTN_GEO_DOWNLOAD: "Скачать списки",
    // ---- DHCP picker ----
    MSG_DHCP_FAILED: "Не удалось получить список клиентов DHCP.\nВведите IP устройств для добавления (через запятую):",
    DHCP_COL_IP: "IP-адрес",
    DHCP_COL_NAME: "Имя",
    ARIA_DHCP_PICK: "Выбор устройств из DHCP",
    DHCP_TITLE: "Устройства из DHCP",
    ARIA_CLOSE: "Закрыть",
    DHCP_POLICY_LABEL: "Политика:",
    ARIA_DHCP_POLICY: "Политика для выбранных устройств",
    DHCP_ADD_SELECTED: "Добавить выбранные",
    // ---- diagnostics ----
    DIAG_COLLECTING: "Сбор данных…",
    DIAG_COLLECTING_WAIT: "Сбор диагностических данных… Подождите.",
    DIAG_TIMEOUT: "Не удалось получить диагностику (таймаут). Попробуйте ещё раз.",
    DIAG_EMPTY: "Диагностика пуста.",
    DIAG_TIMEOUT_NOTE: "⚠ Сбор не завершился по таймауту — данные могут быть неполными.",
    DIAG_NOT_READY: "Данные ещё не собраны — подождите завершения сбора.",
    DIAG_LOG_HEADER: "===== ЖУРНАЛ =====",
    DIAG_COPIED: "Скопировано ✓",
    DIAG_COPY_FAILED: "Не удалось",
    DIAG_COPIED_ALERT: "Диагностика и журнал скопированы в буфер обмена — можно сразу вставить в сообщение Telegram.",
    DIAG_COPY_FAILED_ALERT: "Не удалось скопировать. Выделите текст в окне и скопируйте вручную (Ctrl+C).",
    // ---- status info lines ----
    INFO_ADDRESS: "Адрес: ",
    INFO_PUBLIC_KEY: "Открытый ключ: ",
    INFO_PORT: "Порт: ",
    // ---- active rules summary ----
    RULES_ROUTING: "{0} правил маршрутизации",
    RULES_IPRANGES: "{0} диапазонов IP",
    RULES_DOMAINS: "{0} доменов",
    ACTIVE_PREFIX: "Активно: ",
    NO_RULES: "нет правил",
    TH_GEO_ACTIVE: "Активно (все политики)",
    HINT_GEO_ACTIVE: "Суммарно по всем гео-политикам (правила маршрутизации, диапазоны IP, домены). Число диапазонов IP — живое: растёт по мере резолва доменов, поэтому может превышать значение в журнале сразу после применения.",
    // ---- coexist warning (innerHTML) ----
    COEX_STEP_POLICY: "<li>Смените <b>Политику по умолчанию</b> с <b>«VPN — весь трафик»</b> на <b>«Напрямую»</b> или <b>«VPN — только Geo»</b> — иначе маршрутизация заберёт у {0} весь трафик.</li>",
    COEX_STEP_DNS: "<li>Включите <b>«Режим совместимости»</b> — чтобы перехват :53 не конфликтовал с {0}.</li>",
    COEX_HEADER: "⚠ Обнаружен <b>{0}</b> на роутере. Чтобы AmneziaWG не конфликтовал с ним и не оставил сеть без интернета:",
    COEX_FOOTER: "<span style=\"opacity:0.85;\">После изменений нажмите <b>«Применить»</b>. Geo-маршрутизация по IP при этом продолжает работать.</span>",
    // ---- import config ----
    MSG_IMPORT_REPLACE_CONFIRM: "Импорт заменит текущие настройки интерфейса и пира. Продолжить?",
    MSG_IMPORT_UNRECOGNIZED: "Не удалось распознать конфигурацию: не найдены поля [Interface]/[Peer] (PrivateKey, PublicKey, Endpoint). Проверьте, что это .conf из приложения Amnezia / WireGuard.",
    MSG_IMPORT_OK: "Конфиг импортирован. Проверьте поля и нажмите «Применить».",
    // ==================== STATIC HTML ====================
    LBL_VPN_CLIENT: "VPN-клиент",
    TITLE_AMNEZIA_SITE: "Сайт Amnezia",
    TITLE_TG_CHAT: "Telegram-чат",
    LBL_CHAT: "Чат",
    TITLE_GH_REPO: "GitHub репозиторий Merlin AmneziaWG",
    TH_STATUS: "Статус",
    BTN_START: "Запустить",
    BTN_STOP: "Остановить",
    BTN_RESTART: "Перезапустить",
    BTN_WD_FROM_DNS: "Из DNS",
    TITLE_WD_FROM_DNS: "Заполнить из поля DNS интерфейса выше",
    MSG_NO_DNS_FOR_WD: "Поле DNS интерфейса пустое — сначала укажите DNS.",
    TH_INTERFACE: "Интерфейс",
    FIRSTRUN_HTML: "<b>Похоже, конфигурация ещё не задана.</b><br>\n                    Начните с импорта <code>.conf</code>-файла из приложения Amnezia VPN, затем проверьте поля и нажмите «Применить».",
    BTN_IMPORT_CONFIG: "Импорт конфигурации",
    SEC_CONNECTED_PEERS: "Подключённые пиры",
    TH_SERVER_ADDR: "Адрес сервера",
    TH_ALLOWED_IPS: "Разрешённые IP",
    TH_TRAFFIC: "Трафик (приём/передача)",
    TH_LAST_HANDSHAKE: "Последнее рукопожатие",
    LBL_NO_PEERS: "Нет пиров",
    SEC_CONFIG: "Конфигурация",
    BTN_IMPORT_CONF_FILE: "Импорт .conf-файла из клиента Amnezia VPN",
    OBF_SUMMARY_HTML: "AmneziaWG Obfuscation <span style=\"font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;\">— параметры обфускации (обычно заполняются импортом конфига) ▾</span>",
    TBL_ROUTING_POLICY: "Политика маршрутизации",
    TH_DEFAULT_POLICY: "Политика по умолчанию",
    ARIA_DEFAULT_POLICY: "Политика по умолчанию",
    OPT_DIRECT_NO_VPN: "Напрямую (без VPN)",
    OPT_VPN_ALL_TRAFFIC: "VPN — весь трафик",
    OPT_VPN_GEO_ONLY: "VPN — только Geo",
    HINT_DEFAULT_POLICY: "Применяется к устройствам, которых нет в списке ниже.",
    HINT_GEO_DNS_DEVICE: "Geo по доменам работает только если устройство использует роутер как DNS (настройка — в блоке Geo ниже).",
    TH_IPV6_LEAK: "Защита от утечек IPv6",
    LBL_BLOCK_IPV6_DNS: "Блокировать разрешение IPv6-адресов в DNS (filter-AAAA)",
    HINT_IPV6_DNS: "Критично для надёжной Geo-маршрутизации. Не даёт доменам с dual-stack (IPv4+IPv6) обходить VPN через IPv6.",
    TH_KILLSWITCH: "Kill-switch",
    LBL_KILLSWITCH: "Блокировать VPN-трафик при падении туннеля (strict kill-switch)",
    HINT_KILLSWITCH_HTML: "<summary>Блокирует трафик VPN-устройств, если туннель упал (вместо утечки в обход в WAN). По умолчанию выключено. <u>Подробнее</u></summary>Когда включено: если туннель внезапно падает (краш демона / нехватка памяти), трафик устройств с политикой «VPN» не уходит в обход в WAN открытым текстом, а блокируется до восстановления (watchdog поднимает туннель в течение ~5 мин). Выключено — прежнее поведение (трафик может временно идти мимо VPN). Влияет только на устройства с политикой VPN/Geo; при политике по умолчанию «VPN — весь трафик» затрагивает весь LAN.",
    TH_TUNNEL_CHECK_ADDR: "Адреса проверки туннеля",
    ARIA_TUNNEL_CHECK_ADDR: "Адреса проверки туннеля",
    HINT_WATCHDOG_HTML: "<summary>Адреса, которые watchdog пингует <b>через туннель</b> раз в 5 минут (ответил хоть один — туннель живой). <u>Формат и примеры</u></summary><b>Формат:</b> IP или домен, можно несколько — через пробел или запятую (до 4 адресов).<br><b>Пример:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Лучше указывать IP (без зависимости от DNS). Пусто = по умолчанию <b>8.8.8.8</b> и <b>1.1.1.1</b>. Поменяйте, если эти адреса у вас блокируются/недоступны — иначе watchdog зря перезапускает VPN. Какие адреса проверяются — видно в журнале ниже.",
    TH_ZAPRET_COMPAT: "Режим совместимости",
    LBL_NO_DNS_INTERCEPT: "Режим совместимости — сосуществование с zapret2 / Xray / b4 (не перехватывать DNS)",
    HINT_NO_DNS_HTML: "<summary>Режим совместимости: отключает перехват DNS (порт :53) у AmneziaWG, чтобы он не конфликтовал с соседней DPI/прокси-утилитой. Для новых установок включён по умолчанию. <u>Подробнее</u></summary>Держите включённым, если рядом работает <b>zapret2</b>, <b>Xray/XRAYUI</b> (v2ray, sing-box) или <b>b4</b> — иначе конфликт DNS может оставить сеть без интернета. Geo по IP (GeoIP/antifilter) продолжает работать; geo по доменам работает для клиентов, использующих роутер как DNS — только клиенты с жёстко прописанным внешним резолвером теряют geo по доменам. Обнаруженный рядом zapret2 / Xray / v2ray / sing-box / b4 или след NFQUEUE/TPROXY (iptables или nft) тоже отключает перехват автоматически даже без этой галочки. Важно: галочка решает только конфликт по DNS — при политике «VPN — весь трафик» маршрутизация всё равно заберёт трафик прокси, поэтому для совместимости выбирайте «Напрямую» или «VPN — только Geo».",
    TH_START_DELAY: "Задержка запуска",
    ARIA_START_DELAY: "Задержка запуска в секундах",
    LBL_START_DELAY_UNIT: "с",
    HINT_START_DELAY: "Пауза перед запуском туннеля на буте. 0 = сразу (по умолчанию). Увеличьте, только если туннель поднимается раньше, чем готова сеть или соседний резолвер.",
    TH_WAIT_AGH: "AdGuardHome",
    LBL_WAIT_AGH: "При автозапуске ждать готовности AdGuardHome перед запуском туннеля",
    HINT_WAIT_AGH_HTML: "<summary>Обнаружен AdGuardHome. С этой галочкой при загрузке AmneziaWG ждёт, пока AGH реально поднимется на :53, и только потом стартует (потолок 60 с). <u>Зачем</u></summary>На этом роутере DNS обслуживает AdGuardHome, а geo-по-доменам у AmneziaWG доезжает до AGH через ipset-коллектор AMAGHI, который пересканирует конфиг при каждом перезапуске dnsmasq. Если перезапуск случится раньше готовности AGH, гео-набор может не перемоститься. Ожидание ответа AGH на :53 делает порядок детерминированным. Выкл — старт без ожидания (можно задать фиксированную «Задержку запуска» выше).",
    SEC_DEVICE_RULES: "Правила устройств",
    TH_IP_ADDRESS: "IP-адрес",
    TH_DEVICE_NAME: "Имя устройства",
    TH_POLICY: "Политика",
    TH_ACTIONS: "Действия",
    BTN_ADD_DEVICE: "+ Добавить устройство",
    BTN_FROM_DHCP: "+ Из списка DHCP",
    GEO_DNS_IMPORTANT_HTML: "<b>Важно:</b> Для работы VPN Geo устройства должны использовать роутер как DNS-сервер.<br>\n                    iPhone: Настройки &gt; Wi-Fi &gt; (i) &gt; DNS &gt; Вручную &gt; только ",
    GEO_DNS_MACOS_HTML: " как DNS в настройках сети. Отключите DNS-over-HTTPS в браузере.",
    GEO_DNS_MACOS_PREFIX: "macOS/Windows: укажите ",
    BANNER_LISTS_NOT_LOADED: "⚠ Списки ещё не загружены — без них Geo-маршрутизация не работает.",
    BTN_DOWNLOAD_LISTS: "Скачать списки",
    TBL_GEOIP: "GeoIP — маршрут по IP сервисов",
    TH_GEOIP_LISTS: "Списки сервисов GeoIP",
    HINT_GEOIP: "Через запятую или с новой строки. Доступно: telegram, google, facebook, twitter, netflix, cloudflare, fastly, cloudfront, tor + коды стран (us, ru, cn, …).",
    HINT_GEOIP_WARN: "⚠ Для youtube, discord, microsoft, github, openai и т.п. IP-списков НЕТ — используйте GeoSite ниже.",
    TBL_GEOSITE: "GeoSite — маршрут по сервисам / доменам",
    TH_GEOSITE_LISTS: "Списки сервисов GeoSite",
    HINT_GEOSITE: "Через запятую или с новой строки. 1500+ списков: youtube, google, discord, netflix, telegram, twitter, instagram, facebook, tiktok, spotify, steam, apple, microsoft, amazon, openai, github, whatsapp, category-media, category-games, category-dev …",
    TH_CUSTOM_DOMAINS: "Свои домены",
    HINT_CUSTOM_DOMAINS: "Через запятую или с новой строки. Резолвятся через DNS → маршрутизируются в VPN.",
    TH_CUSTOM_IPS: "Свои IP / подсети",
    HINT_CUSTOM_IPS: "Через запятую или с новой строки: отдельные IP или подсети CIDR.",
    TBL_GEO_CUSTOM: "GeoCustom — свои домены / IP / файлы",
    HINT_GEO_CUSTOM_FORMAT: "Один элемент в строке. Домен (<code>example.com</code>) маршрутизируется через DNS; IP или подсеть CIDR (<code>1.2.3.0/24</code>) добавляется в ipset. Строки, начинающиеся с <code>#</code>, — комментарии. Файл по ссылке должен возвращать простой текстовый список в этом формате.",
    TH_GEO_FILES: "Свои файлы",
    TH_GEO_URLS: "URL-источники",
    TBL_GEO_MODE: "Как работают списки",
    TH_GEO_MODE: "Режим",
    OPT_GEO_MODE_VPN: "Списки — в VPN (включение)",
    OPT_GEO_MODE_DIRECT: "Списки — напрямую, остальное в VPN (исключение)",
    GEO_MODE_HINT_VPN: "Совпавшее со списками идёт в VPN; всё остальное — напрямую.",
    GEO_MODE_HINT_DIRECT: "Совпавшее со списками идёт напрямую; всё остальное — в VPN. Внимание: это тянет почти весь трафик устройства в туннель.",
    TBL_GEO_EXCLUDE: "Точечные исключения для этой политики",
    HINT_GEO_EXCLUDE: "В режиме «включение» идут НАПРЯМУЮ (вырезаются из VPN); в режиме «исключение» — наоборот в VPN. Формат как у GeoCustom.",
    BTN_ADD_GEO_FILE: "+ Добавить файл",
    BTN_ADD_GEO_URL: "+ Добавить ссылку",
    BTN_LOAD_FROM_FILE: "Загрузить из файла",
    BTN_REMOVE: "Удалить",
    PH_GEO_FILE_NAME: "имя (a-z, 0-9)",
    PH_GEO_URL: "https://example.com/list.txt",
    MSG_GEO_FILES_TOO_BIG: "Свои файлы слишком большие для хранения в настройках. Уменьшите содержимое или используйте URL-источник для больших списков.",
    TBL_ANTIFILTER: "Geo Antifilter — РКН-списки (antifilter.download)",
    TH_ANTIFILTER_IP: "Antifilter IP-списки",
    AF_ALLYOUNEED: " allyouneed — все нужные подсети (~15K) ",
    AF_RECOMMENDED: "рекомендуется",
    AF_COMMUNITY: " community — подсети сообщества (~900)",
    AF_IPSUM: " ipsum — IP, сжатые до /24 (~15K)",
    AF_SUBNET: " subnet — крупные подсети (~78)",
    AF_IP: " ip — отдельные IP (~48K)",
    AF_IPRESOLVE: " ipresolve — IP из DNS-резолва (~154K) ",
    AF_IPRESOLVE_WARN: "⚠ очень большой",
    HINT_ANTIFILTER_IP: "Добавляются к спискам GeoIP и маршрутизируются через VPN. allyouneed = ipsum + subnet; ip/ipresolve сильно пересекаются с allyouneed — обычно достаточно allyouneed.",
    TH_ANTIFILTER_DOMAINS: "Antifilter домены",
    AF_COMMUNITY_DOMAINS: " community домены (~485) → dnsmasq",
    HINT_ANTIFILTER_DOMAINS: "Полный domains.lst (1.4M доменов / 27 МБ) не поддерживается — слишком большой для dnsmasq на роутере.",
    TBL_GEO_UPDATE: "Настройки обновления Geo",
    TH_AUTOUPDATE: "Автообновление списков",
    LBL_DAILY_4AM: "Ежедневно в 4:00",
    TH_WIPE_BEFORE: "Очистка перед обновлением",
    LBL_WIPE_BEFORE: "Удалять все geo-файлы перед полным обновлением / обновлением программы",
    HINT_WIPE_BEFORE: "Выключено (по умолчанию): существующие geo-списки сохраняются, в том числе при обновлении программы (без повторной загрузки). Включено: очистка перед перекачкой (чистый набор, но при сбое загрузки какой-то список останется отсутствующим).",
    TH_IPSET_NAME: "Имя ipset",
    ARIA_IPSET_NAME: "Имя ipset",
    HINT_IPSET_HTML: "Имя ipset-набора для GeoIP/antifilter-подсетей (маршрутизируются через VPN). По умолчанию <code>awg_dst</code>. Набор, <b>созданный самим аддоном</b>, удаляется при остановке, а при смене имени удаляется и старый — висяков/утечек не остаётся. Если указать набор, который <b>уже создан другим подключением/инструментом</b>, аддон лишь добавляет в него записи и не трогает при остановке (общий набор). Допустимы буквы, цифры и <code>_ . -</code>, до 31 символа; пусто = <code>awg_dst</code>.",
    TBL_DOWNLOAD_VIA_VPN: "Загрузка через VPN (обход блокировок)",
    TH_GEO_VIA_VPN: "Geo-списки через VPN",
    LBL_GEO_VIA_VPN: "Загружать geo-списки через активный AWG-туннель",
    HINT_GEO_VIA_VPN: "Пока туннель поднят, загрузка GeoIP / GeoSite / antifilter идёт через VPN (обход блокировок GitHub / jsDelivr). Если VPN выключен — загрузка идёт напрямую, как раньше.",
    TH_UPDATE_VIA_VPN: "Обновление программы через VPN",
    LBL_UPDATE_VIA_VPN: "Загружать обновление программы через активный AWG-туннель",
    HINT_UPDATE_VIA_VPN: "Проверка версии и загрузка <code>.ipk</code> идут через VPN, пока туннель активен — можно ставить обновления прямо с GitHub в обход региональных блокировок (и проверять SHA256 по GitHub API). DNS-резолвинг остаётся системным; обход работает для блокировок по IP/TCP. Если VPN выключен — напрямую, как раньше.",
    BTN_APPLY: "Применить",
    TITLE_APPLY: "Сохранить и применить без перезапуска VPN",
    BTN_SAVE_RESTART: "Сохранить и полностью перезапустить VPN",
    TITLE_SAVE_RESTART: "Сохранить + перезапуск VPN (stop → start) + полная пересборка маршрутов и firewall",
    APPLY_DESC1_HTML: "<b>Применить</b> — сохранить настройки и применить их «на лету»: обновляет устройства, политики маршрутизации, firewall и списки GeoIP/GeoSite <b>без разрыва VPN-соединения</b>. Если VPN остановлен — настройки просто сохранятся и применятся при следующем запуске.",
    APPLY_DESC2_HTML: "<b>Сохранить и полностью перезапустить VPN</b> (stop → start) — заново применяется конфиг (awg setconf), пересобираются интерфейс, маршруты и firewall, соединение на пару секунд прерывается. Нужно при смене ключей, сервера (Endpoint), MTU или параметров обфускации (Jc, S1, H1…H4), а также если соединение «залипло».",
    SEC_LOG: "Журнал",
    BTN_GET_DIAG: "Получить диагностические данные и скопировать лог",
    LOG_WAITING: "Ожидание данных…",
    MODAL_UPDATE_TITLE: "Обновление",
    INSTALL_LABEL: "Установить:",
    ARIA_INSTALL_MODE: "Способ установки",
    OPT_INSTALL_AUTO: "Автоматически (последняя)",
    OPT_INSTALL_VERSION: "Выбрать версию",
    OPT_INSTALL_FILE: "Вручную через файл",
    PH_VERSION: "напр. 1.1.49",
    ARIA_VERSION_TO_INSTALL: "Версия для установки",
    ARIA_IPK_FILE: "Файл .ipk для установки",
    BTN_CHECK_UPDATES: "Проверить обновления",
    BTN_CLOSE: "Закрыть",
    MODAL_DIAG_TITLE: "Диагностические данные",
    BTN_COPY_DIAG: "Скопировать диагностические данные",
    DIAG_COPY_NOTE: "Копируется вместе с журналом, обёрнуто для вставки в Telegram.",
    DONATE_LABEL: "Поддержать проект",
    DONATE_COPY_TITLE: "Нажмите, чтобы скопировать адрес",
    DONATE_COPIED: "Скопировано!",
    DONATE_COPY_FAILED: "Не удалось"
}
};
// T(key, ...args): current-lang -> en -> key. {0},{1}.. are positional args.
function T(key){
    var d = AWG_I18N[AWG_LANG] || AWG_I18N.en;
    var s = (d[key] != null) ? d[key] : (AWG_I18N.en[key] != null ? AWG_I18N.en[key] : key);
    for (var i = 1; i < arguments.length; i++){ s = s.replace('{'+(i-1)+'}', arguments[i]); }
    return s;
}
// Localize static DOM tagged with data-i18n* attributes. Called first in initial().
function applyI18n(){
    var i, el, nodes;
    nodes = document.querySelectorAll('[data-i18n]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.textContent = T(el.getAttribute('data-i18n')); }
    nodes = document.querySelectorAll('[data-i18n-html]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.innerHTML = T(el.getAttribute('data-i18n-html')); }
    nodes = document.querySelectorAll('[data-i18n-ph]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.setAttribute('placeholder', T(el.getAttribute('data-i18n-ph'))); }
    nodes = document.querySelectorAll('[data-i18n-title]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.setAttribute('title', T(el.getAttribute('data-i18n-title'))); }
    nodes = document.querySelectorAll('[data-i18n-aria]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.setAttribute('aria-label', T(el.getAttribute('data-i18n-aria'))); }
    nodes = document.querySelectorAll('[data-i18n-val]');
    for(i=0;i<nodes.length;i++){ el=nodes[i]; el.value = T(el.getAttribute('data-i18n-val')); }
}
// Localize backend upload-error codes (see amneziawg.sh). Falls back to a generic message.
function awgErrText(code){
    var k = 'ERR_' + String(code||'').toUpperCase();
    return (AWG_I18N[AWG_LANG] && AWG_I18N[AWG_LANG][k]) || (AWG_I18N.en[k]) || T('ERR_GENERIC');
}

// Relative handshake age computed CLIENT-SIDE from the raw epoch the backend now emits
// (hs_epoch). This is what makes the counter tick live every second without a backend
// round-trip. Returns null when there is no usable epoch (0/absent) so the caller falls
// back to the pre-formatted string from older status files. Negative deltas (browser clock
// behind the router) are clamped to 0 — never show a negative "ago". Wording matches the
// backend's own strings (amneziawg.sh) so the live value and the fallback look identical.
function awgAgo(epoch){
    epoch = parseInt(epoch, 10);
    if(!epoch || epoch <= 0) return null;
    var d = Math.floor(Date.now() / 1000) - epoch;
    if(d < 0) d = 0;
    if(d < 60) return T('AGO_SEC', d);
    if(d < 3600) return T('AGO_MIN', Math.floor(d / 60));
    return T('AGO_HOUR', Math.floor(d / 3600));
}

// Mirror of the backend human_size() (1 decimal, GiB/MiB/KiB/B) so RX/TX can be formatted
// from the raw byte counters. Returns null for non-numeric/absent input -> caller falls back
// to the pre-formatted transfer_rx/tx string. Bytes are 64-bit counters; JS Number is exact
// to 2^53, well above any realistic traffic total.
function awgHumanSize(bytes){
    if(bytes === null || bytes === undefined || bytes === '') return null;
    var b = Number(bytes);
    if(!isFinite(b)) return null;
    if(b >= 1073741824) return (b / 1073741824).toFixed(1) + ' GiB';
    if(b >= 1048576)    return (b / 1048576).toFixed(1) + ' MiB';
    if(b >= 1024)       return (b / 1024).toFixed(1) + ' KiB';
    return b + ' B';
}

// Live handshake ticker: re-computes ONLY the handshake cell text from the stored epochs,
// every second, between the 5s status polls. It never rebuilds the peer table (that would
// fight the poll's render and flicker) — it just updates the textContent of each
// #awg_hs_<i> cell. Peers with no epoch are left as the rendered fallback string.
function awgTickHandshakes(){
    var peers = awgLastPeers;
    if(!peers || !peers.length) return;
    for(var i = 0; i < peers.length; i++){
        var ep = peers[i] && peers[i].hs_epoch;
        var t = awgAgo(ep);
        if(t === null) continue;
        var cell = document.getElementById('awg_hs_' + i);
        if(cell) cell.textContent = t;
    }
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
    applyI18n();
    show_menu();
    loadSettings();
    awgRefreshStatus();
    statusTimer = setInterval(awgRefreshStatus, 5000);
    // Tick the handshake age live (client-side) between the 5s status polls.
    if(!awgTickTimer) awgTickTimer = setInterval(awgTickHandshakes, 1000);
    awgRefreshLog();
    setInterval(awgRefreshLog, 2500);
    loadV2flyCategories();
    initAutocomplete();
    initAutocompleteIp();
    checkForUpdate();
    // After an update/install page reload (awgReload set the flag), bring the log into view so
    // the user keeps watching progress instead of landing back at the top of the page.
    try {
        if(sessionStorage.getItem('awg_scroll_log')){
            sessionStorage.removeItem('awg_scroll_log');
            setTimeout(function(){
                var lb = document.getElementById('awg_log');
                if(lb){ try { lb.scrollIntoView({ behavior:'smooth', block:'center' }); } catch(e){ try { lb.scrollIntoView(); } catch(e2){} } }
            }, 400);
        }
    } catch(e){}
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

// Single header button: "update available" label when one exists, else the current-version
// label. Both open the modal (check / changelog / update happen there).
function renderVersionButton(){
    var ub = document.getElementById('awg_update_btn');
    if(!ub) return;
    ub.style.display = 'inline';
    var label = (awgUpdateAvailable && awgLatestVersion) ? T('BTN_UPDATE_TO', awgCurrentVersion, awgLatestVersion)
              : (awgCurrentVersion ? T('BTN_CURRENT_VERSION', awgCurrentVersion) : T('BTN_VERSION_UPDATES'));
    ub.innerHTML = '<input type="button" class="button_gen" value="' + escHtml(label) + '" onclick="openUpdateModal();" style="font-size:11px; padding:2px 10px;">';
}

// Update the modal's status line + install button (only while the modal is open).
function refreshModalState(){
    var m = document.getElementById('awg_update_modal');
    if(!m || m.style.display === 'none') return;
    var st = document.getElementById('awg_modal_status');
    if(st){
        if(awgChecking) st.textContent = T('MSG_CHECKING_UPDATES');
        else if(awgCheckFailed) st.textContent = T('MSG_CHECK_FAILED');
        else if(awgUpdateAvailable && awgLatestVersion) st.textContent = T('MSG_UPDATE_AVAILABLE', awgLatestVersion);
        else st.textContent = T('MSG_NO_UPDATES') + (awgCurrentVersion ? T('MSG_NO_UPDATES_INSTALLED', awgCurrentVersion) : '');
    }
}

// Reload via a fresh GET (cache-busted), never location.reload() — reload() repeats
// the POST from the last form submit, which makes the browser prompt to resubmit.
function awgReload(){
    // Remember to scroll to the log after the reload (update/install) so progress stays visible.
    try { sessionStorage.setItem('awg_scroll_log', '1'); } catch(e){}
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
    if(badge){ badge.className = 'awg-status connecting'; badge.innerHTML = '&#9679; ' + escHtml(T('STAT_UPDATING')); }
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
    // Supersede any status read still in flight so it can't repaint over the «Updating» badge
    // (same generation guard as awgAction; see awgActionGen).
    awgActionGen++;
    // The modal just closed — scroll to the log so the user can watch the update progress.
    var _lb = document.getElementById('awg_log');
    if(_lb){ try { _lb.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch(e){ try { _lb.scrollIntoView(); } catch(e2){} } }

    // Carry the current "download via VPN" choice even without a prior Apply.
    syncViaVpnToggles();
    // Pin an explicit version (one-shot) so the router installs exactly it — no backend
    // jsDelivr resolution, no crawl lag. Sent via custom_settings, then removed from
    // memory so a later "Apply" can't re-pin it (the backend also clears it after use).
    if(version) custom_settings.awg_update_version = String(version);
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    if(version) delete custom_settings.awg_update_version;
    document.form.action_script.value = "start_awgdoupdate";
    awgSubmitForm();

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
        ? T('MODAL_UPDATE_TO', awgLatestVersion)
        : (T('MODAL_CHANGELOG') + (awgCurrentVersion ? T('MODAL_CHANGELOG_VER', awgCurrentVersion) : ''));
    if(body) body.innerHTML = '<div style="opacity:0.7;">' + escHtml(T('MODAL_LOADING_CHANGELOG')) + '</div>';
    m.style.display = 'block';
    awgModalPrevFocus = document.activeElement;
    document.addEventListener('keydown', awgModalKeydown);
    var firstCtl = document.getElementById('awg_install_mode');
    if(firstCtl){ try { firstCtl.focus(); } catch(e){} }
    awgManualUI(false);    // hide any leftover upload progress
    awgManualEnd(false);   // re-enable the install button
    awgModeUI();           // show the input matching the current mode
    refreshModalState();   // status line + install button visibility
    loadChangelog(ref, function(text, ok){
        if(!body) return;
        if(ok && text){ body.innerHTML = mdToHtml(text); body.scrollTop = 0; }
        else { body.innerHTML = '<div style="opacity:0.7;">' + escHtml(T('MODAL_CHANGELOG_FAILED')) + '</div>'; }
    });
}

function closeUpdateModal(){
    if(awgUploading && !confirm(T('MSG_CLOSE_DURING_UPLOAD'))) return;
    awgRun++;             // invalidate any in-flight upload/poll loops
    awgManualEnd(false);  // reset the install button + awgUploading flag
    document.removeEventListener('keydown', awgModalKeydown);
    var m = document.getElementById('awg_update_modal');
    if(m) m.style.display = 'none';
    if(awgModalPrevFocus){ try { awgModalPrevFocus.focus(); } catch(e){} awgModalPrevFocus = null; }
}

// Esc closes the update modal (listener added while it's open, removed on close).
var awgModalPrevFocus = null;
function awgModalKeydown(e){
    if(e.key === 'Escape' || e.keyCode === 27) closeUpdateModal();
}

// Show the version field / file field for the selected install mode.
function awgModeUI(){
    var mode = document.getElementById('awg_install_mode').value;
    var vin = document.getElementById('awg_version_input');
    var fin = document.getElementById('awg_ipk_file');
    if(vin) vin.style.display = (mode === 'version') ? '' : 'none';
    if(fin) fin.style.display = (mode === 'file') ? '' : 'none';
    // When the user picks the "choose version" mode, focus the version field right away.
    if(mode === 'version' && vin){ try { vin.focus(); vin.select(); } catch(e){} }
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
        if(!f){ alert(T('MSG_PICK_IPK')); return; }
        if(!/\.ipk$/i.test(f.name) && !confirm(T('MSG_NOT_IPK_CONFIRM'))) return;
        awgManualStart(f);
        return;
    }

    if(mode === 'version'){
        var inp = document.getElementById('awg_version_input');
        var v = ((inp && inp.value) || '').trim().replace(/^v/i, '');
        if(!v){ alert(T('MSG_ENTER_VERSION')); return; }
        if(!/^\d+\.\d+\.\d+$/.test(v)){ alert(T('MSG_VERSION_FORMAT')); return; }
        if(awgCurrentVersion && v === awgCurrentVersion && !confirm(T('MSG_VERSION_INSTALLED_REINSTALL', v))) return;
        closeUpdateModal();
        doUpdate(v);
        return;
    }

    // auto -> latest. If we're already on the newest, say so instead of a no-op update.
    if(!awgUpdateAvailable){
        alert(T('MSG_LATEST_VERSION', awgCurrentVersion ? T('MSG_LATEST_VERSION_VER', awgCurrentVersion) : ''));
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
    if(btn){ btn.disabled = uploading; btn.value = uploading ? T('BTN_INSTALLING') : T('BTN_INSTALL'); }
}
function awgManualFail(msg){
    awgManualEnd(false);
    awgSetProgress(0, '');
    awgManualUI(false);
    alert(T('MSG_INSTALL_FAILED', msg));
}

// Encode a Uint8Array to base64 without blowing the call stack on large files.
function awgBytesToB64(bytes){
    var bin = '', step = 0x8000;
    for(var i = 0; i < bytes.length; i += step){
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + step));
    }
    return btoa(bin);
}

// Single submit point for the shared form. The browser's "Save password?" prompt fires
// whenever a form containing an <input type="password"> is submitted — here the WG private
// key / PSK. Those fields are rendered as masked type=text (class awg-dotted, see CSS) rather
// than type=password specifically so the browser never treats the form as a login. (Disabling
// the fields at submit — 1.1.74 — was not enough: Chromium captures the value while typing.)
// Safari also sniffs id/class/name/aria-label for credential words, so those are kept neutral
// too (1.1.89/1.1.90) — see AWG_LEGACY_FIELDS and awg-dotted.
function awgSubmitForm(){
    document.form.submit();
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
    awgSubmitForm();
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
    awgSetProgress(0, T('UP_READING_FILE'));

    var reader = new FileReader();
    reader.onerror = function(){ awgManualFail(T('UP_READ_FAILED')); };
    reader.onload = function(){
        var bytes = new Uint8Array(reader.result);
        var total = bytes.length;
        if(total === 0){ awgManualFail(T('UP_FILE_EMPTY')); return; }
        var b64 = awgBytesToB64(bytes);

        // Size each chunk so the whole POST (current settings + chunk, URL-encoded) stays
        // well under the firmware's ~64 KB body cap. If the existing settings alone are
        // already too big, bail out cleanly rather than send a silently-truncated POST.
        var baseLen = encodeURIComponent(JSON.stringify(custom_settings)).length;
        // -256: the "amng_custom=" prefix, the other form fields, and the chunk key names
        // (awg_ipk_chunk/seq/token/first) that ride along in the same POST body.
        var budget = 52000 - baseLen - 256;
        if(budget < 2000){ awgManualFail(T('UP_SETTINGS_TOO_BIG')); return; }
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
            awgSetProgress(i / total_chunks, T('UP_PROGRESS', i + 1, total_chunks));
            awgPostSettings('start_awgupload', extra, 1, function(){
                awgPollAck(token, i, 15000, myRun, function(ack){
                    if(ack && ack.status === 'ok'){ sendChunk(i + 1); return; }
                    if(ack && (ack.status === 'gap' || ack.status === 'err')){
                        awgManualFail((ack.code ? awgErrText(ack.code) + ' ' : (ack.msg ? ack.msg + ' ' : T('UP_TRANSFER_FAILED'))) + T('UP_PART', i + 1, total_chunks));
                        return;
                    }
                    if(attempt < 4){ attemptChunk(i, extra, attempt + 1); return; }   // timeout -> retry
                    awgManualFail(T('UP_NO_ROUTER_RESPONSE', i + 1, total_chunks));
                });
            });
        }
        function triggerInstall(){
            if(awgStale(myRun)) return;
            awgSetProgress(1, T('UP_VERIFYING'));
            awgPostSettings('start_awgmanualinstall', { awg_ipk_len: String(total), awg_ipk_token: token }, 30, function(){
                awgPollManualInstall(token, myRun);
            });
        }

        awgSetProgress(0, T('UP_PROGRESS', 1, total_chunks));
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
                awgSetProgress(1, T('UP_DONE_RELOADING'));
                setTimeout(awgReload, 1500);
                return;
            }
            if(j && j.tok === token && j.status === 'install_err'){ awgManualFail(j.code ? awgErrText(j.code) : T('UP_INSTALL_FAILED')); return; }
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

// Field names are neutral end-to-end: DOM id == custom_settings key == backend
// get_setting key. Safari (and Chromium) pop "Save password?" / offer autofill for any
// form field whose id/name/class reads like a credential ("key"/"secret"/"private"/
// "psk"), even on a plain type=text — so neither the markup the browser scans nor the
// keys we persist may contain those words. AWG_LEGACY_FIELDS maps each current key to
// the credential-flavored key used up to 1.1.88; loadSettings() carries an existing
// value forward so an in-place upgrade keeps the config (the next Apply persists it
// under the new key, and the backend's migrate_field_names() renames it on disk and
// drops the stale line).
var AWG_LEGACY_FIELDS = {
    awg_iface_p1: 'awg_privatekey',
    awg_peer_p1:  'awg_peer_pubkey',
    awg_peer_p2:  'awg_peer_psk'
};

function loadSettings(){
    // Carry forward any value still stored under a pre-1.1.89 (credential-flavored) key,
    // so an in-place upgrade keeps the config even before the backend migrates the file.
    // Drop the old key from the object too, so a subsequent Apply never POSTs it back
    // (the backend's migrate_field_names removes the stale line on disk).
    for(var lk in AWG_LEGACY_FIELDS){
        var ok = AWG_LEGACY_FIELDS[lk];
        if(custom_settings[lk] == undefined && custom_settings[ok] != undefined)
            custom_settings[lk] = custom_settings[ok];
        delete custom_settings[ok];
    }
    var fields = [
        'awg_iface_p1', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_peer_p1', 'awg_peer_p2', 'awg_peer_endpoint',
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
    // Load geo settings FIRST: builds geoPolicies + rebuilds every policy dropdown so the
    // default-policy value and per-device rows below have their vpn_geo_<id> options present.
    loadGeoSettings();
    // Load default policy (now that the dropdown carries every geo policy option)
    var defPolicy = document.getElementById('default_policy');
    var dpv = custom_settings.awg_default_policy || 'direct';
    defPolicy.value = geoValidRef(dpv) ? dpv : 'direct';
    // Load clients list (rows get the full per-policy dropdown)
    loadClients();
    updateGeoVisibility();
    updateFirstRun();
}

function saveSettings(){ applyConfig('start_awgsaveconf'); }

function forceApply(){
    if(!confirm(T('MSG_FORCE_RESTART_CONFIRM'))) return;
    applyConfig('start_awgforceapply');
}

// ---- UX helpers: apply feedback, validation, first-run --------------------------------
// Both Apply buttons (top quick-bar + bottom) are matched by their onclick so we don't
// have to thread ids through the markup.
function awgApplyBtns(){
    return document.querySelectorAll('input[onclick^="saveSettings"], input[onclick^="forceApply"]');
}
function awgSetApplyBusy(busy){
    var b = awgApplyBtns();
    for(var i = 0; i < b.length; i++){
        b[i].disabled = busy;
        if(busy){ b[i]._lbl = b[i].value; b[i].value = T('BTN_APPLYING'); }
        else if(b[i]._lbl){ b[i].value = b[i]._lbl; }
    }
}
function awgShowAck(msg, ok){
    var ids = ['awg_ack_top', 'awg_ack_bottom'];
    for(var i = 0; i < ids.length; i++){
        var el = document.getElementById(ids[i]);
        if(el){ el.textContent = msg; el.className = 'awg-ack show ' + (ok ? 'ok' : 'err'); }
    }
    setTimeout(function(){
        for(var j = 0; j < ids.length; j++){ var e = document.getElementById(ids[j]); if(e) e.className = 'awg-ack'; }
    }, ok ? 2500 : 5000);
}
// Focus + highlight the first offending field (instead of a bare alert that names no field).
function awgFlagField(id, msg){
    var prev = document.querySelectorAll('.awg-invalid');
    for(var i = 0; i < prev.length; i++) prev[i].className = prev[i].className.replace(/\s*awg-invalid/, '');
    var el = document.getElementById(id);
    if(el){
        el.className += ' awg-invalid';
        try { el.scrollIntoView({block:'center'}); } catch(e){ try { el.scrollIntoView(); } catch(e2){} }
        try { el.focus(); } catch(e3){}
        var clr = function(){ el.className = el.className.replace(/\s*awg-invalid/, ''); el.removeEventListener('input', clr); };
        el.addEventListener('input', clr);
    }
    if(msg) alert(msg);
}
// First-run: no key/peer yet → guide to Import and don't let Start run an empty config.
function updateFirstRun(){
    var pk = (document.getElementById('awg_iface_p1') || {}).value || '';
    var pubk = (document.getElementById('awg_peer_p1') || {}).value || '';
    var empty = !pk && !pubk;
    var fr = document.getElementById('awg_firstrun');
    if(fr) fr.style.display = empty ? '' : 'none';
    var sb = document.getElementById('btn_start');
    if(sb){ sb.disabled = empty; sb.title = empty ? T('TITLE_IMPORT_FIRST') : ''; }
}

function applyConfig(actionScript){
    var fields = [
        'awg_iface_p1', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_peer_p1', 'awg_peer_p2', 'awg_peer_endpoint',
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
        alert(T('MSG_INIT_NON_ASCII'));
        return;
    }

    // Save geo settings PER POLICY (GeoIP/GeoSite/GeoCustom/Antifilter for each tab) into the
    // legacy unsuffixed keys (id 1) / id-suffixed keys (id>=2), plus the awg_geo_policies
    // registry. geoSerializePolicies captures the visible tab first and validates the files
    // budget; bail (no submit) if it's exceeded.
    if(!geoSerializePolicies()) return;
    custom_settings.awg_geo_autoupdate = document.getElementById('geo_autoupdate').checked ? '1' : '0';
    custom_settings.awg_block_ipv6_dns = document.getElementById('awg_block_ipv6_dns').checked ? '1' : '0';
    custom_settings.awg_no_dns_intercept = document.getElementById('awg_no_dns_intercept').checked ? '1' : '0';
    custom_settings.awg_killswitch = document.getElementById('awg_killswitch').checked ? '1' : '0';
    var _wfa = document.getElementById('awg_wait_for_agh');
    if(_wfa) custom_settings.awg_wait_for_agh = _wfa.checked ? '1' : '0';
    var _sd = document.getElementById('awg_start_delay');
    if(_sd){ var _sdv = parseInt(_sd.value, 10); custom_settings.awg_start_delay = (isNaN(_sdv) || _sdv < 0) ? '0' : String(Math.min(_sdv, 300)); }
    // Watchdog probe hosts: keep only safe host chars (IP/hostname + separators), collapse spaces
    custom_settings.awg_watchdog_hosts = document.getElementById('awg_watchdog_hosts').value.replace(/[^0-9A-Za-z.\-, ]/g, '').replace(/\s+/g, ' ').trim();
    custom_settings.awg_geo_wipe_update = document.getElementById('awg_geo_wipe_update').checked ? '1' : '0';
    // ipset name — sanitize to a valid set name (letters/digits/_.-, <=31); empty => backend uses awg_dst
    custom_settings.awg_ipset_name = document.getElementById('awg_ipset_name').value.replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 31);
    // Download-via-VPN toggles (route geo / program-update downloads through the tunnel)
    custom_settings.awg_geo_via_awg = document.getElementById('awg_geo_via_awg').checked ? '1' : '0';
    custom_settings.awg_update_via_awg = document.getElementById('awg_update_via_awg').checked ? '1' : '0';
    // (Antifilter lists are saved per-policy by geoSerializePolicies above.)

    // Basic validation
    var pk = document.getElementById('awg_iface_p1').value;
    var pubk = document.getElementById('awg_peer_p1').value;
    var ep = document.getElementById('awg_peer_endpoint').value;
    if(!pk || !pubk || !ep){
        awgFlagField(!pk ? 'awg_iface_p1' : (!pubk ? 'awg_peer_p1' : 'awg_peer_endpoint'),
                     T('MSG_REQUIRED_FIELDS'));
        return;
    }
    if(pk.length !== 44 || pubk.length !== 44){
        awgFlagField(pk.length !== 44 ? 'awg_iface_p1' : 'awg_peer_p1',
                     T('MSG_BAD_KEY_FORMAT'));
        return;
    }
    if(!/:\d{1,5}$/.test(ep)){
        awgFlagField('awg_peer_endpoint', T('MSG_ENDPOINT_NEEDS_PORT'));
        return;
    }

    // Submit via the shared helper so we get a completion callback for the ack, and disable
    // the Apply buttons meanwhile so an impatient second tap can't queue a redundant
    // firewall rebuild / tunnel restart under the backend lock.
    awgSetApplyBusy(true);
    // Sync the header icon. «Применить» (awgsaveconf) only rebuilds the firewall — no tunnel
    // cycle — so a light fast-probe suffices. «Сохранить и перезапустить» (awgforceapply) really
    // does do_stop; do_start, so give it the same full guarded amber transition as «Перезапустить».
    awgSignalWidget(actionScript === 'start_awgforceapply' ? 'restart' : 'refresh');
    awgPostSettings(actionScript, null, null, function(ok){
        awgSetApplyBusy(false);
        awgShowAck(ok ? T('ACK_SAVED') : T('ACK_SEND_FAILED'), ok);
    });
    // No full-page reload: status + log refresh live via polling. Reloading after a
    // form POST makes the browser prompt to resubmit the form ("resubmit form").
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
        '<td><input type="text" class="client_ip input_25_table" style="width:100%;" value="' + escHtml(ip) + '" placeholder="192.168.1.100" aria-label="' + escHtml(T('ARIA_DEVICE_IP')) + '"></td>' +
        '<td><input type="text" class="client_name input_25_table" style="width:100%;" value="' + escHtml(name) + '" placeholder="iPhone, PS5, TV..." aria-label="' + escHtml(T('ARIA_DEVICE_NAME')) + '"></td>' +
        '<td><select class="client_policy input_option" onchange="updateGeoVisibility();" style="width:100%;" aria-label="' + escHtml(T('ARIA_DEVICE_POLICY')) + '">' +
            geoPolicyOptionsHtml(geoValidRef(policy) ? policy : 'direct') +
        '</select></td>' +
        '<td><div class="awg-cell-actions">' +
            '<button type="button" class="awg-analyze-btn" aria-label="' + escHtml(T('ARIA_ANALYZE')) + '" title="' + escHtml(T('TITLE_ANALYZE')) + '" onclick="awgOpenAnalyze(this);"><svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="3 17 9 11 13 15 21 7"></polyline><polyline points="15 7 21 7 21 13"></polyline></svg></button>' +
            '<button type="button" class="awg-remove-btn" aria-label="' + escHtml(T('ARIA_REMOVE_DEVICE')) + '" title="' + escHtml(T('TITLE_REMOVE')) + '" onclick="awgRemoveClientRow(this);"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="6" y1="6" x2="18" y2="18"></line><line x1="18" y1="6" x2="6" y2="18"></line></svg></button>' +
        '</div></td>';
    tbody.appendChild(tr);
    updateGeoVisibility();
}

// Remove a device row with one-level undo: a mis-tap on the × (which shares the Actions
// column with the analyze button) is easy, and the deletion only becomes permanent on Apply.
// Stash the row and offer an "Undo" link near the Add buttons.
var awgLastRemoved = null;
function awgRemoveClientRow(btn){
    var tr = btn.closest('tr');
    if(!tr) return;
    var ip = (tr.querySelector('.client_ip') || {}).value || '';
    var name = (tr.querySelector('.client_name') || {}).value || '';
    // Confirm before dropping a configured device (the undo is one-level only). Skip the
    // prompt for a still-empty row, e.g. one just added by mistake — nothing to lose there.
    if((ip || name) && !confirm(T('MSG_REMOVE_DEVICE_CONFIRM', name || ip))) return;
    var rows = Array.prototype.slice.call(document.querySelectorAll('#awg_client_rows tr'));
    awgLastRemoved = {
        ip: ip,
        name: name,
        policy: (tr.querySelector('.client_policy') || {}).value || 'vpn_all',
        idx: rows.indexOf(tr)
    };
    tr.parentNode.removeChild(tr);
    updateGeoVisibility();
    awgRenderUndo();
}
function awgRenderUndo(){
    var bar = document.getElementById('awg_client_undo');
    if(!bar) return;
    if(awgLastRemoved){
        bar.innerHTML = escHtml(T('MSG_DEVICE_REMOVED')) + ' <a href="javascript:void(0)" onclick="awgUndoRemove();" style="color:#5db0ff;">' + escHtml(T('BTN_UNDO')) + '</a>';
        bar.style.display = '';
    } else { bar.style.display = 'none'; bar.innerHTML = ''; }
}
function awgUndoRemove(){
    if(!awgLastRemoved) return;
    var r = awgLastRemoved;
    awgLastRemoved = null;
    addClientRow(r.ip, r.name, r.policy);   // appends at the end…
    var rows = document.querySelectorAll('#awg_client_rows tr');
    var tb = document.getElementById('awg_client_rows');
    if(r.idx >= 0 && r.idx < rows.length - 1){   // …move it back to its original slot
        tb.insertBefore(rows[rows.length - 1], rows[r.idx]);
    }
    awgRenderUndo();
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
    // Show geo settings if ANY device uses a geo policy or the default policy is a geo policy
    // (vpn_geo or vpn_geo_<id>).
    var defPolicy = document.getElementById('default_policy').value;
    var hasGeo = (defPolicy.indexOf('vpn_geo') === 0);
    if(!hasGeo){
        var selects = document.querySelectorAll('.client_policy');
        for(var i = 0; i < selects.length; i++){
            if(selects[i].value.indexOf('vpn_geo') === 0){ hasGeo = true; break; }
        }
    }
    document.getElementById('geo_section').style.display = hasGeo ? '' : 'none';
}

// === Geo policies (tabbed multi-policy manager) =========================================
// Each policy holds its config as the SAME serialized strings the backend stores (so capture/
// restore is just (de)serialize). One visible panel swaps data per active tab — no per-tab DOM
// duplication. Policy id 1 = legacy/default (unsuffixed keys); ids >=2 use suffixed keys.
var GEO_MAX_POLICIES = 8;
var geoPolicies = [];     // [{id,name(uri-enc),v2fly,v2flyIp,customDomains,customIps,files,urls,antifilter}]
var geoActiveIdx = 0;
var geoLoadedIds = [];    // ids present at load — used to clear keys of policies removed before Apply

function geoRef(id){ return id === 1 ? 'vpn_geo' : 'vpn_geo_' + id; }
function geoRefId(ref){
    if(ref === 'vpn_geo') return 1;
    var m = /^vpn_geo_(\d+)$/.exec(ref || '');
    return m ? parseInt(m[1], 10) : 0;
}
function geoKeyJs(id, suf){
    if(suf === 'antifilter_lists') return id === 1 ? 'awg_antifilter_lists' : 'awg_antifilter_' + id + '_lists';
    return id === 1 ? 'awg_geo_' + suf : 'awg_geo_' + id + '_' + suf;
}
function geoNextId(){ var mx = 0; for(var i=0;i<geoPolicies.length;i++) if(geoPolicies[i].id > mx) mx = geoPolicies[i].id; return mx + 1; }
function geoPolicyIndexById(id){ for(var i=0;i<geoPolicies.length;i++) if(geoPolicies[i].id === id) return i; return -1; }
function geoDecodeName(n){ try { return decodeURIComponent(n); } catch(e){ return n || ''; } }
function geoValidRef(ref){
    if(ref === 'vpn_all' || ref === 'direct') return true;
    return ref && ref.indexOf('vpn_geo') === 0 && geoPolicyIndexById(geoRefId(ref)) !== -1;
}

// Build the <option> list for a policy dropdown: VPN-all + one option per geo policy + Direct.
function geoPolicyOptionsHtml(selectedRef){
    var h = '<option value="vpn_all"' + (selectedRef==='vpn_all'?' selected':'') + '>' + escHtml(T('OPT_VPN_ALL')) + '</option>';
    for(var i=0;i<geoPolicies.length;i++){
        var ref = geoRef(geoPolicies[i].id);
        h += '<option value="' + ref + '"' + (selectedRef===ref?' selected':'') + '>' + escHtml(T('OPT_VPN_GEO_PREFIX') + geoDecodeName(geoPolicies[i].name)) + '</option>';
    }
    h += '<option value="direct"' + (selectedRef==='direct'?' selected':'') + '>' + escHtml(T('OPT_DIRECT')) + '</option>';
    return h;
}
// Rebuild every policy dropdown (device rows, default policy, DHCP + analyzer pickers).
// A select whose current ref points at a now-deleted policy falls back to Direct.
function refreshPolicyDropdowns(){
    var sels = document.querySelectorAll('.client_policy'), i, cur;
    for(i=0;i<sels.length;i++){
        cur = sels[i].value; if(!geoValidRef(cur)) cur = 'direct';
        sels[i].innerHTML = geoPolicyOptionsHtml(cur); sels[i].value = cur;
    }
    var defSel = document.getElementById('default_policy');
    if(defSel){ cur = defSel.value; if(!geoValidRef(cur)) cur = 'direct'; defSel.innerHTML = geoPolicyOptionsHtml(cur); defSel.value = cur; }
    var dhcp = document.getElementById('awg_dhcp_policy');
    if(dhcp){ cur = dhcp.value; if(!geoValidRef(cur)) cur = 'vpn_all'; dhcp.innerHTML = geoPolicyOptionsHtml(cur); dhcp.value = cur; }
    geoFillAnalyzePicker();
}

// Read the visible panel back into the active policy object.
function geoCaptureActive(){
    if(geoActiveIdx < 0 || geoActiveIdx >= geoPolicies.length) return;
    var p = geoPolicies[geoActiveIdx];
    p.v2flyIp = awgCsv('awg_geo_v2fly_ip');
    p.v2fly = awgCsv('awg_geo_v2fly');
    p.customDomains = awgCsv('geo_custom_domains');
    p.customIps = awgCsv('geo_custom_ips');
    p.files = serializeGeoFiles();
    p.urls = serializeGeoUrls();
    var af = [], boxes = document.querySelectorAll('.af_list');
    for(var i=0;i<boxes.length;i++) if(boxes[i].checked) af.push(boxes[i].value);
    p.antifilter = af.join(',');
    // Mode (include/exclude) + exclusions block.
    var mr = document.querySelector('input[name="geo_mode"]:checked');
    p.mode = (mr && mr.value === 'direct') ? 'direct' : 'vpn';
    p.excDomains = awgCsv('geo_exc_domains');
    p.excIps = awgCsv('geo_exc_ips');
    p.excFiles = serializeGeoFiles('exc');
    p.excUrls = serializeGeoUrls('exc');
}
// Render the active policy object into the visible panel fields.
function geoRenderActive(){
    if(geoActiveIdx < 0 || geoActiveIdx >= geoPolicies.length) return;
    var p = geoPolicies[geoActiveIdx];
    var set = function(id, v){ var e = document.getElementById(id); if(e) e.value = v || ''; };
    set('awg_geo_v2fly_ip', p.v2flyIp);
    set('awg_geo_v2fly', p.v2fly);
    set('geo_custom_domains', p.customDomains);
    set('geo_custom_ips', p.customIps);
    loadGeoFiles(p.files);
    loadGeoUrls(p.urls);
    var sel = (p.antifilter || '').split(','), boxes = document.querySelectorAll('.af_list');
    for(var i=0;i<boxes.length;i++) boxes[i].checked = sel.indexOf(boxes[i].value) !== -1;
    // Mode (include/exclude) + exclusions block.
    var mode = (p.mode === 'direct') ? 'direct' : 'vpn';
    var mr = document.querySelector('input[name="geo_mode"][value="' + mode + '"]');
    if(mr) mr.checked = true;
    set('geo_exc_domains', p.excDomains);
    set('geo_exc_ips', p.excIps);
    loadGeoFiles(p.excFiles, 'exc');
    loadGeoUrls(p.excUrls, 'exc');
    updateGeoModeHint();
}
// Swap the mode hint text to match the selected include/exclude radio.
function updateGeoModeHint(){
    var mr = document.querySelector('input[name="geo_mode"]:checked');
    var el = document.getElementById('geo_mode_hint');
    if(el) el.textContent = T((mr && mr.value === 'direct') ? 'GEO_MODE_HINT_DIRECT' : 'GEO_MODE_HINT_VPN');
}
function geoRenderTabs(){
    var bar = document.getElementById('geo_tabs');
    if(!bar) return;
    var h = '';
    for(var i=0;i<geoPolicies.length;i++){
        var active = (i === geoActiveIdx);
        h += '<div class="awg-geo-tab' + (active?' active':'') + '" onclick="geoSwitchTo(' + i + ')">' +
                 '<span class="awg-geo-tab-name">' + escHtml(geoDecodeName(geoPolicies[i].name)) + '</span>';
        if(active){
            h += '<button type="button" class="awg-geo-tab-edit" title="' + escHtml(T('GEO_TAB_RENAME')) + '" aria-label="' + escHtml(T('GEO_TAB_RENAME')) + '" onclick="event.stopPropagation();geoRenamePolicy(' + i + ')">&#9998;</button>';
            if(geoPolicies.length > 1)
                h += '<button type="button" class="awg-geo-tab-del" title="' + escHtml(T('GEO_TAB_REMOVE')) + '" aria-label="' + escHtml(T('GEO_TAB_REMOVE')) + '" onclick="event.stopPropagation();geoRemovePolicy(' + i + ')">&#10005;</button>';
        }
        h += '</div>';
    }
    if(geoPolicies.length < GEO_MAX_POLICIES)
        h += '<button type="button" class="awg-geo-tab-add" onclick="geoAddPolicy()">' + escHtml(T('GEO_TAB_ADD')) + '</button>';
    bar.innerHTML = h;
    geoRenderStats();
}
// Stats for the ACTIVE tab only (echoes the "Активно: …" route-info format):
// "X диапазонов IP · Y доменов". Numbers come from the status poll (awgGeoStats, keyed by
// policy id); switching tabs re-renders this for the newly-active policy.
var awgGeoStats = {};
function geoRenderStats(){
    var box = document.getElementById('geo_stats');
    if(!box) return;
    if(geoActiveIdx < 0 || geoActiveIdx >= geoPolicies.length){ box.textContent = ''; return; }
    var st = awgGeoStats[String(geoPolicies[geoActiveIdx].id)] || {};
    box.textContent = T('RULES_IPRANGES', st.ip || 0) + ' · ' + T('RULES_DOMAINS', st.dom || 0);
}
function geoSwitchTo(idx){
    if(idx === geoActiveIdx || idx < 0 || idx >= geoPolicies.length) return;
    geoCaptureActive();
    geoActiveIdx = idx;
    geoRenderActive();
    geoRenderTabs();
}
function geoAddPolicy(){
    geoCaptureActive();
    if(geoPolicies.length >= GEO_MAX_POLICIES){ alert(T('GEO_MAX_REACHED', GEO_MAX_POLICIES)); return; }
    var id = geoNextId();
    geoPolicies.push({ id:id, name:encodeURIComponent(T('GEO_TAB_DEFAULT_NAME', id)),
        v2fly:'', v2flyIp:'', customDomains:'', customIps:'', files:'', urls:'', antifilter:'',
        mode:'vpn', excDomains:'', excIps:'', excFiles:'', excUrls:'' });
    geoActiveIdx = geoPolicies.length - 1;
    geoRenderActive();
    geoRenderTabs();
    refreshPolicyDropdowns();
}
function geoRemovePolicy(idx){
    if(geoPolicies.length <= 1 || idx < 0 || idx >= geoPolicies.length) return;
    var p = geoPolicies[idx];
    if(!confirm(T('GEO_TAB_REMOVE_CONFIRM', geoDecodeName(p.name)))) return;
    geoCaptureActive();
    geoPolicies.splice(idx, 1);
    if(geoActiveIdx >= geoPolicies.length) geoActiveIdx = geoPolicies.length - 1;
    if(geoActiveIdx < 0) geoActiveIdx = 0;
    geoRenderActive();
    geoRenderTabs();
    refreshPolicyDropdowns();   // selects pointing at the removed ref fall back to Direct
    updateGeoVisibility();
}
function geoRenamePolicy(idx){
    if(idx < 0 || idx >= geoPolicies.length) return;
    var nn = prompt(T('GEO_TAB_RENAME_PROMPT'), geoDecodeName(geoPolicies[idx].name));
    if(nn === null) return;
    nn = nn.replace(/\s+/g, ' ').trim().slice(0, 24);
    if(!nn) return;
    geoPolicies[idx].name = encodeURIComponent(nn);
    geoRenderTabs();
    refreshPolicyDropdowns();
}
// Build geoPolicies[] from custom_settings (registry + per-policy keys). Default = one "Geo" tab.
function geoHydratePolicies(){
    geoPolicies = [];
    geoLoadedIds = [];
    var reg = custom_settings.awg_geo_policies || '', list = [];
    if(reg){
        var ents = reg.split(';');
        for(var i=0;i<ents.length;i++){
            if(!ents[i]) continue;
            var ci = ents[i].indexOf(':');
            var id = parseInt(ci < 0 ? ents[i] : ents[i].slice(0, ci), 10);
            var nm = ci < 0 ? '' : ents[i].slice(ci + 1);
            if(!isNaN(id)) list.push({ id:id, name:nm });
        }
    }
    if(!list.length) list.push({ id:1, name:encodeURIComponent(T('GEO_TAB_DEFAULT')) });
    for(var k=0;k<list.length;k++){
        var pid = list[k].id;
        geoLoadedIds.push(pid);
        var vip = custom_settings[geoKeyJs(pid,'v2fly_ip')] || '';
        if(!vip && pid === 1) vip = v2flyIpList.join(',');   // legacy default-display for policy 1
        geoPolicies.push({
            id: pid,
            name: list[k].name || encodeURIComponent(pid === 1 ? T('GEO_TAB_DEFAULT') : T('GEO_TAB_DEFAULT_NAME', pid)),
            v2fly: custom_settings[geoKeyJs(pid,'v2fly')] || '',
            v2flyIp: vip,
            customDomains: custom_settings[geoKeyJs(pid,'custom_domains')] || '',
            customIps: custom_settings[geoKeyJs(pid,'custom_ips')] || '',
            files: custom_settings[geoKeyJs(pid,'custom_files')] || '',
            urls: custom_settings[geoKeyJs(pid,'custom_urls')] || '',
            antifilter: custom_settings[geoKeyJs(pid,'antifilter_lists')] || '',
            mode: (custom_settings[geoKeyJs(pid,'mode')] === 'direct') ? 'direct' : 'vpn',
            excDomains: custom_settings[geoKeyJs(pid,'exc_domains')] || '',
            excIps: custom_settings[geoKeyJs(pid,'exc_ips')] || '',
            excFiles: custom_settings[geoKeyJs(pid,'exc_files')] || '',
            excUrls: custom_settings[geoKeyJs(pid,'exc_urls')] || ''
        });
    }
    geoActiveIdx = 0;
}
// Serialize geoPolicies[] back into custom_settings; returns false if the files budget is blown.
function geoSerializePolicies(){
    geoCaptureActive();
    var totalFiles = 0, gp, p, suf, si;
    var sufs = ['v2fly','v2fly_ip','custom_domains','custom_ips','custom_files','custom_urls','antifilter_lists',
                'mode','exc_domains','exc_ips','exc_files','exc_urls'];
    for(gp=0; gp<geoPolicies.length; gp++){
        p = geoPolicies[gp];
        totalFiles += (p.files || '').length + (p.excFiles || '').length;
        custom_settings[geoKeyJs(p.id,'v2fly')] = p.v2fly || '';
        custom_settings[geoKeyJs(p.id,'v2fly_ip')] = p.v2flyIp || '';
        custom_settings[geoKeyJs(p.id,'custom_domains')] = p.customDomains || '';
        custom_settings[geoKeyJs(p.id,'custom_ips')] = p.customIps || '';
        custom_settings[geoKeyJs(p.id,'custom_files')] = p.files || '';
        custom_settings[geoKeyJs(p.id,'custom_urls')] = p.urls || '';
        custom_settings[geoKeyJs(p.id,'antifilter_lists')] = p.antifilter || '';
        custom_settings[geoKeyJs(p.id,'mode')] = (p.mode === 'direct') ? 'direct' : 'vpn';
        custom_settings[geoKeyJs(p.id,'exc_domains')] = p.excDomains || '';
        custom_settings[geoKeyJs(p.id,'exc_ips')] = p.excIps || '';
        custom_settings[geoKeyJs(p.id,'exc_files')] = p.excFiles || '';
        custom_settings[geoKeyJs(p.id,'exc_urls')] = p.excUrls || '';
    }
    custom_settings.awg_geo_policies = geoPolicies.map(function(x){ return x.id + ':' + x.name; }).join(';');
    // Free the settings budget: blank keys of policies that existed at load but were removed.
    for(var li=0; li<geoLoadedIds.length; li++){
        var oid = geoLoadedIds[li];
        if(geoPolicyIndexById(oid) === -1){
            for(si=0; si<sufs.length; si++) custom_settings[geoKeyJs(oid,sufs[si])] = '';
        }
    }
    // Budget guard: across N policies the per-policy keys (domains/IPs/URLs/files/antifilter)
    // add up, and Merlin silently truncates a POST body over ~64 KB. Check the WHOLE serialized
    // store (not just files) against the same ~52000-char cap the upload path uses, so a stack
    // of large lists across tabs can't corrupt settings on Apply. (Files keep their own message.)
    if(totalFiles > 40000){ alert(T('MSG_GEO_FILES_TOO_BIG')); return false; }
    try {
        if(encodeURIComponent(JSON.stringify(custom_settings)).length > 50000){
            alert(T('MSG_GEO_FILES_TOO_BIG')); return false;
        }
    } catch(e){}
    return true;
}

// Populate the analyzer modal's "add to geo policy" picker (placeholder + one per policy),
// preserving the current selection if it still exists.
function geoFillAnalyzePicker(){
    var sel = document.getElementById('awg_an_policy');
    if(!sel) return;
    var prev = sel.value;
    var h = '<option value="">' + escHtml(T('ANALYZE_PICK_POLICY')) + '</option>';
    for(var i=0;i<geoPolicies.length;i++){
        h += '<option value="' + geoPolicies[i].id + '">' + escHtml(T('OPT_VPN_GEO_PREFIX') + geoDecodeName(geoPolicies[i].name)) + '</option>';
    }
    sel.innerHTML = h;
    if(prev && geoPolicyIndexById(parseInt(prev, 10)) !== -1) sel.value = prev; else sel.value = '';
}
// Merge comma-separated items into an existing CSV string (case-insensitive dedup).
function geoMergeCsv(existing, items){
    var have = {}, out = [], added = 0, i;
    var cur = String(existing || '').split(',').map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    for(i=0;i<cur.length;i++){ have[cur[i].toLowerCase()] = true; out.push(cur[i]); }
    for(i=0;i<items.length;i++){
        var it = String(items[i]).trim(); if(!it) continue;
        var lk = it.toLowerCase(); if(have[lk]) continue;
        have[lk] = true; out.push(it); added++;
    }
    return { value: out.join(','), added: added };
}
// Add captured domains/IPs into one policy's custom-domains/IPs (used by the analyzer).
function geoAddToPolicy(pidx, domains, ips){
    if(pidx < 0 || pidx >= geoPolicies.length) return { nDom:0, nIp:0 };
    geoCaptureActive();   // don't lose unsaved edits in the visible tab
    var p = geoPolicies[pidx];
    var rd = geoMergeCsv(p.customDomains, domains);
    var ri = geoMergeCsv(p.customIps, ips);
    p.customDomains = rd.value;
    p.customIps = ri.value;
    if(pidx === geoActiveIdx) geoRenderActive();   // reflect into the visible fields
    return { nDom: rd.added, nIp: ri.added };
}

// === GeoIP / GeoSite ===

function loadGeoSettings(){
    // Geo policies (tabs): build the model from settings, then render the active tab,
    // the tab bar and every policy dropdown. Per-policy fields (GeoIP/GeoSite/GeoCustom/
    // Antifilter) are filled by geoRenderActive for the active tab.
    geoHydratePolicies();
    geoRenderActive();
    geoRenderTabs();
    refreshPolicyDropdowns();
    // Auto-update
    var au = document.getElementById('geo_autoupdate');
    if(au) au.checked = (custom_settings.awg_geo_autoupdate === '1');
    // Block IPv6 DNS (default on)
    var b6 = document.getElementById('awg_block_ipv6_dns');
    if(b6) b6.checked = (custom_settings.awg_block_ipv6_dns !== '0');
    // Compatibility mode: don't hijack :53 DNS. Seeded ON for brand-new installs (the .ipk
    // postinst writes awg_no_dns_intercept 1 when no awg_* settings exist yet); existing
    // installs default off. Backend also auto-skips when a DPI tool (zapret/Xray/b4/NFQUEUE/
    // nft-queue) is detected.
    var ndi = document.getElementById('awg_no_dns_intercept');
    if(ndi) ndi.checked = (custom_settings.awg_no_dns_intercept === '1');
    // Kill-switch (default off — preserves prior fail-open behavior unless the user opts in)
    var ks = document.getElementById('awg_killswitch');
    if(ks) ks.checked = (custom_settings.awg_killswitch === '1');
    // Wait-for-AdGuardHome on autostart (only meaningful/visible on AGH boxes; default off).
    var wfa = document.getElementById('awg_wait_for_agh');
    if(wfa) wfa.checked = (custom_settings.awg_wait_for_agh === '1');
    var sd = document.getElementById('awg_start_delay');
    if(sd) sd.value = (custom_settings.awg_start_delay && custom_settings.awg_start_delay !== '0') ? custom_settings.awg_start_delay : '';
    // Watchdog probe hosts (empty = backend default 8.8.8.8 1.1.1.1)
    var wh = document.getElementById('awg_watchdog_hosts');
    if(wh) wh.value = custom_settings.awg_watchdog_hosts || '';
    var wp = document.getElementById('awg_geo_wipe_update');
    if(wp) wp.checked = (custom_settings.awg_geo_wipe_update === '1');
    var ipn = document.getElementById('awg_ipset_name');
    if(ipn) ipn.value = custom_settings.awg_ipset_name || '';
    // Download-via-VPN toggles (default off)
    var gva = document.getElementById('awg_geo_via_awg');
    if(gva) gva.checked = (custom_settings.awg_geo_via_awg === '1');
    var uva = document.getElementById('awg_update_via_awg');
    if(uva) uva.checked = (custom_settings.awg_update_via_awg === '1');
    // (Antifilter checkboxes + GeoIP/GeoSite/GeoCustom fields are set per-policy by geoRenderActive.)
}

function updateGeoLists(){
    if(awgGeoBusy) return;
    var btn = document.getElementById('btn_geo_update');
    var isDownload = btn && btn.value === T('BTN_GEO_DOWNLOAD');
    var msg = isDownload
        ? T('MSG_DOWNLOAD_LISTS_CONFIRM')
        : T('MSG_REDOWNLOAD_LISTS_CONFIRM');
    var wipe = document.getElementById('awg_geo_wipe_update');
    if(wipe && wipe.checked){
        msg += T('MSG_WIPE_BEFORE_UPDATE');
    }
    if(!confirm(msg)) return;
    // Capture the geo policies (incl. a just-added tab + unsaved active-tab edits) into
    // custom_settings, so the backend downloads the CURRENT matrix, not the last-Applied one.
    if(!geoSerializePolicies()) return;
    var log = document.getElementById('awg_log');
    if(log) log.textContent = T('MSG_GEO_LOADING_WAIT');
    awgSetGeoBusy(true);
    // Carry the current "download via VPN" choice even without a prior Apply.
    syncViaVpnToggles();
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = "start_awgupdategeo";
    awgSubmitForm();
    // No reload: geo progress and result show live in the log + status via polling.
}

// Geo update takes 1-2 min. Disable the button + show a loading label so it isn't re-triggered;
// updateStatusUI clears it when the backend reports geo_busy=false, with a safety timeout
// so we always recover even if that flag never arrives.
var awgGeoBusy = false;
var awgGeoBusySeen = false;   // observed the backend's geo_busy=true yet? (race guard)
var awgGeoBusyTimer = null;
function awgSetGeoBusy(busy){
    awgGeoBusy = busy;
    if(busy) awgGeoBusySeen = false;
    var btn = document.getElementById('btn_geo_update');
    if(btn){ btn.disabled = busy; if(busy) btn.value = T('BTN_GEO_LOADING'); }
    if(awgGeoBusyTimer){ clearTimeout(awgGeoBusyTimer); awgGeoBusyTimer = null; }
    if(busy) awgGeoBusyTimer = setTimeout(function(){ awgSetGeoBusy(false); }, 180000);
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
                        var _mac = c.mac || key || '';
                        var _nm = c.nickName || c.name || '';
                        if(_nm === _mac || _nm === key) _nm = '';   // no real name -> don't just repeat the MAC
                        lines.push({ip: c.ip, mac: _mac, name: _nm});
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
    var input = prompt(T('MSG_DHCP_FAILED'));
    if(input) addManualIPs(input);
}

// Real selection UI (replaces the old numbered prompt()): a checkbox list of DHCP clients
// with one shared policy, rendered as a lightweight overlay.
var awgDhcpClients = [];
function showClientPicker(clients){
    awgCloseDhcp();
    awgDhcpClients = clients;
    var rows = '<div style="display:flex; align-items:center; gap:10px; padding:4px 4px; border-bottom:1px solid #555; font-size:11px; text-transform:uppercase; color:#b6bdc7; letter-spacing:0.5px;">' +
               '<span style="width:13px; flex:0 0 auto;"></span>' +
               '<span style="min-width:115px; flex:0 0 auto; text-align:center;">' + escHtml(T('DHCP_COL_IP')) + '</span>' +
               '<span style="min-width:140px; flex:0 0 auto; text-align:center;">MAC</span>' +
               '<span style="flex:1; text-align:center;">' + escHtml(T('DHCP_COL_NAME')) + '</span>' +
               '</div>';
    for(var i = 0; i < clients.length; i++){
        rows += '<label class="awg-dhcp-row" style="display:flex; align-items:center; gap:10px; padding:6px 4px; border-bottom:1px solid #3a4548;">' +
                '<input type="checkbox" class="awg-dhcp-cb" value="' + i + '" onchange="awgDhcpToggleRow(this);">' +
                '<span style="font-family:monospace; min-width:115px; flex:0 0 auto; text-align:center;">' + escHtml(clients[i].ip) + '</span>' +
                '<span style="font-family:monospace; min-width:140px; flex:0 0 auto; color:#9aa3ad; text-align:center;">' + escHtml(clients[i].mac) + '</span>' +
                '<span style="flex:1; text-align:center; color:#b6bdc7; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + (clients[i].name ? escHtml(clients[i].name) : '<span style="opacity:0.45;">—</span>') + '</span>' +
                '</label>';
    }
    var ov = document.createElement('div');
    ov.id = 'awg_dhcp_modal';
    ov.setAttribute('role', 'dialog');
    ov.setAttribute('aria-modal', 'true');
    ov.setAttribute('aria-label', T('ARIA_DHCP_PICK'));
    ov.style.cssText = 'position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.65); z-index:10001;';
    ov.innerHTML =
        '<div style="background:#2b3338; color:#e0e0e0; width:90%; max-width:520px; margin:6% auto; border:1px solid #444; border-radius:8px; display:flex; flex-direction:column; max-height:80vh;">' +
            '<div style="padding:12px 16px; border-bottom:1px solid #444; display:flex; align-items:center;">' +
                '<span style="font-weight:bold;">' + escHtml(T('DHCP_TITLE')) + '</span>' +
                '<button type="button" aria-label="' + escHtml(T('ARIA_CLOSE')) + '" onclick="awgCloseDhcp();" style="margin-left:auto; background:transparent; border:none; color:inherit; font-size:22px; cursor:pointer;">&times;</button>' +
            '</div>' +
            '<div style="padding:8px 16px; overflow:auto; font-size:12px;">' + rows + '</div>' +
            '<div style="padding:10px 16px; border-top:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:8px;">' +
                '<span style="font-size:12px;">' + escHtml(T('DHCP_POLICY_LABEL')) + '</span>' +
                '<select id="awg_dhcp_policy" class="awg-modal-input" aria-label="' + escHtml(T('ARIA_DHCP_POLICY')) + '">' +
                    geoPolicyOptionsHtml('vpn_all') +
                '</select>' +
                '<input type="button" class="button_gen" value="' + escHtml(T('DHCP_ADD_SELECTED')) + '" onclick="awgAddDhcpSelected();" style="margin-left:auto;">' +
            '</div>' +
        '</div>';
    document.body.appendChild(ov);
    document.addEventListener('keydown', awgDhcpKeydown);
}
function awgDhcpKeydown(e){ if(e.key === 'Escape' || e.keyCode === 27) awgCloseDhcp(); }
function awgDhcpToggleRow(cb){
    var row = cb.parentNode;   // the <label> wrapping the checkbox + cells
    if(!row) return;
    if(cb.checked){ if(row.className.indexOf('sel') === -1) row.className += ' sel'; }
    else { row.className = row.className.replace(/\s*\bsel\b/, ''); }
}
function awgCloseDhcp(){
    var ov = document.getElementById('awg_dhcp_modal');
    if(ov) ov.parentNode.removeChild(ov);
    document.removeEventListener('keydown', awgDhcpKeydown);
}
function awgAddDhcpSelected(){
    var pol = (document.getElementById('awg_dhcp_policy') || {}).value || 'vpn_all';
    var cbs = document.querySelectorAll('.awg-dhcp-cb');
    for(var i = 0; i < cbs.length; i++){
        if(cbs[i].checked){
            var c = awgDhcpClients[parseInt(cbs[i].value, 10)];
            if(c) addClientRow(c.ip, c.name, pol);
        }
    }
    awgCloseDhcp();
}

function addManualIPs(input){
    var ips = input.split(',');
    for(var i = 0; i < ips.length; i++){
        var ip = ips[i].trim();
        if(ip) addClientRow(ip, '', 'vpn_all');
    }
}

// Notify the header widget (a separate script — same window, or the parent window when the
// addon runs inside the firmware's iframe UI) the instant we initiate an action, so its icon
// reacts in lockstep with our buttons instead of lagging its own 10s poll. kind:
// 'start'|'stop'|'restart' mirror the transition; 'refresh' is a light fast-probe after Apply.
function awgSignalWidget(kind){
    try {
        var wins = [window, window.parent, window.top];
        for(var i = 0; i < wins.length; i++){
            var w = wins[i];
            if(w && typeof w.awgWidgetSignal === 'function'){ w.awgWidgetSignal(kind); return; }
        }
    } catch(e){}
}

// Recover from a wedged transition (router unreachable for the whole ~180s action window): land
// on a clean, clickable «Запустить» and resume the steady poll. setOfflineUI() resets BOTH
// style.display AND disabled — essential now that the stop branch HIDES the buttons (a bare
// disabled=false would leave them display:none, stranding the page with no clickable control).
// The immediate awgRefreshStatus() lets a router that just came back correct the UI at once.
function awgActionRecover(pollId){
    clearInterval(pollId);
    setOfflineUI();
    if(!statusTimer) statusTimer = setInterval(awgRefreshStatus, 5000);
    awgRefreshStatus();
}

function awgAction(action){
    document.form.action_script.value = action;
    awgSubmitForm();
    var kind = action.indexOf('stop') !== -1 ? 'stop' : (action.indexOf('restart') !== -1 ? 'restart' : 'start');
    // Flip the header widget's icon in the same frame as our buttons (it polls independently).
    awgSignalWidget(kind);
    // Drive the page's own status block into the transitional state + poll to completion.
    awgEnterTransition(kind);
}

// Move the page's status badge/buttons into the transitional state for `kind`
// ('start'|'stop'|'restart') and poll until the backend settles. Split out of awgAction so it can
// run WITHOUT (re)firing the action — that's how a widget-initiated start/stop flips THIS page in
// lockstep (see window.awgPageSignal) instead of lagging up to one 5s steady poll.
function awgEnterTransition(kind){
    var badge = document.getElementById('awg_badge');
    var isStop = (kind === 'stop');
    var expect = !isStop;

    // Stop periodic refresh and any prior in-flight action poll
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
    if(awgPoll){ clearInterval(awgPoll); awgPoll = null; }
    // Supersede any status read still in flight (steady refresh or a prior action poll) so its
    // pre-click result can't repaint the UI after we've shown the transitional state below.
    awgActionGen++;
    var myGen = awgActionGen;
    var sBtn = document.getElementById('btn_start');
    var pBtn = document.getElementById('btn_stop');
    var rBtn = document.getElementById('btn_restart');
    // Any transition (start / stop / restart) — collapse the actions row to just the badge: hide
    // every button. The phase is short and there's nothing useful to offer mid-transition;
    // «Отменить» is intentionally gone (per request). The steady poll keeps them hidden until the
    // backend settles, then shows the right control («Запустить» or «Остановить»/«Перезапустить»).
    sBtn.style.display = pBtn.style.display = rBtn.style.display = 'none';

    // Show transitional status
    badge.className = 'awg-status connecting';
    badge.innerHTML = isStop ? ('&#9679; ' + escHtml(T('STAT_STOPPING'))) : ('&#9679; ' + escHtml(T('STAT_CONNECTING')));

    // Poll until status is fully ready
    var attempts = 0;
    var poll = setInterval(function(){
        attempts++;
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
        xhr.timeout = 3000;
        xhr.onload = function(){
            // A newer action superseded this poll — abandon it (the new action owns the UI).
            if(myGen !== awgActionGen){ clearInterval(poll); return; }
            try {
                var s = JSON.parse(xhr.responseText);
                // Resolve only when the backend reports the expected final state AND no transition
                // flag is still set. The !starting/!stopping guard is what makes «Перезапустить»
                // safe: a restart is do_stop→do_start, and the pre-teardown running=true (still ===
                // expect=true) would otherwise resolve us instantly, hand the UI to the steady poll,
                // which then catches the brief fully-stopped moment and shows a clickable «Запустить».
                var ready = (s.running === expect && !s.starting && !s.stopping);
                if(ready || attempts >= 90){
                    clearInterval(poll);
                    updateStatusUI(s);
                    statusTimer = setInterval(awgRefreshStatus, 5000);
                    document.getElementById('btn_start').disabled = false;
                    document.getElementById('btn_stop').disabled = false;
                    document.getElementById('btn_restart').disabled = false;
                }
            } catch(e){
                if(attempts >= 90){ awgActionRecover(poll); }
            }
        };
        xhr.onerror = function(){ if(myGen !== awgActionGen){ clearInterval(poll); return; } if(attempts >= 90){ awgActionRecover(poll); } };
        // Without an ontimeout, a router that only times out (typical while a half-started
        // tunnel is breaking routing/DNS) never reaches the attempts>=90 recovery and the
        // poll wedges forever — leaving the page stuck mid-transition. Mirror onerror.
        xhr.ontimeout = function(){ if(myGen !== awgActionGen){ clearInterval(poll); return; } if(attempts >= 90){ awgActionRecover(poll); } };
        xhr.send();
    }, 2000);
    awgPoll = poll;
}

// Called by the header widget when ITS button starts an action, so this page's status block flips
// in lockstep instead of waiting up to one 5s steady poll. The widget already POSTed the action —
// we only mirror the UI and take over polling. Wrapped so a thrown error can't break the widget.
window.awgPageSignal = function(kind){ try { awgEnterTransition(kind); } catch(e){} };

function showLoading(){}
function hideLoading(){}

// Generic clipboard copy. The router UI is usually plain HTTP, where navigator.clipboard is
// unavailable (and a delayed write loses user-activation) — fall back to a hidden-textarea
// execCommand, which is the workhorse here.
function awgCopyText(text, done){
    if(navigator.clipboard && navigator.clipboard.writeText){
        navigator.clipboard.writeText(text).then(function(){ done(true); }, function(){ awgCopyFallback(text, done); });
    } else {
        awgCopyFallback(text, done);
    }
}
// Footer donation: click the USDT (TRC-20) address to copy it (a 34-char address is
// awkward to select by hand). Briefly swaps the text for feedback, then restores it.
function awgCopyAddr(addr, el){
    awgCopyText(addr, function(ok){
        if(!el) return;
        if(el._addr == null) el._addr = el.textContent;
        el.textContent = ok ? T('DONATE_COPIED') : T('DONATE_COPY_FAILED');
        setTimeout(function(){ if(el._addr != null){ el.textContent = el._addr; el._addr = null; } }, 1200);
    });
}
// Diagnostics: the "Get diagnostic data" button triggers the backend diag dump (to a SEPARATE
// file — it does NOT touch the on-page log), waits for [DIAG_DONE], and shows the result in a
// modal. The modal's "Copy diagnostic data" copies the diagnostics PLUS the
// current log, wrapped for Telegram — the copy happens inside the click, so it's reliable.
var awgDiagText = '';
function awgRunDiag(btn){
    if(btn){ if(btn._dlbl == null) btn._dlbl = btn.value; btn.value = T('DIAG_COLLECTING'); btn.disabled = true; }
    awgDiagText = '';
    awgOpenDiag(T('DIAG_COLLECTING_WAIT'));
    // Carry current settings (no-op save) and fire the diag event (does NOT reset the log).
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = 'start_awgdiag';
    awgSubmitForm();
    var t0 = Date.now();
    (function tick(){
        var x = new XMLHttpRequest();
        x.open('GET', '/user/awg_diag.htm?_=' + Date.now(), true);
        x.timeout = 4000;
        x.onload = function(){
            var txt = x.responseText || '';
            if(txt.indexOf('[DIAG_DONE]') !== -1){ awgDiagFinish(btn, txt, false); return; }
            if(Date.now() - t0 > 45000){ awgDiagFinish(btn, txt, true); return; }
            setTimeout(tick, 1500);
        };
        x.onerror = x.ontimeout = function(){
            if(Date.now() - t0 > 45000){ awgDiagFinish(btn, null, true); return; }
            setTimeout(tick, 2000);
        };
        x.send();
    })();
}
function awgDiagFinish(btn, txt, timedOut){
    if(btn){ btn.disabled = false; if(btn._dlbl != null){ btn.value = btn._dlbl; btn._dlbl = null; } }
    var report = String(txt || '').replace(/\[DIAG_DONE\]/g, '').replace(/\s+$/, '');
    awgDiagText = report;
    var body = document.getElementById('awg_diag_body');
    if(body){
        body.textContent = report || (timedOut ? T('DIAG_TIMEOUT') : T('DIAG_EMPTY'));
        body.scrollTop = 0;
    }
    var note = document.getElementById('awg_diag_note');
    if(note) note.textContent = (timedOut && report) ? T('DIAG_TIMEOUT_NOTE') : '';
}
// Diagnostics modal open/close (+ Esc).
var awgDiagPrevFocus = null;
function awgOpenDiag(placeholder){
    var m = document.getElementById('awg_diag_modal');
    if(!m) return;
    var body = document.getElementById('awg_diag_body');
    if(body) body.textContent = placeholder || '';
    var note = document.getElementById('awg_diag_note');
    if(note) note.textContent = '';
    m.style.display = 'block';
    awgDiagPrevFocus = document.activeElement;
    document.addEventListener('keydown', awgDiagKeydown);
}
function awgCloseDiag(){
    var m = document.getElementById('awg_diag_modal');
    if(m) m.style.display = 'none';
    document.removeEventListener('keydown', awgDiagKeydown);
    if(awgDiagPrevFocus){ try { awgDiagPrevFocus.focus(); } catch(e){} awgDiagPrevFocus = null; }
}
function awgDiagKeydown(e){ if(e.key === 'Escape' || e.keyCode === 27) awgCloseDiag(); }

// ---- Per-device traffic analysis modal (Start/Stop + live request log) ----
// Fires awganalyzestart/awganalyzestop (same form/service-event channel as diagnostics) and
// polls /user/awg_analyze.htm for the live stream the backend captures (conntrack flows named
// from a temporary dnsmasq query log, with a Direct/VPN verdict per request).
var awgAnalyzeIp = '';
var awgAnalyzeActive = false;
var awgAnalyzeTimer = null;
var awgAnalyzePrevFocus = null;
var awgAnalyzeSel = {};   // checked-row map (key -> {dom, ip}); survives the 1.5 s re-render

function awgPolicyLabel(p){
    if(p === 'vpn_all') return T('OPT_VPN_ALL');
    if(p && p.indexOf('vpn_geo') === 0){
        var idx = geoPolicyIndexById(geoRefId(p));
        if(idx !== -1) return T('OPT_VPN_GEO_PREFIX') + geoDecodeName(geoPolicies[idx].name);
        return T('OPT_VPN_GEO');
    }
    if(p === 'direct')  return T('OPT_DIRECT');
    return '—';
}
function awgVerdictInfo(v){
    if(v === 'vpn')     return { cls:'vpn',     label:T('VERDICT_VPN') };
    if(v === 'geo')     return { cls:'geo',     label:T('VERDICT_GEO') };
    if(v === 'pending') return { cls:'pending', label:T('VERDICT_PENDING') };
    return                { cls:'direct',  label:T('VERDICT_DIRECT') };
}
function awgRowOf(el){
    if(el.closest) return el.closest('tr');
    var n = el; while(n && n.tagName !== 'TR') n = n.parentNode; return n;
}
function awgAnalyzeShowEmpty(msg){
    var t = document.getElementById('awg_analyze_table');
    var e = document.getElementById('awg_analyze_empty');
    if(msg){ if(t) t.style.display='none'; if(e){ e.style.display='block'; e.textContent = msg; } }
    else   { if(t) t.style.display='';     if(e){ e.style.display='none';  e.textContent = ''; } }
}
function awgAnalyzeSetToggle(active){
    var b = document.getElementById('awg_analyze_toggle');
    if(b) b.value = active ? T('ANALYZE_STOP') : T('ANALYZE_START');
}
// IP -> {mac,name} map from the firmware client list (same get_clientlist() hook the
// device picker uses). Fetched once on first need and cached for the page lifetime; the
// MAC for a given IP is stable enough across a diagnostic session. Offline/unknown IPs
// simply resolve to no MAC.
var awgMacMap = null;          // null = not loaded; object once fetched (possibly empty)
var awgMacMapPending = false;
var awgMacMapWaiters = [];
function awgLoadMacMap(cb){
    if(awgMacMap){ cb(awgMacMap); return; }
    awgMacMapWaiters.push(cb);
    if(awgMacMapPending) return;
    awgMacMapPending = true;
    var done = function(map){
        awgMacMap = map || {};
        awgMacMapPending = false;
        var ws = awgMacMapWaiters; awgMacMapWaiters = [];
        for(var i = 0; i < ws.length; i++){ try { ws[i](awgMacMap); } catch(e){} }
    };
    var x = new XMLHttpRequest();
    x.open('GET', '/appGet.cgi?hook=get_clientlist()&_=' + Date.now(), true);
    x.timeout = 4000;
    x.onload = function(){
        var map = {};
        try {
            var data = JSON.parse(x.responseText);
            var cl = data.get_clientlist || data;
            for(var key in cl){
                if(!cl.hasOwnProperty(key)) continue;
                var c = cl[key];
                if(c && typeof c === 'object' && c.ip){
                    map[c.ip] = { mac: (c.mac || key || ''), name: (c.nickName || c.name || '') };
                }
            }
        } catch(e){}
        done(map);
    };
    x.onerror = function(){ done({}); };
    x.ontimeout = function(){ done({}); };
    x.send();
}
// Render the device identity in the modal header: custom name (or IP) as the title,
// IP and/or MAC on the muted subtitle. IP is shown in the subtitle only when the title
// already carries the custom name, so it never appears twice.
function awgAnalyzeSetIdentity(name, ip, mac){
    var title = document.getElementById('awg_analyze_title');
    if(title) title.textContent = T('ANALYZE_MODAL_TITLE', name || ip);
    var sub = document.getElementById('awg_analyze_sub');
    if(sub){
        var parts = [];
        if(name) parts.push(ip);
        if(mac)  parts.push(mac);
        sub.textContent = parts.join(' · ');
    }
}
function awgOpenAnalyze(btn){
    var tr = awgRowOf(btn);
    var ipEl = tr ? tr.querySelector('.client_ip') : null;
    var ip = ipEl ? String(ipEl.value || '').trim() : '';
    if(!ip){ alert(T('ANALYZE_NEED_IP')); return; }
    var nameEl = tr ? tr.querySelector('.client_name') : null;
    var name = nameEl ? String(nameEl.value || '').trim() : '';
    var polEl = tr ? tr.querySelector('.client_policy') : null;
    awgAnalyzeIp = ip;
    var m = document.getElementById('awg_analyze_modal');
    if(!m) return;
    awgAnalyzeSetIdentity(name, ip, '');   // immediate; MAC filled in once the client list loads
    awgLoadMacMap(function(map){
        if(awgAnalyzeIp !== ip) return;    // user moved on to another device meanwhile
        var info = map[ip];
        awgAnalyzeSetIdentity(name, ip, info && info.mac ? info.mac : '');
    });
    var polBox = document.getElementById('awg_analyze_policy');
    if(polBox) polBox.textContent = awgPolicyLabel(polEl ? polEl.value : '');
    // Seed the "add to geo policy" picker: default to the device's OWN geo policy if it's on
    // one; otherwise leave it on the placeholder so the user must choose before adding.
    geoFillAnalyzePicker();
    var devRef = polEl ? polEl.value : '';
    var anSel = document.getElementById('awg_an_policy');
    if(anSel){
        if(devRef && devRef.indexOf('vpn_geo') === 0 && geoPolicyIndexById(geoRefId(devRef)) !== -1)
            anSel.value = String(geoRefId(devRef));
        else
            anSel.value = '';
    }
    var rows = document.getElementById('awg_analyze_rows');
    if(rows) rows.innerHTML = '';
    awgAnalyzeSel = {};   // fresh selection per modal session
    awgAnalyzeClearAck();
    awgAnalyzeSyncSelAll();
    awgAnalyzeActive = false;
    awgAnalyzeSetToggle(false);
    awgAnalyzeShowEmpty(T('ANALYZE_NO_DATA'));
    m.style.display = 'block';
    awgAnalyzePrevFocus = document.activeElement;
    document.addEventListener('keydown', awgAnalyzeKeydown);
    awgAnalyzeResumeCheck();   // resume display if a capture for this device is already running
}
function awgAnalyzeResumeCheck(){
    var x = new XMLHttpRequest();
    x.open('GET', '/user/awg_analyze.htm?_=' + Date.now(), true);
    x.timeout = 3000;
    x.onload = function(){
        if(x.status !== 200 || !x.responseText) return;
        var data; try { data = JSON.parse(x.responseText); } catch(e){ return; }
        if(data && data.active && data.device === awgAnalyzeIp){
            awgAnalyzeActive = true;
            awgAnalyzeSetToggle(true);
            if(awgAnalyzeTimer) clearInterval(awgAnalyzeTimer);
            awgAnalyzeTimer = setInterval(awgAnalyzePoll, 1500);
            awgAnalyzeRender(data);
        }
    };
    x.send();
}
function awgAnalyzeToggle(){
    if(awgAnalyzeActive) awgAnalyzeStop(); else awgAnalyzeStart();
}
function awgAnalyzeStart(){
    if(!awgAnalyzeIp) return;
    custom_settings.awg_analyze_device = awgAnalyzeIp;
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = 'start_awganalyzestart';
    awgSubmitForm();
    awgAnalyzeActive = true;
    awgAnalyzeSetToggle(true);
    var rows = document.getElementById('awg_analyze_rows');
    if(rows) rows.innerHTML = '';
    awgAnalyzeShowEmpty(T('ANALYZE_WAITING'));
    if(awgAnalyzeTimer) clearInterval(awgAnalyzeTimer);
    awgAnalyzeTimer = setInterval(awgAnalyzePoll, 1500);
    setTimeout(awgAnalyzePoll, 700);
}
function awgAnalyzeStop(){
    document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
    document.form.action_script.value = 'start_awganalyzestop';
    awgSubmitForm();
    awgAnalyzeActive = false;
    awgAnalyzeSetToggle(false);
    if(awgAnalyzeTimer){ clearInterval(awgAnalyzeTimer); awgAnalyzeTimer = null; }
    setTimeout(awgAnalyzePoll, 800);   // pick up the final inactive state
}
function awgAnalyzePoll(){
    var x = new XMLHttpRequest();
    x.open('GET', '/user/awg_analyze.htm?_=' + Date.now(), true);
    x.timeout = 3000;
    x.onload = function(){
        if(x.status !== 200 || !x.responseText) return;
        var data; try { data = JSON.parse(x.responseText); } catch(e){ return; }
        awgAnalyzeRender(data);
    };
    x.send();
}
function awgAnalyzeRender(data){
    if(!data) return;
    if(data.device && awgAnalyzeIp && data.device !== awgAnalyzeIp) return;   // stale file, other device
    var polBox = document.getElementById('awg_analyze_policy');
    if(polBox && data.policy) polBox.textContent = awgPolicyLabel(data.policy);
    if(awgAnalyzeActive && data.active === false){   // backend auto-stopped (timeout)
        awgAnalyzeActive = false;
        awgAnalyzeSetToggle(false);
        if(awgAnalyzeTimer){ clearInterval(awgAnalyzeTimer); awgAnalyzeTimer = null; }
    }
    var entries = (data.entries && data.entries.length) ? data.entries : [];
    var rows = document.getElementById('awg_analyze_rows');
    if(!rows) return;
    if(!entries.length){
        rows.innerHTML = '';
        awgAnalyzeShowEmpty(awgAnalyzeActive ? T('ANALYZE_WAITING') : T('ANALYZE_NO_DATA'));
        return;
    }
    awgAnalyzeShowEmpty(null);
    var html = '';
    for(var i = entries.length - 1; i >= 0; i--){   // newest first
        var e = entries[i] || {};
        var vi = awgVerdictInfo(e.verdict);
        var isDns = (e.proto === 'dns');
        // DNS rows = a resolve request (the intent); connection rows = an actual flow.
        var req = (isDns ? '<span class="awg-dns-tag">DNS</span> ' : '') + escHtml(String(e.name || ''));
        var dest = isDns
            ? (e.ip ? escHtml(String(e.ip)) : '—')
            : (escHtml(String(e.ip || '')) +
               (e.port ? (':' + escHtml(String(e.port))) : '') +
               (e.proto ? (' ' + escHtml(String(e.proto))) : ''));
        // Stable per-row key so checkbox selection survives the 1.5 s re-render.
        var rk = (e.proto || '') + '|' + (e.name || '') + '|' + (e.ip || '') + '|' + (e.port || '');
        var cbChecked = awgAnalyzeSel[rk] ? ' checked' : '';
        html += '<tr>' +
            '<td style="text-align:center;"><input type="checkbox" class="awg-an-cb"' + cbChecked +
                ' data-key="' + escHtml(rk) + '" data-dom="' + escHtml(String(e.name || '')) + '" data-ip="' + escHtml(String(e.ip || '')) +
                '" onclick="awgAnalyzeCbToggle(this);"></td>' +
            '<td class="awg-an-mono">' + escHtml(String(e.t || '')) + '</td>' +
            '<td>' + req + '</td>' +
            '<td class="awg-an-mono">' + dest + '</td>' +
            '<td><span class="awg-verdict ' + vi.cls + '">' + escHtml(vi.label) + '</span></td>' +
            '</tr>';
    }
    rows.innerHTML = html;
    awgAnalyzeSyncSelAll();
}
function awgCloseAnalyze(){
    if(awgAnalyzeActive) awgAnalyzeStop();
    if(awgAnalyzeTimer){ clearInterval(awgAnalyzeTimer); awgAnalyzeTimer = null; }
    var m = document.getElementById('awg_analyze_modal');
    if(m) m.style.display = 'none';
    document.removeEventListener('keydown', awgAnalyzeKeydown);
    if(awgAnalyzePrevFocus){ try { awgAnalyzePrevFocus.focus(); } catch(e){} awgAnalyzePrevFocus = null; }
}
function awgAnalyzeKeydown(e){ if(e.key === 'Escape' || e.keyCode === 27) awgCloseAnalyze(); }

// ---- Analyzer selection → «Свои домены» / «Свои IP» ----
// Tick rows in the analyzer, then "Add selected" pushes each row's domain (if it has one,
// else its IP) into the custom-domains / custom-IPs fields, deduped. Selection lives in
// awgAnalyzeSel so it survives the 1.5 s poll re-render.
function awgAnalyzeCbToggle(cb){
    var k = cb.getAttribute('data-key');
    if(cb.checked){ awgAnalyzeSel[k] = { dom: cb.getAttribute('data-dom') || '', ip: cb.getAttribute('data-ip') || '' }; }
    else { delete awgAnalyzeSel[k]; }
    awgAnalyzeSyncSelAll();
}
function awgAnalyzeToggleAll(master){
    var cbs = document.querySelectorAll('#awg_analyze_rows .awg-an-cb');
    for(var i = 0; i < cbs.length; i++){
        cbs[i].checked = master.checked;
        var k = cbs[i].getAttribute('data-key');
        if(master.checked){ awgAnalyzeSel[k] = { dom: cbs[i].getAttribute('data-dom') || '', ip: cbs[i].getAttribute('data-ip') || '' }; }
        else { delete awgAnalyzeSel[k]; }
    }
}
function awgAnalyzeSyncSelAll(){
    var master = document.getElementById('awg_an_selall');
    if(!master) return;
    var cbs = document.querySelectorAll('#awg_analyze_rows .awg-an-cb');
    var total = cbs.length, checked = 0;
    for(var i = 0; i < cbs.length; i++){ if(cbs[i].checked) checked++; }
    master.checked = (total > 0 && checked === total);
    master.indeterminate = (checked > 0 && checked < total);
}
function awgAnalyzeShowAck(msg, ok){
    var el = document.getElementById('awg_an_ack');
    if(!el) return;
    el.textContent = msg;
    el.className = 'awg-ack show ' + (ok ? 'ok' : 'err');
}
function awgAnalyzeClearAck(){
    var el = document.getElementById('awg_an_ack');
    if(el){ el.textContent = ''; el.className = 'awg-ack'; }
}
// Normalize a captured name to a routable domain, or '' if it's not one (e.g. a bare IP).
function awgCleanDomain(s){
    s = String(s || '').trim().toLowerCase().replace(/^\*\./, '').replace(/\.$/, '');
    if(!s || !/^[a-z0-9._-]+$/.test(s)) return '';
    if(s.indexOf('.') < 0 || !/[a-z]/.test(s)) return '';   // need a dot + a letter (excludes IPs)
    return s;
}
function awgCleanIp(s){
    s = String(s || '').trim();
    if(/^[0-9]{1,3}(\.[0-9]{1,3}){3}(\/[0-9]{1,2})?$/.test(s)) return s;   // IPv4 / CIDR
    if(s.indexOf(':') >= 0 && /^[0-9a-fA-F:.\/]+$/.test(s)) return s;       // IPv6
    return '';
}
// Append items to a comma/newline field, deduped case-insensitively against existing tokens.
function awgMergeIntoField(id, items){
    var el = document.getElementById(id);
    if(!el) return 0;
    var existing = String(el.value || '').split(/[,\n]/).map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    var seen = {};
    for(var i = 0; i < existing.length; i++){ seen[existing[i].toLowerCase()] = true; }
    var added = [];
    for(var j = 0; j < items.length; j++){
        var it = String(items[j]).trim();
        if(!it) continue;
        var lk = it.toLowerCase();
        if(seen[lk]) continue;
        seen[lk] = true;
        added.push(it);
    }
    if(added.length){
        var cur = String(el.value || '').replace(/\s+$/, '');
        el.value = (cur ? cur + '\n' : '') + added.join('\n');
    }
    return added.length;
}
function awgAnalyzeAddSelected(){
    // Which geo policy do the selected requests go into? Default = the device's own policy
    // (seeded on open); if none was pre-selected the user must pick a tab here first.
    var picker = document.getElementById('awg_an_policy');
    var pid = picker ? parseInt(picker.value, 10) : NaN;
    var pidx = isNaN(pid) ? -1 : geoPolicyIndexById(pid);
    if(pidx === -1){ awgAnalyzeShowAck(T('ANALYZE_NEED_POLICY'), false); return; }
    var domains = [], ips = [];
    for(var k in awgAnalyzeSel){
        if(!awgAnalyzeSel.hasOwnProperty(k)) continue;
        var sel = awgAnalyzeSel[k] || {};
        var d = awgCleanDomain(sel.dom);
        if(d){ domains.push(d); }
        else { var ip = awgCleanIp(sel.ip); if(ip) ips.push(ip); }
    }
    if(!domains.length && !ips.length){ awgAnalyzeShowAck(T('ANALYZE_NONE_SELECTED'), false); return; }
    var res = geoAddToPolicy(pidx, domains, ips);
    awgAnalyzeShowAck(T('ANALYZE_ADDED_ACK', res.nDom, res.nIp), true);
    awgAnalyzeSel = {};
    var cbs = document.querySelectorAll('#awg_analyze_rows .awg-an-cb');
    for(var ci = 0; ci < cbs.length; ci++) cbs[ci].checked = false;
    awgAnalyzeSyncSelAll();
}

// "Copy diagnostic data": diagnostics + current log, wrapped for a Telegram post.
function awgCopyDiagReport(btn){
    if(!awgDiagText){ alert(T('DIAG_NOT_READY')); return; }
    var lbox = document.getElementById('awg_log');
    var log = lbox ? String(lbox.textContent || lbox.innerText || '').replace(/\s+$/, '') : '';
    var combined = awgDiagText + (log ? ('\n\n' + T('DIAG_LOG_HEADER') + '\n' + log) : '');
    awgCopyText('```\n' + combined + '\n```', function(ok){
        if(btn){
            if(btn._lbl == null) btn._lbl = btn.value;
            btn.value = ok ? T('DIAG_COPIED') : T('DIAG_COPY_FAILED');
            setTimeout(function(){ if(btn._lbl != null){ btn.value = btn._lbl; btn._lbl = null; } }, 1500);
        }
        alert(ok
            ? T('DIAG_COPIED_ALERT')
            : T('DIAG_COPY_FAILED_ALERT'));
    });
}
function awgCopyFallback(text, done){
    try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.top = '-1000px';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus(); ta.select();
        var ok = document.execCommand('copy');
        document.body.removeChild(ta);
        done(ok);
    } catch(e){ done(false); }
}

// Real-time on-page log: poll the web-readable log the backend writes per action.
function awgRefreshLog(){
    var x = new XMLHttpRequest();
    x.open('GET', '/user/awg_log.htm?_=' + Date.now(), true);
    x.timeout = 3000;
    x.onload = function(){
        if(x.status !== 200 || !x.responseText) return;
        var box = document.getElementById('awg_log');
        if(!box) return;
        var lines = x.responseText.replace(/\[DIAG_DONE\]/g, '').replace(/\s+$/, '').split(/\r?\n/);
        if(lines.length > 80) lines = lines.slice(-80);
        var atBottom = (box.scrollHeight - box.scrollTop - box.clientHeight) < 30;
        box.textContent = awgDecodePct(lines.join('\n'));
        if(atBottom) box.scrollTop = box.scrollHeight;
    };
    x.send();
}

// Watchdog convenience: prefill the probe hosts from the Interface DNS the user already
// entered (so they don't retype IPs). Splits on space/comma, keeps up to 4 entries.
function awgWatchdogFromDns(){
    var wd = document.getElementById('awg_watchdog_hosts');
    if(!wd) return;
    var dns = (document.getElementById('awg_dns') || {}).value || '';
    // Keep only tokens the watchdog backend accepts (IPv4 / hostname). The save path and
    // watchdog_hosts() strip ':' , so an IPv6 DNS (2606:4700:4700::1111) would be silently
    // mangled — drop such tokens here so what we prefill equals what gets stored & probed.
    var hosts = dns.split(/[\s,]+/).filter(function(h){ return /^[0-9A-Za-z][0-9A-Za-z.-]*$/.test(h); }).slice(0, 4).join(' ');
    if(!hosts){ alert(T('MSG_NO_DNS_FOR_WD')); return; }
    wd.value = hosts;
    wd.focus();
}

function awgRefreshStatus(){
    var gen = awgActionGen;
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
    xhr.timeout = 3000;
    xhr.onload = function(){
        // A start/stop/restart action issued after this refresh now owns the UI — drop the stale
        // read so it can't repaint the buttons over the transitional connecting/stopping state.
        if(gen !== awgActionGen) return;
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
    xhr.onerror = function(){ if(gen !== awgActionGen) return; onStatusFail(); };
    xhr.ontimeout = function(){ if(gen !== awgActionGen) return; onStatusFail(); };
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
            b.innerHTML = '&#9679; ' + escHtml(T('STAT_ROUTER_NO_RESPONSE'));
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
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPING'));
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = 'none';
        document.getElementById('btn_restart').style.display = 'none';
    } else if(s.running){
        badge.className = 'awg-status running';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_CONNECTED'));
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = '';
        document.getElementById('btn_stop').value = T('BTN_STOP');
        document.getElementById('btn_restart').style.display = '';
    } else if(s.starting){
        badge.className = 'awg-status connecting';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_CONNECTING'));
        // Connecting — show only the badge, no buttons («Отменить» removed per request).
        document.getElementById('btn_start').style.display = 'none';
        document.getElementById('btn_stop').style.display = 'none';
        document.getElementById('btn_restart').style.display = 'none';
    } else {
        badge.className = 'awg-status stopped';
        badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPED'));
        document.getElementById('btn_start').style.display = '';
        document.getElementById('btn_stop').style.display = 'none';
        document.getElementById('btn_stop').value = T('BTN_STOP');
        document.getElementById('btn_restart').style.display = 'none';
    }

    info.innerHTML = '';
    if(s.interface_addr) info.innerHTML += escHtml(T('INFO_ADDRESS')) + escHtml(s.interface_addr) + '<br>';
    if(s.public_key) info.innerHTML += escHtml(T('INFO_PUBLIC_KEY')) + escHtml(s.public_key.substring(0,12)) + '...<br>';
    if(s.listen_port) info.innerHTML += escHtml(T('INFO_PORT')) + escHtml(s.listen_port) + '<br>';

    // Keep the raw peers for the live handshake ticker (re-read every second).
    awgLastPeers = (s.peers && s.peers.length) ? s.peers : [];

    var html = '';
    if(s.peers && s.peers.length > 0){
        for(var i = 0; i < s.peers.length; i++){
            var p = s.peers[i];
            // Prefer the raw fields the backend now emits; fall back to the pre-formatted
            // strings if they're absent (older status file, e.g. right after an upgrade).
            var rxStr = awgHumanSize(p.rx_bytes); if(rxStr === null) rxStr = p.transfer_rx || '0 B';
            var txStr = awgHumanSize(p.tx_bytes); if(txStr === null) txStr = p.transfer_tx || '0 B';
            var hsStr = awgAgo(p.hs_epoch);       if(hsStr === null) hsStr = p.latest_handshake || T('HS_NEVER');
            html += '<tr>';
            html += '<td>' + escHtml(p.endpoint || '-') + '</td>';
            html += '<td>' + escHtml(p.allowed_ips || '-') + '</td>';
            html += '<td>' + escHtml(rxStr) + ' / ' + escHtml(txStr) + '</td>';
            html += '<td id="awg_hs_' + i + '">' + escHtml(hsStr) + '</td>';
            html += '</tr>';
        }
    }
    peers.innerHTML = html;

    // on-page log is polled in real time via awgRefreshLog() (not from s.log)

    // Route info — aggregate totals across ALL geo policies, in their own row (NOT tied to the
    // default policy). The row label provides the heading, so no inline "Active:" prefix here.
    var rulesEl = document.getElementById('awg_active_rules');
    var rulesRow = document.getElementById('awg_active_row');
    if(s.running){
        var infoParts = [];
        if(s.active_rules > 0) infoParts.push(T('RULES_ROUTING', s.active_rules));
        if(s.ipset_count > 0) infoParts.push(T('RULES_IPRANGES', s.ipset_count));
        if(s.geo_domains > 0) infoParts.push(T('RULES_DOMAINS', s.geo_domains));
        rulesEl.innerHTML = (infoParts.join(' &middot; ') || escHtml(T('NO_RULES')));
        if(rulesRow) rulesRow.style.display = '';
    } else {
        rulesEl.innerHTML = '';
        if(rulesRow) rulesRow.style.display = 'none';
    }
    // Per-tab geo stats (from the backend's per-policy breakdown).
    awgGeoStats = (s && s.geo_stats) || {};
    geoRenderStats();

    // Update geo button text based on database availability — unless a geo download is in
    // flight (then awgSetGeoBusy owns the button). Only clear once we've actually observed
    // geo_busy=true, so a stale "false" right after the click can't end it prematurely.
    if(awgGeoBusy){
        if(s.geo_busy === true) awgGeoBusySeen = true;
        else if(awgGeoBusySeen && s.geo_busy === false) awgSetGeoBusy(false);
    }
    var geoBtn = document.getElementById('btn_geo_update');
    if(geoBtn && !awgGeoBusy){
        geoBtn.disabled = false;
        if(s.geo_downloaded){
            geoBtn.value = T('BTN_GEO_UPDATE_NOW');
        } else {
            geoBtn.value = T('BTN_GEO_DOWNLOAD');
            geoBtn.style.fontWeight = 'bold';
        }
    }

    // "Lists not downloaded yet" banner — shown only while a geo policy is active.
    var notdl = document.getElementById('awg_geo_notdl');
    if(notdl){
        var geoVisible = document.getElementById('geo_section').style.display !== 'none';
        notdl.style.display = (geoVisible && !s.geo_downloaded && !awgGeoBusy) ? '' : 'none';
    }

    // The "wait for AdGuardHome" autostart option is only meaningful on AGH boxes — show its row
    // only when the backend reports AdGuardHome present (status.agh).
    var aghRow = document.getElementById('awg_wait_for_agh_row');
    if(aghRow) aghRow.style.display = (s && s.agh) ? '' : 'none';

    renderCoexistWarning(s);
}

// Warn when a co-resident proxy/DPI tool (Xray/XRAYUI, zapret, ...) is running AND the
// applied config would fight it: default policy "All Traffic -> VPN" steals its traffic,
// and DNS interception (:53 DNAT) collides with its DNS. Advise the two safe settings.
// Uses the applied custom_settings (what's actually running), refreshed every status poll.
function renderCoexistWarning(s){
    var el = document.getElementById('awg_coexist_warn');
    if(!el) return;
    var tool = (s && s.dpi_tool) ? String(s.dpi_tool) : '';
    if(!tool){ el.style.display = 'none'; el.innerHTML = ''; return; }

    var cs = (typeof custom_settings !== 'undefined' && custom_settings) ? custom_settings : {};
    var policy = (cs.awg_default_policy || 'direct');
    var dnsOff = (cs.awg_no_dns_intercept === '1');
    var needPolicy = (policy === 'vpn_all');   // routing collision (not auto-handled)
    var needDns = !dnsOff;                      // DNS collision (auto-handled too, but make it explicit)
    if(!needPolicy && !needDns){ el.style.display = 'none'; el.innerHTML = ''; return; }

    var steps = '';
    if(needPolicy) steps += T('COEX_STEP_POLICY', escHtml(tool));
    if(needDns) steps += T('COEX_STEP_DNS', escHtml(tool));

    el.innerHTML = T('COEX_HEADER', escHtml(tool))
        + '<ul style="margin:5px 0 4px 0; padding-left:20px;">' + steps + '</ul>'
        + T('COEX_FOOTER');
    el.style.display = '';
}

function setOfflineUI(){
    var badge = document.getElementById('awg_badge');
    badge.className = 'awg-status stopped';
    badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPED'));
    // Always land on a clean, clickable «Start»: re-show + re-enable it (a transition may have
    // hidden/disabled the buttons) so a stranded transition can never leave the page without a
    // clickable control.
    var sBtn = document.getElementById('btn_start');
    var pBtn = document.getElementById('btn_stop');
    var rBtn = document.getElementById('btn_restart');
    sBtn.style.display = ''; sBtn.disabled = false;
    pBtn.style.display = 'none'; pBtn.disabled = false; pBtn.value = T('BTN_STOP');
    rBtn.style.display = 'none'; rBtn.disabled = false;
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

    // Warn before overwriting an existing config (import clears every field first).
    var hadPk = !!((document.getElementById('awg_iface_p1') || {}).value);
    var hadPub = !!((document.getElementById('awg_peer_p1') || {}).value);
    var hadEp = !!((document.getElementById('awg_peer_endpoint') || {}).value);
    if((hadPk || hadPub || hadEp) && !confirm(T('MSG_IMPORT_REPLACE_CONFIRM'))) return;

    // Reset all import-target fields first, so values absent from the imported
    // config don't keep stale values (e.g. an old S4 lingering after import).
    var clearFields = [
        'awg_iface_p1', 'awg_address', 'awg_listenport', 'awg_mtu', 'awg_dns',
        'awg_jc', 'awg_jmin', 'awg_jmax', 'awg_s1', 'awg_s2', 'awg_s3', 'awg_s4',
        'awg_h1', 'awg_h2', 'awg_h3', 'awg_h4',
        'awg_i1', 'awg_i2', 'awg_i3', 'awg_i4', 'awg_i5',
        'awg_peer_p1', 'awg_peer_p2', 'awg_peer_endpoint',
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
                case 'PrivateKey': setVal('awg_iface_p1', val); break;
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
                case 'PublicKey':          setVal('awg_peer_p1', val); break;
                case 'PresharedKey':       setVal('awg_peer_p2', val); break;
                case 'Endpoint':           setVal('awg_peer_endpoint', val); break;
                case 'AllowedIPs':         setVal('awg_peer_allowedips', val); break;
                case 'PersistentKeepalive': setVal('awg_peer_keepalive', val); break;
            }
        }
    }
    // If nothing recognizable was parsed, the file wasn't a valid WG/AWG config.
    var gotPk = !!((document.getElementById('awg_iface_p1') || {}).value);
    var gotPub = !!((document.getElementById('awg_peer_p1') || {}).value);
    var gotEp = !!((document.getElementById('awg_peer_endpoint') || {}).value);
    updateFirstRun();
    if(!gotPk && !gotPub && !gotEp){
        alert(T('MSG_IMPORT_UNRECOGNIZED'));
        return;
    }
    alert(T('MSG_IMPORT_OK'));
}

function setVal(id, val){
    var el = document.getElementById(id);
    if(el) el.value = val;
}

// ---- GeoCustom: own list files (paste/edit/load) + downloadable URL sources ----
// Files are stored in settings as `name,<base64(content)>;…` (name sanitized to [A-Za-z0-9_]);
// URLs as base64 of a newline-joined list. The router regenerates files on Apply and downloads
// URLs on update; each list auto-detects domain-vs-IP per line (see HINT_GEO_CUSTOM_FORMAT).
function sanitizeGeoName(s){ return String(s).replace(/[^a-zA-Z0-9]/g, '_'); }
// Read a (now multi-line) field and flatten it to a whitespace-free comma list, safe for the
// custom_settings store (Merlin truncates values at the first whitespace).
function awgCsv(id){
    var el = document.getElementById(id);
    return el ? String(el.value || '').replace(/[\s,]+/g, ',').replace(/^,+|,+$/g, '') : '';
}

function addGeoFileRow(name, content, kind){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_files_rows' : 'awg_geo_files_rows');
    if(!tbody) return;
    var tr = document.createElement('tr');
    tr.innerHTML =
        '<td style="padding:6px 0; border-bottom:1px solid #353d43;">' +
            '<div style="display:flex; gap:6px; align-items:center; flex-wrap:wrap; margin-bottom:4px;">' +
                '<input type="text" class="geo_file_name input_25_table" style="flex:1; min-width:120px;" placeholder="' + escHtml(T('PH_GEO_FILE_NAME')) + '" value="' + escHtml(name || '') + '" oninput="this.value=sanitizeGeoName(this.value);" aria-label="' + escHtml(T('PH_GEO_FILE_NAME')) + '">' +
                '<input type="button" class="button_gen" value="' + escHtml(T('BTN_LOAD_FROM_FILE')) + '" onclick="geoFileLoad(this);">' +
                '<input type="button" class="button_gen" value="✕" title="' + escHtml(T('BTN_REMOVE')) + '" aria-label="' + escHtml(T('BTN_REMOVE')) + '" onclick="removeGeoRow(this);" style="padding:2px 9px;">' +
            '</div>' +
            '<textarea class="geo_file_content awg-geo-ta" rows="3" placeholder="example.com&#10;1.2.3.0/24" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>' +
        '</td>';
    tbody.appendChild(tr);
    var ta = tr.querySelector('.geo_file_content');
    if(ta) ta.value = content || '';   // set via .value so content isn't HTML-parsed
}

function addGeoUrlRow(url, kind){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_url_rows' : 'awg_geo_url_rows');
    if(!tbody) return;
    var tr = document.createElement('tr');
    tr.innerHTML =
        '<td style="padding:6px 0; border-bottom:1px solid #353d43;">' +
            '<div style="display:flex; gap:6px; align-items:center;">' +
                '<input type="text" class="geo_url input_25_table" style="flex:1; min-width:160px;" placeholder="' + escHtml(T('PH_GEO_URL')) + '" value="' + escHtml(url || '') + '" spellcheck="false" autocapitalize="off" autocorrect="off">' +
                '<input type="button" class="button_gen" value="✕" title="' + escHtml(T('BTN_REMOVE')) + '" aria-label="' + escHtml(T('BTN_REMOVE')) + '" onclick="removeGeoRow(this);" style="padding:2px 9px;">' +
            '</div>' +
        '</td>';
    tbody.appendChild(tr);
}

function removeGeoRow(btn){
    var tr = btn.closest ? btn.closest('tr') : null;
    if(!tr){ var n = btn; while(n && n.tagName !== 'TR') n = n.parentNode; tr = n; }
    if(tr && tr.parentNode) tr.parentNode.removeChild(tr);
}

// "Load from file": read a local text file into this row's textarea (and name, if empty).
function geoFileLoad(btn){
    var row = btn.closest ? btn.closest('tr') : null;
    if(!row) return;
    var fi = document.createElement('input');
    fi.type = 'file';
    fi.accept = '.txt,.lst,.conf,.csv';
    fi.style.display = 'none';
    document.body.appendChild(fi);
    fi.onchange = function(){
        if(fi.files && fi.files[0]){
            var f = fi.files[0];
            var reader = new FileReader();
            reader.onload = function(e){
                var ta = row.querySelector('.geo_file_content');
                if(ta) ta.value = String(e.target.result || '');
                var nm = row.querySelector('.geo_file_name');
                if(nm && !nm.value){ nm.value = sanitizeGeoName(f.name.replace(/\.[^.]*$/, '')); }
            };
            reader.readAsText(f);
        }
        try { document.body.removeChild(fi); } catch(e){}
    };
    fi.click();
}

function serializeGeoFiles(kind){
    var rows = document.querySelectorAll('#' + (kind === 'exc' ? 'awg_exc_files_rows' : 'awg_geo_files_rows') + ' tr');
    var parts = [];
    for(var i = 0; i < rows.length; i++){
        var nmEl = rows[i].querySelector('.geo_file_name');
        var ctEl = rows[i].querySelector('.geo_file_content');
        if(!nmEl || !ctEl) continue;
        var name = sanitizeGeoName(nmEl.value);
        var content = ctEl.value;
        if(!name || !content.replace(/\s+/g, '')) continue;   // skip nameless/empty rows
        var b64;
        try { b64 = btoa(unescape(encodeURIComponent(content))); } catch(e){ continue; }
        parts.push(name + ',' + b64);
    }
    return parts.join(';');
}

function serializeGeoUrls(kind){
    var inputs = document.querySelectorAll('#' + (kind === 'exc' ? 'awg_exc_url_rows' : 'awg_geo_url_rows') + ' .geo_url');
    var urls = [];
    for(var i = 0; i < inputs.length; i++){
        var u = String(inputs[i].value || '').replace(/\s+/g, '');
        if(u) urls.push(u);
    }
    if(!urls.length) return '';
    try { return btoa(unescape(encodeURIComponent(urls.join('\n')))); } catch(e){ return ''; }
}

function loadGeoFiles(data, kind){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_files_rows' : 'awg_geo_files_rows');
    if(!tbody) return;
    tbody.innerHTML = '';
    if(data == null) data = custom_settings.awg_geo_custom_files || '';
    if(!data) return;
    var entries = data.split(';');
    for(var i = 0; i < entries.length; i++){
        if(!entries[i]) continue;
        var ci = entries[i].indexOf(',');
        if(ci < 0) continue;
        var name = entries[i].slice(0, ci);
        var content = '';
        try { content = decodeURIComponent(escape(atob(entries[i].slice(ci + 1)))); } catch(e){ content = ''; }
        addGeoFileRow(name, content, kind);
    }
}

function loadGeoUrls(data, kind){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_url_rows' : 'awg_geo_url_rows');
    if(!tbody) return;
    tbody.innerHTML = '';
    if(data == null) data = custom_settings.awg_geo_custom_urls || '';
    if(!data) return;
    var txt = '';
    try { txt = decodeURIComponent(escape(atob(data))); } catch(e){ txt = ''; }
    var urls = txt.split('\n');
    for(var i = 0; i < urls.length; i++){
        var u = urls[i].replace(/\s+/g, '');
        if(u) addGeoUrlRow(u, kind);
    }
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
    list.setAttribute('role', 'listbox');
    wrap.appendChild(list);
    input.setAttribute('role', 'combobox');
    input.setAttribute('aria-autocomplete', 'list');
    input.setAttribute('aria-controls', 'awg_ac_list');
    input.setAttribute('aria-expanded', 'false');
    var selIdx = -1;

    function getLastToken(){
        var val = input.value;
        var parts = val.split(/[,\n]/);
        return parts[parts.length - 1].trim();
    }

    function getExisting(){
        return input.value.split(/[,\n]/).map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    }

    function showSuggestions(){
        var q = getLastToken().toLowerCase();
        var existing = getExisting();
        list.innerHTML = '';
        selIdx = -1;
        if(q.length < 1){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); return; }
        var matches = v2flyList.filter(function(s){
            return s.indexOf(q) !== -1 && existing.indexOf(s) === -1;
        }).slice(0, 15);
        if(matches.length === 0){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); return; }
        for(var i = 0; i < matches.length; i++){
            var d = document.createElement('div');
            d.textContent = matches[i];
            d.setAttribute('role', 'option');
            d.id = list.id + '_opt_' + i;
            d.onmousedown = function(e){ e.preventDefault(); pickItem(this.textContent); };
            list.appendChild(d);
        }
        list.style.display = 'block';
        input.setAttribute('aria-expanded', 'true');
    }

    function pickItem(val){
        // Preserve existing separators (commas AND newlines) so a multi-line textarea keeps
        // the user's line breaks; only the trailing partial token is replaced.
        var v = input.value;
        var m = v.match(/[,\n][^,\n]*$/);
        input.value = (m ? v.slice(0, m.index + 1) : '') + val + ',';
        list.style.display = 'none'; input.setAttribute('aria-expanded', 'false');
        input.focus();
    }

    input.addEventListener('input', showSuggestions);
    input.addEventListener('focus', showSuggestions);
    input.addEventListener('blur', function(){ setTimeout(function(){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); }, 200); });
    input.addEventListener('keydown', function(e){
        var items = list.querySelectorAll('div');
        if(e.key === 'ArrowDown'){ e.preventDefault(); selIdx = Math.min(selIdx + 1, items.length - 1); }
        else if(e.key === 'ArrowUp'){ e.preventDefault(); selIdx = Math.max(selIdx - 1, 0); }
        else if(e.key === 'Enter' && selIdx >= 0){ e.preventDefault(); pickItem(items[selIdx].textContent); return; }
        else return;
        for(var i = 0; i < items.length; i++) items[i].className = (i === selIdx) ? 'selected' : '';
        if(selIdx >= 0 && items[selIdx]) input.setAttribute('aria-activedescendant', items[selIdx].id);
        else input.removeAttribute('aria-activedescendant');
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
    list.setAttribute('role', 'listbox');
    wrap.appendChild(list);
    input.setAttribute('role', 'combobox');
    input.setAttribute('aria-autocomplete', 'list');
    input.setAttribute('aria-controls', 'awg_ac_list_ip');
    input.setAttribute('aria-expanded', 'false');
    var selIdx = -1;

    function getLastToken(){
        var parts = input.value.split(/[,\n]/);
        return parts[parts.length - 1].trim();
    }
    function getExisting(){
        return input.value.split(/[,\n]/).map(function(s){ return s.trim(); }).filter(function(s){ return s; });
    }
    function showSuggestions(){
        var q = getLastToken().toLowerCase();
        var existing = getExisting();
        list.innerHTML = '';
        selIdx = -1;
        if(q.length < 1){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); return; }
        var matches = v2flyIpList.filter(function(s){
            return s.indexOf(q) !== -1 && existing.indexOf(s) === -1;
        }).slice(0, 15);
        if(matches.length === 0){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); return; }
        for(var i = 0; i < matches.length; i++){
            var d = document.createElement('div');
            d.textContent = matches[i];
            d.setAttribute('role', 'option');
            d.id = list.id + '_opt_' + i;
            d.onmousedown = function(e){ e.preventDefault(); pickItem(this.textContent); };
            list.appendChild(d);
        }
        list.style.display = 'block';
        input.setAttribute('aria-expanded', 'true');
    }
    function pickItem(val){
        // Preserve existing separators (commas AND newlines) so a multi-line textarea keeps
        // the user's line breaks; only the trailing partial token is replaced.
        var v = input.value;
        var m = v.match(/[,\n][^,\n]*$/);
        input.value = (m ? v.slice(0, m.index + 1) : '') + val + ',';
        list.style.display = 'none'; input.setAttribute('aria-expanded', 'false');
        input.focus();
    }
    input.addEventListener('input', showSuggestions);
    input.addEventListener('focus', showSuggestions);
    input.addEventListener('blur', function(){ setTimeout(function(){ list.style.display = 'none'; input.setAttribute('aria-expanded', 'false'); }, 200); });
    input.addEventListener('keydown', function(e){
        var items = list.querySelectorAll('div');
        if(e.key === 'ArrowDown'){ e.preventDefault(); selIdx = Math.min(selIdx + 1, items.length - 1); }
        else if(e.key === 'ArrowUp'){ e.preventDefault(); selIdx = Math.max(selIdx - 1, 0); }
        else if(e.key === 'Enter' && selIdx >= 0){ e.preventDefault(); pickItem(items[selIdx].textContent); return; }
        else return;
        for(var i = 0; i < items.length; i++) items[i].className = (i === selIdx) ? 'selected' : '';
        if(selIdx >= 0 && items[selIdx]) input.setAttribute('aria-activedescendant', items[selIdx].id);
        else input.removeAttribute('aria-activedescendant');
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
                <div class="formfonttitle" style="display:flex; flex-wrap:wrap; align-items:center; gap:10px;">
                    <span style="font-size:20px; font-weight:bold; letter-spacing:1px;">AmneziaWG</span>
                    <span style="font-size:13px; font-weight:normal;" data-i18n="LBL_VPN_CLIENT">VPN client</span>
                    <a href="https://storage.googleapis.com/amnezia/amnezia.org" target="_blank" style="margin-left:auto; display:flex; align-items:center; text-decoration:none;" title="Amnezia website" data-i18n-title="TITLE_AMNEZIA_SITE"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAPV0lEQVR4nKyaCXQc5X3Af3PsqWN1rXX5knzK2CDjMwETm9jBNUnKSxsHEpJAk5A2DSYtLwmP5pU2BNricCQ4D0pbHGxwqE2DbRIOO2DjC2PLBzb4vi9J1rmrPWZmZ+brm9VK2pV2V+a1/3mfdjXfN//r+3//a1YVQtAHTzy5nGsHkf5PETAduAMoGOaJ08BG4ARgfwqC/fDTB3/S/11KF2DBkiWoHv+wCExDk41Y91xgIfAVYDwik3HF7UVR3RixcC407cBuYAPw9uiqUZdkR0SHnz6WzG6w4mCbICyuxmVilsLOrTv6kajpGEc3LqZq8mfzMn/1dNOEC/vfegrBF/Otq2mYR2X9dJpeXz54t1IgKoAvpvAkaioqH7n/9rufHlsW1PqXXF4FHbsg3gZaFz9r8vJea0kGlgwB2ueWoH25NitDVntXcXjl2seiWzf/AJAzWMmyXlYUisqr8BQE0CJd+WR1wPXB4b2PHzlz7P4HvvTNZQumzX7N43JnXzmImDx0hTRkRN95f07zN5cdiPxh8w8FyCKFR+Rg3rlZUBLE7y+gZlxjyiyGDjFodEfC1f/8u9+s+/5vHll3uaO1eAhaZ90gilkESHtAN6SOR5/5aedjv94lorH6bESzDgS+ohJcqsLYhlkMFjhD8CwTxy+d+8tvPPmTj7YePzt9KFOfQoCOx3798+jmbf+arvVcRAcPl8eHokBVTT1eX2FOree6NEMf+9CbR3e8e06bnc67GN6EeqH7xVe/Gt2y88e5NJzzEoKCimpKq0aiyOD1qDTOXThAfMjIbl6p4V++W3vxaKeo7tPcYBNSs+1OxxPP/TCycdOvsguY1eqT4B1RzbjbvkZV9QS8Hh8uSeCWBTfNX8yShXNoOX8GS9PZd/Ajmj46iG3nxtUHXZq47p7NrmO/vUWuQ9A5mHxGHFiy4SXn47aO5c+tSwWna+EbyaXiqR1JzS23MaphDoUJiSLnIEuCItUZNmMr/dSWefHYAskQ/GnrDp76r38npsWvhQQlbutglVeffyzsD+3Z+WH//Ywd0M+eq46s3/xbhCjKhaiPiCTLuBbegnrjNEonTqTI9lMckZE0UGSRRKxKNi5F4HYJdE3HrXiQJAlJgUU3zWNCTT2/XPk8h04eycN6L3TrSmO37n8euCv9foaJ9Kx780mRSFTlM9W+G76bZ+H/8Q/wLJyH7Pcj2RKSDYoARRKoKrhd4HILXC6BbRskTAvJcQcKyTGmppYnHniE22/+Qpp6UiO7y10qhLg1qwBbtm75DIK78vu8XiKS103gvrtAdpi2wRRgOa5K4KQDipQSQnGYJymMqkA0rvWikiREMsQIXG4XP/rG97n95kWZPGcnL4N4Op5mdkkBIpGI9IvHf/HEtfh4qaqCogfvxVUdxHCyMTOBbEmgJ9CuXk0KIElgmRqmEUPCRFVttHgPa15dy5lz57GFjdQrZXInHLN6YOl9rHroaXxuzzA8cP1Tzzz17QwB1ry65vZwT/jmYVwaUqCAklX/iP/W2chIyTgtmxbakWOc/PnP6Ni7E9mWkkiP793Je79/BVmyECSorSlj95793Ps3f8/Dj/4LF1uugBsUl50UwuWSCZYW0Vg3Li8PjhC/f/315afPnPH1C7Bt+7a7s21bxvC6KHno63gVNx7nQSGhCht901Zalj+FcbWF0vHTUmdBcOHIRxze/QHtLVdwu2XKA8U03nAdlmWxffcevvN3D/LO9q1IHgnVLZBcAp9H8Midf8HYYFlOGVJfgtu2b1uSFCAcDnuOHju2cDjTKVo0i9I50yhMJvwylikwnl9N+NmV2LqBK1BO8Yg6ZNPJgHVazp7Ctm3WrVyN3+1Keq3bFs3r5yQajfLYM79ixaqVCGECcSQpgs9tsOKbX+C7N9WxeGIx993o4/5Gm3+4Mczogni/Qpua9iYFUJv2NU1FiPK8PkySGLlkDkXIqELF1OHsL1fQs3lb/5LS+qm4LBXZgssnDqPFIsn7F86epfXcZeoqypkypZ7SsgCdnaHknCUsfrdhPaWFPr6+8HNIIowkegh4De6dPQLiEiJ6lR1nLZ5s8ifrgb5IvG///gXJHTh69OjM4VKbkuvqGDVpHGX4KLA8XFz9Oj2b3s/Y2+DEWai6hGzA+cN7M+a2b9uVxKTINp9fMDv9QKLIMqFQG8LuRtghhB0GOwRWFCFivPyJxkM7FFpjUvKZPpy6rgWvNF8pVpv27/uyGJwhpStflpj13aWUiSI028XpnXu5vGZ9hmd1+YoIjpicFECYOpdPHSId585de3jgh/ficdvc/fU/48CBo8iyxNwbG7j9c7OpLPKR6GlHMbpwWV1gRcCK8T+Hwzy3Tycj4xj4Xrhv374Fqq5plUNSvDQIjB9NYW0VVy9cJNTawYnnV2ObZsaaEWMa8Vs+VAPaLpxEj0cyCIa6w7z91tvMnNFAbW0pL/3nw5BIIOk6lhZHD7UjEt0oVgjMMCQiRGIRXtgTwR5SNQ/wqht6pZq1KEm7UTpmFM0HjyNMidildqKXWoY84PVV0nz0ED7Jy9lj72XM+3w+Fi+8FVs32bNzD7UjS5kxfQKKZYClY8RDbNv7MW++/zFaNM4L35oIiSi2EeOuyRYdUYN1Jz3ZtSv6cqFcOyDJjAjW474qYydsug6cgEEZpKJ6KfGMQgqbGHYEU9MYN+YmvF6Z6upKRtaUUx6QwY4i2RZtl1ugoQbbjvHS2u2s2bCXcERLMlMVcIMegkQPxVKMeydrrDvuFPQ5ykvHC/UdpmxQUBCgIF6CiAokU6L7wqWBfDz1ESgajdtwgQmyDZNqv4DLbeL1GRQUWrhtkBIWsmU5foeKch+KFeHypSv8x5odmGkKEcICLQK6M6JEjBj/faIoxV8WJpM7kK3MSYHPU4LdZvc+a0Ms3Jmx1O8uY2xwHnKc3lxIEsiWQMLG5ZYId3bQ3NyKrnfR0tGC1y3zo2/Nh1iESr+gLODlamdsgB9bIIwokh4HO8b6kzLne9ScibZIptMCcnkht12A1O1JpgymZWJaCRTJRVlBHZWl0ygvHIckFNCTeVkSTDnO+bYmmruO0KMN7UZs2n6IxlGNqGaEORNL2bg7OkBPtpG0aK8LtXr4oDmQU7ki9Tf7Ie7bAakcogpOjikJmRmjvo1XLUFVUs0vo7e1lsyJnHIpdoaPWzaSsGI5iX54+CxExiQ9zcKGQjZ8MDA/vkwkmXdcaHdc41D7iMwSMgujeU3IKfkc0xWSjY2Ez12dZNdK5sIDSFVJENFbONT8Oqat5SXY2hmFmHNQY9xQKSh0S0T0Xl85vsRJzbVkNy5uWGimlLdKc+Zkt8fdmiv/kRUvumyhySaaksBQTQyXIEoIXdawXQJcNgnC7L/8KglLy53Tp+4ZCYuLF1oh2oXfiDC/3tU/V1eYADPea0K2PWzx73G7W+UZM2ZuzJY+VAaup7x8Cgm3hekRWD7Q3DGOXVrLvhMriHAVfALVb3OqfQt6IpKfYGrCsgUvbbsI0VByJ+653k4WP17FZnYwmnSh2EbyTImMNHoIysismbO2qNdNmdJEmpuSUJIHtHbEbGy3wHYrCLeEc1Zbzx+gq/t40vcXlJehyCbxnmaaOw4PMcN8W//HjyPcOTHB+JIEo/0GUysk/LJJsRQCoSUP1vvNhb2t6xzm7fF42mpqasLy7FmzPxZCdDjrHObrK26hrLCO9p5TtEVOEqWtt2FeICgZMw5JVikJjsFTDB6fTlS/jG1bQ8wvX1Gim4JV+2MIPYys9/CzmV18Z0ob2PFkoDza5eHZw8E0Mxx6zZg5Y4sjiBoIBPQpDQ1/OnLkyNdsLE63bUWIgQREVlxM/dxdFJYHKSsJMm3BHUhGgpJiCZ9t03qhJ4u2h+/3vHka7msIM9Ifp77ABL/ojTWmxE93VxM3pSF40v+bM3vOm/RVZPPnz3+5t6tmYwsrQ1LLMjjZ9AZeV5ySQptxk+pomDqRioBgRADMRCiLlrM2FjKGaUvsb3FcXaI3PUndX34gyIWIK6vW0xC3LZi/YECAe759zx+Li4p35CIWDXVwdNdbBAt0qosTVBUbBH1xAnI3k6tLcrYY80lQpJqM9Bk42YOz4c5nW0Rhw7niLMszzfOrS5f+ePz48cnWRH9nbtPmTZ9ZtmzZrnzbPrZ+JF9beitex8XGdUplmVl1Nbyx9UNWbz3Axa5Y2jbnOHyy4EtjwnxvcieVvsy0vCWmsvitsanQmBMOHTxw8AYny2Vwa3FSw6Q1gztfg/mZ1TiGO+Y3UOwUJJNGoUYi0NOFGQ5x5Fwzu8+0c6YrTkhLgHCG2c9Pscvie5M6mVBiDOBN47UlqnLb22Pzye8czkUnjp94r+9GRmtxTMXcBy+2711gCasqlwTxUIgyutEMhZUbt3HH5CKCUgI5HuH6Ep1pUyQky0YynaqqE0xjgJI0gMrRW5umcCrsZmLAoMJrUeExqXCbtOlqLu2vRfBe+o2MlUXeyubrar94z6GL64c2d1NQW2hTV2ry5Uc/RE/YvPKuwpKJfr4yTmWkR0e1YqhORKYHLKOXZ2mA+UhCZluzn9fOFnOw05c8zBMDOk/PbWZUgcn08jibLg8mLSh1Wwdr/OZff9KdWdwMEXVq7bR3Rpe9//AbB7uyttfnjnVx8tQVNKPX1XbFLF452MMrB6HUA/VFgoZSmBtUGOl1Ue6x0CyJYz0etjYX8O6VAroNJYO5EyE3a88EeHBaB9eXaWy6VDiYbPjFeVc+/8Kx0tAnXXkEKHBF+NtZLxL0GyvGFiitz+40VzvnLkUnCTdVx1i1L5w1QnZpsM8ZbR5ePhHsrQ+k3qVOApg7OgjWnyvi7nHdNJToGRlomcf65MV5zYumlumdIssLjgwNL6x5m6B1HHpaWdYYWre43lg+ODGLdrWz4ZCW/y1NXwwRkEj1fkXexg10GzL37aimqc2bPhX7pxvb/mpqmd7cL+ogLWR4ofETxg9WjWO5PwEez/s+LU/gzVeODAPnUi/RDwyeOH3qdP/3zPe9QwOHA/8mhPisEOJMvreSua7sIXnYl4SvCcENQnAgW0BLB3moZrIS+BDBdAQrENjZiGYPuNfwUjDzahaIrzoDIcI5Bc8lwDAEwwJxv0BMFog//D9pum8kEDyMoN7RfnYdptMaAPXTmyYngT93PKpI/7FHMum+NgSpZRk/9gAuXdvDmZAhwJ133nmtzzlBYFdq/Pxaf26Tgv/zz23S4X8DAAD//6krBRMCzcQhAAAAAElFTkSuQmCC" alt="Amnezia" style="height:20px; border-radius:4px; display:block;"></a>
                    <a href="https://t.me/asusxray" target="_blank" style="display:flex; align-items:center; gap:5px; text-decoration:none;" title="Telegram chat" data-i18n-title="TITLE_TG_CHAT"><svg width="20" height="20" viewBox="0 0 24 24" fill="#29a9eb" xmlns="http://www.w3.org/2000/svg" style="display:block;" aria-hidden="true" focusable="false"><path d="m20.665 3.717-17.73 6.837c-1.21.486-1.203 1.161-.222 1.462l4.552 1.42 10.532-6.645c.498-.303.953-.14.579.192l-8.533 7.701h-.002l.002.001-.314 4.692c.46 0 .663-.211.921-.46l2.211-2.15 4.599 3.397c.848.467 1.457.227 1.668-.785l3.019-14.228c.309-1.239-.473-1.8-1.282-1.434z"/></svg><span style="font-size:12px;" data-i18n="LBL_CHAT">Chat</span></a>
                    <a href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" title="Merlin AmneziaWG GitHub repository" data-i18n-title="TITLE_GH_REPO" style="font-size:12px; text-decoration:none;"><img src="https://img.shields.io/github/v/release/william-aqn/asuswrt-merlin-amneziawg?logo=github&label=release" alt="GitHub" style="height:18px; display:block;" onerror="this.onerror=null; this.outerHTML='🐙 GitHub';"></a>
                    <span id="awg_update_btn" style="display:none;"></span>
                </div>
                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>

                <!-- Status & Actions -->
                <table width="100%" border="0" cellpadding="4" cellspacing="0">
                <tr>
                    <th width="20%" data-i18n="TH_STATUS">Status</th>
                    <td>
                        <div class="awg-actions">
                            <span id="awg_badge" class="awg-status connecting" data-i18n-html="STAT_LOADING_BADGE">&#9679; Loading…</span>
                            <input type="button" id="btn_start" class="button_gen awg-btn" value="Start" data-i18n-val="BTN_START" onclick="awgAction('start_awgstart');">
                            <input type="button" id="btn_stop" class="button_gen awg-btn" value="Stop" data-i18n-val="BTN_STOP" style="display:none;" onclick="awgAction('start_awgstop');">
                            <input type="button" id="btn_restart" class="button_gen awg-btn" value="Restart" data-i18n-val="BTN_RESTART" style="display:none;" onclick="awgAction('start_awgrestart');">
                        </div>
                    </td>
                </tr>
                <tr>
                    <th width="20%" data-i18n="TH_INTERFACE">Interface</th>
                    <td><span id="awg_info">-</span></td>
                </tr>
                </table>

                <!-- First-run empty state: shown by loadSettings() when no key/peer is set yet -->
                <div id="awg_firstrun" style="display:none; margin:8px 0 2px 0; padding:10px 14px; background:#1b2a33; border:1px solid #2e88c7; border-radius:5px; font-size:12px; line-height:1.55;">
                    <span data-i18n-html="FIRSTRUN_HTML"><b>It looks like no configuration is set yet.</b><br>
                    Start by importing a <code>.conf</code> file from the Amnezia VPN app, then check the fields and click «Apply».</span>
                    <div style="margin-top:6px;"><input type="button" class="button_gen" value="Import configuration" data-i18n-val="BTN_IMPORT_CONFIG" onclick="importConfig();"></div>
                </div>

                <!-- Coexistence warning: shown by updateStatusUI() when a co-resident proxy/DPI
                     tool (Xray/XRAYUI, zapret, ...) is detected AND the config would collide with it -->
                <div id="awg_coexist_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a2e1a; border:1px solid #f0ad4e; border-radius:5px; color:#f0ad4e; font-size:12px; line-height:1.5;"></div>

                <!-- Peers Table -->
                <div class="awg-section" data-i18n="SEC_CONNECTED_PEERS">Connected peers</div>
                <div class="awg-tablewrap">
                <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable_table" id="awg_peers_table" style="min-width:520px;">
                <thead><tr>
                    <td width="25%" data-i18n="TH_SERVER_ADDR">Server address</td>
                    <td width="25%" data-i18n="TH_ALLOWED_IPS">Allowed IPs</td>
                    <td width="25%" data-i18n="TH_TRAFFIC">Traffic (rx/tx)</td>
                    <td width="25%" data-i18n="TH_LAST_HANDSHAKE">Last handshake</td>
                </tr></thead>
                <tbody id="awg_peers">
                    <tr><td colspan="4" style="text-align:center; color:#b6bdc7;" data-i18n="LBL_NO_PEERS">No peers</td></tr>
                </tbody>
                </table>
                </div>

                <div style="margin:15px 0 10px 5px;" class="splitLine"></div>

                <!-- ==================== CONFIG ==================== -->
                <div class="awg-section" style="display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
                    <span data-i18n="SEC_CONFIG">Configuration</span>
                    <input type="button" class="button_gen" value="Import a .conf file from the Amnezia VPN client" data-i18n-val="BTN_IMPORT_CONF_FILE" onclick="importConfig();" style="margin-left:auto; font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;">
                </div>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable">
                <thead><tr><td colspan="2">Interface</td></tr></thead>
                <tr>
                    <th width="35%">Private Key</th>
                    <td><input type="text" class="input_32_table awg-dotted" id="awg_iface_p1" maxlength="64" autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></td>
                </tr>
                <tr>
                    <th>Address</th>
                    <td><input type="text" class="input_20_table" id="awg_address" maxlength="32" placeholder="10.7.0.2/24" aria-label="Address"></td>
                </tr>
                <tr>
                    <th>Listen Port</th>
                    <td><input type="text" class="input_6_table" id="awg_listenport" maxlength="5" placeholder="51820" aria-label="Listen Port"></td>
                </tr>
                <tr>
                    <th>MTU</th>
                    <td><input type="text" class="input_6_table" id="awg_mtu" maxlength="4" placeholder="1280" aria-label="MTU">
                        <span style="color:#b6bdc7; font-size:11px; margin-left:6px;">default 1280 (576–1500)</span></td>
                </tr>
                <tr>
                    <th>DNS</th>
                    <td><input type="text" class="input_20_table" id="awg_dns" maxlength="64" placeholder="1.1.1.1" aria-label="DNS"></td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2">Peer</td></tr></thead>
                <tr>
                    <th width="35%">Public Key</th>
                    <td><input type="text" class="input_32_table" id="awg_peer_p1" maxlength="64"></td>
                </tr>
                <tr>
                    <th>Preshared Key</th>
                    <td><input type="text" class="input_32_table awg-dotted" id="awg_peer_p2" maxlength="64" autocomplete="off" placeholder="(optional)" spellcheck="false" autocapitalize="off" autocorrect="off"></td>
                </tr>
                <tr>
                    <th>Endpoint</th>
                    <td><input type="text" class="input_25_table" id="awg_peer_endpoint" maxlength="64" placeholder="server.example.com:51820" aria-label="Endpoint"></td>
                </tr>
                <tr>
                    <th>Allowed IPs</th>
                    <td><input type="text" class="input_25_table" id="awg_peer_allowedips" maxlength="128" placeholder="0.0.0.0/0" aria-label="Allowed IPs"></td>
                </tr>
                <tr>
                    <th>Persistent Keepalive</th>
                    <td><input type="text" class="input_6_table" id="awg_peer_keepalive" maxlength="4" placeholder="25" aria-label="Persistent Keepalive"> sec</td>
                </tr>
                </table>

                <!-- ==================== OBFUSCATION ==================== -->
                <details class="awg-details" style="margin-top:8px;">
                <summary style="padding:8px 10px; font-weight:bold; text-transform:uppercase; font-size:11px; letter-spacing:0.5px; background:#3a4548; border:1px solid #5a6b70; border-radius:3px; color:#e8edf2;" data-i18n-html="OBF_SUMMARY_HTML">AmneziaWG Obfuscation <span style="font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;">— obfuscation parameters (usually filled in by importing a config) ▾</span></summary>
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:6px;">
                <tr>
                    <th width="35%">Jc (junk packet count)</th>
                    <td><input type="text" class="input_6_table" id="awg_jc" maxlength="3" placeholder="4" aria-label="Jc (junk packet count)"> (0-128)</td>
                </tr>
                <tr>
                    <th>Jmin (min junk size)</th>
                    <td><input type="text" class="input_6_table" id="awg_jmin" maxlength="5" placeholder="40" aria-label="Jmin (min junk size)"> bytes</td>
                </tr>
                <tr>
                    <th>Jmax (max junk size)</th>
                    <td><input type="text" class="input_6_table" id="awg_jmax" maxlength="5" placeholder="70" aria-label="Jmax (max junk size)"> bytes</td>
                </tr>
                <tr>
                    <th>S1 (init padding)</th>
                    <td><input type="text" class="input_6_table" id="awg_s1" maxlength="3" placeholder="20" aria-label="S1 (init padding)"> bytes</td>
                </tr>
                <tr>
                    <th>S2 (response padding)</th>
                    <td><input type="text" class="input_6_table" id="awg_s2" maxlength="3" placeholder="30" aria-label="S2 (response padding)"> bytes</td>
                </tr>
                <tr>
                    <th>S3</th>
                    <td><input type="text" class="input_6_table" id="awg_s3" maxlength="3" placeholder="0" aria-label="S3"> bytes</td>
                </tr>
                <tr>
                    <th>S4</th>
                    <td><input type="text" class="input_6_table" id="awg_s4" maxlength="3" placeholder="0" aria-label="S4"> bytes</td>
                </tr>
                <tr>
                    <th>H1 (init header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h1" maxlength="32" placeholder="1234567891" aria-label="H1 (init header)"></td>
                </tr>
                <tr>
                    <th>H2 (response header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h2" maxlength="32" placeholder="1987654321" aria-label="H2 (response header)"></td>
                </tr>
                <tr>
                    <th>H3 (cookie header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h3" maxlength="32" placeholder="1112223334" aria-label="H3 (cookie header)"></td>
                </tr>
                <tr>
                    <th>H4 (data header)</th>
                    <td><input type="text" class="input_25_table" id="awg_h4" maxlength="32" placeholder="4445556667" aria-label="H4 (data header)"></td>
                </tr>
                <tr>
                    <th>I1 (init junk)</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i1" style="font-size:11px;" maxlength="5000" placeholder="Auto-filled by Import Config" aria-label="I1 (init junk)"></td>
                </tr>
                <tr>
                    <th>I2</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i2" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I2"></td>
                </tr>
                <tr>
                    <th>I3</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i3" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I3"></td>
                </tr>
                <tr>
                    <th>I4</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i4" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I4"></td>
                </tr>
                <tr>
                    <th>I5</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i5" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I5"></td>
                </tr>
                </table>
                </details>

                <!-- ==================== ROUTING ==================== -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_ROUTING_POLICY">Routing policy</td></tr></thead>
                <tr>
                    <th width="35%" data-i18n="TH_DEFAULT_POLICY">Default policy</th>
                    <td>
                        <select id="default_policy" class="input_option" onchange="updateGeoVisibility();"
                                style="font-size:13px; font-weight:bold;" aria-label="Default policy" data-i18n-aria="ARIA_DEFAULT_POLICY">
                            <option value="direct" data-i18n="OPT_DIRECT_NO_VPN">Direct (no VPN)</option>
                            <option value="vpn_all" data-i18n="OPT_VPN_ALL_TRAFFIC">VPN — all traffic</option>
                            <option value="vpn_geo" data-i18n="OPT_VPN_GEO_ONLY">VPN — Geo only</option>
                        </select>
                        <div class="awg-hint" data-i18n="HINT_DEFAULT_POLICY">Applied to devices that are not in the list below.</div>
                        <div class="awg-hint" data-i18n="HINT_GEO_DNS_DEVICE">Geo by domains only works if the device uses the router as its DNS (configured in the Geo block below).</div>
                    </td>
                </tr>
                <tr id="awg_active_row" style="display:none;">
                    <th data-i18n="TH_GEO_ACTIVE">Active (all policies)</th>
                    <td>
                        <div id="awg_active_rules" style="font-size:11px; color:#93E7FF;"></div>
                        <div class="awg-hint" data-i18n="HINT_GEO_ACTIVE">Totals across all geo policies (routing rules, IP ranges, domains).</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_IPV6_LEAK">IPv6 leak protection</th>
                    <td>
                        <label><input type="checkbox" id="awg_block_ipv6_dns"> <span data-i18n="LBL_BLOCK_IPV6_DNS" style="color:#FFCC00;">Block resolving IPv6 addresses in DNS (filter-AAAA)</span></label>
                        <div class="awg-hint" data-i18n="HINT_IPV6_DNS">Critical for reliable Geo routing. Stops dual-stack (IPv4+IPv6) domains from bypassing the VPN over IPv6.</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_KILLSWITCH">Kill-switch</th>
                    <td>
                        <label><input type="checkbox" id="awg_killswitch"> <span data-i18n="LBL_KILLSWITCH" style="color:#FFCC00;">Block VPN traffic when the tunnel goes down (strict kill-switch)</span></label>
                        <details class="awg-hint" data-i18n-html="HINT_KILLSWITCH_HTML"><summary>Blocks traffic of VPN devices if the tunnel goes down (instead of leaking around it to the WAN). Off by default. <u>Details</u></summary>When enabled: if the tunnel suddenly goes down (daemon crash / out of memory), traffic from devices with a «VPN» policy doesn't leak around it to the WAN in cleartext but is blocked until recovery (the watchdog brings the tunnel back within ~5 min). Off — the previous behavior (traffic may temporarily go around the VPN). Affects only devices with a VPN/Geo policy; with the default policy set to «VPN — all traffic» it affects the whole LAN.</details>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_TUNNEL_CHECK_ADDR">Tunnel check addresses</th>
                    <td>
                        <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap; max-width:480px;">
                            <input type="text" class="input_25_table" id="awg_watchdog_hosts" maxlength="200" style="flex:1 1 200px; min-width:140px;" placeholder="8.8.8.8 1.1.1.1" aria-label="Tunnel check addresses" data-i18n-aria="ARIA_TUNNEL_CHECK_ADDR">
                            <input type="button" class="button_gen" id="btn_wd_from_dns" value="From DNS" data-i18n-val="BTN_WD_FROM_DNS" title="Fill in from the Interface DNS above" data-i18n-title="TITLE_WD_FROM_DNS" onclick="awgWatchdogFromDns();" style="font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0; white-space:nowrap;">
                        </div>
                        <details class="awg-hint" data-i18n-html="HINT_WATCHDOG_HTML"><summary>Addresses the watchdog pings <b>through the tunnel</b> every 5 minutes (if at least one replies, the tunnel is alive). <u>Format and examples</u></summary><b>Format:</b> IP or domain, several allowed — separated by a space or comma (up to 4 addresses).<br><b>Example:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Prefer IPs (no dependency on DNS). Empty = default <b>8.8.8.8</b> and <b>1.1.1.1</b>. Change it if those addresses are blocked/unreachable for you — otherwise the watchdog restarts the VPN needlessly. Which addresses are checked is shown in the log below.</details>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_ZAPRET_COMPAT">Compatibility mode</th>
                    <td>
                        <label><input type="checkbox" id="awg_no_dns_intercept"> <span data-i18n="LBL_NO_DNS_INTERCEPT" style="color:#FFCC00;">Compatibility mode — coexist with zapret2 / Xray / b4 (don't intercept DNS)</span></label>
                        <details class="awg-hint" data-i18n-html="HINT_NO_DNS_HTML"><summary>Compatibility mode: disables AmneziaWG's DNS interception (port :53) so it can't clash with a co-resident DPI/proxy tool. ON by default for new installs. <u>Details</u></summary>Keep it on if <b>zapret2</b>, <b>Xray/XRAYUI</b> (v2ray, sing-box) or <b>b4</b> runs alongside — otherwise a DNS conflict can leave the network without internet. Geo by IP (GeoIP/antifilter) keeps working; geo by domains keeps working for clients that use the router as their DNS — only clients with a hardcoded external resolver lose domain-geo. A nearby zapret2 / Xray / v2ray / sing-box / b4 or NFQUEUE/TPROXY (iptables or nft) footprint also disables interception automatically even without this checkbox. Note: this only resolves the DNS conflict — with the «VPN — all traffic» policy, routing still takes the proxy's traffic, so for compatibility choose «Direct» or «VPN — Geo only».</details>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_START_DELAY">Startup delay</th>
                    <td>
                        <div style="display:flex; align-items:center; gap:6px;">
                            <input type="text" class="input_25_table" id="awg_start_delay" maxlength="3" placeholder="0" style="width:90px; flex:0 0 auto;" aria-label="Startup delay in seconds" data-i18n-aria="ARIA_START_DELAY">
                            <span data-i18n="LBL_START_DELAY_UNIT" style="color:#9aa;">sec</span>
                        </div>
                        <div class="awg-hint" data-i18n="HINT_START_DELAY">Pause before starting the tunnel on boot. 0 = start immediately (default). Increase only if the tunnel comes up before the network or a co-resident resolver is ready.</div>
                    </td>
                </tr>
                <tr id="awg_wait_for_agh_row" style="display:none;">
                    <th data-i18n="TH_WAIT_AGH">AdGuardHome</th>
                    <td>
                        <label><input type="checkbox" id="awg_wait_for_agh"> <span data-i18n="LBL_WAIT_AGH">On autostart, wait until AdGuardHome is up before starting the tunnel</span></label>
                        <details class="awg-hint" data-i18n-html="HINT_WAIT_AGH_HTML"><summary>AdGuardHome detected. With this on, on boot AmneziaWG waits until AGH is actually up on :53 before starting (capped at 60s). <u>Why</u></summary>AdGuardHome fronts DNS on this router, and AmneziaWG's geo-by-domain routing reaches AGH through AMAGHI's ipset collector, which re-scans whenever AmneziaWG restarts dnsmasq. If that restart runs before AGH is ready, the geo set may not get (re)bridged. Waiting until AGH answers on :53 makes the ordering deterministic. Off — start without waiting (set a fixed «Startup delay» above if you prefer a pause).</details>
                    </td>
                </tr>
                </table>

                <div class="awg-section" data-i18n="SEC_DEVICE_RULES">Device rules</div>
                <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable_table" id="awg_client_table" style="table-layout:fixed;">
                <thead><tr>
                    <td width="18%" data-i18n="TH_IP_ADDRESS">IP address</td>
                    <td width="35%" data-i18n="TH_DEVICE_NAME">Device name</td>
                    <td width="33%" data-i18n="TH_POLICY">Policy</td>
                    <td width="14%" data-i18n="TH_ACTIONS">Actions</td>
                </tr></thead>
                <tbody id="awg_client_rows">
                </tbody>
                </table>
                <div style="margin-top:6px; display:flex; align-items:center; flex-wrap:wrap; gap:6px;">
                    <input type="button" class="button_gen" value="+ Add device" data-i18n-val="BTN_ADD_DEVICE" onclick="addClientRow('','','vpn_all');">
                    <input type="button" class="button_gen" value="+ From DHCP list" data-i18n-val="BTN_FROM_DHCP" onclick="fetchDhcpClients();">
                    <span id="awg_client_undo" style="display:none; font-size:12px; margin-left:4px;"></span>
                </div>

                <!-- ==================== GEO ROUTING ==================== -->
                <div id="geo_section" style="display:none;">

                <div style="border:1px solid #fc0; border-radius:4px; padding:10px 14px; margin-top:10px; font-size:12px; color:#fc0;">
                    <span data-i18n-html="GEO_DNS_IMPORTANT_HTML"><b>Important:</b> For VPN Geo to work, devices must use the router as their DNS server.<br>
                    iPhone: Settings &gt; Wi-Fi &gt; (i) &gt; DNS &gt; Manual &gt; only </span><% nvram_get("lan_ipaddr"); %><br>
                    <span data-i18n="GEO_DNS_MACOS_PREFIX">macOS/Windows: set </span><% nvram_get("lan_ipaddr"); %><span data-i18n-html="GEO_DNS_MACOS_HTML"> as DNS in your network settings. Disable DNS-over-HTTPS in the browser.</span>
                </div>

                <!-- Shown by updateStatusUI() when geo routing is on but lists aren't downloaded yet -->
                <div id="awg_geo_notdl" style="display:none; border:1px solid #f0ad4e; border-radius:4px; padding:9px 12px; margin-top:8px; font-size:12px; color:#f0ad4e;">
                    <span data-i18n="BANNER_LISTS_NOT_LOADED">⚠ Lists aren't downloaded yet — without them Geo routing doesn't work.</span>
                    <input type="button" class="button_gen" value="Download lists" data-i18n-val="BTN_DOWNLOAD_LISTS" onclick="updateGeoLists();" style="font-size:11px; padding:2px 8px; margin-left:6px;">
                </div>

                <!-- Geo-policy tabs: each tab is an independent GeoIP/GeoSite/GeoCustom/Antifilter combination -->
                <div id="geo_tabs" class="awg-geo-tabs"></div>
                <div id="geo_policy_panel">
                <div class="awg-hint" style="margin:4px 2px 4px;" data-i18n="GEO_TABS_RAM_HINT"></div>
                <div id="geo_stats" style="margin:0 2px 8px; font-size:11px; color:#93E7FF; line-height:1.7;"></div>

                <!-- Policy mode: lists route TO the VPN (include) or AWAY from it (exclude) -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_GEO_MODE">How the lists work</td></tr></thead>
                <tr>
                    <th width="35%" data-i18n="TH_GEO_MODE">Mode</th>
                    <td>
                        <label style="display:block; margin:2px 0;"><input type="radio" name="geo_mode" value="vpn" onchange="updateGeoModeHint();" checked> <span data-i18n="OPT_GEO_MODE_VPN">Route lists via VPN (include)</span></label>
                        <label style="display:block; margin:2px 0;"><input type="radio" name="geo_mode" value="direct" onchange="updateGeoModeHint();"> <span data-i18n="OPT_GEO_MODE_DIRECT">Lists go direct, everything else via VPN (exclude)</span></label>
                        <div id="geo_mode_hint" class="awg-hint" data-i18n="GEO_MODE_HINT_VPN">Matched destinations route via VPN; everything else goes direct.</div>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_GEOIP">GeoIP — route by service IPs</td></tr></thead>
                <tr>
                    <th width="35%"><span data-i18n="TH_GEOIP_LISTS">GeoIP service lists</span><br><span style="font-weight:normal; font-size:11px; color:#b6bdc7;">github.com/Loyalsoldier/geoip</span></th>
                    <td>
                        <textarea class="input_32_table awg-geo-ta" id="awg_geo_v2fly_ip" rows="2" maxlength="512"
                            placeholder="telegram,google,facebook,twitter,netflix,cloudflare"
                            autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                        <div class="awg-hint" data-i18n="HINT_GEOIP">Comma-separated. Available: telegram, google, facebook, twitter, netflix, cloudflare, fastly, cloudfront, tor + country codes (us, ru, cn, …).</div>
                        <div class="awg-hint" style="color:#f0ad4e;" data-i18n="HINT_GEOIP_WARN">⚠ There are NO IP lists for youtube, discord, microsoft, github, openai etc. — use GeoSite below.</div>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_GEOSITE">GeoSite — route by services / domains</td></tr></thead>
                <tr>
                    <th width="35%"><span data-i18n="TH_GEOSITE_LISTS">GeoSite service lists</span><br><span style="font-weight:normal; font-size:11px; color:#b6bdc7;">github.com/v2fly/domain-list-community</span></th>
                    <td>
                        <textarea class="input_32_table awg-geo-ta" id="awg_geo_v2fly" rows="2" maxlength="512"
                            placeholder="youtube,google,discord,netflix,telegram,twitter,instagram,facebook,tiktok,spotify"
                            autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                        <div class="awg-hint" data-i18n="HINT_GEOSITE">Comma-separated. 1500+ lists: youtube, google, discord, netflix, telegram, twitter, instagram, facebook, tiktok, spotify, steam, apple, microsoft, amazon, openai, github, whatsapp, category-media, category-games, category-dev …</div>
                    </td>
                </tr>
                </table>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_ANTIFILTER">Geo Antifilter — RKN lists (antifilter.download)</td></tr></thead>
                <tr>
                    <th width="35%"><span data-i18n="TH_ANTIFILTER_IP">Antifilter IP lists</span><br><span style="font-weight:normal; font-size:11px; color:#b6bdc7;">antifilter.download</span></th>
                    <td>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="allyouneed"><span data-i18n="AF_ALLYOUNEED"> allyouneed — all the needed subnets (~15K) </span><span style="color:#5bd75b;" data-i18n="AF_RECOMMENDED">recommended</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="community"><span data-i18n="AF_COMMUNITY"> community — community subnets (~900)</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ipsum"><span data-i18n="AF_IPSUM"> ipsum — IPs compressed to /24 (~15K)</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="subnet"><span data-i18n="AF_SUBNET"> subnet — large subnets (~78)</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ip"><span data-i18n="AF_IP"> ip — individual IPs (~48K)</span></label>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="ipresolve"><span data-i18n="AF_IPRESOLVE"> ipresolve — IPs from DNS resolution (~154K) </span><span style="color:#f0ad4e;" data-i18n="AF_IPRESOLVE_WARN">⚠ very large</span></label>
                        <div class="awg-hint" data-i18n="HINT_ANTIFILTER_IP">Added to the GeoIP lists and routed through the VPN. allyouneed = ipsum + subnet; ip/ipresolve overlap heavily with allyouneed — allyouneed is usually enough.</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_ANTIFILTER_DOMAINS">Antifilter domains</th>
                    <td>
                        <label style="display:block; margin:2px 0;"><input type="checkbox" class="af_list" value="community_domains"><span data-i18n="AF_COMMUNITY_DOMAINS"> community domains (~485) → dnsmasq</span></label>
                        <div class="awg-hint" data-i18n="HINT_ANTIFILTER_DOMAINS">The full domains.lst (1.4M domains / 27 MB) isn't supported — too large for dnsmasq on the router.</div>
                    </td>
                </tr>
                </table>

                <!-- ==================== GEOCUSTOM — own domains / IPs / files + URL sources ==================== -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_GEO_CUSTOM">GeoCustom — your own domains / IPs / files</td></tr></thead>
                <tr>
                    <th width="35%" data-i18n="TH_CUSTOM_DOMAINS">Custom domains</th>
                    <td>
                        <textarea class="input_32_table awg-geo-ta" id="geo_custom_domains" rows="3"
                               maxlength="2000" placeholder="example.com,another.org,service.net"
                               autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                        <div class="awg-hint" data-i18n="HINT_CUSTOM_DOMAINS">Comma-separated. Resolved via DNS → routed into the VPN.</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_CUSTOM_IPS">Custom IPs / subnets</th>
                    <td>
                        <textarea class="input_32_table awg-geo-ta" id="geo_custom_ips" rows="3"
                               maxlength="2000" placeholder="8.8.8.8,1.1.1.0/24,203.0.113.0/24"
                               autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                        <div class="awg-hint" data-i18n="HINT_CUSTOM_IPS">Comma-separated: individual IPs or CIDR subnets.</div>
                    </td>
                </tr>
                <tr><td colspan="2">
                    <div class="awg-hint" data-i18n-html="HINT_GEO_CUSTOM_FORMAT">One entry per line. A domain (<code>example.com</code>) is routed via DNS; an IP or CIDR subnet (<code>1.2.3.0/24</code>) is added to the ipset. Lines starting with <code>#</code> are comments. A URL must return a plain-text list in this format.</div>

                    <div style="margin-top:8px; font-weight:bold; font-size:12px;" data-i18n="TH_GEO_FILES">Custom files</div>
                    <table width="100%" border="0" cellpadding="0" cellspacing="0" style="table-layout:fixed;"><tbody id="awg_geo_files_rows"></tbody></table>
                    <div style="margin-top:5px;">
                        <input type="button" class="button_gen" value="+ Add file" data-i18n-val="BTN_ADD_GEO_FILE" onclick="addGeoFileRow('','');">
                    </div>

                    <div style="margin-top:12px; font-weight:bold; font-size:12px;" data-i18n="TH_GEO_URLS">URL sources</div>
                    <table width="100%" border="0" cellpadding="0" cellspacing="0" style="table-layout:fixed;"><tbody id="awg_geo_url_rows"></tbody></table>
                    <div style="margin-top:5px;">
                        <input type="button" class="button_gen" value="+ Add URL" data-i18n-val="BTN_ADD_GEO_URL" onclick="addGeoUrlRow('');">
                    </div>
                </td></tr>
                </table>

                <!-- ==================== EXCLUSIONS (pointwise exceptions) ==================== -->
                <details style="margin-top:8px;">
                    <summary style="cursor:pointer; padding:7px 10px; background:#2b3338; border:1px solid #455055; border-radius:4px; font-size:13px; font-weight:bold; color:#e7ebee;" data-i18n="TBL_GEO_EXCLUDE">Exclusions (exceptions)</summary>
                    <div style="border:1px solid #455055; border-top:none; border-radius:0 0 4px 4px; padding:8px 10px;">
                        <div class="awg-hint" style="margin-top:0;" data-i18n="HINT_GEO_EXCLUDE">Pointwise exceptions: in include mode these go DIRECT (carved out of the VPN); in exclude mode they go via VPN (carved back in). Same format as GeoCustom.</div>
                        <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:6px;">
                        <tr>
                            <th width="35%" data-i18n="TH_CUSTOM_DOMAINS">Custom domains</th>
                            <td>
                                <textarea class="input_32_table awg-geo-ta" id="geo_exc_domains" rows="3" maxlength="2000"
                                       placeholder="example.com,another.org,service.net" autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                                <div class="awg-hint" data-i18n="HINT_CUSTOM_DOMAINS">Comma- or newline-separated. Resolved via DNS.</div>
                            </td>
                        </tr>
                        <tr>
                            <th data-i18n="TH_CUSTOM_IPS">Custom IPs / subnets</th>
                            <td>
                                <textarea class="input_32_table awg-geo-ta" id="geo_exc_ips" rows="3" maxlength="2000"
                                       placeholder="8.8.8.8,1.1.1.0/24,203.0.113.0/24" autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></textarea>
                                <div class="awg-hint" data-i18n="HINT_CUSTOM_IPS">Comma- or newline-separated: individual IPs or CIDR subnets.</div>
                            </td>
                        </tr>
                        <tr><td colspan="2">
                            <div style="margin-top:4px; font-weight:bold; font-size:12px;" data-i18n="TH_GEO_FILES">Custom files</div>
                            <table width="100%" border="0" cellpadding="0" cellspacing="0" style="table-layout:fixed;"><tbody id="awg_exc_files_rows"></tbody></table>
                            <div style="margin-top:5px;">
                                <input type="button" class="button_gen" value="+ Add file" data-i18n-val="BTN_ADD_GEO_FILE" onclick="addGeoFileRow('','','exc');">
                            </div>
                            <div style="margin-top:12px; font-weight:bold; font-size:12px;" data-i18n="TH_GEO_URLS">URL sources</div>
                            <table width="100%" border="0" cellpadding="0" cellspacing="0" style="table-layout:fixed;"><tbody id="awg_exc_url_rows"></tbody></table>
                            <div style="margin-top:5px;">
                                <input type="button" class="button_gen" value="+ Add URL" data-i18n-val="BTN_ADD_GEO_URL" onclick="addGeoUrlRow('','exc');">
                            </div>
                        </td></tr>
                        </table>
                    </div>
                </details>

                </div><!-- /geo_policy_panel -->

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_GEO_UPDATE">Geo update settings</td></tr></thead>
                <tr>
                    <th width="35%" data-i18n="TH_AUTOUPDATE">Auto-update lists</th>
                    <td>
                        <label><input type="checkbox" id="geo_autoupdate"> <span data-i18n="LBL_DAILY_4AM">Daily at 4:00</span></label>
                        &nbsp;&nbsp;
                        <input type="button" class="button_gen" id="btn_geo_update" value="Update now" data-i18n-val="BTN_GEO_UPDATE_NOW" onclick="updateGeoLists();">
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_WIPE_BEFORE">Wipe before update</th>
                    <td>
                        <label><input type="checkbox" id="awg_geo_wipe_update"> <span data-i18n="LBL_WIPE_BEFORE" style="color:#FFCC00;">Delete all geo files before a full update / program update</span></label>
                        <div class="awg-hint" data-i18n="HINT_WIPE_BEFORE">Off (default): existing geo lists are kept, including during a program update (no re-download). On: wipe before re-downloading (a clean set, but if a download fails some list will stay missing).</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_IPSET_NAME">ipset name</th>
                    <td>
                        <input type="text" class="input_25_table" id="awg_ipset_name" maxlength="31" style="width:95%; max-width:260px;" placeholder="awg_dst" aria-label="ipset name" data-i18n-aria="ARIA_IPSET_NAME">
                        <div class="awg-hint" data-i18n-html="HINT_IPSET_HTML">The name of the ipset set for GeoIP/antifilter subnets (routed through the VPN). Default <code>awg_dst</code>. A set <b>created by the addon itself</b> is removed on stop, and when the name changes the old one is removed too — no leftovers/leaks. If you specify a set that's <b>already created by another connection/tool</b>, the addon only adds entries to it and doesn't touch it on stop (a shared set). Letters, digits and <code>_ . -</code> are allowed, up to 31 characters; empty = <code>awg_dst</code>.</div>
                    </td>
                </tr>
                </table>

                </div>

                <!-- ==================== DOWNLOAD VIA VPN ==================== -->
                <!-- Outside geo_section: the program-update toggle must show even when no
                     device uses geo routing. -->
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;">
                <thead><tr><td colspan="2" data-i18n="TBL_DOWNLOAD_VIA_VPN">Download via VPN (bypass blocking)</td></tr></thead>
                <tr>
                    <th width="35%" data-i18n="TH_GEO_VIA_VPN">Geo lists via VPN</th>
                    <td>
                        <label><input type="checkbox" id="awg_geo_via_awg"> <span data-i18n="LBL_GEO_VIA_VPN">Download geo lists through the active AWG tunnel</span></label>
                        <div class="awg-hint" data-i18n="HINT_GEO_VIA_VPN">While the tunnel is up, downloading GeoIP / GeoSite / antifilter goes through the VPN (bypassing GitHub / jsDelivr blocking). If the VPN is off — the download goes directly, as before.</div>
                    </td>
                </tr>
                <tr>
                    <th data-i18n="TH_UPDATE_VIA_VPN">Program update via VPN</th>
                    <td>
                        <label><input type="checkbox" id="awg_update_via_awg"> <span data-i18n="LBL_UPDATE_VIA_VPN">Download the program update through the active AWG tunnel</span></label>
                        <div class="awg-hint" data-i18n-html="HINT_UPDATE_VIA_VPN">Version check and <code>.ipk</code> download go through the VPN while the tunnel is active — you can install updates straight from GitHub bypassing regional blocking (and verify SHA256 via the GitHub API). DNS resolution stays system-wide; the bypass works for IP/TCP blocking. If the VPN is off — directly, as before.</div>
                    </td>
                </tr>
                </table>

                <!-- Apply -->
                <div style="margin-top:12px; text-align:center;">
                    <input type="button" class="button_gen" value="Apply" data-i18n-val="BTN_APPLY" onclick="saveSettings();" title="Save and apply without restarting the VPN" data-i18n-title="TITLE_APPLY">
                    <input type="button" class="button_gen" value="Save and fully restart the VPN" data-i18n-val="BTN_SAVE_RESTART" onclick="forceApply();" style="margin-left:8px;" title="Save + restart the VPN (stop → start) + full rebuild of routes and firewall" data-i18n-title="TITLE_SAVE_RESTART">
                    <span id="awg_ack_bottom" class="awg-ack"></span>
                </div>
                <div style="font-size:11px; opacity:0.7; margin:8px auto 0; max-width:640px; line-height:1.55; text-align:left;">
                    <div data-i18n-html="APPLY_DESC1_HTML"><b>Apply</b> — save the settings and apply them «on the fly»: updates devices, routing policies, the firewall and the GeoIP/GeoSite lists <b>without dropping the VPN connection</b>. If the VPN is stopped — the settings are just saved and applied at the next start.</div>
                    <div style="margin-top:4px;" data-i18n-html="APPLY_DESC2_HTML"><b>Save and fully restart the VPN</b> (stop → start) — the config is re-applied (awg setconf), the interface, routes and firewall are rebuilt, the connection drops for a couple of seconds. Needed when changing keys, the server (Endpoint), MTU or obfuscation parameters (Jc, S1, H1…H4), or if the connection is «stuck».</div>
                </div>

                <!-- ==================== LOG ==================== -->
                <div class="awg-section" style="margin-top:15px; display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
                    <span data-i18n="SEC_LOG">Log</span>
                    <input type="button" class="button_gen" value="Get diagnostic data and copy log" data-i18n-val="BTN_GET_DIAG" onclick="awgRunDiag(this);" style="margin-left:auto; font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;">
                </div>
                <div id="awg_log" class="awg-log" data-i18n="LOG_WAITING">Waiting for data…</div>
                <div style="display:flex; align-items:center; flex-wrap:wrap; gap:2px 10px; font-size:11px; opacity:0.55; margin-top:4px;">
                    <span style="margin-right:auto;">
                        <span data-i18n="DONATE_LABEL" style="color:#ffd24a; font-weight:bold;">Support the project</span>&nbsp;&middot;&nbsp;USDT (TRC-20):
                        <code onclick="awgCopyAddr('TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr', this);" title="Click to copy the address" data-i18n-title="DONATE_COPY_TITLE" style="cursor:pointer; padding:1px 4px; border:1px solid #555; border-radius:3px; font-size:11px;">TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr</code>
                    </span>
                    <span style="text-align:right;">
                        <a href="https://github.com/r0otx/asuswrt-merlin-amneziawg" target="_blank" style="text-decoration:none;">&copy; r0otx</a>
                        &nbsp;&middot;&nbsp;
                        <a href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" style="text-decoration:none;">&copy; DCRM</a>
                    </span>
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
<div id="awg_update_modal" role="dialog" aria-modal="true" aria-labelledby="awg_modal_title" style="display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.65); z-index:10000;">
    <div style="background:#2b3338; color:#e0e0e0; width:90%; max-width:680px; margin:4% auto; border:1px solid #444; border-radius:8px; box-shadow:0 6px 40px rgba(0,0,0,0.6); display:flex; flex-direction:column; max-height:84vh;">
        <div style="padding:14px 18px; border-bottom:1px solid #444; display:flex; align-items:center;">
            <span id="awg_modal_title" style="font-size:16px; font-weight:bold;" data-i18n="MODAL_UPDATE_TITLE">Update</span>
            <button type="button" aria-label="Close" data-i18n-aria="ARIA_CLOSE" onclick="closeUpdateModal();" title="Close" data-i18n-title="BTN_CLOSE" style="margin-left:auto; cursor:pointer; font-size:22px; line-height:1; opacity:0.6; background:transparent; border:none; color:inherit; padding:0;">&times;</button>
        </div>
        <div id="awg_modal_body" style="padding:14px 18px; overflow-y:auto; font-size:12px; line-height:1.5;"></div>
        <div style="padding:10px 18px; border-top:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:8px; font-size:12px;">
            <span style="opacity:0.75;" data-i18n="INSTALL_LABEL">Install:</span>
            <select id="awg_install_mode" onchange="awgModeUI();" class="awg-modal-input" aria-label="Install method" data-i18n-aria="ARIA_INSTALL_MODE">
                <option value="auto" data-i18n="OPT_INSTALL_AUTO">Automatic (latest)</option>
                <option value="version" data-i18n="OPT_INSTALL_VERSION">Choose version</option>
                <option value="file" data-i18n="OPT_INSTALL_FILE">Manually from file</option>
            </select>
            <input type="text" id="awg_version_input" placeholder="e.g. 1.1.49" data-i18n-ph="PH_VERSION" maxlength="12" class="awg-modal-input" aria-label="Version to install" data-i18n-aria="ARIA_VERSION_TO_INSTALL" style="width:100px; display:none;">
            <input type="file" id="awg_ipk_file" accept=".ipk" aria-label=".ipk file to install" data-i18n-aria="ARIA_IPK_FILE" style="display:none; color:#e0e0e0; max-width:100%;">
            <input type="button" id="awg_install_btn" class="button_gen" value="Install" data-i18n-val="BTN_INSTALL" onclick="installUpdate();">
        </div>
        <div id="awg_manual_progress" style="display:none; padding:0 18px 12px;">
            <div style="height:10px; background:#1c2226; border:1px solid #555; border-radius:5px; overflow:hidden;">
                <div id="awg_manual_bar" style="height:100%; width:0%; background:#cf0a2c; transition:width 0.2s;"></div>
            </div>
            <div id="awg_manual_msg" style="font-size:11px; opacity:0.85; margin-top:5px;"></div>
        </div>
        <div style="padding:12px 18px; border-top:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
            <span id="awg_modal_status" style="font-size:12px; opacity:0.75; margin-right:auto;"></span>
            <input type="button" class="button_gen" value="Check for updates" data-i18n-val="BTN_CHECK_UPDATES" onclick="checkForUpdate();">
            <input type="button" class="button_gen" value="Close" data-i18n-val="BTN_CLOSE" onclick="closeUpdateModal();" style="margin-left:8px;">
        </div>
    </div>
</div>

<!-- Diagnostics modal: shows the backend `diag` dump; copy = diag + log, wrapped for Telegram -->
<div id="awg_diag_modal" role="dialog" aria-modal="true" aria-labelledby="awg_diag_title" style="display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.65); z-index:10002;">
    <div style="background:#2b3338; color:#e0e0e0; width:92%; max-width:760px; margin:4% auto; border:1px solid #444; border-radius:8px; box-shadow:0 6px 40px rgba(0,0,0,0.6); display:flex; flex-direction:column; max-height:86vh;">
        <div style="padding:14px 18px; border-bottom:1px solid #444; display:flex; align-items:center;">
            <span id="awg_diag_title" style="font-size:16px; font-weight:bold;" data-i18n="MODAL_DIAG_TITLE">Diagnostic data</span>
            <button type="button" aria-label="Close" data-i18n-aria="ARIA_CLOSE" onclick="awgCloseDiag();" title="Close" data-i18n-title="BTN_CLOSE" style="margin-left:auto; background:transparent; border:none; color:inherit; font-size:22px; line-height:1; cursor:pointer; opacity:0.6; padding:0;">&times;</button>
        </div>
        <div id="awg_diag_body" style="padding:14px 18px; overflow:auto; font-family:'Courier New','Lucida Console',monospace; font-size:12px; line-height:1.45; white-space:pre-wrap; word-wrap:break-word;"></div>
        <div style="padding:10px 18px; border-top:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
            <input type="button" class="button_gen" value="Copy diagnostic data" data-i18n-val="BTN_COPY_DIAG" onclick="awgCopyDiagReport(this);">
            <span id="awg_diag_note" style="font-size:11px; color:#f0ad4e;"></span>
            <span style="font-size:11px; opacity:0.7;" data-i18n="DIAG_COPY_NOTE">Copied together with the log, wrapped for pasting into Telegram.</span>
            <input type="button" class="button_gen" value="Close" data-i18n-val="BTN_CLOSE" onclick="awgCloseDiag();" style="margin-left:auto;">
        </div>
    </div>
</div>

<div id="awg_analyze_modal" role="dialog" aria-modal="true" aria-labelledby="awg_analyze_title" style="display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.65); z-index:10003;">
    <div style="background:#2b3338; color:#e0e0e0; width:92%; max-width:760px; margin:4% auto; border:1px solid #444; border-radius:8px; box-shadow:0 6px 40px rgba(0,0,0,0.6); display:flex; flex-direction:column; max-height:86vh;">
        <div style="padding:14px 18px; border-bottom:1px solid #444; display:flex; align-items:center;">
            <div style="display:flex; flex-direction:column; min-width:0; flex:1;">
                <span id="awg_analyze_title" style="font-size:16px; font-weight:bold;">Traffic analysis</span>
                <span id="awg_analyze_sub" style="font-size:12px; color:#9aa3ad; margin-top:3px; font-family:'Courier New','Lucida Console',monospace; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;"></span>
            </div>
            <button type="button" data-i18n-aria="ARIA_CLOSE" onclick="awgCloseAnalyze();" data-i18n-title="BTN_CLOSE" style="margin-left:12px; flex:0 0 auto; background:transparent; border:none; color:inherit; font-size:22px; line-height:1; cursor:pointer; opacity:0.6; padding:0;">&times;</button>
        </div>
        <div style="padding:10px 18px; border-bottom:1px solid #444; display:flex; align-items:center; flex-wrap:wrap; gap:10px;">
            <input type="button" id="awg_analyze_toggle" class="button_gen" value="Start" data-i18n-val="ANALYZE_START" onclick="awgAnalyzeToggle(this);">
            <span style="font-size:12px;"><span data-i18n="ANALYZE_POLICY">Policy</span>: <b id="awg_analyze_policy">—</b></span>
            <span style="margin-left:auto; display:flex; gap:6px; align-items:center;">
                <span class="awg-verdict geo" data-i18n="VERDICT_VPN">VPN</span>
                <span class="awg-verdict direct" data-i18n="VERDICT_DIRECT">Direct</span>
            </span>
        </div>
        <div id="awg_analyze_body" style="padding:8px 18px; overflow:auto; min-height:170px;">
            <table id="awg_analyze_table">
                <thead><tr>
                    <th style="width:26px; text-align:center;"><input type="checkbox" id="awg_an_selall" onclick="awgAnalyzeToggleAll(this);" data-i18n-aria="ARIA_AN_SELALL" aria-label="Select all"></th>
                    <th style="width:60px;" data-i18n="ANALYZE_COL_TIME">Time</th>
                    <th data-i18n="ANALYZE_COL_NAME">Request</th>
                    <th style="width:160px;" data-i18n="ANALYZE_COL_DEST">Destination</th>
                    <th style="width:96px;" data-i18n="ANALYZE_COL_VERDICT">Route</th>
                </tr></thead>
                <tbody id="awg_analyze_rows"></tbody>
            </table>
            <div id="awg_analyze_empty" style="padding:20px 4px; color:#9aa3ad; font-size:12px;"></div>
        </div>
        <div style="padding:10px 18px; border-top:1px solid #444;">
            <details id="awg_analyze_note" class="awg-hint" style="margin:0 0 8px;">
                <summary style="cursor:pointer;" data-i18n="ANALYZE_NOTE_SUMMARY">What does this analysis show?</summary>
                <div style="margin-top:5px;" data-i18n="ANALYZE_NOTE">Diagnostic.</div>
            </details>
            <div style="display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
                <span id="awg_an_ack" class="awg-ack" style="margin-left:0;"></span>
                <label style="font-size:12px; color:#b6bdc7; margin-left:auto;" data-i18n="ANALYZE_TARGET_POLICY">Add to:</label>
                <select id="awg_an_policy" class="awg-modal-input" aria-label="Geo policy" data-i18n-aria="ANALYZE_TARGET_POLICY"></select>
                <input type="button" class="button_gen" id="awg_an_add" value="+ To custom domains/IPs" data-i18n-val="ANALYZE_ADD_SELECTED" onclick="awgAnalyzeAddSelected();">
                <input type="button" class="button_gen" value="Close" data-i18n-val="BTN_CLOSE" onclick="awgCloseAnalyze();">
            </div>
        </div>
    </div>
</div>

<div id="footer"></div>
</body>
</html>
