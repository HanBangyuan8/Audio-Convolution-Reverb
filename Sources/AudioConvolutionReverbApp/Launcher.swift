import AppKit
import SwiftUI

private enum ReverbAppRuntime {
    static var delegate: ReverbAppDelegate?
}

@main
enum AudioConvolutionReverbLauncher {
    static func main() {
        let runtimePlan = RuntimeFeaturePlan.current
        if runtimePlan.usesSwiftUIAppLifecycle, #available(macOS 13.0, *) {
            NativeAudioConvolutionReverbApp.main()
        } else {
            MainActor.assumeIsolated {
                let app = NSApplication.shared
                let delegate = ReverbAppDelegate()
                ReverbAppRuntime.delegate = delegate
                app.delegate = delegate
                app.setActivationPolicy(.regular)
                app.run()
            }
        }
    }
}

@available(macOS 13.0, *)
struct NativeAudioConvolutionReverbApp: App {
    @StateObject private var model = StudioViewModel()

    var body: some Scene {
        WindowGroup {
            StudioView(model: model)
        }

        Settings {
            StudioView(model: model)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Audio Convolution Reverb") {
                    ReverbAboutPanelPresenter.show()
                }
            }
            CommandGroup(after: .newItem) {
                Button("Render") {
                    NotificationCenter.default.post(name: .renderRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

enum ReverbAboutPanelPresenter {
    @MainActor
    static func show() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let build = info?["CFBundleVersion"] as? String ?? "2"
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Audio Convolution Reverb",
            .applicationVersion: version,
            .version: build,
            .credits: NSAttributedString(
                string: "Native impulse-response extraction, convolution reverb design, preview, visualization, and render management.",
                attributes: [.font: NSFont.systemFont(ofSize: 12)]
            )
        ])
    }
}
