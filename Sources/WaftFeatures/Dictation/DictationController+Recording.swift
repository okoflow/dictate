import Foundation
import os
import WaftCore

extension DictationController {
    func beginRecording(for trigger: RecordingTrigger) {
        lastRecordingID = lastRecordingID.next
        watchdog.reset()

        var started = ActiveRecording(id: lastRecordingID, purpose: trigger.purpose, key: trigger.key)
        started.watchdogTimer = .scheduledInCommonModes(every: Self.watchdogInterval, repeats: true) { [weak self] in
            self?.pollKey()
        }

        if let problem = reasonNotToRecord(for: trigger.purpose) {
            started.isRejected = true
            recording = started

            hud.show(HUDMessage(kind: .info, title: problem))

            return
        }

        started.hudTask = scheduleListeningHUD(for: started.id)
        recording = started
        isRecording = true

        let id = started.id
        let deviceID = settings.settings.microphoneID

        Task { await recorder.start(id, deviceID: deviceID) }
        Task { [weak self] in self?.captureTarget(for: id) }
    }

    func endRecording(_ ending: Ending) {
        guard let ended = recording else { return }

        recording = nil
        isRecording = false

        ended.hudTask?.cancel()
        ended.watchdogTimer?.invalidate()

        guard !ended.isRejected else { return }

        switch ending {
        case let .discard(reason):
            hud.hideListening()
            Logger.dictation.info("Discarded the recording: \(reason.rawValue, privacy: .public)")

            Task { _ = await recorder.stop(ended.id, releasedAt: nil) }

        case let .finish(releasedAt):
            hud.hideListening(handingOverTo: DictationQueue.transcribingLabel)

            if settings.settings.playsSounds {
                sounds.play(.recordingFinished)
            }

            Task { await finish(ended, releasedAt: releasedAt) }
        }
    }

    func failRecording(_ reason: String) {
        guard var failed = recording, !failed.hasFailed else { return }

        failed.hasFailed = true
        recording = failed

        hud.hideListening()
        hud.show(HUDMessage(kind: .warning, title: String(localized: "Recording failed"), detail: reason))

        let id = failed.id

        Task { _ = await recorder.stop(id, releasedAt: nil) }
    }

    private func reasonNotToRecord(for purpose: RecordingPurpose) -> String? {
        if purpose == .edit, !pro.allows(.editing) {
            return String(localized: "Editing by voice is part of Waft Pro.")
        }

        if !speechModel.state.isReady {
            return speechModel.state.notReadyMessage
        }

        if permissions.status(of: .microphone) == .denied {
            return String(localized: "Waft can't use the microphone. Allow it in Settings › General.")
        }

        return nil
    }

    private func scheduleListeningHUD(for id: RecordingID) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: Self.hudDelay)
            guard !Task.isCancelled else { return }

            self?.showListeningHUD(for: id)
        }
    }

    private func showListeningHUD(for id: RecordingID) {
        guard let recording, recording.id == id, !recording.hasFailed else { return }

        let mode = settings.settings.mode(for: recording.target?.bundleIdentifier)
        let badge = recording.purpose == .edit ? String(localized: "Edit") : mode == .light ? nil : mode.title
        let recorder = recorder

        hud.showListening(badge: badge, isHandsFree: recording.isHandsFree) { recorder.inputLevel }
    }

    private func captureTarget(for id: RecordingID) {
        guard let started = recording, started.id == id else { return }

        let target = focusTracker.currentFocus()
        recording?.target = target

        guard started.purpose == .edit else { return }

        if let selection = target.element?.selectedText {
            recording?.selection = selection
        } else {
            reject(started, because: String(localized: "Select the text to edit, then hold the key and say what to change."))
        }
    }

    private func reject(_ rejected: ActiveRecording, because reason: String) {
        rejected.hudTask?.cancel()
        recording?.isRejected = true
        isRecording = false

        hud.hideListening()
        hud.show(HUDMessage(kind: .info, title: reason))

        let id = rejected.id

        Task { _ = await recorder.stop(id, releasedAt: nil) }
    }

    private func finish(_ ended: ActiveRecording, releasedAt: TimeInterval) async {
        let samples = await recorder.stop(ended.id, releasedAt: ended.hasFailed ? nil : releasedAt)
        guard !ended.hasFailed else { return }
        guard !samples.isEmpty else {
            let reason = await recorder.failureReason(for: ended.id) ?? String(localized: "No audio was captured.")

            hud.show(HUDMessage(kind: .warning, title: String(localized: "Recording failed"), detail: reason))

            return
        }

        submit(samples, target: ended.target ?? focusTracker.currentFocus(), selection: ended.selection)
    }

    private func submit(_ samples: [Float], target: FocusTarget, selection: String?) {
        let current = settings.settings

        if current.appModes.mode(for: target.bundleIdentifier) != nil {
            Logger.dictation.info("Using the app's own mode for \(target.bundleIdentifier ?? "the app", privacy: .public)")
        }

        queue.submit(DictationJob(
            samples: samples,
            target: target,
            selection: selection,
            settings: current,
            vocabulary: vocabulary.reloadFromDisk(),
            allowsAI: pro.allows(.aiModes),
        ))
    }

    private func pollKey() {
        guard let recording else { return }

        let now = Uptime.now

        guard !recording.isHandsFree else {
            tick(.tick, at: now)

            return
        }

        let isHeld = keyboardState.isHeld(recording.key)

        switch watchdog.poll(isHeld: isHeld, at: now) {
        case .holding:
            tick(.tick, at: now)
        case let .released(since):
            Logger.dictation.notice("The key-up never arrived; ending the recording")

            tick(.keyUp, at: since)
        }
    }
}
