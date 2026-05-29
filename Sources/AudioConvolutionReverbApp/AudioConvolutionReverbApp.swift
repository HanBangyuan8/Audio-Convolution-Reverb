import SwiftUI

@main
struct AudioConvolutionReverbApp: App {
    @State private var showingAbout = false

    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 900, minHeight: 560)
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Audio Convolution Reverb") {
                    showingAbout = true
                }
            }
            CommandGroup(after: .newItem) {
                Button("Render") {
                    NotificationCenter.default.post(name: .renderRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            PreferencesView()
        }
    }
}

extension Notification.Name {
    static let renderRequested = Notification.Name("AudioConvolutionReverb.renderRequested")
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 58))
                .foregroundStyle(.blue)
            Text("Audio Convolution Reverb")
                .font(.title.bold())
            Text("Version 1.1.0")
                .foregroundStyle(.secondary)
            Text("A native macOS audio engineering app for impulse response extraction, convolution reverb design, preview, visualization, and render management.")
                .multilineTextAlignment(.center)
                .frame(width: 420)
            Link("GitHub Repository", destination: URL(string: "https://github.com/HanBangyuan8/Audio-Convolution-Reverb")!)
        }
        .padding(34)
    }
}

private struct PreferencesView: View {
    @AppStorage("defaultPreviewSeconds") private var defaultPreviewSeconds = 8.0
    @AppStorage("autoRevealRenders") private var autoRevealRenders = false

    var body: some View {
        Form {
            Section("Preview") {
                Slider(value: $defaultPreviewSeconds, in: 2...30) {
                    Text("Default preview length")
                }
                Text("\(defaultPreviewSeconds, specifier: "%.0f") seconds")
                    .foregroundStyle(.secondary)
            }
            Section("Render") {
                Toggle("Reveal completed renders automatically", isOn: $autoRevealRenders)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
