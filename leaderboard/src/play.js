import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { escapeHtml } from "./html.js";

const here = path.dirname(fileURLToPath(import.meta.url));

export function loadExerciseHtml() {
  const candidates = [
    path.resolve(here, "../../exercise.html"),
    path.resolve(here, "../content/exercise.html"),
  ];
  for (const file of candidates) {
    if (existsSync(file)) return readFileSync(file, "utf8");
  }
  throw new Error("exercise.html not found — copy it to leaderboard/content/exercise.html");
}

export function wrapPlayPage(raw, { teamName, step, ticks, uploaded, notice, error }) {
  const boot = `<script>
window.__SERVER_STEP__ = ${JSON.stringify(step || "")};
window.__SERVER_TICKS__ = ${JSON.stringify(ticks || {})};
window.__PLAY__ = true;
window.__UPLOADED__ = ${uploaded ? "true" : "false"};
(function () {
  var queue = [];
  function send(body) {
    fetch("/api/progress", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: body,
      credentials: "same-origin",
      keepalive: true
    }).catch(function () { queue.push(body); });
  }
  window.onExerciseProgress = function (state) {
    var body = JSON.stringify(state);
    if (navigator.onLine === false) { queue.push(body); return; }
    send(body);
  };
  window.addEventListener("online", function () {
    while (queue.length) send(queue.shift());
  });
  setInterval(function () {
    if (typeof window.onExerciseProgress === "function") {
      var ticks = {};
      document.querySelectorAll("ul.check input[type=checkbox]").forEach(function (b) {
        if (b.checked && b.dataset.k) ticks[b.dataset.k] = 1;
      });
      window.onExerciseProgress({ step: (location.hash || "").slice(1), ticks: ticks });
    }
  }, 15000);
})();
</script>`;

  const team = `<div id="team-slot" class="team-slot">
  <strong>${escapeHtml(teamName)}</strong>
  <span class="team-links">
    <a href="/wall">The wall</a>
    ·
    <form method="post" action="/leave" style="display:inline">
      <button type="submit" class="linkish">Wrong team?</button>
    </form>
  </span>
</div>`;

  const playCss = `<style>
.flash { padding-top: 1rem; }
.flash .error, .flash .ok { font-size: 1.15rem; }
</style>`;

  const status = error
    ? `<div class="flash"><p class="error" role="alert">${escapeHtml(error)}</p></div>`
    : notice
      ? `<div class="flash"><p class="ok" role="status">${escapeHtml(notice)}</p></div>`
      : "";

  let html = raw;
  html = html.replace('<html lang="en-GB">', '<html lang="en-GB" class="play">');
  html = html.replace("</head>", `${boot}\n${playCss}\n</head>`);
  html = html.replace('<div id="team-slot" class="team-slot" hidden></div>', team);
  html = html.replace('<div class="wrap" id="main">', `${status}<div class="wrap" id="main">`);
  html = html.replace(
    '<form id="shot-form">',
    '<form id="shot-form" method="post" action="/play/screenshot" enctype="multipart/form-data">',
  );
  html = html.replace(
    'id="screenshot-file"',
    uploaded
      ? 'id="screenshot-file" name="screenshot"'
      : 'id="screenshot-file" name="screenshot" required',
  );
  return html;
}
