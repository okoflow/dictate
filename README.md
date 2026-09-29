# dictate

Push-to-talk dictation for macOS. Hold a key, speak, release — the text appears wherever your
cursor is, in any app. Russian, English and Korean.

> **Status: early development.** Push-to-talk and speech recognition work (stages M1 and M2): hold the
> hotkey, speak, and the text lands **in the clipboard** (paste it with ⌘V). Inserting it for you arrives
> in the next stage. See [Roadmap](#roadmap).

## Planned modes

| Mode | What it does | Leaves your Mac? |
|---|---|---|
| **Raw** | Whisper's text as-is | no |
| **Light** | Offline rules: drops fillers ("um", "ээ", "음"), fixes spacing and punctuation | no |
| **Clean** | LLM removes false starts and self-corrections, fixes grammar. Keeps your language | **yes** |
| **Formal** | Clean, in a business tone | **yes** |
| **Translate→EN** | Translates to English | **yes** |

Recognition runs locally ([WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), Apple Silicon).
Only Clean, Formal and Translate send text (never audio) to an LLM API, and only if you set a key.
If the network fails, they fall back to Light.

## Requirements

- macOS 14+, Apple Silicon
- Swift 6 toolchain (Xcode or Command Line Tools), and about 0.6 GB of disk for the speech model
- Dev tools: `brew install swiftlint swiftformat periphery gitleaks shellcheck lefthook`
- For end-to-end tests: [BlackHole](https://github.com/ExistentialAudio/BlackHole) (2ch) and the
  `say` voices Milena (ru), Samantha (en), Yuna (ko)

## Build and run

```sh
make signing   # once: stable code-signing identity (see Permissions)
make model     # optional: download the speech model now (the app also does it on first launch)
make bundle    # builds build/Dictate.app and build/TestPad.app
open build/Dictate.app
```

Dictate lives in the menu bar (no Dock icon). The icon is a filled microphone when all permissions
are granted and a crossed-out one otherwise; the menu lists what is missing and shows the hotkey status
("Hold right ⌥ to dictate", or "Hotkey unavailable: grant Input Monitoring"), the state of the speech
model, and the language choice.

## Speech recognition

Recognition runs on your Mac with [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) (Whisper
large-v3, Core ML). Russian, English and Korean; nothing else is ever chosen, even if the audio sounds like
Ukrainian or Japanese.

- **Model:** `openai_whisper-large-v3-v20240930_626MB` (large-v3 quantised), **606 MB** on disk. Change it
  with `--model <variant>` (any variant of `argmaxinc/whisperkit-coreml`; `openai_whisper-large-v3-v20240930`
  is the full 1.5 GB one).
- **Where it lives:** `~/Library/Application Support/Dictate/Models`. macOS also keeps a compiled copy for
  your chip in `~/Library/Caches/dev.dictate.app` (about 130 MB). **To delete everything:**
  `rm -r ~/Library/Application\ Support/Dictate/Models ~/Library/Caches/dev.dictate.app`.
- **First launch:** the app downloads the model (the menu shows "Downloading model… 42%"), then loads it. The
  first load makes Core ML compile the model for your chip and takes about a minute ("Loading model…");
  later launches take a few seconds. Push-to-talk works once the menu says "Ready"; a press before that
  shows what the model is doing ("Loading model (first launch ≈1 min)…", "Downloading model… 42%") and
  records nothing; a "Ready" pill appears when it is done. If the download fails the menu says why and "Retry" resumes it; if
  the load fails, "Retry" deletes the model and downloads it again. `make model` does the download and the first load from the terminal.
- **Language:** menu → Language: *Auto (ru / en / ko)*, Russian, English or Korean. The choice is remembered.
  Auto adds a short language-detection pass (about 0.6 s); pinning a language skips it.
- **Speed** (Apple M5): about 1 s to transcribe 10 s of speech, plus the 0.6 s detection in Auto mode.
  Recordings over 30 s are split at pauses.
- **Memory:** after loading, Activity Monitor shows about 130 MB resident (`ps` RSS) and `footprint` about
  36 MB idle; the `Bench` process reported 130 MB after 30 transcriptions. Core ML keeps the model weights
  in memory it manages itself (memory-mapped, partly on the Neural Engine), so the system's total use for
  the model is larger than these per-process figures; that total was not measured.
- **Result:** the text goes to the clipboard and its first 60 characters show on a small pill for 1.5 s.
  Paste with ⌘V. A recording without speech (silence, key clicks, steady noise: judged on how long the audio
  is louder than its own noise floor) is not sent to the model, and a result that looks made up (low
  confidence, repeated text, stock phrases such as "Thanks for watching" or "Продолжение следует" when they
  are the whole result) is dropped. In both cases nothing is copied and the pill says "Didn't catch that". You can keep dictating while a previous recording is still being
  recognised; the texts arrive in order, and the recording pill takes priority over the result pill.
- **Clipboard managers and other devices:** the item is marked with the `org.nspasteboard.TransientType` and
  `ConcealedType` flags, which well-behaved managers (Maccy, Alfred, Raycast, ...) honour by not storing it,
  and it is kept off Universal Clipboard (`currentHostOnly`), so it does not sync to your iPhone, iPad or
  other Macs. ⌘V works as usual.

## Push-to-talk

**Hold the right Option key** anywhere, speak, release. Dictate starts the microphone when the key goes
down and converts the audio to 16 kHz mono for recognition. Starting the audio engine takes about
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
| `--model <variant>` | use this WhisperKit model variant instead of the default |
| `--transcript-dir <dir>` | **test-only**: save each transcript as `<n>.txt` there. Honoured only when the environment has `DICTATE_E2E=1` (`open -n --env DICTATE_E2E=1 ...`); it puts dictated text on disk, so do not use it otherwise |

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

- Audio is processed on your Mac. It is kept in memory only while you hold the hotkey (and while it is
  being recognised); nothing is written to disk unless you start Dictate with `--recording-dir`.
- Recognition is fully local. The only network use is the one-time download of the model and its tokenizer
  from Hugging Face; no audio or text is sent anywhere.
- Dictated text goes to the clipboard only, marked so clipboard managers skip it and not synced to other devices.
- Text goes to a cloud LLM only in Clean / Formal / Translate, and the menu shows a cloud icon then.
- Text you dictate is never written to logs (only lengths, languages and timings). WhisperKit's own
  logging is off.
- Your own voice recordings used for testing live in `fixtures/private/`, which is git-ignored.

## Development

```sh
make check   # format, lint, strict build, unit tests + coverage, dead code, secrets, shell scripts
make e2e     # smoke end-to-end suite, run once (local only: needs permissions, BlackHole and `make model`)
make e2e-full # every end-to-end check, for a hand-off or on request
make bench   # recognition accuracy and speed on the fixtures (needs `make model`)
make help    # all targets
```

A stage is done when `make check` and a single `make e2e` (smoke) are green. Edge cases belong in unit
tests; accuracy is measured by `make bench`, not by the end-to-end suite. `make e2e-full` runs the smoke
checks plus the slower ones (overlay, short press, left Option, TestPad round trip, fixture validity).
**Do not touch the keyboard while `make e2e` runs**: it presses Option and types letters itself, and
your own key presses would be mixed into those. The suite also switches the input layout to ABC for
one check and restores it afterwards.
If a run was aborted and Option seems stuck, tap right Option. (Ctrl-C and `kill` are handled: the runner
releases the keys, restores the layout and quits both apps before exiting.)

`make e2e` and `make e2e-full` exit with code 2 when nothing failed but a check waits for something only you can do
(a permission, a signing identity); the BLOCKED lines say what.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

- [x] M0 skeleton, test harness, quality gates
- [x] M1 push-to-talk and recording
- [x] M2 speech recognition (ru / en / ko): text lands in the clipboard until M3
- [ ] M3 text insertion, Raw mode (MVP)
- [ ] M4 Light / Clean / Formal / Translate modes
- [ ] M5 personal dictionary, snippets, history, per-app mode

## License

[MIT](LICENSE)
