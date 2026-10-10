<p align="center">
  <img src="Packaging/Dictate.png" width="128" alt="">
</p>

<h1 align="center">Dictate</h1>

<p align="center">Push-to-talk dictation for macOS with on-device Whisper.</p>

<p align="center"><a href="https://dictate.okoflow.com">dictate.okoflow.com</a></p>

<p align="center">
  <a href="https://github.com/okoflow/dictate/actions/workflows/ci.yml"><img src="https://github.com/okoflow/dictate/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-informational" alt="macOS 14 or later">
</p>

Hold the right Option key, speak, and let go: the text appears wherever you
are typing, in any app. Whisper turns your voice into text on your Mac, so the
audio never leaves it. When you want polished prose rather than a transcript,
an AI mode rewrites the text with Claude, OpenAI, Apple Intelligence, or a
model on your own Mac.

![Dictating into a note](.github/screenshots/preview.jpg)

## What it does

- **Types into any app.** The text is pasted into the focused field, and your
  clipboard is put back afterward. Password fields are left alone.
- **Recognizes speech on your Mac.** Whisper large-v3 turbo runs on Core ML
  through WhisperKit. Audio stays in memory and is never saved.
- **Understands 45 languages.** Arabic, Azerbaijani, Bosnian, Bulgarian,
  Catalan, Chinese, Croatian, Czech, Danish, Dutch, English, Estonian,
  Filipino, Finnish, French, Galician, German, Greek, Hebrew, Hindi,
  Hungarian, Indonesian, Italian, Japanese, Korean, Latvian, Lithuanian,
  Macedonian, Malay, Norwegian, Polish, Portuguese, Romanian, Russian,
  Serbian, Slovak, Slovenian, Spanish, Swedish, Tamil, Thai, Turkish,
  Ukrainian, Urdu, and Vietnamese. Dictate detects which one you speak among
  those you choose.
- **Cleans up as much as you like.** Light removes hesitations such as "um",
  capitalizes the first letter, adds a full stop, and starts a new line or
  paragraph when you say so, offline. Clean, Formal, and Translate rewrite the
  text with Claude or OpenAI using your key, with Apple Intelligence, or with a
  local model through Ollama, LM Studio and similar servers. Translate works
  into any of the 45 languages, or both ways between two. Any app can have a
  mode of its own.
- **Edits by voice.** Select text, hold the editing key, and say what to
  change: "make it shorter", "turn this into a list", "translate into German".
- **Transcribes files.** Drop a recording or a video on Transcribe File… and
  get the text or SRT subtitles, recognized on your Mac.
- **Learns your words.** The dictionary fixes names and terms that come out
  wrong, and snippets turn a spoken phrase into text such as your email
  address.
- **Remembers when you want it to.** Your dictations stay on your Mac for as
  long as you choose, searchable and one click away from the clipboard.

![The HUD while listening, transcribing, and after pasting](.github/screenshots/hud.jpg)

## Install

Dictate is built from source. You need a Mac with Apple silicon, macOS 14 or
later, and the Command Line Tools for Xcode 26 or later; a full Xcode works
too.

```sh
git clone https://github.com/okoflow/dictate.git
cd dictate
make signing
make run
```

`make signing` runs once: it creates a local code-signing identity, so macOS
keeps the permissions you grant across rebuilds, and asks for your password
to trust it. `make run` builds `build/Dictate.app`, signs it, and opens it.
Copy the app to `/Applications` to keep it.

On first launch, a short guide asks for the microphone and Accessibility
permissions while Dictate downloads the speech model, about 630 MB. Loading
the model for the first time compiles it for your chip and takes about a
minute; after that it takes a second.

## Use it

1. Click into a text field in any app.
2. Hold **right Option** and speak.
3. Let go. The text appears a moment later.

| Keys | What they do |
| --- | --- |
| Hold right ⌥ | Dictate into the focused field while held |
| Double-tap right ⌥ | Dictate hands-free until you press it again |
| Hold the editing key | Change the selected text by voice, once you choose a key |
| ⌃⌥M | Switch to the next mode |

Dictate lives in the menu bar. Its menu switches the mode and the language,
copies the last transcript, transcribes files, and opens Settings, where you
can choose any modifier, fn, or F-key as the dictation key, pick a
microphone, and choose the languages Dictate listens for.

## Modes

| Mode | What happens to the text | Leaves your Mac |
| --- | --- | --- |
| Raw | Nothing: exactly what Whisper heard | No |
| Light | Hesitations go, the first letter is capitalized, a full stop is added | No |
| Clean | Fillers and false starts go, grammar is fixed, the language stays | Text only, unless the model runs on your Mac |
| Formal | Like Clean, in a polite business tone | Text only, unless the model runs on your Mac |
| Translate | Translated into the language you choose, or both ways between two | Text only, unless the model runs on your Mac |

Light is the default. Clean, Formal, and Translate need an AI model, which
you choose in Settings › AI Models: Claude or OpenAI with an API key from
[Anthropic](https://console.anthropic.com/settings/keys) or
[OpenAI](https://platform.openai.com/settings/organization/api-keys) that
stays in your Keychain, Apple Intelligence on Macs that have it, or a model
on a local server such as Ollama or LM Studio. When the model can't answer in
time or at all, Dictate uses Light and says why, so you always get your text.

![Settings with the modes and per-app modes](.github/screenshots/modes.jpg)

## Privacy

Speech recognition, Raw, Light, and file transcription run entirely on your
Mac. Dictate uses the network for two things only: downloading the speech
model once, and the AI modes and editing by voice with Claude or OpenAI, which
send text, never audio, to the provider you choose. With Apple Intelligence
or a local model, that text stays on your Mac too.
Dictated text never reaches the logs. [Privacy](docs/privacy.md) lists every
file Dictate keeps and how to remove it.

## Dictate Pro

Dictation, Raw and Light, voice commands, the dictionary, and history are
free. Dictate Pro adds the AI modes with any model, translation both ways,
your own instructions, editing by voice, and file transcription, for a single
payment of $13.99. Every Pro feature works for 3 days from the first launch.

## Documentation

- [Usage](docs/usage.md): modes, languages, the dictionary, snippets, history,
  and settings.
- [How it works](docs/how-it-works.md): what happens between the key press and
  the pasted text.
- [Privacy](docs/privacy.md): what stays on your Mac and what leaves it.
- [Troubleshooting](docs/troubleshooting.md): permissions, the dictation key,
  the speech model, and logs.
- [Architecture](docs/architecture.md): the modules, their interfaces, and how
  they fit together.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the development setup, the checks
that run in CI, and the commit and pull request conventions.

## Security

Report vulnerabilities privately through
[GitHub security advisories](https://github.com/okoflow/dictate/security/advisories/new).
[SECURITY.md](SECURITY.md) describes the process and the scope.

## License

Copyright The Dictate Authors, listed in [AUTHORS](AUTHORS).

MIT. See [LICENSE](LICENSE).
