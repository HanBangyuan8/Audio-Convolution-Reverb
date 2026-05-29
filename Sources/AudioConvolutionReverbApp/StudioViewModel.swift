import AppKit
import AVFoundation
import AudioConvolutionReverbCore
import Foundation
import UniformTypeIdentifiers

enum PlaybackTarget: String, CaseIterable, Identifiable {
    case dry = "Dry"
    case rendered = "Rendered"
    case impulse = "IR"

    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case wav = "WAV"
    case aiff = "AIFF"
    case caf = "CAF"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }

    var audioType: AVAudioConverterIO.AudioFileType {
        switch self {
        case .wav: return .wav
        case .aiff: return .aiff
        case .caf: return .caf
        }
    }
}

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var dryURL: URL?
    @Published var impulseURL: URL?
    @Published var renderedURL: URL?
    @Published var outputURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("output/rendered_reverb.wav")
    @Published var exportFormat: ExportFormat = .wav
    @Published var settings = ReverbSettings()
    @Published var renders: [RenderRecord] = []
    @Published var presets: [ReverbPreset] = []
    @Published var renderSearch = ""
    @Published var presetSearch = ""
    @Published var status = "Ready"
    @Published var isRendering = false
    @Published var renderProgress = 0.0
    @Published var playbackTarget: PlaybackTarget = .rendered
    @Published var isPlaying = false
    @Published var dryAnalysis: AudioAnalysis?
    @Published var impulseAnalysis: AudioAnalysis?
    @Published var renderedAnalysis: AudioAnalysis?
    @Published var customDuration = 2.8
    @Published var customDecay = 4.2
    @Published var customTone = 0.55
    @Published var customReflections = 10.0
    @Published var previewSeconds = 8.0

    private let database: ReverbDatabase
    private var renderTask: Task<Void, Never>?
    private var player: AVAudioPlayer?

    init() {
        database = (try? ReverbDatabase()) ?? (try! ReverbDatabase(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("reverb.sqlite")))
        refresh()
    }

    func refresh() {
        renders = (try? database.renders(search: renderSearch, limit: 100)) ?? []
        presets = (try? database.presets(search: presetSearch)) ?? []
    }

    func chooseDryAudio() {
        if let url = openAudioPanel(title: "Choose Dry Audio") {
            loadDry(url)
        }
    }

    func chooseImpulse() {
        if let url = openAudioPanel(title: "Choose Impulse Response") {
            loadImpulse(url)
        }
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = "Save Rendered Reverb"
        panel.allowedContentTypes = [.wav, .aiff, .audio]
        panel.nameFieldStringValue = outputURL.deletingPathExtension().lastPathComponent + "." + exportFormat.fileExtension
        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
            exportFormat = ExportFormat(rawValue: url.pathExtension.uppercased()) ?? .wav
        }
    }

    func loadDry(_ url: URL) {
        dryURL = url
        if outputURL.lastPathComponent == "rendered_reverb.wav" {
            outputURL = url.deletingLastPathComponent().appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-convolution-reverb." + exportFormat.fileExtension)
        }
        analyze(url: url) { self.dryAnalysis = $0 }
        status = "Loaded dry audio: \(url.lastPathComponent)"
    }

    func loadImpulse(_ url: URL) {
        impulseURL = url
        analyze(url: url) { self.impulseAnalysis = $0 }
        status = "Loaded impulse response: \(url.lastPathComponent)"
    }

    func acceptDrop(_ providers: [NSItemProvider], target: PlaybackTarget) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let data = item as? Data
                let url = data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                guard let url else { return }
                Task { @MainActor in
                    if target == .impulse { self.loadImpulse(url) } else { self.loadDry(url) }
                }
            }
            return true
        }
        return false
    }

    func applyPreset(_ preset: ReverbPreset) {
        settings = preset.settings
        status = "Loaded preset: \(preset.name)"
    }

    func saveCurrentPreset() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let name = "Custom \(formatter.string(from: Date()))"
        do {
            _ = try database.savePreset(ReverbPreset(name: name, settings: settings))
            refresh()
            status = "Saved preset: \(name)"
        } catch {
            status = error.localizedDescription
        }
    }

    func renamePreset(_ preset: ReverbPreset) {
        guard let name = prompt("Rename Preset", text: preset.name), !name.isEmpty else { return }
        do {
            try database.renamePreset(id: preset.id, name: name)
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    func deletePreset(_ preset: ReverbPreset) {
        do {
            try database.deletePreset(id: preset.id)
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    func exportPresets() {
        let panel = NSSavePanel()
        panel.title = "Export Presets"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "audio-convolution-reverb-presets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try database.exportPresets(to: url)
            status = "Exported presets"
        } catch {
            status = error.localizedDescription
        }
    }

    func importPresets() {
        let panel = NSOpenPanel()
        panel.title = "Import Presets"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try database.importPresets(from: url)
            refresh()
            status = "Imported presets"
        } catch {
            status = error.localizedDescription
        }
    }

    func renameRender(_ render: RenderRecord) {
        guard let name = prompt("Rename Render", text: render.name), !name.isEmpty else { return }
        do {
            try database.renameRender(id: render.id, name: name)
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    func deleteRender(_ render: RenderRecord) {
        do {
            try database.deleteRender(id: render.id)
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    func revealRender(_ render: RenderRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: render.outputPath)])
    }

    func reopenRender(_ render: RenderRecord) {
        renderedURL = URL(fileURLWithPath: render.outputPath)
        analyze(url: URL(fileURLWithPath: render.outputPath)) { self.renderedAnalysis = $0 }
        status = "Loaded render: \(render.name)"
    }

    func generateCustomImpulse() {
        let panel = NSSavePanel()
        panel.title = "Save Custom Impulse Response"
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = "custom-convolution-reverb-ir.wav"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let ir = ReverbDSP.createCustomImpulse(
                sampleRate: 48_000,
                duration: customDuration,
                decay: customDecay,
                tone: customTone,
                earlyReflectionCount: Int(customReflections)
            )
            try AVAudioConverterIO.write(ir, to: url, type: .wav)
            loadImpulse(url)
            status = "Generated custom IR: \(url.lastPathComponent)"
        } catch {
            status = error.localizedDescription
        }
    }

    func renderPreview() {
        render(previewOnly: true)
    }

    func render() {
        render(previewOnly: false)
    }

    func cancelRender() {
        renderTask?.cancel()
        isRendering = false
        renderProgress = 0
        status = "Render cancelled"
    }

    private func render(previewOnly: Bool) {
        guard let dryURL, let impulseURL else {
            status = "Choose a dry audio file and an impulse response first."
            return
        }

        renderTask?.cancel()
        isRendering = true
        renderProgress = 0.05
        status = previewOnly ? "Rendering preview..." : "Rendering with FFT convolution..."

        let settings = settings
        let outputURL = previewOnly ? FileManager.default.temporaryDirectory.appendingPathComponent("audio-convolution-preview.wav") : normalizedOutputURL()
        let database = database
        let previewSeconds = previewSeconds
        let exportType = exportFormat.audioType

        renderTask = Task.detached(priority: .userInitiated) {
            do {
                var dry = try AVAudioConverterIO.read(from: dryURL)
                if previewOnly {
                    dry = dry.prefix(seconds: previewSeconds)
                }
                try Task.checkCancellation()
                await MainActor.run { self.renderProgress = 0.25; self.status = "Loaded dry audio" }

                let impulse = try AVAudioConverterIO.read(from: impulseURL)
                try Task.checkCancellation()
                await MainActor.run { self.renderProgress = 0.45; self.status = "Loaded impulse response" }

                let rendered = ReverbDSP.applyConvolutionReverb(dry: dry, impulseResponse: impulse, settings: settings)
                try Task.checkCancellation()
                await MainActor.run { self.renderProgress = 0.82; self.status = "Writing output" }

                try AVAudioConverterIO.write(rendered, to: outputURL, type: previewOnly ? .wav : exportType)
                if !previewOnly {
                    let record = RenderRecord(
                        name: outputURL.deletingPathExtension().lastPathComponent,
                        dryPath: dryURL.path,
                        impulsePath: impulseURL.path,
                        outputPath: outputURL.path,
                        settings: settings,
                        sampleRate: rendered.sampleRate,
                        duration: rendered.duration
                    )
                    _ = try database.saveRender(record)
                }

                await MainActor.run {
                    self.renderedURL = outputURL
                    self.renderedAnalysis = AudioAnalyzer.analyze(rendered)
                    self.refresh()
                    self.isRendering = false
                    self.renderProgress = 1
                    self.status = previewOnly ? "Preview ready" : "Rendered \(outputURL.lastPathComponent)"
                    if previewOnly {
                        self.play(url: outputURL, target: .rendered)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isRendering = false
                    self.renderProgress = 0
                    self.status = "Render cancelled"
                }
            } catch {
                await MainActor.run {
                    self.isRendering = false
                    self.renderProgress = 0
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func playSelected() {
        switch playbackTarget {
        case .dry:
            guard let dryURL else { status = "No dry audio loaded"; return }
            play(url: dryURL, target: .dry)
        case .rendered:
            guard let renderedURL else { status = "No render ready"; return }
            play(url: renderedURL, target: .rendered)
        case .impulse:
            guard let impulseURL else { status = "No impulse response loaded"; return }
            play(url: impulseURL, target: .impulse)
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func abToggle() {
        playbackTarget = playbackTarget == .dry ? .rendered : .dry
        playSelected()
    }

    func openOutputFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func play(url: URL, target: PlaybackTarget) {
        do {
            stopPlayback()
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            playbackTarget = target
            isPlaying = true
            status = "Playing \(target.rawValue)"
        } catch {
            status = error.localizedDescription
        }
    }

    private func analyze(url: URL, assign: @escaping @MainActor (AudioAnalysis) -> Void) {
        Task.detached(priority: .utility) {
            guard let buffer = try? AVAudioConverterIO.read(from: url) else { return }
            let analysis = AudioAnalyzer.analyze(buffer)
            await MainActor.run { assign(analysis) }
        }
    }

    private func normalizedOutputURL() -> URL {
        let base = outputURL.deletingPathExtension()
        let url = base.appendingPathExtension(exportFormat.fileExtension)
        outputURL = url
        return url
    }

    private func openAudioPanel(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.wav, .aiff, .audio, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func prompt(_ title: String, text: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = text
        alert.accessoryView = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
