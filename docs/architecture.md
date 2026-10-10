# Architecture

Dictate is a Swift package of four libraries and an executable. The domain
and every interface live in one module that depends on nothing but
Foundation; the system frameworks and WhisperKit stay behind those interfaces,
and a single composition root wires the real implementations together.

## Modules

```mermaid
flowchart TD
  dictate[Dictate<br/>composition root] --> features[DictateFeatures<br/>models · flow · views]
  dictate --> platform[DictatePlatform<br/>macOS adapters]
  dictate --> speech[DictateSpeech<br/>WhisperKit adapter]
  features --> core[DictateCore<br/>domain · interfaces]
  platform --> core
  speech --> core
```

| Module | Isolation | What lives there |
| --- | --- | --- |
| `DictateCore` | Nonisolated | Domain types, text and recognition rules, state machines, and every interface |
| `DictateSpeech` | Nonisolated | `WhisperTranscriber`, the model files, and the language-restricted tokenizer |
| `DictatePlatform` | Nonisolated | Adapters for audio, the keyboard, Accessibility, the pasteboard, storage, the network, and the system |
| `DictateFeatures` | Main actor | Observable models, the dictation flow, the HUD, the menu, Settings, and the first-run guide |
| `Dictate` | Main actor | The app, its delegate, and `AppDependencies.live()` |

Dependencies point toward `DictateCore`:

- `DictateCore` imports Foundation only.
- `DictateFeatures` depends on `DictateCore` alone. It never sees the AppKit
  adapters or WhisperKit, only their interfaces, so any implementation can
  stand in for them.
- `DictatePlatform` and `DictateSpeech` implement interfaces from
  `DictateCore` and know nothing about the features.
- Only the `Dictate` executable names concrete adapters, in
  `AppDependencies.live()`.

Declarations shared between modules use `package` access; nothing is
`public`.

## Interfaces

| Interface | Abstracts | Live implementation |
| --- | --- | --- |
| `AudioRecorder` | Recording from a microphone | `AudioEngineRecorder`, on AVAudioEngine |
| `AudioInputProvider` | The list of input devices | `CoreAudioInputs` |
| `Transcriber` | The speech model's lifecycle and recognition | `WhisperTranscriber` |
| `TextRewriter` | Rewriting text in a cloud mode | `AnthropicRewriter`, `OpenAIRewriter` |
| `KeyEventMonitor` | Modifier key events | `ModifierKeyTap`, a listen-only event tap |
| `KeyboardState` | Whether a key is held right now | `SystemKeyboardState` |
| `GlobalShortcut` | The next-mode shortcut | `CarbonHotKey` |
| `FocusTracker` | The focused app and text field | `AccessibilityFocusTracker` |
| `TextInserter` | Pasting into the focused field | `PasteboardInserter` |
| `Clipboard` | Copying text | `SystemClipboard` |
| `PermissionProvider` | Microphone and Accessibility access | `SystemPermissions` |
| `LoginItem` | Opening at login | `MainAppLoginItem`, on SMAppService |
| `FeedbackSoundPlayer` | Start and stop sounds | `SystemSoundPlayer` |
| `ValueStore<Value>` | Loading and saving one value | `UserDefaultsStore`, `JSONFileStore`, `KeychainStore` |

`AppDependencies` collects one implementation of each, and a `TextRewriter`
and an API key store for each cloud provider, plus the stores for the
settings, the dictionary, and the history. `AppModel` takes it in its
initializer; there are no singletons.

## The dictation flow

```mermaid
flowchart LR
  monitor[KeyMonitorController] --> controller[DictationController]
  controller --> recorder[AudioRecorder]
  controller --> queue[DictationQueue]
  queue --> transcriber[Transcriber]
  queue --> processor[TranscriptProcessor]
  processor --> modes[ModeProcessor<br/>LightModeRules · TextRewriter]
  queue --> inserter[TextInserter]
  queue --> hud[HUDController]
```

1. `KeyMonitorController` keeps the `KeyEventMonitor` running, restarting it
   when a permission arrives or macOS switches it off.
2. `DictationController` feeds key events to `PushToTalk`, a state machine
   that decides when a recording starts, finishes, or is discarded, and polls
   `ReleaseWatchdog` in case a key-up is lost. It starts and stops the
   `AudioRecorder` and captures the focus target.
3. `DictationQueue` runs finished recordings one at a time: the `Transcriber`
   recognizes them, `TranscriptProcessor` applies the dictionary, snippets,
   and the mode, and the `TextInserter` pastes the result.
4. `ModeProcessor` runs `LightModeRules` or the `TextRewriter` under the
   3-second deadline, checks the answer with `RewriteValidator`, and falls
   back to Light with a `RewriteFallback` that says why.
5. The outcome becomes a `HUDMessage`, a history entry, and the latest
   transcript.

## State

Feature state lives in `@Observable` models owned by `AppModel`:
`SettingsModel`, `PermissionMonitor`, `SpeechModelController`,
`VocabularyModel`, `HistoryModel`, `APIKeyModel`, `FrontmostAppTracker`,
`OnboardingModel`, and `HUDController`. Views read them directly; changes
that affect other models, such as new languages reloading the speech model,
are wired once in `AppModel`.

Rules that need no system access are value types in `DictateCore`, so they
can be reasoned about on their own: `PushToTalk`, `ReleaseWatchdog`,
`SpeechModelState`, whose transitions return effects for the controller to
run, `InsertionDecision`, `PasteboardRestorePolicy`, `HallucinationFilter`,
and `LightModeRules`.

## Concurrency

The package builds in the Swift 6 language mode with complete concurrency
checking, and treats every warning as an error.

- `DictateFeatures` and the executables isolate their declarations to the
  main actor by default.
- `DictateCore`, `DictateSpeech`, and `DictatePlatform` are nonisolated.
  Values that cross into them are `Sendable`.
- `WhisperTranscriber` and `AudioEngineRecorder` are actors, so recognition
  and audio work stay off the main actor.
- Nonisolated async functions run on the caller's actor
  (`NonisolatedNonsendingByDefault`).

## Extending

- **A language.** Add a case to `Language` with its Whisper code and names,
  then its data: hesitation sounds in `HesitationPattern`, stock phrases in
  `StockPhrase`, the example sentence in `WhisperPrompt`, and the writing
  system and typography in `Language+Typography`.
- **A mode.** Add a case to `Mode` with its title and summary. A cloud mode
  needs its instruction in `RewritePrompt`.
- **An adapter.** Implement the interface in `DictatePlatform` and pass it in
  `AppDependencies.live()`.

[CONTRIBUTING.md](../CONTRIBUTING.md) describes the code style and the checks.
