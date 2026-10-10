import CoreAudio
import WaftCore

package struct CoreAudioInputs: AudioInputProvider {
    package init() {}

    static func deviceID(for uid: String) -> AudioDeviceID? {
        inputDeviceIDs().first { string(kAudioDevicePropertyDeviceUID, of: $0) == uid }
    }

    static func name(of deviceID: AudioDeviceID) -> String? {
        string(kAudioObjectPropertyName, of: deviceID)
    }

    static func defaultInputName() -> String? {
        var address = address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }

        return name(of: deviceID)
    }

    private static func inputDeviceIDs() -> [AudioDeviceID] {
        var address = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &deviceIDs) == noErr else { return [] }

        return deviceIDs.filter(hasInputStreams)
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0

        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func string(_ selector: AudioObjectPropertySelector, of objectID: AudioObjectID) -> String? {
        var address = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return nil }

        return value?.takeRetainedValue() as String?
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    package func inputDevices() -> [AudioInputDevice] {
        Self.inputDeviceIDs().compactMap { deviceID in
            guard let uid = Self.string(kAudioDevicePropertyDeviceUID, of: deviceID),
                  let name = Self.name(of: deviceID) else { return nil }

            return AudioInputDevice(id: uid, name: name)
        }
    }
}
