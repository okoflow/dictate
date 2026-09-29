# dictate

Push-to-talk dictation for macOS. Hold a key, speak, release — the text appears wherever your
cursor is, in any app. Russian, English and Korean.

> **Status: early development.** Push-to-talk recording works (stage M1): hold the hotkey and Dictate
> records your voice. Recognition and text insertion arrive in the next stages. See [Roadmap](#roadmap).

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
are granted and a crossed-out one otherwise; the menu lists what is missing and shows the hotkey status
("Hold right ⌥ to dictate", or "Hotkey unavailable: grant Input Monitoring").

## Push-to-talk

**Hold the right Option key** anywhere, speak, release. Dictate starts the microphone when the key goes
down and converts the audio to 16 kHz mono for recognition (M2). Starting the audio engine takes about
0.2 s, so the very first syllable can be missed if you speak the instant you press; start speaking a
beat after the key goes down. (Keeping the engine warm to remove that delay is future work.) The end of
your last word is kept: recording continues for a moment after release to catch audio still in flight.

- A floating pill with a level meter appears after 0.3 s of holding. It never takes focus, so the
  app you are typing in stays active.
- Presses shorter than 0.3 s are ignored.
- Right Option combined with another key (Option+letter, for special characters) is not dictation:
  the recording is dropped and the character is typed as usual. The hotkey only *listens*; it never
  swallows a key.
- The left Option key does nothing.
- On layouts that use right Option as AltGr the pill does not flash for such combinations, but the
  orange microphone indicator in the menu bar can blink briefly, because recording starts immediately.
- A recording stops on its own after 5 minutes, if macOS switches the key listener off, or if the key-up is lost.

### Launch options

Meant for diagnostics and the E2E suite; a normal launch passes none.

| Flag | Effect |
|---|---|
| `--report-file <path>` | write the permission report there at launch |
| `--event-log <path>` | append what the app does (recording started/finished/discarded, overlay, ...) as JSON lines; never contains audio or text |
| `--recording-dir <dir>` | keep every finished recording there as a 16 kHz mono WAV |
| `--input-device <name>` | record from the input device with this name (or CoreAudio UID) instead of the system default |

For example: `open -n build/Dictate.app --args --recording-dir ~/dictate-recordings`.

### Manual check: the hotkey survives a disabled listener

macOS switches a key listener off when the app stops answering it, and this cannot be forced in the
automated suite (unit tests cover the state machine). To check the recovery by hand:

```sh
open -n build/Dictate.app --args --event-log /tmp/dictate.jsonl --recording-dir /tmp/dictate-rec
pkill -STOP -x Dictate   # freeze the app
# press and release right Option a few times, wait ~5 s
pkill -CONT -x Dictate   # let it run again
```

Then hold right Option for a second, twice. A `tapReenabled` line must appear in the log, and after it
the hold must record (`recordingStarted`, then `recordingFinished` with a file in `/tmp/dictate-rec`).
The press that arrives while macOS is still disabling the listener can be lost; the next one must work.

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

- Audio is processed on your Mac. It is kept in memory only while you hold the hotkey; nothing is
  written to disk unless you start Dictate with `--recording-dir`.
- Text goes to a cloud LLM only in Clean / Formal / Translate, and the menu shows a cloud icon then.
- Text you dictate is never written to logs (only lengths and timings).
- Your own voice recordings used for testing live in `fixtures/private/`, which is git-ignored.

## Development

```sh
make check   # format, lint, strict build, unit tests + coverage, dead code, secrets, shell scripts
make e2e     # end-to-end suite (local only: needs permissions and BlackHole)
make help    # all targets
```

A stage is done when `make check` and `make e2e` (including all earlier stages) are green.
**Do not touch the keyboard while `make e2e` runs**: it presses Option and types letters itself, and
your own key presses would be mixed into those. The suite also switches the input layout to ABC for
one check and restores it afterwards.
If a run was aborted and Option seems stuck, tap right Option. (Ctrl-C and `kill` are handled: the runner
releases the keys, restores the layout and quits both apps before exiting.)

`make e2e` exits with code 2 when nothing failed but a check waits for something only you can do
(a permission, a signing identity); the BLOCKED lines say what.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

- [x] M0 skeleton, test harness, quality gates
- [x] M1 push-to-talk and recording
- [ ] M2 speech recognition (ru / en / ko)
- [ ] M3 text insertion, Raw mode (MVP)
- [ ] M4 Light / Clean / Formal / Translate modes
- [ ] M5 personal dictionary, snippets, history, per-app mode

## License

[MIT](LICENSE)
