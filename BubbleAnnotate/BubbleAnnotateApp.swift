import SwiftUI

extension Notification.Name {
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
}

@main
struct BubbleAnnotateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .help) {
                Button("Keyboard Shortcuts…") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
