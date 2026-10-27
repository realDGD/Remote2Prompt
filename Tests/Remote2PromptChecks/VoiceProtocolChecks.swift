import Foundation
import Remote2PromptCore

func voiceProtocolChecks() -> [(String, () throws -> Void)] {
    [
        ("voice settings migrate without enabling audio", {
            let value = try AppConfiguration.decode(Data("{\"schemaVersion\":2,\"mappingsEnabled\":true,\"voiceTrigger\":\"rightControl\"}".utf8))
            try expect(value.voiceEnabled && !value.remoteAudioEnabled && value.voiceTrigger == .rightControl, "Old voice behavior lost or audio silently enabled")
            let defaults = AppConfiguration()
            try expect(!defaults.voiceEnabled && !defaults.remoteAudioEnabled && !defaults.mappingsEnabled, "New settings take over devices by default")
            try expect(try AppConfiguration.decode(value.encoded()) == value, "Voice settings did not round trip")
        }),
        ("ATVV capabilities require supported codec and bounded frame size", {
            let valid = try VoiceCapabilities(packet: Data([11,1,0,2,3,0,120]))
            try expect(valid.frameBytes == 120 && valid.version == 0x100, "Capabilities decoded incorrectly")
            let extended = try VoiceCapabilities(packet: Data([11,1,0,0,2,0,120,0,0]))
            try expect(extended.frameBytes == 120, "Extended v1 capabilities rejected")
            do { _ = try VoiceCapabilities(packet: Data([11,1,0,1,3,0,120])); throw CheckFailure(description: "8 kHz accepted") }
            catch VoiceProtocolFailure.unsupportedCodec {}
            do { _ = try VoiceCapabilities(packet: Data([11,1,0,2,3,255,255])); throw CheckFailure(description: "Oversized frame accepted") }
            catch VoiceProtocolFailure.invalidFrameSize {}
            do { _ = try VoiceCapabilities(packet: Data([11])); throw CheckFailure(description: "Truncated capabilities accepted") }
            catch VoiceProtocolFailure.malformed {}
        }),
        ("ADPCM uses high nibble first with standard predictor updates", {
            var decoder = try RemoteVoiceDecoder(frameBytes: 2)
            let samples = try decoder.append(Data([0x12,0x78]))
            try expect(samples == [1,4,15,13], "Nibble order or state update changed")
        }),
        ("ADPCM frame fragments preserve decoder state", {
            var whole = try RemoteVoiceDecoder(frameBytes: 3)
            var pieces = try RemoteVoiceDecoder(frameBytes: 3)
            let expected = try whole.append(Data([0x12,0x34,0x56,0x78,0x9A,0xBC]))
            let first = try pieces.append(Data([0x12]))
            let second = try pieces.append(Data([0x34,0x56,0x78,0x9A]))
            let third = try pieces.append(Data([0xBC]))
            try expect(first.isEmpty && second + third == expected && pieces.pendingBytes.isEmpty, "Fragment handling lost data")
        }),
        ("ADPCM sync discards partial frame and validates index", {
            var decoder = try RemoteVoiceDecoder(frameBytes: 2)
            _ = try decoder.append(Data([0x77]))
            try decoder.synchronize(packet: Data([10,0,0,0,0xFF,0xFE,0]))
            try expect(decoder.pendingBytes.isEmpty && decoder.predictor == -2, "Sync retained stale partial bytes")
            let samples = try decoder.append(Data([0,0]))
            try expect(samples == [-2,-2,-2,-2], "Sync predictor was ignored")
            do { try decoder.reset(stepIndex: 89); throw CheckFailure(description: "Invalid step accepted") }
            catch VoiceProtocolFailure.invalidSync {}
        }),
        ("ADPCM saturates and reset prevents cross-session audio", {
            var decoder = try RemoteVoiceDecoder(frameBytes: 1)
            try decoder.reset(predictor: 32760, stepIndex: 88)
            try expect(try decoder.append(Data([0x77])) == [32767,32767], "Positive saturation failed")
            try decoder.reset(predictor: -32760, stepIndex: 88)
            try expect(try decoder.append(Data([0xFF])) == [-32768,-32768], "Negative saturation failed")
            try decoder.reset()
            try expect(try decoder.append(Data([0])) == [0,0], "Reset leaked preceding voice")
            do { _ = try decoder.append(Data(repeating: 0, count: 4097)); throw CheckFailure(description: "Unbounded packet accepted") }
            catch VoiceProtocolFailure.oversizedPacket {}
        })
    ]
}
