# Development

## Tools

- Dev tools: `brew install swiftlint swiftformat periphery gitleaks shellcheck lefthook`
- For end-to-end tests: [BlackHole](https://github.com/ExistentialAudio/BlackHole) (2ch) and the
  `say` voices Milena (ru), Samantha (en), Yuna (ko)

## Commands

```sh
make check   # format, lint, strict build, unit tests + coverage, dead code, secrets, shell scripts
make e2e     # smoke end-to-end suite, run once (local only: needs permissions, BlackHole and `make model`)
             # the terminal needs Accessibility and Microphone (macOS asks for the latter when BlackHole starts)
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

### Modes in the E2E suite (M4)

The suite starts a local stand-in for the Anthropic API (`LLMProxy`, loopback only) and launches Dictate with
`--llm-endpoint` pointing at it, plus `--mode raw --language auto` so the M1–M3 checks see Whisper's text.
The mode checks dictate fixtures through a test-only notification (the WAV audio source: no keys, no focus
needed; the file is copied to the temporary directory first, because macOS asks before an app reads
`~/Documents`).

- `modes-offline`: Raw and Light on the ru/en/ko filler fixtures; Light must equal `LightRules` applied to the
  raw text and nothing may reach the proxy.
- `cloud-plumbing`: with a stub answer, the request (model, version header, placeholder key, prompt, transcript)
  and the delivered text.
- `cloud-fallback`: the proxy waits 4 s (→ Light at the 3 s deadline), then drops the connection (→ Light).
- `modes-cloud`, `clean-latency`: Clean/Formal/Translate on the filler fixtures, and 10 s of speech in Clean,
  with **recorded** answers from `e2e/cassettes/llm.json` (keyed by a hash of the request body, replayed with
  the latency measured live). Without recordings these checks are BLOCKED; record them once with a key:
  `E2E_LLM=live make e2e` (the key comes from `ANTHROPIC_API_KEY` or the app's Keychain item; only the proxy
  uses it). A changed prompt or a different transcript is a miss: re-record.
- `mode-cycle-hotkey`: ⌃⌥M five times (needs Accessibility for the terminal, like the push-to-talk checks).

M5 checks (same launch: an empty dictionary and history in the temporary directory, Chrome in Light):

- `dictionary-and-snippets`: ru-vocab-1 ("кубернетис") and en-vocab-1 ("WhisperKit") first with an empty
  dictionary, then with one: the term must come out as written; "Моя почта" must become the snippet in Raw and
  Light; the history file must end with it.
- `app-mode-in-chrome`: opens Chrome, dictates in Raw, expects Chrome's Light; then brings back the app that was
  in front.

`E2ERunner --suite smoke --only a,b` runs just the named checks while you work on them (the report is marked
partial); a stage hand-off runs the whole suite.

`make e2e` and `make e2e-full` exit with code 2 when nothing failed but a check waits for something only you can do
(a permission, a signing identity); the BLOCKED lines say what.

See also [CONTRIBUTING.md](../CONTRIBUTING.md).

## Launch options

Meant for diagnostics and the E2E suite; a normal launch passes none.

| Flag | Effect |
|---|---|
| `--report-file <path>` | write the permission report there at launch |
| `--event-log <path>` | append what the app does (recording started/finished/discarded, overlay, ...) as JSON lines; never contains audio or text |
| `--recording-dir <dir>` | keep every finished recording there as a 16 kHz mono WAV |
| `--input-device <name>` | record from the input device with this name (or CoreAudio UID) instead of the system default |
| `--clipboard-only` | never paste; copy the text to the clipboard (the menu setting forced off) |
| `--insert-only-into <bundle id>` | **test-only** (needs `DICTATE_E2E=1`): paste only into this app, and do nothing elsewhere |
| `--model <variant>` | use this WhisperKit model variant instead of the default |
| `--mode <raw\|light\|clean\|formal\|translate>` | use this mode for this launch (not saved) |
| `--language <auto\|ru\|en\|ko>` | use this language choice for this launch (not saved) |
| `--dictionary <path>` | use this dictionary file instead of the one in Application Support |
| `--history-file <path>` | keep the history in this file instead |
| `--app-mode <bundle>=<mode>,...` | use these per-app modes for this launch (not saved) |
| `--llm-endpoint <url>` | **test-only** (needs `DICTATE_E2E=1`): send ☁︎ requests there instead of the Anthropic API, with the placeholder key `e2e` (the real key never goes to another address) |
| `--transcript-dir <dir>` | **test-only**: save each delivered text as `<n>.txt` and what Whisper heard as `<n>.raw.txt` there. Honoured only when the environment has `DICTATE_E2E=1` (`open -n --env DICTATE_E2E=1 ...`); it puts dictated text on disk, so do not use it otherwise |

For example: `open -n build/Dictate.app --args --recording-dir ~/dictate-recordings`.

## Manual checklist (not automated)

- **TextEdit:** type "Hello", dictate: " ..." is added after "Hello"; at the start of an empty document there
  is no leading space; after a newline there is none either.
- **Modes:** set an API key (menu), dictate "um, move the call to Thursday, no, Friday" in Clean: "Move the
  call to Friday."; turn Wi-Fi off and dictate again: Light text and the pill says "Light: offline"; press ⌃⌥M
  in a text field: the mode changes and nothing is typed there.
- **Chrome:** a text field and a textarea (Gmail, a search box); a password field must stay empty and show the
  "Not typed into a password field" pill; then Copy last transcript works.
- **Terminal:** dictate at the prompt (the text lands on the command line, not executed); switch on
  Terminal → Secure Keyboard Entry and dictate again: it should still paste (the event log shows
  `secureInputActive: true`).
- **Telegram / Slack:** dictate into the message box; the text appears without sending it.
- **Clipboard:** copy something, dictate, and paste again: your text is back. Copy from a password manager,
  dictate: its clear-after-timeout still fires (the dictated text is on the clipboard until then).

## Manual check: the hotkey survives a disabled listener

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
