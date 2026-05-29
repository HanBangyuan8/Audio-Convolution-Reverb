import Foundation
import XCTest
@testable import AudioConvolutionReverbCore

final class ReverbDatabaseTests: XCTestCase {
    func testDatabasePersistsPresetAndRender() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let database = try ReverbDatabase(url: url)
        let settings = ReverbSettings(dryLevel: 0.4, wetLevel: 0.7)
        let presetID = try database.savePreset(ReverbPreset(name: "Test Preset", settings: settings))
        XCTAssertGreaterThan(presetID, 0)

        let renderID = try database.saveRender(RenderRecord(
            name: "Render",
            dryPath: "/tmp/dry.wav",
            impulsePath: "/tmp/ir.wav",
            outputPath: "/tmp/out.wav",
            settings: settings,
            sampleRate: 48_000,
            duration: 1.5
        ))
        XCTAssertGreaterThan(renderID, 0)
        XCTAssertTrue(try database.presets().contains { $0.name == "Test Preset" })
        XCTAssertTrue(try database.renders().contains { $0.name == "Render" })
    }
}
