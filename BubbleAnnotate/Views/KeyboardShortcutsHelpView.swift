import SwiftUI

private struct KeyCap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.controlColor))
                    .shadow(color: .black.opacity(0.15), radius: 0.5, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
    }
}

private struct ShortcutRow: View {
    let keys: [String]
    let description: String

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyCap(symbol: key)
                }
            }
            .frame(width: 110, alignment: .trailing)

            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Playback", icon: "play.circle")
                    ShortcutRow(keys: ["Space"], description: "Play / Pause")
                    ShortcutRow(keys: ["⌘", "←"], description: "Step back one frame")
                    ShortcutRow(keys: ["⌘", "→"], description: "Step forward one frame")

                    Divider().padding(.vertical, 8)

                    SectionHeader(title: "Project", icon: "doc")
                    ShortcutRow(keys: ["⌘", "O"], description: "Open project")
                    ShortcutRow(keys: ["⌘", "S"], description: "Save project")
                    ShortcutRow(keys: ["⌘", "I"], description: "Import video")
                    ShortcutRow(keys: ["⌘", "E"], description: "Export video")

                    Divider().padding(.vertical, 8)

                    SectionHeader(title: "Annotations", icon: "bubble.left")
                    ShortcutRow(keys: ["⌘", "B"], description: "Add bubble")
                    ShortcutRow(keys: ["⌘", "⇧", "A"], description: "Add arrow")
                    ShortcutRow(keys: ["⌫"], description: "Delete selected")

                    Divider().padding(.vertical, 8)

                    SectionHeader(title: "Timeline", icon: "timeline.selection")
                    ShortcutRow(keys: ["="], description: "Zoom in")
                    ShortcutRow(keys: ["-"], description: "Zoom out")

                    Divider().padding(.vertical, 8)

                    SectionHeader(title: "Help", icon: "questionmark.circle")
                    ShortcutRow(keys: ["⌘", "?"], description: "Show shortcuts")
                }
            }
        }
        .padding(24)
        .frame(width: 380, height: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    KeyboardShortcutsHelpView()
}
