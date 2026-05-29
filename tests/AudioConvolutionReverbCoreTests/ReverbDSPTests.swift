import XCTest
@testable import AudioConvolutionReverbCore

final class ReverbDSPTests: XCTestCase {
    func testGenerateLogSweepIsNormalized() {
        let sweep = ReverbDSP.generateLogSweep(duration: 0.1, sampleRate: 1_000, startFrequency: 20, endFrequency: 200)
        XCTAssertEqual(sweep.frameCount, 100)
        XCTAssertLessThanOrEqual(sweep.monoSamples.map(abs).max() ?? 0, 1.0 + 1e-9)
    }

    func testFFTConvolutionReverbPreservesDryLength() {
        let dry = AudioBuffer(samples: [[1, 0, 0, 0, 0, 0, 0, 0]], sampleRate: 8_000)
        let ir = AudioBuffer(samples: [[1, 0.5, 0.25]], sampleRate: 8_000)
        var settings = ReverbSettings()
        settings.dryLevel = 0
        settings.wetLevel = 1
        settings.normalizeOutput = false
        settings.lowCutHz = 0
        settings.highCutHz = 4_000

        let rendered = ReverbDSP.applyConvolutionReverb(dry: dry, impulseResponse: ir, settings: settings)

        XCTAssertEqual(rendered.frameCount, dry.frameCount)
        XCTAssertEqual(rendered.samples[0][0], 1, accuracy: 1e-9)
        XCTAssertEqual(rendered.samples[0][1], 0.5, accuracy: 1e-9)
        XCTAssertEqual(rendered.samples[0][2], 0.25, accuracy: 1e-9)
    }

    func testCustomImpulseCanBeGenerated() {
        let impulse = ReverbDSP.createCustomImpulse(sampleRate: 1_000, duration: 1, decay: 3, tone: 0.6, earlyReflectionCount: 5)
        XCTAssertEqual(impulse.frameCount, 1_000)
        XCTAssertGreaterThan(ReverbDSP.rms(impulse.monoSamples), 0)
    }
}
