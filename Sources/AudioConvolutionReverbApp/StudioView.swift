import AudioConvolutionReverbCore
import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = StudioViewModel()

    private var palette: Palette { Palette(colorScheme) }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 440)
            mainPanel
                .frame(minWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.background)
        .foregroundStyle(palette.primaryText)
        .onReceive(NotificationCenter.default.publisher(for: .renderRequested)) { _ in
            model.render()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Convolution")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Reverb Studio")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
            }

            HStack(spacing: 10) {
                StatTile(title: "History", value: "\(model.renders.count)", palette: palette)
                StatTile(title: "Presets", value: "\(model.presets.count)", palette: palette)
            }

            TextField("Search renders", text: $model.renderSearch)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.renderSearch) { _ in model.refresh() }

            SidebarHeader(title: "Presets", palette: palette) {
                Button(action: model.importPresets) { Image(systemName: "square.and.arrow.down") }
                Button(action: model.exportPresets) { Image(systemName: "square.and.arrow.up") }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.presets) { preset in
                        Button { model.applyPreset(preset) } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(palette.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Wet \(preset.settings.wetLevel, specifier: "%.2f") · Dry \(preset.settings.dryLevel, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename") { model.renamePreset(preset) }
                            Button("Delete", role: .destructive) { model.deletePreset(preset) }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)

            SidebarHeader(title: "Recent Renders", palette: palette) {}

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.renders) { render in
                        Button { model.reopenRender(render) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(render.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(render.sampleRate) Hz · \(render.duration, specifier: "%.1f") s")
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open") { model.reopenRender(render) }
                            Button("Reveal in Finder") { model.revealRender(render) }
                            Button("Rename") { model.renameRender(render) }
                            Button("Delete", role: .destructive) { model.deleteRender(render) }
                        }
                    }
                }
            }

            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                if model.isRendering {
                    ProgressView(value: model.renderProgress)
                        .progressViewStyle(.linear)
                }
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(model.isRendering ? palette.accent : palette.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(22)
        .frame(minWidth: 300, maxWidth: .infinity)
        .background(palette.sidebar)
    }

    private var mainPanel: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 18) {
                hero
                transportPanel
                filePanel
                visualizationPanel
                settingsPanel
                professionalPanel
                customImpulsePanel
                actionPanel
            }
            .padding(28)
            .frame(minWidth: 780, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Convolution reverb, from captured spaces to designed spaces.")
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("Import WAV, AIFF, CAF, or M4A. Preview, compare, visualize, render, and keep every useful preset or output in SQLite history.")
                .font(.title3)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var transportPanel: some View {
        StudioSection(title: "Playback and A/B", palette: palette) {
            HStack(spacing: 12) {
                Picker("Target", selection: $model.playbackTarget) {
                    ForEach(PlaybackTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Button(action: model.playSelected) {
                    Label(model.isPlaying ? "Restart" : "Play", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))

                Button(action: model.stopPlayback) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(SecondaryButtonStyle(palette: palette))

                Button(action: model.abToggle) {
                    Label("A/B", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(SecondaryButtonStyle(palette: palette))

                Spacer()

                SliderRow(title: "Preview", value: $model.previewSeconds, range: 2...30, suffix: " s", palette: palette)
                    .frame(width: 280)
            }
        }
    }

    private var filePanel: some View {
        StudioSection(title: "Session Files", palette: palette) {
            VStack(spacing: 12) {
                FileDropRow(
                    title: "Dry Audio",
                    value: model.dryURL?.path(percentEncoded: false) ?? "Drop WAV, AIFF, CAF, or M4A here",
                    icon: "waveform",
                    palette: palette,
                    action: model.chooseDryAudio
                )
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { model.acceptDrop($0, target: .dry) }

                FileDropRow(
                    title: "Impulse Response",
                    value: model.impulseURL?.path(percentEncoded: false) ?? "Drop an IR or generated space here",
                    icon: "dot.radiowaves.left.and.right",
                    palette: palette,
                    action: model.chooseImpulse
                )
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { model.acceptDrop($0, target: .impulse) }

                HStack {
                    FileDropRow(
                        title: "Output",
                        value: model.outputURL.path(percentEncoded: false),
                        icon: "square.and.arrow.down",
                        palette: palette,
                        action: model.chooseOutput
                    )
                    Picker("Format", selection: $model.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
            }
        }
    }

    private var visualizationPanel: some View {
        StudioSection(title: "Waveform, Spectrum, and Decay", palette: palette) {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    AnalysisCard(title: "Dry", analysis: model.dryAnalysis, palette: palette)
                    AnalysisCard(title: "Impulse", analysis: model.impulseAnalysis, palette: palette)
                    AnalysisCard(title: "Rendered", analysis: model.renderedAnalysis, palette: palette)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
                    SpectrumCard(title: "IR Frequency Response", analysis: model.impulseAnalysis, palette: palette)
                    DecayCard(title: "IR Energy Decay", analysis: model.impulseAnalysis, palette: palette)
                }
            }
        }
    }

    private var settingsPanel: some View {
        StudioSection(title: "Mix and Transform", palette: palette) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    SliderRow(title: "Dry", value: $model.settings.dryLevel, range: 0...1, suffix: "", palette: palette)
                    SliderRow(title: "Wet", value: $model.settings.wetLevel, range: 0...1, suffix: "", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Pre-delay", value: $model.settings.preDelayMilliseconds, range: 0...160, suffix: " ms", palette: palette)
                    SliderRow(title: "Decay", value: $model.settings.decayScale, range: 0.25...3, suffix: "x", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Low Cut", value: $model.settings.lowCutHz, range: 0...1_200, suffix: " Hz", palette: palette)
                    SliderRow(title: "High Cut", value: $model.settings.highCutHz, range: 2_000...22_000, suffix: " Hz", palette: palette)
                }
            }
            HStack {
                Toggle("Reverse impulse bloom", isOn: $model.settings.reverseImpulse)
                Toggle("Normalize output", isOn: $model.settings.normalizeOutput)
                Toggle("Normalize wet signal", isOn: $model.settings.normalizeWetSignal)
            }
        }
    }

    private var professionalPanel: some View {
        StudioSection(title: "Professional Controls", palette: palette) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    SliderRow(title: "Input Gain", value: $model.settings.inputGainDB, range: -24...24, suffix: " dB", palette: palette)
                    SliderRow(title: "Output Gain", value: $model.settings.outputGainDB, range: -24...24, suffix: " dB", palette: palette)
                }
                GridRow {
                    SliderRow(title: "IR Trim Start", value: $model.settings.impulseTrimStartMilliseconds, range: 0...500, suffix: " ms", palette: palette)
                    SliderRow(title: "IR Trim End", value: $model.settings.impulseTrimEndMilliseconds, range: 0...1_000, suffix: " ms", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Fade In", value: $model.settings.fadeInMilliseconds, range: 0...250, suffix: " ms", palette: palette)
                    SliderRow(title: "Fade Out", value: $model.settings.fadeOutMilliseconds, range: 0...1_000, suffix: " ms", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Stereo Width", value: $model.settings.stereoWidth, range: 0...2, suffix: "x", palette: palette)
                    SliderRow(title: "Tail Length", value: $model.settings.tailLengthSeconds, range: 0...12, suffix: " s", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Latency Comp", value: $model.settings.latencyCompensationMilliseconds, range: -120...120, suffix: " ms", palette: palette)
                    EmptyView()
                }
            }
            MeterRow(title: "Dry Level", analysis: model.dryAnalysis, palette: palette)
            MeterRow(title: "Rendered Level", analysis: model.renderedAnalysis, palette: palette)
        }
    }

    private var customImpulsePanel: some View {
        StudioSection(title: "Custom Convolution Reverb", palette: palette) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    SliderRow(title: "IR Duration", value: $model.customDuration, range: 0.3...10, suffix: " s", palette: palette)
                    SliderRow(title: "Decay", value: $model.customDecay, range: 0.5...10, suffix: "", palette: palette)
                }
                GridRow {
                    SliderRow(title: "Tone", value: $model.customTone, range: 0...1, suffix: "", palette: palette)
                    SliderRow(title: "Reflections", value: $model.customReflections, range: 0...40, suffix: "", palette: palette)
                }
            }
            Button { model.generateCustomImpulse() } label: {
                Label("Generate Custom IR", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
        }
    }

    private var actionPanel: some View {
        HStack(spacing: 12) {
            Button(action: model.renderPreview) {
                Label("Preview", systemImage: "bolt.fill")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .disabled(model.isRendering)

            Button(action: model.render) {
                Label(model.isRendering ? "Rendering..." : "Render", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
            .disabled(model.isRendering)

            Button(action: model.cancelRender) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .disabled(!model.isRendering)

            Button(action: model.saveCurrentPreset) {
                Label("Save Preset", systemImage: "bookmark")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))

            Button(action: model.openOutputFolder) {
                Label("Reveal Output", systemImage: "folder")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
        }
    }
}

private struct Palette {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) {
        self.scheme = scheme
    }

    var background: Color { Color(nsColor: .windowBackgroundColor) }
    var sidebar: Color { scheme == .dark ? Color.black.opacity(0.28) : Color(nsColor: .controlBackgroundColor) }
    var panel: Color { scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.045) }
    var panelStrong: Color { scheme == .dark ? Color.white.opacity(0.11) : Color.white }
    var primaryText: Color { Color(nsColor: .labelColor) }
    var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }
    var accent: Color { scheme == .dark ? .cyan : .blue }
    var stroke: Color { scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.09) }
}

private struct StudioSection<Content: View>: View {
    var title: String
    var palette: Palette
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.semibold))
            content
        }
        .padding(18)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke))
    }
}

private struct SidebarHeader<Content: View>: View {
    var title: String
    var palette: Palette
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            content.buttonStyle(.borderless)
        }
        .foregroundStyle(palette.primaryText)
    }
}

private struct FileDropRow: View {
    var title: String
    var value: String
    var icon: String
    var palette: Palette
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(width: 180, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Choose", action: action)
                .buttonStyle(SecondaryButtonStyle(palette: palette))
        }
        .padding(12)
        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke))
    }
}

private struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var suffix: String
    var palette: Palette

    var body: some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 110, alignment: .leading)
            Slider(value: $value, in: range)
            Text("\(value, specifier: "%.2f")\(suffix)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 82, alignment: .trailing)
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: String
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold))
            Text(title).font(.caption).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AnalysisCard: View {
    var title: String
    var analysis: AudioAnalysis?
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            WaveformView(peaks: analysis?.waveform.peaks ?? [], palette: palette)
                .frame(height: 82)
            HStack {
                Text("Peak \(analysis?.waveform.peak ?? 0, specifier: "%.2f")")
                Spacer()
                Text("RMS \(analysis?.waveform.rms ?? 0, specifier: "%.2f")")
                Spacer()
                Text("\(analysis?.waveform.duration ?? 0, specifier: "%.1f") s")
            }
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SpectrumCard: View {
    var title: String
    var analysis: AudioAnalysis?
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            SpectrumView(points: analysis?.spectrum ?? [], palette: palette)
                .frame(height: 120)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DecayCard: View {
    var title: String
    var analysis: AudioAnalysis?
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            DecayView(values: analysis?.decay ?? [], palette: palette)
                .frame(height: 120)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WaveformView: View {
    var peaks: [Double]
    var palette: Palette

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else {
                context.draw(Text("No audio").foregroundColor(palette.secondaryText), at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            let mid = size.height / 2
            let step = size.width / CGFloat(max(peaks.count - 1, 1))
            var path = Path()
            for (index, peak) in peaks.enumerated() {
                let x = CGFloat(index) * step
                let y = CGFloat(min(max(peak, 0), 1)) * mid
                path.move(to: CGPoint(x: x, y: mid - y))
                path.addLine(to: CGPoint(x: x, y: mid + y))
            }
            context.stroke(path, with: .color(palette.accent), lineWidth: 1)
        }
    }
}

private struct SpectrumView: View {
    var points: [FrequencyPoint]
    var palette: Palette

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let minDB = -90.0
            let maxDB = 12.0
            var path = Path()
            for (index, point) in points.enumerated() {
                let x = CGFloat(index) / CGFloat(points.count - 1) * size.width
                let normalized = (point.magnitudeDB - minDB) / (maxDB - minDB)
                let y = size.height * (1 - CGFloat(min(max(normalized, 0), 1)))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(palette.accent), lineWidth: 2)
        }
    }
}

private struct DecayView: View {
    var values: [Double]
    var palette: Palette

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let y = size.height * (1 - CGFloat((value + 90) / 90).clamped(to: 0...1))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(palette.accent), lineWidth: 2)
        }
    }
}

private struct MeterRow: View {
    var title: String
    var analysis: AudioAnalysis?
    var palette: Palette

    var body: some View {
        HStack {
            Text(title).frame(width: 110, alignment: .leading)
            ProgressView(value: min(analysis?.waveform.peak ?? 0, 1))
                .progressViewStyle(.linear)
            Text("\(analysis?.waveform.peak ?? 0, specifier: "%.2f")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    var palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? palette.accent.opacity(0.75) : palette.accent, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    var palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? palette.panel.opacity(0.6) : palette.panel, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(palette.primaryText)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
