# Mac Initiative Builder — codealong

Sales reps, in pairs, one MacBook Pro. They say **three sentences** out loud and a
half-built Mac app learns to record a sales conversation, pull out the key points, and
draft the follow-up email. No code. Analysis stays on the laptop.

**The reps only need one thing: the contest website.** Open it, enter a team name
and the event PIN, and work through the steps there. The same copy lives in
[exercise.html](exercise.html) as an offline fallback. At the end they upload a
screenshot from that tab.

Staff notes: [FACILITATOR.md](FACILITATOR.md). Copy-paste commands:
[COMMANDS.md](COMMANDS.md). MDM owner: [MDM.md](MDM.md). Take-home: [STRETCH.md](STRETCH.md). What to say, as plain
text: [prompts.txt](prompts.txt). After a pair leaves, **Reset** that Mac on the
staff dashboard (agent installed on each contest machine), or double-click
[`scripts/Reset Workshop.command`](scripts/Reset%20Workshop.command).

## Gallery

Pairs join at the home page, follow the exercise there, and upload a screenshot
at the last step. Staff watch live progress at `/admin` and judge the wall.

- Join (put this on the projector): [https://ambassadors26.up.railway.app](https://ambassadors26.up.railway.app)
- Wall: [https://ambassadors26.up.railway.app/wall](https://ambassadors26.up.railway.app/wall)
- Admin: [https://ambassadors26.up.railway.app/admin](https://ambassadors26.up.railway.app/admin)
- Event PIN (rehearsal): `ondevice`
- Staff PIN (rehearsal): `staff`
- Agent secret (rehearsal): `workshop-reset`
- Contest Mac setup (Xcode already on the machine): `curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash`

The gallery app is [`leaderboard/`](leaderboard/). Update the live URL here, in
`exercise.html`, and in `FACILITATOR.md` if the Railway domain changes.

## What's in this repo

| Path | Use |
|---|---|
| [exercise.html](exercise.html) | Participant handout — open this |
| [Starter/](Starter/) | The Xcode project the pairs open |
| [scripts/Reset Workshop.command](scripts/Reset%20Workshop.command) | Local rewind + new seed |
| [scripts/Rescue Session.command](scripts/Rescue%20Session.command) | Mid-session rewind to this pair’s seed |
| [scripts/starter-stock/](scripts/starter-stock) | Pristine three-pane shell reset copies from |
| [scripts/install-workshop-agent.sh](scripts/install-workshop-agent.sh) | Curlable Mac setup (GitHub raw on `main`) |
| [scripts/Install Workshop Agent.command](scripts/Install%20Workshop%20Agent.command) | Double-click fallback for `/admin` reset |
| [leaderboard/](leaderboard/) | Contest site (join, exercise, admin, wall) |
| [FACILITATOR.md](FACILITATOR.md) | Pre-flight and run sheet |
| [COMMANDS.md](COMMANDS.md) | Reset, rescue, seed — copy-paste |
| [MDM.md](MDM.md) | IT / Jamf: Codex API key on contest Macs |
| [prompts.txt](prompts.txt) | Everything to say, for the day |
| `../Ambassadors26` | Finished Mac app — staff answer key, not for the pairs |
