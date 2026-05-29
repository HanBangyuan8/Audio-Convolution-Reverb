import AVFoundation
import Foundation

public enum AVAudioConverterIO {
    public enum AudioFileType: String, CaseIterable, Sendable {
        case wav
        case aiff
        case caf
        case m4a

        public var fileType: AVFileType {
            switch self {
            case .wav: return .wav
            case .aiff: return .aiff
            case .caf: return .caf
            case .m4a: return .m4a
            }
        }

        public var settings: [String: Any] {
            switch self {
            case .m4a:
                return [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 192_000
                ]
            case .aiff:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: true,
                    AVLinearPCMIsNonInterleaved: false
                ]
            case .caf:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            default:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            }
        }

        public static func from(url: URL) -> AudioFileType {
            switch url.pathExtension.lowercased() {
            case "aif", "aiff": return .aiff
            case "caf": return .caf
            case "m4a", "mp4": return .m4a
            default: return .wav
            }
        }
    }

    public static let readableExtensions = ["wav", "aif", "aiff", "caf", "m4a", "mp4"]

    public static func read(from url: URL) throws -> AudioBuffer {
        if url.pathExtension.lowercased() == "wav" {
            if let wav = try? WAVAudioIO.read(from: url) {
                return wav
            }
        }

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioConvolutionReverb.AudioIO", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate audio buffer."])
        }
        try file.read(into: pcm)
        return AudioBuffer(pcmBuffer: pcm)
    }

    public static func write(_ buffer: AudioBuffer, to url: URL, type: AudioFileType? = nil) throws {
        let targetType = type ?? AudioFileType.from(url: url)
        if targetType == .wav {
            try WAVAudioIO.write(buffer, to: url, bitDepth: 24)
            return
        }

        let channelCount = max(1, buffer.channelCount)
        var settings = targetType.settings
        settings[AVSampleRateKey] = buffer.sampleRate
        settings[AVNumberOfChannelsKey] = channelCount
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buffer.frameCount)) else {
            throw NSError(domain: "AudioConvolutionReverb.AudioIO", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate export buffer."])
        }
        pcm.frameLength = AVAudioFrameCount(buffer.frameCount)
        for channel in 0..<Int(format.channelCount) {
            guard let pointer = pcm.floatChannelData?[channel] else { continue }
            let source = buffer.samples[min(channel, buffer.samples.count - 1)]
            for frame in 0..<buffer.frameCount {
                pointer[frame] = Float(source[frame])
            }
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try file.write(from: pcm)
    }
}

public extension AudioBuffer {
    init(pcmBuffer: AVAudioPCMBuffer) {
        let frameCount = Int(pcmBuffer.frameLength)
        let sampleRate = Int(pcmBuffer.format.sampleRate)
        let channelCount = Int(pcmBuffer.format.channelCount)
        var samples = Array(repeating: Array(repeating: 0.0, count: frameCount), count: max(1, channelCount))

        if let floatData = pcmBuffer.floatChannelData {
            for channel in 0..<max(1, channelCount) {
                for frame in 0..<frameCount {
                    samples[channel][frame] = Double(floatData[channel][frame])
                }
            }
        } else {
            let converterFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: AVAudioChannelCount(max(1, channelCount)), interleaved: false)!
            let converter = AVAudioConverter(from: pcmBuffer.format, to: converterFormat)
            let converted = AVAudioPCMBuffer(pcmFormat: converterFormat, frameCapacity: pcmBuffer.frameCapacity)!
            var error: NSError?
            converter?.convert(to: converted, error: &error) { _, status in
                status.pointee = .haveData
                return pcmBuffer
            }
            if let floatData = converted.floatChannelData {
                for channel in 0..<max(1, channelCount) {
                    for frame in 0..<Int(converted.frameLength) {
                        samples[channel][frame] = Double(floatData[channel][frame])
                    }
                }
            }
        }

        self.init(samples: samples, sampleRate: sampleRate)
    }
}
