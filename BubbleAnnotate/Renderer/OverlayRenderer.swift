import SwiftUI

/// Renders annotation overlay in SwiftUI for preview (normalized 0..1 coordinates).
struct OverlayRenderer: View {
    let annotations: [AnnotationItem]
    let currentTime: TimeInterval
    let geometry: GeometryProxy

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleAnnotations) { item in
                annotationView(for: item)
            }
        }
        .allowsHitTesting(false)
    }

    private var visibleAnnotations: [AnnotationItem] {
        annotations.filter { item in
            currentTime >= item.annotation.startTime && currentTime <= item.annotation.endTime
        }
        .sorted { $0.annotation.zIndex < $1.annotation.zIndex }
    }

    @ViewBuilder
    private func annotationView(for item: AnnotationItem) -> some View {
        let rect = contentRect(in: geometry)
        switch item.content {
        case .bubble(let data):
            bubbleView(data: data, in: rect)
        case .arrow(let data):
            arrowView(data: data, in: rect)
        }
    }

    private func contentRect(in geo: GeometryProxy) -> CGRect {
        CGRect(origin: .zero, size: geo.size)
    }

    private func bubbleView(data: BubbleData, in rect: CGRect) -> some View {
        let g = data.geometry
        let x = rect.minX + rect.width * g.originX
        let y = rect.minY + rect.height * (1 - g.originY - g.height)
        let w = rect.width * g.width
        let h = rect.height * g.height

        let cornerRadius = CGFloat(data.style.cornerRadius)
        let borderWidth = max(0, CGFloat(data.style.borderWidth))
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(data.style.backgroundColor.swiftUI)
                .overlay(
                    Group {
                        if borderWidth > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(data.style.borderColor.swiftUI, lineWidth: borderWidth)
                        }
                    }
                )
                .shadow(color: .black.opacity(data.style.shadowOpacity), radius: data.style.shadowRadius, x: 0, y: data.style.shadowOffsetY)
            HStack(alignment: .top, spacing: 6) {
                if let emoji = data.leadingEmoji, !emoji.isEmpty {
                    Text(emoji).font(.system(size: CGFloat(data.style.fontSize)))
                }
                Text(data.text)
                    .font(.system(size: CGFloat(data.style.fontSize)))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CGFloat(data.style.padding))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: max(44, w), height: max(28, h))
        .position(x: x + w / 2, y: y + h / 2)
    }

    private func arrowView(data: ArrowData, in rect: CGRect) -> some View {
        let g = data.geometry
        let startX = rect.minX + rect.width * g.startX
        let startY = rect.minY + rect.height * (1 - g.startY)
        let endX = rect.minX + rect.width * g.endX
        let endY = rect.minY + rect.height * (1 - g.endY)

        return ZStack(alignment: .center) {
            ArrowShape(start: CGPoint(x: startX, y: startY), end: CGPoint(x: endX, y: endY), headSize: CGFloat(data.style.headSize))
                .stroke(data.style.color.swiftUI, style: StrokeStyle(lineWidth: CGFloat(data.style.thickness), lineCap: .round, lineJoin: .round, dash: data.style.isDashed ? [CGFloat(data.style.dashLength)] : []))
            if let label = data.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 12))
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .position(x: (startX + endX) / 2, y: (startY + endY) / 2)
            }
        }
    }
}

struct ArrowShape: Shape {
    var start: CGPoint
    var end: CGPoint
    var headSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        p.move(to: end)
        p.addLine(to: CGPoint(x: end.x - headSize * cos(angle - .pi/6), y: end.y - headSize * sin(angle - .pi/6)))
        p.move(to: end)
        p.addLine(to: CGPoint(x: end.x - headSize * cos(angle + .pi/6), y: end.y - headSize * sin(angle + .pi/6)))
        return p
    }
}
