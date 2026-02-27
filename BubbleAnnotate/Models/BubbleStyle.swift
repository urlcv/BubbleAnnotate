import Foundation
import SwiftUI

enum BubbleBackgroundPreset: String, Codable, CaseIterable {
    case soft
    case glass
    case solid
}

enum BubbleTextAlignment: String, Codable, CaseIterable {
    case leading, center, trailing

    var textAlignment: TextAlignment {
        switch self {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }

    var icon: String {
        switch self {
        case .leading:  return "text.alignleft"
        case .center:   return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

enum BubbleEntranceAnimation: String, Codable, CaseIterable {
    case none
    case fade
    case scale
    case slideUp
    case slideDown
}

struct BubbleStyle: Equatable {
    var backgroundColor: CodableColor
    var borderColor: CodableColor
    var borderWidth: Double
    var cornerRadius: Double
    var padding: Double
    var fontSize: Double
    var fontName: String               // "" = system, "rounded"/"serif"/"mono", or an NSFont name
    var textColor: CodableColor
    var textAlignment: BubbleTextAlignment
    var shadowOpacity: Double
    var shadowRadius: Double
    var shadowOffsetY: Double
    var backgroundPreset: BubbleBackgroundPreset
    var entranceAnimation: BubbleEntranceAnimation
    var exitAnimation: BubbleEntranceAnimation

    init(
        backgroundColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 0.95),
        borderColor: CodableColor = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5),
        borderWidth: Double = 0,
        cornerRadius: Double = 12,
        padding: Double = 12,
        fontSize: Double = 16,
        fontName: String = "",
        textColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        textAlignment: BubbleTextAlignment = .leading,
        shadowOpacity: Double = 0.2,
        shadowRadius: Double = 8,
        shadowOffsetY: Double = 2,
        backgroundPreset: BubbleBackgroundPreset = .soft,
        entranceAnimation: BubbleEntranceAnimation = .fade,
        exitAnimation: BubbleEntranceAnimation = .fade
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.fontSize = fontSize
        self.fontName = fontName
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffsetY = shadowOffsetY
        self.backgroundPreset = backgroundPreset
        self.entranceAnimation = entranceAnimation
        self.exitAnimation = exitAnimation
    }

    /// Build a SwiftUI Font from the stored fontName and a given size.
    func makeFont(size: CGFloat) -> Font {
        switch fontName {
        case "rounded": return .system(size: size, design: .rounded)
        case "serif":   return .system(size: size, design: .serif)
        case "mono":    return .system(size: size, design: .monospaced)
        case "":        return .system(size: size)
        default:        return Font.custom(fontName, size: size)
        }
    }

    static let presetSoft = BubbleStyle(
        backgroundColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 0.95),
        borderWidth: 0,
        cornerRadius: 14,
        padding: 14,
        fontSize: 17,
        fontName: "",
        textColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        textAlignment: .leading,
        shadowOpacity: 0.15,
        shadowRadius: 10,
        backgroundPreset: .soft,
        entranceAnimation: .fade,
        exitAnimation: .fade
    )

    static let presetGlass = BubbleStyle(
        backgroundColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 0.75),
        borderWidth: 0.5,
        cornerRadius: 16,
        padding: 12,
        fontSize: 16,
        fontName: "",
        textColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        textAlignment: .leading,
        shadowOpacity: 0.1,
        shadowRadius: 12,
        backgroundPreset: .glass,
        entranceAnimation: .scale,
        exitAnimation: .fade
    )

    static let presetSolid = BubbleStyle(
        backgroundColor: CodableColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
        borderColor: CodableColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1),
        borderWidth: 1,
        cornerRadius: 10,
        padding: 12,
        fontSize: 16,
        fontName: "",
        textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        textAlignment: .leading,
        shadowOpacity: 0.25,
        shadowRadius: 6,
        backgroundPreset: .solid,
        entranceAnimation: .slideUp,
        exitAnimation: .fade
    )

    static var presets: [BubbleStyle] { [presetSoft, presetGlass, presetSolid] }
}

extension BubbleStyle: Codable {
    enum CodingKeys: String, CodingKey {
        case backgroundColor, borderColor, borderWidth, cornerRadius, padding, fontSize
        case fontName, textColor, textAlignment
        case shadowOpacity, shadowRadius, shadowOffsetY, backgroundPreset, entranceAnimation, exitAnimation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = try c.decode(CodableColor.self, forKey: .backgroundColor)
        borderColor = try c.decodeIfPresent(CodableColor.self, forKey: .borderColor)
            ?? CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0
        cornerRadius = try c.decode(Double.self, forKey: .cornerRadius)
        padding = try c.decode(Double.self, forKey: .padding)
        fontSize = try c.decode(Double.self, forKey: .fontSize)
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? ""
        textColor = try c.decodeIfPresent(CodableColor.self, forKey: .textColor)
            ?? CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
        textAlignment = try c.decodeIfPresent(BubbleTextAlignment.self, forKey: .textAlignment) ?? .leading
        shadowOpacity = try c.decode(Double.self, forKey: .shadowOpacity)
        shadowRadius = try c.decode(Double.self, forKey: .shadowRadius)
        shadowOffsetY = try c.decode(Double.self, forKey: .shadowOffsetY)
        backgroundPreset = try c.decode(BubbleBackgroundPreset.self, forKey: .backgroundPreset)
        entranceAnimation = try c.decode(BubbleEntranceAnimation.self, forKey: .entranceAnimation)
        exitAnimation = try c.decode(BubbleEntranceAnimation.self, forKey: .exitAnimation)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(backgroundColor, forKey: .backgroundColor)
        try c.encode(borderColor, forKey: .borderColor)
        try c.encode(borderWidth, forKey: .borderWidth)
        try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(padding, forKey: .padding)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(textColor, forKey: .textColor)
        try c.encode(textAlignment, forKey: .textAlignment)
        try c.encode(shadowOpacity, forKey: .shadowOpacity)
        try c.encode(shadowRadius, forKey: .shadowRadius)
        try c.encode(shadowOffsetY, forKey: .shadowOffsetY)
        try c.encode(backgroundPreset, forKey: .backgroundPreset)
        try c.encode(entranceAnimation, forKey: .entranceAnimation)
        try c.encode(exitAnimation, forKey: .exitAnimation)
    }
}

/// Codable wrapper for SwiftUI Color (RGBA in 0...1).
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var swiftUI: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
