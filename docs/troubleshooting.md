# Troubleshooting

The first line of the Dictate menu says what Dictate is doing, and the HUD
explains every dictation that did not end in pasted text. Start there; the
sections below cover what they point to.

## Holding the key does nothing

- **The menu says "Setup needed".** Dictate is missing a permission. Choose
  **Finish Setup…**, or allow it in Settings › General › Permissions.
  Accessibility is under System Settings › Privacy & Security › Accessibility,
  or Device Control and Data Access on macOS 27.
- **The menu shows the speech model.** Dictate records nothing until the
  model is ready. The first load takes about a minute.
- **Another key is set.** Settings › Dictation › Hold to dictate shows which key
  Dictate listens for.
- **Permissions were lost after a rebuild.** An app signed ad hoc gets a new
  identity with every build, and macOS forgets what you allowed. Run
  `make signing` once, rebuild, remove the old Dictate entries in Privacy &
  Security, and allow the permissions again.

## The menu bar icon is missing

On macOS 26 and later, check that Dictate is allowed in System Settings ›
Menu Bar. On a crowded menu bar, the icon can hide behind the camera notch;
opening Dictate again while it runs shows Settings.

## The text is not pasted

| The HUD says | What happened |
| --- | --- |
| Copied: press ⌘V to paste | Focus moved to another app or field, Accessibility is not allowed, or you held the dictation key for 10 seconds after the text was ready |
| Not pasted into a password field | The field is a password field, or an app holds secure keyboard input; Copy Last Transcript gets the text back |
| Didn't catch that | The recording held no speech, or Whisper's result looked made up |
| Recording failed | The microphone stopped or delivered no audio |

With **Paste into the focused field** off in Settings › Writing, Dictate only
ever copies the text.

## The first word is cut off

The microphone takes a moment to start. Start speaking a beat after you press
the key.

## Recognition is poor or picks the wrong language

- Enable only the languages you speak, or pin one, in Settings › Dictation.
- Choose the microphone you speak into in Settings › Dictation › Microphone.
- Add names and terms that come out wrong to the dictionary, with the
  spellings Whisper writes under **Heard as**.

## The cloud modes use Light

The second line of the HUD says why and names the provider you chose,
Claude or OpenAI:

- **Add your API key**: add it in Settings › Cloud.
- **Rejected the API key**: check the key in the
  [Anthropic Console](https://console.anthropic.com/settings/keys) or the
  [OpenAI dashboard](https://platform.openai.com/settings/organization/api-keys) and paste it again.
- **You're offline**, **didn't answer within 3 seconds**, or **is
  rate-limiting requests**: the next dictation tries again. With OpenAI, the
  last one also appears when the account is out of credit: the `network` log
  category says `insufficient_quota`.
- **Returned an error**: the `network` log category records the reason. With
  Claude, the common one is a key that isn't scoped to a workspace: create
  the key inside a workspace in the Anthropic Console and paste it again.
- **The answer couldn't be used**: the answer was cut off, refused, or in
  another language. Dictating again usually works.

## The speech model fails

**Retry Speech Model** in the menu resumes a failed download. After a failed
load, it loads the model again, and if that fails too, it deletes the model and
downloads it anew. The model needs about 1 GB of free space, including its
compiled copy.

To start over by hand, quit Dictate and remove the model:

```sh
rm -r ~/Library/Application\ Support/Dictate/Models ~/Library/Caches/dev.dictate.app
```

## Logs

Dictate logs what it does, never what you said. Watch the log live while you
dictate, or show the last ten minutes:

```sh
log stream --level info --predicate 'subsystem == "dev.dictate.app"'
log show --last 10m --info --predicate 'subsystem == "dev.dictate.app"'
```

Attach the relevant lines to a bug report.
