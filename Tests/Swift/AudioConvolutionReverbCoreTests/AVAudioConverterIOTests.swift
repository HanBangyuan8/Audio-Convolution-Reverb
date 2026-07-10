import Foundation
import XCTest
@testable import AudioConvolutionReverbCore

final class AVAudioConverterIOTests: XCTestCase {
    func testWriteAndReadAIFF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".aiff")
        defer { try? FileManager.default.removeItem(at: url) }

        let audio = AudioBuffer(samples: [[0, 0.2, -0.2, 0.4]], sampleRate: 44_100)
        try AVAudioConverterIO.write(audio, to: url, type: .aiff)
        let read = try AVAudioConverterIO.read(from: url)

        XCTAssertEqual(read.sampleRate, 44_100)
        XCTAssertEqual(read.channelCount, 1)
        XCTAssertEqual(read.frameCount, 4)
    }

    func testWriteAndReadCAF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }

        let audio = AudioBuffer(samples: [[0, 0.1, -0.1, 0.2], [0, -0.1, 0.1, -0.2]], sampleRate: 48_000)
        try AVAudioConverterIO.write(audio, to: url, type: .caf)
        let read = try AVAudioConverterIO.read(from: url)

        XCTAssertEqual(read.sampleRate, 48_000)
        XCTAssertEqual(read.channelCount, 2)
        XCTAssertEqual(read.frameCount, 4)
    }
}
