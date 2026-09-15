import pg from "pg";
import { randomUUID } from "node:crypto";

export function createDb() {
  const url = process.env.DATABASE_URL;
  if (url) return createPostgres(url);
  return createMemory();
}

function createPostgres(connectionString) {
  const pool = new pg.Pool({
    connectionString,
    ssl: connectionString.includes("localhost") ? false : { rejectUnauthorized: false },
  });

  return {
    async migrate() {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS submissions (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          team_name TEXT NOT NULL,
          image_key TEXT NOT NULL,
          content_type TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS submissions_team_name_lower
          ON submissions (lower(team_name));

        CREATE TABLE IF NOT EXISTS teams (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          team_name TEXT NOT NULL,
          token TEXT NOT NULL,
          step TEXT NOT NULL DEFAULT 'welcome',
          ticks JSONB NOT NULL DEFAULT '{}'::jsonb,
          last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS teams_name_lower ON teams (lower(team_name));
        CREATE UNIQUE INDEX IF NOT EXISTS teams_token ON teams (token);

        ALTER TABLE submissions ADD COLUMN IF NOT EXISTS team_id UUID;

        CREATE TABLE IF NOT EXISTS machines (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          token TEXT NOT NULL,
          hostname TEXT NOT NULL DEFAULT '',
          label TEXT NOT NULL,
          last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          reset_queued BOOLEAN NOT NULL DEFAULT FALSE,
          reset_state TEXT NOT NULL DEFAULT 'idle',
          reset_error TEXT,
          last_reset_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        CREATE UNIQUE INDEX IF NOT EXISTS machines_token ON machines (token);
      `);
    },

    async join({ teamName }) {
      const existing = await pool.query(
        `SELECT id, team_name, token, step, ticks, last_seen
         FROM teams WHERE lower(team_name) = lower($1)`,
        [teamName],
      );
      if (existing.rows[0]) {
        await pool.query(`UPDATE teams SET last_seen = NOW() WHERE id = $1`, [
          existing.rows[0].id,
        ]);
        return { ok: true, team: rowTeam(existing.rows[0]), resumed: true };
      }
      const token = randomUUID();
      const { rows } = await pool.query(
        `INSERT INTO teams (team_name, token)
         VALUES ($1, $2)
         RETURNING id, team_name, token, step, ticks, last_seen`,
        [teamName, token],
      );
      return { ok: true, team: rowTeam(rows[0]), resumed: false };
    },

    async getByToken(token) {
      if (!token) return null;
      const { rows } = await pool.query(
        `SELECT id, team_name, token, step, ticks, last_seen
         FROM teams WHERE token = $1`,
        [token],
      );
      return rows[0] ? rowTeam(rows[0]) : null;
    },

    async saveProgress({ token, step, ticks }) {
      const { rows } = await pool.query(
        `UPDATE teams
         SET step = COALESCE($2, step),
             ticks = COALESCE($3::jsonb, ticks),
             last_seen = NOW()
         WHERE token = $1
         RETURNING id, team_name, token, step, ticks, last_seen`,
        [token, step || null, ticks ? JSON.stringify(ticks) : null],
      );
      return rows[0] ? rowTeam(rows[0]) : null;
    },

    async listLive() {
      const { rows } = await pool.query(
        `SELECT t.id, t.team_name, t.step, t.ticks, t.last_seen, t.created_at,
                s.id AS submission_id, s.created_at AS submitted_at
         FROM teams t
         LEFT JOIN submissions s ON s.team_id = t.id
         ORDER BY t.last_seen DESC`,
      );
      return rows.map((row) => ({
        ...rowTeam(row),
        created_at: row.created_at,
        submission_id: row.submission_id || null,
        submitted_at: row.submitted_at || null,
      }));
    },

    async list() {
      const { rows } = await pool.query(
        `SELECT id, team_name, created_at
         FROM submissions
         ORDER BY created_at DESC`,
      );
      return rows;
    },

    async get(id) {
      const { rows } = await pool.query(
        `SELECT id, team_name, image_key, content_type FROM submissions WHERE id = $1`,
        [id],
      );
      return rows[0] || null;
    },

    async upsertShot({ team, imageKey, contentType }) {
      const updated = await pool.query(
        `UPDATE submissions
         SET image_key = $2, content_type = $3, team_name = $4, team_id = $1, created_at = NOW()
         WHERE team_id = $1 OR lower(team_name) = lower($4)
         RETURNING id, team_name, created_at`,
        [team.id, imageKey, contentType, team.team_name],
      );
      if (updated.rows[0]) return { ok: true, row: updated.rows[0] };
      try {
        const { rows } = await pool.query(
          `INSERT INTO submissions (team_name, image_key, content_type, team_id)
           VALUES ($1, $2, $3, $4)
           RETURNING id, team_name, created_at`,
          [team.team_name, imageKey, contentType, team.id],
        );
        return { ok: true, row: rows[0] };
      } catch (error) {
        if (error.code === "23505")         return { ok: false, taken: true };
        throw error;
      }
    },

    async helloMachine({ token, hostname, label }) {
      if (token) {
        const existing = await pool.query(
          `UPDATE machines
           SET hostname = $2, label = $3, last_seen = NOW()
           WHERE token = $1
           RETURNING *`,
          [token, hostname, label],
        );
        if (existing.rows[0]) return rowMachine(existing.rows[0]);
      }
      const minted = randomUUID();
      const { rows } = await pool.query(
        `INSERT INTO machines (token, hostname, label)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [minted, hostname, label],
      );
      return rowMachine(rows[0]);
    },

    async getMachineByToken(token) {
      if (!token) return null;
      const { rows } = await pool.query(`SELECT * FROM machines WHERE token = $1`, [token]);
      return rows[0] ? rowMachine(rows[0]) : null;
    },

    async pollMachine(token) {
      const claimed = await pool.query(
        `UPDATE machines
         SET last_seen = NOW(),
             reset_queued = FALSE,
             reset_state = 'running',
             reset_error = NULL
         WHERE token = $1 AND reset_queued = TRUE
         RETURNING *`,
        [token],
      );
      if (claimed.rows[0]) return { machine: rowMachine(claimed.rows[0]), reset: true };
      const { rows } = await pool.query(
        `UPDATE machines SET last_seen = NOW() WHERE token = $1 RETURNING *`,
        [token],
      );
      return rows[0] ? { machine: rowMachine(rows[0]), reset: false } : null;
    },

    async ackMachine(token, { ok, error }) {
      const { rows } = await pool.query(
        `UPDATE machines
         SET last_seen = NOW(),
             reset_state = $2,
             reset_error = $3,
             last_reset_at = CASE WHEN $4 THEN NOW() ELSE last_reset_at END
         WHERE token = $1
         RETURNING *`,
        [token, ok ? "idle" : "failed", ok ? null : error || "reset failed", ok],
      );
      return rows[0] ? rowMachine(rows[0]) : null;
    },

    async requestReset({ id, all }) {
      if (all) {
        await pool.query(`UPDATE machines SET reset_queued = TRUE, reset_error = NULL`);
        return;
      }
      await pool.query(
        `UPDATE machines SET reset_queued = TRUE, reset_error = NULL WHERE id = $1`,
        [id],
      );
    },

    async listMachines() {
      const { rows } = await pool.query(
        `SELECT * FROM machines ORDER BY label ASC, last_seen DESC`,
      );
      return rows.map(rowMachine);
    },
  };
}

function rowTeam(row) {
  return {
    id: row.id,
    team_name: row.team_name,
    token: row.token,
    step: row.step,
    ticks: row.ticks && typeof row.ticks === "string" ? JSON.parse(row.ticks) : row.ticks || {},
    last_seen: row.last_seen,
  };
}

function rowMachine(row) {
  return {
    id: row.id,
    token: row.token,
    hostname: row.hostname,
    label: row.label,
    last_seen: row.last_seen,
    reset_queued: Boolean(row.reset_queued),
    reset_state: row.reset_state,
    reset_error: row.reset_error || null,
    last_reset_at: row.last_reset_at || null,
  };
}

function createMemory() {
  const teams = [];
  const rows = [];
  const machines = [];

  return {
    async migrate() {},

    async join({ teamName }) {
      const existing = teams.find(
        (t) => t.team_name.toLowerCase() === teamName.toLowerCase(),
      );
      if (existing) {
        existing.last_seen = new Date();
        return { ok: true, team: { ...existing }, resumed: true };
      }
      const team = {
        id: randomUUID(),
        team_name: teamName,
        token: randomUUID(),
        step: "welcome",
        ticks: {},
        last_seen: new Date(),
        created_at: new Date(),
      };
      teams.push(team);
      return { ok: true, team: { ...team }, resumed: false };
    },

    async getByToken(token) {
      const team = teams.find((t) => t.token === token);
      return team ? { ...team, ticks: { ...team.ticks } } : null;
    },

    async saveProgress({ token, step, ticks }) {
      const team = teams.find((t) => t.token === token);
      if (!team) return null;
      if (step) team.step = step;
      if (ticks) team.ticks = { ...ticks };
      team.last_seen = new Date();
      return { ...team, ticks: { ...team.ticks } };
    },

    async listLive() {
      return teams
        .map((t) => {
          const shot = rows.find((r) => r.team_id === t.id);
          return {
            ...t,
            ticks: { ...t.ticks },
            submission_id: shot?.id || null,
            submitted_at: shot?.created_at || null,
          };
        })
        .sort((a, b) => b.last_seen - a.last_seen);
    },

    async list() {
      return [...rows].sort((a, b) => b.created_at - a.created_at);
    },

    async get(id) {
      return rows.find((row) => row.id === id) || null;
    },

    async upsertShot({ team, imageKey, contentType }) {
      const existing = rows.find((r) => r.team_id === team.id);
      if (existing) {
        existing.image_key = imageKey;
        existing.content_type = contentType;
        existing.team_name = team.team_name;
        existing.created_at = new Date();
        return { ok: true, row: existing };
      }
      const taken = rows.some(
        (row) => row.team_name.toLowerCase() === team.team_name.toLowerCase() && !row.team_id,
      );
      if (taken) return { ok: false, taken: true };
      const row = {
        id: randomUUID(),
        team_name: team.team_name,
        team_id: team.id,
        image_key: imageKey,
        content_type: contentType,
        created_at: new Date(),
      };
      rows.push(row);
      return { ok: true, row };
    },

    async helloMachine({ token, hostname, label }) {
      let machine = token ? machines.find((m) => m.token === token) : null;
      if (machine) {
        machine.hostname = hostname;
        machine.label = label;
        machine.last_seen = new Date();
        return { ...machine };
      }
      machine = {
        id: randomUUID(),
        token: randomUUID(),
        hostname,
        label,
        last_seen: new Date(),
        reset_queued: false,
        reset_state: "idle",
        reset_error: null,
        last_reset_at: null,
        created_at: new Date(),
      };
      machines.push(machine);
      return { ...machine };
    },

    async getMachineByToken(token) {
      const machine = machines.find((m) => m.token === token);
      return machine ? { ...machine } : null;
    },

    async pollMachine(token) {
      const machine = machines.find((m) => m.token === token);
      if (!machine) return null;
      machine.last_seen = new Date();
      if (machine.reset_queued) {
        machine.reset_queued = false;
        machine.reset_state = "running";
        machine.reset_error = null;
        return { machine: { ...machine }, reset: true };
      }
      return { machine: { ...machine }, reset: false };
    },

    async ackMachine(token, { ok, error }) {
      const machine = machines.find((m) => m.token === token);
      if (!machine) return null;
      machine.last_seen = new Date();
      if (ok) {
        machine.reset_state = "idle";
        machine.reset_error = null;
        machine.last_reset_at = new Date();
      } else {
        machine.reset_state = "failed";
        machine.reset_error = error || "reset failed";
      }
      return { ...machine };
    },

    async requestReset({ id, all }) {
      for (const machine of machines) {
        if (all || machine.id === id) {
          machine.reset_queued = true;
          machine.reset_error = null;
        }
      }
    },

    async listMachines() {
      return [...machines]
        .sort((a, b) => String(a.label).localeCompare(String(b.label)))
        .map((m) => ({ ...m }));
    },
  };
}
