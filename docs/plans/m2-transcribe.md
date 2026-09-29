# M2 — speech recognition (ru / en / ko): implementation plan

Task: TaskQ #97. Branch `m2-transcribe` from `m1-push-to-talk`. Repo `~/Documents/pets/dictate`.

## Goal

After a push-to-talk recording, Dictate turns the audio into text locally with WhisperKit, picking
the language among ru / en / ko. Until M3 adds auto-insertion, the text is **copied to the clipboard**
and shown briefly on the overlay, so the user can already dictate with ⌘V.

## Part 0 — trim the E2E suite first (user request: e2e takes too long)

Rules from now on: `make e2e` is a **smoke suite run once** (retry once only on failure); edge cases
live in unit tests; `make e2e-full` keeps every check for MVP hand-off or on request; accuracy is
measured by `make bench`, not by e2e. No repeated stability loops.

- `make e2e` (smoke), in this order:
  1. `app-ready` — merges: signature stable, launches as menu bar app, all permissions granted,
     hotkey ready, BlackHole available (one check, first failing reason reported; BLOCKED rules kept).
  2. `record-fixture-through-blackhole` (M1 main path, as today).
  3. `option-letter-passes-through` (as today).
  4. `dictate-fixture-to-clipboard` (new, M2 main path) — see below.
- `make e2e-full` = smoke + fixtures-valid, testpad-launches, testpad-accessibility-roundtrip,
  silence-control, left-option-ignored, short-press-discarded, overlay-shown-and-hidden.
- The runner takes `--suite smoke|full`; the Makefile passes it. Report lists which suite ran.

## Part 1 — spike (log the findings to the task)

Add WhisperKit (MIT, `https://github.com/argmaxinc/WhisperKit`, pin an exact recent version) as a
SwiftPM dependency and confirm, with a throwaway executable or test:
- it builds under Swift 6 language mode with only Command Line Tools, warnings-as-errors for our
  targets (dependency warnings don't count);
- model name for large-v3 turbo in `argmaxinc/whisperkit-coreml`, download size, where it downloads
  (set `downloadBase` to `~/Library/Application Support/Dictate/Models`, never `~/Documents`);
- `detectLanguage(audioArray:)` returns per-language probabilities → pick max over {ru, en, ko};
  then `transcribe` with `DecodingOptions(language:, detectLanguage: false)`; cost of the extra pass;
- first-load (Core ML compile) time and warm transcription time for ~5 s and ~10 s audio.
If large-v3 turbo is too slow on this Mac (warm 10 s audio > 2 s), report and propose a smaller model.

## Part 2 — design

- New target **`Transcription`** (depends on WhisperKit + DictateCore): `actor Transcriber` —
  `load(progress:)`, `transcribe(samples: [Float], language: Language?) -> Transcript` where
  `Transcript { text, language, languageProbability, seconds }`. Audio longer than 30 s is split on
  the quietest point near each 25–30 s boundary (pure splitting logic in core, unit-tested) and the
  pieces are joined with a space.
- **Core (pure, unit-tested):** `Language` enum {ru, en, ko} + `pick(from probabilities:)` restricted
  to the three; `TextMetrics.cer(reference:hypothesis:language:)` with normalisation (case, punctuation,
  whitespace; Korean compares without spaces); chunk-boundary finder; `LanguagePreference` (auto or
  fixed) persisted via `UserDefaults` in the app.
- **App:**
  - The model loads at launch in the background; menu shows "Downloading model… 42%" /
    "Loading model…" / "Ready". Push-to-talk works only when ready; before that a press shows
    "Model not ready" on the overlay (no recording kept).
  - After `recordingFinished`, samples → `Transcriber` → text. Overlay switches to a spinner while
    transcribing, then shows the first ~60 characters for 1.5 s. Text goes to the clipboard.
    Empty/silence result → nothing copied, overlay shows "Didn't catch that".
  - Menu: language submenu — Auto (ru / en / ko), Russian, English, Korean.
  - Events (no dictated text, privacy): `modelReady(name, loadSeconds)`,
    `transcribed(language, characters, seconds)`, `transcriptionFailed(reason)`.
  - Debug flag `--transcript-dir <dir>`: write each transcript to `<n>.txt` (like `--recording-dir`),
    used by e2e only.
- **`make bench`** — new executable `Bench` (depends on Transcription): runs every fixture in
  `fixtures/generated` (say) and `fixtures/private` (FLEURS, if present) through the Transcriber
  with auto language; prints and saves `bench/reports/<date>.md`: per language CER, language-id
  accuracy, warm latency per clip and per 10 s of audio, model load time. Gates (exit 1 if missed):
  CER ≤ 10 % ru/en and ≤ 15 % ko on clean `plain` fixtures; language id ≥ 95 % over all clips.
  FLEURS and noisy numbers are reported, not gated.

## E2E (smoke) — new check

`dictate-fixture-to-clipboard`: Dictate launched with `--input-device "BlackHole 2ch"
--transcript-dir <tmp>`; wait for `modelReady` (first run may download: allow 15 min, print
progress; later runs seconds); save the clipboard; hold right Option, play `ru-plain-2.wav`,
release; expect `transcribed(language: ru)`, clipboard text CER ≤ 15 % vs the manifest text, and the
transcript file matches the clipboard; restore the previous clipboard.

## Definition of done

`make check` green (unit tests don't need the model), `make e2e` (smoke) green once,
`make bench` passes gates and its report is attached, README updated (model download, languages,
clipboard behaviour, privacy: audio and text stay on the Mac), small commits, nothing pushed.

---

## Revision after critique (binding; overrides the sections above where they conflict)

1. **Package:** WhisperKit is now `argmaxinc/argmax-oss-swift` (v1.x). Pin an exact 1.x tag and depend only on the `WhisperKit` product. The spike confirms, before any design work:
   - the current `detectLanguage` signature;
   - `DecodingOptions` fields (language, `chunkingStrategy`, `noSpeechThreshold`);
   - that it builds with CLT only.

   If it cannot build without Xcode, stop and report.
2. **Strictness on our targets only:** drop `-Xswiftc -warnings-as-errors` from the Makefile. Instead, our own targets get `swiftSettings` that treat warnings as errors: `.treatAllWarnings(as: .error)` with tools-version 6.2, or `unsafeFlags(["-warnings-as-errors"])` on root targets. Dependencies must not be affected.
3. **Model:**
   - bench `openai_whisper-large-v3-v20240930` (~1.6 GB) against `openai_whisper-large-v3-v20240930_626MB`;
   - default to the 626 MB variant if it passes the CER gates, otherwise the full one;
   - the model name is a flag/setting (`--model`).
4. **Swift 6:** use `@preconcurrency import WhisperKit` (or the equivalent) in the `Transcription` target, so its non-Sendable types stay confined to the `Transcriber` actor.
5. **Chunking:** use `DecodingOptions.chunkingStrategy = .vad` for audio over 30 s. Drop the custom splitter unless the spike shows `.vad` is bad.
6. **CER:**
   - the manifest gets optional `"alternatives": [..]` per fixture (e.g. digit forms "3 часа", "3 o'clock", "3시", "2층"); CER = min over the reference and its alternatives;
   - normalisation: Unicode NFC, locale-aware lowercasing, ё→е, strip punctuation by Unicode category, collapse whitespace; Korean is compared without spaces;
   - all of it unit-tested.
7. **Language-id gate:** a fixed set, i.e. all generated `say` clips (plain + filler + noisy + the new long ones), plus FLEURS only when all 15 are present. The gate is "at most 1 miss out of N" and the report states N.
8. **Latency:**
   - add one ~10 s `say` fixture per language (`*-long-1`, tag `long`, with text and alternatives) and measure only on those;
   - report the detect pass and the transcribe pass separately;
   - goal: transcription of 10 s ≤ 1 s warm, reported and not gated. The gate is ≤ 3 s so a slow Mac doesn't block the stage.
9. **Silence / hallucination:**
   - before transcribing, run an energy check (reuse `AudioLevel.speechSpan`: no loud window, or span < 0.3 s → "Didn't catch that", no transcription);
   - also set `noSpeechThreshold`;
   - the decision is a pure core function, unit-tested.
10. **Model download:**
    - a new `make model` downloads the model with progress into `~/Library/Application Support/Dictate/Models`;
    - `make e2e` and `make bench` never download; if the model is missing they exit 2 (BLOCKED "run make model");
    - the e2e allows only the Core ML compile / warm-up time (≤ 3 min on the first load, then seconds);
    - the app downloads on first launch with progress in the menu.
11. **States and races:** a pure core state machine `ModelState` covering `notDownloaded → downloading(progress) → loading → ready | failed(reason)`, with retry from the menu and removal of partial downloads, unit-tested. While a transcription runs, recording still works: transcripts go through a FIFO queue in the actor, and the overlay prioritises the recording state. A press before the model is ready → overlay "Model not ready", recording discarded (event `recordingDiscarded(.modelNotReady)`).
12. **Privacy:**
    - the pasteboard item is also marked `org.nspasteboard.TransientType` and `org.nspasteboard.ConcealedType` (clipboard managers skip it, and ⌘V works);
    - WhisperKit `verbose: false`, logging off;
    - `--transcript-dir` works only together with `--event-log` (e2e) and is documented as test-only;
    - bench reports contain metrics and fixture ids only, never transcript text, and `bench/reports/` is git-ignored.
13. **Detect pass:** run `detectLanguage` only in Auto mode; a pinned language skips it.
14. **`make check` hygiene:**
    - unit tests never construct WhisperKit (a grep guard in `make check`);
    - coverage stays scoped to DictateCore;
    - Periphery must not flag API used only by `Bench` (fine, since Bench is a target).
15. **README:** model name, size, location, how to delete it, RAM while resident, languages, clipboard behaviour, privacy.


---

## Spike findings (measured on this Mac: Apple M5, macOS 26.5, Command Line Tools only, Swift 6.3.2)

**Package.** `argmaxinc/argmax-oss-swift` tags run `v0.14.0 … v1.0.0, v1.1.0`; pinned to exactly `1.1.0`, product
`WhisperKit` only (its own tools-version is 5.10, macOS 13+). It resolves and builds with Command Line Tools alone
(about 30 s for a release build of the product); no Xcode needed. Our targets stay in Swift 6 language mode with
`-warnings-as-errors`; the dependency keeps its own settings. Two Swift 6 frictions: `WhisperKit` and its results
are not `Sendable` (`@preconcurrency import`, all use confined to `actor Transcriber`), and a top-level `var`
cannot be mutated from the download progress closure (`@Sendable`).

**API as it really is in 1.1.0.**
- `WhisperKit.download(variant:downloadBase:useBackgroundSession:from:token:endpoint:progressCallback:) async throws -> URL`
  (static; `progressCallback: @Sendable (Progress) -> Void`).
- `WhisperKit(WhisperKitConfig(model:downloadBase:modelFolder:tokenizerFolder:verbose:logLevel:prewarm:load:download:))`.
  With `modelFolder` set and `download: false` nothing is fetched except the tokenizer.
- **The language detector is misspelled: `detectLangauge(audioArray:)`** (only the `audioPath:` variant is spelled
  `detectLanguage`). It returns `(language: String, langProbs: [String: Float])`, but `langProbs` holds **only the
  winner** with its log-probability (`en = -0.00`), not one entry per language. The plan's "pick the max over
  {ru, en, ko}" therefore cannot be done on the result; if Whisper ranks Ukrainian above Russian it is lost.
  The decoder builds its language filter from `tokenizer.allLanguageTokens`, so `Transcriber` wraps the tokenizer
  (`RestrictedTokenizer`) to expose only `<|ru|>`, `<|en|>`, `<|ko|>`: the detector then answers with the most
  probable of those three (probability among the three, about 1.00 on every fixture). `Language.pick(from:)`
  stays as the pure decision over whatever the detector returns.
- `DecodingOptions(verbose:task:language:usePrefillPrompt:detectLanguage:skipSpecialTokens:noSpeechThreshold:chunkingStrategy:…)`;
  `noSpeechThreshold` defaults to 0.6, `chunkingStrategy: ChunkingStrategy?` is `.vad` or `.none`.
- `transcribe(audioArray:decodeOptions:) async throws -> [TranscriptionResult]` (`text`, `segments`, `language`, `timings`).
- The tokenizer is fetched on first load from `openai/whisper-large-v3` into `tokenizerFolder ?? downloadBase`, and
  **defaults to `~/Documents/huggingface`** when neither is set (the spike created it there; it was removed).
  `Transcriber` passes `tokenizerFolder` explicitly, so nothing goes under Documents.

**Models** (`argmaxinc/whisperkit-coreml`): large-v3 variants are `openai_whisper-large-v3`, `…-v20240930`
(1.5 GB on disk), `…-v20240930_626MB` (606 MB), `…-v20240930_turbo(_632MB)`, `distil-whisper_distil-large-v3(_turbo)(_594MB|_600MB)`.
Downloaded to `<downloadBase>/models/argmaxinc/whisperkit-coreml/<variant>` (we use
`~/Library/Application Support/Dictate/Models`); a half-finished download leaves `*.incomplete` files under
`.cache/huggingface/download`. Download took 78 s for 626 MB and 242 s for 1.5 GB on this connection.

**Timings** (release build, 16 kHz clips; warm = second call):

| | 626 MB | 1.5 GB |
|---|---|---|
| first load (Core ML compile) | 51 s | 13.5 s |
| load with the compile cache warm | 1.3 s (in the app) | seconds |
| detect pass, any length up to 30 s | 0.59-0.61 s | 0.58-0.60 s |
| transcribe 3 s / 4.6 s / 7.9 s / 11.8 s audio | 0.76 / 0.82 / 0.82 / 1.05 s | 0.76 / - / - / 1.00 s |

The detect pass costs as much as the whole decode of a short phrase (it pads to the 30 s window and runs the
encoder, which `transcribe` then runs again; the two cannot share the result through the public API), so auto mode
takes about 1.4-1.8 s for a 3-10 s phrase and a pinned language about 0.8-1.2 s. Transcribing ~10 s takes 1.0-1.2 s,
just over the 1 s goal and well inside the 3 s gate: no need for a smaller model. The compile cache is kept per
executable (`~/Library/Caches/<executable or bundle id>`), so each new binary (the app, `Bench`, `FetchModel`)
pays the first-load cost once.

**Long audio.** `chunkingStrategy: .vad` on concatenated FLEURS clips of 33-41 s: ru 7.0 % CER in 4.0 s, en 1.1 % in
2.5 s, ko 4.9 % in 3.1 s (auto language). The custom splitter from the first plan is not needed.

**Decision.** Default model: the 626 MB variant (see `make bench` results in the final report): it passes every gate
and matches the full model within noise on the fixtures.


---

## Corrections after review

- **No-speech protection (replaces revision 9's `noSpeechThreshold`).** WhisperKit sets its no-speech probability
  to a constant 0, so `noSpeechThreshold` does nothing. `SpeechGate` now measures the *total time* the audio is
  louder than its own noise floor (10th-percentile window level + 12 dB, never below -60 dBFS), counting only runs of
  at least 60 ms, and needs 0.3 s. Clicks and steady noise no longer pass just by being spread over the clip. After
  decoding, `TranscriptFilter` drops results with an average log-probability below -1.0, a compression ratio above
  2.4, or that are entirely a known stock phrase.
- **Model completeness (revision 10).** A download is trusted only with a `.dictate-complete` marker (written after
  the model and the tokenizer are on disk) and no `.incomplete` file in that variant's Hugging Face cache folder.
  Retry after a failed download resumes; retry after a failed load deletes the model and downloads it again.
- **Universal Clipboard.** The clipboard item is written with `currentHostOnly`.
- **`--transcript-dir`** needs `DICTATE_E2E=1` in the environment (revision 12 said `--event-log`).
