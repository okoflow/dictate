# M5 — dictionary, snippets, history, a mode per app

Task: TaskQ #101. Branch `m5-vocab` from `m4-modes`.

## Design

- **Core (`DictateCore`, unit-tested):**
  - `Vocabulary` (`dictionary.json`): terms with spoken forms, snippets. `correcting(_:)` replaces spoken forms and
    other-case spellings by the term (whole words, phrases separated by spaces, Korean particles kept);
    `wholeSnippet(for:)`; `expandingSnippets(in:)`. Matching on `TextPiece` (shared with `LightRules`).
  - `WhisperPrompt`: the style sentence plus the terms (≤ 200 characters), for Whisper's prompt tokens.
  - `DictationHistory`: the last 50 entries (date, text, mode, app).
  - `AppModes`: bundle identifier → mode; from `UserDefaults` and from `--app-mode`.
- **Transcriber:** prompt tokens per call from `WhisperPrompt` (newest 200 tokens).
- **Pipeline:** dictionary → whole snippet (delivered as is, no mode, no cloud) or mode → dictionary again →
  snippets inside the text; the delivered text goes into the history.
- **App:** `VocabularyStore` (reloads on change; menu *Dictionary & snippets…* opens the file), `HistoryStore`
  (`history.json`, mode 600; *Keep history*, *Clear history*, last 10 in the menu), `AppModeSettings` (the app in
  front, *Mode in <app>*). The target app's own mode wins over the menu's (event `appModeUsed`).
- **Launch options:** `--dictionary`, `--history-file`, `--app-mode` (the suite isolates itself from your files).

## E2E

`dictionary-and-snippets` (term recognised or corrected, snippet expanded, history written) and
`app-mode-in-chrome` (Chrome's own mode used), plus the M1–M4 regression.

## Deviations (as built)

- Fixtures `ru-vocab-1`, `en-vocab-1`, `ru-snippet-1`; the snippet clip has pauses around it (a `say` field with
  `[[slnc 600]]`), because a clip that is all speech has no noise floor for the speech gate and a real press
  always has some silence.
- No settings window: the dictionary is a JSON file opened in your editor.
- Whisper wrote both terms right by itself once they were in the prompt, so the e2e run shows "recognised"; the
  replacement path is covered by unit tests.
