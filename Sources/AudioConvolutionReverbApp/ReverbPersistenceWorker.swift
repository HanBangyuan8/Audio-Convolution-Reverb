import AudioConvolutionReverbCore
import Foundation

struct ReverbLibrarySnapshot: Sendable {
    let renders: [RenderRecord]
    let presets: [ReverbPreset]
}

actor ReverbPersistenceWorker {
    private let database: ReverbDatabase

    init(database: ReverbDatabase) {
        self.database = database
    }

    func snapshot(renderSearch: String, presetSearch: String, renderLimit: Int) throws -> ReverbLibrarySnapshot {
        ReverbLibrarySnapshot(
            renders: try database.renders(search: renderSearch, limit: renderLimit),
            presets: try database.presets(search: presetSearch)
        )
    }

    func savePreset(_ preset: ReverbPreset) throws {
        _ = try database.savePreset(preset)
    }

    func renamePreset(id: Int64, name: String) throws {
        try database.renamePreset(id: id, name: name)
    }

    func deletePreset(id: Int64) throws {
        try database.deletePreset(id: id)
    }

    func exportPresets(to url: URL) throws {
        try database.exportPresets(to: url)
    }

    func importPresets(from url: URL) throws {
        try database.importPresets(from: url)
    }

    func saveRender(_ record: RenderRecord) throws {
        _ = try database.saveRender(record)
    }

    func renameRender(id: Int64, name: String) throws {
        try database.renameRender(id: id, name: name)
    }

    func deleteRender(id: Int64) throws {
        try database.deleteRender(id: id)
    }
}
