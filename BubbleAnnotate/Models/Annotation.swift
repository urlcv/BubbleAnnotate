import Foundation

/// Unique identifier for an annotation.
typealias AnnotationID = UUID

enum AnnotationType: String, Codable, CaseIterable {
    case bubble
    case arrow
}

/// Base annotation: id, type, time range, z-order.
struct Annotation: Identifiable, Codable, Equatable {
    var id: AnnotationID
    var type: AnnotationType
    var startTime: TimeInterval
    var endTime: TimeInterval
    var zIndex: Int

    init(id: AnnotationID = UUID(), type: AnnotationType, startTime: TimeInterval, endTime: TimeInterval, zIndex: Int = 0) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.zIndex = zIndex
    }

    static let minimumDuration: TimeInterval = 0.2

    var duration: TimeInterval { max(Annotation.minimumDuration, endTime - startTime) }

    mutating func clampDuration() {
        if endTime - startTime < Annotation.minimumDuration {
            endTime = startTime + Annotation.minimumDuration
        }
    }
}

/// Geometry for bubble: normalized origin (0...1) and size (0...1).
struct BubbleGeometry: Codable, Equatable {
    var originX: Double
    var originY: Double
    var width: Double
    var height: Double

    init(originX: Double = 0.15, originY: Double = 0.2, width: Double = 0.22, height: Double = 0.12) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }
}

/// Geometry for arrow: start and end in normalized (0...1) coordinates.
struct ArrowGeometry: Codable, Equatable {
    var startX: Double
    var startY: Double
    var endX: Double
    var endY: Double

    init(startX: Double = 0.2, startY: Double = 0.3, endX: Double = 0.8, endY: Double = 0.5) {
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
    }
}

/// Bubble-specific data.
struct BubbleData: Codable, Equatable {
    var text: String
    var geometry: BubbleGeometry
    var style: BubbleStyle
    var leadingEmoji: String?
}

/// Arrow-specific data.
struct ArrowData: Codable, Equatable {
    var geometry: ArrowGeometry
    var style: ArrowStyle
    var label: String?
}

/// Tagged annotation content (discriminated by type).
enum AnnotationContent: Codable, Equatable {
    case bubble(BubbleData)
    case arrow(ArrowData)

    enum CodingKeys: String, CodingKey { case type, bubble, arrow }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "bubble": self = .bubble(try c.decode(BubbleData.self, forKey: .bubble))
        case "arrow": self = .arrow(try c.decode(ArrowData.self, forKey: .arrow))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bubble(let d):
            try c.encode("bubble", forKey: .type)
            try c.encode(d, forKey: .bubble)
        case .arrow(let d):
            try c.encode("arrow", forKey: .type)
            try c.encode(d, forKey: .arrow)
        }
    }

    var bubble: BubbleData? {
        if case .bubble(let d) = self { return d }
        return nil
    }

    var arrow: ArrowData? {
        if case .arrow(let d) = self { return d }
        return nil
    }
}

/// Full annotation with content (for in-memory editing).
struct AnnotationItem: Identifiable, Equatable, Codable {
    var annotation: Annotation
    var content: AnnotationContent

    var id: AnnotationID { annotation.id }

    static func bubble(start: TimeInterval, end: TimeInterval, text: String = "New bubble", geometry: BubbleGeometry = BubbleGeometry(), style: BubbleStyle = .presetSoft) -> AnnotationItem {
        let ann = Annotation(type: .bubble, startTime: start, endTime: end)
        return AnnotationItem(annotation: ann, content: .bubble(BubbleData(text: text, geometry: geometry, style: style, leadingEmoji: nil)))
    }

    static func arrow(start: TimeInterval, end: TimeInterval, geometry: ArrowGeometry = ArrowGeometry(), style: ArrowStyle = ArrowStyle(), label: String? = nil) -> AnnotationItem {
        let ann = Annotation(type: .arrow, startTime: start, endTime: end)
        return AnnotationItem(annotation: ann, content: .arrow(ArrowData(geometry: geometry, style: style, label: label)))
    }
}
