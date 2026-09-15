import { createHmac } from "node:crypto";
import { PLAY_STEPS, stepIndex, stepLabel, tickCount } from "./steps.js";

const mosaicVars = `
:root {
  --cream: #fef6ed;
  --blue: #1f73a0;
  --teal: #37afb6;
  --green: #6c946b;
  --gold: #cc973d;
  --gold-light: #e2b14d;
  --taupe: #bfae8b;
  --bg: var(--cream);
  --card: #fffdf9;
  --ink: #23323c;
  --ink-dim: #6f6757;
  --line: #ecdfcc;
  --gold-ink: #7a5518;
  --link: #175f83;
  --radius: 14px;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #16222a;
    --card: #1e2c35;
    --ink: #fef6ed;
    --ink-dim: #a89e8c;
    --line: #33454f;
    --gold-ink: var(--gold-light);
    --link: #7fd0dd;
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font: 17px/1.55 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
}
.wrap { max-width: 72rem; margin: 0 auto; padding: 1.5rem 1.25rem 4rem; }
.wrap.narrow { max-width: 28rem; }
header.top { text-align: center; margin-bottom: 1.5rem; }
.eyebrow {
  font: 700 .74rem/1 inherit; letter-spacing: .16em; text-transform: uppercase;
  color: var(--gold-ink); margin: 0 0 .7rem;
}
h1 { font-size: 2.1rem; line-height: 1.12; margin: 0 0 .35rem; letter-spacing: -.025em; }
.sub { color: var(--ink-dim); margin: 0 auto; max-width: 34rem; }
nav.links { display: flex; gap: .75rem; justify-content: center; margin: 1rem 0 0; flex-wrap: wrap; }
a { color: var(--link); }
.btn {
  display: inline-block;
  font: 600 .95rem/1 inherit;
  color: var(--cream);
  background: var(--blue);
  border: 0;
  border-radius: 8px;
  padding: .7rem 1rem;
  text-decoration: none;
  cursor: pointer;
}
.btn.ghost {
  background: transparent;
  color: var(--ink);
  border: 1px solid var(--line);
}
.btn.small { padding: .35rem .65rem; font-size: .85rem; }
.btn.danger { background: #9a3b2f; color: #fffdf9; }
form.inline { display: inline; }
.card {
  background: var(--card);
  border: 1px solid var(--line);
  border-top: 3px solid var(--teal);
  border-radius: var(--radius);
  padding: 1.25rem 1.4rem 1.4rem;
  margin: 0 auto 1.25rem;
  max-width: 28rem;
}
label { display: block; font-weight: 650; margin: 0 0 .35rem; }
input[type="text"], input[type="password"], input[type="file"] {
  width: 100%;
  font: inherit;
  padding: .55rem .7rem;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--bg);
  color: var(--ink);
  margin-bottom: 1rem;
}
.hint { font-size: .85rem; color: var(--ink-dim); margin: -.5rem 0 1rem; }
.error {
  background: #fbeeda;
  border-left: 4px solid var(--gold);
  border-radius: 8px;
  padding: .8rem 1rem;
  margin: 0 0 1rem;
}
.ok {
  background: #e8f4f5;
  border-left: 4px solid var(--teal);
  border-radius: 8px;
  padding: .8rem 1rem;
  margin: 0 0 1rem;
}
.wall {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(18rem, 1fr));
  gap: 1rem;
}
figure {
  margin: 0;
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  overflow: hidden;
}
figure img {
  display: block;
  width: 100%;
  height: 14rem;
  object-fit: cover;
  background: #0f1c23;
}
figcaption { padding: .7rem .9rem .9rem; }
figcaption strong { display: block; }
figcaption span { color: var(--ink-dim); font-size: .85rem; }
.empty { text-align: center; color: var(--ink-dim); padding: 3rem 1rem; }
table.live { width: 100%; border-collapse: collapse; font-size: .95rem; }
table.live th, table.live td {
  text-align: left; padding: .7rem .55rem; border-bottom: 1px solid var(--line); vertical-align: top;
}
table.live th {
  font-size: .72rem; text-transform: uppercase; letter-spacing: .1em; color: var(--gold-ink);
}
.pips { display: flex; gap: 3px; flex-wrap: wrap; }
.pip {
  width: 11px; height: 11px; border-radius: 99px; background: var(--line);
}
.pip.on { background: var(--teal); }
.pip.now { background: var(--gold); outline: 2px solid var(--gold); outline-offset: 1px; }
.stale { color: var(--ink-dim); }
.live-dot { color: var(--green); font-weight: 700; }
.stats { display: flex; gap: 1.25rem; flex-wrap: wrap; margin: 0 0 1.25rem; color: var(--ink-dim); }
.stats b { color: var(--ink); }
`;

export function adminToken(pin) {
  return createHmac("sha256", pin).update("mib-admin").digest("hex");
}

export function layout({ title, body, heading, sub, nav, wrapClass, extraHead }) {
  return `<!DOCTYPE html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>${mosaicVars}</style>
${extraHead || ""}
</head>
<body>
<div class="wrap${wrapClass ? " " + wrapClass : ""}">
<header class="top">
  <p class="eyebrow">Apple Ambassadors · Barcelona 2026</p>
  <h1>${escapeHtml(heading)}</h1>
  ${sub ? `<p class="sub">${escapeHtml(sub)}</p>` : ""}
  ${nav || ""}
</header>
${body}
</div>
</body>
</html>`;
}

function publicNav() {
  return `<nav class="links">
    <a href="/">Join the contest</a>
    <a href="/wall">The wall</a>
  </nav>`;
}

function adminNav() {
  return `<nav class="links">
    <a href="/admin">Live teams</a>
    <a href="/wall">Leaderboard</a>
    <form method="post" action="/admin/logout" style="display:inline">
      <button class="btn ghost" type="submit">Sign out</button>
    </form>
  </nav>`;
}

export function joinPage({ error, teamName } = {}) {
  const alert = error ? `<p class="error" role="alert">${escapeHtml(error)}</p>` : "";
  const body = `<form class="card" method="post" action="/">
  ${alert}
  <label for="teamName">Team name</label>
  <input id="teamName" name="teamName" type="text" required minlength="2" maxlength="40"
         autocomplete="organization" value="${escapeHtml(teamName || "")}">
  <p class="hint">Unique in the room. Same name + PIN brings you back to this Mac's session.</p>
  <label for="pin">Event PIN</label>
  <input id="pin" name="pin" type="password" required autocomplete="off">
  <p class="hint">On the projector.</p>
  <button class="btn" type="submit">Open the exercise</button>
</form>
<p class="hint" style="text-align:center">Keep the tab open. You'll turn Wi-Fi off later — the steps stay on this page.</p>`;

  return layout({
    title: "Join — Mac Initiative Builder",
    heading: "Join the contest",
    sub: "Enter a team name. The session steps appear next. At the end you'll upload a screenshot of the app.",
    nav: publicNav(),
    body,
  });
}

export function wallPage(entries, { admin } = {}) {
  const cards = entries.length
    ? `<div class="wall">${entries
        .map(
          (row) => `<figure>
  <a href="/images/${encodeURIComponent(row.id)}">
    <img src="/images/${encodeURIComponent(row.id)}" alt="Screenshot from ${escapeHtml(row.team_name)}">
  </a>
  <figcaption>
    <strong>${escapeHtml(row.team_name)}</strong>
    <span>${formatWhen(row.created_at)}</span>
  </figcaption>
</figure>`,
        )
        .join("")}</div>`
    : `<p class="empty">No screenshots yet. First pair to finish, first on the wall.</p>`;

  return layout({
    title: "The wall — Mac Initiative Builder",
    heading: "The wall",
    sub: "Screenshots of the apps built in the room. Staff judge by looking.",
    nav: admin ? adminNav() : publicNav(),
    body: cards,
  });
}

export function adminGate({ error } = {}) {
  const alert = error ? `<p class="error" role="alert">${escapeHtml(error)}</p>` : "";
  const body = `<form class="card" method="post" action="/admin">
  ${alert}
  <label for="pin">Staff PIN</label>
  <input id="pin" name="pin" type="password" required autocomplete="current-password">
  <button class="btn" type="submit">Open admin</button>
</form>`;
  return layout({
    title: "Admin — Mac Initiative Builder",
    heading: "Staff",
    sub: "Live progress and the screenshot wall. Not for the pairs.",
    body,
  });
}

export function adminLivePage(teams, machines = []) {
  return layout({
    title: "Live teams — Mac Initiative Builder",
    heading: "Staff",
    sub: "Reset Macs between pairs. Watch where each team is. The wall is the leaderboard.",
    nav: adminNav(),
    extraHead: `<script src="/htmx.min.js" defer></script>`,
    body: `<div id="board" hx-get="/admin/live" hx-trigger="every 3s [!document.hidden]" hx-swap="innerHTML" hx-sync="this:replace">${adminLiveBody(teams, machines)}</div>`,
  });
}

export function adminLiveFragment(teams, machines = []) {
  return adminLiveBody(teams, machines);
}

function adminLiveBody(teams, machines) {
  const submitted = teams.filter((t) => t.submission_id).length;
  const online = machines.filter((m) => isFresh(m.last_seen, 15000)).length;
  return `
<h2 style="font-size:1.1rem;margin:0 0 .6rem">Workshop Macs</h2>
<div class="stats">
  <span><b id="n-macs-online">${online}</b> online</span>
  <span><b id="n-macs">${machines.length}</b> agents</span>
  <form class="inline" method="post" action="/admin/reset-all"
        hx-post="/admin/reset-all" hx-target="#board" hx-swap="innerHTML"
        hx-confirm="Reset EVERY connected Mac? This wipes the Xcode project on those machines.">
    <button class="btn danger small" type="submit">Reset all Macs</button>
  </form>
</div>
<div style="overflow:auto">
<table class="live">
  <thead>
    <tr>
      <th>Mac</th>
      <th>Status</th>
      <th>Last seen</th>
      <th>Last reset</th>
      <th></th>
    </tr>
  </thead>
  <tbody id="mac-body">${machineRows(machines)}</tbody>
</table>
</div>
<p class="empty" id="mac-empty" ${machines.length ? "hidden" : ""}>No agents yet. On each contest Mac, double-click <code>scripts/Install Workshop Agent.command</code>.</p>

<h2 style="font-size:1.1rem;margin:2rem 0 .6rem">Teams</h2>
<div class="stats">
  <span><b id="n-teams">${teams.length}</b> teams</span>
  <span><b id="n-shots">${submitted}</b> on the wall</span>
  <span><a href="/wall">Open the leaderboard</a></span>
</div>
<div style="overflow:auto">
<table class="live">
  <thead>
    <tr>
      <th>Team</th>
      <th>Step</th>
      <th>Progress</th>
      <th>Ticks</th>
      <th>Last seen</th>
      <th>Screenshot</th>
    </tr>
  </thead>
  <tbody id="live-body">${teamRows(teams)}</tbody>
</table>
</div>
<p class="empty" id="live-empty" ${teams.length ? "hidden" : ""}>No teams yet. They join at the home page.</p>`;
}

function machineRows(machines) {
  if (!machines.length) return "";
  return machines.map((m) => machineRow(m)).join("");
}

function machineRow(m) {
  const live = isFresh(m.last_seen, 15000);
  const status = machineStatus(m);
  return `<tr>
    <td><strong>${escapeHtml(m.label)}</strong><br><span style="color:var(--ink-dim);font-size:.85rem">${escapeHtml(m.hostname || "")}</span></td>
    <td>${status}</td>
    <td class="${live ? "live-dot" : "stale"}">${live ? "Live · " : ""}${escapeHtml(formatAgo(m.last_seen))}</td>
    <td>${m.last_reset_at ? escapeHtml(formatAgo(m.last_reset_at)) : "—"}</td>
    <td>
      <form class="inline" method="post" action="/admin/reset"
            hx-post="/admin/reset" hx-target="#board" hx-swap="innerHTML"
            hx-confirm="Reset ${escapeHtml(m.label)}? This wipes the Xcode project on that Mac.">
        <input type="hidden" name="id" value="${escapeHtml(m.id)}">
        <button class="btn small" type="submit">Reset</button>
      </form>
    </td>
  </tr>`;
}

function machineStatus(m) {
  if (m.reset_queued) return "Queued";
  if (m.reset_state === "running") return "Resetting…";
  if (m.reset_state === "failed") return escapeHtml(m.reset_error ? `Failed: ${m.reset_error}` : "Failed");
  return "Idle";
}

function teamRows(teams) {
  if (!teams.length) return "";
  return teams.map((t) => teamRow(t)).join("");
}

function teamRow(t) {
  const idx = stepIndex(t.step);
  const pips = PLAY_STEPS.map((s, i) => {
    const cls = i === idx ? "pip now" : i < idx ? "pip on" : "pip";
    return `<span class="${cls}" title="${escapeHtml(s.label)}"></span>`;
  }).join("");
  const seen = formatAgo(t.last_seen);
  const live = isFresh(t.last_seen);
  const shot = t.submission_id
    ? `<a href="/images/${encodeURIComponent(t.submission_id)}">View</a>`
    : "—";
  return `<tr>
    <td><strong>${escapeHtml(t.team_name)}</strong></td>
    <td>${escapeHtml(stepLabel(t.step))}</td>
    <td><div class="pips">${pips}</div></td>
    <td>${tickCount(t.ticks)}</td>
    <td class="${live ? "live-dot" : "stale"}">${live ? "Live · " : ""}${escapeHtml(seen)}</td>
    <td>${shot}</td>
  </tr>`;
}

export function livePayload(teams) {
  return teams.map((t) => ({
    team_name: t.team_name,
    step: t.step,
    ticks: t.ticks,
    last_seen: t.last_seen,
    submission_id: t.submission_id,
    submitted_at: t.submitted_at,
  }));
}

export function machinePayload(machines) {
  return machines.map((m) => ({
    id: m.id,
    label: m.label,
    hostname: m.hostname,
    last_seen: m.last_seen,
    reset_queued: m.reset_queued,
    reset_state: m.reset_state,
    reset_error: m.reset_error,
    last_reset_at: m.last_reset_at,
  }));
}

export function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function formatWhen(date) {
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
}

function formatAgo(date) {
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) return "";
  const s = Math.max(0, Math.floor((Date.now() - d.getTime()) / 1000));
  if (s < 10) return "just now";
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  return `${Math.floor(s / 3600)}h ago`;
}

function isFresh(date, windowMs = 45000) {
  const d = date instanceof Date ? date : new Date(date);
  return Date.now() - d.getTime() < windowMs;
}
