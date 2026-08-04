import AppKit
import AudioConvolutionReverbCore
import Charts
import SwiftUI
import UniformTypeIdentifiers

enum MotionIntensity: String, CaseIterable, Identifiable {
    case enhanced
    case reduced
    case none

    var id: String { rawValue }
}
struct AccentColorOption: Identifiable, Hashable {
    let id: String
    let englishName: String
    let color: Color

    static let all: [AccentColorOption] = [
        AccentColorOption(id: "red", englishName: "Red", color: Color(red: 0.90, green: 0.24, blue: 0.28)),
        AccentColorOption(id: "orange", englishName: "Orange", color: Color(red: 0.94, green: 0.48, blue: 0.16)),
        AccentColorOption(id: "yellow", englishName: "Yellow", color: Color(red: 0.90, green: 0.72, blue: 0.18)),
        AccentColorOption(id: "green", englishName: "Green", color: Color(red: 0.22, green: 0.70, blue: 0.38)),
        AccentColorOption(id: "cyan", englishName: "Cyan", color: Color(red: 0.10, green: 0.70, blue: 0.76)),
        AccentColorOption(id: "blue", englishName: "Blue", color: Color(red: 0.20, green: 0.48, blue: 0.92)),
        AccentColorOption(id: "purple", englishName: "Purple", color: Color(red: 0.56, green: 0.34, blue: 0.88)),
        AccentColorOption(id: "pink", englishName: "Pink", color: Color(red: 0.92, green: 0.34, blue: 0.62)),
        AccentColorOption(id: "rose", englishName: "Rose", color: Color(red: 0.86, green: 0.30, blue: 0.42)),
        AccentColorOption(id: "amber", englishName: "Amber", color: Color(red: 0.96, green: 0.58, blue: 0.18)),
        AccentColorOption(id: "lime", englishName: "Lime", color: Color(red: 0.54, green: 0.76, blue: 0.22)),
        AccentColorOption(id: "mint", englishName: "Mint", color: Color(red: 0.18, green: 0.72, blue: 0.56)),
        AccentColorOption(id: "teal", englishName: "Teal", color: Color(red: 0.12, green: 0.58, blue: 0.70)),
        AccentColorOption(id: "indigo", englishName: "Indigo", color: Color(red: 0.36, green: 0.38, blue: 0.86)),
        AccentColorOption(id: "darkGray", englishName: "Dark Gray", color: Color(red: 0.36, green: 0.38, blue: 0.43)),
        AccentColorOption(id: "lightGray", englishName: "Light Gray", color: Color(red: 0.72, green: 0.74, blue: 0.78))
    ]

    static func option(for id: String) -> AccentColorOption {
        all.first { $0.id == id } ?? all[6]
    }
}

@available(macOS 12.0, *)
struct AccentColorPicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 16), spacing: 7), count: 8)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(AccentColorOption.all) { option in
                Button {
                    withAnimation(reduceMotion ? nil : MotionTokens.color) {
                        selection = option.id
                    }
                } label: {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(option.color)
                            .frame(height: 14)
                            .overlay {
                                if selection == option.id {
                                    Capsule(style: .continuous)
                                        .strokeBorder(.primary.opacity(0.9), lineWidth: 1.5)
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(.white.opacity(0.9), lineWidth: 0.8)
                                        }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .accessibilityLabel(option.englishName)
                }
                .buttonStyle(LightweightPressButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(macOS 12.0, *)
struct SidebarStatusRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            content
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@available(macOS 12.0, *)
struct StatCard: View {
    let title: String
    let value: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(title)
                .font((compact ? Font.footnote : Font.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: compact ? 20 : 23, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 14 : 18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .gentleAppear()
    }
}

@available(macOS 12.0, *)
struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if title.isEmpty {
                Spacer(minLength: 0)
                    .frame(width: 160)
            } else {
                Text(title)
                    .frame(width: 160, alignment: .leading)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleTint(_ color: Color) -> some View {
        if #available(macOS 13.0, *) {
            tint(color)
        } else {
            accentColor(color)
        }
    }
}

struct StudioView: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                ReverbNativeContentView(model: model)
            } else {
                ReverbCompatibilityContentView(model: model)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .renderRequested)) { _ in
            model.render()
        }
    }
}

@available(macOS 13.0, *)
private struct ReverbNativeContentView: View {
    @ObservedObject var model: StudioViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"
    @State private var selectedSidebarPage = "overview"
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var motionIntensity: MotionIntensity { MotionIntensity(rawValue: motionIntensityID) ?? .enhanced }
    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }
    private var profile: VersionedMotionProfile { VersionedMotionProfile(runtimeProfile: .current, intensity: motionIntensity) }
    private var interfaceAnimation: Animation? { reduceMotion || motionIntensity == .none ? nil : profile.pageSwitchAnimation }
    private var pageOrder: [String] { ["overview", "workspace"] + model.presets.map { "preset:\($0.id)" } + model.renders.map { "render:\($0.id)" } }

    var body: some View {
        NavigationSplitView {
            ReverbSidebar(
                model: model,
                selectedPage: $selectedSidebarPage,
                motionIntensityID: $motionIntensityID,
                accentColorID: $accentColorID,
                nativeNavigation: true,
                profile: profile,
                onSelectPage: selectPage
            )
            .navigationTitle("Audio Convolution Reverb")
            .navigationSplitViewColumnWidth(min: 248, ideal: 272, max: 330)
        } detail: {
            ReverbDetailRouter(
                model: model,
                selectedPage: selectedSidebarPage,
                navigationDirection: navigationDirection,
                profile: profile,
                accentColor: accentColor,
                showsInlineActions: false
            )
            .navigationTitle("Convolution Reverb")
        }
        .frame(minWidth: 1100, minHeight: 820)
        .tint(accentColor)
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
        .versionedStartupMotion(profile: profile)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.isRendering ? model.cancelRender() : model.render()
                } label: {
                    Label(model.isRendering ? "Cancel Render" : "Render", systemImage: model.isRendering ? "xmark" : "waveform.badge.plus")
                }
                .disabled(!model.isRendering && !canProcess)
                .help(model.isRendering ? "Cancel the current render" : "Render the complete output")

                Button(action: model.renderPreview) {
                    Label("Preview", systemImage: "play.fill")
                }
                .disabled(model.isRendering || !canProcess)
                .help("Render and audition a short preview")

                Menu {
                    Button("Save Current Preset", action: model.saveCurrentPreset)
                    Button("Reveal Output Folder", action: model.openOutputFolder)
                } label: {
                    Label("More Actions", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private func selectPage(_ page: String) {
        guard page != selectedSidebarPage else { return }
        let currentIndex = pageOrder.firstIndex(of: selectedSidebarPage) ?? 0
        let nextIndex = pageOrder.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        selectedSidebarPage = page
    }

    private var canProcess: Bool {
        model.dryURL != nil && model.impulseURL != nil
    }
}

private struct ReverbCompatibilityContentView: View {
    @ObservedObject var model: StudioViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"
    @State private var selectedSidebarPage = "overview"
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var motionIntensity: MotionIntensity { MotionIntensity(rawValue: motionIntensityID) ?? .enhanced }
    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }
    private var profile: VersionedMotionProfile { VersionedMotionProfile(runtimeProfile: .current, intensity: motionIntensity) }
    private var interfaceAnimation: Animation? { reduceMotion || motionIntensity == .none ? nil : profile.pageSwitchAnimation }
    private var pageOrder: [String] { ["overview", "workspace"] + model.presets.map { "preset:\($0.id)" } + model.renders.map { "render:\($0.id)" } }

    var body: some View {
        HStack(spacing: 0) {
            ReverbSidebar(
                model: model,
                selectedPage: $selectedSidebarPage,
                motionIntensityID: $motionIntensityID,
                accentColorID: $accentColorID,
                nativeNavigation: false,
                profile: profile,
                onSelectPage: selectPage
            )
            .frame(width: 238)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.82))

            Divider()

            ReverbDetailRouter(
                model: model,
                selectedPage: selectedSidebarPage,
                navigationDirection: navigationDirection,
                profile: profile,
                accentColor: accentColor,
                showsInlineActions: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1010, minHeight: 820)
        .compatibleTint(accentColor)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.98),
                    Color(NSColor.controlBackgroundColor).opacity(0.88)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
        .versionedStartupMotion(profile: profile)
    }

    private func selectPage(_ page: String) {
        guard page != selectedSidebarPage else { return }
        let currentIndex = pageOrder.firstIndex(of: selectedSidebarPage) ?? 0
        let nextIndex = pageOrder.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        selectedSidebarPage = page
    }
}

private struct ReverbSidebar: View {
    @ObservedObject var model: StudioViewModel
    @Binding var selectedPage: String
    @Binding var motionIntensityID: String
    @Binding var accentColorID: String
    let nativeNavigation: Bool
    let profile: VersionedMotionProfile
    let onSelectPage: (String) -> Void

    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }

    var body: some View {
        List {
            Section("Motion") {
                Picker("", selection: $motionIntensityID) {
                    Text("Enhanced").tag(MotionIntensity.enhanced.rawValue)
                    Text("Reduced").tag(MotionIntensity.reduced.rawValue)
                    Text("Off").tag(MotionIntensity.none.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section("Accent Color") {
                AccentColorPicker(selection: $accentColorID)
            }

            Section("Studio") {
                pageButton("Overview", systemImage: "rectangle.stack", page: "overview")
                pageButton("Workspace", systemImage: "slider.horizontal.3", page: "workspace")
            }

            Section("Presets") {
                ForEach(model.presets) { preset in
                    let page = "preset:\(preset.id)"
                    Button {
                        model.applyPreset(preset)
                        onSelectPage(page)
                    } label: {
                        selectionLabel(preset.name, systemImage: "slider.horizontal.3", page: page)
                    }
                    .buttonStyle(pageStyle(selected: selectedPage == page))
                    .contextMenu {
                        Button("Rename") { model.renamePreset(preset) }
                        Button("Delete", role: .destructive) { model.deletePreset(preset) }
                    }
                }
            }

            Section("Recent Renders") {
                TextField("Search", text: $model.renderSearch)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.renderSearch) { _ in model.refresh() }

                ForEach(model.renders) { render in
                    let page = "render:\(render.id)"
                    Button {
                        model.reopenRender(render)
                        onSelectPage(page)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(render.name).lineLimit(1)
                                Text("\(render.sampleRate) Hz · \(render.duration, specifier: "%.1f") s")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedPage == page { Image(systemName: "checkmark") }
                        }
                    }
                    .buttonStyle(pageStyle(selected: selectedPage == page))
                    .contextMenu {
                        Button("Reveal in Finder") { model.revealRender(render) }
                        Button("Rename") { model.renameRender(render) }
                        Button("Delete", role: .destructive) { model.deleteRender(render) }
                    }
                }
            }

            Section("Status") {
                SidebarStatusRow(title: "Render") { Text(model.isRendering ? "Running" : "Ready") }
                SidebarStatusRow(title: "Playback") { Text(model.isPlaying ? "Playing" : "Stopped") }
                SidebarStatusRow(title: "Renders") { Text("\(model.renders.count)").monospacedDigit() }
                if model.isRendering { ProgressView(value: model.renderProgress).progressViewStyle(.linear) }
                Text(model.status).font(.footnote).foregroundStyle(model.isRendering ? accentColor : .secondary).lineLimit(3)
            }
        }
        .listStyle(.sidebar)
    }

    private func pageButton(_ title: String, systemImage: String, page: String) -> some View {
        Button { onSelectPage(page) } label: { selectionLabel(title, systemImage: systemImage, page: page) }
            .buttonStyle(pageStyle(selected: selectedPage == page))
    }

    private func selectionLabel(_ title: String, systemImage: String, page: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).lineLimit(1)
            Spacer()
            if selectedPage == page { Image(systemName: "checkmark") }
        }
    }

    private func pageStyle(selected: Bool) -> AnyButtonStyle {
        if nativeNavigation {
            return AnyButtonStyle(VersionedPagePressButtonStyle(isSelected: selected, accentColor: accentColor, profile: profile))
        }
        return AnyButtonStyle(Legacy15SidebarButtonStyle(isSelected: selected, accentColor: accentColor))
    }

}

private struct ReverbDetailRouter: View {
    @ObservedObject var model: StudioViewModel
    let selectedPage: String
    let navigationDirection: PageNavigationDirection
    let profile: VersionedMotionProfile
    let accentColor: Color
    let showsInlineActions: Bool

    var body: some View {
        let isWorkspace = selectedPage == "workspace" || selectedPage.hasPrefix("preset:")
        VStack(spacing: 0) {
            if showsInlineActions {
                ReverbActionStrip(model: model, accentColor: accentColor)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            GeometryReader { geometry in
                ZStack {
                    ReverbWorkspacePage(
                        model: model,
                        profile: profile,
                        accentColor: accentColor,
                        pageID: selectedPage,
                        navigationDirection: navigationDirection
                    )
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .coordinateSpace(name: "detailScroll")
                    .versionedPersistentPageMotion(
                        profile: profile,
                        isSelected: isWorkspace,
                        direction: navigationDirection,
                        pageID: selectedPage,
                        scalesContent: false
                    )

                    ReverbOverviewPage(
                        model: model,
                        pageID: selectedPage,
                        navigationDirection: navigationDirection,
                        profile: profile,
                        accentColor: accentColor,
                        availableWidth: geometry.size.width,
                        availableHeight: geometry.size.height
                    )
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .coordinateSpace(name: "detailScroll")
                    .versionedPersistentPageMotion(
                        profile: profile,
                        isSelected: !isWorkspace,
                        direction: navigationDirection,
                        pageID: selectedPage
                    )
                }
            }
        }
    }
}

private struct ReverbActionStrip: View {
    @ObservedObject var model: StudioViewModel
    let accentColor: Color

    private var canProcess: Bool {
        model.dryURL != nil && model.impulseURL != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.isRendering ? model.cancelRender() : model.render()
            } label: {
                Label(model.isRendering ? "Cancel Render" : "Render", systemImage: model.isRendering ? "xmark" : "waveform.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isRendering && !canProcess)

            Button(action: model.renderPreview) {
                Label("Preview", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .disabled(model.isRendering || !canProcess)

            Menu {
                Button("Save Current Preset", action: model.saveCurrentPreset)
                Button("Reveal Output Folder", action: model.openOutputFolder)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }

            Spacer(minLength: 12)

            if model.isRendering {
                ProgressView(value: model.renderProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
            }
            Text(model.status)
                .font(.footnote)
                .foregroundStyle(model.isRendering ? accentColor : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .compatibleTint(accentColor)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .interactivePanel(cornerRadius: 14, accentColor: accentColor)
    }
}

private struct ReverbOverviewPage: View {
    @ObservedObject var model: StudioViewModel
    let pageID: String
    let navigationDirection: PageNavigationDirection
    let profile: VersionedMotionProfile
    let accentColor: Color
    var availableWidth: CGFloat? = nil
    var availableHeight: CGFloat? = nil

    var body: some View {
        let contentWidth = max(0, (availableWidth ?? 0) - 40)
        let statCardWidth = max(120, (contentWidth - 48) / 5)
        VStack(alignment: .leading, spacing: 12) {
            Text(pageID.hasPrefix("render:") ? (model.renderedURL?.lastPathComponent ?? "Render") : "Studio Overview")
                .font(.title2.bold())
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)

            HStack(spacing: 12) {
                StatCard(title: "Renders", value: "\(model.renders.count)", compact: true).frame(width: statCardWidth)
                StatCard(title: "Presets", value: "\(model.presets.count)", compact: true).frame(width: statCardWidth)
                StatCard(title: "Dry Duration", value: duration(model.dryAnalysis), compact: true).frame(width: statCardWidth)
                StatCard(title: "IR Duration", value: duration(model.impulseAnalysis), compact: true).frame(width: statCardWidth)
                StatCard(title: "Output Duration", value: duration(model.renderedAnalysis), compact: true).frame(width: statCardWidth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)

            Text("Session Files").font(.title3.bold())
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)
            ReverbSessionFiles(model: model)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .interactivePanel(cornerRadius: 16, accentColor: accentColor)
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)

            Text("Playback and A/B").font(.title3.bold())
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)
            ReverbPlayback(model: model)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .interactivePanel(cornerRadius: 16, accentColor: accentColor)
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)

            Text("Audio Analysis").font(.title3.bold())
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)
            ReverbAnalysisGrid(
                model: model,
                accentColor: accentColor,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection, isChart: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func duration(_ analysis: AudioAnalysis?) -> String {
        analysis.map { String(format: "%.1f s", $0.waveform.duration) } ?? "--"
    }
}

private struct ReverbSessionFiles: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        VStack(spacing: 10) {
            fileRow("Dry Audio", value: model.dryURL?.path ?? "No file selected", icon: "waveform", action: model.chooseDryAudio)
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { model.acceptDrop($0, target: .dry) }
            fileRow("Impulse Response", value: model.impulseURL?.path ?? "No file selected", icon: "dot.radiowaves.left.and.right", action: model.chooseImpulse)
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { model.acceptDrop($0, target: .impulse) }
            fileRow("Output", value: model.outputURL.path, icon: "square.and.arrow.down", action: model.chooseOutput)
            SettingsRow(title: "Format") {
                Picker("Format", selection: $model.exportFormat) {
                    ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
        }
    }

    private func fileRow(_ title: String, value: String, icon: String, action: @escaping () -> Void) -> some View {
        SettingsRow(title: title) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 10)
                Button("Choose", action: action)
            }
        }
    }
}

private struct ReverbPlayback: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        VStack(spacing: 10) {
            SettingsRow(title: "Target") {
                HStack(spacing: 10) {
                    Picker("Target", selection: $model.playbackTarget) {
                        ForEach(PlaybackTarget.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    Button(model.isPlaying ? "Restart" : "Play", action: model.playSelected)
                    Button("Stop", action: model.stopPlayback)
                    Button("A/B", action: model.abToggle)
                }
            }
            SettingsRow(title: "Preview Length") {
                HStack {
                    Slider(value: $model.previewSeconds, in: 2...30)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    Text("\(model.previewSeconds, specifier: "%.1f") s").monospacedDigit().frame(width: 72, alignment: .trailing)
                }
            }
        }
    }
}

private struct ReverbWorkspacePage: View {
    @ObservedObject var model: StudioViewModel
    let profile: VersionedMotionProfile
    let accentColor: Color
    let pageID: String
    let navigationDirection: PageNavigationDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reverb Workspace").font(.title2.bold())
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)
            VStack(alignment: .leading, spacing: 8) {
                settingsSection("Mix and Transform", index: 0) { mixRows }
                settingsSection("Professional Controls", index: 1) { professionalRows }
                settingsSection("Custom Impulse Response", index: 2) { customRows }
            }
            .versionedComponentAppear(profile: profile, pageID: pageID, direction: navigationDirection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func settingsSection<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { content() }
                .settingsSolidCard(accentColor: accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggeredGroupAppear(index: index)
    }

    private var mixRows: some View {
        Group {
            sliderRow("Dry Level", value: $model.settings.dryLevel, range: 0...1)
            sliderRow("Wet Level", value: $model.settings.wetLevel, range: 0...1)
            sliderRow("Pre-delay", value: $model.settings.preDelayMilliseconds, range: 0...160, suffix: " ms")
            sliderRow("Decay Scale", value: $model.settings.decayScale, range: 0.25...3, suffix: "x")
            sliderRow("Low Cut", value: $model.settings.lowCutHz, range: 0...1_200, suffix: " Hz")
            sliderRow("High Cut", value: $model.settings.highCutHz, range: 2_000...22_000, suffix: " Hz")
            SettingsRow(title: "") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                    Toggle("Reverse impulse", isOn: $model.settings.reverseImpulse)
                    Toggle("Normalize output", isOn: $model.settings.normalizeOutput)
                    Toggle("Normalize wet signal", isOn: $model.settings.normalizeWetSignal)
                }
            }
        }
    }

    private var professionalRows: some View {
        Group {
            sliderRow("Input Gain", value: $model.settings.inputGainDB, range: -24...24, suffix: " dB")
            sliderRow("Output Gain", value: $model.settings.outputGainDB, range: -24...24, suffix: " dB")
            sliderRow("IR Trim Start", value: $model.settings.impulseTrimStartMilliseconds, range: 0...500, suffix: " ms")
            sliderRow("IR Trim End", value: $model.settings.impulseTrimEndMilliseconds, range: 0...1_000, suffix: " ms")
            sliderRow("Fade In", value: $model.settings.fadeInMilliseconds, range: 0...250, suffix: " ms")
            sliderRow("Fade Out", value: $model.settings.fadeOutMilliseconds, range: 0...1_000, suffix: " ms")
            sliderRow("Stereo Width", value: $model.settings.stereoWidth, range: 0...2, suffix: "x")
            sliderRow("Tail Length", value: $model.settings.tailLengthSeconds, range: 0...12, suffix: " s")
            sliderRow("Latency Compensation", value: $model.settings.latencyCompensationMilliseconds, range: -120...120, suffix: " ms")
        }
    }

    private var customRows: some View {
        Group {
            sliderRow("IR Duration", value: $model.customDuration, range: 0.3...10, suffix: " s")
            sliderRow("Decay", value: $model.customDecay, range: 0.5...10)
            sliderRow("Tone", value: $model.customTone, range: 0...1)
            sliderRow("Early Reflections", value: $model.customReflections, range: 0...40)
            SettingsRow(title: "") {
                Button("Generate Custom IR", action: model.generateCustomImpulse)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "") -> some View {
        SettingsRow(title: title) {
            HStack {
                Slider(value: value, in: range)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                Text("\(value.wrappedValue, specifier: "%.2f")\(suffix)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 96, alignment: .trailing)
            }
        }
    }
}

private struct ReverbAnalysisGrid: View {
    @ObservedObject var model: StudioViewModel
    let accentColor: Color
    var availableWidth: CGFloat? = nil
    var availableHeight: CGFloat? = nil
    @State private var bottomChartHeight: CGFloat = 120

    var body: some View {
        let contentWidth = max(0, (availableWidth ?? 0) - 40)
        let analysisCardWidth = max(190, (contentWidth - 24) / 3)
        let chartCardWidth = max(260, (contentWidth - 12) / 2)
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ReverbAnalysisCard(title: "Dry", analysis: model.dryAnalysis, accentColor: accentColor).frame(width: analysisCardWidth)
                ReverbAnalysisCard(title: "Impulse", analysis: model.impulseAnalysis, accentColor: accentColor).frame(width: analysisCardWidth)
                ReverbAnalysisCard(title: "Rendered", analysis: model.renderedAnalysis, accentColor: accentColor).frame(width: analysisCardWidth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ReverbSpectrumCard(analysis: model.impulseAnalysis, accentColor: accentColor, height: bottomChartHeight).frame(width: chartCardWidth)
                ReverbDecayCard(analysis: model.impulseAnalysis, accentColor: accentColor, height: bottomChartHeight).frame(width: chartCardWidth)
            }
            .frame(maxWidth: .infinity, minHeight: bottomChartHeight, maxHeight: bottomChartHeight, alignment: .topLeading)
            .background {
                GeometryReader { geometry in
                    let minY = geometry.frame(in: .named("detailScroll")).minY
                    Color.clear
                        .onAppear {
                            updateBottomChartHeight(from: minY)
                        }
                        .onChange(of: minY) { nextMinY in
                            updateBottomChartHeight(from: nextMinY)
                        }
                        .onChange(of: availableHeight ?? 0) { _ in
                            updateBottomChartHeight(from: minY)
                        }
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func updateBottomChartHeight(from minY: CGFloat) {
        guard let availableHeight else { return }
        let bottomPadding: CGFloat = 28
        let nextHeight = max(92, availableHeight - minY - bottomPadding)
        guard abs(bottomChartHeight - nextHeight) > 0.5 else { return }
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                bottomChartHeight = nextHeight
            }
        }
    }
}

private struct ReverbAnalysisCard: View {
    let title: String
    let analysis: AudioAnalysis?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ReverbWaveformPlot(values: analysis?.waveform.peaks ?? [], accentColor: accentColor).frame(height: 82)
            HStack {
                Text("Peak \(analysis?.waveform.peak ?? 0, specifier: "%.2f")")
                Spacer()
                Text("RMS \(analysis?.waveform.rms ?? 0, specifier: "%.2f")")
                Spacer()
                Text("\(analysis?.waveform.duration ?? 0, specifier: "%.1f") s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .interactivePanel(cornerRadius: 16, accentColor: accentColor)
    }
}

private struct ReverbSpectrumCard: View {
    let analysis: AudioAnalysis?
    let accentColor: Color
    let height: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IR Frequency Response").font(.headline)
            ReverbSpectrumPlot(points: analysis?.spectrum ?? [], accentColor: accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .interactivePanel(cornerRadius: 16, accentColor: accentColor)
    }
}

private struct ReverbDecayCard: View {
    let analysis: AudioAnalysis?
    let accentColor: Color
    let height: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IR Energy Decay").font(.headline)
            ReverbDecayPlot(values: analysis?.decay ?? [], accentColor: accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .interactivePanel(cornerRadius: 16, accentColor: accentColor)
    }
}

private struct ReverbWaveformPlot: View {
    let values: [Double]
    let accentColor: Color
    @ViewBuilder var body: some View {
        if #available(macOS 13.0, *) { NativeSeriesChart(values: values, accentColor: accentColor, area: true) }
        else { LegacySeriesPlot(values: values, accentColor: accentColor, minimum: 0, maximum: 1) }
    }
}

private struct ReverbSpectrumPlot: View {
    let points: [FrequencyPoint]
    let accentColor: Color
    @ViewBuilder var body: some View {
        if #available(macOS 13.0, *) { NativeSpectrumChart(points: points, accentColor: accentColor) }
        else { LegacySeriesPlot(values: points.map(\.magnitudeDB), accentColor: accentColor, minimum: -90, maximum: 12) }
    }
}

private struct ReverbDecayPlot: View {
    let values: [Double]
    let accentColor: Color
    @ViewBuilder var body: some View {
        if #available(macOS 13.0, *) { NativeSeriesChart(values: values, accentColor: accentColor, area: true) }
        else { LegacySeriesPlot(values: values, accentColor: accentColor, minimum: -90, maximum: 0) }
    }
}

@available(macOS 13.0, *)
private struct NativeSeriesChart: View {
    let values: [Double]
    let accentColor: Color
    let area: Bool
    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { point in
            if area { AreaMark(x: .value("Index", point.offset), y: .value("Value", point.element)).foregroundStyle(accentColor.opacity(0.16)) }
            LineMark(x: .value("Index", point.offset), y: .value("Value", point.element)).foregroundStyle(accentColor)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

@available(macOS 13.0, *)
private struct NativeSpectrumChart: View {
    let points: [FrequencyPoint]
    let accentColor: Color
    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { point in
            LineMark(x: .value("Frequency", point.element.frequency), y: .value("dB", point.element.magnitudeDB)).foregroundStyle(accentColor)
        }
        .chartXScale(type: .log)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct LegacySeriesPlot: View {
    let values: [Double]
    let accentColor: Color
    let minimum: Double
    let maximum: Double

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                context.draw(Text("No data").foregroundColor(.secondary), at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let normalized = min(max((value - minimum) / max(maximum - minimum, 0.0001), 0), 1)
                let y = size.height * (1 - CGFloat(normalized))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(accentColor), lineWidth: 2)
        }
    }
}

extension Notification.Name {
    static let renderRequested = Notification.Name("AudioConvolutionReverb.renderRequested")
}

@MainActor
final class ReverbAppDelegate: NSObject, NSApplicationDelegate {
    private let model = StudioViewModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        if window == nil {
            buildMainWindow()
            return
        }
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMainWindow() {
        let hostingController = NSHostingController(rootView: StudioView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1010, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Audio Convolution Reverb"
        window.contentMinSize = NSSize(width: 1010, height: 820)
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
