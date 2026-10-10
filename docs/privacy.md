# Privacy

Dictate recognizes speech on your Mac. This page lists what it keeps, where,
and the two cases in which it uses the network.

## Audio

Audio is recorded only while you hold the dictation key. It stays in memory
until Whisper has recognized it and is then discarded. It is never written to
disk and never sent anywhere, in any mode.

## The network

Dictate connects to these services, and only for these reasons:

| Service | When | What is sent |
| --- | --- | --- |
| Hugging Face | Downloading the speech model, once | Requests for the model files |
| Anthropic API | Dictating in Clean, Formal, or Translate with Claude chosen and a key added | The recognized text, the mode's instruction, the spoken language, the target language when translating, your Claude API key |
| OpenAI API | Dictating in Clean, Formal, or Translate with OpenAI chosen and a key added | The recognized text, the mode's instruction, the spoken language, the target language when translating, your OpenAI API key |
| A local server you run | Dictating in Clean, Formal, or Translate with Local server chosen | The same as above without a key, sent only to the address you set, usually on this Mac |

Raw and Light never use the network. In the cloud modes, only the provider
you chose receives the text after recognition, never audio, and only when the
mode in use is a cloud mode and you have added a key for that provider.
Dictate asks OpenAI not to store the response. Anthropic's
[privacy policy](https://www.anthropic.com/legal/privacy) and OpenAI's
[API data controls](https://developers.openai.com/api/docs/guides/your-data)
describe how each API handles it.

## What Dictate keeps

| What | Where |
| --- | --- |
| Settings | The `dev.dictate.app` preferences domain |
| Dictionary and snippets | `~/Library/Application Support/Dictate/dictionary.json` |
| History, kept for a month unless you choose otherwise | `~/Library/Application Support/Dictate/history.json`, readable only by you |
| Speech model | `~/Library/Application Support/Dictate/Models` |
| The model compiled for your chip | `~/Library/Caches/dev.dictate.app` |
| Claude and OpenAI API keys | The login Keychain, service `dev.dictate.app`, on this Mac only |

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
security delete-generic-password -s dev.dictate.app -a openai-api-key
tccutil reset All dev.dictate.app
```

The last three commands remove the API keys and the permissions you granted. If
you ran `make signing`, delete the Dictate Dev certificate in Keychain Access
as well.
