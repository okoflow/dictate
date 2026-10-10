# Privacy

Dictate recognizes speech on your Mac. This page lists what it keeps, where,
and the two cases in which it uses the network.

## Audio

Audio is recorded only while you hold the dictation key. It stays in memory
until Whisper has recognized it and is then discarded. It is never written to
disk and never sent anywhere, in any mode.

## The network

Dictate connects to two services, and only for these reasons:

| Service | When | What is sent |
| --- | --- | --- |
| Hugging Face | Downloading the speech model, once | Requests for the model files |
| Anthropic API | Dictating in Clean, Formal, or Translate to English with an API key | The recognized text, the mode's instruction, the spoken language, your API key |

Raw and Light never use the network. In the cloud modes, Claude receives the
text after recognition, never audio, and only when the mode in use is a cloud
mode and you have added a key. Anthropic's
[privacy policy](https://www.anthropic.com/legal/privacy) describes how the API
handles it.

## What Dictate keeps

| What | Where |
| --- | --- |
| Settings | The `dev.dictate.app` preferences domain |
| Dictionary and snippets | `~/Library/Application Support/Dictate/dictionary.json` |
| History, the last 50 texts | `~/Library/Application Support/Dictate/history.json`, readable only by you |
| Speech model | `~/Library/Application Support/Dictate/Models` |
| The model compiled for your chip | `~/Library/Caches/dev.dictate.app` |
| Claude API key | The login Keychain, item `dev.dictate.app`, on this Mac only |

Copy Last Transcript keeps your last five texts in memory for 10 minutes; they
are never written to disk. With **Keep history** off, no new texts are added to
the history, and a text kept out of a password field is never saved at all.

## Logs

Dictate writes to the unified log under the `dev.dictate.app` subsystem: what
it did, how long it took, the mode, why a cloud mode fell back to Light, the
app it pasted into, and how many characters it pasted. The dictated text and
the audio never reach the log.

## Removing everything

Quit Dictate, delete the app, then remove its data:

```sh
rm -r ~/Library/Application\ Support/Dictate ~/Library/Caches/dev.dictate.app
defaults delete dev.dictate.app
security delete-generic-password -s dev.dictate.app -a anthropic-api-key
tccutil reset All dev.dictate.app
```

The last two commands remove the API key and the permissions you granted. If
you ran `make signing`, delete the Dictate Dev certificate in Keychain Access
as well.
