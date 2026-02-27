import SwiftUI

/// Compact color row: swatch + optional expanded RGBA sliders.
struct ColorEditorView: View {
    let label: String
    @Binding var color: CodableColor
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                sliderRow("R", value: Binding(get: { color.red }, set: { color = CodableColor(red: $0, green: color.green, blue: color.blue, alpha: color.alpha) }))
                sliderRow("G", value: Binding(get: { color.green }, set: { color = CodableColor(red: color.red, green: $0, blue: color.blue, alpha: color.alpha) }))
                sliderRow("B", value: Binding(get: { color.blue }, set: { color = CodableColor(red: color.red, green: color.green, blue: $0, alpha: color.alpha) }))
                sliderRow("A", value: Binding(get: { color.alpha }, set: { color = CodableColor(red: color.red, green: color.green, blue: color.blue, alpha: $0) }))
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.swiftUI)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                    .frame(width: 24, height: 18)
                Text(label).font(.subheadline)
            }
        }
    }

    private func sliderRow(_ letter: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(letter).frame(width: 10, alignment: .leading).font(.caption2).foregroundStyle(.secondary)
            Slider(value: value, in: 0...1)
        }
    }
}
