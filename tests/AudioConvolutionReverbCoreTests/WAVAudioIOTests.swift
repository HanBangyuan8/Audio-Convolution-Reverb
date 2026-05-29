import Foundation
import XCTest
@testable import AudioConvolutionReverbCore

final class WAVAudioIOTests: XCTestCase {
    func testWriteAndReadWAV() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audio = AudioBuffer(samples: [[0, 0.25, -0.25, 0.5]], sampleRate: 44_100)
        try WAVAudioIO.write(audio, to: url, bitDepth: 24)
        let read = try WAVAudioIO.read(from: url)

        XCTAssertEqual(read.sampleRate, 44_100)
        XCTAssertEqual(read.channelCount, 1)
        XCTAssertEqual(read.frameCount, 4)
        XCTAssertEqual(read.samples[0][1], 0.25, accuracy: 0.001)
    }
}
