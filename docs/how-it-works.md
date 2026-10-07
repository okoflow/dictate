# How Dictate works

The details behind the [README](../README.md): how text gets into the app, how recognition behaves, and the known limits.

## Dictionary, snippets and history

- **File:** `~/Library/Application Support/Dictate/dictionary.json` (menu → *Dictionary & snippets…* creates and
  opens it). It is read again when it changes; a file with a JSON error is reported in the event log and the
  last good version stays in use.
- **Terms:** go into Whisper's prompt after the style sentence (up to 200 characters of terms; Whisper reads
  at most 224 tokens), so Whisper often writes them right by itself. Then every `spoken` form, and the term in
  another case, is replaced by the term: whole words, any case, ё = е; a multi-word form must be separated by
  spaces. Korean particles stay attached (쿠버네티스를 → Kubernetes를). Russian endings are not guessed: add
  "кубера" as a separate form if you need it. Forms with other characters between words ("C++", "node.js") cannot
  be matched word by word and are ignored as `spoken` forms (they still work as terms). The replacement runs before
  the mode and again after it, because an LLM may undo it.
- **Snippets:** if the whole dictation is a trigger (case and punctuation aside), the snippet text is delivered as
  it is: no mode, nothing sent to the cloud. A trigger inside a longer text is replaced after the mode.
- **History:** the last 50 delivered texts with time, mode and app, in `history.json` next to the dictionary (file
  mode 600). *Keep history* (on by default) stops adding to it when off; *Clear history* deletes the file. The
  in-memory *Copy last transcript* is separate and unchanged.

## Pasting

How it types: Dictate puts the text on the clipboard and presses ⌘V for you, then puts your previous
clipboard back. The restore is skipped (and the event log says why) if something else was copied in the
meantime, if the clipboard holds a password-manager item (those are cleared by watching the clipboard's
change counter, so Dictate does not touch them, and the pasted text replaces them until they clear), or if it
holds more than 5 MB. Only text, rich text, HTML, images, PDFs and file/URL items are saved and restored;
other private clipboard formats do not survive a paste. Nothing is typed key by key.

- **Password fields:** if the focused element is a secure text field, nothing is typed and the text is not
  put on the clipboard either; the pill says so. Menu → **Copy last transcript** gets it back (it is kept in
  memory only).
- **Focus moved:** if you switched apps or fields while the text was being recognised, it is not pasted into
  the wrong place; it is copied instead and the pill says "Copied — ⌘V to paste".
- **Menu:** *Insert into the focused field* (on by default). Off = the text only goes to the clipboard.
  *Copy last transcript* copies the latest of the last five texts (kept in memory for 10 minutes, never on disk).
- **Several dictations in a row:** they are pasted in the order you spoke them, one at a time. If you are
  holding the hotkey for the next one when a text is ready, the paste waits for you to let go (a ⌘V with
  Option held would be a different shortcut). If you hold it for more than 10 s, the text is copied instead
  ("Copied — ⌘V to paste").

Known limits:

- Needs the Accessibility permission (to press ⌘V and to look at the focused field). Without it the text is
  copied instead.
- The shortcut is pressed on the key that types "v" in your Latin layout, so Dvorak, Colemak and "Dvorak - QWERTY ⌘" work; with
  only a non-Latin layout active it follows the Latin one, as macOS does for shortcuts.
- Apps that expose little to Accessibility (some Electron apps, games, remote desktops) still get the paste,
  but the spacing decision cannot see the text before the cursor, so no leading space is added there.
- Terminal's "Secure Keyboard Entry" and password fields in browsers: see the manual checklist in [development.md](development.md#manual-checklist-not-automated). Dictate
  decides on the *focused element* being a password field, not on the global secure-input flag (it only
  logs that flag).
- The first syllable can be lost if you speak the instant you press the key (see [Push-to-talk](#push-to-talk)).

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
- **Result:** the text is pasted into the focused field (see [Pasting](#pasting)), and the whole text shows on
  the same small pill at the bottom of the screen (wrapped, up to 60 % of the screen wide) for 2 s plus 1 s
  per 15 characters, at most 10 s. With "Insert into the focused field" off it goes to the clipboard instead; paste
  with ⌘V. A recording without speech (silence, key clicks, steady noise: judged on how long the audio
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

## Permissions and code signing

macOS ties these grants to the app's **code signature**. An ad-hoc signature changes on every build,
so the grants would be lost after each rebuild. `make signing` creates a self-signed identity
("Dictate Dev") once and marks it trusted for code signing (macOS asks for your password). After that,
rebuilds keep their permissions.

Check what an app instance holds: `build/Dictate.app/Contents/MacOS/Dictate --print-permissions`
(when run from a terminal this reports the *terminal's* permissions; the E2E suite asks the
LaunchServices-launched app instead).

## Modes

After recognition the text goes through the mode chosen in the menu (or with ⌃⌥M, which cycles Raw → Light →
Clean → Formal → Translate → Raw). The mode is remembered. The mode at the moment you let go of the key is the
one used, so switching while a text is still being recognised does not change it.

- **Raw:** Whisper's text, untouched.
- **Light** (offline rules, the default): removes hesitation sounds as whole words: "э", "ээ", "эм", "мм", "хм",
  "um", "uh", "uhm", "er", "erm", "hmm", "음", "으음", "어", "흠" (stretched or hyphenated forms too, never "мм"
  after a number), with the commas around them; tidies spaces; capitalises the first letter (Russian and
  English) and adds a full stop if the text ends in a letter or a digit. Real filler *words* ("ну", "значит",
  "like", "그러니까") and self-corrections need meaning, so they are left to Clean. Korean word spacing is kept.
- **Clean, Formal, Translate → EN** (☁︎): the text goes to Claude Haiku (`claude-haiku-4-5-20251001`) with a
  short instruction per mode: remove fillers and self-corrections, fix grammar, keep the language (Formal: also a
  business tone; Translate: into English). The transcript is sent as text to edit, with an instruction never
  to follow requests inside it, so dictating a question gives you the question, not an answer.
- **Checks on the answer:** an empty answer, one far longer than what you said, one cut off or refused, or one in
  the wrong script (Clean and Formal must stay Cyrillic, Latin or Hangul as spoken; Translate must be Latin) is not
  pasted.
- **Fallback:** no key, no network, an error from the API, no answer within 3 s, or an answer that fails the
  checks → Light is used instead and the pill adds a line saying why ("Light: offline", "Light: no answer in 3 s",
  ...). The text is never lost.
- **Speed:** Light adds nothing noticeable. The ☁︎ modes add the round trip to the API, usually well under a
  second; the target is at most 2.5 s from letting go to the text for 10 s of speech.
- **API key:** menu → *Set Anthropic API key…* stores it in the login Keychain (service `dev.dictate.app`,
  account `anthropic-api-key`, this device only); *Remove API key* deletes it. It is read for each ☁︎ request and
  never written anywhere else.
- **Event log:** each dictation logs the mode, what really ran, the fallback reason and whether a request was
  sent, never the text.

- **Per-app mode:** menu → *Mode in <app>* sets a mode for the app that was in front when you opened the menu
  (stored by bundle identifier; *Apps with their own mode* lists them, click one to remove it). The app is the
  one in front when you pressed the key; the event log says when its own mode was used.

Known limits:

- The ☁︎ modes know nothing about the app beyond its own mode.
- ⌃⌥M is taken system-wide while Dictate runs; if another app already holds it, the menu says so and only the
  menu switches modes.
