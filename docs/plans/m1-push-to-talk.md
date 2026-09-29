# M1 — push-to-talk and recording: implementation plan

Task: TaskQ #96. Branch: `m1-push-to-talk` (from `m0-scaffold`). Repo: `~/Documents/pets/dictate`.
Overall plan: Obsidian `taskq/93-dictate-итоговый-план.md` (section M1).

## Goal

Hold **right Option** anywhere → Dictate records the microphone; release → recording ends.
A floating pill ("overlay") shows the input level while recording. No transcription yet (M2).

Acceptance (from the task):
- Right Option via CGEventTap; Option+letter still reaches apps; tap re-enabled after
  `tapDisabledByTimeout` / `ByUserInput`.
- AVAudioEngine, captured audio converted to 16 kHz mono; engine starts on key press.
- Presses shorter than 0.3 s ignored.
- Overlay with level.
- `make check` green; `make e2e` green including all M0 checks plus new ones:
  synthetic key press + WAV played into BlackHole → recorded file of the right length, not silence;
  overlay appears and disappears; Option+letter still types a character.
- README updated.

## Already written (spec, keep unless the critique finds a problem)

Written before the pipeline was agreed; treat as the contract, adjust if needed. Uncommitted in the
working tree of `m1-push-to-talk`:

- `Sources/DictateCore/PushToTalk.swift`: `RawKeyEvent`, `KeyboardSignal`, `Hotkey.classify`,
  `PushToTalk` state machine (`idle → holding → finish/discard`, `cancelled` until release,
  `tapDisabled` while holding discards).
- `Sources/DictateCore/AudioLevel.swift`: `rms`, `meterValue` (−50 dBFS…0 → 0…1).
- `Sources/DictateCore/AppEvent.swift`: event log (JSON lines) — `ready`, `hotkeyUnavailable`,
  `recordingStarted`, `recordingFinished(seconds, file?)`, `recordingDiscarded(reason)`,
  `recordingFailed`, `overlayShown/Hidden`, `tapReenabled`.
- `Sources/DictateCore/LaunchOptions.swift`: `--report-file`, `--event-log`, `--recording-dir`,
  `--input-device`.
- Tests: `Tests/DictateCoreTests/PushToTalkTests.swift`, `AudioAndEventTests.swift`.

Not yet built or run.

## Design

### Targets

- `DictateCore` (pure, unit-tested) — as above.
- New target **`AudioDevices`** (CoreAudio): find an input/output `AudioDeviceID` by name; list
  devices. Used by the app (`--input-device`) and by the E2E runner (play into BlackHole).
- `Dictate` app gains:
  - `HotkeyMonitor` — `CGEvent.tapCreate(.cgSessionEventTap, .headInsertEventTap, .listenOnly,
    mask: flagsChanged | keyDown)`. **Listen-only**: never swallows events, so Option+letter
    passes through untouched and only Input Monitoring is needed. Callback maps `CGEvent` →
    `RawKeyEvent` → `Hotkey.classify`. On `.tapDisabled` it calls `CGEvent.tapEnable(tap:, enable: true)`
    and logs `tapReenabled`. If `tapCreate` returns nil (no permission) → log `hotkeyUnavailable`,
    retry every 2 s (the permission poll already exists in `PermissionsModel`).
  - `AudioRecorder` — new `AVAudioEngine` per recording (fresh state, device can change between
    recordings). Optional input device set on `inputNode.audioUnit` via
    `kAudioOutputUnitProperty_CurrentDevice` before `start()`. Tap on input node in its native
    format, `AVAudioConverter` → 16 kHz mono Float32, accumulate in a lock-protected buffer
    (`OSAllocatedUnfairLock`, Swift 6 safe). Publishes meter level (≈20 Hz) to the main actor.
    `stop()` returns the samples.
  - `WAVWriter` — 16-bit PCM 16 kHz mono via `AVAudioFile`. Used only with `--recording-dir`
    (privacy: by default audio never touches disk; M2 will consume the samples in memory).
  - `RecordingOverlay` — borderless, non-activating `NSPanel` (`.nonactivatingPanel`,
    `level = .statusBar`, `ignoresMouseEvents`, joins all spaces), bottom-centre of the screen with
    the mouse, SwiftUI level bars. Accessibility identifier `dictate.overlay`. Never takes focus.
  - `DictationController` (`@MainActor`) — owns monitor, `PushToTalk`, recorder, overlay, event log.
    `startRecording` → start engine, show overlay; `finish` → stop, write WAV if asked, hide overlay;
    `discard` → stop, drop samples, hide overlay. Engine start failure → `recordingFailed`, hide overlay.
  - `EventLogWriter` — append-only file handle; no-op without `--event-log`.
  - Menu shows hotkey status ("Hold right ⌥ to dictate" / "Hotkey unavailable: grant Input Monitoring").

### E2E (new checks, all in `E2ERunner`)

Dictate is launched with `--event-log <tmp> --recording-dir <tmp> --input-device "BlackHole 2ch"`.

1. `hotkey-ready` — event log contains `ready` within 5 s.
2. `record-fixture-through-blackhole` — post right-Option down (synthetic `flagsChanged`,
   keycode 61, flags `optionFlag | rightOptionDeviceFlag`, posted at `.cghidEventTap`), play
   `fixtures/generated/en-plain-2.wav` into BlackHole (AVAudioEngine with output device = BlackHole),
   wait for playback end + 0.2 s, post release. Expect `recordingStarted`, then
   `recordingFinished(seconds≈hold, file)`; file is 16 kHz mono, duration within ±0.5 s of the hold
   time, RMS above 0.01 (fixture level is far above that).
3. `silence-control` — same hold, nothing played → file RMS below 0.001. Proves check 2 measures
   the fixture, not noise.
4. `short-press-discarded` — 0.1 s press → `recordingDiscarded(tooShort)`, no new file.
5. `overlay-shown-and-hidden` — during a hold, Dictate's AX tree has a window with identifier
   `dictate.overlay`; 1 s after release it is gone. Also `overlayShown`/`overlayHidden` in the log.
6. `option-letter-passes-through` — TestPad frontmost; right-Option down, key `a` down/up with
   option flags, right-Option up. Expect TestPad text non-empty (the layout decides the exact
   character) and `recordingDiscarded(otherKeyPressed)` in the log.
7. `blackhole-available` — BLOCKED (not FAIL) if no device named "BlackHole 2ch".

All M0 checks stay. Every check that needs a permission reports BLOCKED, not FAIL, when it is missing.

### Unit coverage

Core stays ≥ 70% (currently 100%): new core types are fully unit-tested above.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Synthetic events not seen by the tap (secure keyboard entry on in the terminal) | detect via `IsSecureEventInputEnabled()`; BLOCKED with a hint |
| Engine start latency cuts the start of audio | e2e hold covers playback + margin; length tolerance ±0.5 s |
| BlackHole at 48 kHz stereo | converter handles any input format; checks assert output format |
| Overlay steals focus from TestPad | non-activating panel; check 6 runs with TestPad frontmost and asserts it stays frontmost |
| Posting events requires Accessibility for the runner | already granted to the terminal; BLOCKED otherwise |
| Another Dictate instance holds the tap | launcher terminates existing instances first (already) |
| Swift 6 strictness around audio thread callbacks | lock-protected buffer, `Sendable` value types, main-actor hops for UI |

## Definition of done

`make check` green, `make e2e` green (M0 + M1 checks, run 5× without a failure), README updated
(hotkey, overlay, new flags), small focused commits on `m1-push-to-talk`, nothing pushed.

---

## Revision after critique (binding; overrides the sections above where they conflict)

Critique by an independent Opus review, all points accepted unless noted.

### Audio (Swift 6 safety first)

1. **Spike first:** before anything else, get a 1 s recording working in a debug build.
   - The tap block is built in a `nonisolated` function and is explicitly `@Sendable`.
   - It captures only a `final class AudioSink: @unchecked Sendable`, which holds the converter and an `OSAllocatedUnfairLock`-protected buffer. A main-actor-isolated closure traps on the audio thread.
2. **Format guard:** after setting the device, read `inputNode.inputFormat(forBus: 0)`. If `channelCount == 0 || sampleRate == 0`, log `recordingFailed` and do not call `installTap` (it throws an ObjC exception).
3. **Converter:**
   - use `convert(to:error:withInputFrom:)`;
   - the input block gives its buffer once, then returns `.noDataNow`, never `.endOfStream`;
   - set `downmix = true`;
   - output capacity = `ceil(frames * 16000 / inRate) + 32`.
4. **Recorder threading:** the recorder runs on its own serial queue (or actor) with a per-recording generation token, so a 0.1 s press cannot stop before start finishes. `recordingStarted` is logged when the **first buffer** arrives. `engine.start()` never runs on the main thread.
5. **Device change mid-recording:** observe `AVAudioEngineConfigurationChange` and emit `recordingFailed`.
6. **WAV:**
   - write Float32 source samples as 16-bit PCM WAV to `<name>.tmp`;
   - close the file (drop the `AVAudioFile` reference / `close()`), then rename;
   - only then log `recordingFinished`.

### State machine (core; update draft + unit tests)

7. `DiscardReason.interrupted` for a disabled tap or a lost key-up (not `otherKeyPressed`).
8. `.cancelled` escapes:
   - `hotkeyDown` → start a new press;
   - `tapDisabled` → `.idle`.
9. **Watchdog** in the app, while holding:
   - poll `CGEventSource.flagsState(.combinedSessionState)` every 250 ms; if bit `0x40` is gone, feed a `hotkeyUp`;
   - max recording length 5 minutes → finish.
10. **Time** comes from `CGEvent.timestamp` (mach time → seconds), not the wall clock.
11. Unit tests for:
    - the new transitions;
    - right Option pressed while left Option is held (flags `alt|0x20|0x40`);
    - the Codable round-trip of `.interrupted`.

### Events

12. `recordingStarted(device: String)` and `recordingFinished(seconds, samples, file?)`, so e2e can assert the audio came from BlackHole and that `samples/16000 ≈ seconds`.

### Hotkey tap

13. **Gate on permission:** gate `tapCreate` on `CGPreflightListenEventAccess()` and request it once. Log `tapReenabled` when re-enabling.
14. **Coverage of tap re-enable:** unit tests only. It cannot be forced in e2e; README gets a manual check step for it.

### Overlay

15. **Panel setup:**
    - `NSPanel` subclass with `canBecomeKey = false` and `canBecomeMain = false`, `hidesOnDeactivate = false`;
    - shown via `orderFrontRegardless()`;
    - collection behaviour `canJoinAllSpaces | fullScreenAuxiliary | stationary`;
    - accessibility identifier set on the panel itself.
16. **Shown only after 0.3 s of holding.** A right-Option-as-AltGr combo then does not flash it; the mic indicator can still blink briefly (note in README).

### E2E

17. **Per-check baseline:** snapshot the event count and the recording-dir listing before each action; assert only on new events and files.
18. **Synthetic events:**
    - `CGEventSource(stateID: .privateState)`;
    - explicit `type = .flagsChanged` and keycode (61 right, 58 left);
    - flags `maskAlternate | 0x40` on down and on keys while held, cleared on release;
    - releases posted in `defer`, so a failed check never leaves Option stuck.
19. **`record-fixture-through-blackhole`:**
    - press, wait for the new `recordingStarted(device == BlackHole)`, then play `en-plain-2.wav`, then release;
    - report press→`recordingStarted` latency in the report, fail above 600 ms (critic proposed 400; engine start varies, 600 is less flaky);
    - assert the recording's non-silent span (20 ms windows above −40 dBFS) lasts as long as the fixture's non-silent span, within ±0.25 s — this also proves the real sample rate;
    - assert `samples/16000 ≈ seconds` (±0.3 s).
20. **`silence-control`:** hold ~1.5 s with nothing played → RMS < 0.001. If it is not silent → BLOCKED "something else routes audio into BlackHole".
21. **`left-option-ignored`:** hold left Option (keycode 58, flags `alt|0x20`) for 1 s → no new `recordingStarted`.
22. **`option-letter-passes-through`:**
    - assert TestPad is frontmost;
    - clear its text via AX;
    - switch the input source to `com.apple.keylayout.ABC` via TIS and restore the previous one in `defer`;
    - right-Option down, `a` down/up with flags, release;
    - expect the text to be exactly "å" and a new `recordingDiscarded(otherKeyPressed)`;
    - if `IsSecureEventInputEnabled()` → BLOCKED.
23. **`overlay-shown-and-hidden`:**
    - during a hold of ≥0.8 s, check the AX window `dictate.overlay` **and** `CGWindowListCopyWindowInfo` for Dictate's pid with `kCGWindowIsOnscreen` and alpha > 0;
    - ≤1 s after release, both are gone.
24. **`short-press-discarded`:** 0.1 s press → new `recordingDiscarded(tooShort)`, no new file, no overlay window.
25. **BlackHole:**
    - find it by UID `BlackHole2ch_UID` (fall back to the name);
    - BLOCKED if missing.
    - Playback uses `AudioQueue` with `kAudioQueueProperty_CurrentDevice` (simpler than AVAudioEngine), waiting for completion with a semaphore.
26. Don't touch the keyboard during `make e2e` (the README says so).

### Periphery / hygiene

27. `Entry` uses `LaunchOptions` (no second `argumentValue` parsing of the same flags). Every new core API is used by the app or removed.
