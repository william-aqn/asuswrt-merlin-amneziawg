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
/* Action row. Flex + align-items:center ONLY — deliberately no sizing of our own.
   History, because it is easy to "improve" this back into a bug (1.5.15 -> 1.5.16):
   the stock `.button_gen` is a fixed-height box, and on a gnuton/TUF build (field photos
   2026-08-03) «Сохранить и полностью перезапустить VPN» wrapped to three lines, so the fixed
   height clipped the last one AND, as inline-blocks align on the baseline of their LAST line,
   the taller button sat above «Применить». 1.5.15 fixed that by making our buttons size to their
   content (width/height auto) — which traded one bug for a worse one: a content-sized box is
   re-laid-out by ANY state-dependent metric the theme applies, so hovering a button resized it
   and the whole row jumped. The stock fixed box cannot do that, by construction.
   So: keep the stock geometry and make the LABELS fit it instead (they were shortened in 1.5.16;
   the full wording lives in each button's `title` and in the description block below the row).
   Do not add width/height/padding here without a way to test on the affected theme. */
.awg-actions { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 8px; }

/* Config-profile bar (multi-config): one row per slot, rendered by pfRenderBar(). */
.awg-pf-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    padding: 5px 8px;
    margin: 3px 0;
    border: 1px solid #3a4548;
    border-radius: 4px;
    background: rgba(255,255,255,0.03);
    cursor: pointer;
}
.awg-pf-row.sel {
    border-color: #2e88c7;
    background: rgba(46,136,199,0.10);
}
.awg-pf-badge {
    font-size: 10px;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 2px 8px;
    border-radius: 3px;
    background: #1a6e2e;
    border: 1px solid #2a8b42;
    color: #fff;
    white-space: nowrap;
}
.awg-pf-badge.auto { background: #b8860b; border-color: #daa520; }
.awg-pf-ep {
    color: #b6bdc7;
    font-size: 11px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 230px;
}

/* Field help text. #666 was near-invisible on the dark ROG theme; use a readable light
   gray (still secondary vs the white labels). code = the inline format/example sample. */
/* Protocol-version badge next to an obfuscation parameter. Which AmneziaWG version first
   shipped a param decides whether the PEER understands it at all, so it belongs on the
   label rather than buried in a hint. */
.awg-ver { display:inline-block; margin-left:6px; padding:0 5px; border-radius:8px;
           font-size:9px; font-weight:normal; line-height:15px; vertical-align:middle;
           background:#3a4548; border:1px solid #5a6b70; color:#b6bdc7; }
.awg-ver.v3 { background:#4a4230; border-color:#7a6a3a; color:#e8dfc8; }
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
#awg_hist_table { width: 100%; table-layout: fixed; }
/* Shared header style for the data tables. Headers are <td> (not <th>) so they pick up the
   firmware's gradient header background AND their width="%" attrs aren't overridden by the
   firmware's `.FormTable_table thead th { width:98px }` rule. */
#awg_peers_table thead td, #awg_client_table thead td, #awg_hist_table thead td {
    font-weight: bold;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.5px;
    text-align: center;
    white-space: nowrap;   /* keep headers on one line (both tables sit in a scrollable wrap) */
    padding: 6px 8px;   /* override firmware's asymmetric padding-left so centered text is truly centered */
}
#awg_peers_table tbody td, #awg_hist_table tbody td {
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
#awg_analyze_table td.awg-an-owner { color:#8a929c; font-size:11px; }
#awg_analyze_table td.awg-an-owner .awg-own-link { cursor:pointer; border-bottom:1px dotted #5a636b; }
#awg_analyze_table td.awg-an-owner .awg-own-link:hover { color:#cfd5db; border-bottom-color:#8fb7de; }
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
// Save-pipeline BASE (1.5.26, see awgSave): the store exactly as the firmware's reader showed it to
// this page, captured BEFORE any mutation below (the awg_ipk_ sweep, the legacy-key carry-forward,
// the orphan-meta sweep). A save compares the LIVE store against it — a page-owned key that differs
// was changed elsewhere since load (another tab, the AWG server page, the CLI) and the save is
// refused instead of reverting it; after a save it advances only to what THIS page wrote.
var awgCsBase = (function(){
    var b = {};
    for(var k in custom_settings){ if(custom_settings.hasOwnProperty(k)) b[k] = custom_settings[k]; }
    return b;
})();
// Set when another writer stored the settings at the same moment as one of our saves (result
// 'unknown') or a verified save read back different page-owned values: the base can no longer be
// trusted, so every later normal save is a conflict until the page is reloaded.
var awgCsStale = false;
// One-shot keys of the retired browser .ipk upload (1.1.52-1.5.23): never meant to persist, and
// every byte left in the store counts against the firmware's shared 8 KB cap — drop any leftover
// so the next save sweeps it out (the page's saves are full-replace).
(function(){ for(var k in custom_settings){ if(custom_settings.hasOwnProperty(k) && k.indexOf('awg_ipk_') === 0) delete custom_settings[k]; } })();
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
var awgTickTimer = null;    // singleton 1s interval: awgTickHandshakes + awgTickUptime (started once)
// GeoSite category autocomplete source. Seeded with a static fallback of common v2fly
// categories so suggestions work even when /user/v2fly_categories.htm is 404 — which happens
// on a fresh /opt whose v2fly DB hasn't downloaded yet, or when the DB download (a GitHub
// RELEASE asset, dlc.dat_plain.yml) is region-blocked. loadV2flyCategories() REPLACES this with
// the full ~1500-entry list once the DB is present. These are real v2fly category names, so a
// fallback pick still routes correctly; the full list just adds the long tail.
var v2flyList = ['google','youtube','telegram','twitter','facebook','instagram','whatsapp','tiktok',
    'netflix','spotify','twitch','discord','github','gitlab','steam','epicgames','apple','microsoft',
    'amazon','openai','cloudflare','reddit','wikipedia','disney','hbo','primevideo','soundcloud',
    'deezer','viber','signal','snapchat','pinterest','linkedin','medium','paypal','speedtest','adobe',
    'nvidia','docker','stackoverflow','playstation','xbox','nintendo','roblox','ubisoft','oracle',
    'zoom','slack','dropbox','protonmail','mozilla','category-ads-all','category-porn','category-games',
    'category-media','category-dev','category-ai-!cn'];
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
    // ---- install actions ----
    MSG_ENTER_VERSION: "Enter a version as X.Y.Z, e.g. 1.1.49",
    MSG_VERSION_FORMAT: "Version as X.Y.Z, e.g. 1.1.49",
    MSG_VERSION_INSTALLED_REINSTALL: "Version v{0} is already installed. Reinstall?",
    MSG_LATEST_VERSION: "You already have the latest version{0}.",
    MSG_LATEST_VERSION_VER: " (v{0})",
    BTN_INSTALL: "Install",
    // ---- install from a local file (SSH only since 1.5.24) ----
    INSTALL_FILE_HELP: "A local <code>.ipk</code> can't be uploaded through this page: the router firmware discards any addon settings save over {1} KB, and a package weighs megabytes. Install it over SSH instead:<br>1. Copy the file to the router's <code>/tmp</code> — WinSCP with file protocol <b>SCP</b>, or<br><code>scp -O amneziawg_*.ipk &lt;login&gt;@{0}:/tmp/</code> (<code>-O</code>: the router has no SFTP — drop it if your scp rejects it; add <code>-P &lt;port&gt;</code> if SSH isn't on 22)<br>2. In an SSH session run<br><code>/opt/etc/init.d/S99amneziawg install_ipk /tmp/amneziawg_X.Y.Z-1_&lt;arch&gt;.ipk</code><br>The package is checked (gzip CRC + .ipk structure) and installed exactly like an update from this page: geo lists are kept, the VPN is stopped for the install — start it again afterwards. If the router can reach GitHub, «Choose version» installs any published version without a file.",
    // ---- apply / restart ----
    MSG_FORCE_RESTART_CONFIRM: "The VPN will be fully restarted (stop → start) — the connection will drop briefly (devices on a VPN policy lose access for a few seconds). Routes and the firewall will also be rebuilt. Continue?",
    BTN_APPLYING: "Applying…",
    ACK_SAVED: "Saved ✓",
    ACK_SEND_FAILED: "Could not send — try again",
    // ---- first-run / validation ----
    TITLE_IMPORT_FIRST: "Import a configuration (.conf) first",
    MSG_INIT_NON_ASCII: "Fields I1–I5 contain invalid (non-ASCII) characters.",
    MSG_IPARAM_MALFORMED: "Field {0} looks truncated or malformed: the «< >» brackets don't match, or it doesn't end with «>». Re-copy the full value from your config (a valid I-param ends with «>»).",
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
    ANALYZE_COL_OWNER: "Owner",
    OWNER_CLICK_HINT: "click: add this network · Shift-click: whole AS",
    OWNER_PFX: "AS: {0} IPv4 prefixes",
    OWNER_LOOKING: "Looking up the network…",
    OWNER_NO_PREFIX: "Couldn't determine the network.",
    OWNER_NO_ASN: "No ASN for this owner.",
    OWNER_CONFIRM_NET: "Add {0} — network {1} — to this policy's custom IPs?",
    OWNER_CONFIRM_AS: "Add ALL {2} IPv4 prefixes of {0} ({1}) to custom IPs? This can be a lot.",
    OWNER_ADDED_NET: "Added network {0} ({1} new). Don't forget Apply.",
    OWNER_ADDED_AS: "Added {0} ranges of {1}. Don't forget Apply.",
    VERDICT_VPN: "VPN",
    VERDICT_GEO: "VPN (Geo)",
    VERDICT_DIRECT: "Direct",
    VERDICT_PENDING: "resolving…",
    ANALYZE_NOTE_SUMMARY: "What does this analysis show?",
    ANALYZE_NOTE: "Diagnostic. Shows the device's DNS requests (tagged DNS — what it's trying to reach) and its actual connections, each labeled Direct or VPN/Geo. Starting briefly restarts DNS to capture queries; only devices that use the router as DNS are visible. Verdict reflects the device's applied policy and the current geo lists. Owner (ASN) is resolved in your browser via an external service (ipwho.is).",
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
    DIAG_DOWNLOADED: "Downloaded ✓",
    DIAG_DOWNLOAD_FAILED: "Download failed",
    DIAG_DOWNLOAD_NOTE: "Saves the diagnostics + log as a .txt file. Or copy (📋) to paste into Telegram.",
    BTN_DOWNLOAD_DIAG: "Download .txt",
    TITLE_DOWNLOAD_DIAG: "Download the diagnostics and the log as a .txt file",
    BTN_COPY_DIAG_MINI: "Copy to clipboard (for Telegram)",
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
    FWVPN_ACTIVE: "⛔ The <b>firmware's own VPN client</b> is routing traffic ahead of AmneziaWG ({0}). Its policy rule outranks ours (ip-rule priority &lt;98), so devices assigned to AmneziaWG actually leave through the firmware VPN. Disable the firmware VPN client (VPN → VPN Client / VPN Fusion) or unbind the devices from it.",
    FWVPN_ENABLED: "⚠ A <b>firmware VPN client profile is enabled</b> ({0}) but not connected. The moment it connects, its routing rule will outrank AmneziaWG's (ip-rule priority &lt;98) and silently capture the traffic. If the profile is unused — disable it in the router UI (VPN → VPN Client / VPN Fusion).",
    NOHS: "⚠ The tunnel is up but <b>has not completed a handshake</b> — the server (endpoint) is not responding. Usual causes: wrong/unreachable endpoint, the server is down, or the obfuscation parameters don't match the server. Nothing is actually being tunnelled yet{0}. Check the endpoint and re-import the config from the provider if needed.",
    NOHS_KS: " — and with the <b>kill-switch ON</b>, all VPN-routed traffic is blocked, so those devices have no internet until the handshake succeeds",
    DNSGEO_USER: "⚠ Domain-based geo lists are active ({0} domains in dnsmasq), but <b>DNS interception is off</b> (compatibility mode). Domains feed the routing only for clients that use the router's DNS — devices with DoH/private DNS bypass the VPN, so in practice mostly the IP lists (GeoIP/Antifilter) route. Not running zapret/Xray/b4? Turn compatibility mode off to re-enable interception.",
    DNSGEO_AUTO: "⚠ Domain-based geo lists are active ({1} domains), but DNS interception is <b>disabled automatically because of {0}</b>. Domains populate only for clients that use the router's DNS; IP lists keep working.",
    MEM_SQUEEZE_NOSWAP: "⚠ <b>The router is short on memory for this tunnel.</b> This firmware uses strict memory accounting (<code>vm.overcommit_memory=2</code>), and so little of that budget is left that the VPN daemon runs at its minimum settings: heap ceiling {0} MiB, packet buffer pool {1} × 64 KB. Under sustained load — video through the tunnel above all — the daemon can run out of memory, crash and be restarted by the watchdog, which looks like «the VPN drops every few minutes». <b>What helps:</b> a <b>swap file on the USB drive</b> (amtm → swap, 1 GB) — under strict accounting swap raises the memory budget one-to-one, and the next tunnel start gets a higher ceiling. Use a healthy drive: if it fails or is unplugged, programs whose memory was moved to swap will crash. Stopping unused addons and Entware services also frees budget, but usually far less.",
    MEM_SQUEEZE_SWAP: "⚠ <b>The router is short on memory for this tunnel.</b> Even with swap ({2} MiB), strict memory accounting (<code>vm.overcommit_memory=2</code>) leaves so little budget that the VPN daemon runs at its minimum settings: heap ceiling {0} MiB, packet buffer pool {1} × 64 KB. Under sustained load the daemon can run out of memory and be restarted by the watchdog — it looks like «the VPN drops every few minutes». <b>What helps:</b> enlarge the swap file (e.g. to 1 GB), or stop other memory consumers — unused addons and Entware services, and firmware features such as AiProtection, Traffic Analyzer or Adaptive QoS (their background services count against this budget). The next tunnel start picks up the higher ceiling.",
    CONF_PENDING: "⚠ The saved connection config differs from the one the tunnel is <b>currently running</b>. «Apply» updates routing/geo on the fly but never restarts the tunnel — press <b>«Restart»</b> to switch to the new config (keys, endpoint, obfuscation, DNS, MTU).",
    GEO_MATCHALL: "⛔ A rule in your <b>custom dnsmasq config</b> is routing <b>every</b> domain into a geo set, so Geo mode sends <b>all</b> traffic through the VPN (every site shows the VPN IP and geo-restricted services stop working). The offending line:<div style=\"margin:6px 0;\"><code>{0}</code></div>The <code>https://</code> (or a stray <code>//</code>) leaves an empty segment, which dnsmasq treats as “match everything”. Fix it in your custom dnsmasq config (<code>/jffs/configs/dnsmasq.conf.add</code>): keep only the bare domain — e.g. <code>ipset=/example.com/awg_dst</code> — then restart dnsmasq or reboot. AmneziaWG's own generated rules are fine; this is a hand-added line.",
    COEX_FOOTER: "<span style=\"opacity:0.85;\">After the changes, click <b>«Apply»</b>. GeoIP routing by IP keeps working in the meantime.</span>",
    XRAY_CAP_HEADER: "ℹ <b>XRAYUI / Xray</b> is running in <b>transparent-proxy mode (TPROXY, «redirect all traffic»)</b>, capturing the router's LAN traffic. AmneziaWG now automatically gives the devices you assigned to it (<b>«VPN: all traffic»</b> / <b>«VPN: Geo only»</b>) <b>priority into the tunnel, ahead of Xray</b> — those devices go through AmneziaWG, while the rest of the LAN keeps using Xray. Both run side by side; no action is needed for this.",
    XRAY_CAP_FIX: "<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li>Want <b>all</b> traffic through AmneziaWG instead of Xray? Set the default policy to <b>«VPN — all traffic»</b>, or stop Xray below.</li><li>If the AmneziaWG tunnel itself <b>won't pass traffic</b> (stays «Connecting…» / rolls back), Xray may also be grabbing the router's <i>own</i> handshake — that part the priority chain can't fix. In <b>XRAYUI</b>, exclude AmneziaWG's <b>endpoint</b> and the <b>awg0</b> interface from capture, or stop Xray.</li></ul>",
    XRAY_CAP_TECH: "<span style=\"opacity:0.85;\">Xray's <code>from all fwmark 0x10000/0x10000</code> rule (priority 19) sits ahead of AmneziaWG's fwmark rule (priority 98); AmneziaWG restores priority with an <code>AWG_PRIO</code> mangle chain hooked at the top of PREROUTING (before XRAYUI) that marks and accepts your assigned devices' tunnel-bound packets before Xray sees them.</span>",
    XRAY_STOP_BTN: "Stop Xray",
    XRAY_STOPPING: "Stopping Xray…",
    XRAY_STOP_CONFIRM: "Stop Xray / XRAYUI now? This is a regular stop via XRAYUI's own command — same as the Stop button on its page. Only the active transparent-proxy (TPROXY) firewall rules are removed so AmneziaWG can route traffic; XRAYUI's saved settings and rules are not touched. Start it again from its page (VPN → X-RAY) and it will come back with all its previous settings.",
    // ---- Broadcom CTF (HW NAT acceleration) blocks the tunnel ----
    CTF_BLOCK_HEADER: "⛔ <b>Hardware NAT acceleration (Broadcom CTF)</b> is enabled on this router. AmneziaWG relies on policy routing, which on this platform is <b>incompatible</b> with CTF — starting the tunnel corrupts the accelerator's kernel state and <b>hangs the router until its watchdog reboots it</b>. The tunnel will not start until CTF is disabled.",
    CTF_BLOCK_FIX: "<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li>Click the button below to disable CTF (<code>ctf_disable=1</code>) and reboot — the same fix Merlin applies for its own policy-routed VPN clients. After the reboot AmneziaWG starts normally.</li><li>Trade-off: with CTF off, NAT throughput drops somewhat (the CPU forwards packets). You can re-enable acceleration in the firmware later if you stop using AmneziaWG.</li></ul>",
    CTF_DISABLE_BTN: "Disable acceleration & reboot",
    CTF_DISABLING: "Disabling & rebooting…",
    CTF_DISABLE_CONFIRM: "Disable hardware NAT acceleration (CTF) and REBOOT the router now? This is required for AmneziaWG to work on this model. The router will be unreachable for a minute or two while it restarts.",
    // ---- kernel too old for sendmmsg() → daemon can't send packets ----
    KERNEL_UNSUP_HEADER: "⚠️ This router runs an old kernel (Linux&nbsp;2.6.x — RT-AC68U and similar), where AmneziaWG is <b>experimental</b>. Testing on real hardware showed the <b>tunnel core works</b> (handshake completes, traffic flows both ways) — but the full start can sometimes destabilise the router (the WAN connection may drop, and the router may reboot) on this old kernel. <b>You can start the tunnel, but at your own risk.</b>",
    KERNEL_UNSUP_BODY: "If the router becomes unreachable after you start it, it reboots on its own and comes back with the tunnel stopped. Keep <b>«Autostart after reboot» OFF</b> so a bad start can't loop. Routers on Linux&nbsp;3.x/4.x/5.x are unaffected — this note only appears on 2.6.x.",
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
    MSG_WD_COPIED: "Copied: {0}. Press «Apply» to save.",
    MSG_WD_COPIED_DROPPED: "Copied: {0} — some entries were skipped (the tunnel probe works over IPv4 only, up to 4 hosts). Press «Apply» to save.",
    MSG_WD_DNS_ALL_V6: "The DNS field has no IPv4 address — the tunnel probe works over IPv4 only; enter e.g. 8.8.8.8.",
    TH_INTERFACE: "Interface",
    FIRSTRUN_HTML: "<b>It looks like no configuration is set yet.</b><br>\n                    Start by importing a <code>.conf</code> file from the Amnezia VPN app, then check the fields and click «Apply».",
    BTN_IMPORT_CONFIG: "Import configuration",
    SEC_CONNECTED_PEERS: "Connected peers",
    TH_SERVER_ADDR: "Server address",
    TH_ALLOWED_IPS: "Allowed IPs",
    TH_TRAFFIC: "Traffic (rx/tx)",
    TH_LAST_HANDSHAKE: "Last handshake",
    LBL_NO_PEERS: "No peers",
    // ---- connection uptime & history ----
    TITLE_UPTIME: "Current connection uptime",
    DUR_S: "{0} s",
    DUR_M: "{0} min",
    DUR_HM: "{0} h {1} min",
    DUR_DH: "{0} d {1} h",
    SEC_CONN_HISTORY: "Connection history",
    TH_HIST_START: "Started",
    TH_HIST_DURATION: "Duration",
    TH_HIST_END: "Ended by",
    HIST_R_USER: "stopped by user",
    HIST_R_RESTART: "restart",
    HIST_R_ROLLBACK: "auto-rollback (tunnel had no traffic)",
    HIST_R_WATCHDOG: "watchdog restart",
    HIST_R_UPDATE: "addon update",
    HIST_R_DEADMAN: "emergency rollback (LAN protection)",
    HIST_R_REBOOT: "router reboot",
    HIST_R_INTERRUPTED: "interrupted (crash)",
    HIST_R_AUTO: "auto stop",
    HIST_R_SWITCH: "profile switch",
    HIST_R_FAILOVER: "auto-switch to a reserve profile",
    TH_PROFILE: "Profile",
    PF_UNNAMED: "Profile {0}",
    LBL_PF_ACTIVE: "Active",
    LBL_PF_AUTO: "auto (failover)",
    LBL_PF_EMPTY: "empty — import a .conf or fill the form below",
    LBL_PF_FO: "failover",
    BTN_PF_SWITCH: "Switch to",
    BTN_PF_ADD: "+ Add profile",
    TITLE_PF_EDIT: "Click the row to edit this profile in the form below",
    TITLE_PF_FO: "Participates in automatic failover",
    TITLE_PF_DELETE: "Delete profile",
    LBL_PF_FAILOVER: "Auto-switch profiles on failure",
    HINT_PF_BAR: "The form below edits the highlighted profile; «Apply» saves it. «Switch to» saves everything AND restarts the tunnel on that profile.",
    HINT_PF_FAILOVER: "Auto-switch: if the started tunnel fails the ~60s connectivity check, the next profile is tried in a circle (see the journal). A reboot or a manual switch returns to your chosen profile.",
    MSG_PF_SWITCH_CONFIRM: "Apply settings and switch to profile \"{0}\"? The tunnel will be restarted.",
    MSG_PF_DELETE_CONFIRM: "Delete profile \"{0}\"? It is deleted right away (the tunnel is not restarted); unsaved profile names and failover checkboxes in this list are saved together with the deletion.",
    MSG_PF_DEL_ACTIVE: "Can't delete the active profile — switch to another one first.",
    MSG_PF_DEL_PRIMARY: "This is your primary profile, and a backup one is running right now (auto-switch). Switch to another profile first.",
    MSG_PF_DISCARD_NEW: "Discard the unsaved profile \"{0}\"?",
    MSG_PF_WAIT_TRANSITION: "Wait until the tunnel finishes connecting or stopping, then try again.",
    MSG_PF_SWITCH_BUSY: "The router is busy (the tunnel is connecting or stopping, or lists are downloading) — try again in a few seconds.",
    MSG_PF_SWITCH_EMPTY: "Can't switch to profile \"{0}\": its form below is empty. Fill it in (or import a .conf) or pick another profile; to delete this one, use the ✕ button in its row. Nothing was saved.",
    MSG_PF_DEL_PENDING_OVER: "The profile is deleted on this page, but the settings still don't fit the firmware's limit: {0} of {1} bytes. Delete another profile or shorten the lists, then press «Apply».",
    MSG_PF_DEL_PENDING_KEY: "The profile is deleted on this page but not saved yet: one of the fields doesn't fit the firmware's store. Fix it and press «Apply» (reloading the page before that brings the profile back).",
    LBL_PF_DELETING: "Deleting…",
    LBL_PF_DELETED: "Profile deleted ✓",
    HINT_PF_UNSAVED: "Profile changes are not saved — press «Apply»",
    MSG_SWITCH_SKIPPED: "The router was busy and skipped the profile switch: the profile is saved, but the tunnel was not restarted on it.",
    BTN_SWITCH_RETRY: "Retry the switch",
    MSG_SWITCH_FAILED: "The profile switch did not complete — see the journal below for the reason.",
    MSG_PF_UNSAVED: "Profile \"{0}\" has unsaved edits in the form — discard them?",
    MSG_PF_FULL: "All {0} profile slots are in use.",
    // ---- settings save pipeline (live-store check + verification, 1.5.26) ----
    BTN_CHECKING: "Checking…",
    MSG_WAIT_SAVE: "Please wait — settings are being saved",
    ACK_SAVED_BUSY: "Saved; the router was busy — the action may not have run, check the journal",
    MSG_CS_CONFLICT: "The settings changed after this page was loaded (another tab, the AWG server page or SSH). To avoid overwriting those changes, the save was cancelled. Reload the page now? Unsaved edits on this page will be lost.",
    MSG_ROUTER_BUSY: "The router is not responding (the tunnel is restarting or lists are downloading) — try again in a few seconds.",
    MSG_SESSION_EXPIRED: "Your router login session has expired — log in again in another tab and retry; the edits on this page are kept.",
    MSG_SAVE_DISCARDED: "The router did not store the settings (the firmware rejected the save). Reload the page to see the current state.",
    TAIL_SWITCH: "The switch was not performed.",
    TAIL_FORCEAPPLY: "The tunnel was restarted with the previous settings.",
    TAIL_GEO: "The previously saved lists are being downloaded.",
    TAIL_DELETE: "The profile was not deleted.",
    TAIL_ANALYZE: "The capture was stopped.",
    MSG_CS_UNKNOWN: "Another page stored the settings at the same moment as this save — the result is unknown. Reload the page.",
    MSG_STORE_TRUNCATED: "The router stored the settings only partially (/jffs is probably full). Don't reload the page: free some space and press «Apply» again.",
    MSG_UPDATE_PIN_LOST: "The router did not store the chosen version (the firmware rejected the save) — it installs the latest release instead.",
    OVF_BREAKDOWN: "What takes the space (bytes of the saved settings):",
    OVF_PROFILE: "Profile #{0} «{1}»: {2} bytes (I1–I5: {3} of them)",
    OVF_GEO: "Geo policy «{0}»: {1} bytes",
    OVF_CLIENTS: "Device list: {0} bytes",
    OVF_AWG_OTHER: "Other AmneziaWG settings: {0} bytes",
    OVF_SERVER: "AWG server (awgs_*): {0} bytes",
    OVF_OTHER_ADDONS: "Other addons: {0} bytes — can only be freed in their own settings",
    OVF_LIVE_OVER: "The router's store ALONE is already over the limit ({0} of {1} bytes): no addon page can save anything until it shrinks.",
    MSG_SETTINGS_TOO_BIG: "Settings don't fit the firmware's store: {0} of {1} bytes. Asuswrt-Merlin does not save a larger set at all (the whole save is discarded), and this budget is shared with every other addon. Shorten I1-I5 junk data, delete an unused profile, or trim the GeoCustom lists.",
    MSG_SETTING_TOO_LONG: "«{0}» is too long for the firmware's store: {1} of {2} characters (the firmware silently cuts longer values). Shorten it.",
    SEC_CONFIG: "Configuration",
    BTN_IMPORT_CONF_FILE: "Import .conf",
    TITLE_IMPORT_CONF_FILE: "Import a .conf file from the Amnezia VPN client",
    OBF_SUMMARY_HTML: "AmneziaWG Obfuscation <span style=\"font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;\">— obfuscation parameters (usually filled in by importing a config) ▾</span>",
    TBL_AWG3: "AmneziaWG 3.0 — needs a 3.0-capable peer on the OTHER side too. Leave empty unless the provider's config has them.",
    AWG3_UNSUPPORTED: "AmneziaWG 3.0 parameters are not supported by the installed binaries — the fields below are disabled. Update the addon to a build with AWG 3.0 support.",
    HINT_AWG3_HPK: "Shared key — must be IDENTICAL on the server and every client. Requires S1–S4 ≥ 12 (all four, S3 included).",
    HINT_AWG3_CPA: "A single number or a \"lo-hi\" range: extra bytes per data packet. A padded packet never exceeds the largest one sent since the peer's last reply (500 B minimum), so the biggest packets go unpadded.",
    HINT_AWG3_RAT: "How long a session lives before a rekey. Default 120. Must stay below RejectAfterTime.",
    HINT_AWG3_RTO: "Retry interval for an unanswered handshake. Default 5. Very small values cause a handshake storm.",
    HINT_AWG3_RJT: "A session is dropped after this. Default 180. Below RekeyAfterTime the tunnel dies before it can rekey.",
    HINT_AWG3_KAT: "Passive keepalive delay. Default 10 — this is NOT Persistent Keepalive (25).",
    HINT_AWG3_MHA: "Handshake retries before giving up. Default 18.",
    AWG31_UNSUPPORTED: "AmneziaWG 3.1 parameters (RandomTrailers / DisableCookies) are not supported by the installed binaries — those two fields are disabled.",
    OPT_AWG31_UNSET: "— (default: off)",
    HINT_AWG31_RT: "Random-length tail on handshake packets (size obfuscation). SYMMETRIC: a peer without it drops OUR trailered handshakes — set only what the provider's config says. Needs AmneziaWG 3.1+ on both sides.",
    HINT_AWG31_DC: "Never send WireGuard cookie replies (a load-protection message DPI can fingerprint). Affects this side only — safe with any peer. Trade-off: this side loses its handshake-flood protection.",
    UNIT_BYTES: "bytes",
    UNIT_SEC: "sec",
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
    HINT_WATCHDOG_HTML: "<summary>Addresses the watchdog pings <b>through the tunnel</b> every 5 minutes (if at least one replies, the tunnel is alive). <u>Format and examples</u></summary><b>Format:</b> IPv4 or domain, several allowed — separated by a space or comma (up to 4 addresses; IPv6 is not supported — the probe rides the tunnel's IPv4).<br><b>Example:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Prefer IPs (no dependency on DNS). Empty = default <b>8.8.8.8</b> and <b>1.1.1.1</b>. Change it if those addresses are blocked/unreachable for you — otherwise the watchdog restarts the VPN needlessly. Which addresses are checked is shown in the log below.",
    TH_ZAPRET_COMPAT: "Compatibility mode",
    LBL_NO_DNS_INTERCEPT: "Compatibility mode — coexist with zapret2 / Xray / b4 (don't intercept DNS)",
    LBL_TUNNEL_DNS_TH: "DNS via tunnel",
    LBL_TUNNEL_DNS: "Route the whole LAN's DNS through the tunnel to the servers above while the VPN is up (needs DNS interception ON — inert in compatibility mode; defeats ISP DNS poisoning)",
    HINT_DNS: "used by “DNS via tunnel” below; empty = firmware DNS",
    HINT_NO_DNS_HTML: "<summary>Compatibility mode: disables AmneziaWG's DNS interception (port :53) so it can't clash with a co-resident DPI/proxy tool. ON by default for new installs. <u>Details</u></summary>Keep it on if <b>zapret2</b>, <b>Xray/XRAYUI</b> (v2ray, sing-box) or <b>b4</b> runs alongside — otherwise a DNS conflict can leave the network without internet. Geo by IP (GeoIP/antifilter) keeps working; geo by domains keeps working for clients that use the router as their DNS — only clients with a hardcoded external resolver lose domain-geo. A nearby zapret2 / Xray / v2ray / sing-box / b4 or NFQUEUE/TPROXY (iptables or nft) footprint also disables interception automatically even without this checkbox. Note: this only resolves the DNS conflict — with the «VPN — all traffic» policy, routing still takes the proxy's traffic, so for compatibility choose «Direct» or «VPN — Geo only».",
    TH_AUTOSTART: "Autostart",
    LBL_AUTOSTART: "Start the tunnel automatically after a router reboot",
    HINT_AUTOSTART: "On (default): the tunnel comes up by itself when the router boots. Turn it off to keep the tunnel stopped across reboots (e.g. while debugging another tool) — the configured connection is fully preserved, just start it manually with the «Start» button when needed. Manual start/restart and the watchdog of an already-running tunnel are not affected.",
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
    HINT_GEO_CUSTOM_FORMAT: "One entry per line. A domain (<code>example.com</code>) is routed via DNS; an IPv4 address or CIDR subnet (<code>1.2.3.0/24</code>) is added to the ipset (IPv6 is skipped). Text after <code>#</code> is a comment. A URL must return a plain-text list in this format. Files live inside the firmware's settings store, which holds only <b>about 2 KB of text per tab (~150 lines)</b> — put a bigger list online (e.g. a GitHub raw link) and add it as a URL source: those have no size limit.",
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
    MSG_GEO_FILES_TOO_BIG: "«Custom files»{0} on the «{1}» tab take {2} characters once encoded, but the firmware's settings store keeps at most {3} per tab (about 2 KB of text, ~150 CIDR lines) and silently cuts the rest. Shrink the files, or put a big list online (e.g. a GitHub raw link) and add it under «URL sources» — those have no size limit.",
    GEO_FILES_EXC_SUFFIX: " (exclusions)",
    GEO_FILE_CUT: "⚠ The firmware cut this file when it was saved (its settings store keeps ~2 KB of text per tab): only the part that survived is shown, the partial last line was dropped, and any files after it were lost. Shrink it, or move the list to a URL source.",
    GEO_FILE_UNREADABLE: "⚠ The stored content of this file is damaged (cut by the firmware's settings store) and can't be shown. Paste it again (smaller) or delete the row.",
    MSG_GEO_URL_BAD: "«URL sources» on the «{0}» tab: \"{1}\" is not an http:// or https:// link.",
    MSG_GEO_URL_IDN: "«URL sources» on the «{0}» tab: \"{1}\" has a non-Latin host name — the router's downloader needs its punycode (xn--…) form. Copy the link from the browser's address bar after opening it, or convert the domain with any IDN converter.",
    GEO_URLS_CUT: "⚠ The firmware cut this URL list when it was saved (its settings store keeps ~3000 characters per value): the last, partial link was dropped and any links after it were lost. Re-add them.",
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
    BTN_SAVE_RESTART: "Save and restart",
    TITLE_SAVE_RESTART: "Save + restart the VPN (stop → start) + full rebuild of routes and firewall",
    APPLY_DESC1_HTML: "<b>Apply</b> — save the settings and apply them «on the fly»: devices, routing policies, the firewall and the GeoIP/GeoSite lists update <b>without dropping the VPN connection</b>. Changes to the connection config itself (keys, endpoint, obfuscation, DNS, MTU) take effect only after <b>«Restart»</b> — a yellow notice will point that out. If the VPN is stopped — the settings are just saved and applied at the next start.",
    APPLY_DESC2_HTML: "<b>Save and fully restart the VPN</b> (stop → start) — the config is re-applied (awg setconf), the interface, routes and firewall are rebuilt, the connection drops for a couple of seconds. Needed when changing keys, the server (Endpoint), MTU or obfuscation parameters (Jc, S1, H1…H4), or if the connection is «stuck».",
    SEC_LOG: "Log",
    BTN_GET_DIAG: "Diagnostics",
    TITLE_GET_DIAG: "Collect a full diagnostic report and copy it together with the log",
    LOG_WAITING: "Waiting for data…",
    MODAL_UPDATE_TITLE: "Update",
    INSTALL_LABEL: "Install:",
    ARIA_INSTALL_MODE: "Install method",
    OPT_INSTALL_AUTO: "Automatic (latest)",
    OPT_INSTALL_VERSION: "Choose version",
    OPT_INSTALL_FILE: "From a local file (over SSH)",
    PH_VERSION: "e.g. 1.1.49",
    ARIA_VERSION_TO_INSTALL: "Version to install",
    BTN_CHECK_UPDATES: "Check for updates",
    BTN_CLOSE: "Close",
    MODAL_DIAG_TITLE: "Diagnostic data",
    BTN_COPY_DIAG: "Copy diagnostic data",
    DIAG_COPY_NOTE: "Copied together with the log, wrapped for pasting into Telegram."
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
    // ---- install actions ----
    MSG_ENTER_VERSION: "Введите версию в формате X.Y.Z, например 1.1.49",
    MSG_VERSION_FORMAT: "Версия в формате X.Y.Z, например 1.1.49",
    MSG_VERSION_INSTALLED_REINSTALL: "Версия v{0} уже установлена. Переустановить?",
    MSG_LATEST_VERSION: "У вас последняя версия{0}.",
    MSG_LATEST_VERSION_VER: " (v{0})",
    BTN_INSTALL: "Установить",
    // ---- install from a local file (SSH only since 1.5.24) ----
    INSTALL_FILE_HELP: "Свой <code>.ipk</code> через эту страницу загрузить нельзя: прошивка роутера отбрасывает любое сохранение настроек аддона больше {1} КБ, а пакет весит мегабайты. Поставьте его по SSH:<br>1. Скопируйте файл в <code>/tmp</code> роутера — WinSCP с протоколом <b>SCP</b> или<br><code>scp -O amneziawg_*.ipk &lt;логин&gt;@{0}:/tmp/</code> (<code>-O</code> — SFTP на роутере нет; если scp его не знает, уберите; если SSH не на 22-м порту, добавьте <code>-P &lt;порт&gt;</code>)<br>2. В SSH-сессии выполните<br><code>/opt/etc/init.d/S99amneziawg install_ipk /tmp/amneziawg_X.Y.Z-1_&lt;arch&gt;.ipk</code><br>Пакет проверяется (CRC gzip + структура .ipk) и ставится так же, как обновление с этой страницы: гео-списки сохраняются, VPN на время установки останавливается — потом запустите его снова. Если роутер видит GitHub, «Выбрать версию» поставит любую опубликованную версию без файла.",
    // ---- apply / restart ----
    MSG_FORCE_RESTART_CONFIRM: "VPN будет полностью перезапущен (stop → start) — соединение временно прервётся (устройства с политикой VPN потеряют доступ на несколько секунд). Заодно пересоберутся маршруты и firewall. Продолжить?",
    BTN_APPLYING: "Применение…",
    ACK_SAVED: "Сохранено ✓",
    ACK_SEND_FAILED: "Не удалось отправить — повторите",
    // ---- first-run / validation ----
    TITLE_IMPORT_FIRST: "Сначала импортируйте конфигурацию (.conf)",
    MSG_INIT_NON_ASCII: "Поля I1–I5 содержат недопустимые (не-ASCII) символы.",
    MSG_IPARAM_MALFORMED: "Поле {0} выглядит обрезанным или повреждённым: скобки «< >» не сходятся либо значение не оканчивается на «>». Скопируйте полное значение из конфига заново (корректный I-параметр оканчивается на «>»).",
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
    ANALYZE_COL_OWNER: "Владелец",
    OWNER_CLICK_HINT: "клик: добавить эту подсеть · Shift+клик: весь AS",
    OWNER_PFX: "AS: {0} IPv4-префиксов",
    OWNER_LOOKING: "Определяю подсеть…",
    OWNER_NO_PREFIX: "Не удалось определить подсеть.",
    OWNER_NO_ASN: "У этого владельца нет ASN.",
    OWNER_CONFIRM_NET: "Добавить {0} — подсеть {1} — в «Свои IP» этой политики?",
    OWNER_CONFIRM_AS: "Добавить ВСЕ {2} IPv4-префиксов {0} ({1}) в «Свои IP»? Это может быть много.",
    OWNER_ADDED_NET: "Добавлена подсеть {0} ({1} нов.). Не забудьте «Применить».",
    OWNER_ADDED_AS: "Добавлено {0} диапазонов {1}. Не забудьте «Применить».",
    VERDICT_VPN: "VPN",
    VERDICT_GEO: "VPN (Geo)",
    VERDICT_DIRECT: "Напрямую",
    VERDICT_PENDING: "резолв…",
    ANALYZE_NOTE_SUMMARY: "Что показывает этот анализ?",
    ANALYZE_NOTE: "Диагностика. Показывает DNS-запросы устройства (метка DNS — что оно пытается вызвать) и его реальные соединения, у каждого — вердикт «напрямую» или «VPN/Geo». При старте кратко перезапускается DNS для захвата запросов; видны только устройства, использующие роутер как DNS. Вердикт отражает применённую политику устройства и текущие гео-списки. Владелец (ASN) резолвится в вашем браузере через внешний сервис (ipwho.is).",
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
    DIAG_DOWNLOADED: "Скачано ✓",
    DIAG_DOWNLOAD_FAILED: "Не удалось скачать",
    DIAG_DOWNLOAD_NOTE: "Сохраняет диагностику + журнал в файл .txt. Или скопировать (📋) для вставки в Telegram.",
    BTN_DOWNLOAD_DIAG: "Скачать .txt",
    TITLE_DOWNLOAD_DIAG: "Скачать диагностику и журнал одним .txt-файлом",
    BTN_COPY_DIAG_MINI: "Скопировать в буфер (для Telegram)",
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
    FWVPN_ACTIVE: "⛔ <b>Прошивочный VPN-клиент</b> маршрутизирует трафик раньше AmneziaWG ({0}). Его правило стоит выше нашего (приоритет ip-rule &lt;98) — устройства, назначенные в AmneziaWG, фактически уходят через VPN прошивки. Отключите VPN-клиента прошивки (VPN → VPN-клиент / VPN Fusion) или отвяжите от него устройства.",
    FWVPN_ENABLED: "⚠ В прошивке <b>включён профиль VPN-клиента</b> ({0}), но он сейчас не подключён. Как только он подключится, его правило маршрутизации встанет выше правил AmneziaWG (приоритет ip-rule &lt;98) и незаметно заберёт трафик. Если профиль не используется — выключите его в интерфейсе роутера (VPN → VPN-клиент / VPN Fusion).",
    NOHS: "⚠ Туннель поднят, но <b>рукопожатие не проходит</b> — сервер (endpoint) не отвечает. Обычные причины: неверный/недоступный endpoint, сервер выключен, либо параметры обфускации не совпадают с сервером. Трафик в туннель фактически ещё не идёт{0}. Проверьте endpoint и при необходимости переимпортируйте конфиг от провайдера.",
    NOHS_KS: " — а с <b>включённым килл-свичом</b> весь VPN-трафик блокируется, поэтому на этих устройствах интернета не будет, пока рукопожатие не пройдёт",
    DNSGEO_USER: "⚠ Выбраны доменные гео-списки ({0} доменов в dnsmasq), но <b>перехват DNS выключен</b> (режим совместимости). Домены наполняют маршрутизацию только у устройств, использующих DNS роутера, — устройства с DoH/приватным DNS пройдут мимо VPN, т.е. фактически работают в основном IP-списки (GeoIP/Antifilter). Если zapret/Xray/b4 не используются — выключите режим совместимости, и перехват включится.",
    DNSGEO_AUTO: "⚠ Выбраны доменные гео-списки ({1} доменов), но перехват DNS <b>отключён автоматически из-за {0}</b>. Домены будут наполняться только у устройств, использующих DNS роутера; IP-списки работают как обычно.",
    MEM_SQUEEZE_NOSWAP: "⚠ <b>Роутеру не хватает памяти для этого туннеля.</b> Прошивка использует строгий учёт памяти (<code>vm.overcommit_memory=2</code>), и свободного бюджета осталось так мало, что VPN-демон работает на минимальных настройках: потолок памяти {0} МиБ, пул пакетных буферов {1} × 64 КБ. Под нагрузкой — прежде всего при просмотре видео через туннель — демону может не хватить памяти: он падает, и его поднимает watchdog, а со стороны это выглядит как «VPN отваливается каждые несколько минут». <b>Что помогает:</b> <b>файл подкачки на USB-накопителе</b> (amtm → swap, 1 ГБ) — при строгом учёте swap один к одному увеличивает бюджет памяти, и при следующем запуске туннель получит потолок выше. Нужен исправный накопитель: если он откажет или его извлекут, программы, чья память ушла в подкачку, упадут. Отключение неиспользуемых аддонов и служб Entware тоже освобождает бюджет, но обычно намного меньше.",
    MEM_SQUEEZE_SWAP: "⚠ <b>Роутеру не хватает памяти для этого туннеля.</b> Даже с подкачкой ({2} МиБ) строгий учёт памяти (<code>vm.overcommit_memory=2</code>) оставляет так мало бюджета, что VPN-демон работает на минимальных настройках: потолок памяти {0} МиБ, пул пакетных буферов {1} × 64 КБ. Под нагрузкой демону может не хватить памяти, и его перезапускает watchdog — выглядит это как «VPN отваливается каждые несколько минут». <b>Что помогает:</b> увеличьте файл подкачки (например, до 1 ГБ) или отключите другие потребители памяти — неиспользуемые аддоны и службы Entware, а также функции прошивки вроде AiProtection, анализатора трафика или адаптивного QoS (их фоновые службы расходуют этот же бюджет). Туннель получит потолок выше при следующем запуске.",
    CONF_PENDING: "⚠ Сохранённая конфигурация подключения отличается от той, на которой туннель <b>работает сейчас</b>. «Применить» обновляет маршрутизацию/гео на лету, но туннель не перезапускает — нажмите <b>«Перезапустить»</b>, чтобы перейти на новую конфигурацию (ключи, endpoint, обфускация, DNS, MTU).",
    GEO_MATCHALL: "⛔ Правило в вашем <b>пользовательском конфиге dnsmasq</b> отправляет в гео-набор <b>все</b> домены, поэтому в режиме Гео через VPN уходит <b>весь</b> трафик (на всех сайтах виден IP VPN, гео-сервисы перестают работать). Проблемная строка:<div style=\"margin:6px 0;\"><code>{0}</code></div>Из-за <code>https://</code> (или лишнего <code>//</code>) появляется пустой сегмент, а его dnsmasq трактует как «совпадает со всем». Исправьте в своём конфиге dnsmasq (<code>/jffs/configs/dnsmasq.conf.add</code>): оставьте только домен — например <code>ipset=/example.com/awg_dst</code> — и перезапустите dnsmasq или перезагрузите роутер. Правила, которые генерирует сам AmneziaWG, тут ни при чём — строка добавлена вручную.",
    COEX_FOOTER: "<span style=\"opacity:0.85;\">После изменений нажмите <b>«Применить»</b>. Geo-маршрутизация по IP при этом продолжает работать.</span>",
    XRAY_CAP_HEADER: "ℹ <b>XRAYUI / Xray</b> работает в режиме <b>прозрачного проксирования (TPROXY, «перенаправить весь трафик»)</b> и забирает LAN-трафик роутера. Теперь AmneziaWG автоматически даёт устройствам, назначенным на него (<b>«VPN: весь трафик»</b> / <b>«VPN: только Geo»</b>), <b>приоритет в туннель, впереди Xray</b> — такие устройства идут через AmneziaWG, а остальная сеть продолжает работать через Xray. Оба работают вместе, никаких действий не требуется.",
    XRAY_CAP_FIX: "<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li>Хотите пустить <b>весь</b> трафик через AmneziaWG, а не через Xray? Поставьте политику по умолчанию <b>«VPN — весь трафик»</b> — либо остановите Xray кнопкой ниже.</li><li>Если сам туннель AmneziaWG <b>не пропускает трафик</b> (висит «Подключение…» / откатывается), Xray может забирать и <i>собственное</i> рукопожатие роутера — это цепочка приоритета исправить не может. В <b>XRAYUI</b> исключите из перехвата <b>endpoint</b> AmneziaWG и интерфейс <b>awg0</b> либо остановите Xray.</li></ul>",
    XRAY_CAP_TECH: "<span style=\"opacity:0.85;\">Правило Xray <code>from all fwmark 0x10000/0x10000</code> (приоритет 19) стоит впереди fwmark-правила AmneziaWG (приоритет 98); AmneziaWG восстанавливает приоритет через mangle-цепочку <code>AWG_PRIO</code>, встроенную в начало PREROUTING (впереди XRAYUI): она помечает и пропускает пакеты назначенных устройств в туннель раньше, чем их увидит Xray.</span>",
    XRAY_STOP_BTN: "Остановить Xray",
    XRAY_STOPPING: "Останавливаю Xray…",
    XRAY_STOP_CONFIRM: "Остановить Xray / XRAYUI сейчас? Это штатная остановка командой самого XRAYUI — то же, что кнопка «Стоп» на его странице. Из файрвола снимаются только действующие правила прозрачного проксирования (TPROXY), чтобы AmneziaWG мог маршрутизировать трафик; сохранённые настройки и правила XRAYUI не затрагиваются. Включите его снова на странице VPN → X-RAY — он поднимется со всеми прежними настройками.",
    // ---- Broadcom CTF (аппаратное ускорение NAT) блокирует туннель ----
    CTF_BLOCK_HEADER: "⛔ На роутере включено <b>аппаратное ускорение NAT (Broadcom CTF)</b>. AmneziaWG использует policy-routing, который на этой платформе <b>несовместим</b> с CTF — запуск туннеля повреждает состояние ускорителя в ядре и <b>подвешивает роутер до перезагрузки по watchdog</b>. Туннель не запустится, пока CTF не отключён.",
    CTF_BLOCK_FIX: "<ul style=\"margin:5px 0 4px 0; padding-left:20px;\"><li>Нажмите кнопку ниже, чтобы отключить CTF (<code>ctf_disable=1</code>) и перезагрузиться — это то же решение, что Merlin применяет для своих policy-routed VPN-клиентов. После перезагрузки AmneziaWG запустится нормально.</li><li>Компромисс: с выключенным CTF скорость NAT немного снижается (пересылку делает CPU). Позже можно вернуть ускорение в прошивке, если перестанете пользоваться AmneziaWG.</li></ul>",
    CTF_DISABLE_BTN: "Отключить ускорение и перезагрузить",
    CTF_DISABLING: "Отключаю и перезагружаю…",
    CTF_DISABLE_CONFIRM: "Отключить аппаратное ускорение NAT (CTF) и ПЕРЕЗАГРУЗИТЬ роутер сейчас? Это необходимо для работы AmneziaWG на этой модели. Роутер будет недоступен минуту-две, пока перезагружается.",
    // ---- ядро слишком старое для sendmmsg() → демон не может слать пакеты ----
    KERNEL_UNSUP_HEADER: "⚠️ Роутер на старом ядре (Linux&nbsp;2.6.x — RT-AC68U и подобные), где AmneziaWG <b>экспериментален</b>. Тесты на живом железе показали, что <b>ядро туннеля работает</b> (handshake проходит, трафик идёт в обе стороны) — но полный запуск иногда дестабилизирует роутер (может отвалиться WAN, роутер может перезагрузиться) на этом старом ядре. <b>Туннель можно запустить, но на свой страх и риск.</b>",
    KERNEL_UNSUP_BODY: "Если после запуска роутер станет недоступен — он сам перезагрузится и поднимется с остановленным туннелем. Держите <b>«Автозапуск после перезагрузки» ВЫКЛЮЧЕННЫМ</b>, чтобы неудачный старт не зациклился. Роутеров на ядре Linux&nbsp;3.x/4.x/5.x это не касается — это уведомление только на 2.6.x.",
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
    MSG_WD_COPIED: "Скопировано: {0}. Нажмите «Применить», чтобы сохранить.",
    MSG_WD_COPIED_DROPPED: "Скопировано: {0} — часть адресов пропущена (проверка туннеля работает только по IPv4, максимум 4). Нажмите «Применить», чтобы сохранить.",
    MSG_WD_DNS_ALL_V6: "В поле DNS нет IPv4-адреса — проверка туннеля работает только по IPv4; укажите, например, 8.8.8.8.",
    TH_INTERFACE: "Интерфейс",
    FIRSTRUN_HTML: "<b>Похоже, конфигурация ещё не задана.</b><br>\n                    Начните с импорта <code>.conf</code>-файла из приложения Amnezia VPN, затем проверьте поля и нажмите «Применить».",
    BTN_IMPORT_CONFIG: "Импорт конфигурации",
    SEC_CONNECTED_PEERS: "Подключённые пиры",
    TH_SERVER_ADDR: "Адрес сервера",
    TH_ALLOWED_IPS: "Разрешённые IP",
    TH_TRAFFIC: "Трафик (приём/передача)",
    TH_LAST_HANDSHAKE: "Последнее рукопожатие",
    LBL_NO_PEERS: "Нет пиров",
    // ---- аптайм и история подключений ----
    TITLE_UPTIME: "Время работы текущего подключения",
    DUR_S: "{0} с",
    DUR_M: "{0} мин",
    DUR_HM: "{0} ч {1} мин",
    DUR_DH: "{0} д {1} ч",
    SEC_CONN_HISTORY: "История подключений",
    TH_HIST_START: "Начало",
    TH_HIST_DURATION: "Длительность",
    TH_HIST_END: "Причина завершения",
    HIST_R_USER: "остановлено пользователем",
    HIST_R_RESTART: "перезапуск",
    HIST_R_ROLLBACK: "автооткат (туннель без трафика)",
    HIST_R_WATCHDOG: "перезапуск вотчдогом",
    HIST_R_UPDATE: "обновление аддона",
    HIST_R_DEADMAN: "аварийный откат (защита LAN)",
    HIST_R_REBOOT: "перезагрузка роутера",
    HIST_R_INTERRUPTED: "прервано (сбой)",
    HIST_R_AUTO: "автоостановка",
    HIST_R_SWITCH: "переключение профиля",
    HIST_R_FAILOVER: "автопереключение на резервный профиль",
    TH_PROFILE: "Профиль",
    PF_UNNAMED: "Профиль {0}",
    LBL_PF_ACTIVE: "Активен",
    LBL_PF_AUTO: "авто (failover)",
    LBL_PF_EMPTY: "пусто — импортируйте .conf или заполните форму ниже",
    LBL_PF_FO: "failover",
    BTN_PF_SWITCH: "Переключиться",
    BTN_PF_ADD: "+ Добавить профиль",
    TITLE_PF_EDIT: "Клик по строке — редактировать этот профиль в форме ниже",
    TITLE_PF_FO: "Участвует в автопереключении",
    TITLE_PF_DELETE: "Удалить профиль",
    LBL_PF_FAILOVER: "Автопереключение профилей при отказе",
    HINT_PF_BAR: "Форма ниже редактирует подсвеченный профиль; «Применить» сохраняет его. «Переключиться» сохраняет всё И перезапускает туннель на выбранном профиле.",
    HINT_PF_FAILOVER: "Автопереключение: если запущенный туннель не проходит ~60-сек проверку связности, по кругу пробуется следующий профиль (см. журнал). Перезагрузка или ручное переключение возвращают выбранный вами профиль.",
    MSG_PF_SWITCH_CONFIRM: "Применить настройки и переключиться на профиль «{0}»? Туннель будет перезапущен.",
    MSG_PF_DELETE_CONFIRM: "Удалить профиль «{0}»? Он удаляется сразу (туннель не перезапускается); несохранённые названия профилей и флажки автопереключения в этом списке сохранятся вместе с удалением.",
    MSG_PF_DEL_ACTIVE: "Нельзя удалить активный профиль — сначала переключитесь на другой.",
    MSG_PF_DEL_PRIMARY: "Это ваш основной профиль, а сейчас работает резервный (автопереключение). Сначала переключитесь на другой профиль.",
    MSG_PF_DISCARD_NEW: "Убрать несохранённый профиль «{0}»?",
    MSG_PF_WAIT_TRANSITION: "Дождитесь окончания подключения или остановки туннеля и повторите.",
    MSG_PF_SWITCH_BUSY: "Роутер занят (идёт подключение или остановка туннеля либо загрузка списков) — повторите через несколько секунд.",
    MSG_PF_SWITCH_EMPTY: "Нельзя переключиться на профиль «{0}»: его форма ниже пуста. Заполните её (или импортируйте .conf) либо выберите другой профиль; чтобы удалить этот профиль, нажмите ✕ в его строке. Ничего не сохранено.",
    MSG_PF_DEL_PENDING_OVER: "Профиль удалён на странице, но настройки всё ещё не помещаются в лимит прошивки: {0} из {1} байт. Удалите ещё профиль или сократите списки и нажмите «Применить».",
    MSG_PF_DEL_PENDING_KEY: "Профиль удалён на странице, но ещё не сохранён: одно из полей не помещается в хранилище прошивки. Исправьте его и нажмите «Применить» (до этого перезагрузка страницы вернёт профиль).",
    LBL_PF_DELETING: "Удаление…",
    LBL_PF_DELETED: "Профиль удалён ✓",
    HINT_PF_UNSAVED: "Изменения профилей не сохранены — нажмите «Применить»",
    MSG_SWITCH_SKIPPED: "Роутер был занят и пропустил переключение профиля: профиль сохранён, но туннель на нём не перезапущен.",
    BTN_SWITCH_RETRY: "Повторить переключение",
    MSG_SWITCH_FAILED: "Переключение профиля не завершилось — причина в журнале ниже.",
    MSG_PF_UNSAVED: "У профиля «{0}» есть несохранённые правки в форме — отбросить их?",
    MSG_PF_FULL: "Все {0} слотов профилей заняты.",
    // ---- конвейер сохранения настроек (проверка живого хранилища + подтверждение, 1.5.26) ----
    BTN_CHECKING: "Проверка…",
    MSG_WAIT_SAVE: "Подождите — идёт сохранение настроек",
    ACK_SAVED_BUSY: "Сохранено; роутер был занят — действие могло не выполниться, проверьте журнал",
    MSG_CS_CONFLICT: "Настройки изменились после загрузки этой страницы (другая вкладка, страница сервера AWG или SSH). Чтобы не перезаписать эти изменения, сохранение отменено. Обновить страницу сейчас? Несохранённые правки на этой странице будут потеряны.",
    MSG_ROUTER_BUSY: "Роутер не отвечает (идёт перезапуск туннеля или загрузка списков) — повторите через несколько секунд",
    MSG_SESSION_EXPIRED: "Сеанс входа в роутер истёк — войдите в другой вкладке и повторите; правки на этой странице сохранены",
    MSG_SAVE_DISCARDED: "Роутер не записал настройки (прошивка отклонила сохранение). Обновите страницу, чтобы увидеть текущее состояние.",
    TAIL_SWITCH: "Переключение не выполнено.",
    TAIL_FORCEAPPLY: "Туннель перезапущен с прежними настройками.",
    TAIL_GEO: "Загружаются ранее сохранённые списки.",
    TAIL_DELETE: "Профиль не удалён.",
    TAIL_ANALYZE: "Захват остановлен.",
    MSG_CS_UNKNOWN: "Одновременно с этим сохранением настройки записала другая страница — результат неизвестен. Обновите страницу.",
    MSG_STORE_TRUNCATED: "Роутер записал настройки не полностью (вероятно, заполнен /jffs). Не перезагружайте страницу: освободите место и нажмите «Применить» ещё раз",
    MSG_UPDATE_PIN_LOST: "Роутер не записал выбранную версию (прошивка отклонила сохранение) — будет установлена последняя версия.",
    OVF_BREAKDOWN: "Что занимает место (байты сохраняемых настроек):",
    OVF_PROFILE: "Профиль #{0} «{1}»: {2} байт (из них I1–I5: {3})",
    OVF_GEO: "Гео-политика «{0}»: {1} байт",
    OVF_CLIENTS: "Список устройств: {0} байт",
    OVF_AWG_OTHER: "Прочие настройки AmneziaWG: {0} байт",
    OVF_SERVER: "Сервер AWG (awgs_*): {0} байт",
    OVF_OTHER_ADDONS: "Другие аддоны: {0} байт — можно освободить только в их настройках",
    OVF_LIVE_OVER: "Хранилище роутера УЖЕ само превышает лимит ({0} из {1} байт): ни одна страница аддонов не сможет сохранить настройки, пока оно не уменьшится.",
    MSG_SETTINGS_TOO_BIG: "Настройки не помещаются в хранилище прошивки: {0} из {1} байт. Больший набор Asuswrt-Merlin не сохраняет вообще (сохранение отбрасывается целиком), а этот лимит общий для всех аддонов. Сократите I1-I5, удалите неиспользуемый профиль или уменьшите списки GeoCustom.",
    MSG_SETTING_TOO_LONG: "«{0}» не помещается в хранилище прошивки: {1} из {2} символов (длиннее прошивка молча обрезает). Сократите.",
    SEC_CONFIG: "Конфигурация",
    BTN_IMPORT_CONF_FILE: "Импорт .conf",
    TITLE_IMPORT_CONF_FILE: "Импорт .conf-файла из клиента Amnezia VPN",
    OBF_SUMMARY_HTML: "AmneziaWG Obfuscation <span style=\"font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;\">— параметры обфускации (обычно заполняются импортом конфига) ▾</span>",
    TBL_AWG3: "AmneziaWG 3.0 — нужна поддержка 3.0 и на ДРУГОЙ стороне. Оставьте пустым, если их нет в конфиге провайдера.",
    AWG3_UNSUPPORTED: "Параметры AmneziaWG 3.0 не поддерживаются установленными бинарниками — поля ниже отключены. Обновите аддон до сборки с поддержкой AWG 3.0.",
    HINT_AWG3_HPK: "Общий ключ — должен быть ОДИНАКОВЫМ на сервере и на всех клиентах. Требует S1–S4 ≥ 12 (все четыре, включая S3).",
    HINT_AWG3_CPA: "Одно число или диапазон «lo-hi»: добавочные байты к пакету данных. Пакет с добавкой не больше самого крупного, отправленного с последнего ответа пира (минимум 500 Б), поэтому самые крупные пакеты уходят без добавки.",
    HINT_AWG3_RAT: "Через сколько сессия перезаключается. По умолчанию 120. Должно быть меньше RejectAfterTime.",
    HINT_AWG3_RTO: "Интервал повтора неотвеченного хендшейка. По умолчанию 5. Слишком малые значения дают шторм хендшейков.",
    HINT_AWG3_RJT: "После этого времени сессия отбрасывается. По умолчанию 180. Меньше RekeyAfterTime — туннель умрёт, не успев перезаключиться.",
    HINT_AWG3_KAT: "Задержка пассивного keepalive. По умолчанию 10 — это НЕ Persistent Keepalive (25).",
    HINT_AWG3_MHA: "Сколько раз повторять хендшейк перед сдачей. По умолчанию 18.",
    AWG31_UNSUPPORTED: "Параметры AmneziaWG 3.1 (RandomTrailers / DisableCookies) не поддерживаются установленными бинарниками — эти два поля отключены.",
    OPT_AWG31_UNSET: "— (по умолчанию off)",
    HINT_AWG31_RT: "Случайный «хвост» у пакетов рукопожатия (маскировка размера). Симметричный: пир без него отбрасывает НАШИ рукопожатия с хвостом — ставьте только то, что указано в конфиге провайдера. Нужен AmneziaWG 3.1+ с обеих сторон.",
    HINT_AWG31_DC: "Не отправлять cookie-ответы WireGuard (служебное сообщение защиты от перегрузки, заметное для DPI). Действует только на этой стороне — совместимо с любым пиром. Цена: эта сторона теряет защиту от флуда рукопожатиями.",
    UNIT_BYTES: "байт",
    UNIT_SEC: "сек",
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
    HINT_WATCHDOG_HTML: "<summary>Адреса, которые watchdog пингует <b>через туннель</b> раз в 5 минут (ответил хоть один — туннель живой). <u>Формат и примеры</u></summary><b>Формат:</b> IPv4 или домен, можно несколько — через пробел или запятую (до 4 адресов; IPv6 не поддерживается — проверка идёт по IPv4 туннеля).<br><b>Пример:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Лучше указывать IP (без зависимости от DNS). Пусто = по умолчанию <b>8.8.8.8</b> и <b>1.1.1.1</b>. Поменяйте, если эти адреса у вас блокируются/недоступны — иначе watchdog зря перезапускает VPN. Какие адреса проверяются — видно в журнале ниже.",
    TH_ZAPRET_COMPAT: "Режим совместимости",
    LBL_NO_DNS_INTERCEPT: "Режим совместимости — сосуществование с zapret2 / Xray / b4 (не перехватывать DNS)",
    LBL_TUNNEL_DNS_TH: "DNS через туннель",
    LBL_TUNNEL_DNS: "Пускать DNS-запросы всей сети через туннель на указанные выше серверы, пока VPN запущен (нужен включённый перехват DNS — в режиме совместимости не действует; защищает от DNS-подмены провайдером)",
    HINT_DNS: "используется опцией «DNS через туннель» ниже; пусто = DNS прошивки",
    HINT_NO_DNS_HTML: "<summary>Режим совместимости: отключает перехват DNS (порт :53) у AmneziaWG, чтобы он не конфликтовал с соседней DPI/прокси-утилитой. Для новых установок включён по умолчанию. <u>Подробнее</u></summary>Держите включённым, если рядом работает <b>zapret2</b>, <b>Xray/XRAYUI</b> (v2ray, sing-box) или <b>b4</b> — иначе конфликт DNS может оставить сеть без интернета. Geo по IP (GeoIP/antifilter) продолжает работать; geo по доменам работает для клиентов, использующих роутер как DNS — только клиенты с жёстко прописанным внешним резолвером теряют geo по доменам. Обнаруженный рядом zapret2 / Xray / v2ray / sing-box / b4 или след NFQUEUE/TPROXY (iptables или nft) тоже отключает перехват автоматически даже без этой галочки. Важно: галочка решает только конфликт по DNS — при политике «VPN — весь трафик» маршрутизация всё равно заберёт трафик прокси, поэтому для совместимости выбирайте «Напрямую» или «VPN — только Geo».",
    TH_AUTOSTART: "Автозапуск",
    LBL_AUTOSTART: "Автоматически запускать туннель после перезагрузки роутера",
    HINT_AUTOSTART: "Включено (по умолчанию): туннель поднимается сам при загрузке роутера. Выключите, чтобы после перезагрузки туннель оставался остановленным (например, на время отладки другой программы) — настроенное подключение полностью сохраняется, просто запускайте его вручную кнопкой «Запустить», когда нужно. На ручной запуск/перезапуск и на watchdog уже работающего туннеля галочка не влияет.",
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
    HINT_GEO_CUSTOM_FORMAT: "Один элемент в строке. Домен (<code>example.com</code>) маршрутизируется через DNS; IPv4-адрес или подсеть CIDR (<code>1.2.3.0/24</code>) добавляется в ipset (IPv6 пропускается). Текст после <code>#</code> — комментарий. Файл по ссылке должен возвращать простой текстовый список в этом формате. Свои файлы хранятся в настройках прошивки, а туда помещается лишь <b>около 2 КБ текста на вкладку (~150 строк)</b> — большой список выложите по ссылке (например, raw-ссылка GitHub) и добавьте как URL-источник: у них ограничения размера нет.",
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
    MSG_GEO_FILES_TOO_BIG: "«Свои файлы»{0} на вкладке «{1}» занимают {2} символов в закодированном виде, а хранилище настроек прошивки держит не больше {3} на вкладку (около 2 КБ текста, ~150 строк CIDR) и молча обрезает остальное. Уменьшите файлы или выложите большой список по ссылке (например, raw-ссылка GitHub) и добавьте её в «URL-источники» — у них ограничения размера нет.",
    GEO_FILES_EXC_SUFFIX: " (исключения)",
    GEO_FILE_CUT: "⚠ Прошивка обрезала этот файл при сохранении (её хранилище настроек держит ~2 КБ текста на вкладку): показана уцелевшая часть, неполная последняя строка отброшена, файлы после него потеряны. Уменьшите файл или перенесите список в URL-источник.",
    GEO_FILE_UNREADABLE: "⚠ Сохранённое содержимое файла повреждено (обрезано хранилищем прошивки) и не может быть показано. Вставьте его заново (поменьше) или удалите строку.",
    MSG_GEO_URL_BAD: "«URL-источники» на вкладке «{0}»: «{1}» — не ссылка http:// или https://.",
    MSG_GEO_URL_IDN: "«URL-источники» на вкладке «{0}»: в «{1}» домен не латиницей — загрузчику роутера нужна его punycode-форма (xn--…). Откройте ссылку в браузере и скопируйте её из адресной строки или переведите домен любым IDN-конвертером.",
    GEO_URLS_CUT: "⚠ Прошивка обрезала этот список ссылок при сохранении (её хранилище держит ~3000 символов на значение): последняя неполная ссылка отброшена, ссылки после неё потеряны. Добавьте их заново.",
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
    BTN_SAVE_RESTART: "Сохранить и перезапустить",
    TITLE_SAVE_RESTART: "Сохранить + перезапуск VPN (stop → start) + полная пересборка маршрутов и firewall",
    APPLY_DESC1_HTML: "<b>Применить</b> — сохранить настройки и применить их «на лету»: устройства, политики маршрутизации, firewall и списки GeoIP/GeoSite обновляются <b>без разрыва VPN-соединения</b>. Изменения самой конфигурации подключения (ключи, endpoint, обфускация, DNS, MTU) вступают в силу только после <b>«Перезапустить»</b> — страница подскажет жёлтой плашкой. Если VPN остановлен — настройки просто сохранятся и применятся при следующем запуске.",
    APPLY_DESC2_HTML: "<b>Сохранить и полностью перезапустить VPN</b> (stop → start) — заново применяется конфиг (awg setconf), пересобираются интерфейс, маршруты и firewall, соединение на пару секунд прерывается. Нужно при смене ключей, сервера (Endpoint), MTU или параметров обфускации (Jc, S1, H1…H4), а также если соединение «залипло».",
    SEC_LOG: "Журнал",
    BTN_GET_DIAG: "Диагностика",
    TITLE_GET_DIAG: "Собрать полный отчёт диагностики и скопировать его вместе с журналом",
    LOG_WAITING: "Ожидание данных…",
    MODAL_UPDATE_TITLE: "Обновление",
    INSTALL_LABEL: "Установить:",
    ARIA_INSTALL_MODE: "Способ установки",
    OPT_INSTALL_AUTO: "Автоматически (последняя)",
    OPT_INSTALL_VERSION: "Выбрать версию",
    OPT_INSTALL_FILE: "Из своего файла (по SSH)",
    PH_VERSION: "напр. 1.1.49",
    ARIA_VERSION_TO_INSTALL: "Версия для установки",
    BTN_CHECK_UPDATES: "Проверить обновления",
    BTN_CLOSE: "Закрыть",
    MODAL_DIAG_TITLE: "Диагностические данные",
    BTN_COPY_DIAG: "Скопировать диагностические данные",
    DIAG_COPY_NOTE: "Копируется вместе с журналом, обёрнуто для вставки в Telegram."
}
};
// T(key, ...args): current-lang -> en -> key. {0},{1}.. are positional args.
function T(key){
    var d = AWG_I18N[AWG_LANG] || AWG_I18N.en;
    var s = (d[key] != null) ? d[key] : (AWG_I18N.en[key] != null ? AWG_I18N.en[key] : key);
    var a = arguments;
    return s.replace(/\{(\d+)\}/g, function(m, n){ n = +n + 1; return n < a.length ? String(a[n]) : m; });
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

// ---- Current-connection uptime (ticks live client-side, like the handshake counter) ----
// Primary source is the start epoch (status.conn_start) — same Date.now() arithmetic as
// awgAgo; when that epoch is implausible (session started before NTP sync) or the browser
// clock sits behind it, fall back to the static conn_uptime snapshot from the status file
// (monotonic on the router, but refreshed only per status write — may lag, never lies).
var awgConnStart = 0, awgConnUptime = 0, awgConnUp = false;
function awgFmtDur(sec){
    sec = Math.floor(sec);
    if(!isFinite(sec) || sec < 0) return null;
    if(sec < 60) return T('DUR_S', sec);
    var m = Math.floor(sec / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
    if(h < 1) return T('DUR_M', m);
    if(d < 1) return T('DUR_HM', h, m % 60);
    return T('DUR_DH', d, h % 24);
}
function awgUptimeText(){
    if(!awgConnUp) return null;
    var up = -1;
    if(awgConnStart > 1000000000) up = Math.floor(Date.now() / 1000) - awgConnStart;
    if(up < 0) up = (awgConnUptime > 0) ? awgConnUptime : -1;
    return awgFmtDur(up);
}
// Repaint the small uptime label next to the status badge; also called every second by the
// shared ticker so it counts live between the 5s status polls.
function awgTickUptime(){
    var el = document.getElementById('awg_uptime');
    if(!el) return;
    var t = awgUptimeText();
    if(t === null){ el.style.display = 'none'; el.textContent = ''; return; }
    el.textContent = '· ' + t;
    el.style.display = '';
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
        // Replace the static fallback with the full list ONLY when the DB file is present and
        // non-empty; on 404 (fresh /opt / region-blocked v2fly DB) keep the seeded fallback so
        // autocomplete still offers the common categories instead of going silent.
        if(xhr.status === 200 && xhr.responseText.trim().length > 0){
            // Strip quotes per line: a categories file generated by an older addon from the
            // post-2026-07 v2fly DB (quoted `- name: "xai"` scalars) carries the quotes, and
            // they'd flow via autocomplete straight into saved settings. Heals the stale file
            // without waiting for the next geo DB download.
            var full = xhr.responseText.trim().split('\n').map(function(s){ return s.replace(/["']/g, '').trim(); }).filter(function(s){ return s; });
            if(full.length) v2flyList = full;
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
    // Tick the handshake age + connection uptime live (client-side) between the 5s status polls.
    if(!awgTickTimer) awgTickTimer = setInterval(function(){ awgTickHandshakes(); awgTickUptime(); }, 1000);
    awgRefreshLog();
    setInterval(awgRefreshLog, 2500);
    loadV2flyCategories();
    initAutocomplete();
    initAutocompleteIp();
    checkForUpdate();
    loadGithubBadge();
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

// Swap the header's text GitHub link for the shields.io release badge — but only once the
// badge actually loads. As a static <img> the badge participated in the document load event,
// so an ISP that silently drops img.shields.io (no RST) stalled body onload=initial() for the
// browser's full ~30s connect timeout and the page sat on «Loading…». Fetched from here (during
// the load event) it can't delay anything: the text link is usable immediately, the badge pops
// in only on success, and on error/timeout the text simply stays.
function loadGithubBadge(){
    var a = document.getElementById('awg_gh_link');
    if(!a) return;
    var img = new Image();
    img.alt = 'GitHub';
    img.style.height = '18px';
    img.style.display = 'block';
    img.onload = function(){ a.innerHTML = ''; a.appendChild(img); };
    img.src = 'https://img.shields.io/github/v/release/william-aqn/asuswrt-merlin-amneziawg?logo=github&label=release';
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

function doUpdate(version, latest){
    // Synchronous pre-flight, before any UI change (the caller keeps the modal open on false).
    if(awgFormBusy()){ awgFormBusyRefuse(); return false; }
    // What this POST carries — ONLY these keys, on top of the LIVE store (awgSave 'onlyExtra'):
    // the current "download via VPN" choice (even without a prior Apply) and the version pin.
    // Pin an explicit version (one-shot) so the router installs exactly it — no backend jsDelivr
    // resolution, no crawl lag; the backend clears it after use. No version = an explicit null,
    // i.e. DELETE the key: a pin left behind by an earlier update whose event the router dropped
    // must never be re-posted from the live store (the router would install that stale version).
    var pinned = !!(version && !latest);
    var extra = { awg_update_version: version ? String(version) : null };
    var gv = document.getElementById('awg_geo_via_awg'), uv = document.getElementById('awg_update_via_awg');
    if(gv) extra.awg_geo_via_awg = gv.checked ? '1' : '0';
    if(uv) extra.awg_update_via_awg = uv.checked ? '1' : '0';
    // Local estimate of the firmware's WHOLE-store cap (the model approximates the live store):
    // over it the firmware would drop the POST whole — a user-chosen version is refused here;
    // "latest" is posted with NO settings, which the backend resolves by itself (see done()).
    var est = awgSettingsSnapshot();
    for(var ek in extra){ if(extra.hasOwnProperty(ek)){ if(extra[ek] === null) delete est[ek]; else est[ek] = extra[ek]; } }
    var ovfU = awgSettingsOverflow(est, true);
    if(ovfU && pinned){ ovfU.obj = est; alert(awgOverflowMsg(ovfU)); return false; }
    var started = awgSave({
        mode: 'onlyExtra', check: 'total', extra: extra, action: 'start_awgdoupdate',
        busyUI: awgUpdateCheckUI,
        onSubmit: awgUpdateUI,
        done: function(res, info){
            if(res === 'verified-late'){ awgShowAck(T('ACK_SAVED_BUSY'), true); return; }
            if(res === 'verified' || res === 'unverified') return;
            if(res === 'overflow'){
                // The final object (live store + these keys) is over the cap: a pinned version can't
                // be carried — refuse (the pre-submit UI is already restored); "latest" needs no
                // settings — fall back to the empty post exactly as before 1.5.26.
                if(pinned){ alert(awgOverflowMsg(info.ovf)); return; }
                if(awgPostSettings('start_awgdoupdate', false, null, function(){}) !== false) awgUpdateUI();
                return;
            }
            // The event fired in all three cases below — the update runs: keep its UI + reload poll.
            if(res === 'discarded'){ if(pinned) alert(T('MSG_UPDATE_PIN_LOST')); return; }
            if(res === 'unknown' || res === 'truncated'){ awgSaveNotify(res, info); return; }
            awgSaveNotify(res, info);   // busy / login: nothing was posted, the page is back as it was
        }
    });
    if(!started){ awgFormBusyRefuse(); return false; }
    return true;
}
// doUpdate's busy label while awgSave reads the live store (the modal has already closed): the
// badge says «Checking…» and the steady poll is paused so it can't repaint it; 'idle' = the save
// ended before anything was posted — resume the poll ('submit' hands over to awgUpdateUI).
function awgUpdateCheckUI(phase){
    var badge = document.getElementById('awg_badge');
    if(phase === 'check'){
        if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
        if(badge){ badge.className = 'awg-status connecting'; badge.innerHTML = '&#9679; ' + escHtml(T('BTN_CHECKING')); }
    } else if(phase === 'idle'){
        if(!statusTimer && !awgTransitionActive) statusTimer = setInterval(awgRefreshStatus, 5000);
        awgRefreshStatus();
    }
}
// The update is on its way: «Updating» badge, poll handed over to the reload watcher below.
function awgUpdateUI(){
    var badge = document.getElementById('awg_badge');
    if(badge){ badge.className = 'awg-status connecting'; badge.innerHTML = '&#9679; ' + escHtml(T('STAT_UPDATING')); }
    awgConnUp = false;
    awgTickUptime();
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
    // Supersede any status read still in flight so it can't repaint over the «Updating» badge
    // (same generation guard as awgAction; see awgActionGen). That also abandons a running
    // transition poll — stop it here and drop the transition flag with it.
    awgActionGen++;
    if(awgPoll){ clearInterval(awgPoll); awgPoll = null; }
    awgTransitionActive = false;
    // The modal just closed — scroll to the log so the user can watch the update progress.
    var _lb = document.getElementById('awg_log');
    if(_lb){ try { _lb.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch(e){ try { _lb.scrollIntoView(); } catch(e2){} } }

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
    awgModeUI();           // show the input matching the current mode
    refreshModalState();   // status line + install button visibility
    loadChangelog(ref, function(text, ok){
        if(!body) return;
        if(ok && text){ body.innerHTML = mdToHtml(text); body.scrollTop = 0; }
        else { body.innerHTML = '<div style="opacity:0.7;">' + escHtml(T('MODAL_CHANGELOG_FAILED')) + '</div>'; }
    });
}

function closeUpdateModal(){
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

// Show the version field / the local-file instructions for the selected install mode.
// "From a local file" is SSH-only since 1.5.24: the browser upload it used to offer could never
// work (the firmware discards any settings POST over 8 KB — see AWG_CS_TOTAL_MAX), so the mode
// now shows the two commands instead of a file picker, with this router's address filled in.
function awgModeUI(){
    var mode = document.getElementById('awg_install_mode').value;
    var vin = document.getElementById('awg_version_input');
    var help = document.getElementById('awg_file_help');
    var btn = document.getElementById('awg_install_btn');
    if(vin) vin.style.display = (mode === 'version') ? '' : 'none';
    if(btn) btn.style.display = (mode === 'file') ? 'none' : '';
    if(help){
        help.style.display = (mode === 'file') ? 'block' : 'none';
        if(mode === 'file') help.innerHTML = T('INSTALL_FILE_HELP', escHtml(location.hostname || '192.168.50.1'), Math.round(AWG_CS_TOTAL_MAX / 1024));
    }
    // When the user picks the "choose version" mode, focus the version field right away.
    if(mode === 'version' && vin){ try { vin.focus(); vin.select(); } catch(e){} }
}

// Install action, dispatched by the mode selector:
//   auto    -> latest published version (auto-detected)
//   version -> an exact published version X.Y.Z
//   file    -> nothing to do here: installed over SSH (install_ipk), see awgModeUI
function installUpdate(){
    var mode = document.getElementById('awg_install_mode').value;
    if(mode === 'file') return;

    if(mode === 'version'){
        var inp = document.getElementById('awg_version_input');
        var v = ((inp && inp.value) || '').trim().replace(/^v/i, '');
        if(!v){ alert(T('MSG_ENTER_VERSION')); return; }
        if(!/^\d+\.\d+\.\d+$/.test(v)){ alert(T('MSG_VERSION_FORMAT')); return; }
        if(awgCurrentVersion && v === awgCurrentVersion && !confirm(T('MSG_VERSION_INSTALLED_REINSTALL', v))) return;
        if(doUpdate(v) !== false) closeUpdateModal();
        return;
    }

    // auto -> latest. If we're already on the newest, say so instead of a no-op update.
    if(!awgUpdateAvailable){
        alert(T('MSG_LATEST_VERSION', awgCurrentVersion ? T('MSG_LATEST_VERSION_VER', awgCurrentVersion) : ''));
        return;
    }
    if(doUpdate(awgLatestVersion || '', true) !== false) closeUpdateModal();
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

// ---- Firmware custom_settings limits (Asuswrt-Merlin httpd, every branch incl. gnuton) ----------
// write_custom_settings(): snprintf(line, 3040, "%s %s\n") per key — a record over 3039 bytes is CUT
//   and loses its '\n', so the NEXT key is glued onto it (the router's line reader then can't see it).
// ej_get_custom_settings(): sscanf("%29s%*[ ]%2999s") — the page reads back at most 2999 bytes of a
//   value (and cuts it at its first whitespace).
// validate_apply(): amng_custom is declared CKN_STR8192 — a POST whose JSON exceeds 8192 bytes fails
//   nvram_check and is DISCARDED WHOLE (syslog "nvram_check fail: nvram amng_custom over length"),
//   while the service event still fires and the iframe still loads: nothing saved, no error.
//   That 8 KB is shared with every other addon's keys. (The old ~50/64 KB budgets here were wrong.)
var AWG_CS_VALUE_MAX = 2900;   // our per-value ceiling — same margin as the chunked initdata keys
var AWG_CS_TOTAL_MAX = 8192;
function awgUtf8Len(s){
    s = String(s == null ? '' : s);
    try { return unescape(encodeURIComponent(s)).length; } catch(e){ return s.length * 3; }
}
// Why `obj` can't be saved as-is — {key, len} for the first over-long value of OUR keys, or
// {key:'', total} when the whole object is over the firmware's cap — or null when it fits.
// Only OUR awg_* keys are length-checked: other addons' (and the server page's awgs_*) values
// came through the firmware's own reader and are that page's business.
function awgSettingsOverflow(obj, totalOnly){
    for(var k in obj){
        if(totalOnly) break;
        if(!obj.hasOwnProperty(k) || k.indexOf('awg_') !== 0) continue;
        var n = awgUtf8Len(obj[k]);
        var cap = /^awg_(geo_|antifilter)/.test(k) ? AWG_CS_VALUE_MAX : Math.min(2999, 3037 - k.length);
        if(n > cap) return { key: k, len: n, cap: cap };
    }
    var total = awgUtf8Len(JSON.stringify(obj));
    return total > AWG_CS_TOTAL_MAX ? { key: '', total: total } : null;
}
// A human message for awgSettingsOverflow's result, naming the field (and geo tab) when possible.
// A total-size refusal carries the object that was measured (o.obj — awgSave's FINAL object, which
// is what the firmware would receive) and the live store (o.live): the breakdown says where the
// bytes are, so the user knows what to shorten.
function awgOverflowMsg(o){
    if(!o.key) return T('MSG_SETTINGS_TOO_BIG', o.total, AWG_CS_TOTAL_MAX) + (o.obj ? awgOverflowBreakdown(o.obj, o.live) : '');
    var m = /^awg_geo_(?:(\d+)_)?(v2fly|v2fly_ip|custom_domains|custom_ips|custom_files|custom_urls|exc_domains|exc_ips|exc_files|exc_urls)$/.exec(o.key), label = o.key;
    var cap = o.cap || AWG_CS_VALUE_MAX;
    if(m){
        var id = m[1] ? parseInt(m[1], 10) : 1, gi = geoPolicyIndexById(id);
        var tab = gi !== -1 ? geoDecodeName(geoPolicies[gi].name) : String(id);
        if(m[2] === 'custom_files' || m[2] === 'exc_files')
            return T('MSG_GEO_FILES_TOO_BIG', m[2] === 'exc_files' ? T('GEO_FILES_EXC_SUFFIX') : '', tab, o.len, cap);
        var lk = { custom_domains:'TH_CUSTOM_DOMAINS', exc_domains:'TH_CUSTOM_DOMAINS', custom_ips:'TH_CUSTOM_IPS',
                   exc_ips:'TH_CUSTOM_IPS', custom_urls:'TH_GEO_URLS', exc_urls:'TH_GEO_URLS',
                   v2fly:'TH_GEOSITE_LISTS', v2fly_ip:'TH_GEOIP_LISTS' }[m[2]];
        label = (lk ? T(lk) : o.key) + (m[2].indexOf('exc_') === 0 ? T('GEO_FILES_EXC_SUFFIX') : '') + ' — ' + tab;
    } else {
        var am = /^awg_antifilter(?:_(\d+))?_lists$/.exec(o.key);
        if(am){
            var ai = geoPolicyIndexById(am[1] ? parseInt(am[1], 10) : 1);
            label = T('TH_ANTIFILTER_IP') + ' — ' + (ai !== -1 ? geoDecodeName(geoPolicies[ai].name) : (am[1] || '1'));
        } else if(o.key === 'awg_clients') label = T('TBL_ROUTING_POLICY');
        else if(/^awg_(?:pf\d+_)?peer_allowedips$/.test(o.key)) label = T('TH_ALLOWED_IPS');
        else if(o.key === 'awg_watchdog_hosts') label = T('TH_TUNNEL_CHECK_ADDR');
    }
    return T('MSG_SETTING_TOO_LONG', label, o.len, cap);
}
// Where the bytes of a too-big settings object go. Each key is charged its JSON contribution —
// `"k":"v"` plus the comma after it — and the object's braces go to "other AmneziaWG settings", so
// the lines add up to exactly the total the firmware measures. Largest group first.
function awgOverflowBreakdown(obj, live){
    var groups = {}, order = [], sum = 0, k, m;
    function add(id, n, i5){
        if(!groups[id]){ groups[id] = { n: 0, i5: 0 }; order.push(id); }
        groups[id].n += n; groups[id].i5 += (i5 || 0);
    }
    // Slot numbers of the profiles the object configures, for the "#k" ordinals (C5).
    var cfgSlots = [];
    for(var s = 1; s <= AWG_PF_MAX; s++){ if(pfConfiguredIn(obj, s)) cfgSlots.push(s); }
    for(k in obj){
        if(!obj.hasOwnProperty(k)) continue;
        var n = awgUtf8Len(JSON.stringify(k) + ':' + JSON.stringify(obj[k])) + 1;
        sum += n;
        var slot = pfSlotOfKey(k);
        if(slot && cfgSlots.indexOf(slot) !== -1){ add('pf' + slot, n, /initdata\d*$/.test(k) ? n : 0); continue; }
        if((m = /^awg_geo_(?:(\d+)_)?(?:v2fly|v2fly_ip|custom_domains|custom_ips|custom_files|custom_urls|mode|exc_domains|exc_ips|exc_files|exc_urls)$/.exec(k)) ||
           (m = /^awg_antifilter(?:_(\d+))?_lists$/.exec(k))){ add('geo' + (m[1] ? parseInt(m[1], 10) : 1), n); continue; }
        if(k === 'awg_clients'){ add('clients', n); continue; }
        if(k.indexOf('awg_') === 0){ add('awg', n); continue; }
        if(k.indexOf('awgs_') === 0){ add('srv', n); continue; }
        add('other', n);
    }
    var total = awgUtf8Len(JSON.stringify(obj));
    add('awg', total - sum);
    order.sort(function(a, b){ return groups[b].n - groups[a].n; });
    var lines = [];
    for(var i = 0; i < order.length; i++){
        var id = order[i], g = groups[id];
        if(g.n <= 0) continue;
        if(id.indexOf('pf') === 0){
            var sl = parseInt(id.slice(2), 10), ord = cfgSlots.indexOf(sl) + 1;
            var nm = pfNameDec(obj[pfKey(sl, 'name')] || '') || T('PF_UNNAMED', ord);
            lines.push(T('OVF_PROFILE', ord, nm, g.n, g.i5));
        } else if(id.indexOf('geo') === 0){
            var gi = geoPolicyIndexById(parseInt(id.slice(3), 10));
            lines.push(T('OVF_GEO', gi !== -1 ? geoDecodeName(geoPolicies[gi].name) : id.slice(3), g.n));
        } else if(id === 'clients') lines.push(T('OVF_CLIENTS', g.n));
        else if(id === 'awg') lines.push(T('OVF_AWG_OTHER', g.n));
        else if(id === 'srv') lines.push(T('OVF_SERVER', g.n));
        else lines.push(T('OVF_OTHER_ADDONS', g.n));
    }
    var out = '\n\n' + T('OVF_BREAKDOWN') + '\n• ' + lines.join('\n• ');
    var liveTotal = live ? awgUtf8Len(JSON.stringify(live)) : 0;
    if(liveTotal > AWG_CS_TOTAL_MAX) out += '\n\n' + T('OVF_LIVE_OVER', liveTotal, AWG_CS_TOTAL_MAX);
    return out;
}
// Deep-enough copy of custom_settings (flat string map) to roll back a refused save: applyConfig
// and updateGeoLists write their values into the object BEFORE the store-limit check, and a
// refused value left behind would ride along on the next path that posts the object.
function awgSettingsSnapshot(){
    var c = {};
    for(var k in custom_settings){ if(custom_settings.hasOwnProperty(k)) c[k] = custom_settings[k]; }
    return c;
}
function awgSettingsRestore(snap){
    var k;
    for(k in custom_settings){ if(custom_settings.hasOwnProperty(k)) delete custom_settings[k]; }
    for(k in snap){ if(snap.hasOwnProperty(k)) custom_settings[k] = snap[k]; }
}

// Submit the shared form (-> hidden_frame, proven auth path) for an action with NO settings
// intent: amng_custom is posted EMPTY, so the firmware writes nothing (re-posting the page-load
// snapshot would revert changes made elsewhere since, and an over-limit object would be discarded
// anyway). See awgAction. Every settings-carrying POST goes through awgSave instead (1.5.26) —
// `extra` must be false. cb() fires when the POST has been processed. Returns false (and posts
// nothing) while a settings save holds the form (awgFormBusy): callers check that first.
function awgPostSettings(actionScript, extra, waitVal, cb){
    if(awgFormBusy()) return false;
    var fr = document.getElementById('hidden_frame');
    var done = false;
    var to = setTimeout(function(){ if(!done){ done = true; cleanup(); cb(false); } }, 12000);
    function cleanup(){ try{ fr.removeEventListener('load', onl); }catch(e){} clearTimeout(to); }
    function onl(){ if(done) return; done = true; cleanup(); cb(true); }
    fr.addEventListener('load', onl);

    var ac = document.getElementById('amng_custom');
    if(ac) ac.value = '';

    var aw = document.form.action_wait;
    var oldwait = aw ? aw.value : null;
    if(aw && waitVal != null) aw.value = String(waitVal);
    document.form.action_script.value = actionScript;
    awgSubmitForm();
    if(aw && oldwait != null) aw.value = oldwait;   // submit() snapshots fields synchronously
    return true;
}

// ==================== Settings save pipeline (1.5.26) ====================
// The firmware's settings API is a FULL REPLACE of /jffs/addons/custom_settings.txt with whatever
// JSON the page posts, shared by every addon AND by this addon's server page — and it reports
// nothing: an over-limit POST is discarded whole while the event still fires, a POST that lands
// while rc runs one of our long handlers is written but its event dropped (~15 s notify_rc block),
// a full /jffs cuts the file short. So every settings-carrying POST goes through awgSave:
//   pre-fetch the LIVE store  →  refuse if a page-owned key changed elsewhere since load (conflict)
//   →  post live's not-owned keys + this page's own keys, the save token LAST  →  read the store
//   back and classify: verified / verified-late / unverified / discarded / unknown / truncated.
// Ownership, not merging: this page owns every awg_* key except the two below; everything else
// (awgs_* = the server page, other addons) is taken from the live store as-is.
var AWG_CS_NOT_OWNED = {
    awg_save_tok: 1,         // the save token — rewritten by every save of either page
    awg_update_version: 1    // one-shot update pin, cleared by the backend's do_update
};
function awgCsOwned(k){ return k.indexOf('awg_') === 0 && !AWG_CS_NOT_OWNED.hasOwnProperty(k); }
// A value as the firmware's reader will show it back — ej_get_custom_settings() parses each line
// with sscanf("%29s%*[ ]%2999s"): the separating spaces and any further leading C-whitespace are
// skipped, the value ends at its first C-whitespace and at 2999 bytes, an empty value is not
// emitted at all. undefined = absent. Every comparison of page state against the store uses this.
function awgCsNorm(v){
    if(v === undefined || v === null) return undefined;
    var s = String(v).replace(/^[ \t\v\f\r]+/, '');
    if(s === '' || s.charAt(0) === '\n') return undefined;
    s = s.replace(/[ \t\n\v\f\r][\s\S]*$/, '');
    if(awgUtf8Len(s) > 2999) s = awgUtf8Cut(s, 2999);
    return s === '' ? undefined : s;
}
// The reader view of obj[k]: keys over 29 chars are invisible to %29s.
function awgCsView(obj, k){ return (k.length > 29) ? undefined : awgCsNorm(obj[k]); }
// Cut a string to at most `max` UTF-8 bytes on a character boundary.
function awgUtf8Cut(s, max){
    var out = '', n = 0;
    for(var i = 0; i < s.length; i++){
        var c = s.charCodeAt(i), ch = s.charAt(i), w;
        if(c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length){ ch = s.substr(i, 2); w = 4; i++; }
        else w = (c < 0x80) ? 1 : (c < 0x800 ? 2 : 3);
        if(n + w > max) break;
        out += ch; n += w;
    }
    return out;
}
function awgCsCopy(o){
    var c = {};
    for(var k in o){ if(o.hasOwnProperty(k)) c[k] = o[k]; }
    return c;
}
// Every live-store GET carries a globally unique cache buster (never a per-load counter, never the
// save token): 3006.102+/master serve .htm files with an ETag of the FILE, which never changes
// while its output does, so a repeated URL may be answered 304 from the browser's cache.
var awgCsReqSeq = 0, awgCsTokSeq = 0;
function awgCsUnique(){ return Date.now() + '_' + (++awgCsReqSeq); }
// The save token: base36 time + a counter, [0-9a-z] and at most 12 chars.
function awgCsNewToken(){ return (Date.now().toString(36) + (++awgCsTokSeq).toString(36)).slice(0, 12); }
function awgCsPlainObj(txt){
    try {
        var o = JSON.parse(txt);
        return (o && typeof o === 'object' && !(o instanceof Array)) ? o : null;
    } catch(e){ return null; }
}
// The rendered-page fallback: the settings object of this very page, as the firmware renders it
// into the custom_settings line of the first script. The needle is built by concatenation and
// must be followed by '{' or "new Object()", so this function's own source text (also part of
// the rendered page) can never match; the brace scan is string- and escape-aware.
function awgCsExtractPage(body){
    var needle = 'var custom' + '_settings =', from = 0, i;
    while((i = body.indexOf(needle, from)) !== -1){
        var j = i + needle.length;
        while(j < body.length && /\s/.test(body.charAt(j))) j++;
        if(body.substr(j, 12) === 'new Object()') return {};
        if(body.charAt(j) === '{'){
            var depth = 0, inStr = false, esc = false;
            for(var e = j; e < body.length; e++){
                var c = body.charAt(e);
                if(inStr){
                    if(esc) esc = false;
                    else if(c === '\\') esc = true;
                    else if(c === '"') inStr = false;
                    continue;
                }
                if(c === '"') inStr = true;
                else if(c === '{') depth++;
                else if(c === '}'){ if(--depth === 0) return awgCsPlainObj(body.slice(j, e + 1)); }
            }
            return null;
        }
        from = j;
    }
    return null;
}
// httpd's answer to ANY request of an expired session: a tiny page that navigates the whole tab to
// the login form. The file name is split so no addon page ever contains it contiguously (a
// rendered page is itself a fallback response and must never read as a login page).
var AWG_CS_LOGIN_RE = new RegExp('top\\.location\\.href\\s*=\\s*[\'"]\\/Main_' + 'Login\\.asp');
// Classify a response body, in this fixed order: the AWGCS-framed endpoint → the rendered page →
// the login page (short bodies only) → unusable.
function awgCsParseBody(body){
    var b = String(body == null ? '' : body).replace(/^\s+|\s+$/g, '');
    if(b.length >= 10 && b.slice(0, 5) === 'AWGCS' && b.slice(-5) === 'AWGCS'){
        var mid = b.slice(5, -5).replace(/^\s+|\s+$/g, '');
        if(mid === 'new Object()') return { kind: 'store', obj: {} };   // no settings file at all
        var o = awgCsPlainObj(mid);
        return o ? { kind: 'store', obj: o } : { kind: 'unusable' };
    }
    var po = awgCsExtractPage(b);
    if(po) return { kind: 'store', obj: po };
    if(b.length < 512 && AWG_CS_LOGIN_RE.test(b)) return { kind: 'login' };
    return { kind: 'unusable' };
}
// One GET. cb(kind, body): 'ok' (2xx), 'transient' (timeout / status 0 / 5xx — worth a retry),
// 'missing' (404 and other definitive answers).
function awgCsGet(url, ms, cb){
    var x = new XMLHttpRequest(), fin = false;
    function end(kind){ if(fin) return; fin = true; cb(kind, kind === 'ok' ? String(x.responseText || '') : ''); }
    try { x.open('GET', url, true); } catch(e){ setTimeout(function(){ end('transient'); }, 0); return; }
    x.timeout = ms;
    x.onload = function(){
        var st = x.status;
        end((st >= 200 && st < 300) ? 'ok' : ((st === 0 || st >= 500) ? 'transient' : 'missing'));
    };
    x.onerror = function(){ end('transient'); };
    x.ontimeout = function(){ end('transient'); };
    try { x.send(); } catch(e2){ end('transient'); }
}
// Read the LIVE store: /user/awg_cs.htm (the backend writes it next to the page: an AWGCS-framed
// get_custom_settings), falling back to a fresh GET of this page when the endpoint is unusable.
// o = { budget: ms (pre-fetch) | tries: n (verify), perTry: ms, gap: ms, page: start on the page }.
// cb(r): r.kind = 'store' (r.obj, r.page) | 'login' | 'legacy' (both definitively unusable —
// NOT a timeout) | 'busy' (the budget / the tries ran out on timeouts).
function awgCsFetch(o, cb){
    var t0 = Date.now(), tries = 0, page = !!o.page;
    function next(){
        var left = o.budget ? (o.budget - (Date.now() - t0)) : o.perTry;
        if(o.budget ? (left <= 0) : (tries >= o.tries)){ cb({ kind: 'busy' }); return; }
        tries++;
        var url = page ? (location.pathname + '?_=' + awgCsUnique()) : ('/user/awg_cs.htm?_=' + awgCsUnique());
        awgCsGet(url, Math.max(1000, Math.min(o.perTry, left)), function(kind, body){
            if(kind === 'transient'){ setTimeout(next, o.gap); return; }
            var r = (kind === 'ok') ? awgCsParseBody(body) : { kind: 'unusable' };
            if(r.kind === 'store'){ cb({ kind: 'store', obj: r.obj, page: page }); return; }
            if(r.kind === 'login'){ cb({ kind: 'login' }); return; }
            if(!page){ page = true; tries--; next(); return; }   // switching to the fallback costs no try
            cb({ kind: 'legacy' });
        });
    }
    next();
}
// Did a page-owned key change in the live store since this page's base? (keys of either side)
function awgCsConflict(live){
    var k;
    for(k in live){ if(live.hasOwnProperty(k) && awgCsOwned(k) && awgCsNorm(live[k]) !== awgCsNorm(awgCsBase[k])) return k; }
    for(k in awgCsBase){ if(awgCsBase.hasOwnProperty(k) && awgCsOwned(k) && awgCsNorm(live[k]) !== awgCsNorm(awgCsBase[k])) return k; }
    return '';
}
// The object to post, without the token (appended LAST by awgSave). Normal: every NOT-owned key
// from live, every owned key from `mine`, in live's key order first (the file keeps its layout),
// then this page's new keys. onlyExtra: a copy of live. No live store (LEGACY): a copy of mine.
// Then owned values are trimmed and '' dropped (the reader never returns an empty value — every
// byte counts against the shared 8 KB), name/fo meta of unconfigured profile slots dropped, and
// the extras applied (null = delete the key).
function awgCsBuildFinal(mine, live, onlyExtra, extra){
    var f = {}, k;
    if(!live){
        for(k in mine){ if(mine.hasOwnProperty(k)) f[k] = mine[k]; }
        // A LEGACY save can't see the store; don't let it revert a profile switch made elsewhere
        // (CLI / another tab): an untouched pointer follows the backend's last report of it. A
        // pointer the page only REPAIRED (pfUserFix, K13 — awgPfPtrAuto) is untouched too: else the
        // repair reads as an edit and reverts a CLI switch made after the load. A page «Switch to»
        // is never overridden here — applyConfig posts its target as an extra, applied below.
        var mp = awgCsNorm(mine.awg_profile_active);
        if(!onlyExtra && (mp === awgCsNorm(awgCsBase.awg_profile_active) || (awgPfPtrAuto !== null && mp === awgPfPtrAuto)) &&
           awgPfStatus && awgPfStatus.user >= 1 && awgLastStatus && !awgLastStatus.starting && !awgLastStatus.stopping)
            f.awg_profile_active = String(awgPfStatus.user);
    } else if(onlyExtra){
        for(k in live){ if(live.hasOwnProperty(k)) f[k] = live[k]; }
    } else {
        for(k in live){
            if(!live.hasOwnProperty(k)) continue;
            if(!awgCsOwned(k)) f[k] = live[k];
            else if(mine.hasOwnProperty(k)) f[k] = mine[k];
        }
        for(k in mine){ if(mine.hasOwnProperty(k) && awgCsOwned(k) && !f.hasOwnProperty(k)) f[k] = mine[k]; }
    }
    if(!onlyExtra || !live){
        for(k in f){
            if(!f.hasOwnProperty(k) || !awgCsOwned(k)) continue;
            if(typeof f[k] === 'string') f[k] = f[k].replace(/^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g, '');
            if(f[k] === '' || f[k] === undefined || f[k] === null) delete f[k];
        }
        for(var n = 1; n <= AWG_PF_MAX; n++){
            if(!pfConfiguredIn(f, n)){ delete f[pfKey(n, 'name')]; delete f[pfKey(n, 'fo')]; }
        }
    }
    for(k in extra){
        if(!extra.hasOwnProperty(k)) continue;
        if(extra[k] === null) delete f[k]; else f[k] = String(extra[k]);
    }
    delete f.awg_save_tok;
    return f;
}
// The file keeps the posted order, so a store the firmware cut short (full /jffs) reads back as a
// strict in-order PREFIX of what the reader would show of the posted object.
function awgCsIsPrefix(live2, fobj){
    var fk = [], k;
    for(k in fobj){ if(fobj.hasOwnProperty(k) && awgCsView(fobj, k) !== undefined) fk.push(k); }
    var lk = [];
    for(k in live2){ if(live2.hasOwnProperty(k)) lk.push(k); }
    if(lk.length >= fk.length) return false;
    for(var i = 0; i < lk.length; i++){ if(lk[i] !== fk[i]) return false; }
    return true;
}
function awgCsSameStore(a, b){
    var ka = [], kb = [], k, i;
    for(k in a){ if(a.hasOwnProperty(k)) ka.push(k); }
    for(k in b){ if(b.hasOwnProperty(k)) kb.push(k); }
    if(ka.length !== kb.length) return false;
    for(i = 0; i < ka.length; i++){ if(ka[i] !== kb[i] || String(a[ka[i]]) !== String(b[kb[i]])) return false; }
    return true;
}
// What the read-back says about OUR POST (tok = its token, live = the pre-fetch).
function awgCsClassify(live2, fobj, live, tok, late){
    var t2 = live2.awg_save_tok, t1 = live ? live.awg_save_tok : undefined;
    if(t2 === tok) return late ? 'verified-late' : 'verified';
    if(t2 !== undefined) return (t1 !== undefined && t2 === t1) ? 'discarded' : 'unknown';
    // No token in the store: unchanged → the firmware dropped the POST; our keys cut short → a
    // partial write; anything else → another (older, token-less) writer.
    if(t1 === undefined && live && awgCsSameStore(live2, live)) return 'discarded';
    return awgCsIsPrefix(live2, fobj) ? 'truncated' : 'unknown';
}
// A verified store whose page-owned values differ from what we posted: a writer that keeps the
// token line (the CLI's set_setting) changed something between our write and the read-back.
function awgCsDrift(live2, fobj){
    var k;
    for(k in fobj){ if(fobj.hasOwnProperty(k) && awgCsOwned(k) && awgCsNorm(live2[k]) !== awgCsView(fobj, k)) return true; }
    for(k in live2){ if(live2.hasOwnProperty(k) && awgCsOwned(k) && awgCsNorm(live2[k]) !== awgCsView(fobj, k)) return true; }
    return false;
}

// The form lock: one settings save at a time, and no other submitter of the shared form (which
// has ONE hidden iframe) while it runs — their POST would cancel ours mid-flight.
var awgCsSaving = false;
var awgCsTruncLive = null;   // the pre-fetch live store kept after a 'truncated' save (see below)
var awgCsAfterSave = [];     // deferred actions queued while the form was locked (awgAfterSave)
function awgFormBusy(){ return awgCsSaving; }
// The short "please wait" reply of every refused submitter: the ack next to the Apply buttons for
// those buttons (nearAck), an alert for every other control (the ack would be off-screen or behind
// a modal).
function awgFormBusyRefuse(nearAck){
    if(nearAck) awgShowAck(T('MSG_WAIT_SAVE'), false);
    else alert(T('MSG_WAIT_SAVE'));
}
// Run fn once the current save has finished (now, when none is running).
function awgAfterSave(fn){ if(awgCsSaving) awgCsAfterSave.push(fn); else fn(); }

// awgSave(opts) — the one path for every settings-carrying POST. Returns false (nothing done) when
// another save holds the form. opts:
//   mode      'normal' (the page's own keys win) | 'onlyExtra' (post the live store + opts.extra —
//             for actions that carry a key or two and must not act as a settings save)
//   extra     keys to set on the final object (null = delete)
//   check     'full' (awgSettingsOverflow on the final object) | 'total' (the 8 KB total only)
//   action    the action_script, or function(final) returning it
//   fixFinal  function(final) — last adjustment before the size check (pfDelete)
//   abort     function() → true: give up before posting (result 'aborted')
//   busyUI    function(phase): 'check' at entry (label the caller's button), 'submit' right
//             before onSubmit, 'idle' when the save ends before anything was posted
//   onSubmit  function(final) — the caller's "in progress" UI, run right before the POST
//   done      function(result, info) — MUST handle every result (the lock is already released):
//             'verified' | 'verified-late' (the router was busy: written, but the action may have
//             been skipped) | 'unverified' (posted, the read-back failed) | 'overflow' (info.ovf)
//             | 'conflict' | 'busy' | 'login' | 'discarded' (the event still fired) | 'unknown'
//             (another writer at the same moment) | 'truncated' (a partial write) | 'aborted'
function awgSave(opts){
    if(awgCsSaving) return false;
    awgCsSaving = true;
    // Frozen at entry: a model change made while the pre-fetch runs must not leak into this POST.
    var mine = awgCsCopy(custom_settings);
    var extra = opts.extra || {};
    var ui = opts.busyUI || null;
    var tok = awgCsNewToken(), submitted = false, fin = false;
    if(ui) ui('check');
    pfBarLock(true);
    function done(res, info){
        if(fin) return;
        fin = true;
        awgCsSaving = false;
        if(!submitted && ui) ui('idle');
        pfBarLock(false);
        try { opts.done(res, info || {}); }
        finally {
            var q = awgCsAfterSave; awgCsAfterSave = [];
            for(var i = 0; i < q.length; i++){ try { q[i](); } catch(e){} }
        }
    }
    awgCsFetch({ budget: 25000, perTry: 6000, gap: 1000 }, function(r){
        if(r.kind === 'login'){ done('login'); return; }
        if(r.kind === 'busy'){ done('busy'); return; }
        var live = (r.kind === 'store') ? r.obj : null;       // null = LEGACY (no live store readable)
        // After a partial write the next save rewrites EVERYTHING from the complete pre-fetch copy
        // kept then (the store now lacks other addons' keys too), once, without a conflict check.
        var retained = live ? awgCsTruncLive : null;
        // "full" = this POST writes the page's own keys (a normal save, that rewrite, or LEGACY,
        // where the page's model is all there is); onlyExtra only adds its extras to live.
        var full = (opts.mode !== 'onlyExtra') || !!retained || !live;
        if(live && full && !retained){
            if(awgCsStale){ done('conflict', { stale: true }); return; }
            var ck = awgCsConflict(live);
            if(ck){ done('conflict', { key: ck }); return; }
        }
        var fobj = awgCsBuildFinal(mine, retained || live, !full, extra);
        // Keys the caller forces in the final (fixFinal) are not the model's value: the model keeps
        // its own (pending) one — they are left out of the post-save model sync.
        var forced = {};
        if(opts.fixFinal){
            var pre = awgCsCopy(fobj);
            opts.fixFinal(fobj);
            for(var fk in pre){ if(pre.hasOwnProperty(fk) && pre[fk] !== fobj[fk]) forced[fk] = 1; }
            for(fk in fobj){ if(fobj.hasOwnProperty(fk) && pre[fk] !== fobj[fk]) forced[fk] = 1; }
        }
        delete fobj.awg_save_tok;
        fobj.awg_save_tok = tok;   // LAST: a file cut short loses it and can't read as saved
        var ovf = awgSettingsOverflow(fobj, opts.check !== 'full');
        if(ovf){ ovf.obj = fobj; ovf.live = live; done('overflow', { ovf: ovf, fobj: fobj, live: live }); return; }
        if(opts.abort && opts.abort()){ done('aborted'); return; }

        var act = (typeof opts.action === 'function') ? opts.action(fobj) : opts.action;
        var ac = document.getElementById('amng_custom');
        if(ac) ac.value = JSON.stringify(fobj);
        document.form.action_script.value = act;
        submitted = true;
        if(retained) awgCsTruncLive = null;
        if(ui) ui('submit');
        if(opts.onSubmit) opts.onSubmit(fobj);
        // The load listener and the 20 s no-load fallback belong to THIS submit only (a new submit
        // into the same iframe cancels the previous navigation). A load ≥10 s after submit is the
        // notify_rc signature: the store was written, then rc blocked ~15 s on one of our
        // foreground handlers and DROPPED this event.
        var fr = document.getElementById('hidden_frame'), landed = false, tm = null, t0 = 0;
        function onl(){ arrived(false); }
        function arrived(viaTimer){
            if(landed) return;
            landed = true;
            if(tm) clearTimeout(tm);
            try { fr.removeEventListener('load', onl); } catch(e){}
            var late = viaTimer || (Date.now() - t0 >= 10000);
            if(!live){ finish('unverified', null); return; }   // LEGACY: nothing to read back
            awgCsFetch({ tries: 3, perTry: 20000, gap: 1500, page: r.page }, function(v){
                if(v.kind !== 'store'){ finish('unverified', null); return; }
                finish(awgCsClassify(v.obj, fobj, live, tok, late), v.obj);
            });
        }
        function finish(res, live2){
            var ok = (res === 'verified' || res === 'verified-late' || res === 'unverified' || res === 'truncated');
            var k, v;
            if(ok){
                // The base advances ONLY to what this page wrote: a change another writer made
                // in the meantime must still surface as a conflict on the next save.
                if(full){
                    var ks = awgCsCopy(awgCsBase);
                    for(k in fobj){ if(fobj.hasOwnProperty(k)) ks[k] = 1; }
                    for(k in ks){
                        if(!ks.hasOwnProperty(k) || !awgCsOwned(k)) continue;
                        v = awgCsView(fobj, k);
                        if(v === undefined) delete awgCsBase[k]; else awgCsBase[k] = v;
                    }
                    if((res === 'verified' || res === 'verified-late') && awgCsDrift(live2, fobj)) awgCsStale = true;
                    awgCsSyncModel(mine, fobj, forced);
                } else {
                    for(k in extra){
                        if(!extra.hasOwnProperty(k) || !awgCsOwned(k)) continue;
                        v = (extra[k] === null) ? undefined : awgCsNorm(extra[k]);
                        if(v === undefined) delete awgCsBase[k]; else awgCsBase[k] = v;
                    }
                }
                // Extras that are page-owned keys (analyzer device, via-VPN toggles) are now
                // part of the saved model.
                for(k in extra){
                    if(!extra.hasOwnProperty(k) || !awgCsOwned(k)) continue;
                    if(extra[k] === null) delete custom_settings[k]; else custom_settings[k] = String(extra[k]);
                }
            }
            if(res === 'truncated') awgCsTruncLive = retained || live;
            if(res === 'unknown') awgCsStale = true;
            done(res, { fobj: fobj, live: live, live2: live2 });
        }
        if(fr) fr.addEventListener('load', onl);
        tm = setTimeout(function(){ arrived(true); }, 20000);
        t0 = Date.now();
        awgSubmitForm();
    });
    return true;
}
// After a normal save the model must equal what was written: drop the page-owned keys the final
// object left out ('' values, meta of unconfigured slots) and take its trimmed values. Only keys
// still holding the value frozen at entry are touched; the meta of the slot the form is editing
// is kept (a name typed for a profile that isn't saved yet — it rides the Apply that saves it), and
// so are the keys the caller forced in the final (`forced`, see awgSave's fixFinal).
function awgCsSyncModel(mine, fobj, forced){
    var keep = pfConfigured(awgPfSel) ? {} : pfMetaKeys(awgPfSel);
    for(var k in mine){
        if(!mine.hasOwnProperty(k) || !awgCsOwned(k) || custom_settings[k] !== mine[k]) continue;
        if(forced && forced.hasOwnProperty(k)) continue;
        if(!fobj.hasOwnProperty(k)){ if(!keep.hasOwnProperty(k)) delete custom_settings[k]; }
        else if(fobj[k] !== mine[k]) custom_settings[k] = fobj[k];
    }
}
// The user-facing message of a save outcome that means the same for every caller (tail = the
// action-specific consequence of a discarded save).
function awgSaveNotify(res, info, tail){
    info = info || {};
    if(res === 'overflow') alert(awgOverflowMsg(info.ovf));
    else if(res === 'conflict'){ if(confirm(T('MSG_CS_CONFLICT'))) awgReloadFresh(); }
    else if(res === 'busy') alert(T('MSG_ROUTER_BUSY'));
    else if(res === 'login') alert(T('MSG_SESSION_EXPIRED'));
    else if(res === 'discarded') alert(T('MSG_SAVE_DISCARDED') + (tail ? '\n' + tail : ''));
    else if(res === 'unknown') alert(T('MSG_CS_UNKNOWN'));
    else if(res === 'truncated') alert(T('MSG_STORE_TRUNCATED'));
}
// Reload for a conflict: a plain cache-busted GET (no scroll-to-log flag, unlike awgReload).
function awgReloadFresh(){ window.location.href = window.location.pathname + '?_=' + (new Date()).getTime(); }
// busyUI for a single button: «Checking…» + disabled while the live store is read, the button's
// own label/state back at submit (the caller's onSubmit then takes over) or when nothing was posted.
function awgBtnBusyUI(btn){
    var lbl = null, dis = false;
    return function(phase){
        if(!btn) return;
        if(phase === 'check'){ lbl = btn.value; dis = btn.disabled; btn._awgChk = true; btn.value = T('BTN_CHECKING'); btn.disabled = true; }
        else if(lbl !== null){ btn.value = lbl; btn.disabled = dis; btn._awgChk = false; lbl = null; }
    };
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

// ==================== Config profiles (multi-config) ====================
// A profile is a numbered slot of the client config fields. Slot 1 = the legacy unsuffixed
// keys (awg_iface_p1, …) so existing installs upgrade with zero migration; slots 2..MAX use
// awg_pf<N>_<field>. META (name / failover participation) is always slot-prefixed. Mirrors
// pf_key() in amneziawg.sh — keep the two in sync.
var AWG_PF_MAX = 5;
// DOM id = 'awg_' + suffix for every data field of the config form (I1-I5 ride separately
// as the chunked base64 'initdata', see pfStoreForm/pfLoadForm).
var AWG_PF_FIELDS = ['iface_p1','address','listenport','mtu','dns',
                     'peer_p1','peer_p2','peer_endpoint','peer_allowedips','peer_keepalive',
                     'jc','jmin','jmax','s1','s2','s3','s4','h1','h2','h3','h4',
                     // AmneziaWG 3.0 device params. Short suffixes keep the per-slot
                     // custom_settings key names (awg_pf5_rjt) well inside the length the
                     // firmware's settings store is happy with.
                     'hpk','cpa','rat','rto','rjt','kat','mha',
                     // AmneziaWG 3.1: rt = RandomTrailers, dc = DisableCookies ('' | 'on' | 'off').
                     'rt','dc'];
// AWG 3.0 fields, in the order the daemon documents them — DOM id is 'awg_' + suffix.
var AWG3_FIELDS = ['hpk','cpa','rat','rto','rjt','kat','mha'];
// AWG 3.1 fields — gated separately (status.awg31): a 3.0-capable pair must keep the seven
// fields above usable while these two stay disabled.
var AWG31_FIELDS = ['rt','dc'];

// amneziawg-tools compares config keys with strncasecmp(), so a hand-written or
// provider-generated .conf may spell them any way (`privatekey`, `ENDPOINT`, …) and awg
// still accepts it. parseConfig() used to compare exactly, silently dropping such lines.
// Canonicalise via this map first — lowercase spelling -> the spelling the switch expects.
var AWG_CONF_KEY_CANON = (function(){
    var keys = ['PrivateKey','Address','ListenPort','MTU','DNS',
                'Jc','Jmin','Jmax','S1','S2','S3','S4','H1','H2','H3','H4',
                'I1','I2','I3','I4','I5',
                'HeaderProtectionKey','ContentPaddingAddition','RekeyAfterTime',
                'RekeyTimeout','RejectAfterTime','KeepaliveTimeout','MaxHandshakeAttempts',
                'RandomTrailers','DisableCookies',
                'PublicKey','PresharedKey','Endpoint','AllowedIPs','PersistentKeepalive'];
    var m = {};
    for(var i = 0; i < keys.length; i++) m[keys[i].toLowerCase()] = keys[i];
    return m;
})();
var awgPfSel = 1;         // slot the form currently edits
var awgPfSnapshot = '';   // form state at load — detects unsaved edits on slot change
var awgPfStatus = null;   // last status.profile from the backend (active/user/auto)
var awgPfPtrAuto = null;  // the pointer value pfUserFix last wrote (a K13 repair, not a user choice)
var awgLastStatus = null; // the last status object read (transition guards, switch bookkeeping)
var awgPfRenderKey = '';  // active|auto of the last bar render (skip needless re-renders)
var awgPfBarMsg = '';     // the bar's own status line («Deleting…» / «Profile deleted ✓»)
var awgPfBarMsgTimer = null;
var awgPfBarBusyRender = false;   // the bar was re-rendered (disabled) while a save held the form
var awgPfBarLocked = [];          // bar controls disabled by pfBarLock, with their prior state
var awgPfRenderSeq = 0;           // bumps on every bar draw (a postponed render skips if one happened)
var awgPfRenderPending = false;   // a harvesting render asked for during a save waits for its end

function pfKey(slot, field){
    if(field === 'name' || field === 'fo') return 'awg_pf' + slot + '_' + field;
    return (slot == 1) ? ('awg_' + field) : ('awg_pf' + slot + '_' + field);
}
function pfMetaKeys(slot){
    var o = {};
    o[pfKey(slot, 'name')] = 1;
    o[pfKey(slot, 'fo')] = 1;
    return o;
}
// The profile slot a settings key belongs to (0 = none): awg_pf<N>_* (meta of slot 1 included),
// or one of slot 1's legacy unsuffixed data keys.
function pfSlotOfKey(k){
    var m = /^awg_pf(\d+)_/.exec(k);
    if(m){ var s = parseInt(m[1], 10); return (s >= 1 && s <= AWG_PF_MAX) ? s : 0; }
    if(/^awg_initdata\d*$/.test(k)) return 1;
    return (k.indexOf('awg_') === 0 && AWG_PF_FIELDS.indexOf(k.slice(4)) !== -1) ? 1 : 0;
}
// Profile names (C4). The store is whitespace-hostile — the firmware's reader cuts a value at its
// first space, so «My Phone» came back as «My» and the next save persisted the cut. Names are
// sanitized (whitespace, the store's | and ; delimiters and < > become one space, 32 chars) and
// stored with '%' → %25 and ' ' → %20; decoding is one pass over exactly those two escapes, so a
// legacy raw name (stored before 1.5.26) decodes to itself.
function pfNameSan(s){
    return String(s == null ? '' : s).replace(/[\s|;<>]+/g, ' ').replace(/^ +| +$/g, '').slice(0, 32).replace(/[\uD800-\uDBFF]$/, '').replace(/ +$/, '');
}
function pfNameEnc(s){ return pfNameSan(s).replace(/%/g, '%25').replace(/ /g, '%20'); }
function pfNameDec(s){
    return String(s == null ? '' : s).replace(/%(20|25)/g, function(m, c){ return c === '20' ? ' ' : '%'; });
}
function pfUser(){
    var p = parseInt(custom_settings.awg_profile_active, 10);
    return (p >= 1 && p <= AWG_PF_MAX) ? p : 1;
}
// The slot the tunnel actually runs (failover override included) — from the last status
// poll; falls back to the persisted user choice before the first poll lands.
function pfActiveNow(){
    return (awgPfStatus && awgPfStatus.active >= 1) ? awgPfStatus.active : pfUser();
}
function pfConfiguredIn(obj, slot){
    return !!(obj[pfKey(slot, 'iface_p1')]) && !!(obj[pfKey(slot, 'peer_endpoint')]);
}
function pfConfigured(slot){ return pfConfiguredIn(custom_settings, slot); }
// K13 on the page: when the pointer names an EMPTY slot (a ≤1.5.25 delete could leave that), the
// backend's profile_user runs the lowest configured slot. Normalize the MODEL's pointer the same
// way — not just the getter — so pfUser() and the status' user agree: the form opens on the profile
// that really runs, the new row's trash reaches the discard path instead of the primary refusal,
// and «Add profile» appends a real backup rather than filling the pointed slot (an import there
// would silently make it the primary). The base keeps the old value, so the next save persists the
// repair as an ordinary page edit. No configured slot at all (a fresh install) = nothing to fix.
// The value written is remembered (awgPfPtrAuto): a LEGACY save must still treat the repaired
// pointer as untouched and follow the backend's user (awgCsBuildFinal).
function pfUserFix(){
    if(pfConfigured(pfUser())) return;
    for(var s = 1; s <= AWG_PF_MAX; s++){
        if(pfConfigured(s)){ custom_settings.awg_profile_active = awgPfPtrAuto = String(s); return; }
    }
}
// Every profile number the user sees is an ORDINAL (C5): the 1-based position among the
// configured slots in slot order — stored slot numbers stay stable and are never renumbered, so
// slots {1,3} read as #1 and #2 (never «3/2»). An unconfigured slot (the unsaved new row) is N+1.
function pfOrdinal(slot){
    var k = 0;
    for(var n = 1; n <= AWG_PF_MAX; n++){ if(pfConfigured(n)){ k++; if(n === slot) return k; } }
    return k + 1;
}
function pfName(slot){
    var nm = pfNameDec(custom_settings[pfKey(slot, 'name')] || '');
    return nm ? nm : T('PF_UNNAMED', pfOrdinal(slot));
}
// Derive a default profile name from an imported .conf filename — providers usually name the
// file after the country/location (Netherlands.conf, nl-amsterdam.conf). Strips any path and
// the trailing extension, then applies the same sanitation as the name inputs (pfNameSan).
// Unicode names (Германия.conf) pass through. Returns the DISPLAY form (the caller encodes it);
// empty result (e.g. a dotfile) → caller keeps the "Profile N" fallback.
function pfCleanFileName(fname){
    var base = String(fname || '').replace(/^.*[\\/]/, '').replace(/\.[^.]+$/, '');
    return pfNameSan(base);
}
function pfInitB64(slot){
    var b64 = custom_settings[pfKey(slot, 'initdata')] || '';
    for(var ic = 1; ic <= 30 && custom_settings[pfKey(slot, 'initdata') + ic] != undefined; ic++)
        b64 += custom_settings[pfKey(slot, 'initdata') + ic];
    return b64;
}
function pfFormSerialize(){
    var s = '';
    for(var i = 0; i < AWG_PF_FIELDS.length; i++){
        var el = document.getElementById('awg_' + AWG_PF_FIELDS[i]);
        s += (el ? el.value : '') + '\u0001';
    }
    for(var iz = 1; iz <= 5; iz++){
        var e2 = document.getElementById('awg_i' + iz);
        s += (e2 ? e2.value : '') + '\u0001';
    }
    return s;
}

// Fill the config form from a slot's stored values (absent keys clear the field).
function pfLoadForm(slot){
    for(var i = 0; i < AWG_PF_FIELDS.length; i++){
        var k = pfKey(slot, AWG_PF_FIELDS[i]);
        setVal('awg_' + AWG_PF_FIELDS[i], custom_settings[k] != undefined ? custom_settings[k] : '');
    }
    for(var iz = 1; iz <= 5; iz++) setVal('awg_i' + iz, '');
    var b64 = pfInitB64(slot);
    if(b64){
        try {
            var initLines = atob(b64).split('\n');
            for(var il = 0; il < initLines.length; il++){
                var ip = initLines[il].split('=');
                if(ip.length >= 2){
                    var ik = ip[0].trim().toLowerCase();
                    if(ik === 'i1' || ik === 'i2' || ik === 'i3' || ik === 'i4' || ik === 'i5')
                        setVal('awg_' + ik, ip.slice(1).join('=').trim());
                }
            }
        } catch(e){}
    }
    awgPfSnapshot = pfFormSerialize();
    pfRenderBar();
    updateFirstRun();
}

// Remove every stored key of a slot from the local model (persisted by the next Apply —
// the settings POST replaces the whole store, so deleted keys vanish on the router too).
function pfWipeSlot(slot){
    for(var i = 0; i < AWG_PF_FIELDS.length; i++) delete custom_settings[pfKey(slot, AWG_PF_FIELDS[i])];
    delete custom_settings[pfKey(slot, 'initdata')];
    for(var ck = 1; ck <= 30; ck++) delete custom_settings[pfKey(slot, 'initdata') + ck];
    delete custom_settings[pfKey(slot, 'name')];
    delete custom_settings[pfKey(slot, 'fo')];
}

// The form reads as a DELETE of its slot: no private key, no peer key, no endpoint.
function pfFormEmpty(){
    var ids = ['awg_iface_p1', 'awg_peer_p1', 'awg_peer_endpoint'];
    for(var i = 0; i < ids.length; i++){ if((document.getElementById(ids[i]) || {}).value) return false; }
    return true;
}

// Serialize the config form into the slot's keys. Returns false when validation blocks the
// save (field flagged). A fully-empty form (pfFormEmpty) is allowed for a NON-active slot — it
// wipes the slot (that's how a delete gets persisted) — but the active slot must stay complete.
function pfStoreForm(slot){
    var vals = {};
    for(var i = 0; i < AWG_PF_FIELDS.length; i++){
        var el = document.getElementById('awg_' + AWG_PF_FIELDS[i]);
        if(!el) continue;
        var v = el.value;
        // Remove spaces from comma-separated values (Merlin truncates at spaces)
        if(AWG_PF_FIELDS[i] === 'peer_allowedips' || AWG_PF_FIELDS[i] === 'address' || AWG_PF_FIELDS[i] === 'dns')
            v = v.replace(/\s+/g, '');
        vals[AWG_PF_FIELDS[i]] = v;
    }
    var pk = vals.iface_p1 || '', pubk = vals.peer_p1 || '', ep = vals.peer_endpoint || '';
    if(pfFormEmpty()){
        if(slot == pfActiveNow()){
            awgFlagField('awg_iface_p1', T('MSG_REQUIRED_FIELDS'));
            return false;
        }
        // D6 on this second delete path, the same rule as pfDelete: under a failover override the
        // USER's primary is not the running slot, yet wiping it would leave the pointer on an empty
        // slot. An already-empty slot is exempt — wiping it deletes nothing, and a pointer an older
        // version left on an empty slot must not block every Apply. (pfConfigured still reads the
        // stored keys here: this function writes only after validation.)
        if(pfConfigured(slot) && (slot == pfUser() || (awgPfStatus && slot == awgPfStatus.user))){
            awgFlagField('awg_iface_p1', T('MSG_PF_DEL_PRIMARY'));
            return false;
        }
        pfWipeSlot(slot);
        // Clear the slot's name in the bar too — else applyConfig's harvest right after this
        // would write the typed name back and resurrect an orphan awg_pfN_name (D3) — and put its
        // failover box back to the default (on): the harvest keeps an untick of the edited slot,
        // which a profile imported into the emptied slot later would inherit.
        var bne = document.getElementById('awg_pf_name_' + slot);
        if(bne) bne.value = '';
        var bfe = document.getElementById('awg_pf_fo_' + slot);
        if(bfe) bfe.checked = true;
        awgPfSnapshot = pfFormSerialize();
        return true;
    }
    if(!pk || !pubk || !ep){
        awgFlagField(!pk ? 'awg_iface_p1' : (!pubk ? 'awg_peer_p1' : 'awg_peer_endpoint'), T('MSG_REQUIRED_FIELDS'));
        return false;
    }
    if(pk.length !== 44 || pubk.length !== 44){
        awgFlagField(pk.length !== 44 ? 'awg_iface_p1' : 'awg_peer_p1', T('MSG_BAD_KEY_FORMAT'));
        return false;
    }
    if(!/:\d{1,5}$/.test(ep)){
        awgFlagField('awg_peer_endpoint', T('MSG_ENDPOINT_NEEDS_PORT'));
        return false;
    }
    // Sanity-check I1-I5 before saving: an AmneziaWG obfuscation tag is `<…>`, so a value with
    // a '<' must balance its brackets and end with '>'. The classic failure is a TRUNCATED
    // value that lost its closing '>' (incomplete paste / an old storage cap), which
    // amneziawg-go then rejects with "failed to parse I1: missing enclosing >".
    for(var iz = 1; iz <= 5; iz++){
        var izv = document.getElementById('awg_i' + iz);
        var izs = izv ? String(izv.value || '').trim() : '';
        if(izs && izs.indexOf('<') !== -1){
            var izo = (izs.match(/</g) || []).length, izc = (izs.match(/>/g) || []).length;
            if(izo !== izc || izs.charAt(0) !== '<' || izs.charAt(izs.length - 1) !== '>'){
                alert(T('MSG_IPARAM_MALFORMED', 'I' + iz));
                if(izv) izv.focus();
                return false;
            }
        }
    }
    // I1-I5 as base64 (contain HTML-unsafe chars)
    var initData = '';
    for(var ix = 1; ix <= 5; ix++){
        var iv = document.getElementById('awg_i' + ix);
        if(iv && iv.value) initData += 'I' + ix + ' = ' + iv.value + '\n';
    }
    var initB64;
    try {
        initB64 = initData ? btoa(initData) : '';
    } catch(e){
        alert(T('MSG_INIT_NON_ASCII'));
        return false;
    }
    for(var i2 = 0; i2 < AWG_PF_FIELDS.length; i2++)
        custom_settings[pfKey(slot, AWG_PF_FIELDS[i2])] = vals[AWG_PF_FIELDS[i2]];
    // The firmware caps ONE custom_settings value at ~3000 chars; a long I-param's base64
    // overflows that and is silently truncated (the closing '>' is lost → setconf rejects
    // "missing enclosing >"). Split the base64 across <initdata> + <initdata>1 + … (<=2900
    // each, PER SLOT) and clear any stale chunks from a previous, longer value.
    for(var ck = 1; ck <= 30; ck++) delete custom_settings[pfKey(slot, 'initdata') + ck];
    var ICHUNK = 2900;
    if(initB64.length <= ICHUNK){
        custom_settings[pfKey(slot, 'initdata')] = initB64;
    } else {
        custom_settings[pfKey(slot, 'initdata')] = initB64.substr(0, ICHUNK);
        for(var cj = 1; cj * ICHUNK < initB64.length; cj++)
            custom_settings[pfKey(slot, 'initdata') + cj] = initB64.substr(cj * ICHUNK, ICHUNK);
    }
    awgPfSnapshot = pfFormSerialize();
    return true;
}

// Pull the bar's editable state (names, per-slot failover flags, the global toggle) into the
// local model. Runs before every bar re-render and on Apply, so typed-but-unsaved values
// survive a re-render and always ride the next POST. Never while a save holds the form: its
// rollback / model sync own the model then.
function pfHarvestBar(){
    if(awgFormBusy()) return;
    for(var n = 1; n <= AWG_PF_MAX; n++){
        var nk = pfKey(n, 'name'), fk = pfKey(n, 'fo');
        // Meta of a slot that is neither configured nor the one being edited is an orphan (a
        // deleted profile's leftover, D3): never keep it, whatever an input may still show.
        if(!pfConfigured(n) && n !== awgPfSel){ delete custom_settings[nk]; delete custom_settings[fk]; continue; }
        var ne = document.getElementById('awg_pf_name_' + n);
        if(ne){
            var v = pfNameEnc(ne.value);
            if(v) custom_settings[nk] = v; else delete custom_settings[nk];
        }
        var fe = document.getElementById('awg_pf_fo_' + n);
        if(fe){
            // A configured slot carries an explicit flag. The EDITED unsaved slot keeps an untick
            // too (absent = on, as the reader and the backend read it), like its typed name: every
            // redraw draws the box from the model — a refused Apply's rollback, a re-import, a
            // status-driven render — so a flag dropped here came back ticked, and the Apply that
            // saved the profile stored fo=1 against the user's choice. awgCsBuildFinal drops the
            // meta of unconfigured slots from every POST; the empty-form wipe resets the box.
            if(pfConfigured(n)) custom_settings[fk] = fe.checked ? '1' : '0';
            else if(!fe.checked) custom_settings[fk] = '0';
            else delete custom_settings[fk];
        }
    }
    var fw = document.getElementById('awg_failover');
    if(fw) custom_settings.awg_failover = fw.checked ? '1' : '0';
}

// noHarvest: render the model as it is (after a save / a rollback the model is the truth and the
// inputs may still show what was just posted or refused). While a save holds the form only such a
// render draws (disabled); a harvesting one can't harvest then (pfHarvestBar), and drawing from a
// model that never saw what is typed into the bar reset it: a save that doesn't harvest the bar
// (geo update, analyzer start, update) keeps its unapplied names / failover ticks ONLY in the
// inputs — a status-driven render after a failover hop wiped them, then pfBarLock(false)'s redraw
// made it final. It waits for the save's end instead and harvests first — unless the bar has been
// drawn since (the caller's own redraw after a save that harvested on entry: the model is the truth).
function pfRenderBar(noHarvest){
    var bar = document.getElementById('awg_pf_bar');
    if(!bar) return;
    var busy = awgFormBusy();
    if(busy && !noHarvest){
        if(!awgPfRenderPending){
            awgPfRenderPending = true;
            var seq = awgPfRenderSeq;
            awgAfterSave(function(){ awgPfRenderPending = false; if(awgPfRenderSeq === seq) pfRenderBar(); });
        }
        return;
    }
    if(!noHarvest) pfHarvestBar();
    var active = pfActiveNow();
    var auto = !!(awgPfStatus && awgPfStatus.auto);
    awgPfRenderKey = active + '|' + (auto ? 1 : 0);
    var trash = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="6" y1="6" x2="18" y2="18"></line><line x1="18" y1="6" x2="6" y2="18"></line></svg>';
    var dis = busy ? ' disabled' : '';
    // Configured slots in slot order, numbered by ordinal (C5); the unsaved new row (the form
    // edits an unconfigured slot) comes LAST as N+1, whatever its slot number.
    var rows = [], n;
    for(n = 1; n <= AWG_PF_MAX; n++){ if(pfConfigured(n)) rows.push(n); }
    var used = rows.length;
    if(!pfConfigured(awgPfSel)) rows.push(awgPfSel);
    var html = '';
    for(var ri = 0; ri < rows.length; ri++){
        n = rows[ri];
        var cfg = (ri < used);
        // The edited slot shows the LIVE form endpoint (a just-imported .conf is visible
        // before Apply); other slots show their stored value.
        var ep = (n === awgPfSel)
            ? (((document.getElementById('awg_peer_endpoint') || {}).value) || '')
            : (custom_settings[pfKey(n, 'peer_endpoint')] || '');
        var foChecked = (custom_settings[pfKey(n, 'fo')] != '0') ? ' checked' : '';
        html += '<div class="awg-pf-row' + (n === awgPfSel ? ' sel' : '') + '" onclick="pfSelect(' + n + ');" title="' + escHtml(T('TITLE_PF_EDIT')) + '">' +
            '<b style="min-width:14px; text-align:center;">' + (ri + 1) + '</b>' +
            '<input type="text" class="input_25_table" style="width:150px;" id="awg_pf_name_' + n + '" maxlength="32" value="' + escHtml(pfNameDec(custom_settings[pfKey(n, 'name')] || '')) + '" placeholder="' + escHtml(T('PF_UNNAMED', ri + 1)) + '" onclick="event.stopPropagation();" oninput="pfUpdateDirtyHint();"' + dis + '>' +
            '<span class="awg-pf-ep">' + (ep ? escHtml(ep) : '<i>' + escHtml(T('LBL_PF_EMPTY')) + '</i>') + '</span>' +
            '<span style="margin-left:auto; display:flex; align-items:center; gap:10px;" onclick="event.stopPropagation();">' +
                '<label style="font-size:11px; color:#b6bdc7; white-space:nowrap; cursor:pointer;" title="' + escHtml(T('TITLE_PF_FO')) + '"><input type="checkbox" id="awg_pf_fo_' + n + '"' + foChecked + ' onchange="pfUpdateDirtyHint();"' + dis + '> ' + escHtml(T('LBL_PF_FO')) + '</label>' +
                (n === active
                    ? '<span class="awg-pf-badge' + (auto ? ' auto' : '') + '">' + escHtml(T('LBL_PF_ACTIVE')) + (auto ? ' · ' + escHtml(T('LBL_PF_AUTO')) : '') + '</span>'
                    : (cfg ? '<input type="button" class="button_gen" style="font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;" value="' + escHtml(T('BTN_PF_SWITCH')) + '" onclick="pfSwitch(' + n + ');"' + dis + '>' : '')) +
                '<button type="button" class="awg-remove-btn" aria-label="' + escHtml(T('TITLE_PF_DELETE')) + '" title="' + escHtml(T('TITLE_PF_DELETE')) + '" onclick="pfDelete(' + n + ');"' + dis + '>' + trash + '</button>' +
            '</span>' +
        '</div>';
    }
    var fwChecked = (custom_settings.awg_failover == '1') ? ' checked' : '';
    html += '<div style="display:flex; align-items:center; flex-wrap:wrap; gap:14px; margin-top:5px;">' +
        '<input type="button" class="button_gen" style="font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;" value="' + escHtml(T('BTN_PF_ADD')) + '" onclick="pfAdd();"' + ((used >= AWG_PF_MAX || busy) ? ' disabled' : '') + '>' +
        '<label style="font-size:12px; cursor:pointer;"><input type="checkbox" id="awg_failover"' + fwChecked + ' onchange="pfUpdateDirtyHint();"' + dis + '> <span style="color:#FFCC00;">' + escHtml(T('LBL_PF_FAILOVER')) + '</span></label>' +
        '</div>' +
        '<div id="awg_pf_msg" class="awg-hint" style="color:#5cb85c;' + (awgPfBarMsg ? '' : ' display:none;') + '">' + escHtml(awgPfBarMsg) + '</div>' +
        '<div id="awg_pf_dirty" class="awg-hint" style="color:#FFCC00; display:none;">' + escHtml(T('HINT_PF_UNSAVED')) + '</div>' +
        '<div class="awg-hint">' + escHtml(T('HINT_PF_BAR')) + ' ' + escHtml(T('HINT_PF_FAILOVER')) + '</div>';
    bar.innerHTML = html;
    awgPfRenderSeq++;
    awgPfBarBusyRender = busy;
    pfUpdateDirtyHint();
}
// Disable the bar's controls while a save holds the form, and give them back afterwards. A bar
// re-rendered during the save (noHarvest only — pfDelete's own) was already drawn disabled
// (pfRenderBar) — it is simply redrawn.
function pfBarLock(on){
    var bar = document.getElementById('awg_pf_bar'), i;
    if(on){
        awgPfBarLocked = [];
        awgPfBarBusyRender = false;
        if(!bar || !bar.querySelectorAll) return;
        var els = bar.querySelectorAll('input, button');
        for(i = 0; i < els.length; i++){ awgPfBarLocked.push([els[i], els[i].disabled]); els[i].disabled = true; }
        return;
    }
    var list = awgPfBarLocked;
    awgPfBarLocked = [];
    if(awgPfBarBusyRender){ awgPfBarBusyRender = false; pfRenderBar(true); return; }
    for(i = 0; i < list.length; i++) list[i][0].disabled = list[i][1];
}
// The bar's own status line; a success note clears itself after a few seconds.
function pfSetBarMsg(msg){
    awgPfBarMsg = msg || '';
    if(awgPfBarMsgTimer){ clearTimeout(awgPfBarMsgTimer); awgPfBarMsgTimer = null; }
    var el = document.getElementById('awg_pf_msg');
    if(el){ el.textContent = awgPfBarMsg; el.style.display = awgPfBarMsg ? '' : 'none'; }
    if(awgPfBarMsg && awgPfBarMsg === T('LBL_PF_DELETED'))
        awgPfBarMsgTimer = setTimeout(function(){ pfSetBarMsg(''); }, 5000);
}
// P9: are there profile-list edits — names, per-slot failover flags, the global toggle, a pending
// delete — that the store doesn't hold yet? Compared SEMANTICALLY with the base, as the firmware's
// reader shows it (an absent fo = on, an absent global toggle = off, a name decoded + sanitized),
// so an untouched page over a store that never had those keys stays quiet.
function pfBarDirty(){
    for(var n = 1; n <= AWG_PF_MAX; n++){
        var cb = pfConfiguredIn(awgCsBase, n), cm = pfConfigured(n);
        if(cb !== cm) return true;          // a pending delete (or a profile the store lacks)
        if(!cb) continue;                   // unconfigured on both sides: its meta is noise
        var ne = document.getElementById('awg_pf_name_' + n);
        var nm = pfNameSan(ne ? ne.value : pfNameDec(awgCsNorm(custom_settings[pfKey(n, 'name')]) || ''));
        if(nm !== pfNameSan(pfNameDec(awgCsNorm(awgCsBase[pfKey(n, 'name')]) || ''))) return true;
        var fe = document.getElementById('awg_pf_fo_' + n);
        var fo = fe ? !!fe.checked : (awgCsNorm(custom_settings[pfKey(n, 'fo')]) !== '0');
        if(fo !== (awgCsNorm(awgCsBase[pfKey(n, 'fo')]) !== '0')) return true;
    }
    var fw = document.getElementById('awg_failover');
    var fv = fw ? !!fw.checked : (awgCsNorm(custom_settings.awg_failover) === '1');
    return fv !== (awgCsNorm(awgCsBase.awg_failover) === '1');
}
function pfUpdateDirtyHint(){
    var el = document.getElementById('awg_pf_dirty');
    if(el) el.style.display = pfBarDirty() ? '' : 'none';
}

// Re-render only when the backend-reported active/auto pair changed — a blind re-render on
// every 5s status poll would eat the user's in-progress typing in the name inputs. During a save
// the render waits for the save's end (pfRenderBar), and the key stays old until it draws.
function pfRenderBarIfChanged(){
    var active = pfActiveNow();
    var auto = !!(awgPfStatus && awgPfStatus.auto);
    if((active + '|' + (auto ? 1 : 0)) !== awgPfRenderKey) pfRenderBar();
}

function pfSelect(n){
    if(n === awgPfSel || awgFormBusy()) return;
    if(pfFormSerialize() !== awgPfSnapshot && !confirm(T('MSG_PF_UNSAVED', pfName(awgPfSel)))) return;
    awgPfSel = n;
    pfLoadForm(n);
}

function pfAdd(){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    // Append (C5): the first free slot AFTER the highest configured one, so the new profile is
    // numbered last and no existing #k shifts; the lowest free slot only when the tail is full.
    var hi = 0, free = 0, n;
    for(n = 1; n <= AWG_PF_MAX; n++){ if(pfConfigured(n)) hi = n; }
    if(hi < AWG_PF_MAX) free = hi + 1;
    else { for(n = 1; n <= AWG_PF_MAX; n++){ if(!pfConfigured(n)){ free = n; break; } } }
    if(!free){ alert(T('MSG_PF_FULL', AWG_PF_MAX)); return; }
    // An unconfigured slot holds nothing worth keeping — but a pre-1.5.26 store may still carry a
    // deleted profile's name/fo there, which the new profile would silently inherit (D3).
    if(free !== awgPfSel) pfWipeSlot(free);
    pfSelect(free);
    if(awgPfSel === free) importConfig();   // selection may have been cancelled (unsaved edits)
}

// Delete = IMMEDIATE (1.5.26): its own settings save (event awgpfsave — the backend only logs it,
// the tunnel is not restarted), so a delete can't sit unnoticed until some later Apply, and a
// reload can't bring the profile back. Pending per-slot names / failover flags ride along; the
// global failover toggle and every other unapplied edit do not.
function pfDelete(n){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    var ls = awgLastStatus;
    if(awgTransitionActive || (ls && (ls.starting || ls.stopping))){ alert(T('MSG_PF_WAIT_TRANSITION')); return; }
    var act = pfActiveNow();
    if(n === act){ alert(T('MSG_PF_DEL_ACTIVE')); return; }
    // Under a failover override the USER's primary is not the running slot, yet deleting it
    // would leave the pointer on an empty slot (D6). Only a profile that exists (here or in the
    // store) can be the primary — the unsaved new row must always reach its discard below.
    if((pfConfigured(n) || pfConfiguredIn(awgCsBase, n)) &&
       ((n === pfUser() && pfUser() !== act) || (awgPfStatus && n === awgPfStatus.user && awgPfStatus.user !== act))){
        alert(T('MSG_PF_DEL_PRIMARY'));
        return;
    }
    // The unsaved new row: nothing of it is on the router — just drop it here.
    if(!pfConfigured(n) && !pfConfiguredIn(awgCsBase, n)){
        if(!confirm(T('MSG_PF_DISCARD_NEW', pfName(n)))) return;
        pfWipeSlot(n);
        if(n === awgPfSel){ awgPfSel = act; pfLoadForm(awgPfSel); } else pfRenderBar();
        return;
    }
    if(!confirm(T('MSG_PF_DELETE_CONFIRM', pfName(n)))) return;
    // Everything typed in the bar goes into the model (the global toggle stays PENDING there —
    // fixFinal below keeps it out of this POST, and the redraw after the save keeps showing it).
    pfHarvestBar();
    var snap = awgSettingsSnapshot();
    var wasSel = (n === awgPfSel);
    pfWipeSlot(n);
    var started = awgSave({
        mode: 'normal', check: 'full', action: 'start_awgpfsave',
        // The global failover toggle is NOT part of a delete: post the stored value (the model
        // keeps the pending one for the next Apply).
        fixFinal: function(f){
            if(awgCsBase.hasOwnProperty('awg_failover')) f.awg_failover = awgCsBase.awg_failover;
            else delete f.awg_failover;
        },
        done: function(res, info){
            var stands = (res === 'verified' || res === 'verified-late' || res === 'unverified' ||
                          res === 'unknown' || res === 'truncated' || res === 'overflow');
            if(!stands){
                awgSettingsRestore(snap);
                pfSetBarMsg('');
                pfRenderBar(true);
                awgSaveNotify(res, info, T('TAIL_DELETE'));
                return;
            }
            // The deletion stands — saved, or (overflow) PENDING in the model for the next Apply,
            // which the P9 hint keeps visible. The pointer must still name a configured slot (K13,
            // as at load — the guards above keep this a no-op). A deleted edited slot hands the form
            // to the running profile, so the next Apply can't store the deleted fields back.
            pfUserFix();
            if(wasSel){ awgPfSel = pfActiveNow(); pfLoadForm(awgPfSel); }
            var ok = (res === 'verified' || res === 'verified-late' || res === 'unverified');
            pfSetBarMsg(ok ? T('LBL_PF_DELETED') : '');
            pfRenderBar(true);
            updateFirstRun();
            if(res === 'overflow'){
                var o = info.ovf;
                // One value too long (o.key) or the whole object over 8 KB: either way the row is gone
                // here while the router still holds the profile — say so before the field's own text
                // (MSG_PF_DEL_PENDING_OVER's {0}/{1} are TOTAL bytes, so it can't carry a per-value cut).
                alert(o.key ? (T('MSG_PF_DEL_PENDING_KEY') + '\n\n' + awgOverflowMsg(o))
                            : (T('MSG_PF_DEL_PENDING_OVER', o.total, AWG_CS_TOTAL_MAX) + awgOverflowBreakdown(o.obj, o.live)));
            } else if(!ok) awgSaveNotify(res, info);
        }
    });
    if(!started){ awgSettingsRestore(snap); awgFormBusyRefuse(); return; }
    pfSetBarMsg(T('LBL_PF_DELETING'));
    pfRenderBar(true);   // the row is gone; drawn disabled while the save runs
}

// «Switch to» = one submit that persists everything (incl. the form's pending edits) with
// the new awg_profile_active and fires start_awgswitch<SLOT> → the backend restarts the tunnel on
// that slot (the slot rides the event, so a save the firmware discarded or another writer
// overwrote can't restart the CURRENT profile instead). applyConfig sets the pointer inside its
// own snapshot, so any refusal rolls it back; the transition starts only once the save landed.
function pfSwitch(n){
    if(!pfConfigured(n)) return;
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    var ls = awgLastStatus;
    if(awgTransitionActive || (ls && (ls.starting || ls.stopping || ls.geo_busy))){ alert(T('MSG_PF_SWITCH_BUSY')); return; }
    if(!confirm(T('MSG_PF_SWITCH_CONFIRM', pfName(n)))) return;
    applyConfig('start_awgswitch', { switchTo: n });
}

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
    // Orphan meta (D3): a ≤1.5.25 delete could leave a slot's name/fo behind, and a profile added
    // to that slot later inherited the old name. Drop it from the MODEL (right after the legacy
    // carry-forward above, which can make slot 1 configured) — the base keeps it, so the next save
    // removes it from the store without reading as a conflict.
    for(var on = 1; on <= AWG_PF_MAX; on++){
        if(!pfConfigured(on)){ delete custom_settings[pfKey(on, 'name')]; delete custom_settings[pfKey(on, 'fo')]; }
    }
    // A pointer at an empty slot follows the backend's K13 fallback (after the carry-forward and
    // the sweep above, which decide what is configured; before the form picks its slot from it).
    pfUserFix();
    // Config form = the user's chosen profile slot (I1-I5 reassembly from the slot's chunked
    // initdata happens inside pfLoadForm; the profile bar renders there too).
    awgPfSel = pfUser();
    pfLoadForm(awgPfSel);
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
// Idempotent: the button's own label is remembered only on the first busy call, so «Checking…»
// (the live-store read) followed by «Applying…» (the POST) still restores «Apply» at the end.
function awgSetApplyBusy(busy, label){
    var b = awgApplyBtns();
    for(var i = 0; i < b.length; i++){
        b[i].disabled = busy;
        if(busy){
            if(!b[i]._awgBusy){ b[i]._lbl = b[i].value; b[i]._awgBusy = true; }
            b[i].value = label || T('BTN_APPLYING');
        } else if(b[i]._awgBusy){ b[i].value = b[i]._lbl; b[i]._awgBusy = false; }
    }
}
// awgSave busyUI for the Apply family (Apply / Save and restart / Switch to).
function awgApplyBusyUI(phase){
    if(phase === 'check') awgSetApplyBusy(true, T('BTN_CHECKING'));
    else if(phase === 'idle') awgSetApplyBusy(false);
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
    // The Start button follows the ACTIVE profile (what do_start will actually run) — while
    // editing an empty "new profile" slot the active one may be perfectly startable, and
    // vice versa a filled form doesn't make an unconfigured active slot runnable until Apply.
    var activeOk = pfConfigured(pfActiveNow()) || (awgPfSel === pfActiveNow() && !empty);
    var sb = document.getElementById('btn_start');
    if(sb){ sb.disabled = !activeOk; sb.title = !activeOk ? T('TITLE_IMPORT_FIRST') : ''; }
}

// o.switchTo: «Switch to» that slot (the pointer is set inside the snapshot, so every refusal
// rolls it back; the action becomes start_awgswitch<slot>).
function applyConfig(actionScript, o){
    o = o || {};
    if(awgFormBusy()){ awgFormBusyRefuse(true); return false; }
    var sw = o.switchTo || 0;
    // The bar's typed values go into the model first — exactly what any bar re-render does — so
    // a refused save rolls back to a model that still holds them (the bar is redrawn from it).
    pfHarvestBar();
    // Every refusal below rolls custom_settings back to this snapshot (awgSettingsSnapshot).
    var snap = awgSettingsSnapshot(), pfSnap = awgPfSnapshot, ptrAuto = awgPfPtrAuto;
    var wdEl = document.getElementById('awg_wd_hint');
    var wdPrev = (wdEl && wdEl.style.display !== 'none') ? (wdEl.textContent || '') : '';
    // Every restore also redraws the bar FROM the restored model (noHarvest): pfStoreForm's
    // empty-form wipe clears that slot's name input, and a refusal that left the blank input on
    // screen let the next harvesting render delete the name the rollback had just brought back.
    // The model was harvested before the snapshot, so typed bar values survive this redraw. The
    // pointer's provenance goes back with the pointer (pfUserFix below may have repaired it).
    function rollback(){ awgSettingsRestore(snap); awgPfSnapshot = pfSnap; awgPfPtrAuto = ptrAuto; pfRenderBar(true); updateFirstRun(); }
    // «Switch to» the row whose form was just emptied: its row still looks configured, but
    // pfStoreForm would read the empty form as a delete — the click would wipe the profile and
    // point the store at an empty slot. Refused before anything is touched (the target must be a
    // profile that exists: pfSwitch checked the model, and only the edited slot can be wiped).
    if(sw && sw === awgPfSel && pfFormEmpty()){
        awgFlagField('awg_iface_p1', T('MSG_PF_SWITCH_EMPTY', pfName(sw)));
        return false;
    }
    // Serialize the config form into the profile slot it edits (field validation + the
    // per-slot chunked I1-I5 initdata live inside; a blocked save also blocks the submit).
    if(!pfStoreForm(awgPfSel)){ rollback(); return false; }
    // Profile bar state (names, per-slot failover flags, the global toggle) rides along; again
    // after pfStoreForm, whose empty-form wipe clears that slot's name input.
    pfHarvestBar();

    // Save default policy and clients
    custom_settings.awg_default_policy = document.getElementById('default_policy').value;
    custom_settings.awg_clients = serializeClients();

    // Save geo settings PER POLICY (GeoIP/GeoSite/GeoCustom/Antifilter for each tab) into the
    // legacy unsuffixed keys (id 1) / id-suffixed keys (id>=2), plus the awg_geo_policies
    // registry. geoSerializePolicies captures the visible tab first and validates the files
    // budget; bail (no submit) if it's exceeded.
    if(!geoSerializePolicies()){ rollback(); return false; }
    custom_settings.awg_geo_autoupdate = document.getElementById('geo_autoupdate').checked ? '1' : '0';
    custom_settings.awg_block_ipv6_dns = document.getElementById('awg_block_ipv6_dns').checked ? '1' : '0';
    custom_settings.awg_no_dns_intercept = document.getElementById('awg_no_dns_intercept').checked ? '1' : '0';
    custom_settings.awg_killswitch = document.getElementById('awg_killswitch').checked ? '1' : '0';
    custom_settings.awg_tunnel_dns = document.getElementById('awg_tunnel_dns').checked ? '1' : '0';
    var _as = document.getElementById('awg_autostart');
    if(_as) custom_settings.awg_autostart = _as.checked ? '1' : '0';
    var _wfa = document.getElementById('awg_wait_for_agh');
    if(_wfa) custom_settings.awg_wait_for_agh = _wfa.checked ? '1' : '0';
    var _sd = document.getElementById('awg_start_delay');
    if(_sd){ var _sdv = parseInt(_sd.value, 10); custom_settings.awg_start_delay = (isNaN(_sdv) || _sdv < 0) ? '0' : String(Math.min(_sdv, 300)); }
    // Watchdog probe hosts: token-filter to what the probe accepts (IPv4/hostname). The old
    // char-level strip mangled an IPv6 into a fake all-digit "hostname" (2606:4700::1111 ->
    // "2606470047001111") that persisted and wasted a probe slot; drop such tokens whole.
    // COMMA-joined, like awg_dns/awg_address: Merlin stores the value fine but truncates it
    // at the first space when the page reads it back, so a space-joined "1.1.1.1 1.0.0.1"
    // came back as "1.1.1.1" after a reload — and the next Apply persisted the loss.
    custom_settings.awg_watchdog_hosts = document.getElementById('awg_watchdog_hosts').value
        .split(/[\s,]+/).filter(function(h){ return /^[0-9A-Za-z][0-9A-Za-z.-]*$/.test(h); }).join(',');
    custom_settings.awg_geo_wipe_update = document.getElementById('awg_geo_wipe_update').checked ? '1' : '0';
    // ipset name — sanitize to a valid set name (letters/digits/_.-, <=31); empty => backend uses awg_dst
    custom_settings.awg_ipset_name = document.getElementById('awg_ipset_name').value.replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 31);
    // Download-via-VPN toggles (route geo / program-update downloads through the tunnel)
    custom_settings.awg_geo_via_awg = document.getElementById('awg_geo_via_awg').checked ? '1' : '0';
    custom_settings.awg_update_via_awg = document.getElementById('awg_update_via_awg').checked ? '1' : '0';
    // (Antifilter lists are saved per-policy by geoSerializePolicies above.)
    // (Per-field validation of the config form ran inside pfStoreForm above.)
    // Not a switch: the pointer must still name a configured slot (K13 — an empty-form wipe may
    // have emptied the one it names; inside the snapshot, so a refusal rolls this back too).
    if(sw) custom_settings.awg_profile_active = String(sw);
    else pfUserFix();

    // Post through the save pipeline (awgSave): live-store conflict check, the store-limit guard
    // on the object the firmware would really receive (the firmware silently cuts any value over
    // ~3000 bytes and discards the WHOLE save over 8192 bytes — see AWG_CS_*), then a read-back
    // that says whether the save landed. The Apply buttons stay disabled meanwhile so an
    // impatient second tap can't queue a redundant firewall rebuild / tunnel restart.
    var isForce = (actionScript === 'start_awgforceapply');
    var swConn;
    var started = awgSave({
        mode: 'normal', check: 'full',
        // The switch target rides as an extra too: a LEGACY save lets an untouched pointer follow
        // the backend's user (awgCsBuildFinal) — for a switch that would post the CURRENT profile
        // and the backend would refuse start_awgswitch<N> as «did not reach the store».
        extra: sw ? { awg_profile_active: String(sw) } : null,
        action: sw ? ('start_awgswitch' + sw) : actionScript,
        busyUI: awgApplyBusyUI,
        onSubmit: function(){
            awgSetApplyBusy(true);
            awgWdHint('');   // the "press Apply to save" note is fulfilled by this very submit
            // Sync the header icon. «Применить» (awgsaveconf) only rebuilds the firewall — no
            // tunnel cycle — so a light fast-probe suffices; «Сохранить и перезапустить» really
            // does do_stop; do_start. A switch signals only once its save has landed (done).
            if(sw) swConn = awgLastStatus ? awgLastStatus.conn_start : undefined;
            else awgSignalWidget(isForce ? 'restart' : 'refresh');
        },
        done: function(res, info){
            awgSetApplyBusy(false);
            var landed = (res === 'verified' || res === 'verified-late' || res === 'unverified');
            if(!landed && res !== 'unknown' && res !== 'truncated'){
                rollback();   // bar + first-run redrawn inside
                if(wdPrev) awgWdHint(wdPrev);
                awgSaveNotify(res, info, sw ? T('TAIL_SWITCH') : (isForce ? T('TAIL_FORCEAPPLY') : ''));
                return;
            }
            // The model now equals what was written (awgSave): redraw the bar from it — a profile
            // saved just now gets its «Switch to» (D8).
            pfRenderBar(true);
            updateFirstRun();
            if(sw && res !== 'truncated'){
                // The pointer is in the store: show the target in the form and follow the switch
                // in the guarded transition (P13 — it resolves on the NEW connection only, and
                // reports a switch the busy router skipped). The form stayed editable during the
                // flight, and pfStoreForm froze awgPfSnapshot at entry: anything typed since is
                // unsaved, so the reload asks first (as pfSelect does). A form already on the target
                // shows what was just stored — nothing to reload, the late edits stay dirty-armed.
                // Declining keeps the old slot's edits in the form; the switch itself stands.
                if(awgPfSel !== sw &&
                   (pfFormSerialize() === awgPfSnapshot || confirm(T('MSG_PF_UNSAVED', pfName(awgPfSel))))){
                    awgPfSel = sw;
                    pfLoadForm(sw);
                }
                awgSignalWidget('restart');
                awgEnterTransition('restart', { n: sw, cs: swConn, t0: Date.now() });
            }
            if(res === 'unknown' || res === 'truncated'){ awgSaveNotify(res, info); return; }
            awgShowAck((res === 'verified-late' && !sw) ? T('ACK_SAVED_BUSY') : T('ACK_SAVED'), true);
        }
    });
    if(!started){ rollback(); awgFormBusyRefuse(true); return false; }
    // No full-page reload: status + log refresh live via polling. Reloading after a
    // form POST makes the browser prompt to resubmit the form ("resubmit form").
    return true;
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
    // The rows now hold what survived (partial line already dropped at render): nothing is "cut" anymore.
    p.filesCut = p.excFilesCut = p.urlsCut = p.excUrlsCut = false;
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
    loadGeoFiles(p.files, '', p.filesCut);
    loadGeoUrls(p.urls, '', p.urlsCut);
    var sel = (p.antifilter || '').split(','), boxes = document.querySelectorAll('.af_list');
    for(var i=0;i<boxes.length;i++) boxes[i].checked = sel.indexOf(boxes[i].value) !== -1;
    // Mode (include/exclude) + exclusions block.
    var mode = (p.mode === 'direct') ? 'direct' : 'vpn';
    var mr = document.querySelector('input[name="geo_mode"][value="' + mode + '"]');
    if(mr) mr.checked = true;
    set('geo_exc_domains', p.excDomains);
    set('geo_exc_ips', p.excIps);
    loadGeoFiles(p.excFiles, 'exc', p.excFilesCut);
    loadGeoUrls(p.excUrls, 'exc', p.excUrlsCut);
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
        var vip = (custom_settings[geoKeyJs(pid,'v2fly_ip')] || '').replace(/["']/g, '');
        geoPolicies.push({
            id: pid,
            name: list[k].name || encodeURIComponent(pid === 1 ? T('GEO_TAB_DEFAULT') : T('GEO_TAB_DEFAULT_NAME', pid)),
            // Quote-strip: settings saved while the v2fly categories list carried quotes
            // (2026-07 upstream format change) hold `"xai","youtube"` — clean them at load so
            // the panel displays clean names and the next Apply persists clean values.
            v2fly: (custom_settings[geoKeyJs(pid,'v2fly')] || '').replace(/["']/g, ''),
            v2flyIp: vip,
            customDomains: custom_settings[geoKeyJs(pid,'custom_domains')] || '',
            customIps: custom_settings[geoKeyJs(pid,'custom_ips')] || '',
            files: custom_settings[geoKeyJs(pid,'custom_files')] || '',
            urls: geoNormUrlsB64(custom_settings[geoKeyJs(pid,'custom_urls')] || ''),
            // The firmware reader returns at most 2999 bytes of a value: at that length it was cut.
            filesCut: (custom_settings[geoKeyJs(pid,'custom_files')] || '').length >= 2999,
            urlsCut: (custom_settings[geoKeyJs(pid,'custom_urls')] || '').length >= 2999,
            excFilesCut: (custom_settings[geoKeyJs(pid,'exc_files')] || '').length >= 2999,
            excUrlsCut: (custom_settings[geoKeyJs(pid,'exc_urls')] || '').length >= 2999,
            antifilter: custom_settings[geoKeyJs(pid,'antifilter_lists')] || '',
            mode: (custom_settings[geoKeyJs(pid,'mode')] === 'direct') ? 'direct' : 'vpn',
            excDomains: custom_settings[geoKeyJs(pid,'exc_domains')] || '',
            excIps: custom_settings[geoKeyJs(pid,'exc_ips')] || '',
            excFiles: custom_settings[geoKeyJs(pid,'exc_files')] || '',
            excUrls: geoNormUrlsB64(custom_settings[geoKeyJs(pid,'exc_urls')] || '')
        });
    }
    geoActiveIdx = 0;
}
// First URL in a stored custom_urls/exc_urls value (base64 of \n-joined URLs) that the backend
// would ignore — it fetches only http(s):// links — or '' when all are fine.
function geoBadUrl(b64){
    var txt = '';
    try { txt = decodeURIComponent(escape(atob(b64 || ''))); } catch(e){ return ''; }
    var a = txt.split('\n');
    for(var i = 0; i < a.length; i++){
        var u = a[i].replace(/\s+/g, '');
        if(u && !/^https?:\/\/([^\/?#@]*@)?([A-Za-z0-9._~%-]+|\[[0-9A-Fa-f:.]+\])(:\d+)?([\/?#]|$)/.test(u)) return u;
    }
    return '';
}
// Normalize one URL the way the backend fetches (lowercase http(s):// scheme): "HTTPS://x" is
// lowercased and a bare "example.com/list.txt" (or host:port/...) gets https://. Anything else
// that looks like a scheme or a local path — "mailto:", "C:\…", "http:/x" — is left as typed so
// geoBadUrl names it instead of it turning into a bogus https:// "host".
function geoNormUrl(u){
    u = String(u || '').replace(/\s+/g, '');
    if(!u) return '';
    var sm = /^([a-z][a-z0-9+.-]*):\/\//i.exec(u);
    if(sm) return sm[1].toLowerCase() + u.slice(sm[1].length);
    if(/^[a-z][a-z0-9+.-]*:(?!\d)/i.test(u) || u.indexOf('\\') !== -1) return u;
    return 'https://' + u.replace(/^\/+/, '');
}
// geoNormUrl over a stored custom_urls/exc_urls value (base64 of \n-joined URLs), so a legacy
// "HTTPS://…" on a tab that is never opened is not refused as bad on the next Apply.
function geoNormUrlsB64(b64){
    if(!b64) return '';
    var txt;
    try { txt = decodeURIComponent(escape(atob(b64))); } catch(e){ return b64; }
    var a = txt.split('\n'), out = [], ch = false;
    for(var i = 0; i < a.length; i++){
        var n = geoNormUrl(a[i]);
        if(n !== a[i]) ch = true;
        if(n) out.push(n);
    }
    if(!ch) return b64;
    try { return btoa(unescape(encodeURIComponent(out.join('\n')))); } catch(e){ return b64; }
}
// Serialize geoPolicies[] back into custom_settings; returns false (after telling the user and
// showing the offending tab) when a policy's files can't fit the firmware store or a URL is bad.
function geoSerializePolicies(){
    geoCaptureActive();
    var gp, p, suf, si, bad;
    var sufs = ['v2fly','v2fly_ip','custom_domains','custom_ips','custom_files','custom_urls','antifilter_lists',
                'mode','exc_domains','exc_ips','exc_files','exc_urls'];
    // Files are stored as ONE settings value per tab and channel, and the firmware cuts a value
    // at ~3000 bytes (see AWG_CS_*): refuse here, naming the tab, instead of saving a list that
    // comes back cut mid-line (the pre-1.5.24 «files don't save» report).
    for(gp=0; gp<geoPolicies.length; gp++){
        p = geoPolicies[gp];
        var fl = [[p.files, ''], [p.excFiles, T('GEO_FILES_EXC_SUFFIX')]];
        for(si=0; si<fl.length; si++){
            var n = awgUtf8Len(fl[si][0] || '');
            if(n > AWG_CS_VALUE_MAX){
                if(gp !== geoActiveIdx) geoSwitchTo(gp);
                alert(T('MSG_GEO_FILES_TOO_BIG', fl[si][1], geoDecodeName(p.name), n, AWG_CS_VALUE_MAX));
                return false;
            }
        }
        bad = geoBadUrl(p.urls) || geoBadUrl(p.excUrls);
        if(bad){
            if(gp !== geoActiveIdx) geoSwitchTo(gp);
            alert(T(/^https?:\/\/[^\/?#]*[^\x00-\x7f]/.test(bad) ? 'MSG_GEO_URL_IDN' : 'MSG_GEO_URL_BAD', geoDecodeName(p.name), bad));
            return false;
        }
    }
    // Empty fields are deleted rather than stored as '' (the page never reads an empty value back,
    // the backend treats empty == missing, and every byte counts against the shared 8 KB cap);
    // mode 'vpn' is the default on both sides, so only 'direct' is stored.
    var put = function(k, v){ if(v) custom_settings[k] = v; else delete custom_settings[k]; };
    for(gp=0; gp<geoPolicies.length; gp++){
        p = geoPolicies[gp];
        put(geoKeyJs(p.id,'v2fly'), p.v2fly);
        put(geoKeyJs(p.id,'v2fly_ip'), p.v2flyIp);
        put(geoKeyJs(p.id,'custom_domains'), p.customDomains);
        put(geoKeyJs(p.id,'custom_ips'), p.customIps);
        put(geoKeyJs(p.id,'custom_files'), p.files);
        put(geoKeyJs(p.id,'custom_urls'), p.urls);
        put(geoKeyJs(p.id,'antifilter_lists'), p.antifilter);
        put(geoKeyJs(p.id,'mode'), (p.mode === 'direct') ? 'direct' : '');
        put(geoKeyJs(p.id,'exc_domains'), p.excDomains);
        put(geoKeyJs(p.id,'exc_ips'), p.excIps);
        put(geoKeyJs(p.id,'exc_files'), p.excFiles);
        put(geoKeyJs(p.id,'exc_urls'), p.excUrls);
    }
    custom_settings.awg_geo_policies = geoPolicies.map(function(x){ return x.id + ':' + x.name; }).join(';');
    // Free the settings budget: drop the keys of policies that existed at load but were removed.
    for(var li=0; li<geoLoadedIds.length; li++){
        var oid = geoLoadedIds[li];
        if(geoPolicyIndexById(oid) === -1){
            for(si=0; si<sufs.length; si++) delete custom_settings[geoKeyJs(oid,sufs[si])];
        }
    }
    // The whole-store limits (other long fields, the 8 KB total) are checked by the callers right
    // before they POST, once every other setting has been folded in (awgSettingsOverflow).
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
    var tdns = document.getElementById('awg_tunnel_dns');
    if(tdns) tdns.checked = (custom_settings.awg_tunnel_dns === '1');
    // Autostart after reboot (default ON — absent/1 = start, the pre-1.2.52 behavior; the
    // boot gate itself lives in the S99 init script -> `amneziawg.sh boot_start`).
    var asb = document.getElementById('awg_autostart');
    if(asb) asb.checked = (custom_settings.awg_autostart !== '0');
    // Wait-for-AdGuardHome on autostart (only meaningful/visible on AGH boxes; default off).
    var wfa = document.getElementById('awg_wait_for_agh');
    if(wfa) wfa.checked = (custom_settings.awg_wait_for_agh === '1');
    var sd = document.getElementById('awg_start_delay');
    if(sd) sd.value = (custom_settings.awg_start_delay && custom_settings.awg_start_delay !== '0') ? custom_settings.awg_start_delay : '';
    // Watchdog probe hosts (empty = backend default 8.8.8.8 1.1.1.1). Stored comma-joined
    // (spaces don't survive the settings read-back); shown space-separated like the placeholder.
    var wh = document.getElementById('awg_watchdog_hosts');
    if(wh) wh.value = (custom_settings.awg_watchdog_hosts || '').replace(/,/g, ' ');
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
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
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
    var snap = awgSettingsSnapshot();
    // Capture the geo policies (incl. a just-added tab + unsaved active-tab edits) into
    // custom_settings, so the backend downloads the CURRENT matrix, not the last-Applied one.
    if(!geoSerializePolicies()){ awgSettingsRestore(snap); return; }
    // Carry the current "download via VPN" choice even without a prior Apply.
    syncViaVpnToggles();
    // A normal settings save (awgSave): same store-limit guard and live-store check as Apply — an
    // over-limit POST is discarded whole by the firmware, and the backend would then download the
    // PREVIOUS matrix while the page claims the new one.
    var log = document.getElementById('awg_log');
    var logPrev = log ? log.textContent : '';
    var started = awgSave({
        mode: 'normal', check: 'full', action: 'start_awgupdategeo',
        busyUI: awgBtnBusyUI(btn),
        onSubmit: function(){
            if(log) log.textContent = T('MSG_GEO_LOADING_WAIT');
            awgSetGeoBusy(true);
        },
        done: function(res, info){
            if(res === 'verified' || res === 'unverified') return;
            if(res === 'verified-late'){ awgShowAck(T('ACK_SAVED_BUSY'), true); return; }
            if(res === 'unknown' || res === 'truncated'){ awgSaveNotify(res, info); return; }
            // Not saved. The model goes back; the geo tabs keep the edits for the next Apply. No bar
            // redraw: this path never harvested the bar, so names / failover ticks typed but not yet
            // applied live only in its inputs — a noHarvest render would wipe them, and the restore
            // touches no bar key (a status-driven redraw asked for during the save runs once it has
            // ended, harvesting those inputs first — pfRenderBar).
            awgSettingsRestore(snap);
            // A discarded save still fired the event: the router IS downloading — the previously
            // saved lists — so the busy UI stays (updateStatusUI ends it on geo_busy=false).
            if(res === 'discarded'){ awgSaveNotify(res, info, T('TAIL_GEO')); return; }
            if(awgGeoBusy) awgSetGeoBusy(false);
            if(log && log.textContent === T('MSG_GEO_LOADING_WAIT')) log.textContent = logPrev;
            awgSaveNotify(res, info);
        }
    });
    if(!started){ awgSettingsRestore(snap); awgFormBusyRefuse(); }
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
    if(pollId === awgPoll){ awgPoll = null; awgTransitionActive = false; }
    setOfflineUI();
    if(!statusTimer) statusTimer = setInterval(awgRefreshStatus, 5000);
    awgRefreshStatus();
}
// True from awgEnterTransition until that transition resolves / recovers / is abandoned. The
// guards test THIS, never awgPoll (only the next transition ever reset that).
var awgTransitionActive = false;
// Leave a transition: hand the UI to the steady poll with this status.
function awgTransitionEnd(poll, s){
    clearInterval(poll);
    if(poll === awgPoll){ awgPoll = null; awgTransitionActive = false; }
    updateStatusUI(s);
    if(statusTimer) clearInterval(statusTimer);
    statusTimer = setInterval(awgRefreshStatus, 5000);
    document.getElementById('btn_start').disabled = false;
    document.getElementById('btn_stop').disabled = false;
    document.getElementById('btn_restart').disabled = false;
}

// A profile switch the router skipped or that failed (P13): a yellow note under the status, with
// «Retry the switch» for the skipped case — an EMPTY post of start_awgswitch<slot>: the pointer is
// already in the store, and the backend accepts the switch exactly when it is. (Never «Restart»:
// under a failover override a plain restart brings the backup profile back, not this one.)
var awgSwitchWarnSlot = 0, awgSwitchWarnConn = null;
function awgSwitchWarn(kind, n, s){
    var el = document.getElementById('awg_switch_warn');
    awgSwitchWarnSlot = kind ? n : 0;
    awgSwitchWarnConn = (kind && s) ? s.conn_start : null;
    if(!el) return;
    if(!kind){ el.style.display = 'none'; el.innerHTML = ''; return; }
    var html = escHtml(T(kind === 'skipped' ? 'MSG_SWITCH_SKIPPED' : 'MSG_SWITCH_FAILED'));
    if(kind === 'skipped')
        html += '<div style="margin-top:8px;"><input type="button" class="button_gen" value="' + escHtml(T('BTN_SWITCH_RETRY')) + '" onclick="awgRetrySwitch(' + n + ');"></div>';
    el.innerHTML = html;
    el.style.display = '';
}
function awgRetrySwitch(n){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    var ls = awgLastStatus;
    if(awgTransitionActive || (ls && (ls.starting || ls.stopping))){ alert(T('MSG_PF_SWITCH_BUSY')); return; }
    var cs = ls ? ls.conn_start : undefined;
    if(awgPostSettings('start_awgswitch' + n, false, null, function(){}) === false) return;
    awgSignalWidget('restart');
    awgEnterTransition('restart', { n: n, cs: cs, t0: Date.now() });
}

function awgAction(action){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    // Plain actions (start/stop/restart) carry NO settings: clear the hidden amng_custom, or
    // the submit would re-post the snapshot left there by the LAST settings flow — with
    // profiles that stale snapshot could silently revert an awg_profile_active switched
    // elsewhere (CLI/another tab) since that Apply. Empty = firmware writes nothing (the
    // page-load default; pre-first-Apply starts always posted it empty).
    var ac = document.getElementById('amng_custom');
    if(ac) ac.value = '';
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
// sw = { n: target slot, cs: conn_start before the switch, t0: when its save landed } turns it into
// a SWITCH transition (P13): the old tunnel still reads running=true until the backend gets to the
// switch — it may queue behind another lock holder for 30 s+ (switch_req says it is on its way) —
// so it resolves only on a NEW connection of the target profile. No phase at all for 45 s and the
// same connection = the busy router skipped it; a phase seen and then a steady non-resolved state
// for 4 s = it failed.
function awgEnterTransition(kind, sw){
    var badge = document.getElementById('awg_badge');
    var isStop = (kind === 'stop');
    var expect = !isStop;

    // Stop periodic refresh and any prior in-flight action poll
    if(statusTimer){ clearInterval(statusTimer); statusTimer = null; }
    if(awgPoll){ clearInterval(awgPoll); awgPoll = null; }
    awgTransitionActive = true;
    awgSwitchWarn('');
    var seen = false, steadySince = 0;
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

    // Show transitional status (uptime label hides with it — it belongs to the stable state)
    badge.className = 'awg-status connecting';
    badge.innerHTML = isStop ? ('&#9679; ' + escHtml(T('STAT_STOPPING'))) : ('&#9679; ' + escHtml(T('STAT_CONNECTING')));
    awgConnUp = false;
    awgTickUptime();

    // Poll until status is fully ready
    var attempts = 0;
    var poll = setInterval(function(){
        attempts++;
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/user/awg_status.htm?_=' + Date.now(), true);
        xhr.timeout = 3000;
        // A newer action superseded this poll — abandon it (the new action owns the UI).
        function superseded(){
            if(myGen === awgActionGen) return false;
            clearInterval(poll);
            if(poll === awgPoll){ awgPoll = null; awgTransitionActive = false; }
            return true;
        }
        xhr.onload = function(){
            if(superseded()) return;
            try {
                var s = JSON.parse(xhr.responseText);
                awgLastStatus = s;
                var ready;
                if(sw){
                    var phase = !!(s.starting || s.stopping || (s.switch_req > 0 && s.switch_req == sw.n));
                    if(phase) seen = true;
                    ready = !!(s.running && !s.starting && !s.stopping && String(s.conn_start) !== String(sw.cs) &&
                               s.profile && s.profile.user == sw.n);
                    if(!ready && !phase){
                        if(!seen && String(s.conn_start) === String(sw.cs) && Date.now() - sw.t0 >= 45000){
                            awgTransitionEnd(poll, s); awgSwitchWarn('skipped', sw.n, s); return;
                        }
                        if(seen){
                            if(!steadySince) steadySince = Date.now();
                            else if(Date.now() - steadySince >= 4000){ awgTransitionEnd(poll, s); awgSwitchWarn('failed', sw.n, s); return; }
                        }
                    } else steadySince = 0;
                } else {
                    // Resolve only when the backend reports the expected final state AND no
                    // transition flag is still set. The !starting/!stopping guard is what makes
                    // «Перезапустить» safe: a restart is do_stop→do_start, and the pre-teardown
                    // running=true (still === expect=true) would otherwise resolve us instantly,
                    // hand the UI to the steady poll, which then catches the brief fully-stopped
                    // moment and shows a clickable «Запустить».
                    ready = (s.running === expect && !s.starting && !s.stopping);
                }
                if(ready || attempts >= 90) awgTransitionEnd(poll, s);
            } catch(e){
                if(attempts >= 90){ awgActionRecover(poll); }
            }
        };
        xhr.onerror = function(){ if(superseded()) return; if(attempts >= 90){ awgActionRecover(poll); } };
        // Without an ontimeout, a router that only times out (typical while a half-started
        // tunnel is breaking routing/DNS) never reaches the attempts>=90 recovery and the
        // poll wedges forever — leaving the page stuck mid-transition. Mirror onerror.
        xhr.ontimeout = function(){ if(superseded()) return; if(attempts >= 90){ awgActionRecover(poll); } };
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
// Diagnostics: the "Get diagnostic data" button triggers the backend diag dump (to a SEPARATE
// file — it does NOT touch the on-page log), waits for [DIAG_DONE], and shows the result in a
// modal. The modal's "Copy diagnostic data" copies the diagnostics PLUS the
// current log, wrapped for Telegram — the copy happens inside the click, so it's reliable.
var awgDiagText = '';
function awgRunDiag(btn){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    if(btn){ if(btn._dlbl == null) btn._dlbl = btn.value; btn.value = T('DIAG_COLLECTING'); btn.disabled = true; }
    awgDiagText = '';
    awgOpenDiag(T('DIAG_COLLECTING_WAIT'));
    // Diag carries NO settings, so clear the hidden field rather than re-posting the page-load
    // snapshot (1.5.13). It used to do a "no-op save", which is not a no-op at all: the firmware
    // writes the whole object back, reverting anything changed since this page loaded (the
    // server page in another tab, a CLI profile switch). Same reasoning as awgAction above.
    var acd = document.getElementById('amng_custom');
    if(acd) acd.value = '';
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
// Start pins the device in awg_analyze_device — and ONLY that: an 'onlyExtra' save posts the live
// store plus this one key (never this page's unapplied edits). awgAnalyzeStarting spans the whole
// save; closing the modal meanwhile sets awgAnalyzeCancel (see awgCloseAnalyze): before the POST
// nothing is sent, after it the capture the router may already have started is stopped.
var awgAnalyzeStarting = false, awgAnalyzeCancel = false;
function awgAnalyzeStart(){
    if(!awgAnalyzeIp || awgAnalyzeStarting) return;
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    var ip = awgAnalyzeIp, submitted = false;
    awgAnalyzeCancel = false;
    awgAnalyzeStarting = true;
    var started = awgSave({
        mode: 'onlyExtra', check: 'total', extra: { awg_analyze_device: ip }, action: 'start_awganalyzestart',
        busyUI: awgBtnBusyUI(document.getElementById('awg_analyze_toggle')),
        abort: function(){ return awgAnalyzeCancel; },
        onSubmit: function(){
            submitted = true;
            awgAnalyzeActive = true;
            awgAnalyzeSetToggle(true);
            var rows = document.getElementById('awg_analyze_rows');
            if(rows) rows.innerHTML = '';
            awgAnalyzeShowEmpty(T('ANALYZE_WAITING'));
            if(awgAnalyzeTimer) clearInterval(awgAnalyzeTimer);
            awgAnalyzeTimer = setInterval(awgAnalyzePoll, 1500);
            setTimeout(awgAnalyzePoll, 700);
        },
        done: function(res, info){
            awgAnalyzeStarting = false;
            // Every post-submit result means the event may have fired on the router.
            if(awgAnalyzeCancel){ if(submitted) awgAnalyzeStopQuiet(); return; }
            if(res === 'verified-late'){ awgAnalyzeShowAck(T('ACK_SAVED_BUSY'), false); return; }
            if(res === 'verified' || res === 'unverified') return;
            if(res === 'unknown' || res === 'truncated'){ awgSaveNotify(res, info); return; }
            // A discarded save still fired the event — with the OLD stored device: stop that
            // capture at once, and show the analyzer as stopped.
            if(res === 'discarded') awgAnalyzeStopQuiet();
            awgSaveNotify(res, info, T('TAIL_ANALYZE'));
        }
    });
    if(!started){ awgAnalyzeStarting = false; awgFormBusyRefuse(); }
}
// Stop a capture the page no longer shows (an aborted / discarded start): an empty post, and the
// analyzer UI back to «stopped».
function awgAnalyzeStopQuiet(){
    awgPostSettings('start_awganalyzestop', false, null, function(){});
    awgAnalyzeActive = false;
    awgAnalyzeSetToggle(false);
    if(awgAnalyzeTimer){ clearInterval(awgAnalyzeTimer); awgAnalyzeTimer = null; }
}
function awgAnalyzeStop(){
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    // Stop carries no settings (unlike Start, which pins awg_analyze_device) — clear, don't
    // re-post the page-load snapshot. See awgAction / awgRunDiag (1.5.13).
    var aca = document.getElementById('amng_custom');
    if(aca) aca.value = '';
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
            '<td class="awg-an-owner" data-ip="' + escHtml(String(e.ip || '')) + '">' + awgOwnerCell(e.ip) + '</td>' +
            '<td><span class="awg-verdict ' + vi.cls + '">' + escHtml(vi.label) + '</span></td>' +
            '</tr>';
    }
    rows.innerHTML = html;
    awgAnalyzeSyncSelAll();
    awgOwnerResolveVisible();
}
// ---- IP → owner (ASN / org) resolution for the analyzer table ----
// Resolved in the admin's browser (NOT on the router) via a free CORS API (ipwho.is), cached per
// IP for the page's lifetime. Only public IPv4 destinations are looked up; private / LAN / reserved
// and IPv6 show "—". Cells carry data-ip, so a late reply patches every matching row even after the
// capture (and its polling) has stopped. Concurrency is capped to stay gentle with the free API.
var awgOwnerCache = {};      // ip -> {t:'ok',v,full} | {t:'err'} | {t:'pending'}
var awgOwnerQueue = [];
var awgOwnerInflight = 0;
var AWG_OWNER_MAX = 3;
var awgOwnerLsLoaded = false;
var awgAsnCount = {};        // asn -> IPv4 prefix count | 'pending' | -1 (errored)
var awgCountQueue = [];
var awgCountInflight = 0;
var AWG_COUNT_MAX = 2;
function awgOwnerIsPublic(ip){
    if(!ip || ip.indexOf(':') >= 0) return false;          // empty or IPv6 -> skip
    var p = ip.split('.'); if(p.length !== 4) return false;
    var a = +p[0], b = +p[1];
    if(a === 0 || a === 10 || a === 127) return false;
    if(a === 192 && b === 168) return false;
    if(a === 172 && b >= 16 && b <= 31) return false;
    if(a === 169 && b === 254) return false;
    if(a === 100 && b >= 64 && b <= 127) return false;     // CGNAT
    if(a >= 224) return false;                             // multicast / reserved
    return true;
}
function awgOwnerTrunc(s, n){ s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s; }
function awgOwnerCell(ip){
    if(!awgOwnerIsPublic(ip)) return '—';
    var c = awgOwnerCache[ip];
    if(c && c.t === 'ok'){
        var cnt = c.asn ? awgAsnCount[c.asn] : undefined;
        var ttl = c.full + ((typeof cnt === 'number' && cnt >= 0) ? ' · ' + T('OWNER_PFX', cnt) : '') + ' · ' + T('OWNER_CLICK_HINT');
        return '<span class="awg-own-link" title="' + escHtml(ttl) + '" onclick="awgOwnerClick(\'' + escHtml(ip) + '\', event)">' + escHtml(c.v) + '</span>';
    }
    if(c && c.t === 'err') return '<span style="color:#6b7480;">?</span>';
    return '<span style="color:#6b7480;">…</span>';        // pending / not requested yet
}
function awgOwnerResolveVisible(){
    if(!awgOwnerLsLoaded){ awgOwnerLsLoaded = true; awgOwnerLsLoad(); }
    var cells = document.querySelectorAll('#awg_analyze_rows .awg-an-owner');
    var seen = {};
    for(var i = 0; i < cells.length; i++){
        var ip = cells[i].getAttribute('data-ip');
        if(!ip || seen[ip] || !awgOwnerIsPublic(ip)) continue;
        seen[ip] = 1;
        var c = awgOwnerCache[ip];
        if(!c){ awgOwnerCache[ip] = { t: 'pending' }; awgOwnerQueue.push(ip); }
        else if(c.t === 'ok' && c.asn){ awgAsnCountResolve(c.asn); }   // seed the tooltip count for cached owners
    }
    awgOwnerPump();
}
function awgOwnerPump(){
    while(awgOwnerInflight < AWG_OWNER_MAX && awgOwnerQueue.length){
        awgOwnerFetch(awgOwnerQueue.shift());
    }
}
function awgOwnerFetch(ip){
    awgOwnerInflight++;
    var x = new XMLHttpRequest();
    x.open('GET', 'https://ipwho.is/' + encodeURIComponent(ip) + '?fields=success,connection,country_code', true);
    x.timeout = 8000;
    x.onload = function(){
        awgOwnerInflight--;
        var v = null, full = null, asn = 0;
        try {
            var d = JSON.parse(x.responseText);
            if(d && d.success !== false && d.connection){
                var org = d.connection.org || d.connection.isp || '';
                asn = d.connection.asn || 0;
                var asns = asn ? ('AS' + asn) : '';
                v = org || asns || null;
                if(v) full = ((asns ? asns + ' ' : '') + org + (d.country_code ? ' [' + d.country_code + ']' : '')).replace(/\s+$/, '');
            }
        } catch(e){}
        awgOwnerCache[ip] = v ? { t: 'ok', v: awgOwnerTrunc(v, 28), full: full || v, asn: asn, ts: Date.now() } : { t: 'err' };
        if(v){ awgOwnerLsSaveSoon(); if(asn) awgAsnCountResolve(asn); }
        awgOwnerApply(ip);
        awgOwnerPump();
    };
    x.onerror = x.ontimeout = function(){
        awgOwnerInflight--;
        awgOwnerCache[ip] = { t: 'err' };
        awgOwnerApply(ip);
        awgOwnerPump();
    };
    x.send();
}
function awgOwnerApply(ip){
    var cells = document.querySelectorAll('#awg_analyze_rows .awg-an-owner');
    for(var i = 0; i < cells.length; i++){
        if(cells[i].getAttribute('data-ip') === ip) cells[i].innerHTML = awgOwnerCell(ip);
    }
}
// Owner cache persistence in localStorage — owner/ASN is stable, so it survives page reloads (and
// the whole session). Only resolved ('ok') entries are stored, each with a timestamp; on load,
// entries older than the TTL are dropped and the rest seed awgOwnerCache so cells fill instantly.
var AWG_OWNER_LS = 'awg_owner_cache_v1';
var AWG_ASN_LS = 'awg_asn_count_v1';
var AWG_OWNER_TTL = 45 * 24 * 3600 * 1000;   // 45 days
var awgOwnerSaveTimer = null;
function awgOwnerLsLoad(){
    awgAsnLsLoad();
    try {
        var raw = localStorage.getItem(AWG_OWNER_LS); if(!raw) return;
        var o = JSON.parse(raw), now = Date.now();
        for(var ip in o){
            if(!o.hasOwnProperty(ip)) continue;
            var e = o[ip];
            if(e && e.v && e.ts && (now - e.ts) < AWG_OWNER_TTL && !awgOwnerCache[ip])
                awgOwnerCache[ip] = { t: 'ok', v: e.v, full: e.full || e.v, asn: e.asn || 0, ts: e.ts };
        }
    } catch(e){}
}
function awgOwnerLsSave(){
    try {
        var o = {}, n = 0;
        for(var ip in awgOwnerCache){
            if(!awgOwnerCache.hasOwnProperty(ip)) continue;
            var c = awgOwnerCache[ip];
            if(c && c.t === 'ok'){ o[ip] = { v: c.v, full: c.full, asn: c.asn || 0, ts: c.ts || Date.now() }; if(++n >= 3000) break; }
        }
        localStorage.setItem(AWG_OWNER_LS, JSON.stringify(o));
    } catch(e){}
}
function awgOwnerLsSaveSoon(){
    if(awgOwnerSaveTimer) return;
    awgOwnerSaveTimer = setTimeout(function(){ awgOwnerSaveTimer = null; awgOwnerLsSave(); awgAsnLsSave(); }, 1500);
}
// Click an owner -> add its network to the selected policy's custom IPs. Plain click adds the
// announced prefix that CONTAINS this IP (targeted — catches the provider's rotating IPs in that
// block, e.g. a CDN); Shift-click adds EVERY IPv4 prefix of the AS, behind a count confirm so an
// Amazon-scale AS can't be added by accident. Prefixes come from RIPEstat (browser-side, CORS).
function awgOwnerTargetPidx(){
    var picker = document.getElementById('awg_an_policy');
    var pid = picker ? parseInt(picker.value, 10) : NaN;
    return isNaN(pid) ? -1 : geoPolicyIndexById(pid);
}
function awgOwnerRipe(url, cb){
    var x = new XMLHttpRequest();
    x.open('GET', url, true);
    x.timeout = 12000;
    x.onload = function(){ var d = null; try { d = JSON.parse(x.responseText); } catch(e){} cb(d); };
    x.onerror = x.ontimeout = function(){ cb(null); };
    x.send();
}
function awgOwnerClick(ip, ev){
    if(ev && ev.stopPropagation) ev.stopPropagation();
    var c = awgOwnerCache[ip];
    if(!c || c.t !== 'ok') return;
    var pidx = awgOwnerTargetPidx();
    if(pidx === -1){ awgAnalyzeShowAck(T('ANALYZE_NEED_POLICY'), false); return; }
    if(ev && ev.shiftKey){
        if(!c.asn){ awgAnalyzeShowAck(T('OWNER_NO_ASN'), false); return; }
        awgAnalyzeShowAck(T('OWNER_LOOKING'), true);
        awgOwnerRipe('https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS' + encodeURIComponent(c.asn), function(d){
            var pfx = [], a = (d && d.data && d.data.prefixes) || [], i;
            for(i = 0; i < a.length; i++){ if(a[i].prefix && a[i].prefix.indexOf(':') < 0) pfx.push(a[i].prefix); }
            if(!pfx.length){ awgAnalyzeShowAck(T('OWNER_NO_PREFIX'), false); return; }
            if(!confirm(T('OWNER_CONFIRM_AS', c.v, 'AS' + c.asn, pfx.length))){ awgAnalyzeClearAck(); return; }
            var res = geoAddToPolicy(pidx, [], pfx);
            awgAnalyzeShowAck(T('OWNER_ADDED_AS', res.nIp, 'AS' + c.asn), true);
        });
    } else {
        awgAnalyzeShowAck(T('OWNER_LOOKING'), true);
        awgOwnerRipe('https://stat.ripe.net/data/network-info/data.json?resource=' + encodeURIComponent(ip), function(d){
            var cidr = (d && d.data && d.data.prefix) || '';
            if(!cidr){ awgAnalyzeShowAck(T('OWNER_NO_PREFIX'), false); return; }
            if(!confirm(T('OWNER_CONFIRM_NET', c.v, cidr))){ awgAnalyzeClearAck(); return; }
            var res = geoAddToPolicy(pidx, [], [cidr]);
            awgAnalyzeShowAck(T('OWNER_ADDED_NET', cidr, res.nIp), true);
        });
    }
}
// AS IPv4-prefix count for the owner tooltip — so the scale of an AS is visible BEFORE Shift-click
// (e.g. Amazon = 1000+ prefixes vs a small provider = a couple dozen). Cached per ASN (not per IP),
// persisted, throttled. Uses RIPEstat routing-status (a single summary number, not the full list).
function awgAsnCountResolve(asn){
    if(!asn || awgAsnCount[asn] !== undefined) return;
    awgAsnCount[asn] = 'pending';
    awgCountQueue.push(asn);
    awgCountPump();
}
function awgCountPump(){
    while(awgCountInflight < AWG_COUNT_MAX && awgCountQueue.length){
        awgCountFetch(awgCountQueue.shift());
    }
}
function awgCountFetch(asn){
    awgCountInflight++;
    var x = new XMLHttpRequest();
    x.open('GET', 'https://stat.ripe.net/data/routing-status/data.json?resource=AS' + encodeURIComponent(asn), true);
    x.timeout = 10000;
    x.onload = function(){
        awgCountInflight--;
        var n = null;
        try {
            var d = JSON.parse(x.responseText);
            if(d && d.data && d.data.announced_space && d.data.announced_space.v4 && typeof d.data.announced_space.v4.prefixes === 'number')
                n = d.data.announced_space.v4.prefixes;
        } catch(e){}
        awgAsnCount[asn] = (n === null) ? -1 : n;   // -1 = errored (kept, so we don't refetch every render)
        if(n !== null) awgOwnerLsSaveSoon();
        awgOwnerApplyAsn(asn);
        awgCountPump();
    };
    x.onerror = x.ontimeout = function(){
        awgCountInflight--;
        awgAsnCount[asn] = -1;
        awgCountPump();
    };
    x.send();
}
function awgOwnerApplyAsn(asn){
    var cells = document.querySelectorAll('#awg_analyze_rows .awg-an-owner');
    for(var i = 0; i < cells.length; i++){
        var ip = cells[i].getAttribute('data-ip'), c = awgOwnerCache[ip];
        if(c && c.t === 'ok' && c.asn === asn) cells[i].innerHTML = awgOwnerCell(ip);
    }
}
function awgAsnLsLoad(){
    try {
        var raw = localStorage.getItem(AWG_ASN_LS); if(!raw) return;
        var o = JSON.parse(raw), now = Date.now();
        for(var k in o){
            if(!o.hasOwnProperty(k)) continue;
            var e = o[k];
            if(e && typeof e.n === 'number' && e.n >= 0 && e.ts && (now - e.ts) < AWG_OWNER_TTL && awgAsnCount[k] === undefined)
                awgAsnCount[k] = e.n;
        }
    } catch(e){}
}
function awgAsnLsSave(){
    try {
        var o = {}, n = 0;
        for(var k in awgAsnCount){
            if(!awgAsnCount.hasOwnProperty(k)) continue;
            var c = awgAsnCount[k];
            if(typeof c === 'number' && c >= 0){ o[k] = { n: c, ts: Date.now() }; if(++n >= 2000) break; }
        }
        localStorage.setItem(AWG_ASN_LS, JSON.stringify(o));
    } catch(e){}
}
function awgCloseAnalyze(){
    // A start still in its save: cancel it (awgAnalyzeStart's done stops what it may have
    // started). A running capture while another save holds the form: stop it once that ends —
    // closing must never leave a hidden capture (+ dnsmasq query logging) running.
    if(awgAnalyzeStarting) awgAnalyzeCancel = true;
    else if(awgAnalyzeActive){
        if(awgFormBusy()) awgAfterSave(function(){ if(awgAnalyzeActive) awgAnalyzeStop(); });
        else awgAnalyzeStop();
    }
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
// Build the combined report (diag dump + the on-page log), shared by download + copy.
function awgBuildDiagReport(){
    var lbox = document.getElementById('awg_log');
    var log = lbox ? String(lbox.textContent || lbox.innerText || '').replace(/\s+$/, '') : '';
    return awgDiagText + (log ? ('\n\n' + T('DIAG_LOG_HEADER') + '\n' + log) : '');
}
// Brief inline feedback in the footer note (green ok / red fail), auto-clears.
function awgDiagFlashNote(msg, ok){
    var n = document.getElementById('awg_diag_note');
    if(!n) return;
    n.style.color = ok ? '#5cb85c' : '#d9534f';
    n.textContent = msg;
    clearTimeout(n._ft);
    n._ft = setTimeout(function(){ n.textContent = ''; n.style.color = '#f0ad4e'; }, 1800);
}
// Primary action: generate the report client-side and download it as a .txt file (no round-trip).
function awgDownloadDiagReport(btn){
    if(!awgDiagText){ alert(T('DIAG_NOT_READY')); return; }
    var report = awgBuildDiagReport();
    var d = new Date(), p = function(n){ return (n < 10 ? '0' : '') + n; };
    var name = 'amneziawg-diag-' + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
             + '-' + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + '.txt';
    try {
        var blob = new Blob([report], { type: 'text/plain;charset=utf-8' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url; a.download = name;
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        setTimeout(function(){ URL.revokeObjectURL(url); }, 2000);
        awgDiagFlashNote(T('DIAG_DOWNLOADED'), true);
    } catch(e){
        awgDiagFlashNote(T('DIAG_DOWNLOAD_FAILED'), false);
    }
}
// Secondary: copy the report (fenced for Telegram) to the clipboard — the mini icon button.
function awgCopyDiagReport(btn){
    if(!awgDiagText){ alert(T('DIAG_NOT_READY')); return; }
    awgCopyText('```\n' + awgBuildDiagReport() + '\n```', function(ok){
        awgDiagFlashNote(ok ? T('DIAG_COPIED') : T('DIAG_COPY_FAILED'), ok);
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
// The probe path is IPv4-only (ping/curl -I awg0 rides the v4 policy rule), so IPv6 DNS
// entries can't be probed and are dropped — but VISIBLY: with dual-stack configs the silent
// drop read as "the button is broken". The fill is also NOT saved by itself (a refresh
// reverts it like any unapplied field) — the inline hint says both things.
function awgWatchdogFromDns(){
    var wd = document.getElementById('awg_watchdog_hosts');
    if(!wd) return;
    var dns = (document.getElementById('awg_dns') || {}).value || '';
    var toks = dns.split(/[\s,]+/).filter(function(h){ return !!h; });
    var hosts = toks.filter(function(h){ return /^[0-9A-Za-z][0-9A-Za-z.-]*$/.test(h); }).slice(0, 4);
    if(!hosts.length){ alert(T(toks.length ? 'MSG_WD_DNS_ALL_V6' : 'MSG_NO_DNS_FOR_WD')); return; }
    wd.value = hosts.join(' ');
    awgWdHint(T(toks.length > hosts.length ? 'MSG_WD_COPIED_DROPPED' : 'MSG_WD_COPIED', hosts.join(' ')));
    wd.focus();
}

// Show/clear the small note under the watchdog-hosts field ('' hides it).
function awgWdHint(msg){
    var el = document.getElementById('awg_wd_hint');
    if(!el) return;
    el.textContent = msg || '';
    el.style.display = msg ? '' : 'none';
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
    applyAwg3Capability(s.awg3);
    applyAwg31Capability(s.awg31);
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

    // Uptime label next to the badge — only in the stable Connected state (transition states
    // show just the badge). The 1s ticker keeps it counting between polls.
    awgConnUp = !!(s.running && !s.stopping && !s.starting);
    awgConnStart = parseInt(s.conn_start, 10) || 0;
    awgConnUptime = parseInt(s.conn_uptime, 10) || 0;
    awgTickUptime();

    awgLastStatus = s;
    // Config profiles: render the status row + refresh the bar. The status never writes the
    // model's pointer any more (D9): the status file can lag the store, and a pointer changed
    // elsewhere is exactly what the save pipeline's conflict check must see (awgSave).
    if(s.profile && s.profile.active >= 1){
        awgPfStatus = s.profile;
        pfRecoverLegacyNames(s.profile);
        var pfRow = document.getElementById('awg_profile_row');
        var pfCell = document.getElementById('awg_profile_cell');
        if(pfRow && pfCell){
            // «name (k/N)» with ORDINALS over the configured slots (C5) — never a slot number;
            // the name comes from the active slot's list entry (the backend sends it decoded,
            // empty when unnamed).
            var pfCfg = [], pfActName = '', pfl = s.profile.list || [];
            for(var pfi = 0; pfi < pfl.length; pfi++){
                var pfe = pfl[pfi] || {}, pfs = pfe.n || (pfi + 1);
                if(!pfe.cfg) continue;
                pfCfg.push(pfs);
                if(pfs == s.profile.active) pfActName = String(pfe.name || '');
            }
            var pfK = 0;
            for(var pfj = 0; pfj < pfCfg.length; pfj++){ if(pfCfg[pfj] == s.profile.active){ pfK = pfj + 1; break; } }
            if(pfCfg.length > 1 || s.profile.auto){
                var ptxt = escHtml(pfActName || T('PF_UNNAMED', pfK || '?'));
                if(pfK) ptxt += ' <span style="color:#b6bdc7;">(' + pfK + '/' + pfCfg.length + ')</span>';
                if(s.profile.auto) ptxt += ' <span style="color:#f0ad4e;">&middot; ' + escHtml(T('LBL_PF_AUTO')) + '</span>';
                pfCell.innerHTML = ptxt;
                pfRow.style.display = '';
            } else {
                pfRow.style.display = 'none';
            }
        }
        // A skipped/failed switch note goes once the switch happened after all, or the user's
        // choice moved on.
        if(awgSwitchWarnSlot && (s.profile.user != awgSwitchWarnSlot ||
           (s.running && !s.starting && !s.stopping && s.profile.active == awgSwitchWarnSlot && String(s.conn_start) !== String(awgSwitchWarnConn))))
            awgSwitchWarn('');
        pfRenderBarIfChanged();
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

    // Connection history (last 5 sessions) — hidden until the backend has recorded at least
    // one. Start time is rendered in the browser locale; unknown duration/epoch shows as "—";
    // reason tokens map to i18n keys, unknown tokens are shown as-is (forward-compatible).
    var histBody = document.getElementById('awg_hist');
    if(histBody){
        var hist = (s.conn_history && s.conn_history.length) ? s.conn_history : [];
        var hh = '';
        for(var hi = 0; hi < hist.length; hi++){
            var he = hist[hi] || {};
            var hStart = (he.s > 1000000000) ? new Date(he.s * 1000).toLocaleString() : '—';
            var hDurS = awgFmtDur(he.d); if(hDurS === null) hDurS = '—';
            var hKey = 'HIST_R_' + String(he.r || 'auto').toUpperCase();
            var hReason = (AWG_I18N[AWG_LANG] && AWG_I18N[AWG_LANG][hKey]) || AWG_I18N.en[hKey] || String(he.r || '—');
            hh += '<tr><td>' + escHtml(hStart) + '</td><td>' + escHtml(hDurS) + '</td><td>' + escHtml(hReason) + '</td></tr>';
        }
        histBody.innerHTML = hh;
        var histTitle = document.getElementById('awg_hist_title');
        var histWrap = document.getElementById('awg_hist_wrap');
        if(histTitle) histTitle.style.display = hh ? '' : 'none';
        if(histWrap) histWrap.style.display = hh ? '' : 'none';
    }

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
    if(geoBtn && !awgGeoBusy && !geoBtn._awgChk){   // (_awgChk: awgSave is reading the store for it)
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
    renderKernelUnsupWarning(s);
    renderCtfBlockWarning(s);
    renderMemSqueezeWarning(s);
    renderXrayCaptureWarning(s);
    renderFwVpnWarning(s);
    renderDnsGeoWarning(s);
    renderGeoMatchallWarning(s);
    renderNoHandshakeWarning(s);
    renderConfPendingWarning(s);
}

// Legacy spaced names (D2): a name stored raw before 1.5.26 («My Phone») reached this page cut at
// its first space («My»), while the backend still reads the whole line and reports it decoded in
// status. Where the model holds exactly that first word and the stored value is not in the new
// encoded form (no '%'), put the full name back into the model (and the input, unless the user is
// typing in it) — the unsaved-changes hint then shows it, and the next save stores it encoded.
function pfRecoverLegacyNames(p){
    if(awgFormBusy() || !p || !p.list) return;
    for(var i = 0; i < p.list.length; i++){
        var it = p.list[i] || {}, sl = it.n || (i + 1);
        if(!it.cfg || typeof it.name !== 'string' || it.name.indexOf(' ') === -1) continue;
        if(sl < 1 || sl > AWG_PF_MAX || !pfConfigured(sl)) continue;
        var key = pfKey(sl, 'name'), bv = awgCsBase[key];
        if(bv != null && String(bv).indexOf('%') !== -1) continue;
        if(pfNameDec(custom_settings[key] || '') !== it.name.split(' ')[0]) continue;
        var enc = pfNameEnc(it.name);
        if(!enc || enc === custom_settings[key]) continue;
        custom_settings[key] = enc;
        var ne = document.getElementById('awg_pf_name_' + sl);
        if(ne && document.activeElement !== ne) ne.value = pfNameDec(enc);
        pfUpdateDirtyHint();
    }
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

// Reverse-coexistence banner (amber, informational since 1.3.12): a transparent proxy (XRAYUI/xray
// in TPROXY "redirect all" mode) captures LAN traffic ahead of our routing. This is now largely
// auto-resolved — the backend's AWG_PRIO mangle chain (hooked before XRAYUI) gives AmneziaWG-
// assigned devices priority into the tunnel — so the banner just explains that coexistence, and
// notes the one residual case AWG_PRIO can't fix: xray also grabbing the router's OWN handshake
// (tunnel up but no traffic). Flagged in status.xray_capture (xray running + TPROXY/fwmark).
var awgXrayStopping = false;
function renderXrayCaptureWarning(s){
    var el = document.getElementById('awg_xray_warn');
    if(!el) return;
    if(!s || !s.xray_capture){ el.style.display = 'none'; el.innerHTML = ''; awgXrayStopping = false; return; }
    var html = T('XRAY_CAP_HEADER') + T('XRAY_CAP_FIX') + T('XRAY_CAP_TECH');
    // Offer a one-click "Stop Xray" only when XRAYUI is actually controllable (status.xray_ctl =
    // /jffs/scripts/xrayui present) — the backend stops it through XRAYUI's own cleanup.
    if(s.xray_ctl){
        html += '<div style="margin-top:8px;"><input type="button" class="button_gen"'
              + (awgXrayStopping ? ' disabled' : '')
              + ' value="' + escHtml(awgXrayStopping ? T('XRAY_STOPPING') : T('XRAY_STOP_BTN')) + '"'
              + ' onclick="awgStopXray(this);"></div>';
    }
    el.innerHTML = html;
    el.style.display = '';
}
// Unsupported-kernel banner — RETIRED in 1.2.61. Old kernels (Linux 2.6.x, e.g. RT-AC68U) are now
// supported (smfix daemon 1.2.58 + the drain_ip_rules fix 1.2.61), so the backend hard-codes
// status.kernel_unsup = false and this renderer stays dormant — the scaffold is kept only so the
// field can't accidentally render a stale banner. Left in place in case a future old-kernel
// warning ever needs it (KERNEL_UNSUP_HEADER/BODY text would need updating first).
function renderKernelUnsupWarning(s){
    var el = document.getElementById('awg_kernel_warn');
    if(!el) return;
    if(!s || !s.kernel_unsup){ el.style.display = 'none'; el.innerHTML = ''; return; }
    el.innerHTML = T('KERNEL_UNSUP_HEADER') + '<div style="margin-top:6px;">' + T('KERNEL_UNSUP_BODY') + '</div>';
    el.style.display = '';
}

// Broadcom CTF blocker (red, with an action button). On CTF-accelerated boxes (RT-AC68U class)
// our policy routing would hang the kernel → watchdog reboot, so the backend refuses do_start and
// flags status.ctf_block. Offer a one-click "disable CTF + reboot" (backend do_ctf_disable sets
// nvram ctf_disable=1 and reboots — the fix Merlin itself uses for policy-routed VPNs).
var awgCtfDisabling = false;
function renderCtfBlockWarning(s){
    var el = document.getElementById('awg_ctf_warn');
    if(!el) return;
    if(!s || !s.ctf_block){ el.style.display = 'none'; el.innerHTML = ''; awgCtfDisabling = false; return; }
    var html = T('CTF_BLOCK_HEADER') + T('CTF_BLOCK_FIX');
    html += '<div style="margin-top:8px;"><input type="button" class="button_gen"'
          + (awgCtfDisabling ? ' disabled' : '')
          + ' value="' + escHtml(awgCtfDisabling ? T('CTF_DISABLING') : T('CTF_DISABLE_BTN')) + '"'
          + ' onclick="awgDisableCtf(this);"></div>';
    el.innerHTML = html;
    el.style.display = '';
}
// "Disable acceleration & reboot": backend do_ctf_disable sets nvram ctf_disable=1 and reboots the
// router. User-initiated, with a confirm (it IS a reboot). No status refresh follows — the box goes
// down; the page reconnects after it's back (CTF then off, banner gone, tunnel startable).
function awgDisableCtf(btn){
    if(awgCtfDisabling) return;
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    if(!confirm(T('CTF_DISABLE_CONFIRM'))) return;
    awgCtfDisabling = true;
    if(btn){ btn.disabled = true; btn.value = T('CTF_DISABLING'); }
    awgPostSettings('start_awgctfdisable', false, 2, function(){});   // no settings to carry
}

// "Stop Xray": stop the co-resident XRAYUI through its OWN entry point (backend do_xray_stop ->
// /jffs/scripts/xrayui stop) so its TPROXY/fwmark rules are cleaned up, not just the process.
// User-initiated, with a confirm. After firing, refresh status so the banner clears once gone.
// Firmware VPN client (wgc*/VPN Fusion) banner. Its policy rules sit ABOVE AmneziaWG's
// (ip-rule prio <98), so a CONNECTED firmware VPN captures traffic before our marking —
// and an enabled-but-idle profile is the same trap in latent form (field case: wgc_enable=1
// with a dead endpoint, discovered only by reading ip rule). Backend probe:
// status.fwvpn_state = "active" (red: capturing NOW) | "enabled" (yellow: will capture when
// it connects) | "" — plus fwvpn_detail (rule/table or profile names) for the message.
function renderFwVpnWarning(s){
    var el = document.getElementById('awg_fwvpn_warn');
    if(!el) return;
    var st = (s && s.fwvpn_state) || '';
    if(st !== 'active' && st !== 'enabled'){ el.style.display = 'none'; el.innerHTML = ''; return; }
    var detail = escHtml(s.fwvpn_detail || '');
    if(st === 'active'){
        el.style.background = '#3a1a1a'; el.style.borderColor = '#d9534f'; el.style.color = '#e8a0a0';
        el.innerHTML = T('FWVPN_ACTIVE', detail);
    } else {
        el.style.background = '#3a331a'; el.style.borderColor = '#d9c34f'; el.style.color = '#e8dca0';
        el.innerHTML = T('FWVPN_ENABLED', detail);
    }
    el.style.display = '';
}

// Memory envelope at its floor (yellow). On a strict-overcommit firmware
// (vm.overcommit_memory=2) with little commit headroom the RUNNING daemon was launched with
// its soft heap ceiling on the 64MiB floor and its buffer pool on the 512 x 64KB liveness
// floor. A sustained inbound burst then walks through the soft limit into a Go OOM abort,
// the watchdog restarts the daemon, and the user sees "the VPN drops every few minutes" —
// with nothing in the UI explaining why. The levers that work are box-side (swap raises
// CommitLimit 1:1; stopping user-space memory consumers lowers Committed_AS). Backend (only
// while the tunnel runs): status.mem_squeeze = "floor" (no swap) | "tight" (swap present) |
// "", mem_detail = "<GOMEMLIMIT MiB>|<pool cap>|<swap MiB>".
function renderMemSqueezeWarning(s){
    var el = document.getElementById('awg_mem_warn');
    if(!el) return;
    var st = (s && s.mem_squeeze) || '';
    if(st !== 'floor' && st !== 'tight'){ el.style.display = 'none'; el.innerHTML = ''; return; }
    var d = String((s && s.mem_detail) || '').split('|');
    el.innerHTML = T(st === 'floor' ? 'MEM_SQUEEZE_NOSWAP' : 'MEM_SQUEEZE_SWAP',
                     escHtml(d[0] || '?'), escHtml(d[1] || '?'), escHtml(d[2] || '0'));
    el.style.display = '';
}

// Domain-geo vs DNS-interception mismatch (yellow): domain lists are loaded and geo is
// routed, but the :53 interception is not in place — domains then populate only for clients
// that voluntarily use the router's dnsmasq (field case: "traffic didn't move until I
// enabled interception"). Backend: status.dnsgeo_warn = "user" (compat mode) | "dpi:<tool>"
// | "fwdns:<owner>" | "" — DoT and the transient mid-start window are deliberately excluded.
function renderDnsGeoWarning(s){
    var el = document.getElementById('awg_dnsgeo_warn');
    if(!el) return;
    var w = (s && s.dnsgeo_warn) || '';
    if(!w){ el.style.display = 'none'; el.innerHTML = ''; return; }
    var doms = escHtml(String(s.geo_domains != null ? s.geo_domains : '?'));
    if(w === 'user'){
        el.innerHTML = T('DNSGEO_USER', doms);
    } else {
        var cause = escHtml(w.indexOf(':') > 0 ? w.slice(w.indexOf(':') + 1) : w);
        el.innerHTML = T('DNSGEO_AUTO', cause, doms);
    }
    el.style.display = '';
}

// Foreign match-all ipset directive (red). A rule hand-written in the user's OWN dnsmasq config
// routes EVERY domain into one of our geo sets — the empty //-segment left by a `https://` scheme
// (or a bare `#`) is dnsmasq's "match everything" — so Geo mode sends the WHOLE LAN through the
// tunnel (every site shows the VPN IP; geo-blocked services break). Backend can't fix the user's
// own line, only surface it: status.geo_matchall_warn = the offending line (already trimmed) | "".
function renderGeoMatchallWarning(s){
    var el = document.getElementById('awg_geo_matchall_warn');
    if(!el) return;
    var ln = (s && s.geo_matchall_warn) || '';
    if(!ln){ el.style.display = 'none'; el.innerHTML = ''; return; }
    el.innerHTML = T('GEO_MATCHALL', escHtml(ln));
    el.style.display = '';
}

// Saved config differs from the RUNNING tunnel (yellow). Apply deliberately never restarts
// the daemon, so edits to the connection config itself (keys/endpoint/obfuscation/DNS/MTU)
// sit in the saved conf until a Restart — without this badge users assumed Apply had switched
// them (field case: a user swapped the whole provider config, applied, and kept riding the old
// tunnel). Backend: status.conf_pending (launch-time conf md5 vs current conf; live peer-key
// fallback right after an upgrade). Gated on !starting && !stopping like the other banners.
function renderConfPendingWarning(s){
    var el = document.getElementById('awg_confpend_warn');
    if(!el) return;
    if(!s || !s.conf_pending || !s.running || s.starting || s.stopping){
        el.style.display = 'none'; el.innerHTML = '';
        return;
    }
    el.innerHTML = T('CONF_PENDING');
    el.style.display = '';
}

// "Tunnel up but no handshake" banner. Backend status.no_handshake is true only while
// running AND no peer ever handshaked (peer_hs_max==0 → server unreachable / obfuscation
// mismatch). Gated here on !starting && !stopping so the brief post-start window (running
// true, first handshake pending) doesn't flash it. Extra-loud when the kill-switch is on,
// where a dead tunnel is a total blackout ("connected but nothing opens").
function renderNoHandshakeWarning(s){
    var el = document.getElementById('awg_nohs_warn');
    if(!el) return;
    if(!s || !s.no_handshake || s.starting || s.stopping || !s.running){
        el.style.display = 'none'; el.innerHTML = ''; return;
    }
    var ksNote = s.killswitch ? T('NOHS_KS') : '';
    el.innerHTML = T('NOHS', ksNote);
    el.style.display = '';
}

function awgStopXray(btn){
    if(awgXrayStopping) return;
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
    if(!confirm(T('XRAY_STOP_CONFIRM'))) return;
    awgXrayStopping = true;
    if(btn){ btn.disabled = true; btn.value = T('XRAY_STOPPING'); }
    awgPostSettings('start_awgxraystop', false, 2, function(){   // no settings to carry
        setTimeout(awgRefreshStatus, 2500);
        setTimeout(function(){ awgXrayStopping = false; awgRefreshStatus(); }, 6000);
    });
}

function setOfflineUI(){
    var badge = document.getElementById('awg_badge');
    badge.className = 'awg-status stopped';
    badge.innerHTML = '&#9679; ' + escHtml(T('STAT_STOPPED'));
    awgConnUp = false;
    awgTickUptime();
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
    if(awgFormBusy()){ awgFormBusyRefuse(); return; }
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
        var fname = fileInput.files[0].name;   // capture now — used to default the profile name
        var reader = new FileReader();
        reader.onload = function(e){ parseConfig(e.target.result, fname); };
        reader.readAsText(fileInput.files[0]);
    };
    fileInput.click();
}

// The backend reports whether the INSTALLED daemon + awg CLI understand the AmneziaWG 3.0
// device params (status.awg3). They are not optional extras: an older awg CLI aborts the whole
// `setconf` on the first key it does not recognise, so the tunnel would simply never come up.
// When unsupported, disable the inputs and say why — but NEVER clear what the user (or an
// imported provider config) already stored, so the values survive until the binaries catch up.
// Undefined (older backend that predates the field) is treated as "unsupported" — fail closed.
function applyAwg3Capability(cap){
    // Three states, not two. Only an EXPLICIT false means "the installed binaries cannot do
    // this" — undefined means the status simply has not reported yet (a seeded stub, a poll
    // that has not landed), and claiming unsupported there is a false statement the user acts
    // on. Leave the fields usable in that case: the backend gates emission independently, so
    // the disabling is a convenience, never the safety mechanism.
    var known = (cap === true || cap === false);
    var ok = (cap !== false);
    var note = document.getElementById('awg3_unsupported');
    if(note) note.style.display = (known && !ok) ? '' : 'none';
    for(var i = 0; i < AWG3_FIELDS.length; i++){
        var el = document.getElementById('awg_' + AWG3_FIELDS[i]);
        if(!el) continue;
        el.disabled = !ok;
        el.style.opacity = ok ? '' : '0.5';
    }
}

// The AmneziaWG 3.1 pair (status.awg31) — same three-state contract as applyAwg3Capability,
// its own gate: a 3.0-capable build must keep the seven 3.0 fields editable while these two
// go disabled.
function applyAwg31Capability(cap){
    var known = (cap === true || cap === false);
    var ok = (cap !== false);
    var note = document.getElementById('awg31_unsupported');
    if(note) note.style.display = (known && !ok) ? '' : 'none';
    for(var i = 0; i < AWG31_FIELDS.length; i++){
        var el = document.getElementById('awg_' + AWG31_FIELDS[i]);
        if(!el) continue;
        el.disabled = !ok;
        el.style.opacity = ok ? '' : '0.5';
    }
}

// Canonical "on"/"off" for the AWG 3.1 booleans; anything unrecognised -> '' (unset).
function awgNormOnOff(v){
    v = String(v == null ? '' : v).trim().toLowerCase();
    if(v === 'on' || v === 'true' || v === '1' || v === 'yes') return 'on';
    if(v === 'off' || v === 'false' || v === '0' || v === 'no') return 'off';
    return '';
}

function parseConfig(text, fileName){
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
        'awg_hpk', 'awg_cpa', 'awg_rat', 'awg_rto', 'awg_rjt', 'awg_kat', 'awg_mha',
        'awg_rt', 'awg_dc',
        'awg_peer_p1', 'awg_peer_p2', 'awg_peer_endpoint',
        'awg_peer_allowedips', 'awg_peer_keepalive'
    ];
    for(var ci = 0; ci < clearFields.length; ci++){ setVal(clearFields[ci], ''); }

    var lines = text.split('\n');
    var section = '';
    for(var i = 0; i < lines.length; i++){
        var line = lines[i].trim();
        // Section headers are case-insensitive in amneziawg-tools too.
        if(line.toLowerCase() === '[interface]'){ section = 'iface'; continue; }
        if(line.toLowerCase() === '[peer]'){ section = 'peer'; continue; }
        if(!line || line.charAt(0) === '#') continue;

        var parts = line.split('=');
        if(parts.length < 2) continue;
        var key = parts[0].trim();
        var val = parts.slice(1).join('=').trim();
        var canon = AWG_CONF_KEY_CANON[key.toLowerCase()];
        if(canon) key = canon;

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
                // AmneziaWG 3.0. amneziawg-tools matches config keys case-INsensitively,
                // so a provider file may spell these any way; normalise before comparing.
                case 'HeaderProtectionKey':    setVal('awg_hpk', val); break;
                case 'ContentPaddingAddition': setVal('awg_cpa', val); break;
                case 'RekeyAfterTime':         setVal('awg_rat', val); break;
                case 'RekeyTimeout':           setVal('awg_rto', val); break;
                case 'RejectAfterTime':        setVal('awg_rjt', val); break;
                case 'KeepaliveTimeout':       setVal('awg_kat', val); break;
                case 'MaxHandshakeAttempts':   setVal('awg_mha', val); break;
                // AmneziaWG 3.1 booleans. The backend emits the stored value verbatim and
                // amneziawg-tools' parse_bool takes only "on"/"off"/digits, so normalise the
                // provider's spelling here; an unrecognised value stays unset rather than
                // riding through to a setconf error.
                case 'RandomTrailers':         setVal('awg_rt', awgNormOnOff(val)); break;
                case 'DisableCookies':         setVal('awg_dc', awgNormOnOff(val)); break;
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
    var recognized = gotPk || gotPub || gotEp;
    // Default the edited slot's name from the filename (providers name files by country), but
    // ONLY when it has no name yet — never clobber one the user typed. Harvest the bar FIRST: a
    // name typed into the row but not yet harvested lives only in the input (D11). Set the row's
    // name input (if the row is rendered) AND the stored (encoded) key, so it survives the
    // pfRenderBar() harvest.
    if(recognized && fileName){
        pfHarvestBar();
        var nm = pfCleanFileName(fileName);
        var nameKey = pfKey(awgPfSel, 'name');
        if(nm && !custom_settings[nameKey]){
            custom_settings[nameKey] = pfNameEnc(nm);
            var ne = document.getElementById('awg_pf_name_' + awgPfSel);
            if(ne) ne.value = nm;
        }
    }
    updateFirstRun();
    pfRenderBar();   // the edited slot's row shows the freshly imported endpoint + defaulted name
    if(!recognized){
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
// custom_settings store (Merlin truncates values at the first whitespace). Quotes are never
// valid in any CSV field (domains/IPs/category names) — strip them, so values pasted from a
// quote-polluted v2fly categories list (2026-07 upstream format change) self-heal on save.
function awgCsv(id){
    var el = document.getElementById(id);
    return el ? String(el.value || '').replace(/["']/g, '').replace(/[\s,]+/g, ',').replace(/^,+|,+$/g, '') : '';
}

// `warn` (optional): a notice shown under the textarea — set when the stored value came back cut
// by the firmware (see loadGeoFiles); it clears as soon as the user edits the content.
function addGeoFileRow(name, content, kind, warn){
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
            (warn ? '<div class="awg-hint geo_file_warn" style="color:#ffcc00;">' + escHtml(warn) + '</div>' : '') +
        '</td>';
    tbody.appendChild(tr);
    var ta = tr.querySelector('.geo_file_content');
    if(ta){
        ta.value = content || '';   // set via .value so content isn't HTML-parsed
        if(warn) ta.addEventListener('input', function(){ var w = tr.querySelector('.geo_file_warn'); if(w) w.style.display = 'none'; tr.removeAttribute('data-raw'); });
    }
    return tr;
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
    tbody.insertBefore(tr, tbody.querySelector('tr.geo_url_warn'));   // above a "cut" warning row, if any
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
    fi.accept = '.txt,.lst,.list,.cidr,.conf,.csv,text/plain';
    fi.style.display = 'none';
    document.body.appendChild(fi);
    fi.onchange = function(){
        if(fi.files && fi.files[0]){
            var f = fi.files[0];
            var reader = new FileReader();
            reader.onload = function(e){
                var ta = row.querySelector('.geo_file_content');
                if(ta) ta.value = String(e.target.result || '');
                var w = row.querySelector('.geo_file_warn'); if(w) w.style.display = 'none';
                row.removeAttribute('data-raw');
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
    var parts = [], used = {}, j;
    for(j = 0; j < rows.length; j++){
        var un = rows[j].querySelector('.geo_file_name');
        if(un && un.value) used[sanitizeGeoName(un.value)] = true;
    }
    for(var i = 0; i < rows.length; i++){
        var nmEl = rows[i].querySelector('.geo_file_name');
        var ctEl = rows[i].querySelector('.geo_file_content');
        if(!nmEl || !ctEl) continue;
        var name = sanitizeGeoName(nmEl.value);
        var content = ctEl.value;
        var raw = rows[i].getAttribute('data-raw');
        if(raw && name && !content){ parts.push(name + ',' + raw); continue; }   // damaged, untouched: keep as stored
        if(!content.replace(/\s+/g, '')) continue;   // skip empty rows
        // A pasted list without a name used to be dropped SILENTLY on save — name it instead.
        if(!name){ for(j = 1; used['file' + j]; j++){} name = 'file' + j; used[name] = true; nmEl.value = name; }
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
        // Normalize what the backend accepts (it fetches only lowercase-scheme http(s)://): a bare
        // "example.com/list.txt" gets https://, "HTTPS://" is lowercased. Both used to be dropped
        // by the router without a word. Written back so the user sees what will be fetched.
        var u = geoNormUrl(inputs[i].value);
        if(!u) continue;
        if(inputs[i].value !== u) inputs[i].value = u;
        urls.push(u);
    }
    if(!urls.length) return '';
    try { return btoa(unescape(encodeURIComponent(urls.join('\n')))); } catch(e){ return ''; }
}

function loadGeoFiles(data, kind, cut){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_files_rows' : 'awg_geo_files_rows');
    if(!tbody) return;
    tbody.innerHTML = '';
    if(data == null) data = custom_settings.awg_geo_custom_files || '';
    if(!data) return;
    // A value at the firmware reader's 2999-byte cap was CUT (see AWG_CS_*): its last file lost
    // its tail, usually mid-line, and any files after it are gone. atob used to throw on that
    // (for some name lengths) and the row came back EMPTY — the next Apply then dropped the file
    // for good; for other lengths the half-line was re-saved as data ("…/24" cut to "/2" = a
    // quarter of IPv4). Decode what survived, drop the partial line, and say so on the row.
    // `cut` comes from the STORED value (geoHydratePolicies): rows re-rendered from unsaved edits
    // must never be cut again. If the cut fell inside a following file's name, that file is gone:
    // the warning then goes on the last row shown.
    var entries = data.split(';'), last = -1, i, shown = null;
    for(i = 0; i < entries.length; i++) if(entries[i]) last = i;
    var tailcut = !!cut && /[;=]$/.test(data);
    if(tailcut) cut = false;
    for(i = 0; i < entries.length; i++){
        if(!entries[i]) continue;
        var ci = entries[i].indexOf(',');
        if(ci < 0 || ci === 0){
            if(cut && i === last && shown){ var sw = shown.querySelector('.geo_file_warn'); if(!sw) addGeoFileWarn(shown, T('GEO_FILE_CUT')); }
            continue;
        }
        var name = entries[i].slice(0, ci), b64 = entries[i].slice(ci + 1);
        var content = '', warn = '', raw = '';
        if(cut && i === last){
            content = geoB64DecodeLoose(b64).replace(/\n?[^\n]*$/, '');
            warn = T('GEO_FILE_CUT');
        } else if(tailcut && i === last){
            content = geoB64DecodeLoose(b64);
        } else {
            try { content = decodeURIComponent(escape(atob(b64))); } catch(e){ content = ''; warn = T('GEO_FILE_UNREADABLE'); raw = b64; }
        }
        shown = addGeoFileRow(name, content, kind, warn);
        if(raw && shown) shown.setAttribute('data-raw', raw);
    }
    if(tailcut && shown && !shown.querySelector('.geo_file_warn')) addGeoFileWarn(shown, T('GEO_FILE_CUT'));
}
// Put a warning line under an existing file row (used when the file after it was cut away).
function addGeoFileWarn(tr, msg){
    var td = tr.querySelector('td'); if(!td) return;
    var d = document.createElement('div');
    d.className = 'awg-hint geo_file_warn'; d.style.color = '#ffcc00'; d.textContent = msg;
    td.appendChild(d);
}
// Decode as much of a (possibly truncated) base64 UTF-8 text as survives — the backend b64d rule:
// stray characters dropped, the stream ends at its first '=', padding repaired (a 2/3-char tail
// gets its '='s back — a cut between the two '=' loses nothing; a lone 1-char tail is dropped),
// and a multi-byte character split by the cut is trimmed.
function geoB64DecodeLoose(b64){
    b64 = String(b64 || '').replace(/[^A-Za-z0-9+\/=]/g, '');
    var eq = b64.indexOf('='); if(eq !== -1) b64 = b64.slice(0, eq);
    var r = b64.length % 4;
    if(r === 1) b64 = b64.slice(0, -1); else if(r) b64 += (r === 2 ? '==' : '=');
    var bin = '';
    try { bin = atob(b64); } catch(e){ return ''; }
    for(var k = 0; k < 4 && k <= bin.length; k++){
        try { return decodeURIComponent(escape(bin.slice(0, bin.length - k))); } catch(e){}
    }
    return '';
}

function loadGeoUrls(data, kind, cut){
    var tbody = document.getElementById(kind === 'exc' ? 'awg_exc_url_rows' : 'awg_geo_url_rows');
    if(!tbody) return;
    tbody.innerHTML = '';
    if(data == null) data = custom_settings.awg_geo_custom_urls || '';
    if(!data) return;
    var txt = '';
    // A value the firmware cut (flag from geoHydratePolicies) keeps all but its partial last URL.
    if(cut) txt = geoB64DecodeLoose(data).replace(/\n?[^\n]*$/, '');
    else { try { txt = decodeURIComponent(escape(atob(data))); } catch(e){ txt = geoB64DecodeLoose(data); } }
    var urls = txt.split('\n');
    for(var i = 0; i < urls.length; i++){
        var u = urls[i].replace(/\s+/g, '');
        if(u) addGeoUrlRow(u, kind);
    }
    if(cut){
        var wtr = document.createElement('tr');
        wtr.className = 'geo_url_warn';
        wtr.innerHTML = '<td><div class="awg-hint" style="color:#ffcc00;">' + escHtml(T('GEO_URLS_CUT')) + '</div></td>';
        tbody.appendChild(wtr);
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
                    <a id="awg_gh_link" href="https://github.com/william-aqn/asuswrt-merlin-amneziawg" target="_blank" title="Merlin AmneziaWG GitHub repository" data-i18n-title="TITLE_GH_REPO" style="font-size:12px; text-decoration:none;">🐙 GitHub</a>
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
                            <span id="awg_uptime" style="display:none; color:#b6bdc7; font-size:12px;" title="Current connection uptime" data-i18n-title="TITLE_UPTIME"></span>
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
                <!-- Active config profile (hidden while only one profile exists and no failover override) -->
                <tr id="awg_profile_row" style="display:none;">
                    <th width="20%" data-i18n="TH_PROFILE">Profile</th>
                    <td><span id="awg_profile_cell">-</span></td>
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
                <div id="awg_kernel_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_ctf_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a1a1a; border:1px solid #d9534f; border-radius:5px; color:#e8a0a0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_mem_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_xray_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a2e1a; border:1px solid #f0ad4e; border-radius:5px; color:#f0d9a8; font-size:12px; line-height:1.5;"></div>
                <div id="awg_geo_matchall_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a1a1a; border:1px solid #d9534f; border-radius:5px; color:#e8a0a0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_fwvpn_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; border:1px solid; border-radius:5px; font-size:12px; line-height:1.5;"></div>
                <div id="awg_dnsgeo_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_nohs_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>
                <div id="awg_confpend_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>
                <!-- Skipped / failed profile switch (awgSwitchWarn) -->
                <div id="awg_switch_warn" style="display:none; margin:8px 0 2px 0; padding:9px 12px; background:#3a331a; border:1px solid #d9c34f; border-radius:5px; color:#e8dca0; font-size:12px; line-height:1.5;"></div>

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

                <!-- Connection history (last 5 sessions; rendered by updateStatusUI from status.conn_history) -->
                <div class="awg-section" id="awg_hist_title" style="display:none;" data-i18n="SEC_CONN_HISTORY">Connection history</div>
                <div class="awg-tablewrap" id="awg_hist_wrap" style="display:none;">
                <table width="100%" border="0" cellpadding="4" cellspacing="0" class="FormTable_table" id="awg_hist_table" style="min-width:520px;">
                <thead><tr>
                    <td width="40%" data-i18n="TH_HIST_START">Started</td>
                    <td width="25%" data-i18n="TH_HIST_DURATION">Duration</td>
                    <td width="35%" data-i18n="TH_HIST_END">Ended by</td>
                </tr></thead>
                <tbody id="awg_hist"></tbody>
                </table>
                </div>

                <div style="margin:15px 0 10px 5px;" class="splitLine"></div>

                <!-- ==================== CONFIG ==================== -->
                <div class="awg-section" style="display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
                    <span data-i18n="SEC_CONFIG">Configuration</span>
                    <input type="button" class="button_gen" value="Import .conf" data-i18n-val="BTN_IMPORT_CONF_FILE" title="Import a .conf file from the Amnezia VPN client" data-i18n-title="TITLE_IMPORT_CONF_FILE" onclick="importConfig();" style="margin-left:auto; font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;">
                </div>

                <!-- Config profiles (multi-config): slot rows + failover toggle, rendered by pfRenderBar() -->
                <div id="awg_pf_bar" style="margin:2px 0 10px 0;"></div>

                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable">
                <thead><tr><td colspan="2">Interface</td></tr></thead>
                <tr>
                    <th width="35%">Private Key</th>
                    <td><input type="text" class="input_32_table awg-dotted" id="awg_iface_p1" maxlength="64" autocomplete="off" spellcheck="false" autocapitalize="off" autocorrect="off"></td>
                </tr>
                <tr>
                    <th>Address</th>
                    <td><input type="text" class="input_20_table" id="awg_address" maxlength="128" placeholder="10.7.0.2/24, fd00::2/64" aria-label="Address"></td>
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
                    <td><input type="text" class="input_20_table" id="awg_dns" maxlength="160" placeholder="1.1.1.1" aria-label="DNS">
                        <span data-i18n="HINT_DNS" style="color:#b6bdc7; font-size:11px; margin-left:6px;">used by “DNS via tunnel” below; empty = firmware DNS</span></td>
                </tr>
                <tr>
                    <th data-i18n="LBL_TUNNEL_DNS_TH">DNS via tunnel</th>
                    <td><label><input type="checkbox" id="awg_tunnel_dns"> <span data-i18n="LBL_TUNNEL_DNS" style="color:#FFCC00;">Route the whole LAN's DNS through the tunnel to the servers above while the VPN is up (needs DNS interception ON — inert in compatibility mode; defeats ISP DNS poisoning)</span></label></td>
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
                    <!-- maxlength 21, not 4: with an AmneziaWG 3.0 build the backend accepts a
                         "lo-hi" range here (generate_config validates the shape either way). A
                         range could always be IMPORTED (setVal bypasses maxlength) but not typed. -->
                    <td><input type="text" class="input_6_table" id="awg_peer_keepalive" maxlength="21" placeholder="25" aria-label="Persistent Keepalive"> sec</td>
                </tr>
                </table>

                <!-- ==================== OBFUSCATION ==================== -->
                <details class="awg-details" style="margin-top:8px;">
                <summary style="padding:8px 10px; font-weight:bold; text-transform:uppercase; font-size:11px; letter-spacing:0.5px; background:#3a4548; border:1px solid #5a6b70; border-radius:3px; color:#e8edf2;" data-i18n-html="OBF_SUMMARY_HTML">AmneziaWG Obfuscation <span style="font-weight:normal; text-transform:none; letter-spacing:0; color:#b6bdc7;">— obfuscation parameters (usually filled in by importing a config) ▾</span></summary>
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:6px;">
                <tr>
                    <th width="35%">Jc (junk packet count)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_6_table" id="awg_jc" maxlength="3" placeholder="4" aria-label="Jc (junk packet count)"> (0-128)</td>
                </tr>
                <tr>
                    <th>Jmin (min junk size)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_6_table" id="awg_jmin" maxlength="5" placeholder="40" aria-label="Jmin (min junk size)"> bytes</td>
                </tr>
                <tr>
                    <th>Jmax (max junk size)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_6_table" id="awg_jmax" maxlength="5" placeholder="70" aria-label="Jmax (max junk size)"> bytes</td>
                </tr>
                <tr>
                    <th>S1 (init padding)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_6_table" id="awg_s1" maxlength="3" placeholder="20" aria-label="S1 (init padding)"> bytes</td>
                </tr>
                <tr>
                    <th>S2 (response padding)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_6_table" id="awg_s2" maxlength="3" placeholder="30" aria-label="S2 (response padding)"> bytes</td>
                </tr>
                <tr>
                    <th>S3<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_6_table" id="awg_s3" maxlength="3" placeholder="0" aria-label="S3"> bytes</td>
                </tr>
                <tr>
                    <th>S4<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_6_table" id="awg_s4" maxlength="3" placeholder="0" aria-label="S4"> bytes</td>
                </tr>
                <tr>
                    <th>H1 (init header)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_25_table" id="awg_h1" maxlength="32" placeholder="1234567891" aria-label="H1 (init header)"></td>
                </tr>
                <tr>
                    <th>H2 (response header)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_25_table" id="awg_h2" maxlength="32" placeholder="1987654321" aria-label="H2 (response header)"></td>
                </tr>
                <tr>
                    <th>H3 (cookie header)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_25_table" id="awg_h3" maxlength="32" placeholder="1112223334" aria-label="H3 (cookie header)"></td>
                </tr>
                <tr>
                    <th>H4 (data header)<span class="awg-ver">AWG 1.0</span></th>
                    <td><input type="text" class="input_25_table" id="awg_h4" maxlength="32" placeholder="4445556667" aria-label="H4 (data header)"></td>
                </tr>
                <tr>
                    <th>I1 (init junk)<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i1" style="font-size:11px;" maxlength="5000" placeholder="Auto-filled by Import Config" aria-label="I1 (init junk)"></td>
                </tr>
                <tr>
                    <th>I2<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i2" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I2"></td>
                </tr>
                <tr>
                    <th>I3<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i3" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I3"></td>
                </tr>
                <tr>
                    <th>I4<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i4" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I4"></td>
                </tr>
                <tr>
                    <th>I5<span class="awg-ver">AWG 1.5</span></th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_i5" style="font-size:11px;" maxlength="5000" placeholder="(optional)" aria-label="I5"></td>
                </tr>
                </table>

                <!-- ==================== AmneziaWG 3.0 ==================== -->
                <div id="awg3_unsupported" style="display:none; margin-top:8px; padding:6px 10px; border:1px solid #7a6a3a; background:#4a4230; border-radius:3px; font-size:11px; color:#e8dfc8;"
                     data-i18n="AWG3_UNSUPPORTED">AmneziaWG 3.0 parameters are not supported by the installed binaries — the fields below are disabled. Update the addon to a build with AWG 3.0 support.</div>
                <table width="100%" border="1" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;" id="awg3_table">
                <thead><tr><td colspan="2" data-i18n="TBL_AWG3">AmneziaWG 3.0 — needs a 3.0-capable peer on the OTHER side too. Leave empty unless the provider's config has them.</td></tr></thead>
                <tr>
                    <th width="35%">HeaderProtectionKey</th>
                    <td><input type="text" class="input_32_table awg-input-wide" id="awg_hpk" style="font-size:11px;" maxlength="44" placeholder="(optional, base64 — awg genkey)" aria-label="HeaderProtectionKey">
                        <div class="awg-hint" data-i18n="HINT_AWG3_HPK">Shared key — must be IDENTICAL on the server and every client. Requires S1–S4 ≥ 12 (all four, S3 included).</div></td>
                </tr>
                <tr>
                    <th>ContentPaddingAddition</th>
                    <td><input type="text" class="input_6_table" id="awg_cpa" maxlength="21" placeholder="10-40" aria-label="ContentPaddingAddition"> <span data-i18n="UNIT_BYTES">bytes</span>
                        <div class="awg-hint" data-i18n="HINT_AWG3_CPA">A single number or a "lo-hi" range: extra bytes per data packet. A padded packet never exceeds the largest one sent since the peer's last reply (500 B minimum), so the biggest packets go unpadded.</div></td>
                </tr>
                <tr>
                    <th>RekeyAfterTime</th>
                    <td><input type="text" class="input_6_table" id="awg_rat" maxlength="21" placeholder="120" aria-label="RekeyAfterTime"> <span data-i18n="UNIT_SEC">sec</span>
                        <div class="awg-hint" data-i18n="HINT_AWG3_RAT">How long a session lives before a rekey. Default 120. Must stay below RejectAfterTime.</div></td>
                </tr>
                <tr>
                    <th>RekeyTimeout</th>
                    <td><input type="text" class="input_6_table" id="awg_rto" maxlength="21" placeholder="5" aria-label="RekeyTimeout"> <span data-i18n="UNIT_SEC">sec</span>
                        <div class="awg-hint" data-i18n="HINT_AWG3_RTO">Retry interval for an unanswered handshake. Default 5. Very small values cause a handshake storm.</div></td>
                </tr>
                <tr>
                    <th>RejectAfterTime</th>
                    <td><input type="text" class="input_6_table" id="awg_rjt" maxlength="21" placeholder="180" aria-label="RejectAfterTime"> <span data-i18n="UNIT_SEC">sec</span>
                        <div class="awg-hint" data-i18n="HINT_AWG3_RJT">A session is dropped after this. Default 180. Below RekeyAfterTime the tunnel dies before it can rekey.</div></td>
                </tr>
                <tr>
                    <th>KeepaliveTimeout</th>
                    <td><input type="text" class="input_6_table" id="awg_kat" maxlength="21" placeholder="10" aria-label="KeepaliveTimeout"> <span data-i18n="UNIT_SEC">sec</span>
                        <div class="awg-hint" data-i18n="HINT_AWG3_KAT">Passive keepalive delay. Default 10 — this is NOT Persistent Keepalive (25).</div></td>
                </tr>
                <tr>
                    <th>MaxHandshakeAttempts</th>
                    <td><input type="text" class="input_6_table" id="awg_mha" maxlength="21" placeholder="18" aria-label="MaxHandshakeAttempts">
                        <div class="awg-hint" data-i18n="HINT_AWG3_MHA">Handshake retries before giving up. Default 18.</div></td>
                </tr>
                <tr>
                    <th>RandomTrailers<span class="awg-ver">AWG 3.1</span></th>
                    <td><select id="awg_rt" class="input_option" style="font-size:12px;" aria-label="RandomTrailers">
                            <option value="" data-i18n="OPT_AWG31_UNSET">— (default: off)</option>
                            <option value="on">on</option>
                            <option value="off">off</option>
                        </select>
                        <div class="awg-hint" data-i18n="HINT_AWG31_RT">Random-length tail on handshake packets (size obfuscation). SYMMETRIC: with it on, the peer's trailer-less handshakes still pass, but ours are dropped by a peer that lacks it — set only what the provider's config says.</div></td>
                </tr>
                <tr>
                    <th>DisableCookies<span class="awg-ver">AWG 3.1</span></th>
                    <td><select id="awg_dc" class="input_option" style="font-size:12px;" aria-label="DisableCookies">
                            <option value="" data-i18n="OPT_AWG31_UNSET">— (default: off)</option>
                            <option value="on">on</option>
                            <option value="off">off</option>
                        </select>
                        <div class="awg-hint" data-i18n="HINT_AWG31_DC">Never send WireGuard cookie replies (a load-protection message DPI can fingerprint). Affects this side only — safe with any peer. Trade-off: this side loses its handshake-flood protection.</div></td>
                </tr>
                </table>
                <div id="awg31_unsupported" style="display:none; margin-top:8px; padding:6px 10px; border:1px solid #7a6a3a; background:#4a4230; border-radius:3px; font-size:11px; color:#e8dfc8;"
                     data-i18n="AWG31_UNSUPPORTED">AmneziaWG 3.1 parameters (RandomTrailers / DisableCookies) are not supported by the installed binaries — those two fields are disabled.</div>
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
                        <div id="awg_wd_hint" style="display:none; margin-top:4px; max-width:480px; color:#FFCC00; font-size:11px; line-height:1.4;"></div>
                        <details class="awg-hint" data-i18n-html="HINT_WATCHDOG_HTML"><summary>Addresses the watchdog pings <b>through the tunnel</b> every 5 minutes (if at least one replies, the tunnel is alive). <u>Format and examples</u></summary><b>Format:</b> IPv4 or domain, several allowed — separated by a space or comma (up to 4 addresses; IPv6 is not supported — the probe rides the tunnel's IPv4).<br><b>Example:</b> <code>8.8.8.8, 1.1.1.1, 9.9.9.9</code><br>Prefer IPs (no dependency on DNS). Empty = default <b>8.8.8.8</b> and <b>1.1.1.1</b>. Change it if those addresses are blocked/unreachable for you — otherwise the watchdog restarts the VPN needlessly. Which addresses are checked is shown in the log below.</details>
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
                    <th data-i18n="TH_AUTOSTART">Autostart</th>
                    <td>
                        <label><input type="checkbox" id="awg_autostart"> <span data-i18n="LBL_AUTOSTART">Start the tunnel automatically after a router reboot</span></label>
                        <div class="awg-hint" data-i18n="HINT_AUTOSTART">On (default): the tunnel comes up by itself when the router boots. Turn it off to keep the tunnel stopped across reboots (e.g. while debugging another tool) — the configured connection is fully preserved, just start it manually with the «Start» button when needed. Manual start/restart and the watchdog of an already-running tunnel are not affected.</div>
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
                    <div class="awg-hint" data-i18n-html="HINT_GEO_CUSTOM_FORMAT">One entry per line. A domain (<code>example.com</code>) is routed via DNS; an IPv4 address or CIDR subnet (<code>1.2.3.0/24</code>) is added to the ipset (IPv6 is skipped). Text after <code>#</code> is a comment. A URL must return a plain-text list in this format. Files live inside the firmware's settings store, which holds only <b>about 2 KB of text per tab (~150 lines)</b> — put a bigger list online (e.g. a GitHub raw link) and add it as a URL source: those have no size limit.</div>

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
                <div class="awg-actions" style="margin-top:12px;">
                    <input type="button" class="button_gen" value="Apply" data-i18n-val="BTN_APPLY" onclick="saveSettings();" title="Save and apply without restarting the VPN" data-i18n-title="TITLE_APPLY">
                    <input type="button" class="button_gen" value="Save and restart" data-i18n-val="BTN_SAVE_RESTART" onclick="forceApply();" title="Save + restart the VPN (stop → start) + full rebuild of routes and firewall" data-i18n-title="TITLE_SAVE_RESTART">
                    <span id="awg_ack_bottom" class="awg-ack"></span>
                </div>
                <div style="font-size:11px; opacity:0.7; margin:8px auto 0; max-width:640px; line-height:1.55; text-align:left;">
                    <div data-i18n-html="APPLY_DESC1_HTML"><b>Apply</b> — save the settings and apply them «on the fly»: devices, routing policies, the firewall and the GeoIP/GeoSite lists update <b>without dropping the VPN connection</b>. Changes to the connection config itself (keys, endpoint, obfuscation, DNS, MTU) take effect only after <b>«Restart»</b> — a yellow notice will point that out. If the VPN is stopped — the settings are just saved and applied at the next start.</div>
                    <div style="margin-top:4px;" data-i18n-html="APPLY_DESC2_HTML"><b>Save and fully restart the VPN</b> (stop → start) — the config is re-applied (awg setconf), the interface, routes and firewall are rebuilt, the connection drops for a couple of seconds. Needed when changing keys, the server (Endpoint), MTU or obfuscation parameters (Jc, S1, H1…H4), or if the connection is «stuck».</div>
                </div>

                <!-- ==================== LOG ==================== -->
                <div class="awg-section" style="margin-top:15px; display:flex; align-items:center; flex-wrap:wrap; gap:8px;">
                    <span data-i18n="SEC_LOG">Log</span>
                    <!-- Short label on purpose (1.5.16): the long RU one overflowed the stock
                         fixed-size button on gnuton/TUF builds. The `value=` fallback is what
                         shows before applyI18n() runs, so it must be short too. -->
                    <input type="button" class="button_gen" value="Diagnostics" data-i18n-val="BTN_GET_DIAG" onclick="awgRunDiag(this);" title="Collect a full diagnostic report and copy it together with the log" data-i18n-title="TITLE_GET_DIAG" style="margin-left:auto; font-size:11px; padding:2px 10px; font-weight:normal; text-transform:none; letter-spacing:0;">
                </div>
                <div id="awg_log" class="awg-log" data-i18n="LOG_WAITING">Waiting for data…</div>
                <div style="display:flex; align-items:center; flex-wrap:wrap; gap:2px 10px; font-size:11px; opacity:0.55; margin-top:4px;">
                    <span style="margin-left:auto; text-align:right;">
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
                <option value="file" data-i18n="OPT_INSTALL_FILE">From a local file (over SSH)</option>
            </select>
            <input type="text" id="awg_version_input" placeholder="e.g. 1.1.49" data-i18n-ph="PH_VERSION" maxlength="12" class="awg-modal-input" aria-label="Version to install" data-i18n-aria="ARIA_VERSION_TO_INSTALL" style="width:100px; display:none;">
            <input type="button" id="awg_install_btn" class="button_gen" value="Install" data-i18n-val="BTN_INSTALL" onclick="installUpdate();">
        </div>
        <div id="awg_file_help" style="display:none; padding:0 18px 12px; font-size:12px; line-height:1.55;"></div>
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
            <input type="button" class="button_gen" value="Download .txt" data-i18n-val="BTN_DOWNLOAD_DIAG" title="Download the diagnostics and the log as a .txt file" data-i18n-title="TITLE_DOWNLOAD_DIAG" onclick="awgDownloadDiagReport(this);">
            <button type="button" id="awg_diag_copy_btn" onclick="awgCopyDiagReport(this);" title="Copy to clipboard (for Telegram)" data-i18n-title="BTN_COPY_DIAG_MINI" aria-label="Copy to clipboard" data-i18n-aria="BTN_COPY_DIAG_MINI" style="display:inline-flex; align-items:center; justify-content:center; width:30px; height:30px; padding:0; background:transparent; border:1px solid #666; border-radius:5px; color:inherit; cursor:pointer; flex:0 0 auto;">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
            </button>
            <span id="awg_diag_note" style="font-size:11px; color:#f0ad4e;"></span>
            <span style="font-size:11px; opacity:0.7;" data-i18n="DIAG_DOWNLOAD_NOTE">Saves the diagnostics + log as a .txt file. Or copy (📋) to paste into Telegram.</span>
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
                    <th style="width:150px;" data-i18n="ANALYZE_COL_OWNER">Owner</th>
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
