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

    func testDatabaseRenamesDeletesSearchesAndTransfersPresets() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: exportURL)
        }

        let database = try ReverbDatabase(url: url)
        let presetID = try database.savePreset(ReverbPreset(name: "Plate Room", settings: ReverbSettings(wetLevel: 0.8)))
        try database.renamePreset(id: presetID, name: "Plate Room Wide")
        XCTAssertEqual(try database.presets(search: "Wide").filter { $0.id == presetID }.first?.name, "Plate Room Wide")

        try database.exportPresets(to: exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        try database.deletePreset(id: presetID)
        XCTAssertFalse(try database.presets().contains { $0.id == presetID })
        try database.importPresets(from: exportURL)
        XCTAssertTrue(try database.presets(search: "Plate").contains { $0.name == "Plate Room Wide" })

        let renderID = try database.saveRender(RenderRecord(
            name: "Searchable Render",
            dryPath: "/tmp/dry.wav",
            impulsePath: "/tmp/ir.wav",
            outputPath: "/tmp/out.wav",
            settings: ReverbSettings(),
            sampleRate: 48_000,
            duration: 2
        ))
        try database.renameRender(id: renderID, name: "Renamed Render")
        XCTAssertTrue(try database.renders(search: "Renamed").contains { $0.id == renderID })
        try database.deleteRender(id: renderID)
        XCTAssertFalse(try database.renders(search: "Renamed").contains { $0.id == renderID })
    }
}
