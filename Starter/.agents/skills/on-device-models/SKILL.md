---
name: on-device-models
description: Builds on-device Apple Intelligence features with FoundationModels and LanguageModelSession. Use when the user wants to read notes, pitch a customer, fill CRM fields, draft a follow-up email, or generate structured output on this Mac with no network.
---

# On-device Foundation Models

Use this skill whenever the request involves understanding notes, structured recommendations, or drafting email. Follow `Ambassadors26/BUILD-SPEC.md` for field names and session instructions.

## Rules

- Import `FoundationModels`. Use `LanguageModelSession` and `SystemLanguageModel.default`.
- Never call a network API, OpenAI, a cloud SDK, or ask for an API key.
- Put model-facing logic in a `@MainActor @Observable final class` in its own file.
- Gate the UI on `SystemLanguageModel.default.availability`. Map unavailable reasons to plain English: device not eligible, Apple Intelligence not switched on, or model still downloading.
- Trim input. If notes are empty, do nothing — never send blank input to the model.

## Structured output

Do not return a paragraph and parse it. Define a `@Generable` type and call:

```swift
let response = try await session.respond(to: prompt, generating: MacInitiative.self)
```

Every stored property needs a `@Guide` description. For `FollowUpEmail.paragraphs` use `@Guide(..., .count(2...4))`.

`Priority` is a `@Generable enum` with `high`, `medium`, `low`. Add `label` and `tint` in an extension (High/red, Medium/orange, Low/green).

## Phases

Model long-running work as an enum: `idle`, working, `result(…)`, `failed(String)`. The UI switches on it. Buttons show a spinner and a present-tense label while running.

Email is a **second** session with its own phase (`idle`, `composing`, `ready(FollowUpEmail)`, `failed`) so the panes spin independently. Start it automatically after a successful analysis.

## Copy and Mail

Copy with `NSPasteboard`. Open Mail with a percent-encoded `mailto:` URL. Encode conservatively so `& + = ?` survive the query.
