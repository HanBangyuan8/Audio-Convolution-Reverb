import AudioConvolutionReverbCore
import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = StudioViewModel()

    private var palette: Palette { Palette(colorScheme) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            mainPanel
        }
        .navigationSplitViewStyle(.balanced)
        .background(palette.background)
        .foregroundStyle(palette.primaryText)
        .onReceive(NotificationCenter.default.publisher(for: .renderRequested)) { _ in
            model.render()
        }
    }

    private var sidebar: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Convolution Reverb")
                        .font(.headline)
                    Text("Audio Engineering Studio")
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                }
                .padding(.vertical, 6)
            }

            Section("Library") {
                Label("\(model.renders.count) renders", systemImage: "clock")
                Label("\(model.presets.count) presets", systemImage: "slider.horizontal.3")
            }

            Section {
                TextField("Search renders", text: $model.renderSearch)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.renderSearch) { _ in model.refresh() }
            }

            Section {
                ForEach(model.presets) { preset in
                    Button { model.applyPreset(preset) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("Wet \(preset.settings.wetLevel, specifier: "%.2f") · Dry \(preset.settings.dryLevel, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(palette.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename") { model.renamePreset(preset) }
                        Button("Delete", role: .destructive) { model.deletePreset(preset) }
                    }
                }
            } header: {
                Text("Presets")
            }

            Section("Recent Renders") {
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

            Section {
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
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(palette.sidebar)
    }

    private var mainPanel: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 44
            let contentWidth = max(1, geometry.size.width - horizontalPadding)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear
                            .frame(height: 1)
                            .id("mainTop")
                        sessionHeader
                        filePanel(width: contentWidth)
                        transportPanel(width: contentWidth)
                        visualizationPanel(width: contentWidth)
                        settingsPanel(width: contentWidth)
                        professionalPanel(width: contentWidth)
                        customImpulsePanel(width: contentWidth)
                        actionPanel(width: contentWidth)
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, horizontalPadding / 2)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    for delay in [0.0, 0.15, 0.35] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            proxy.scrollTo("mainTop", anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private var sessionHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Studio Session")
                    .font(.title3.weight(.semibold))
                Text("Import, preview, visualize, and render convolution reverb.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Text(model.isRendering ? "Rendering" : "Ready")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(model.isRendering ? palette.accent.opacity(0.16) : palette.panel, in: Capsule())
                .foregroundStyle(model.isRendering ? palette.accent : palette.secondaryText)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private func transportPanel(width: CGFloat) -> some View {
        StudioSection(title: "Playback and A/B", palette: palette) {
            ViewThatFits(in: .horizontal) {
                transportControls
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        playbackPicker
                        playButton
                        stopButton
                        abButton
                    }
                    SliderRow(title: "Preview", value: $model.previewSeconds, range: 2...30, suffix: " s", palette: palette)
                }
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            playbackPicker
            playButton
            stopButton
            abButton
            Spacer(minLength: 14)
            SliderRow(title: "Preview", value: $model.previewSeconds, range: 2...30, suffix: " s", palette: palette)
                .frame(width: 300)
        }
    }

    private var playbackPicker: some View {
        HStack(spacing: 8) {
            Text("Target")
            Picker("Target", selection: $model.playbackTarget) {
                ForEach(PlaybackTarget.allCases) { target in
                    Text(target.rawValue).tag(target)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
    }

    private var playButton: some View {
        Button(action: model.playSelected) {
            Label(model.isPlaying ? "Restart" : "Play", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle(palette: palette))
        .frame(width: 96)
    }

    private var stopButton: some View {
        Button(action: model.stopPlayback) {
            Label("Stop", systemImage: "stop.fill")
        }
        .buttonStyle(SecondaryButtonStyle(palette: palette))
        .frame(width: 82)
    }

    private var abButton: some View {
        Button(action: model.abToggle) {
            Label("A/B", systemImage: "arrow.left.arrow.right")
        }
        .buttonStyle(SecondaryButtonStyle(palette: palette))
        .frame(width: 76)
    }

    private func filePanel(width: CGFloat) -> some View {
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

                FileDropRow(
                    title: "Output",
                    value: model.outputURL.path(percentEncoded: false),
                    icon: "square.and.arrow.down",
                    palette: palette,
                    action: model.chooseOutput
                )

                HStack {
                    Spacer()
                    Text("Format")
                    Picker("Format", selection: $model.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
            }
        }
    }

    private func visualizationPanel(width: CGFloat) -> some View {
        StudioSection(title: "Waveform, Spectrum, and Decay", palette: palette) {
            VStack(spacing: 14) {
                LazyVGrid(columns: adaptiveColumns(width: width, minimum: 260, maximumCount: 3), spacing: 14) {
                    AnalysisCard(title: "Dry", analysis: model.dryAnalysis, palette: palette)
                    AnalysisCard(title: "Impulse", analysis: model.impulseAnalysis, palette: palette)
                    AnalysisCard(title: "Rendered", analysis: model.renderedAnalysis, palette: palette)
                }
                LazyVGrid(columns: adaptiveColumns(width: width, minimum: 340, maximumCount: 2), spacing: 14) {
                    SpectrumCard(title: "IR Frequency Response", analysis: model.impulseAnalysis, palette: palette)
                    DecayCard(title: "IR Energy Decay", analysis: model.impulseAnalysis, palette: palette)
                }
            }
        }
    }

    private func settingsPanel(width: CGFloat) -> some View {
        StudioSection(title: "Mix and Transform", palette: palette) {
            LazyVGrid(columns: adaptiveColumns(width: width, minimum: 320, maximumCount: 2), spacing: 12) {
                SliderRow(title: "Dry", value: $model.settings.dryLevel, range: 0...1, suffix: "", palette: palette)
                SliderRow(title: "Wet", value: $model.settings.wetLevel, range: 0...1, suffix: "", palette: palette)
                SliderRow(title: "Pre-delay", value: $model.settings.preDelayMilliseconds, range: 0...160, suffix: " ms", palette: palette)
                SliderRow(title: "Decay", value: $model.settings.decayScale, range: 0.25...3, suffix: "x", palette: palette)
                SliderRow(title: "Low Cut", value: $model.settings.lowCutHz, range: 0...1_200, suffix: " Hz", palette: palette)
                SliderRow(title: "High Cut", value: $model.settings.highCutHz, range: 2_000...22_000, suffix: " Hz", palette: palette)
            }
            FlowLayout(spacing: 16) {
                Toggle("Reverse impulse bloom", isOn: $model.settings.reverseImpulse)
                Toggle("Normalize output", isOn: $model.settings.normalizeOutput)
                Toggle("Normalize wet signal", isOn: $model.settings.normalizeWetSignal)
            }
        }
    }

    private func professionalPanel(width: CGFloat) -> some View {
        StudioSection(title: "Professional Controls", palette: palette) {
            LazyVGrid(columns: adaptiveColumns(width: width, minimum: 320, maximumCount: 2), spacing: 12) {
                SliderRow(title: "Input Gain", value: $model.settings.inputGainDB, range: -24...24, suffix: " dB", palette: palette)
                SliderRow(title: "Output Gain", value: $model.settings.outputGainDB, range: -24...24, suffix: " dB", palette: palette)
                SliderRow(title: "IR Trim Start", value: $model.settings.impulseTrimStartMilliseconds, range: 0...500, suffix: " ms", palette: palette)
                SliderRow(title: "IR Trim End", value: $model.settings.impulseTrimEndMilliseconds, range: 0...1_000, suffix: " ms", palette: palette)
                SliderRow(title: "Fade In", value: $model.settings.fadeInMilliseconds, range: 0...250, suffix: " ms", palette: palette)
                SliderRow(title: "Fade Out", value: $model.settings.fadeOutMilliseconds, range: 0...1_000, suffix: " ms", palette: palette)
                SliderRow(title: "Stereo Width", value: $model.settings.stereoWidth, range: 0...2, suffix: "x", palette: palette)
                SliderRow(title: "Tail Length", value: $model.settings.tailLengthSeconds, range: 0...12, suffix: " s", palette: palette)
                SliderRow(title: "Latency Comp", value: $model.settings.latencyCompensationMilliseconds, range: -120...120, suffix: " ms", palette: palette)
            }
            MeterRow(title: "Dry Level", analysis: model.dryAnalysis, palette: palette)
            MeterRow(title: "Rendered Level", analysis: model.renderedAnalysis, palette: palette)
        }
    }

    private func customImpulsePanel(width: CGFloat) -> some View {
        StudioSection(title: "Custom Convolution Reverb", palette: palette) {
            LazyVGrid(columns: adaptiveColumns(width: width, minimum: 320, maximumCount: 2), spacing: 12) {
                SliderRow(title: "IR Duration", value: $model.customDuration, range: 0.3...10, suffix: " s", palette: palette)
                SliderRow(title: "Decay", value: $model.customDecay, range: 0.5...10, suffix: "", palette: palette)
                SliderRow(title: "Tone", value: $model.customTone, range: 0...1, suffix: "", palette: palette)
                SliderRow(title: "Reflections", value: $model.customReflections, range: 0...40, suffix: "", palette: palette)
            }
            Button { model.generateCustomImpulse() } label: {
                Label("Generate Custom IR", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
            .frame(width: 180, alignment: .leading)
        }
    }

    private func actionPanel(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button(action: model.renderPreview) {
                Label("Preview", systemImage: "bolt.fill")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .frame(width: 116)
            .disabled(model.isRendering)

            Button(action: model.render) {
                Label(model.isRendering ? "Rendering..." : "Render", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
            .frame(width: 116)
            .disabled(model.isRendering)

            Button(action: model.cancelRender) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .frame(width: 116)
            .disabled(!model.isRendering)

            Button(action: model.saveCurrentPreset) {
                Label("Save Preset", systemImage: "bookmark")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .frame(width: 132)

            Button(action: model.openOutputFolder) {
                Label("Reveal Output", systemImage: "folder")
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette))
            .frame(width: 132)

            Spacer()
        }
    }

    private func adaptiveColumns(width: CGFloat, minimum: CGFloat, maximumCount: Int) -> [GridItem] {
        let available = max(1, width - 56)
        let count = max(1, min(maximumCount, Int(available / minimum)))
        return Array(repeating: GridItem(.flexible(minimum: min(minimum, available), maximum: .infinity), spacing: 14), count: count)
    }
}

private struct Palette {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) {
        self.scheme = scheme
    }

    var background: Color { Color(nsColor: .windowBackgroundColor) }
    var sidebar: Color { Color(nsColor: .controlBackgroundColor) }
    var panel: Color { scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.035) }
    var panelStrong: Color { Color(nsColor: .controlBackgroundColor) }
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .padding(14)
        .background(palette.panelStrong, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke))
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(.subheadline.weight(.semibold))
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Button("Choose", action: action)
                .buttonStyle(SecondaryButtonStyle(palette: palette))
                .frame(width: 82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(palette.background, in: RoundedRectangle(cornerRadius: 7))
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).frame(width: 110, alignment: .leading)
                Slider(value: $value, in: range)
                valueLabel
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                    Spacer()
                    valueLabel
                }
                Slider(value: $value, in: range)
            }
        }
    }

    private var valueLabel: some View {
        Text("\(value, specifier: "%.2f")\(suffix)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(palette.secondaryText)
            .frame(width: 82, alignment: .trailing)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width + spacing }
        return layout(in: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, items: [(index: Int, origin: CGPoint, size: CGSize)]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        var items: [(Int, CGPoint, CGSize)] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: min(maxWidth, width), height: y + rowHeight), items)
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
                .frame(height: 54)
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
                .frame(height: 78)
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
                .frame(height: 78)
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
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).frame(width: 110, alignment: .leading)
                meter
                value
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                    Spacer()
                    value
                }
                meter
            }
        }
    }

    private var meter: some View {
        ProgressView(value: min(analysis?.waveform.peak ?? 0, 1))
            .progressViewStyle(.linear)
    }

    private var value: some View {
        Text("\(analysis?.waveform.peak ?? 0, specifier: "%.2f")")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(palette.secondaryText)
            .frame(width: 50, alignment: .trailing)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    var palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .padding(.horizontal, 10)
            .background(configuration.isPressed ? palette.accent.opacity(0.75) : palette.accent, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    var palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .padding(.horizontal, 10)
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
