# Usage

How to dictate, and everything you can set up. What happens behind the scenes
is in [How it works](how-it-works.md).

## First launch

A short guide walks you through the setup: the gesture, the microphone and
Accessibility permissions, a field to try dictating into, and whether
Dictate opens at login. The speech model downloads in the meantime, and the
guide's footer shows its progress.

![The first-run guide](../.github/screenshots/onboarding.jpg)

Accessibility lets Dictate notice the dictation key and paste the text. On
macOS 27, System Settings lists it under Privacy & Security › Device Control
and Data Access. If you close the guide early, **Finish Setup…** in the menu
brings it back.

## Dictating

Hold the dictation key, speak, and let go. While you speak, the HUD at the
bottom of the screen shows a level meter; once the text is pasted, it shows
the text.

- Start speaking a beat after you press the key: the microphone takes a
  moment to start.
- A press shorter than 0.3 seconds is ignored, so a tap does nothing.
- Pressing another key while you hold the dictation key cancels the
  recording, so Option shortcuts and special characters keep working.
- A recording stops on its own after 5 minutes.
- You can dictate again while the previous text is still being recognized.
  Texts arrive in the order you spoke them.

The dictation key is right Option by default. To change it, click the key in
Settings › Dictation and press another: Option, Command, Shift, or Control on
either side, fn (🌐), or an F-key. Keys that type text can't be used.

## The menu

![The menu bar menu](../.github/screenshots/menu.jpg)

| Item | What it does |
| --- | --- |
| Mode | Sets the mode for every app; ⌃⌥M switches to the next one |
| Mode in *app* | Gives the app in front a mode of its own |
| Language | Detects the language automatically, or pins one |
| Copy Last Transcript | Copies the latest text again for 10 minutes, even one that was not pasted |
| Recent | Copies one of your last five dictations |
| Settings… | Opens Settings |

To hide the icon, turn off **Show in menu bar** in Settings › General.
Dictation keeps working, ⌃⌥M still switches the mode, and opening Dictate
again brings up Settings.

## Modes

**Raw** pastes exactly what Whisper heard. **Light**, the default, removes
hesitation sounds such as "um", "uh", "ээ", or "음", tidies the spaces around
punctuation, capitalizes the first letter, and ends the text with a full
stop. Light works offline and leaves words with meaning alone: filler words
such as "like" and self-corrections need Clean.

The cloud modes, marked with ☁︎, send the recognized text to Claude or
OpenAI, whichever you choose in Settings › AI Models:

- **Clean** removes filler words and false starts, keeps only the final
  version when you correct yourself ("Thursday, no, Friday"), and fixes the
  grammar and punctuation, in the language you spoke.
- **Formal** does the same in a polite, concise business tone.
- **Translate to English** translates the text into English.

Without an API key, without a network connection, when the provider does
not answer within 3 seconds, or when its answer cannot be used, Dictate
pastes the Light text instead, and the HUD says why.

### Your own instructions

In Settings › Writing, **Instructions…** next to Clean, Formal, and Translate
to English shows what the mode asks the model to do, and lets you rewrite it, for example for a more
casual tone or your team's style. Dictate still tells the model to treat
what you said as text and to reply with the text only. **Reset to Default**
brings back the original.

### A mode for each app

An app can have a mode of its own, such as Formal in Mail and Raw in
Terminal. Choose **Mode in *app*** in the menu while the app is in front, or
add the app in Settings › Writing › Apps. Dictate uses the mode of the app that
was in front when you pressed the key.

### The cloud provider

Settings › AI Models has a section for **Claude** and one for **OpenAI**: paste
the provider's API key there and click **Use** on the one the cloud modes
should call:

- Claude: create the key inside a workspace in the
  [Anthropic Console](https://console.anthropic.com/settings/keys).
- OpenAI: create the key in the
  [OpenAI dashboard](https://platform.openai.com/settings/organization/api-keys).

Each provider keeps its own key in your login Keychain, on this Mac only, and
Dictate reads it for each cloud request. **Remove** deletes it.

## Languages

![Settings with the languages](../.github/screenshots/languages.jpg)

Add the languages you speak in Settings › Dictation with **Add Language**, and
Dictate detects which of them you speak each time. Fewer languages make detection faster and
more accurate. To skip detection, pin one language with **Spoken language**
or the **Language** menu.

On first launch, Dictate adds up to three of your macOS preferred languages
and English.

## Dictionary and snippets

Settings › Dictionary holds two lists.

**Terms** are names and words that come out wrong. Dictate gives them to
Whisper as a hint, then replaces the spellings Whisper still writes instead:
list them under **Heard as**, separated by commas. Replacements match whole
words in any letter case and work in every mode, Raw included.

**Snippets** turn a phrase into text. Say the phrase on its own, and Dictate
pastes the text exactly as written without sending anything to the cloud. The
phrase inside a longer dictation is replaced too.

Both lists live in `dictionary.json`, which **Open in Editor** opens:

```json
{
  "terms": [
    { "term": "Kubernetes", "spoken": ["kubernetis", "kuber"] },
    { "term": "WhisperKit" }
  ],
  "snippets": [
    { "trigger": "my email", "text": "name@example.com" }
  ]
}
```

Edits to the file apply from the next dictation.

## History

Settings › History lists your dictations with the time, the mode, and the app,
and copies any of them with one click. They stay for a month and up to 1,000
dictations unless you change **Keep dictations for** (a day to forever) or
**Keep at most** (100 to 10,000). Turn off
**Keep history** to stop saving new ones; **Clear History…** deletes them all. A text kept out of
a password field is never saved.

## Settings

| Pane | What you set there |
| --- | --- |
| General | Opening at login, the menu bar icon, sounds, permissions |
| Dictation | The dictation key, the microphone, languages, the spoken language |
| Writing | The mode and its instructions, per-app modes, pasting |
| AI Models | The speech model, and Claude or OpenAI with their API keys for the cloud modes |
| Dictionary | Terms and snippets |
| History | How long and how much to keep, searching, copying, and clearing |
| About | The version, the source code, and the license |

With **Paste into the focused field** off, Dictate only puts the text on the
clipboard for you to paste with ⌘V.
