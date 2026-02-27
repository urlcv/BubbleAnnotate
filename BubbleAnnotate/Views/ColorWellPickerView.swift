import SwiftUI

/// Compact inline color picker: a clickable swatch that reveals a popover with a preset grid + opacity slider.
struct ColorWellPickerView: View {
    @Binding var color: CodableColor
    @State private var showPopover = false

    private static let presetColors: [[CodableColor]] = [
        // Row 1: grayscale
        [
            CodableColor(red: 0, green: 0, blue: 0),
            CodableColor(red: 0.25, green: 0.25, blue: 0.25),
            CodableColor(red: 0.5, green: 0.5, blue: 0.5),
            CodableColor(red: 0.75, green: 0.75, blue: 0.75),
            CodableColor(red: 1, green: 1, blue: 1),
        ],
        // Row 2: warm
        [
            CodableColor(red: 0.9, green: 0.2, blue: 0.2),
            CodableColor(red: 0.95, green: 0.45, blue: 0.15),
            CodableColor(red: 1, green: 0.75, blue: 0),
            CodableColor(red: 1, green: 0.6, blue: 0.7),
            CodableColor(red: 0.7, green: 0.2, blue: 0.5),
        ],
        // Row 3: cool
        [
            CodableColor(red: 0.2, green: 0.5, blue: 0.95),
            CodableColor(red: 0.2, green: 0.75, blue: 0.95),
            CodableColor(red: 0.15, green: 0.8, blue: 0.55),
            CodableColor(red: 0.3, green: 0.7, blue: 0.3),
            CodableColor(red: 0.5, green: 0.3, blue: 0.8),
        ],
    ]

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.swiftUI)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(0..<Self.presetColors.count, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<Self.presetColors[row].count, id: \.self) { col in
                            let preset = Self.presetColors[row][col]
                            let isSelected = isMatch(preset)
                            Button {
                                color = CodableColor(red: preset.red, green: preset.green,
                                                     blue: preset.blue, alpha: color.alpha)
                            } label: {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(preset.swiftUI)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.15),
                                                          lineWidth: isSelected ? 2 : 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("Opacity")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                Slider(value: Binding(
                    get: { color.alpha },
                    set: { color = CodableColor(red: color.red, green: color.green, blue: color.blue, alpha: $0) }
                ), in: 0...1)
                .frame(width: 80)
                Text("\(Int(color.alpha * 100))%")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(12)
        .frame(width: 180)
    }

    private func isMatch(_ preset: CodableColor) -> Bool {
        abs(color.red - preset.red) < 0.05 &&
        abs(color.green - preset.green) < 0.05 &&
        abs(color.blue - preset.blue) < 0.05
    }
}
