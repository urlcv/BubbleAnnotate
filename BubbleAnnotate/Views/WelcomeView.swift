import SwiftUI

struct WelcomeView: View {
    let onImportVideo: () -> Void
    let onOpenProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            Text("BubbleAnnotate")
                .font(.system(size: 28, weight: .semibold))
                .padding(.bottom, 4)

            Text("Add speech bubbles and arrows to your videos")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 36)

            VStack(spacing: 12) {
                Button(action: onImportVideo) {
                    Label("Import Video", systemImage: "film")
                        .frame(width: 200)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("i", modifiers: .command)

                Button(action: onOpenProject) {
                    Label("Open Project", systemImage: "folder")
                        .frame(width: 200)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .keyboardShortcut("o", modifiers: .command)
            }

            Spacer()

            VStack(spacing: 6) {
                Text("⌘? for keyboard shortcuts")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    Text("A tool by")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("URLCV") {
                        if let url = URL(string: "https://urlcv.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .underline()
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    WelcomeView(onImportVideo: {}, onOpenProject: {})
        .frame(width: 500, height: 400)
}
