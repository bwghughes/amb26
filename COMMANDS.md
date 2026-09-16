# Staff commands

Copy-paste from the **codealong folder** (the one that contains `Starter/`, `scripts/`, and `exercise.html`). Replace `$PACK` if you are not already in that folder.

```bash
cd /path/to/Ambassadors26-CodeAlong
```

The pairs never need these. They talk to Xcode. You run reset between pairs, and Rescue Session if a pair’s build is stuck.

Do not run any of this while a pair is still working.

---

## Reset the Mac for the next pair

**Normal path — double-click**

`scripts/Reset Workshop.command`

First time on a machine: Right-click → **Open**, then allow it. After that, double-click is enough.

Confirm **Reset**. It quits the app, restores the stock three-pane shell, picks a new look, clears this app’s DerivedData, deletes today’s Desktop *window* screenshots, and reopens the handout with the ticks cleared. The gallery on the web is not touched. It does not commit, and it does not `git reset` this repo.

**Same thing from Terminal**, if the double-click is blocked:

```bash
cd "$PACK"
chmod +x "scripts/Reset Workshop.command"
open "scripts/Reset Workshop.command"
```

Or run it in this shell (you still get the confirm dialog):

```bash
cd "$PACK"
./scripts/Reset\ Workshop.command
```

Run it **once before doors** so the first pair is not all on hospital grey. Run it
**again after each pair leaves** — or press **Reset** on the staff dashboard if the
workshop agent is installed on that Mac.

After it finishes:

1. In Xcode, start a **new Coding Assistant chat** (the last pair’s thread must go).
2. Open `Starter/Ambassadors26.xcodeproj` (or the Desktop copy) and press **Run** once to warm the build.

---

## Workshop agent (reset from the dashboard)

Install once on every contest Mac. It sits in the background, checks in with the
staff site, and runs `Reset Workshop.command --yes` when you press Reset.

**Install** (primary — from-scratch bootstrap, non-interactive):

```bash
curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash
```

Do **not** put an API key on that command line. MDM delivers
`OPENAI_API_KEY` or `CODEX_API_KEY` onto each contest Mac. The served
script only *reads* it.

MDM owner: see [MDM.md](MDM.md).

On a Mac that already has Xcode, that is the whole setup. MDM may run that
curl as root — **do not trust `$HOME`** (it is `/var/root` in that case).
Artifacts always land under `/Users/Ambassador` (override with `INSTALL_HOME`
or `AMBASSADOR_HOME` for rehearsal). It clones this pack to
`/Users/Ambassador/Desktop/Ambassadors26-CodeAlong` if needed (or fast-forward
pulls if the folder already exists), makes sure `Starter/` is a real Xcode
project (copies `scripts/starter-stock/` if GitHub left an empty gitlink),
copies `Starter` to `/Users/Ambassador/Desktop/Starter` on first install,
`chmod +x` the reset/rescue/install scripts, `chown`s pack / Starter / Library
trees (not the Desktop folder — SIP/TCC; the pack lives inside it) to user
`Ambassador`, installs the LaunchAgent in `gui/$(id -u Ambassador)`, and
installs **Codex as the Xcode Intelligence agent** (the tarball Xcode 27
already lists in `AgentVersions.plist`). Confirm the printed Computer Name
under **Workshop Macs** on https://ambassadors26.up.railway.app/admin. Quit
and reopen Xcode if it was already open, then open the Desktop Starter and
press Run once.

**MDM must put the key** where Codex and this script can see it (first match
wins; the script never prints the value):

1. Process environment `OPENAI_API_KEY` or `CODEX_API_KEY`
2. Aqua session env via `launchctl getenv` — typical for a config-profile
   Environment Variables payload
3. Managed preferences domain **`com.openai.codex`** (Codex’s official MDM
   domain), same key names — also `openai_api_key`, `APIKey`, `api_key`
4. Any plist under `/Library/Managed Preferences` with those keys

The script then copies that MDM value into:

- Codex login for Xcode’s `CODEX_HOME`
  (`/Users/Ambassador/Library/Developer/Xcode/CodingAssistant/codex`) — Keychain service
  **`Codex Auth`**, plus `auth.json` there if the CLI writes one. Login runs **as
  user Ambassador** so the item is in their login keychain, not root’s.
- `launchctl setenv OPENAI_API_KEY` / `CODEX_API_KEY` in **Ambassador’s GUI
  domain** if those were not already set, so Xcode launched from the Dock can
  see the key
- Xcode defaults so Codex is the selected Intelligence agent

Nothing is written into the git repo or the install script.

If MDM has not applied the key yet, pack + LaunchAgent still finish. The
script prints a loud warning and skips Codex login. Re-run the same plain
curl after MDM delivers the key.

Defaults: contest URL `https://ambassadors26.up.railway.app`, agent secret
`workshop-reset`, repo `https://github.com/bwghughes/amb26.git`, install home
`/Users/Ambassador`. Override with `SERVER`, `AGENT_SECRET`, `PACK`,
`DESKTOP_STARTER`, `INSTALL_HOME` / `AMBASSADOR_HOME`, or `REPO_URL`. A re-run
will not overwrite an existing `/Users/Ambassador/Desktop/Starter` that
already looks like a project. If GitHub is
private, copy the pack onto the Mac first and re-run with `PACK` set to that
folder. If `/Users/Ambassador` does not exist, the installer exits — creating
that account is MDM’s job.

**Double-click fallback** (first time: Right-click → Open):

```bash
open "$PACK/scripts/Install Workshop Agent.command"
```

Accept the contest URL and the agent secret (`workshop-reset` unless you changed
`AGENT_SECRET` on Railway).

**From the dashboard:** **Reset** on one Mac, or **Reset all Macs**. Confirm. The
Mac must be able to reach the site. If Wi-Fi is off, the reset is queued and
runs when it comes back.

**Uninstall:**

```bash
open "$PACK/scripts/Uninstall Workshop Agent.command"
```

Log: `/Users/Ambassador/Library/Logs/ambassadors26-agent.log`
LaunchAgent: `/Users/Ambassador/Library/LaunchAgents/com.ambassadors26.workshop-agent.plist`
Agent config: `/Users/Ambassador/Library/Application Support/Ambassadors26/agent.json`

Do not install this on a Mac you are still building on — a dashboard reset
wipes `Starter/` the same way the local script does.

---

## Rescue during a session (this pair’s seed, not a new look)

Two failed builds. This rewinds to **this pair’s seed**, not a blank grey app and not the next pair’s theme. `Starter/` is not its own git repo, so `git checkout .` will not do this.

**Normal path — double-click**

`scripts/Rescue Session.command`

Confirm **Restore**. Then they say the sentence again.

**Same thing from Terminal:**

```bash
cd "$PACK"
./scripts/Rescue\ Session.command
```

`--yes` skips the confirm dialog (same as reset):

```bash
./scripts/Rescue\ Session.command --yes
```

That reads the current theme from `.session-last-theme` or `SEED.md`, restores the stock shell, re-applies that theme, and copies the result onto `/Users/Ambassador/Desktop/Starter` if that folder exists. It does not pick a new look, does not clear exercise ticks, and does not commit.

Do **not** `git reset --hard` this pack. Do **not** `git clean -x`.

---

## Force a look (staff only)

The reset script picks a random theme and avoids the one it used last. To pin one (demo on the projector, or a pair that already had newsroom):

```bash
cd "$PACK"
./scripts/Reset\ Workshop.command --theme newsroom
```

`--yes` skips the confirm dialog. The Desktop copy is updated from the pack Starter after seeding. Do not commit the seed in this repo.

Theme ids:

| id | Window title |
|---|---|
| `clinic-linen` | Ward Initiative |
| `lecture-hall` | Campus Mac Brief |
| `shopfloor` | Floor Brief |
| `trading-floor` | Desk Brief |
| `kitchen-pass` | Service Brief |
| `newsroom` | Desk File |
| `workshop-bay` | Bay Brief |
| `chambers` | Matter Brief |
| `lab-bench` | Lab Brief |
| `depot` | Yard Brief |

See the current seed without guessing:

```bash
cat "$PACK/Starter/SEED.md"
# or
cat /Users/Ambassador/Desktop/Starter/SEED.md
```

---

## Open the handout / project / finished demo

```bash
open "$PACK/exercise.html"
open "$PACK/Starter/Ambassadors26.xcodeproj"
```

Reset already reopens the handout with ticks cleared. To do that by itself,
open it as a **URL** (macOS `open path#reset` looks for a file named
`exercise.html#reset` and fails):

```bash
open -u "file://$PACK/exercise.html#reset"
```

Answer-key app (staff only — not for the pairs):

```bash
open ../Ambassadors26/Ambassadors26.xcodeproj
```

Warm the speech assets from that finished app: Run it, click **Record call** once, stop. Do this on every Mac **before** the room fills.

---

## Gallery (Safari, not the Mac app)

Pairs open the home page, enter a team name and the event PIN, and work the
exercise in that tab. Staff watch `/admin`. The wall is the leaderboard.

- Join: https://ambassadors26.up.railway.app
- Wall: https://ambassadors26.up.railway.app/wall
- Admin: https://ambassadors26.up.railway.app/admin
- Event PIN (rehearsal): `ondevice`
- Staff PIN (rehearsal): `staff`

Local rehearsal:

```bash
cd "$PACK/leaderboard"
npm install
EVENT_PIN=ondevice ADMIN_PIN=staff npm start
```

Then http://localhost:3000 — in-memory, gone on restart. Live deploy notes are in `leaderboard/README.md`.

---

## What reset actually runs

You do not type these. They are inside `Reset Workshop.command`, listed here so you can see what “reset” means.

```bash
# quit the workshop app
osascript -e 'tell application "Ambassadors26" to quit'

# restore the stock three-pane shell into Starter/ (not git reset of this pack)
rsync -a --delete scripts/starter-stock/ Starter/
# overlay AGENTS.md / BUILD-SPEC.md / skills from scripts/starter-overlay/
python3 scripts/apply_seed.py --starter Starter   # or --theme <id> / rescue keeps the current id
# if /Users/Ambassador/Desktop/Starter exists, copy the restored+seeded pack Starter onto it

rm -rf /Users/Ambassador/Library/Developer/Xcode/DerivedData/*Ambassadors26*
find /Users/Ambassador/Desktop -maxdepth 1 \( -name 'Screen Shot *.png' -o -name 'Screenshot *.png' \) -mtime -1 -delete
open -u "file://$PACK/exercise.html#reset"
```

Rescue is the same restore + overlay + seed, but it passes this pair’s theme id and skips the screenshot/tick cleanup.
