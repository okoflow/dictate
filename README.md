# dictate

Push-to-talk dictation for macOS. Hold a key, speak, release — the text appears wherever your
cursor is, in any app. Russian, English and Korean.

> **Status: early development.** Only the project skeleton exists so far (stage M0): a menu bar app
> that reports its permissions, a test harness and the quality gates. Recording, recognition and
> text insertion arrive in the next stages. See [Roadmap](#roadmap).

## Planned modes

| Mode | What it does | Leaves your Mac? |
|---|---|---|
| **Raw** | Whisper's text as-is | no |
| **Light** | Offline rules: drops fillers ("um", "ээ", "음"), fixes spacing and punctuation | no |
| **Clean** | LLM removes false starts and self-corrections, fixes grammar. Keeps your language | **yes** |
| **Formal** | Clean, in a business tone | **yes** |
| **Translate→EN** | Translates to English | **yes** |

Recognition runs locally ([WhisperKit](https://github.com/argmaxinc/WhisperKit), Apple Silicon).
Only Clean, Formal and Translate send text (never audio) to an LLM API, and only if you set a key.
If the network fails, they fall back to Light.

## Requirements

- macOS 14+, Apple Silicon
- Swift 6 toolchain (Xcode or Command Line Tools)
- Dev tools: `brew install swiftlint swiftformat periphery gitleaks shellcheck lefthook`
- For end-to-end tests: [BlackHole](https://github.com/ExistentialAudio/BlackHole) (2ch) and the
  `say` voices Milena (ru), Samantha (en), Yuna (ko)

## Build and run

```sh
make signing   # once: stable code-signing identity (see Permissions)
make bundle    # builds build/Dictate.app and build/TestPad.app
open build/Dictate.app
```

Dictate lives in the menu bar (no Dock icon). The icon is a filled microphone when all permissions
are granted and a crossed-out one otherwise; the menu lists what is missing.

## Permissions

| Permission | Why |
|---|---|
| Microphone | record your voice while the hotkey is held |
| Accessibility | insert text into the focused field, detect password fields |
| Input Monitoring | see the global hotkey |

macOS ties these grants to the app's **code signature**. An ad-hoc signature changes on every build,
so the grants would be lost after each rebuild. `make signing` creates a self-signed identity
("Dictate Dev") once and marks it trusted for code signing (macOS asks for your password). After that,
rebuilds keep their permissions.

Check what an app instance holds: `build/Dictate.app/Contents/MacOS/Dictate --print-permissions`
(when run from a terminal this reports the *terminal's* permissions; the E2E suite asks the
LaunchServices-launched app instead).

## Privacy

- Audio is processed on your Mac and is not stored.
- Text goes to a cloud LLM only in Clean / Formal / Translate, and the menu shows a cloud icon then.
- Text you dictate is never written to logs (only lengths and timings).
- Your own voice recordings used for testing live in `fixtures/private/`, which is git-ignored.

## Development

```sh
make check   # format, lint, strict build, unit tests + coverage, dead code, secrets, shell scripts
make e2e     # end-to-end suite (local only: needs permissions and, later, a microphone route)
make help    # all targets
```

A stage is done when `make check` and `make e2e` (including all earlier stages) are green.
`make e2e` exits with code 2 when nothing failed but a check waits for something only you can do
(a permission, a signing identity); the BLOCKED lines say what.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

- [x] M0 skeleton, test harness, quality gates
- [ ] M1 push-to-talk and recording
- [ ] M2 speech recognition (ru / en / ko)
- [ ] M3 text insertion, Raw mode (MVP)
- [ ] M4 Light / Clean / Formal / Translate modes
- [ ] M5 personal dictionary, snippets, history, per-app mode

## License

[MIT](LICENSE)
