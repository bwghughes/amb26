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

  const banner = `<div class="team-bar" role="region" aria-label="Your team">
  <strong>${escapeHtml(teamName)}</strong>
  <span>Keep this tab open when you turn Wi-Fi off. Progress syncs when you're back.</span>
  <span class="team-bar-links">
    <a href="/wall">The wall</a>
    ·
    <form method="post" action="/leave" style="display:inline">
      <button type="submit" class="linkish">Not this team</button>
    </form>
  </span>
</div>
<style>
.team-bar {
  position: sticky; top: 0; z-index: 6;
  display: flex; gap: .75rem; align-items: baseline; flex-wrap: wrap;
  margin: 0 -1.25rem 0; padding: .45rem 1.25rem;
  background: var(--card); border-bottom: 1px solid var(--line);
  font-size: .9rem;
}
.team-bar span { color: var(--ink-dim); }
.team-bar-links { margin-left: auto; }
.team-bar button.linkish {
  background: none; border: 0; padding: 0; color: var(--link);
  font: inherit; cursor: pointer; text-decoration: underline;
}
.toolbar { top: 2.4rem; }
.error {
  background: #fbeeda; border-left: 4px solid var(--gold);
  border-radius: 8px; padding: .8rem 1rem;
}
.ok {
  background: #e8f4f5; border-left: 4px solid var(--teal);
  border-radius: 8px; padding: .8rem 1rem;
}
form label { display: block; font-weight: 650; margin: 0 0 .35rem; }
form input[type="file"] { display: block; margin: 0 0 .6rem; }
</style>`;

  const status = error
    ? `<p class="error" role="alert" style="margin: .75rem 1.25rem">${escapeHtml(error)}</p>`
    : notice
      ? `<p class="ok" role="status" style="margin: .75rem 1.25rem">${escapeHtml(notice)}</p>`
      : "";

  const upload = uploaded
    ? `<h3>Upload it</h3>
<p class="ok" role="status">It's on the wall. You can replace it with a better crop if you need to.</p>
<form method="post" action="/play/screenshot" enctype="multipart/form-data">
  <label for="screenshot">Replace screenshot</label>
  <input id="screenshot" name="screenshot" type="file" accept="image/png,image/jpeg,image/webp">
  <p class="hint">⌘⇧4, then Space, click the window. All three panes should show content.</p>
  <button class="btn" type="submit">Replace</button>
</form>
<p><a href="/wall">See the wall</a></p>
<h3>Before you move on</h3>`
    : `<h3>Upload it</h3>
<p>You're already signed in as <b class="ui">${escapeHtml(teamName)}</b>. Turn Wi-Fi back on, then attach the PNG from your Desktop.</p>
<form method="post" action="/play/screenshot" enctype="multipart/form-data">
  <label for="screenshot">Screenshot of the app window</label>
  <input id="screenshot" name="screenshot" type="file" accept="image/png,image/jpeg,image/webp" required>
  <p class="hint">⌘⇧4, then Space, click the window. All three panes should show content.</p>
  <button class="btn" type="submit">Publish screenshot</button>
</form>
<h3>Before you move on</h3>`;

  let html = raw;
  html = html.replace("</head>", `${boot}\n</head>`);
  html = html.replace('<div class="wrap">', `${banner}${status}<div class="wrap">`);
  html = html.replace(
    /<h3>Upload it<\/h3>[\s\S]*?<h3>Before you move on<\/h3>/,
    upload,
  );
  return html;
}
