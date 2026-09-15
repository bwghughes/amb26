---
name: on-device-speech
description: Adds live on-device call recording and transcription with SpeechAnalyzer and SpeechTranscriber. Use when the user wants to record a call, listen, dictate notes, or stop typing notes. Never use SFSpeechRecognizer.
---

# On-device speech

Use this skill when they ask to record, listen, or have the app write notes while they talk.

## The named API

Use **`SpeechAnalyzer`** with a **`SpeechTranscriber`** module, fed from `AVAudioEngine` input via an `AsyncStream` of `AnalyzerInput`.

**Do not use `SFSpeechRecognizer`.** It is deprecated. It compiles and mostly works, which is worse than failing. If you reach for it, you have built the wrong app.

## Shape

New class `CallRecorder`, `@MainActor @Observable final`.

Phases: `idle`, `preparing`, `recording`, `unauthorized`, `unsupported`, `failed(String)`.

1. Microphone permission via `AVCaptureDevice`. The project already has `NSMicrophoneUsageDescription` and `ENABLE_RESOURCE_ACCESS_AUDIO_INPUT`. Do not remove them.
2. `SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)`. If none, phase `unsupported`.
3. `SpeechTranscriber(locale:locale, preset: .progressiveTranscription)` so words appear while they are still talking.
4. Install assets first: `AssetInventory.assetInstallationRequest(supporting: [transcriber])`, then `downloadAndInstall()` if needed.
5. Convert tap buffers into `AnalyzerInput` for the analyzer's expected format. Stream them through an `AsyncStream`.
6. Keep **finalised** text and the **volatile tail** as separate strings. Publish their concatenation. Replace the tail on partial results; do not append it. Otherwise the text stutters and duplicates words.
7. On stop: stop the engine, remove the tap, finish the stream, then `finalizeAndFinishThroughEndOfInput()` so in-flight audio still lands. Fold the tail into the finalised transcript.

## UI

- A **Record call** button beside **Use sample**. While recording it is a red **Stop recording**.
- Disabled while `preparing`. Show a recording notice.
- Live text **appends to** notes that were already there. Capture `notesBeforeRecording` before starting. Never overwrite typed notes.

## If they complain

- Words only after they stop → preset must be `.progressiveTranscription`, and the UI must publish partial results.
- Text repeats itself → replace the volatile tail, do not append it.
- Crashes on Record → microphone permission and audio-input sandbox entitlement.
- Notes they typed disappeared → append, do not replace.
