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

A few things it does on its own:

- **Your clipboard is safe.** Dictate pastes through the clipboard, then puts back whatever you had copied.
- **Password fields are skipped.** Nothing is typed there. If you need the text, use **Copy last transcript** in the menu.
- **It won't paste into the wrong place.** If you switched apps while it was working, the text goes to the clipboard instead, so just press ⌘V.

## Privacy

- Everything runs locally. The only thing Dictate downloads is the speech model, once.
- Audio stays in memory while you hold the key and is never saved.
- The dictated text is never written to logs.

To remove the model: `rm -r ~/Library/Application\ Support/Dictate/Models ~/Library/Caches/dev.dictate.app`

## What's next

Right now Dictate types exactly what Whisper hears. Next up are modes that tidy the text: dropping "um"s offline, and optional LLM clean-up, formal tone and translation to English.

## More

- [How it works](docs/how-it-works.md): pasting, recognition, known limits
- [Development](docs/development.md): tests, benchmarks, launch flags
- [MIT License](LICENSE)
