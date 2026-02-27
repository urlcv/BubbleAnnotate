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
            CommandGroup(replacing: .appInfo) {
                Button("About BubbleAnnotate") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "BubbleAnnotate",
                        .applicationVersion: "1.0",
                        .version: "1",
                        .credits: NSAttributedString(
                            string: "A video annotation tool by URLCV\nhttps://urlcv.com",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        )
                    ])
                }
            }
            CommandGroup(after: .help) {
                Button("Keyboard Shortcuts…") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
                Divider()
                Button("URLCV Website") {
                    if let url = URL(string: "https://urlcv.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
