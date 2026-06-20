/* AmneziaWG — глобальный индикатор в шапке роутера.
 * Отдаётся как /www/user/awg_widget.js и подгружается на каждой странице
 * прошивки крошечным загрузчиком, добавленным в menuTree.js.
 *
 * Показывает иконку Amnezia рядом с иконками шапки (QoS и т.п.) на цветном фоне:
 * зелёный — включён, красный — выключен, жёлтый — переключение.
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
      on:      "Включён",
      off:     "Выключен",
      moving:  "Переключение…",
      unknown: "Статус неизвестен",
      addr:    "Адрес",
      hs:      "Рукопожатие",
      turnOn:  "Включить",
      turnOff: "Выключить",
      settings:"Открыть настройки →",
      tipOn:   "AmneziaWG VPN: включён",
      tipOff:  "AmneziaWG VPN: выключен",
      tipMv:   "AmneziaWG VPN: переключение…",
      tipUnk:  "AmneziaWG VPN: статус неизвестен"
    };

    // Amnezia icon (same image as the addon page header), embedded so the widget needs no
    // network. Replaces the old "AWG" text in the header indicator; the pill background shows
    // status (green = on, red = off).
    var AWG_ICON = "data:image/png;base64,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";

    function $(id) { return document.getElementById(id); }

    function injectStyle() {
      if ($("awgWidgetStyle")) return;
      var st = document.createElement("style");
      st.id = "awgWidgetStyle";
      st.textContent =
        "#awgHeaderInd{display:inline-flex;align-items:center;gap:5px;cursor:pointer;" +
        "font:11px/1 Arial,Helvetica,sans-serif;color:#fff;padding:2px 6px;margin:0 8px 0 0;" +
        "border-radius:11px;background:#6b7a80;vertical-align:middle;white-space:nowrap;" +
        "user-select:none;-webkit-user-select:none;}" +
        "#awgHeaderInd.awg-on {background:#2a8b42;}" +
        "#awgHeaderInd.awg-off{background:#b23030;}" +
        "#awgHeaderInd.awg-mv {background:#b8860b;}" +
        "#awgHeaderInd .awg-ico{width:16px;height:16px;border-radius:50%;display:block;flex:0 0 auto;" +
        "box-shadow:0 0 3px rgba(0,0,0,.35);}" +
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
      d.innerHTML = '<img class="awg-ico" src="' + AWG_ICON + '" alt="AWG">';
      d.onclick = function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        togglePanel();
      };
      return d;
    }

    function placeIndicator(d) {
      // Leftmost slot of the status-icon row. We deliberately do NOT anchor to a
      // specific icon (QoS, wifi, usb…) — any of those can be hidden or absent
      // depending on the router config, so the first slot is the only reliable target.

      // 1) ROG / flex theme (GT-AX11000 etc.): a #status_block flex container.
      var block = document.getElementById("status_block");
      if (block) {
        try { block.insertBefore(d, block.firstChild); return; } catch (e) {}
      }

      // 2) Classic / table theme (RT-AC68U, RT-AX88U etc.): icons are <td> cells in a
      //    <tr>. Insert a leading <td> right after the title cell so the badge is the
      //    first icon — a bare <div> can't be a direct <tr> child.
      var row = findIconRow();
      if (row) {
        try {
          var td = document.createElement("td");
          td.style.width = "auto";
          td.style.verticalAlign = "middle";
          td.appendChild(d);
          var cells = row.children;
          var ref = (cells && cells.length > 1) ? cells[1] : null; // after the leading title cell
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

    function renderPanel() {
      var p = $("awgPanel");
      if (!p) return;
      var s = curState();
      p.className = p.className.replace(/\bawg-(on|off|mv)\b/g, "").replace(/\s+/g, " ").replace(/^\s|\s$/g, "");
      var stText = $("awgStText"), rows = $("awgRows"), btn = $("awgActBtn");

      if (s === "mv") { p.className += " awg-mv"; stText.textContent = T.moving; }
      else if (s === "on") { p.className += " awg-on"; stText.textContent = T.on; }
      else if (s === "off") { p.className += " awg-off"; stText.textContent = T.off; }
      else { stText.textContent = T.unknown; }

      // строки быстрой информации — только когда туннель поднят
      rows.innerHTML = "";
      if (s === "on" && lastData) {
        if (lastData.interface_addr) {
          rows.innerHTML += '<div class="awg-row">' + T.addr + ': <b>' + esc(lastData.interface_addr) + '</b></div>';
        }
        var hs = (lastData.peers && lastData.peers[0] && lastData.peers[0].latest_handshake) || "";
        if (hs) {
          rows.innerHTML += '<div class="awg-row">' + T.hs + ': <b>' + esc(hs) + '</b></div>';
        }
      }

      // кнопка действия
      if (s === "mv") {
        btn.disabled = true;
        btn.className = "awg-act on";
        btn.textContent = T.moving;
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
