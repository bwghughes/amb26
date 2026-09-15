---
name: workshop-ui
description: Keeps the Mac Initiative Builder three-pane SwiftUI shell consistent. Use when changing ContentView, empty states, buttons, badges, email layout, or VoiceOver labels.
---

# Workshop UI

Keep the existing three-pane window. Do not collapse it.

## Layout

`HSplitView` of conversation notes | initiative | follow-up email. `PaneHeader` for pane titles. `ContentUnavailableView` for empty states. No custom fonts.

If `SEED.md` exists, follow it for the window title, `.tint`, empty-state SF Symbol, and sample notes. When they ask to stand out, push colour and personality further. Do not flatten the accent back to default grey.

## Behaviour

- Model long-running jobs as phase enums. The view switches on the phase. No booleans-plus-optionals.
- Every failure is a short plain-English notice in that pane. Never fail silently. Never show a raw stack trace.
- Buttons that start work show a spinner and a present-tense label while running, and disable themselves.
- **Use sample** and **Build initiative** already exist. Add **Record call** beside **Use sample** when building speech. Do not add a submit-score control, team-name field, or server settings.

## Initiative card

Priority badge tinted by `Priority.tint` at the top. One row per field: small grey field name, wrapping value. `nextAction` has visual weight. The pane scrolls.

## Email pane

Subject prominent, then `formattedBody`, scrollable and selectable. **Copy** and **Open in Mail**.

## Accessibility

Label controls for VoiceOver. Mark decorative icons `.accessibilityHidden(true)`. Combine a row's title and value. Placeholder overlay text in the notes editor is decorative.
