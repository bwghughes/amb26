import { timingSafeEqual } from "node:crypto";
import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createDb } from "./db.js";
import {
  adminGate,
  adminLiveFragment,
  adminLivePage,
  adminToken,
  joinPage,
  livePayload,
  machinePayload,
  wallPage,
} from "./html.js";
import { loadExerciseHtml, wrapPlayPage } from "./play.js";
import { isKnownStep } from "./steps.js";
import { createStorage, validateImage } from "./storage.js";

const port = Number(process.env.PORT) || 3000;
const eventPin = process.env.EVENT_PIN || "ondevice";
const staffPin = process.env.ADMIN_PIN || "staff";
const agentSecret = process.env.AGENT_SECRET || "workshop-reset";
const here = path.dirname(fileURLToPath(import.meta.url));

const db = createDb();
const storage = createStorage();
const app = new Hono();

await db.migrate();

const TEAM_COOKIE = "mib_team";
const ADMIN_COOKIE = "mib_admin";

function cookieOpts(c) {
  return {
    path: "/",
    httpOnly: true,
    sameSite: "Lax",
    maxAge: 60 * 60 * 18,
    secure: c.req.url.startsWith("https://"),
  };
}

async function teamFrom(c) {
  return db.getByToken(getCookie(c, TEAM_COOKIE));
}

function isAdmin(c) {
  return getCookie(c, ADMIN_COOKIE) === adminToken(staffPin);
}

function wantsHtmlSwap(c) {
  return c.req.header("HX-Request") === "true";
}

async function adminLiveHtml(c) {
  const [teams, machines] = await Promise.all([db.listLive(), db.listMachines()]);
  return c.html(adminLiveFragment(teams, machines));
}

function secretsMatch(got, expected) {
  const a = Buffer.from(String(got || ""));
  const b = Buffer.from(String(expected || ""));
  if (!a.length || a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

function clip(value, max) {
  return String(value || "").trim().slice(0, max);
}

app.get("/", async (c) => {
  const team = await teamFrom(c);
  if (team) return c.redirect("/play", 302);
  return c.html(joinPage());
});

app.post("/", async (c) => {
  const body = await c.req.parseBody();
  const teamName = String(body.teamName || "").trim();
  const pin = String(body.pin || "");
  if (pin !== eventPin) {
    return c.html(joinPage({ error: "That PIN isn't right. Use the one on the projector.", teamName }), 400);
  }
  if (teamName.length < 2 || teamName.length > 40) {
    return c.html(joinPage({ error: "Team name needs to be between 2 and 40 characters.", teamName }), 400);
  }
  const { team } = await db.join({ teamName });
  setCookie(c, TEAM_COOKIE, team.token, cookieOpts(c));
  return c.redirect("/play", 303);
});

app.post("/leave", (c) => {
  deleteCookie(c, TEAM_COOKIE, { path: "/" });
  return c.redirect("/", 303);
});

app.get("/leave", (c) => {
  deleteCookie(c, TEAM_COOKIE, { path: "/" });
  return c.redirect("/", 302);
});

app.get("/play", async (c) => {
  const team = await teamFrom(c);
  if (!team) return c.redirect("/", 302);
  const live = (await db.listLive()).find((t) => t.id === team.id);
  return c.html(
    wrapPlayPage(loadExerciseHtml(), {
      teamName: team.team_name,
      step: team.step,
      ticks: team.ticks,
      uploaded: Boolean(live?.submission_id),
      notice: c.req.query("ok") === "1" ? "Screenshot is on the wall." : "",
      error: c.req.query("err") || "",
    }),
  );
});

app.post("/api/progress", async (c) => {
  const team = await teamFrom(c);
  if (!team) return c.json({ ok: false }, 401);
  let body;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ ok: false }, 400);
  }
  const step = typeof body.step === "string" && isKnownStep(body.step) ? body.step : undefined;
  const ticks =
    body.ticks && typeof body.ticks === "object" && !Array.isArray(body.ticks)
      ? Object.fromEntries(
          Object.entries(body.ticks)
            .filter(([k, v]) => /^b\d+$/.test(k) && v)
            .slice(0, 40),
        )
      : undefined;
  await db.saveProgress({ token: team.token, step, ticks });
  return c.json({ ok: true });
});

app.post("/play/screenshot", async (c) => {
  const team = await teamFrom(c);
  if (!team) return c.redirect("/", 302);
  const body = await c.req.parseBody({ all: true });
  const file = body.screenshot;
  const imageError = validateImage(file);
  if (imageError) {
    return c.redirect(`/play?err=${encodeURIComponent(imageError)}#submit`, 303);
  }
  const bytes = Buffer.from(await file.arrayBuffer());
  const contentType = file.type || "image/png";
  const imageKey = await storage.put(bytes, contentType);
  await db.upsertShot({ team, imageKey, contentType });
  await db.saveProgress({ token: team.token, step: "why" });
  return c.redirect("/play?ok=1#why", 303);
});

app.get("/submit", (c) => c.redirect("/play#submit", 302));

app.get("/wall", async (c) => {
  const entries = await db.list();
  return c.html(wallPage(entries, { admin: isAdmin(c) }));
});

app.get("/images/:id", async (c) => {
  const row = await db.get(c.req.param("id"));
  if (!row) return c.notFound();
  const { bytes, contentType } = await storage.get(row.image_key);
  return new Response(bytes, {
    headers: {
      "Content-Type": row.content_type || contentType,
      "Cache-Control": "public, max-age=86400",
    },
  });
});

app.get("/hero-banner.png", async (c) => {
  const file = [path.resolve(here, "../../hero-banner.png"), path.resolve(here, "../public/hero-banner.png")].find(
    (p) => existsSync(p),
  );
  if (!file) return c.notFound();
  const bytes = await readFile(file);
  return new Response(bytes, {
    headers: { "Content-Type": "image/png", "Cache-Control": "public, max-age=86400" },
  });
});

app.get("/htmx.min.js", async (c) => {
  const file = path.resolve(here, "../public/htmx.min.js");
  if (!existsSync(file)) return c.notFound();
  const bytes = await readFile(file);
  return new Response(bytes, {
    headers: {
      "Content-Type": "text/javascript; charset=utf-8",
      "Cache-Control": "public, max-age=86400",
    },
  });
});

app.get("/admin", async (c) => {
  if (!isAdmin(c)) return c.html(adminGate());
  const [teams, machines] = await Promise.all([db.listLive(), db.listMachines()]);
  return c.html(adminLivePage(teams, machines));
});

app.get("/admin/live", async (c) => {
  if (!isAdmin(c)) {
    if (c.req.header("HX-Request")) c.header("HX-Redirect", "/admin");
    return c.body("", 401);
  }
  const [teams, machines] = await Promise.all([db.listLive(), db.listMachines()]);
  return c.html(adminLiveFragment(teams, machines));
});

app.post("/admin", async (c) => {
  const body = await c.req.parseBody();
  if (String(body.pin || "") !== staffPin) {
    return c.html(adminGate({ error: "That's not the staff PIN." }), 401);
  }
  setCookie(c, ADMIN_COOKIE, adminToken(staffPin), cookieOpts(c));
  return c.redirect("/admin", 303);
});

app.post("/admin/logout", (c) => {
  deleteCookie(c, ADMIN_COOKIE, { path: "/" });
  return c.redirect("/admin", 303);
});

app.get("/admin/api/teams", async (c) => {
  if (!isAdmin(c)) return c.json({ error: "unauthorized" }, 401);
  const teams = await db.listLive();
  return c.json(livePayload(teams));
});

app.get("/admin/api/state", async (c) => {
  if (!isAdmin(c)) return c.json({ error: "unauthorized" }, 401);
  const [teams, machines] = await Promise.all([db.listLive(), db.listMachines()]);
  return c.json({ teams: livePayload(teams), machines: machinePayload(machines) });
});

app.post("/admin/reset", async (c) => {
  if (!isAdmin(c)) return c.redirect("/admin", 302);
  const body = await c.req.parseBody();
  const id = String(body.id || "");
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    return wantsHtmlSwap(c) ? adminLiveHtml(c) : c.redirect("/admin", 303);
  }
  await db.requestReset({ id });
  return wantsHtmlSwap(c) ? adminLiveHtml(c) : c.redirect("/admin", 303);
});

app.post("/admin/reset-all", async (c) => {
  if (!isAdmin(c)) return c.redirect("/admin", 302);
  await db.requestReset({ all: true });
  return wantsHtmlSwap(c) ? adminLiveHtml(c) : c.redirect("/admin", 303);
});

app.post("/api/agent/hello", async (c) => {
  if (!secretsMatch(c.req.header("x-agent-secret"), agentSecret)) {
    return c.json({ error: "unauthorized" }, 401);
  }
  let body;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad json" }, 400);
  }
  const machine = await db.helloMachine({
    token: clip(body.token, 80),
    hostname: clip(body.hostname, 80) || "mac",
    label: clip(body.label, 80) || clip(body.hostname, 80) || "Mac",
  });
  return c.json({ token: machine.token, id: machine.id, label: machine.label });
});

app.get("/api/agent/poll", async (c) => {
  if (!secretsMatch(c.req.header("x-agent-secret"), agentSecret)) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const header = c.req.header("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  const result = await db.pollMachine(token);
  if (!result) return c.json({ error: "unknown agent" }, 401);
  return c.json({ reset: result.reset });
});

app.post("/api/agent/ack", async (c) => {
  if (!secretsMatch(c.req.header("x-agent-secret"), agentSecret)) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const header = c.req.header("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  let body = {};
  try {
    body = await c.req.json();
  } catch {
    body = {};
  }
  const machine = await db.ackMachine(token, {
    ok: Boolean(body.ok),
    error: clip(body.error, 500),
  });
  if (!machine) return c.json({ error: "unknown agent" }, 401);
  return c.json({ ok: true });
});

function installScriptHeaders() {
  return {
    "Content-Type": "text/x-shellscript; charset=utf-8",
    "Content-Disposition": 'inline; filename="install.sh"',
    "Cache-Control": "no-cache",
  };
}

async function serveInstall() {
  const file = path.resolve(here, "../content/install.sh");
  if (!existsSync(file)) return null;
  return new Response(await readFile(file), { headers: installScriptHeaders() });
}

app.get("/install", async (c) => (await serveInstall()) || c.notFound());
app.get("/install.sh", async (c) => (await serveInstall()) || c.notFound());

app.get("/health", (c) => c.json({ ok: true }));

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`Contest site listening on http://localhost:${info.port}`);
});
