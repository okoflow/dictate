# Dictate

[![check](https://github.com/okoflow/dictate/actions/workflows/check.yml/badge.svg)](https://github.com/okoflow/dictate/actions/workflows/check.yml)

Push-to-talk dictation for macOS. Hold right ⌥, speak, let go, and the text shows up where your cursor is, in any app.

Speech is recognised on your Mac with Whisper. Russian, English and Korean.

## Install

You need an Apple Silicon Mac with macOS 14 or later, and Xcode 26 (Swift 6.2).

```sh
git clone https://github.com/okoflow/dictate
cd dictate
make signing   # once: lets macOS remember the permissions between builds
make bundle
open build/Dictate.app
```

Dictate lives in the menu bar. On first launch it downloads the speech model (about 600 MB) and prepares it, which takes a minute or so. When the menu says **Ready**, you can dictate.

macOS will ask for three permissions:

| Permission | What for |
|---|---|
| Microphone | recording while you hold the key |
| Accessibility | pasting into the field you're in |
| Input Monitoring | noticing the hotkey |

## Use it

1. Click into any text field.
2. Hold **right ⌥** and speak.
3. Let go. The text appears in a second or two.

Give it a beat after pressing the key before you start talking, or the first syllable can get cut off.

The language is picked automatically. To pin one, use the menu: **Language → Russian / English / Korean**.

## Modes

What happens to the text before it is pasted. Pick one in the menu (**Mode**) or press **⌃⌥M** to go to the
next one; the pill shows which.

| Mode | What it does | Leaves your Mac? |
|---|---|---|
| **Raw** | Exactly what Whisper heard | no |
| **Light** (default) | Drops "um", "uh", "ээ", "мм", "음", "어", tidies spaces, capital letter, full stop at the end | no |
| **Clean** ☁︎ | Removes fillers and self-corrections ("Thursday, no, Friday" → "Friday"), fixes grammar. Keeps your language | **yes** |
| **Formal** ☁︎ | Clean, in a polite business tone. Keeps your language | **yes** |
| **Translate → EN** ☁︎ | Translates to English | **yes** |

The ☁︎ modes use Claude Haiku and need your Anthropic API key: menu → **Set Anthropic API key…** (it is kept in
your Keychain). Without a key, offline, or when there is no answer within 3 seconds, Dictate uses Light instead
and the pill says why, so you always get your text.

**A mode per app:** menu → **Mode in Chrome** (the app you were in when you opened the menu) gives that app its
own mode, say Formal in Mail and Raw in the terminal. Other apps follow the Mode menu.

## Dictionary, snippets, history

- **Dictionary:** menu → **Dictionary & snippets…** opens a small JSON file. List the names and terms Whisper
  gets wrong, and how it writes them instead:

  ```json
  {
    "terms": [
      { "term": "Kubernetes", "spoken": ["кубернетис", "кубер"] },
      { "term": "Ivan Petrov" }
    ],
    "snippets": [
      { "trigger": "моя почта", "text": "ivan.petrov@example.com" }
    ]
  }
  ```

  The terms are given to Whisper as a hint, and whatever it still writes from `spoken` (any case, whole words)
  is replaced by the term. This works in every mode, Raw included. Changes apply to the next dictation.
- **Snippets:** say just the trigger ("моя почта") and its text is pasted as it is, in any mode, without going to
  the cloud. A trigger inside a longer dictation is replaced too.
- **History:** menu → **History** shows your last dictations; click one to copy it. Turn it off with **Keep
  history**, delete it with **Clear history**.

A few things it does on its own:

- **Your clipboard is safe.** Dictate pastes through the clipboard, then puts back whatever you had copied.
- **Password fields are skipped.** Nothing is typed there. If you need the text, use **Copy last transcript** in the menu.
- **It won't paste into the wrong place.** If you switched apps while it was working, the text goes to the clipboard instead, so just press ⌘V.

## Privacy

- Recognition runs locally. Apart from the speech model (downloaded once), Dictate talks to the network only in
  the ☁︎ modes.
- Raw and Light never leave your Mac.
- Clean, Formal and Translate send the **recognised text** (never audio) to the Anthropic API, and only when you
  have set a key. See [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy) for how the API
  handles it.
- The API key lives in your Keychain, nowhere else. **Remove API key** in the menu deletes it.
- The history (your last 50 texts) is kept in `~/Library/Application Support/Dictate/history.json`, readable only
  by your user. Switch it off or clear it in the History menu. The dictionary is in the same folder.
- Audio stays in memory while you hold the key and is never saved.
- The dictated text is never written to logs.

To remove the model: `rm -r ~/Library/Application\ Support/Dictate/Models ~/Library/Caches/dev.dictate.app`

## What's next

Hands-free mode (no holding the key), voice commands, editing the selected text, and a release build.

## More

- [How it works](docs/how-it-works.md): modes, dictionary, pasting, recognition, known limits
- [Development](docs/development.md): tests, benchmarks, launch flags
- [MIT License](LICENSE)
