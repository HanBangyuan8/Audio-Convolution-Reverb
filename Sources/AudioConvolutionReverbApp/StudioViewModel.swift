import AppKit
import AudioConvolutionReverbCore
import Foundation
import UniformTypeIdentifiers

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var dryURL: URL?
    @Published var impulseURL: URL?
    @Published var outputURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("output/rendered_reverb.wav")
    @Published var settings = ReverbSettings()
    @Published var renders: [RenderRecord] = []
    @Published var presets: [ReverbPreset] = []
    @Published var status = "Ready"
    @Published var isRendering = false
    @Published var customDuration = 2.8
    @Published var customDecay = 4.2
    @Published var customTone = 0.55
    @Published var customReflections = 10.0

    private let database: ReverbDatabase

    init() {
        database = (try? ReverbDatabase()) ?? (try! ReverbDatabase(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("reverb.sqlite")))
        refresh()
    }

    func refresh() {
        renders = (try? database.renders()) ?? []
        presets = (try? database.presets()) ?? []
    }

    func chooseDryAudio() {
        if let url = openAudioPanel(title: "Choose Dry Audio") {
            dryURL = url
            if outputURL.lastPathComponent == "rendered_reverb.wav" {
                outputURL = url.deletingLastPathComponent().appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-convolution-reverb.wav")
            }
        }
    }

    func chooseImpulse() {
        impulseURL = openAudioPanel(title: "Choose Impulse Response")
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = "Save Rendered Reverb"
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = outputURL.lastPathComponent
        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
        }
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
            try WAVAudioIO.write(ir, to: url, bitDepth: 24)
            impulseURL = url
            status = "Generated custom IR: \(url.lastPathComponent)"
        } catch {
            status = error.localizedDescription
        }
    }

    func render() {
        guard let dryURL, let impulseURL else {
            status = "Choose a dry audio file and an impulse response first."
            return
        }

        isRendering = true
        status = "Rendering with FFT convolution..."
        let settings = settings
        let outputURL = outputURL
        let database = database

        Task.detached(priority: .userInitiated) {
            do {
                let dry = try WAVAudioIO.read(from: dryURL)
                let impulse = try WAVAudioIO.read(from: impulseURL)
                let rendered = ReverbDSP.applyConvolutionReverb(dry: dry, impulseResponse: impulse, settings: settings)
                try WAVAudioIO.write(rendered, to: outputURL, bitDepth: 24)
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
                await MainActor.run {
                    self.refresh()
                    self.isRendering = false
                    self.status = "Rendered \(outputURL.lastPathComponent)"
                }
            } catch {
                await MainActor.run {
                    self.isRendering = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func openOutputFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func openAudioPanel(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.wav, .aiff, .audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
