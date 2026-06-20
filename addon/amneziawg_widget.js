/* AmneziaWG — глобальный индикатор в шапке роутера.
 * Отдаётся как /www/user/awg_widget.js и подгружается на каждой странице
 * прошивки крошечным загрузчиком, добавленным в menuTree.js.
 *
 * Показывает иконку Amnezia рядом с иконками шапки (QoS и т.п.). Сам значок меняет
 * цвет по статусу: зелёный — включён, красный — выключен, жёлтый — переключение,
 * серый — статус неизвестен. Без подложки — как штатные иконки прошивки.
 * По клику открывается мини-панель: статус, адрес/рукопожатие и кнопка
 * «Включить»/«Выключить» туннеля awg0 — глобально, с любой страницы.
 *
 * Только ES5 (старые браузеры в прошивке). Весь код в try/catch — он не должен
 * ломать страницу прошивки ни при каких обстоятельствах.
 */
(function () {
  "use strict";
  try {
    if (window.__awgWidgetLoaded) return;
    window.__awgWidgetLoaded = 1;

    var POLL_MS = 10000;   // пассивный опрос статуса (только чтение, без записи на флеш)
    var FAST_MS = 2000;    // частый опрос во время переключения
    var TRANSITION_MAX = 180000; // 3 мин — предохранитель от «зависшего» статуса

    var lastRunning = null;     // null = неизвестно
    var lastData = null;        // последний разобранный JSON статуса
    var transitioning = false;  // идёт инициированное нами переключение
    var expectRunning = false;  // ожидаемое running после переключения

    var T = {
      title:   "AmneziaWG VPN",
      on:      "Подключено",
      off:     "Остановлено",
      starting:"Подключение…",
      stopping:"Остановка…",
      unknown: "Статус неизвестен",
      addr:    "Адрес",
      hs:      "Рукопожатие",
      turnOn:  "Запустить",
      turnOff: "Остановить",
      settings:"Открыть настройки →",
      tipOn:   "AmneziaWG VPN: подключено",
      tipOff:  "AmneziaWG VPN: остановлено",
      tipMv:   "AmneziaWG VPN: переключение…",
      tipUnk:  "AmneziaWG VPN: статус неизвестен"
    };

    // Amnezia "A" logo as a single-path monochrome vector, taken from the Android app's
    // ic_icon/ic_tile drawable (the glyph drawn in the notification shade / quick-settings).
    // Inline SVG (not an <img>) so CSS can tint it: fill follows currentColor, and the
    // indicator sets that colour per status (green = on, red = off, amber = switching, grey =
    // unknown) — a bare glyph with no background, matching the firmware's own header icons.
    // The colourful PNG used as the "open site" link on the addon page is a different image,
    // left untouched.
    var AWG_ICON =
      '<svg class="awg-ico" viewBox="0 0 568 568" xmlns="http://www.w3.org/2000/svg" ' +
      'aria-hidden="true" focusable="false"><path fill="currentColor" d="M472.8,24.2c-4.1,5.6 -9.5,14.9 -12.9,22.8 -2.9,6.6 -8.2,16.3 -16.3,29.8 -4.8,8 -14.3,8.9 -20.7,2.1 -2.6,-2.8 -8.9,-18.2 -8.9,-21.8 0,-7.2 -11,-8.5 -23,-2.7 -9.5,4.6 -12.6,4.6 -27,-0.5 -22.2,-7.8 -37.2,-11.8 -52,-13.9 -3.9,-0.6 -10.2,-1.5 -14,-2 -17.1,-2.4 -71,-0.1 -85,3.7 -12.1,3.3 -37.4,15.4 -54.9,26.3 -11.1,6.9 -13.4,8 -17.3,8 -4.5,0 -4.7,0.1 -12.2,9 -7.3,8.5 -16.2,16.8 -17.1,15.9 -0.2,-0.3 -0.9,-3.6 -1.5,-7.4 -2.3,-15.1 -12,-40.1 -20.3,-52.5 -1.8,-2.6 -3.7,-5.5 -4.3,-6.5 -1.6,-2.9 -3.2,-1 -5.4,6.4 -2.2,7.2 -2.5,16.5 -2.1,72.9 0.2,22.8 0,23.5 -10.7,37.1 -15.5,19.6 -29.9,54.7 -32.7,79.6 -0.8,7.1 -2.4,21.8 -3.7,32.5 -3.6,31.1 -3.5,35.3 1.4,53 1.1,4.1 3.1,11.4 4.4,16.1 1.2,4.8 4.4,13.3 7,19 2.5,5.7 5.9,13.6 7.4,17.5 12.3,30.9 53.6,76.9 79.9,89.1 23.9,11 29.5,15.2 34.1,25.4 1.4,2.9 4,8.3 5.8,11.9 1.9,3.6 6.7,14.3 10.8,23.8 18.9,44 22.8,45.4 29.8,11.1 7.3,-36.1 12.4,-39.7 49.9,-35.4 14.5,1.6 16.1,1.6 30.2,0 36.7,-4.1 35.8,-4.5 42.5,16.5 1.6,5.2 3,11.1 3,13.2s1.2,6.8 2.7,10.5c9.1,23.2 19,22.8 26.9,-0.9 1.5,-4.6 3.5,-9.4 4.4,-10.8s4.5,-8.1 7.9,-15c3.3,-6.9 7.8,-14.6 9.9,-17.2 16.9,-21.2 46.1,-47.9 73.6,-67.3 6.5,-4.6 17.5,-17.5 21.3,-24.9 1.4,-2.8 5.6,-9.7 9.3,-15.3 7.6,-11.4 12.1,-23.6 16.5,-44.6 1.4,-7.1 4,-15.3 6.4,-20.7 8.8,-19.7 11.5,-41.1 6.7,-51.6 -5.8,-12.5 -9.5,-53.5 -6.6,-71.9 2.1,-13.3 2.8,-25.5 1.9,-29.1 -1.1,-3.7 -9.1,-8.4 -14.4,-8.4 -8.9,0 -23.5,-15.2 -23.5,-24.4 0,-0.8 -2.2,-5.8 -5,-11 -5.6,-10.7 -5.8,-12.1 -3,-23.5 4.9,-19.7 8.3,-73 4.8,-75.9 -1.3,-1 -1.9,-0.7 -4,2M305.3,85.5c15.4,1.2 29.5,5.6 47.1,14.6 9.5,5 20.1,8.9 24.1,8.9 4.2,0 35.9,20.9 38,25.1 1.9,3.6 1.9,7.6 0,13 -0.9,2.4 -1.3,5.4 -1,6.6s0,4.4 -0.6,7c-2.5,11.2 -4,21.7 -4.9,35.8 -0.6,8.2 -1.9,20.2 -3.1,26.5 -1.1,6.3 -2.6,16.2 -3.3,22 -1.7,13.4 -4.1,25.4 -7,35.5 -4.2,14.1 -7.4,26.9 -8,31.5 -0.4,2.5 -2,9.9 -3.5,16.5 -1.6,6.6 -3.5,16.3 -4.1,21.5 -2.7,21.7 -10.3,50.7 -16.5,63 -5.4,10.5 -8.8,14 -11.4,11.6 -2.3,-2.1 -8.1,-16.2 -8.1,-19.8 0,-1.3 -1.2,-5 -2.6,-8.3s-3.6,-9.8 -4.8,-14.5c-1.3,-4.7 -3.2,-10.3 -4.3,-12.5s-2.4,-5.1 -2.8,-6.5 -2.5,-6.3 -4.7,-10.9c-5.7,-12.2 -8.5,-21.6 -9.3,-30.6 -0.8,-9.7 -1.8,-13.7 -5.6,-23.8 -1.6,-4.3 -3.6,-12.2 -4.4,-17.5s-2.2,-14.4 -3.1,-20.2c-1.7,-12.1 -2.5,-15.3 -6.4,-27 -3.6,-10.8 -8.2,-25.5 -11,-34.6 -3.6,-12.1 -4,-12.2 -8.9,-0.3 -5.7,14.1 -12.9,36.3 -14.6,45.2 -2.9,15.6 -8.1,40.7 -10.5,50.7 -1,4.1 -2.6,11.5 -3.5,16.5 -0.9,4.9 -3.2,12.8 -5.1,17.5 -5.4,12.9 -7.3,18 -9.4,24 -9.8,29.2 -25.8,73.1 -27.6,75.8 -2.4,3.7 -7.1,2.7 -11,-2.5 -4.5,-5.9 -7.6,-14.7 -13.9,-39.3 -3,-11.8 -6.6,-25.6 -8,-30.5 -4.8,-16.8 -10.5,-38.9 -15,-58.5 -2.4,-10.7 -5.2,-22.4 -6.1,-26 -1.6,-6.7 -4.5,-19.2 -8.8,-38.5 -1.4,-6.1 -3.2,-15.5 -4.1,-21s-2.2,-12.9 -3,-16.5 -1.9,-10.1 -2.5,-14.5 -2,-11.2 -3.1,-15.2c-1.1,-3.9 -2.4,-10.2 -3,-14 -0.5,-3.7 -1.2,-8.2 -1.5,-10 -1.6,-8.9 29.9,-30.1 58.6,-39.6 37.3,-12.2 56.4,-15.9 83.7,-16.1 11.7,-0.1 21.6,-0.5 22,-1 0.4,-0.4 2.8,-0.5 5.3,-0.2s7.5,0.8 11.3,1.1m146.9,111.2c22.3,23 22.4,98.5 0.3,144.8 -2.9,6 -6.2,13.9 -7.4,17.3 -8.3,24.4 -39.3,60.8 -44.6,52.2 -0.7,-1.1 4,-17.4 5.9,-20.5 2.2,-3.5 5.2,-17.2 6.1,-27.5 0.8,-9.2 3,-20.1 6.1,-30 1.3,-4.1 2.6,-9.5 3,-12s2.2,-10.2 4,-17.2 4,-17.8 4.8,-24 2.2,-14.6 3.1,-18.7c1.5,-7.1 2.4,-12.1 6,-35.6 0.8,-5.5 2.4,-12.7 3.5,-15.9 1.1,-3.3 2,-8.3 2,-11.1 0,-8.1 0.9,-8.3 7.2,-1.8m-361.5,3.8c4.9,8.5 8.8,18.1 12.8,31 4.9,16.2 7.7,23.9 11,30.5 5.6,11 11.7,32.9 16.4,58.5 1.1,6 2.9,15.3 4.1,20.5 3.8,17.3 3,56.1 -1.2,61.6 -7.8,9.9 -33,-7.3 -47.1,-32.1 -1.9,-3.3 -5.5,-9.4 -8,-13.5 -5.1,-8.2 -14.5,-30 -18.4,-42.5 -4.3,-13.7 -1.7,-66.3 4,-82C68.9,219.9 83.6,193 86,193c0.3,0 2.4,3.4 4.7,7.5m191,108.1c1.2,3.2 3.1,9.5 4.2,13.9s3.5,13.2 5.2,19.5c1.8,6.3 3.5,14.2 3.9,17.5 0.5,3.3 1.7,9.1 2.8,13 3.6,12.4 10.3,35.8 12.2,43 7.6,27.7 -17.3,46.3 -52.2,39 -4,-0.9 -8.3,-1.3 -9.6,-1 -3,0.7 -8.1,-2.4 -11.6,-7l-2.7,-3.5 4,-8.6c2.2,-4.7 4.5,-11.3 5.2,-14.7 0.6,-3.4 1.9,-8.2 2.9,-10.7 2.3,-6 6.2,-20.6 9.5,-36 6.4,-29.5 9.3,-40.2 14.3,-51.6 1.7,-3.8 3.7,-9.2 4.6,-11.9 0.9,-2.8 1.9,-5.6 2.1,-6.3 0.9,-2.6 3,-0.5 5.2,5.4"/></svg>';

    function $(id) { return document.getElementById(id); }

    function injectStyle() {
      if ($("awgWidgetStyle")) return;
      var st = document.createElement("style");
      st.id = "awgWidgetStyle";
      st.textContent =
        "#awgHeaderInd{display:inline-flex;align-items:center;cursor:pointer;" +
        "color:#9aa3a8;margin:0 4px 0 0;vertical-align:middle;line-height:0;" +
        "user-select:none;-webkit-user-select:none;}" +
        "#awgHeaderInd.awg-on {color:#3fbf3f;}" +
        "#awgHeaderInd.awg-off{color:#e04545;}" +
        "#awgHeaderInd.awg-mv {color:#e0a020;}" +
        "#awgHeaderInd .awg-ico{width:22px;height:22px;display:block;flex:0 0 auto;" +
        "fill:currentColor;}" +
        // Classic (table) theme: native sprite icons have built-in padding, so the solid
        // glyph reads a touch larger — trim to 20px; sit it on the right of the cluster.
        "#awgHeaderInd.awg-classic{margin:0 0 0 6px;}" +
        "#awgHeaderInd.awg-classic .awg-ico{width:20px;height:20px;}" +
        "#awgHeaderInd.awg-fixed{position:fixed;top:8px;right:12px;z-index:99999;}" +
        "#awgPanel{position:fixed;z-index:100000;display:none;min-width:210px;" +
        "background:#2b3a41;color:#e8e8e8;border:1px solid #4a5a62;border-radius:6px;" +
        "box-shadow:0 6px 20px rgba(0,0,0,.45);font:12px/1.4 Arial,Helvetica,sans-serif;" +
        "padding:10px 12px;}" +
        "#awgPanel .awg-h{font-weight:bold;font-size:13px;margin-bottom:6px;letter-spacing:.5px;}" +
        "#awgPanel .awg-st{display:flex;align-items:center;gap:6px;margin-bottom:8px;font-weight:bold;}" +
        "#awgPanel .awg-st .awg-d{width:10px;height:10px;border-radius:50%;background:#888;flex:0 0 auto;}" +
        "#awgPanel.awg-on  .awg-st .awg-d{background:#3fbf3f;}" +
        "#awgPanel.awg-off .awg-st .awg-d{background:#e04545;}" +
        "#awgPanel.awg-mv  .awg-st .awg-d{background:#e0a020;}" +
        "#awgPanel .awg-row{color:#bcc8ce;margin:2px 0;}" +
        "#awgPanel .awg-row b{color:#e8e8e8;font-weight:normal;}" +
        "#awgPanel .awg-act{display:block;width:100%;box-sizing:border-box;margin-top:10px;" +
        "padding:7px 0;border:0;border-radius:4px;color:#fff;font-weight:bold;font-size:12px;" +
        "cursor:pointer;text-align:center;}" +
        "#awgPanel .awg-act.on{background:#2a8b42;}" +
        "#awgPanel .awg-act.off{background:#b23030;}" +
        "#awgPanel .awg-act[disabled]{background:#6b7a80;cursor:default;}" +
        "#awgPanel .awg-link{display:block;margin-top:8px;font-size:11px;color:#8fc7e6;" +
        "text-decoration:none;}";
      (document.head || document.documentElement).appendChild(st);
    }

    function closestTd(el) {
      var n = el;
      while (n && n.nodeType === 1) {
        if (n.tagName === "TD") return n;
        n = n.parentNode;
      }
      return null;
    }

    // Classic (non-ROG) themes lay the status icons out as <td> cells in a <tr>
    // rather than a flex #status_block. Locate that row via a known status icon.
    function findIconRow() {
      var ids = ["notification_status1", "bwdpi_status", "wifi_hw_sw_status",
                 "connect_status", "usb_status"];
      for (var i = 0; i < ids.length; i++) {
        var el = document.getElementById(ids[i]);
        if (!el) continue;
        var td = (el.tagName === "TD") ? el : closestTd(el);
        if (td && td.parentNode && td.parentNode.tagName === "TR") return td.parentNode;
      }
      return null;
    }

    function buildIndicator() {
      var d = $("awgHeaderInd");
      if (d) return d;
      d = document.createElement("div");
      d.id = "awgHeaderInd";
      d.title = T.tipUnk;
      d.innerHTML = AWG_ICON;
      d.onclick = function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        togglePanel();
      };
      return d;
    }

    function placeIndicator(d) {
      // Place next to the native status icons without anchoring to a specific one
      // (QoS, wifi, usb… can each be hidden or absent depending on router config) — we
      // target an EDGE of the icon row instead.

      // 1) ROG / flex theme (GT-AX11000 etc.): a #status_block flex container.
      var block = document.getElementById("status_block");
      if (block) {
        try { block.insertBefore(d, block.firstChild); return; } catch (e) {}
      }

      // 2) Classic / table theme (RT-AC68U, RT-AX88U etc.): icons are <td> cells in a
      //    <tr> that also holds the title cell (Режим/Firmware/SSID) on the left with an
      //    auto width that eats the leftover space. A LEADING cell would float far from the
      //    icon cluster (the empty notification cell widens the gap), so we join the cluster
      //    at its RIGHT edge: insert just before the trailing spacer cell (or append). A bare
      //    <div> can't be a direct <tr> child, so it goes in its own <td>.
      var row = findIconRow();
      if (row) {
        try {
          if (d.className.indexOf("awg-classic") === -1) d.className += " awg-classic";
          var td = document.createElement("td");
          td.style.verticalAlign = "middle";
          td.appendChild(d);
          var cells = row.children;
          var ref = null; // default: append at the end of the row
          if (cells.length) {
            var last = cells[cells.length - 1];
            var lw = parseInt(last.getAttribute("width") || last.style.width || "0", 10);
            if (lw && lw <= 20) ref = last; // tuck in before a narrow trailing spacer (e.g. width=17)
          }
          row.insertBefore(td, ref);
          return;
        } catch (e) {}
      }

      // 3) Unknown theme: floating pill, top-right (predictable, never mis-anchored).
      if (d.className.indexOf("awg-fixed") === -1) d.className += " awg-fixed";
      document.body.appendChild(d);
    }

    function buildPanel() {
      var p = $("awgPanel");
      if (p) return p;
      p = document.createElement("div");
      p.id = "awgPanel";
      p.innerHTML =
        '<div class="awg-h">' + T.title + '</div>' +
        '<div class="awg-st"><span class="awg-d"></span><span id="awgStText">' + T.unknown + '</span></div>' +
        '<div id="awgRows"></div>' +
        '<button type="button" id="awgActBtn" class="awg-act on">' + T.turnOn + '</button>' +
        '<a id="awgSettingsLink" class="awg-link" href="#">' + T.settings + '</a>';
      // не закрывать панель по клику внутри неё
      p.onclick = function (e) { if (e) e.stopPropagation(); };
      document.body.appendChild(p);

      $("awgActBtn").onclick = onActionClick;
      var link = $("awgSettingsLink");
      if (window.__awgPage) {
        link.href = "/" + window.__awgPage;
      } else {
        link.style.display = "none";
      }
      return p;
    }

    function positionPanel() {
      var ind = $("awgHeaderInd"), p = $("awgPanel");
      if (!ind || !p) return;
      var r = ind.getBoundingClientRect();
      p.style.top = (r.bottom + 5) + "px";
      // выровнять правый край панели по правому краю значка
      var right = Math.max(6, window.innerWidth - r.right);
      p.style.right = right + "px";
      p.style.left = "auto";
    }

    function isOpen() { var p = $("awgPanel"); return p && p.style.display === "block"; }

    function togglePanel() {
      var p = buildPanel();
      if (isOpen()) { p.style.display = "none"; return; }
      renderPanel();
      p.style.display = "block";
      positionPanel();
    }
    function closePanel() { var p = $("awgPanel"); if (p) p.style.display = "none"; }

    function curState() {
      // 'mv' | 'on' | 'off' | 'unknown'
      if (transitioning) return "mv";
      if (lastData && (lastData.starting === true || lastData.stopping === true)) return "mv";
      if (lastRunning === true) return "on";
      if (lastRunning === false) return "off";
      return "unknown";
    }

    function renderIndicator() {
      var d = $("awgHeaderInd");
      if (!d) return;
      var s = curState();
      d.className = d.className.replace(/\bawg-(on|off|mv)\b/g, "").replace(/\s+/g, " ").replace(/^\s|\s$/g, "");
      if (s === "mv") { d.className += " awg-mv"; d.title = T.tipMv; }
      else if (s === "on") { d.className += " awg-on"; d.title = T.tipOn; }
      else if (s === "off") { d.className += " awg-off"; d.title = T.tipOff; }
      else { d.title = T.tipUnk; }
    }

    // Transient transition label, matching the main UI ("Подключение…" / "Остановка…").
    function mvText() {
      var up = transitioning ? expectRunning : !!(lastData && lastData.starting === true);
      return up ? T.starting : T.stopping;
    }

    function renderPanel() {
      var p = $("awgPanel");
      if (!p) return;
      var s = curState();
      p.className = p.className.replace(/\bawg-(on|off|mv)\b/g, "").replace(/\s+/g, " ").replace(/^\s|\s$/g, "");
      var stText = $("awgStText"), rows = $("awgRows"), btn = $("awgActBtn");

      if (s === "mv") { p.className += " awg-mv"; stText.textContent = mvText(); }
      else if (s === "on") { p.className += " awg-on"; stText.textContent = T.on; }
      else if (s === "off") { p.className += " awg-off"; stText.textContent = T.off; }
      else { stText.textContent = T.unknown; }

      // строки быстрой информации — только когда туннель поднят
      rows.innerHTML = "";
      if (s === "on" && lastData) {
        if (lastData.interface_addr) {
          rows.innerHTML += '<div class="awg-row">' + T.addr + ': <b>' + esc(lastData.interface_addr) + '</b></div>';
        }
        // Compute the handshake age live from the raw epoch the backend emits; fall back to
        // the pre-formatted string for older status files. The panel re-renders on each 10s
        // poll while open, so this recomputes without any extra timer.
        var pe = lastData.peers && lastData.peers[0];
        var hs = (pe && awgComputeAgo(pe.hs_epoch)) || (pe && pe.latest_handshake) || "";
        if (hs) {
          rows.innerHTML += '<div class="awg-row">' + T.hs + ': <b>' + esc(hs) + '</b></div>';
        }
      }

      // кнопка действия
      if (s === "mv") {
        btn.disabled = true;
        btn.className = "awg-act on";
        btn.textContent = mvText();
      } else if (s === "on") {
        btn.disabled = false;
        btn.className = "awg-act off";
        btn.textContent = T.turnOff;
      } else {
        // off или unknown → предлагаем включить
        btn.disabled = false;
        btn.className = "awg-act on";
        btn.textContent = T.turnOn;
      }
    }

    function esc(s) {
      return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Handshake age from a raw UNIX epoch (seconds). Returns null for 0/absent so the caller
    // falls back to the pre-formatted string. Clamps clock skew (client behind router) to 0.
    // Wording matches the addon page / backend so page, widget and fallback all agree.
    function awgComputeAgo(epoch) {
      epoch = parseInt(epoch, 10);
      if (!epoch || epoch <= 0) return null;
      var d = Math.floor(new Date().getTime() / 1000) - epoch;
      if (d < 0) d = 0;
      if (d < 60) return d + " с назад";
      if (d < 3600) return Math.floor(d / 60) + " мин назад";
      return Math.floor(d / 3600) + " ч назад";
    }

    function onActionClick(e) {
      if (e) { e.preventDefault(); e.stopPropagation(); }
      if (transitioning) return;
      var stop = (lastRunning === true);
      expectRunning = !stop;
      transitioning = true;
      renderIndicator();
      renderPanel();
      fire(stop ? "start_awgstop" : "start_awgstart");
      restartTimer(FAST_MS);
      poll(); // быстрый первый опрос после отправки
      setTimeout(function () {
        if (transitioning) { transitioning = false; restartTimer(POLL_MS); poll(); }
      }, TRANSITION_MAX);
    }

    function fire(action) {
      var sink = $("awgWidgetSink");
      if (!sink) {
        sink = document.createElement("iframe");
        sink.name = "awgWidgetSink";
        sink.id = "awgWidgetSink";
        sink.style.display = "none";
        document.body.appendChild(sink);
      }
      var old = $("awgWidgetForm");
      if (old && old.parentNode) old.parentNode.removeChild(old);
      var f = document.createElement("form");
      f.id = "awgWidgetForm";
      f.method = "post";
      f.action = "/start_apply.htm";
      f.target = "awgWidgetSink";
      f.style.display = "none";
      function add(n, v) {
        var i = document.createElement("input");
        i.type = "hidden"; i.name = n; i.value = v; f.appendChild(i);
      }
      add("action_mode", "apply");
      add("action_script", action); // start_awgstart | start_awgstop
      add("action_wait", "15");
      document.body.appendChild(f);
      f.submit();
    }

    function poll() {
      var x = new XMLHttpRequest();
      x.open("GET", "/user/awg_status.htm?_=" + (new Date().getTime()), true);
      x.timeout = 4000;
      x.onload = function () {
        if (x.status !== 200) return;
        try {
          var s = JSON.parse(x.responseText);
          lastData = s;
          lastRunning = (s.running === true);
          if (transitioning && lastRunning === expectRunning) {
            transitioning = false;
            restartTimer(POLL_MS);
          }
          renderIndicator();
          if (isOpen()) renderPanel();
        } catch (e) { /* оставить прежнее состояние */ }
      };
      x.onerror = function () { /* не сбрасывать состояние при разовом сбое */ };
      x.ontimeout = x.onerror;
      x.send();
    }

    function restartTimer(ms) {
      if (window.__awgPollTimer) clearInterval(window.__awgPollTimer);
      window.__awgPollTimer = setInterval(poll, ms);
    }

    function mount(attempt) {
      try {
        if ($("awgHeaderInd")) return; // защита от повторной вставки
        injectStyle();
        var d = buildIndicator();
        placeIndicator(d);
        buildPanel();
        // закрытие панели по клику вне её / по Esc / при прокрутке-ресайзе
        document.addEventListener("click", function () { if (isOpen()) closePanel(); }, false);
        document.addEventListener("keydown", function (e) { if (e && e.keyCode === 27) closePanel(); }, false);
        window.addEventListener("resize", function () { if (isOpen()) positionPanel(); }, false);
        poll();
        restartTimer(POLL_MS);
      } catch (e) {
        if ((attempt || 0) < 5) {
          setTimeout(function () { mount((attempt || 0) + 1); }, 600);
        }
      }
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", function () { mount(0); }, false);
    } else {
      mount(0);
    }
  } catch (e) { /* никогда не ломаем страницу прошивки */ }
})();
