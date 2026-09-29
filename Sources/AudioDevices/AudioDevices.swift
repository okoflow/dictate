import CoreAudio
import Foundation

/// A CoreAudio device as far as Dictate cares: how to select it and what to call it.
public struct AudioDevice: Equatable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
}

public enum AudioDirection: Sendable {
    case input
    case output

    fileprivate var scope: AudioObjectPropertyScope {
        switch self {
        case .input: kAudioObjectPropertyScopeInput
        case .output: kAudioObjectPropertyScopeOutput
        }
    }
}

/// Looks devices up by identity instead of by position, because the default device changes
/// with headphones and docks.
public enum AudioDevices {
    /// UID of the BlackHole 2ch virtual loopback driver, which the E2E suite records from.
    public static let blackHoleUID = "BlackHole2ch_UID"

    /// The first device in `direction` whose UID or name equals `query`. A UID is stable across
    /// systems and locales, so callers that know one should try it before the display name.
    public static func find(_ query: String, direction: AudioDirection) -> AudioDevice? {
        allDevices(direction: direction).first { $0.uid == query || $0.name == query }
    }

    public static func defaultInput() -> AudioDevice? {
        var address = address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown
        else { return nil }
        return device(id)
    }

    private static func allDevices(direction: AudioDirection) -> [AudioDevice] {
        var address = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { hasStreams($0, direction: direction) }.compactMap(device)
    }

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasStreams(_ id: AudioDeviceID, direction: AudioDirection) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: direction.scope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func device(_ id: AudioDeviceID) -> AudioDevice? {
        guard let uid = string(kAudioDevicePropertyDeviceUID, of: id),
              let name = string(kAudioObjectPropertyName, of: id)
        else { return nil }
        return AudioDevice(id: id, uid: uid, name: name)
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
