import SwiftUI

@main
struct AudioConvolutionReverbApp: App {
    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Render") {
                    NotificationCenter.default.post(name: .renderRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let renderRequested = Notification.Name("AudioConvolutionReverb.renderRequested")
}
