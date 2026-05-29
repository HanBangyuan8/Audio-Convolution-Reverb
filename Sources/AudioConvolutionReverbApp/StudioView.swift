import AudioConvolutionReverbCore
import SwiftUI

struct StudioView: View {
    @StateObject private var model = StudioViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.11), Color(red: 0.12, green: 0.13, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Divider().overlay(.white.opacity(0.08))
                mainPanel
            }
        }
        .foregroundStyle(.white)
        .onReceive(NotificationCenter.default.publisher(for: .renderRequested)) { _ in
            model.render()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Audio Convolution")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Reverb Studio")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
            }

            statGrid

            Text("Presets")
                .font(.headline)
                .padding(.top, 8)

            ForEach(model.presets) { preset in
                Button {
                    model.applyPreset(preset)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name).font(.subheadline.weight(.semibold))
                            Text("Wet \(preset.settings.wetLevel, specifier: "%.2f")  Dry \(preset.settings.dryLevel, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text("Recent Renders")
                .font(.headline)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.renders) { render in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(render.name)
                                .font(.caption.weight(.semibold))
                            Text("\(render.sampleRate) Hz · \(render.duration, specifier: "%.1f") s")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }

            Spacer()
            Text(model.status)
                .font(.caption)
                .foregroundStyle(model.isRendering ? .cyan : .white.opacity(0.72))
                .lineLimit(3)
        }
        .padding(24)
        .frame(width: 310)
        .background(.black.opacity(0.28))
    }

    private var statGrid: some View {
        HStack(spacing: 10) {
            StatTile(title: "History", value: "\(model.renders.count)")
            StatTile(title: "Presets", value: "\(model.presets.count)")
        }
    }

    private var mainPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                filePanel
                settingsPanel
                customImpulsePanel
                actionPanel
            }
            .padding(30)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Design a space, capture a space, or invent a new one.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("SwiftUI front end, Swift FFT convolution engine, SQLite render history, and the original notebook algorithm preserved in the Python CLI.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 4)
    }

    private var filePanel: some View {
        StudioSection(title: "Session") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                FileRow(title: "Dry Audio", value: model.dryURL?.path(percentEncoded: false) ?? "No file selected", icon: "waveform", action: model.chooseDryAudio)
                FileRow(title: "Impulse Response", value: model.impulseURL?.path(percentEncoded: false) ?? "No IR selected", icon: "dot.radiowaves.left.and.right", action: model.chooseImpulse)
                FileRow(title: "Output", value: model.outputURL.path(percentEncoded: false), icon: "square.and.arrow.down", action: model.chooseOutput)
            }
        }
    }

    private var settingsPanel: some View {
        StudioSection(title: "Mix and Transform") {
            VStack(spacing: 16) {
                SliderRow(title: "Dry", value: $model.settings.dryLevel, range: 0...1, suffix: "")
                SliderRow(title: "Wet", value: $model.settings.wetLevel, range: 0...1, suffix: "")
                SliderRow(title: "Pre-delay", value: $model.settings.preDelayMilliseconds, range: 0...120, suffix: " ms")
                SliderRow(title: "Decay Shape", value: $model.settings.decayScale, range: 0.35...2.5, suffix: "x")
                SliderRow(title: "Low Cut", value: $model.settings.lowCutHz, range: 0...800, suffix: " Hz")
                SliderRow(title: "High Cut", value: $model.settings.highCutHz, range: 2_000...20_000, suffix: " Hz")
                Toggle("Reverse impulse bloom", isOn: $model.settings.reverseImpulse)
                Toggle("Normalize output", isOn: $model.settings.normalizeOutput)
            }
        }
    }

    private var customImpulsePanel: some View {
        StudioSection(title: "Custom Convolution Reverb") {
            VStack(spacing: 16) {
                SliderRow(title: "IR Duration", value: $model.customDuration, range: 0.3...8, suffix: " s")
                SliderRow(title: "Decay", value: $model.customDecay, range: 0.5...9, suffix: "")
                SliderRow(title: "Tone", value: $model.customTone, range: 0...1, suffix: "")
                SliderRow(title: "Early Reflections", value: $model.customReflections, range: 0...28, suffix: "")
                Button {
                    model.generateCustomImpulse()
                } label: {
                    Label("Generate Custom IR", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var actionPanel: some View {
        HStack(spacing: 14) {
            Button(action: model.render) {
                Label(model.isRendering ? "Rendering..." : "Render Reverb", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isRendering)

            Button(action: model.saveCurrentPreset) {
                Label("Save Preset", systemImage: "bookmark")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: model.openOutputFolder) {
                Label("Reveal Output", systemImage: "folder")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.top, 4)
    }
}

private struct StudioSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            content
        }
        .padding(20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08)))
    }
}

private struct FileRow: View {
    var title: String
    var value: String
    var icon: String
    var action: () -> Void

    var body: some View {
        GridRow {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(width: 180, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Choose", action: action)
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

private struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var suffix: String

    var body: some View {
        HStack(spacing: 14) {
            Text(title).frame(width: 140, alignment: .leading)
            Slider(value: $value, in: range)
            Text("\(value, specifier: "%.2f")\(suffix)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 82, alignment: .trailing)
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(configuration.isPressed ? Color.cyan.opacity(0.75) : Color.cyan, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.black)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? .white.opacity(0.16) : .white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }
}
