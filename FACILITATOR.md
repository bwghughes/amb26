# Facilitator notes

Rehearse against a clock. There is no slack in it.

The pairs only need the contest website (team name + event PIN, then the steps).
[exercise.html](exercise.html) is the offline fallback. Copy-paste for reset, rescue,
and seeding is in [COMMANDS.md](COMMANDS.md).

## Run sheet

| Time | What happens |
|------|----------------|
| **0:00–0:04** | Join on the website (team name + PIN). Open `Starter/`, Run, see the dead button. Paste the priming line if the assistant did not already follow `AGENTS.md` / `SEED.md`. |
| **0:04–0:16** | **Prompt 1** — structured key points. |
| **0:16–0:18** | Wi-Fi off. Change a word. Build again. |
| **0:18–0:28** | **Prompt 2** — follow-up email. |
| **0:28–0:36** | **Prompt 3** — live recording. Talk in the seed's industry, not only the hospital script. |
| **0:36–0:41** | **Prompt 4** — make it yours. Behind? Skip it. The seed already changed title, tint, and customer. |
| **0:41–0:45** | Wi-Fi on. Screenshot. Upload to the gallery. |

**Checkpoint at 0:28.** Any pair not finished with the email still says Prompt 3 so the
Record button exists, then screenshots using **Use sample**. A complete three-pane
screenshot beats a broken recording.

**If the mic fails:** they still submit. Sample notes + initiative + email is a valid
screenshot. Do not debug TCC in the last five minutes.

**Judging the wall.** Every screenshot must show notes, a filled initiative, and an email.
It should also look like *that pair's* app — seed plus whatever they did with prompt 4.
A grey clone of the projector demo is an incomplete submission even if the fields are there.

## Before the day — this decides whether it works

**On every machine:**

- [ ] macOS 27, Xcode 27, opened once with components installed.
- [ ] Apple Intelligence **on and fully downloaded**. It pulls several GB in the background and reports "unavailable" until it's finished.
- [ ] Xcode's Coding Assistant signed in and working — send it a throwaway prompt and confirm it can edit a file.
- [ ] **Dictation on and tested** (System Settings → Keyboard → Dictation). Confirm the shortcut works in Xcode's assistant field.
- [ ] `Starter/` copied to the Desktop, **opened in Xcode and run once** — warms the build so their first rebuild is seconds, not a minute.
- [ ] **Workshop agent installed** on every contest Mac:
      `curl -fsSL https://ambassadors26.up.railway.app/install | bash`
      Confirm each Computer Name appears under Workshop Macs on `/admin`.
- [ ] **Reset Workshop run once before doors** (dashboard **Reset all**, or `scripts/Reset Workshop.command`) so the first pair is not all on hospital grey.
- [ ] The finished app (`../Ambassadors26`) built and run once too, **including the record button** — pre-downloads the speech assets. Twenty Macs doing that on conference Wi-Fi is how you lose the session.
- [ ] ~30 GB free disk.

**In the room:**

- [ ] [exercise.html](exercise.html) as a fallback if the site is down. [prompts.txt](prompts.txt) if dictation misbehaves.
- [ ] Contest URL and event PIN on the projector. Rehearsal defaults:
      [https://ambassadors26.up.railway.app](https://ambassadors26.up.railway.app)
      PIN `ondevice`
- [ ] Staff admin open on your machine:
      [https://ambassadors26.up.railway.app/admin](https://ambassadors26.up.railway.app/admin)
      PIN `staff`
- [ ] One test join + screenshot before doors.
- [ ] Show them where the Coding Assistant lives in your Xcode 27 build on the projector first — where to talk, how to see proposed edits, how to accept them. Don't rely on a written menu path; the beta moves.

## Rules for the pairs

1. **Say it, don't type it** — dictation key, sentence, dictation key. Mention that the dictation is on-device too.
2. **Say it in your own words** once you've heard the gist. The sentences in `prompts.txt` are a floor, not a script.
3. **Read what changed** — not to check the Swift, to check it did what you asked.
4. **If the build breaks, paste the error and say "fix this".** One or two rounds is normal.
5. **Two failed rounds:** staff double-click `scripts/Rescue Session.command` (or
   `./scripts/Rescue\ Session.command` from the pack). That rewinds to *this pair's
   seed*, not a blank grey app. Then they say it again.
6. **Swap who's driving** each time.

## Debrief — two minutes

- Every pair's app looks different. Same three jobs, different colour and customer, still works.
- **Someone wrote the spec.** The sentence is short because the detail was captured once, up front. That's the bit they can take back to their own job.
- Name the specific thing you want. Ask vaguely for "speech to text" and you get a deprecated API that compiles and mostly works.
- Nothing they said in the conversation notes left the laptop. The screenshot upload is a photo of the result, taken afterwards, with Wi-Fi back on.
- The on-device model is small and fast. Excellent at pulling structure out of messy notes. It will not write anyone's account strategy.

## When it goes wrong

| Symptom | Fix |
|---|---|
| "Apple Intelligence not available" notice | The app is right, the Mac isn't ready. Not fixable in the room — pre-flight prevents it. |
| Assistant built something odd | *"Have another look at BUILD-SPEC.md — that isn't what it asks for."* |
| Build fails | Paste the error, *"fix this"*. Two failed rounds → Rescue Session, then say it again. |
| It broke something that worked | *"You've broken something that was working — put it back."* |
| It asked for an API key | *"No. This has to run on the Mac, on device. No network calls."* |
| Dictation mangles the sentence | Paste from `prompts.txt` and move on. |
| Pair is two sentences behind | Sample notes + screenshot. Everyone ends with something on the wall. |
| Gallery rejects the team name | That name is already in. If it's theirs, same name + PIN resumes. Otherwise pick another. |
| Words only appear after they stop talking | *"Use SpeechAnalyzer, not SFSpeechRecognizer. I want the words while I'm still talking."* |

## Answer key

The finished Mac app is `../Ambassadors26`. Do not give pairs that project. `Starter/` is
what they open.

## Reset between pairs

On the staff dashboard, **Reset** that Mac or **Reset all Macs**. The workshop
agent runs [`scripts/Reset Workshop.command`](scripts/Reset%20Workshop.command)
`--yes` on the machine.

Or double-click the script locally and confirm **Reset**. Either way it:

1. Quits the app.
2. Restores `Starter/` from `scripts/starter-stock/` (the stock three-pane shell), then
   overlays agent docs. If `~/Desktop/Starter` exists, that copy is replaced with the
   restored+seeded pack Starter.
3. Picks a new theme (accent, title, empty-state symbol, sample notes, spoken line) and
   writes `SEED.md`.
4. Does **not** commit, and does **not** `git reset` this pack. Mid-session rescue
   re-applies the current `SEED.md` / `.session-last-theme` instead of picking a new look.
5. Clears this app's DerivedData, today's Desktop window screenshots, and the exercise ticks.
6. Leaves the Railway gallery alone. Safari is sent back to the join page.

Do not use `git clean -x`. Do not `git reset --hard` this repo. Do not run reset while a
pair is still working — it destroys their project. The first time on a machine, macOS may
ask you to allow the script.

Primary Mac setup is `curl -fsSL https://ambassadors26.up.railway.app/install | bash`.
Uninstall and the double-click fallback are in [COMMANDS.md](COMMANDS.md).
