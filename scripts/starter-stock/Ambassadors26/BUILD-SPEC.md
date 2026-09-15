# BUILD-SPEC — Mac Initiative Builder

You are helping a sales rep build this app by describing what they want in plain English.
They are not a programmer. They will ask for outcomes, not implementations. This file is
where the implementation detail lives — read it, then make their request real.

## How to work

- **Ask them nothing unless you're genuinely blocked.** They can't answer technical
  questions. Choose sensibly and tell them what you chose.
- **Always finish by building the app**, and fix any compile errors before you stop.
- **Never break what already works.** Each request adds to a working app.
- **Report back in their language:** what the app can now do, and what to click to see it.
  One short paragraph. No code in your summary.
- If a request is vague, match it to a section below and build that whole section.

## Request routing

Match what they say to a section. They will not use these words.

| When they say something like… | Build |
|---|---|
| "read the notes", "tell me what to pitch", "make the button work", "what should I sell them", "wall of text", "proper fields", "put it in our CRM", "how urgent is it" | §1 Structured initiative |
| "write the email", "the follow-up", "send it to the customer" | §2 Follow-up email |
| "listen to me", "record the call", "I don't want to type", "take notes for me" | §3 Live transcription |
| "stand out", "make it ours", "look different", "colour", "theme" | House style — follow SEED.md, then push the look |
| "prove it works", "check your work", "test it" | §4 Tests (take-home only) |

## Non-negotiables

These apply to everything, and matter more than anything else in this file.

1. **Everything runs on this Mac.** Use Apple's on-device frameworks only. Never call a
   network API, web service or third-party model. Never ask for an API key. The entire point
   of this app is that the customer's words never leave the laptop — if you reach for the
   cloud, you have built the wrong app. Do not add a submit button, team-name field, or
   leaderboard. Screenshot upload happens in Safari, outside this app.
2. **macOS 27 only.** Don't reintroduce iOS or visionOS settings.
3. **Use the modern API, not the popular one.** Where this file names a specific framework or
   type, use exactly that, even if an older API is more common in your training data. The
   named ones are correct for macOS 27.
4. Keep everything from previous steps working.

## House style

- Model-facing logic goes in its own file, in a `@MainActor @Observable final class`.
- Model each long-running job as a phase enum — typically `idle`, working, `result(…)`,
  `failed(String)` — and let the UI switch on it. No booleans-plus-optionals.
- Every failure is visible to the rep as a short, plain-English notice in the relevant pane.
  Never fail silently, and never show a raw stack trace.
- Buttons that start work show a spinner and a present-tense label while running, and disable
  themselves.
- Keep the three panes: `PaneHeader` for pane titles, `ContentUnavailableView` for empty
  states. No custom fonts.
- If `SEED.md` is present, that is this session: window title, accent tint, empty-state
  symbol, sample notes, and industry. Do not replace the sample with a different customer
  story. Do not flatten the tint back to default grey.
- When they ask to stand out, keep every control working (**Use sample**, **Record call**,
  **Build initiative**, **Copy**, **Open in Mail**) and push the look further — colour,
  badge, empty-state copy — without collapsing the three panes.
- Label controls for VoiceOver, and mark decorative icons as hidden.
- Comment the *why*, not the *what*, and only where a reader would otherwise wonder.

---

## §1 Structured initiative

Make the "Build initiative" button turn the notes into a structured recommendation. Do this
in one step: the model must fill a `MacInitiative` directly. Do **not** first return a
paragraph of prose and then parse it.

- New class `InitiativeAnalyzer`, `@MainActor @Observable final`.
- Use **FoundationModels** and `LanguageModelSession`.
- Phase enum: `idle`, `analyzing`, `result(MacInitiative)`, `failed(String)`.
- Trim the notes; if they're empty, do nothing at all — never send blank input to the model.
- Session instructions, in substance: *you are a sales engineer in Apple's enterprise channel.
  You are given rough notes from a sales conversation with an organisation. Turn them into a
  concise, actionable "Mac initiative" recommendation. Infer urgency from the strength of the
  signals — ageing fleet, rising support volume, security or data-privacy concerns, workflow
  friction. Identify the single most important underlying problem rather than listing
  symptoms. Recommend a concrete Apple solution — iPhone, iPad and/or Mac — appropriate to the
  workflow described. Prefer an on-device Apple Intelligence opportunity that directly
  relieves the stated pain, and explain the security benefit in terms of data staying on the
  device. Propose a measurable, low-risk next step such as a time-boxed pilot with a specific
  device count and duration. Keep every field short and specific. Do not invent facts the
  notes do not support.*
- `@Generable struct MacInitiative: Equatable` with a `@Guide` description on every property:
  - `customerPriority: Priority` — urgency, judged from device age, support burden, security
    exposure and workflow pain
  - `primaryProblem` — the single most important underlying problem, a short noun phrase
    (e.g. "Shared-device clinical workflow")
  - `recommendedSolution` — the Apple hardware and software, a short phrase (e.g. "iPhone and
    Mac pilot")
  - `onDeviceAIOpportunity` — a concrete way on-device Apple Intelligence helps *this*
    customer, a short phrase (e.g. "Clinical note structuring")
  - `securityRationale` — one short sentence on why on-device addresses their data concern
  - `nextAction` — a specific, measurable next step (e.g. "30-device, 6-week pilot")
- `@Generable enum Priority: Equatable, CaseIterable` — `high`, `medium`, `low`; with `label`
  ("High"/"Medium"/"Low") and `tint` (red/orange/green) in an extension.
- Analyzer calls `session.respond(to:generating: MacInitiative.self)`. **Delete all string
  parsing** — the model fills the structure directly.
- Middle pane becomes a result card: priority badge tinted by `tint` at the top, then one row
  per field with the field name above the value in small grey uppercase. Values wrap; the pane
  scrolls. Give `nextAction` visual weight — it's what the rep acts on. Placeholder when idle
  or analyzing; the error notice if it failed.
- Gate the UI on `SystemLanguageModel.default.availability`. When unavailable, show a notice in
  the left pane that says which of these it is, in plain English: device not eligible, Apple
  Intelligence not switched on, or model still downloading.

## §2 Follow-up email

- `@Generable struct FollowUpEmail: Equatable` — `subject`, `greeting`, `paragraphs`,
  `signOff`, `senderName`, each with a `@Guide`. Discrete fields so the layout is always
  right; never one pre-formatted blob.
  - `paragraphs: [String]` — `@Guide(..., .count(2...4))`. Each is one paragraph, no line
    breaks, excluding the greeting and sign-off.
  - `greeting` and `signOff` include their trailing commas ("Hi there," / "Best regards,").
- `formattedBody` computed property: greeting, blank line, paragraphs separated by blank
  lines, blank line, sign-off, newline, sender name.
- On a successful analysis, automatically start a **second** session drafting the email from
  the initiative plus the original notes. Separate phase enum (`idle`, `composing`,
  `ready(FollowUpEmail)`, `failed`) so the two panes spin independently.
- Email instructions, in substance: *warm, concise, professional proposal email. Acknowledge
  the situation, propose the recommended solution and its on-device security benefit in plain
  language, lead into the specific next step. Avoid jargon and hype. Sender name "The team".*
- Right pane: subject prominent, then `formattedBody`, scrollable and selectable. A **Copy**
  button (`NSPasteboard`) and an **Open in Mail** button (percent-encoded `mailto:` URL with
  subject and body).

## §3 Live transcription

- New class `CallRecorder`, `@MainActor @Observable final`.
- Use **`SpeechAnalyzer`** with a **`SpeechTranscriber`** module, fed from `AVAudioEngine`
  input via an `AsyncStream` of `AnalyzerInput`. **Do not use `SFSpeechRecognizer`** — it is
  deprecated and is not the on-device pipeline this app exists to demonstrate.
- `SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)`; if none, phase
  `unsupported`. Preset `.progressiveTranscription` so text appears while they're still
  talking. Install assets first via `AssetInventory.assetInstallationRequest` if needed.
- Keep finalised text and the volatile tail as separate strings, publishing their
  concatenation, so the tail is *replaced* rather than appended — otherwise the text stutters
  and duplicates words.
- Phases: `idle`, `preparing`, `recording`, `unauthorized`, `unsupported`, `failed(String)`.
- Microphone permission via `AVCaptureDevice`. The project already has the microphone usage
  description and the audio-input sandbox entitlement. Do not strip them.
- On stop: stop the engine, remove the tap, finish the stream, then
  `finalizeAndFinishThroughEndOfInput()` so in-flight audio still lands, then fold the tail in.
- UI: a "Record call" button beside "Use sample" that becomes a red "Stop recording" with a
  visible recording notice; disabled while `preparing`. Live text **appends to** whatever notes
  are already there — capture them before recording starts and never overwrite them.

## §4 Tests (take-home only)

Do not build this during the live session unless they explicitly ask.

- Unit test target using **Swift Testing** (`@Test`, `#expect`, `@Suite`) — not XCTest.
- Fast deterministic suite, no microphone or model: priority labels, tints, every case has a
  non-empty label, `formattedBody` layout, and `Equatable` for identical and single-field-
  different initiatives.
- One integration suite that runs a real analysis of the sample notes. Assert only on
  structure — every field non-empty, priority a valid case. **Never assert on generated
  wording**; it varies per run. Also assert blank input never reaches the model.
- Mark it `@Suite(.enabled(if: SystemLanguageModel.default.isAvailable))` so it skips rather
  than fails where Apple Intelligence is unavailable.
- Run the tests and report the result.

---

## Sample notes

Used by the "Use sample" button. Use whatever is already in `ContentView.swift` — it is
set per session from `SEED.md`. Do not swap in a different industry story.
