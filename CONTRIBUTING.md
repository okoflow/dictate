# Contributing

Thanks for helping. The short version: `make check` must be green before you open a PR.

## Setup

```sh
brew install swiftlint swiftformat periphery gitleaks shellcheck lefthook
make hooks      # pre-commit: format, lint, shellcheck, secrets
make signing    # once, so macOS keeps permissions between rebuilds
```

## What `make check` runs

| Step | Tool | Fails on |
|---|---|---|
| `format-check` | SwiftFormat `--lint` | any formatting difference (`make format` fixes it) |
| `lint` | SwiftLint `--strict` | any warning, including force unwraps and over-long functions |
| `build` | `swift build` | any compiler warning (Swift 6 language mode, `-warnings-as-errors`) |
| `test` + `coverage` | `swift test`, llvm-cov | a failing test, or `DictateCore` line coverage below 70% |
| `periphery` | Periphery | unused code |
| `secrets` | gitleaks | secrets in history or the working tree |
| `shellcheck` | ShellCheck | problems in `scripts/*.sh` |

Do not weaken rules to get a green run. If a rule is wrong for one line, add a targeted
`// swiftlint:disable:next <rule>` with a comment explaining why.

## End-to-end tests

`make e2e` drives the real apps: it launches `Dictate.app` and `TestPad.app`, and uses the
Accessibility API to read and write text. It needs macOS permissions, so it runs locally, not in CI.
Grant Accessibility to your terminal app and to `Dictate.app` (menu bar icon → Grant…).

Every stage adds its own e2e checks **and** must keep all earlier ones green.

Speech fixtures are generated with `say` (`make fixtures`) from `fixtures/manifest.json`.
Real human speech for accuracy tests comes from [Google FLEURS](https://huggingface.co/datasets/google/fleurs)
(CC-BY 4.0): `make fixtures-real` downloads 5 clips per language with exact transcripts into
`fixtures/private/` (git-ignored, attribution in `fixtures/private/SOURCES.md`). If you record your own
voice, put it there too (`<lang>-<n>.wav` + `<lang>-<n>.txt`) — never commit it.

## Architecture in one paragraph

A pipeline of replaceable stages: `AudioSource → Transcriber → Processor → Inserter`. Each stage is a
protocol so tests can swap the microphone for a WAV file and the network for a recorded response.
Pure logic lives in `DictateCore` (unit-tested); code that touches macOS APIs lives in the app target
and is covered by the E2E suite.

## Commits

Small, focused commits with an imperative subject line ("Add Light mode filler rules").
