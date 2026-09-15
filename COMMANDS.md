# Staff commands

Copy-paste from the **codealong folder** (the one that contains `Starter/`, `scripts/`, and `exercise.html`). Replace `$PACK` if you are not already in that folder.

```bash
cd /path/to/Ambassadors26-CodeAlong
```

The pairs never need these. They talk to Xcode. You run reset between pairs, and `git checkout .` if a pair’s build is stuck.

Do not run any of this while a pair is still working.

---

## Reset the Mac for the next pair

**Normal path — double-click**

`scripts/Reset Workshop.command`

First time on a machine: Right-click → **Open**, then allow it. After that, double-click is enough.

Confirm **Reset**. It quits the app, rewinds the project, picks a new look, commits that seed, clears this app’s DerivedData, deletes today’s Desktop *window* screenshots, and reopens the handout with the ticks cleared. The gallery on the web is not touched.

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

**Install** (first time: Right-click → Open):

```bash
open "$PACK/scripts/Install Workshop Agent.command"
```

Accept the contest URL (`https://gallery-production-85f3.up.railway.app`) and the
agent secret (`workshop-reset` unless you changed `AGENT_SECRET` on Railway).
The Mac appears on https://gallery-production-85f3.up.railway.app/admin under
**Workshop Macs**, named with that Mac's Computer Name.

**From the dashboard:** **Reset** on one Mac, or **Reset all Macs**. Confirm. The
Mac must be able to reach the site. If Wi-Fi is off, the reset is queued and
runs when it comes back.

**Uninstall:**

```bash
open "$PACK/scripts/Uninstall Workshop Agent.command"
```

Log: `~/Library/Logs/ambassadors26-agent.log`

Do not install this on a Mac you are still building on — a dashboard reset
wipes `Starter/` the same way the local script does.

---

## Rescue during a session (pair, not staff reset)

Two failed builds. This rewinds to **this pair’s seed**, not a blank app.

They must be in the same `Starter` folder Xcode has open — usually the Desktop copy:

```bash
cd ~/Desktop/Starter
git checkout .
```

If they opened the copy inside this repo instead:

```bash
cd "$PACK/Starter"
git checkout .
```

Then they say the sentence again.

Do **not** use `git reset --hard` or `git clean -x` as the rescue. `git clean -x` would throw away `SEED.md` and the pair’s look. The reset script is the only thing that should rewind to the original commit.

---

## Force a look (staff only)

The reset script picks a random theme and avoids the one it used last. To pin one (demo on the projector, or a pair that already had newsroom):

```bash
cd "$PACK"
python3 scripts/apply_seed.py --starter "$PACK/Starter" --theme newsroom
cd "$PACK/Starter"
git add -A
git commit -m "session seed: Newsroom"
```

If they are working from the Desktop copy, do the Desktop folder too, **same theme id**:

```bash
python3 scripts/apply_seed.py --starter ~/Desktop/Starter --theme newsroom
cd ~/Desktop/Starter
git add -A
git commit -m "session seed: Newsroom"
```

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
cat ~/Desktop/Starter/SEED.md
```

---

## Open the handout / project / finished demo

```bash
open "$PACK/exercise.html"
open "$PACK/Starter/Ambassadors26.xcodeproj"
```

Reset already opens `exercise.html#reset` (clears the ticks). To do that by itself:

```bash
open "$PACK/exercise.html#reset"
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

- Join: https://gallery-production-85f3.up.railway.app
- Wall: https://gallery-production-85f3.up.railway.app/wall
- Admin: https://gallery-production-85f3.up.railway.app/admin
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

# in Starter/ and in ~/Desktop/Starter if that copy exists:
git rev-list --max-parents=0 HEAD          # original starter commit
git reset --hard <that-commit>
git clean -fd                              # not -x
# overlay AGENTS.md / BUILD-SPEC.md / skills from scripts/starter-overlay/
python3 scripts/apply_seed.py --starter <dir>
git add -A
git commit -m "session seed: <theme name>"

rm -rf ~/Library/Developer/Xcode/DerivedData/*Ambassadors26*
find ~/Desktop -maxdepth 1 \( -name 'Screen Shot *.png' -o -name 'Screenshot *.png' \) -mtime -1 -delete
open exercise.html#reset
```
