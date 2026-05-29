import Foundation

public enum WAVAudioIO {
    public enum WAVError: Error, LocalizedError {
        case invalidFile
        case unsupportedFormat(String)

        public var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The file is not a valid WAV file."
            case .unsupportedFormat(let detail):
                return "Unsupported WAV format: \(detail)"
            }
        }
    }

    public static func read(from url: URL) throws -> AudioBuffer {
        let data = try Data(contentsOf: url)
        guard data.count > 44, data.string(at: 0, length: 4) == "RIFF", data.string(at: 8, length: 4) == "WAVE" else {
            throw WAVError.invalidFile
        }

        var offset = 12
        var audioFormat: UInt16 = 0
        var channelCount: UInt16 = 0
        var sampleRate: UInt32 = 0
        var bitsPerSample: UInt16 = 0
        var dataRange: Range<Int>?

        while offset + 8 <= data.count {
            let id = data.string(at: offset, length: 4)
            let size = Int(data.uint32LE(at: offset + 4))
            let chunkStart = offset + 8
            let chunkEnd = min(chunkStart + size, data.count)

            if id == "fmt ", chunkStart + 16 <= chunkEnd {
                audioFormat = data.uint16LE(at: chunkStart)
                channelCount = data.uint16LE(at: chunkStart + 2)
                sampleRate = data.uint32LE(at: chunkStart + 4)
                bitsPerSample = data.uint16LE(at: chunkStart + 14)
            } else if id == "data" {
                dataRange = chunkStart..<chunkEnd
            }

            offset = chunkEnd + (size % 2)
        }

        guard let range = dataRange, channelCount > 0, sampleRate > 0 else {
            throw WAVError.invalidFile
        }

        let channels = Int(channelCount)
        let bytesPerSample = Int(bitsPerSample / 8)
        guard bytesPerSample > 0 else { throw WAVError.unsupportedFormat("missing bit depth") }

        let frameCount = (range.count / bytesPerSample) / channels
        var samples = Array(repeating: Array(repeating: 0.0, count: frameCount), count: channels)
        var cursor = range.lowerBound

        for frame in 0..<frameCount {
            for channel in 0..<channels {
                samples[channel][frame] = try sample(from: data, at: cursor, audioFormat: audioFormat, bitsPerSample: bitsPerSample)
                cursor += bytesPerSample
            }
        }

        return AudioBuffer(samples: samples, sampleRate: Int(sampleRate))
    }

    public static func write(_ buffer: AudioBuffer, to url: URL, bitDepth: Int = 16) throws {
        guard [16, 24, 32].contains(bitDepth) else {
            throw WAVError.unsupportedFormat("write bit depth \(bitDepth)")
        }

        let channels = max(1, buffer.channelCount)
        let frames = buffer.frameCount
        let bytesPerSample = bitDepth / 8
        let dataByteCount = frames * channels * bytesPerSample
        let byteRate = buffer.sampleRate * channels * bytesPerSample
        let blockAlign = channels * bytesPerSample

        var data = Data()
        data.appendASCII("RIFF")
        data.appendUInt32LE(UInt32(36 + dataByteCount))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(UInt16(channels))
        data.appendUInt32LE(UInt32(buffer.sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitDepth))
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(dataByteCount))

        for frame in 0..<frames {
            for channel in 0..<channels {
                let value = buffer.samples[min(channel, buffer.samples.count - 1)][frame]
                data.appendPCM(value, bitDepth: bitDepth)
            }
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private static func sample(from data: Data, at offset: Int, audioFormat: UInt16, bitsPerSample: UInt16) throws -> Double {
        if audioFormat == 1 {
            switch bitsPerSample {
            case 16:
                return Double(data.int16LE(at: offset)) / Double(Int16.max)
            case 24:
                return Double(data.int24LE(at: offset)) / 8_388_608.0
            case 32:
                return Double(data.int32LE(at: offset)) / Double(Int32.max)
            default:
                throw WAVError.unsupportedFormat("PCM \(bitsPerSample)-bit")
            }
        }

        if audioFormat == 3 {
            switch bitsPerSample {
            case 32:
                return Double(data.float32LE(at: offset))
            case 64:
                return data.float64LE(at: offset)
            default:
                throw WAVError.unsupportedFormat("float \(bitsPerSample)-bit")
            }
        }

        throw WAVError.unsupportedFormat("format code \(audioFormat)")
    }
}

private extension Data {
    func string(at offset: Int, length: Int) -> String {
        String(data: self[offset..<Swift.min(offset + length, count)], encoding: .ascii) ?? ""
    }

    func uint16LE(at offset: Int) -> UInt16 {
        self[offset..<offset + 2].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
    }

    func uint32LE(at offset: Int) -> UInt32 {
        self[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
    }

    func int16LE(at offset: Int) -> Int16 {
        Int16(bitPattern: uint16LE(at: offset))
    }

    func int24LE(at offset: Int) -> Int32 {
        let b0 = Int32(self[offset])
        let b1 = Int32(self[offset + 1]) << 8
        let b2 = Int32(self[offset + 2]) << 16
        var value = b0 | b1 | b2
        if value & 0x800000 != 0 { value |= ~0xFFFFFF }
        return value
    }

    func int32LE(at offset: Int) -> Int32 {
        Int32(bitPattern: uint32LE(at: offset))
    }

    func float32LE(at offset: Int) -> Float {
        Float(bitPattern: uint32LE(at: offset))
    }

    func float64LE(at offset: Int) -> Double {
        let bits = self[offset..<offset + 8].withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).littleEndian }
        return Double(bitPattern: bits)
    }

    mutating func appendASCII(_ value: String) {
        append(value.data(using: .ascii)!)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 2))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 4))
    }

    mutating func appendPCM(_ value: Double, bitDepth: Int) {
        let clamped = Swift.min(Swift.max(value, -1), 1)
        switch bitDepth {
        case 16:
            var intValue = Int16(clamped * Double(Int16.max)).littleEndian
            append(Data(bytes: &intValue, count: 2))
        case 24:
            let intValue = Int32(clamped * 8_388_607.0)
            append(UInt8(intValue & 0xFF))
            append(UInt8((intValue >> 8) & 0xFF))
            append(UInt8((intValue >> 16) & 0xFF))
        default:
            var intValue = Int32(clamped * Double(Int32.max)).littleEndian
            append(Data(bytes: &intValue, count: 4))
        }
    }
}
