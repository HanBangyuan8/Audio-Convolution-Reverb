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
                .background(LaunchWindowSizeResetter(width: 1100, height: 820))
        }
        .defaultSize(width: 1100, height: 820)

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

@available(macOS 13.0, *)
private struct LaunchWindowSizeResetter: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> LaunchWindowSizingView {
        LaunchWindowSizingView(contentSize: NSSize(width: width, height: height))
    }

    func updateNSView(_ nsView: LaunchWindowSizingView, context: Context) {}
}

@available(macOS 13.0, *)
private final class LaunchWindowSizingView: NSView {
    private let launchContentSize: NSSize
    private var didApplyLaunchSize = false

    init(contentSize: NSSize) {
        launchContentSize = contentSize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didApplyLaunchSize, let window else { return }
        didApplyLaunchSize = true
        window.contentMinSize = launchContentSize
        window.setContentSize(launchContentSize)
        window.center()
    }
}

enum ReverbAboutPanelPresenter {
    @MainActor
    static func show() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.3.0"
        let build = info?["CFBundleVersion"] as? String ?? "3"
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
