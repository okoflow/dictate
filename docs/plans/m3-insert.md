# M3 — text insertion + Raw mode (MVP): implementation plan

Task: TaskQ #98. Built on top of M2 (branch `m3-insert` from `m2-transcribe`). Delivered together with M2 as one hand-off.

## Goal

After transcription, the text is **typed into the focused field of the frontmost app**. That is the MVP:
hold the key → speak → release → the text appears where the cursor is. Mode "Raw" = Whisper text as-is
(plus a trailing space policy, below).

## Design

- **`Inserter`** (app, `@MainActor`):
  1. If Secure Input is active (`IsSecureEventInputEnabled()`) or the focused element is a secure
     text field (AX role/subrole `AXSecureTextField`) → do not paste; overlay shows the text with a
     "Copy" button for ~5 s; event `insertionSkipped(.secureInput)`.
  2. Snapshot the general pasteboard: all items with all their types (data per type), and the change count.
  3. Write the text as one item, types `public.utf8-plain-text` plus `org.nspasteboard.TransientType`
     and `org.nspasteboard.ConcealedType` (clipboard managers skip it).
  4. Post ⌘V: a private-state `CGEventSource`, key `v` (keycode 9) down/up with `.maskCommand`, posted
     at `.cghidEventTap`. Needs Accessibility (Dictate already has it).
  5. Restore the snapshot after ~300 ms, **only if** the pasteboard change count is still the one we
     set (the user or the target app did not copy something new meanwhile).
  6. Event `inserted(characters, app bundle id)`, never the text.
- **Focused-app awareness:** remember the frontmost app at key-down. If the frontmost app changed
  by the time the transcript is ready, don't paste into the wrong app: keep the text on the clipboard
  (as in M2) and show "Copied — ⌘V to paste"; event `insertionSkipped(.focusChanged)`.
- **Queue:** transcripts are inserted in press order (FIFO), one at a time; the next insertion waits
  until the previous clipboard restore has finished.
- **Spacing (pure core function, unit-tested):** add a leading space if the character before the
  caret (AX `AXSelectedTextRange` + `AXValue`, when readable) is not whitespace and not the start of
  the text; otherwise no leading space. If unreadable → no leading space. No trailing space.
- **Fallback:** if AX can't find a focused text element, still paste (many apps, e.g. Electron,
  expose poor AX); if paste fails there is nothing to detect — the text stays recoverable because
  the overlay offers "Copy" for 5 s after every insertion.
- **Mode:** menu shows "Mode: Raw" (M4 adds more); the M2 clipboard-only behaviour becomes a
  setting "Insert into the focused field" (default on) — off = clipboard only (M2 behaviour).

## Tests

- Unit (core): spacing decision; snapshot/restore decision (change-count rule); queue ordering;
  secure/focus-change decisions as pure functions.
- E2E smoke — replace `dictate-fixture-to-clipboard` with **`dictate-into-testpad`**: TestPad
  frontmost with some existing text, hold right Option, play `ru-plain-2.wav`, release → TestPad text
  = previous text + space + transcript (CER ≤ 15 %), clipboard restored to what it was before.
- E2E full only: password field gets nothing (`insertionSkipped(.secureInput)`); two quick phrases
  arrive in order; focus changed → not pasted.
- Manual (README checklist, not automated): TextEdit, Chrome, Terminal, Slack/Telegram.

## Definition of done

Full `make check` once at the end, `make e2e` smoke once, README (how to use the MVP, what happens
in password fields, clipboard behaviour, known limits), commits on `m3-insert`, nothing pushed.

---

## Revision after critique (binding; overrides the sections above)

1. **Restore timing:** write the text through an `NSPasteboardItem` with an `NSPasteboardItemDataProvider` (lazy data). Restore ~150 ms after the provider callback fires (the target has read it). If the callback never fires, restore after 1.5 s. No fixed 300 ms.
2. **Snapshot safety:**
   - don't snapshot/restore at all if the current pasteboard has `org.nspasteboard.ConcealedType` or `TransientType` (password managers rely on the change count to auto-clear);
   - cap the snapshot at 5 MB total; skip `dyn.*` and file-promise types;
   - over the cap → no restore, event `restoreSkipped(reason)`.
3. **Hotkey still held:** wait until `Hotkey.isStillHeld` is false (right Option physically released) before posting ⌘V. Post ⌘V from a **private-state** `CGEventSource`, so the synthetic ⌘ never enters the HID state the watchdog reads.
4. **No clickable "Copy" button on the overlay** (it stays non-activating and click-through). Instead, add a menu item "Copy last transcript" (from the transcript store) and overlay text "Copied — ⌘V to paste" when not inserted.
5. **Secure input:** decide on the focused element's `AXSecureTextField` subrole only. The global `IsSecureEventInputEnabled()` is only reported in the event (`secureInputActive: Bool`), not used to block. README gets a manual check for Terminal "Secure Keyboard Entry".
6. **Spacing read:**
   - `AXUIElementSetMessagingTimeout(element, 0.1)`;
   - read one character with `AXStringForRange` for `(loc-1, 1)` from `AXSelectedTextRange`, UTF-16 indexing (NSString);
   - trim Whisper's leading/trailing whitespace first;
   - no leading space after whitespace, start of text, `(`, `"`, `«`, `„`, `/`, `[`;
   - same rule for ru/en/ko.
7. **Focus check at paste time** (after the queue wait): compare the focused AX element (`CFEqual`) with the one captured at key-down, falling back to the pid when the element is unavailable. On a mismatch → don't paste; copy and show the overlay hint.
8. **Keycode for V:** resolve the key that produces "v" in the current ASCII-capable layout via `UCKeyTranslate` (fallback: keycode 9). README notes the Dvorak case.
9. **Paste is the only insertion method** (no `AXSelectedText` set).
10. **Scope:**
    - drop the "Mode: Raw" menu item (M4); keep the "Insert into the focused field" on/off setting;
    - password-field, ordering and focus-change behaviour → unit tests on pure decisions;
    - e2e smoke keeps only `dictate-into-testpad`, and the runner asserts TestPad is frontmost right before releasing the key (otherwise it aborts the check);
    - the M2 `dictate-fixture-to-clipboard` smoke check is replaced (or moved to full).

---

## Deviations (as built)

- **Test-only paste guard.** With the default settings the smoke suite's earlier checks would paste English text
  into the terminal the suite runs from. Under `DICTATE_E2E=1`, `--insert-only-into <bundle id>` makes Dictate
  paste only into TestPad and do nothing (clipboard untouched) elsewhere (`insertionSkipped(notAllowed)`).
- **TestPad got an Edit menu:** ⌘V reaches a text view only through a menu key equivalent.
- **Password field:** the text is neither pasted nor copied (the plan said "overlay shows the text"); the way back
  is "Copy last transcript" (in memory only).
- **`--clipboard-only`** flag added so the full suite can still check the M2 clipboard path
  (`dictate-fixture-to-clipboard`, now full-only, relaunches the app with it).
- **Queue ordering** is inherited from the M2 pipeline (one `AsyncStream` consumer that awaits each insertion,
  including the clipboard restore); it has no separate unit test because it is not a pure function.
- **Not built:** the full-only e2e checks for password field, ordering and focus change (revision 10 moved
  them to unit tests of the pure decisions in `InsertionRulesTests`).
