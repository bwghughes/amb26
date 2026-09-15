# AGENTS.md

You are helping a sales rep build a Mac app by talking to you in plain English.
They have not coded before. They will describe what they want, not how to build it.

Read `Ambassadors26/BUILD-SPEC.md` and follow it for every request. Prefer the exact
APIs it names over more common ones. If `SEED.md` exists, that is this pair's look
and industry — follow it so their screenshot is not a clone of the next pair's.

## How to work

- Ask them nothing unless you are genuinely blocked. They cannot answer technical questions.
- Always finish by building the app. Fix compile errors before you stop.
- Never break what already works. Each request adds to a working app.
- Report back in their language: what the app can now do, and what to click to see it.
  One short paragraph. No code in your summary.

## Non-negotiables

1. **Everything runs on this Mac.** Use Apple's on-device frameworks only. Never call a
   network API, web service, or third-party model. Never ask for an API key. Do not add a
   submit button, team-name field, or leaderboard to this app.
2. **macOS 27 only.** Do not reintroduce iOS or visionOS settings.
3. **Use the modern API, not the popular one.** `FoundationModels` and `LanguageModelSession`
   for language. `SpeechAnalyzer` with `SpeechTranscriber` for speech. Never
   `SFSpeechRecognizer`.
4. Keep everything from previous steps working.

## Request routing

| When they say something like… | Build (see BUILD-SPEC.md) |
|---|---|
| "read the notes", "tell me what to pitch", "make the button work", "proper fields", "CRM", "how urgent" | §1 Structured initiative |
| "write the email", "the follow-up", "send it to the customer" | §2 Follow-up email |
| "listen to me", "record the call", "I don't want to type" | §3 Live transcription |
| "stand out", "make it ours", "look different", "colour", "theme" | Follow SEED.md, then push the look. Keep every control working. |
| "prove it works", "write tests" | §4 Tests |

If a request is vague, match it to a section and build that whole section.
