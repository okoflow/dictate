# Privacy

Waft recognizes speech on your Mac. This page lists what it keeps, where,
and the two cases in which it uses the network.

## Audio

Audio is recorded only while you hold the dictation or editing key. It stays
in memory until Whisper has recognized it and is then discarded. It is never
written to disk and never sent anywhere, in any mode. Files you transcribe
are read from where they are, recognized on the Mac in the same way, and
never uploaded.

## The network

Waft connects to these services, and only for these reasons:

| Service | When | What is sent |
| --- | --- | --- |
| Hugging Face | Downloading the speech model, once | Requests for the model files |
| Anthropic API | Dictating in Clean, Formal, or Translate with Claude chosen and a key added | The recognized text, the mode's instruction, the spoken language, the target language when translating, your Claude API key |
| OpenAI API | Dictating in Clean, Formal, or Translate with OpenAI chosen and a key added | The recognized text, the mode's instruction, the spoken language, the target language when translating, your OpenAI API key |
| A local server you run | Dictating in Clean, Formal, or Translate with Local server chosen | The same as above without a key, sent only to the address you set, usually on this Mac |

Editing by voice sends the selected text and your spoken instruction to the
same provider, under the same conditions. With a local server on your Mac,
everything stays on the Mac. Raw and Light never use the network. In the cloud modes, only the provider
you chose receives the text after recognition, never audio, and only when the
mode in use is a cloud mode and you have added a key for that provider.
Waft asks OpenAI not to store the response. Anthropic's
[privacy policy](https://www.anthropic.com/legal/privacy) and OpenAI's
[API data controls](https://developers.openai.com/api/docs/guides/your-data)
describe how each API handles it.

## What Waft keeps

| What | Where |
| --- | --- |
| Settings | The `com.okoflow.waft` preferences domain |
| Dictionary and snippets | `~/Library/Application Support/Waft/dictionary.json` |
| Word and time counts per day for the stats | `~/Library/Application Support/Waft/stats.json`, no text |
| History, kept for a month unless you choose otherwise | `~/Library/Application Support/Waft/history.json`, readable only by you |
| Speech model | `~/Library/Application Support/Waft/Models` |
| The model compiled for your chip | `~/Library/Caches/com.okoflow.waft` |
| Claude and OpenAI API keys | The login Keychain, service `com.okoflow.waft`, on this Mac only |
| Waft Pro license key | The login Keychain, service `com.okoflow.waft`, checked on the Mac without a server |

Copy Last Transcript keeps your last five texts in memory for 10 minutes; they
are never written to disk. With **Keep history** off, no new texts are added to
the history, and a text kept out of a password field is never saved at all.

## Logs

Waft writes to the unified log under the `com.okoflow.waft` subsystem: what
it did, how long it took, the mode, why a cloud mode fell back to Light, the
app it pasted into, and how many characters it pasted. The dictated text and
the audio never reach the log.

## Removing everything

Quit Waft, delete the app, then remove its data:

```sh
rm -r ~/Library/Application\ Support/Waft ~/Library/Caches/com.okoflow.waft
defaults delete com.okoflow.waft
security delete-generic-password -s com.okoflow.waft -a anthropic-api-key
security delete-generic-password -s com.okoflow.waft -a openai-api-key
security delete-generic-password -s com.okoflow.waft -a license-key
tccutil reset All com.okoflow.waft
```

The last four commands remove the API keys, the license key, and the
permissions you granted. If you ran `make signing`, delete the Waft Dev
certificate in Keychain Access as well.

### Data from Dictate

Waft used to be called Dictate. On first launch, Waft moves Dictate's data
over, but the API keys and permissions stay under the old name too:

```sh
security delete-generic-password -s dev.dictate.app -a anthropic-api-key
security delete-generic-password -s dev.dictate.app -a openai-api-key
tccutil reset All dev.dictate.app
```
