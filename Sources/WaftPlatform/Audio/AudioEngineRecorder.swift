@preconcurrency import AVFoundation
import os
import WaftCore

package actor AudioEngineRecorder: AudioRecorder {
    private struct Session {
        let recording: RecordingID
        let engine: AVAudioEngine
        let sink: AudioSampleSink
        let configurationObserver: any NSObjectProtocol
        let sampleRate: Double
        let channelCount: AVAudioChannelCount
    }

    private enum StartError: Error, CustomStringConvertible {
        case noInputChannels(String)
        case unsupportedFormat
        case deviceUnavailable(OSStatus)

        var description: String {
            switch self {
            case let .noInputChannels(device): "the input device \"\(device)\" reports no channels"
            case .unsupportedFormat: "the input format isn't supported"
            case let .deviceUnavailable(status): "the input device can't be selected (OSStatus \(status))"
            }
        }
    }

    private static let tailGrace: TimeInterval = 0.15

    package nonisolated let events: AsyncStream<RecordingEvent>

    private nonisolated let continuation: AsyncStream<RecordingEvent>.Continuation
    private nonisolated let meter = LevelMeter()
    private let queue = DispatchSerialQueue(label: "\(AppIdentity.bundleIdentifier).recorder")
    private var session: Session?
    private var stoppedThrough = RecordingID.none
    private var lastFailure: (recording: RecordingID, reason: String)?

    package nonisolated var inputLevel: Float {
        meter.value
    }

    package nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    package init() {
        let stream = AsyncStream.makeStream(of: RecordingEvent.self)
        events = stream.stream
        continuation = stream.continuation
    }

    private nonisolated static func tapBlock(for sink: AudioSampleSink) -> AVAudioNodeTapBlock {
        { @Sendable buffer, time in
            sink.consume(buffer, at: time)
        }
    }

    package func start(_ recording: RecordingID, deviceID: String?) {
        guard recording > stoppedThrough else { return }

        tearDown()

        do {
            session = try makeSession(for: recording, deviceID: deviceID)
        } catch {
            report(String(describing: error), for: recording)
        }
    }

    package func stop(_ recording: RecordingID, releasedAt: TimeInterval?) async -> [Float] {
        stoppedThrough = max(stoppedThrough, recording)

        guard let current = session, current.recording == recording else { return [] }

        if let releasedAt {
            await waitForTail(of: current.sink, after: releasedAt)
        }

        if session?.recording == recording {
            tearDown()
        }

        return current.sink.samples
    }

    package func failureReason(for recording: RecordingID) -> String? {
        lastFailure?.recording == recording ? lastFailure?.reason : nil
    }

    private func makeSession(for recording: RecordingID, deviceID: String?) throws -> Session {
        let engine = AVAudioEngine()
        let deviceName = try selectInput(deviceID, on: engine)
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw StartError.noInputChannels(deviceName) }

        let continuation = continuation
        let sink = AudioSampleSink(inputFormat: format, meter: meter) {
            continuation.yield(.started(recording, deviceName: deviceName))
        }
        guard let sink else { throw StartError.unsupportedFormat }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(for: sink))
        let observer = observeConfigurationChanges(of: engine, for: recording)

        do {
            try engine.start()
        } catch {
            NotificationCenter.default.removeObserver(observer)
            engine.inputNode.removeTap(onBus: 0)

            throw error
        }

        return Session(
            recording: recording,
            engine: engine,
            sink: sink,
            configurationObserver: observer,
            sampleRate: format.sampleRate,
            channelCount: format.channelCount,
        )
    }

    private func selectInput(_ deviceID: String?, on engine: AVAudioEngine) throws -> String {
        let defaultName = CoreAudioInputs.defaultInputName() ?? "Default input"
        guard let deviceID else { return defaultName }
        guard let audioDeviceID = CoreAudioInputs.deviceID(for: deviceID), let unit = engine.inputNode.audioUnit else {
            Logger.audio.notice("The chosen microphone isn't connected; recording from the default input")

            return defaultName
        }

        var selected = audioDeviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selected,
            UInt32(MemoryLayout<AudioDeviceID>.size),
        )
        guard status == noErr else { throw StartError.deviceUnavailable(status) }

        return CoreAudioInputs.name(of: audioDeviceID) ?? defaultName
    }

    private func observeConfigurationChanges(of engine: AVAudioEngine, for recording: RecordingID) -> any NSObjectProtocol {
        NotificationCenter.default
            .addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
                Task { await self?.configurationChanged(for: recording) }
            }
    }

    private func configurationChanged(for recording: RecordingID) async {
        guard let current = session, current.recording == recording else { return }
        guard current.sink.hasAudio else {
            guard !current.engine.isRunning else { return }

            try? await Task.sleep(for: .milliseconds(200))

            if session?.recording == recording, !current.sink.hasAudio, !current.engine.isRunning {
                report("the audio engine stopped while starting", for: recording)
            }

            return
        }

        let format = current.engine.inputNode.inputFormat(forBus: 0)

        if !current.engine.isRunning {
            report("the audio engine stopped after a device change", for: recording)
        } else if format.sampleRate != current.sampleRate || format.channelCount != current.channelCount {
            report("the input format changed during the recording", for: recording)
        }
    }

    private func waitForTail(of sink: AudioSampleSink, after releasedAt: TimeInterval) async {
        let deadline = Uptime.now + Self.tailGrace

        while sink.coveredUntil < releasedAt, Uptime.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func report(_ reason: String, for recording: RecordingID) {
        lastFailure = (recording, reason)

        continuation.yield(.failed(recording, reason: reason))

        Logger.audio.error("Recording failed: \(reason, privacy: .public)")
    }

    private func tearDown() {
        guard let current = session else { return }

        NotificationCenter.default.removeObserver(current.configurationObserver)
        current.engine.inputNode.removeTap(onBus: 0)
        current.engine.stop()

        session = nil
        meter.value = 0
    }
}
