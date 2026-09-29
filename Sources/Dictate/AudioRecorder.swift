import AudioDevices
@preconcurrency import AVFoundation
import Foundation

/// What a recording reports while it runs. `generation` identifies the recording, so a late
/// report from one that was already stopped can be dropped.
enum RecorderEvent: Sendable {
    /// The first buffer arrived from `device`: the microphone is really live.
    case started(device: String)
    /// Recording cannot continue (no device, engine error, device unplugged).
    case failed(String)
}

/// Records the microphone into 16 kHz mono samples, one `AVAudioEngine` per recording.
///
/// An actor that runs on its own serial queue: `engine.start()` blocks for a while and must not
/// stall the main thread (which would delay the hotkey tap), and every start or stop is ordered
/// against the others. Each recording carries a generation number from the caller, so a short
/// press whose `stop` overtakes its `start` cancels the start instead of leaving the microphone on.
actor AudioRecorder {
    private struct Session {
        let generation: Int
        let engine: AVAudioEngine
        let sink: AudioSink
        let configObserver: NSObjectProtocol
    }

    private let queue = DispatchSerialQueue(label: "dev.dictate.recorder")
    private var session: Session?
    /// Highest generation that was stopped; any `start` at or below it is stale.
    private var stoppedThrough = 0
    private let onEvent: @Sendable (Int, RecorderEvent) -> Void

    /// Input level for the overlay; safe to read from any thread.
    nonisolated let meter = LevelMeter()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    init(onEvent: @escaping @Sendable (Int, RecorderEvent) -> Void) {
        self.onEvent = onEvent
    }

    /// Starts capturing from the device called `deviceName`, or the system default when `nil`.
    func start(generation: Int, deviceName: String?) {
        guard generation > stoppedThrough else { return }
        teardown()
        meter.value = 0
        do {
            session = try makeSession(generation: generation, deviceName: deviceName)
        } catch {
            onEvent(generation, .failed(String(describing: error)))
        }
    }

    /// Ends the recording and returns what was captured (empty if it never started).
    func stop(generation: Int) -> [Float] {
        stoppedThrough = max(stoppedThrough, generation)
        guard let current = session, current.generation == generation else { return [] }
        let samples = current.sink.takeSamples()
        teardown()
        return samples
    }

    private func makeSession(generation: Int, deviceName: String?) throws -> Session {
        let engine = AVAudioEngine()
        let device = try select(deviceName, on: engine)

        // An input node with no channels (no microphone, or one that just vanished) makes
        // `installTap` raise an Objective-C exception that Swift cannot catch.
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw RecorderError.noInputFormat(device) }

        let onEvent = onEvent
        guard let sink = AudioSink(inputFormat: format, meter: meter, onFirstBuffer: {
            onEvent(generation, .started(device: device))
        }) else { throw RecorderError.unsupportedFormat }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(sink))
        // A device change (unplugged, sample rate switched) stops the engine or changes the format
        // the converter was built for; report it instead of silently recording nothing. The engine
        // also posts this once while it starts up, with nothing actually changed, so ignore that.
        let observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak engine] _ in
            let current = engine?.inputNode.inputFormat(forBus: 0)
            guard engine?.isRunning != true || current != format else { return }
            onEvent(generation, .failed("audio configuration changed during recording"))
        }
        do {
            try engine.start()
        } catch {
            NotificationCenter.default.removeObserver(observer)
            engine.inputNode.removeTap(onBus: 0)
            throw error
        }
        return Session(generation: generation, engine: engine, sink: sink, configObserver: observer)
    }

    /// Built outside the actor on purpose: a closure created in an isolated context inherits that
    /// isolation, and the audio thread would then trap on the executor check.
    private nonisolated static func tapBlock(_ sink: AudioSink) -> AVAudioNodeTapBlock {
        { @Sendable buffer, _ in
            sink.consume(buffer)
        }
    }

    /// Points the engine at the requested device and returns the device's name.
    private func select(_ name: String?, on engine: AVAudioEngine) throws -> String {
        guard let name else {
            return AudioDevices.defaultInput()?.name ?? "default input"
        }
        guard let device = AudioDevices.find(name, direction: .input) else { throw RecorderError.deviceNotFound(name) }
        guard let unit = engine.inputNode.audioUnit else { throw RecorderError.unsupportedFormat }
        var id = device.id
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw RecorderError.cannotSelect(name, status) }
        return device.name
    }

    private func teardown() {
        guard let current = session else { return }
        NotificationCenter.default.removeObserver(current.configObserver)
        current.engine.inputNode.removeTap(onBus: 0)
        current.engine.stop()
        session = nil
        meter.value = 0
    }
}

enum RecorderError: Error, CustomStringConvertible {
    case deviceNotFound(String)
    case cannotSelect(String, OSStatus)
    case noInputFormat(String)
    case unsupportedFormat

    var description: String {
        switch self {
        case let .deviceNotFound(name): "input device \"\(name)\" not found"
        case let .cannotSelect(name, status): "cannot select input device \"\(name)\" (OSStatus \(status))"
        case let .noInputFormat(name): "input device \"\(name)\" reports no channels"
        case .unsupportedFormat: "input format not supported"
        }
    }
}
