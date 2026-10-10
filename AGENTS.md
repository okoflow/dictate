# Dictate

Push-to-talk dictation for macOS. Holding the right Option key records the
microphone, Whisper recognizes the speech on the Mac through WhisperKit, a
mode cleans the text up offline or with Claude or OpenAI, and the result is
pasted into the focused field through the clipboard.

Swift package: `DictateCore` (domain and every interface, Foundation only),
`DictateSpeech` (WhisperKit adapter), `DictatePlatform` (macOS adapters),
`DictateFeatures` (main-actor models, dictation flow, SwiftUI interface),
`Dictate` (app and composition root).
[docs/architecture.md](docs/architecture.md) explains the layering;
[CONTRIBUTING.md](CONTRIBUTING.md) the conventions and checks.

- `make check` runs every check CI runs and must pass; `make run` builds,
  signs, and opens the app.
- The package builds with the Command Line Tools alone: no `@State`,
  `@Entry`, `@Animatable`, or `#Preview`.
- No comments in code. Commits follow Conventional Commits.
