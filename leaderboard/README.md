# Contest site

Pairs open this in Safari, enter a team name, and work through the exercise in
that tab. Staff watch live progress at `/admin` and judge screenshots on `/wall`.

## Local

```bash
cd leaderboard
npm install
EVENT_PIN=ondevice ADMIN_PIN=staff npm start
```

- Join: http://localhost:3000
- Exercise (after join): http://localhost:3000/play
- Wall: http://localhost:3000/wall
- Admin: http://localhost:3000/admin (PIN `staff`)

Without `DATABASE_URL` and bucket credentials it stores rows in memory and files
in `data/uploads` — fine for a rehearsal, gone on restart.

Keep the contest tab open when they turn Wi-Fi off. Ticks queue and sync when
the network is back. `exercise.html` at the repo root is the fallback if the
site is down.

Docker copies `content/exercise.html` and `content/install.sh`. After you edit the
root `exercise.html` or `scripts/install-workshop-agent.sh`, copy them before deploy:

```bash
cp ../exercise.html content/exercise.html
cp ../scripts/install-workshop-agent.sh content/install.sh
```

Mac setup (from-scratch pack + agent + Codex; API key from MDM, not this curl):
`curl -fsSL https://ambassadors26.up.railway.app/install | bash`

## Railway

Web service + Postgres + a private bucket. Env on the web service:

- `DATABASE_URL` (from Postgres)
- `EVENT_PIN` (pairs)
- `ADMIN_PIN` (staff only — not on the projector)
- `AGENT_SECRET` (workshop agent on each Mac; rehearsal default `workshop-reset`)
- `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET_NAME`, `AWS_DEFAULT_REGION`

Live: [https://ambassadors26.up.railway.app](https://ambassadors26.up.railway.app)

See [FACILITATOR.md](../FACILITATOR.md) for the URL to put on the projector.
