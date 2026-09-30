# Development

## Tools

- Dev tools: `brew install swiftlint swiftformat periphery gitleaks shellcheck lefthook`
- For end-to-end tests: [BlackHole](https://github.com/ExistentialAudio/BlackHole) (2ch) and the
  `say` voices Milena (ru), Samantha (en), Yuna (ko)

## Commands

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
| `--transcript-dir <dir>` | **test-only**: save each transcript as `<n>.txt` there. Honoured only when the environment has `DICTATE_E2E=1` (`open -n --env DICTATE_E2E=1 ...`); it puts dictated text on disk, so do not use it otherwise |

For example: `open -n build/Dictate.app --args --recording-dir ~/dictate-recordings`.

## Manual checklist (not automated)

- **TextEdit:** type "Hello", dictate: " ..." is added after "Hello"; at the start of an empty document there
  is no leading space; after a newline there is none either.
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
