import SwiftUI
import AppKit

/// Native macOS color well that opens the system color panel; binds to CodableColor (supports transparency).
struct ColorWellPickerView: NSViewRepresentable {
    @Binding var color: CodableColor

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.color = nsColor(from: color)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ well: NSColorWell, context: Context) {
        well.color = nsColor(from: color)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func nsColor(from c: CodableColor) -> NSColor {
        NSColor(red: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue), alpha: CGFloat(c.alpha))
    }

    class Coordinator: NSObject {
        var parent: ColorWellPickerView

        init(_ parent: ColorWellPickerView) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            let ns = sender.color.usingColorSpace(.sRGB) ?? sender.color
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ns.getRed(&r, green: &g, blue: &b, alpha: &a)
            parent.color = CodableColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        }
    }
}
