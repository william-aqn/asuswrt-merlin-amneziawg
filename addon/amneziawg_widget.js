/* AmneziaWG — глобальный индикатор в шапке роутера.
 * Отдаётся как /www/user/awg_widget.js и подгружается на каждой странице
 * прошивки крошечным загрузчиком, добавленным в menuTree.js.
 *
 * Показывает цветную точку статуса + «AWG» рядом с иконками шапки (QoS и т.п.).
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

    function $(id) { return document.getElementById(id); }

    function injectStyle() {
      if ($("awgWidgetStyle")) return;
      var st = document.createElement("style");
      st.id = "awgWidgetStyle";
      st.textContent =
        "#awgHeaderInd{display:inline-flex;align-items:center;gap:5px;cursor:pointer;" +
        "font:11px/1 Arial,Helvetica,sans-serif;color:#e8e8e8;padding:3px 8px;margin:0 5px;" +
        "border-radius:11px;background:rgba(0,0,0,.30);vertical-align:middle;white-space:nowrap;" +
        "user-select:none;-webkit-user-select:none;}" +
        "#awgHeaderInd .awg-dot{width:9px;height:9px;border-radius:50%;background:#888;" +
        "box-shadow:0 0 4px rgba(0,0,0,.4);flex:0 0 auto;}" +
        "#awgHeaderInd.awg-on  .awg-dot{background:#3fbf3f;}" +
        "#awgHeaderInd.awg-off .awg-dot{background:#e04545;}" +
        "#awgHeaderInd.awg-mv  .awg-dot{background:#e0a020;}" +
        "#awgHeaderInd .awg-label{font-weight:bold;letter-spacing:.5px;}" +
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

    function findContainer() {
      var sels = [
        "#statusicon", ".statusbar", "#status_icon", ".status_icon",
        "#topbar", ".topbar", ".top_bar",
        "#TopBanner .product", "#TopBanner"
      ];
      for (var i = 0; i < sels.length; i++) {
        var el = document.querySelector(sels[i]);
        if (el) return el;
      }
      return null;
    }

    function buildIndicator() {
      var d = $("awgHeaderInd");
      if (d) return d;
      d = document.createElement("div");
      d.id = "awgHeaderInd";
      d.title = T.tipUnk;
      d.innerHTML = '<span class="awg-dot"></span><span class="awg-label">AWG</span>';
      d.onclick = function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        togglePanel();
      };
      return d;
    }

    function placeIndicator(d) {
      var c = findContainer();
      if (c) { try { c.appendChild(d); return; } catch (e) {} }
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
