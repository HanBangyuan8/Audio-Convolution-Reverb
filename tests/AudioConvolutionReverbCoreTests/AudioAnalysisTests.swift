import XCTest
@testable import AudioConvolutionReverbCore

final class AudioAnalysisTests: XCTestCase {
    func testAudioAnalysisProducesWaveformSpectrumAndDecay() {
        let samples = (0..<2_048).map { sin(2 * Double.pi * 440 * Double($0) / 44_100) }
        let buffer = AudioBuffer(samples: [samples], sampleRate: 44_100)
        let analysis = AudioAnalyzer.analyze(buffer, points: 64)

        XCTAssertFalse(analysis.waveform.peaks.isEmpty)
        XCTAssertFalse(analysis.spectrum.isEmpty)
        XCTAssertFalse(analysis.decay.isEmpty)
        XCTAssertGreaterThan(analysis.waveform.peak, 0.9)
    }

    func testPrefixCreatesPreviewSegment() {
        let buffer = AudioBuffer(samples: [Array(repeating: 0.1, count: 1_000)], sampleRate: 1_000)
        XCTAssertEqual(buffer.prefix(seconds: 0.25).frameCount, 250)
    }
}
