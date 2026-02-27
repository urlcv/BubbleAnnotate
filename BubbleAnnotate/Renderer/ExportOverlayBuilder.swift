import Foundation
import AVFoundation
import QuartzCore
import AppKit
import CoreText

/// Builds CALayer trees for export overlay with time-based visibility (opacity/transform).
enum ExportOverlayBuilder {
    /// Content rect in container coordinates where video is drawn (for mapping normalized 0..1).
    static func makeBubbleLayer(
        data: BubbleData,
        containerSize: CGSize,
        contentRect: CGRect,
        startTime: TimeInterval,
        endTime: TimeInterval,
        totalDuration: TimeInterval
    ) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: containerSize)
        // Match overlay view: top-left origin, Y down. Geometry originY = bottom edge from bottom.
        container.isGeometryFlipped = true

        let g = data.geometry
        let x = contentRect.minX + CGFloat(g.originX) * contentRect.width
        let w = CGFloat(g.width) * contentRect.width
        let h = CGFloat(g.height) * contentRect.height
        // Top edge in top-down coords = (1 - originY - height) * height; same as OverlayEditorView.
        let top = contentRect.minY + contentRect.height * CGFloat(1 - g.originY - g.height)
        let bubbleFrame = CGRect(x: x, y: top, width: w, height: h)

        let bubble = CALayer()
        bubble.frame = bubbleFrame
        bubble.isGeometryFlipped = true
        bubble.cornerRadius = CGFloat(data.style.cornerRadius)
        let c = data.style.backgroundColor
        bubble.backgroundColor = NSColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha).cgColor
        if data.style.borderWidth > 0 {
            let bc = data.style.borderColor
            bubble.borderColor = NSColor(red: bc.red, green: bc.green, blue: bc.blue, alpha: bc.alpha).cgColor
            bubble.borderWidth = CGFloat(data.style.borderWidth)
        }
        bubble.masksToBounds = false
        bubble.shadowOpacity = Float(data.style.shadowOpacity)
        bubble.shadowRadius = CGFloat(data.style.shadowRadius)
        bubble.shadowOffset = CGSize(width: 0, height: -data.style.shadowOffsetY)
        bubble.shadowColor = NSColor.black.cgColor

        let padding = CGFloat(data.style.padding)
        let textRect = bubble.bounds.insetBy(dx: padding, dy: padding)
        let displayText = (data.leadingEmoji.map { "\($0) " } ?? "") + data.text
        // CATextLayer text does not render in AVVideoCompositionCoreAnimationTool on macOS.
        // Render text to an image and use that as layer contents instead.
        if let textImage = Self.renderTextToImage(text: displayText.isEmpty ? " " : displayText, style: data.style, bounds: textRect) {
            let textLayer = CALayer()
            textLayer.frame = textRect
            textLayer.contents = textImage
            textLayer.contentsScale = 2
            textLayer.contentsGravity = .resize
            bubble.addSublayer(textLayer)
        }

        container.addSublayer(bubble)
        addTimeRangeAnimation(to: container, startTime: startTime, endTime: endTime, totalDuration: totalDuration)
        return container
    }

    static func makeArrowLayer(
        data: ArrowData,
        containerSize: CGSize,
        contentRect: CGRect,
        startTime: TimeInterval,
        endTime: TimeInterval,
        totalDuration: TimeInterval
    ) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: containerSize)
        container.isGeometryFlipped = true

        let g = data.geometry
        let startX = contentRect.minX + CGFloat(g.startX) * contentRect.width
        let endX = contentRect.minX + CGFloat(g.endX) * contentRect.width
        // Y from bottom in model → top-down: y = (1 - yFromBottom) * height (match OverlayEditorView).
        let startY = contentRect.minY + contentRect.height * CGFloat(1 - g.startY)
        let endY = contentRect.minY + contentRect.height * CGFloat(1 - g.endY)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))

        let shape = CAShapeLayer()
        shape.path = path
        let c = data.style.color
        shape.strokeColor = NSColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha).cgColor
        shape.lineWidth = CGFloat(data.style.thickness)
        shape.fillColor = nil
        if data.style.isDashed {
            shape.lineDashPattern = [NSNumber(value: data.style.dashLength), NSNumber(value: data.style.dashLength)]
        }
        shape.lineCap = .round
        shape.lineJoin = .round
        container.addSublayer(shape)

        let headSize = CGFloat(data.style.headSize)
        let angle = atan2(endY - startY, endX - startX)
        let headPath = CGMutablePath()
        headPath.move(to: CGPoint(x: endX, y: endY))
        headPath.addLine(to: CGPoint(x: endX - headSize * cos(angle - .pi/6), y: endY - headSize * sin(angle - .pi/6)))
        headPath.move(to: CGPoint(x: endX, y: endY))
        headPath.addLine(to: CGPoint(x: endX - headSize * cos(angle + .pi/6), y: endY - headSize * sin(angle + .pi/6)))
        let headLayer = CAShapeLayer()
        headLayer.path = headPath
        headLayer.strokeColor = NSColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha).cgColor
        headLayer.lineWidth = CGFloat(data.style.thickness)
        headLayer.fillColor = nil
        headLayer.lineCap = .round
        headLayer.lineJoin = .round
        container.addSublayer(headLayer)

        if let label = data.label, !label.isEmpty {
            let midX = (startX + endX) / 2
            let midY = (startY + endY) / 2
            let labelRect = CGRect(x: midX - 50, y: midY - 10, width: 100, height: 20)
            if let labelImage = Self.renderLabelToImage(text: label, bounds: labelRect) {
                let textLayer = CALayer()
                textLayer.frame = labelRect
                textLayer.contents = labelImage
                textLayer.contentsScale = 2
                textLayer.contentsGravity = .resize
                container.addSublayer(textLayer)
            }
        }

        addTimeRangeAnimation(to: container, startTime: startTime, endTime: endTime, totalDuration: totalDuration)
        return container
    }

    /// Renders a short label (e.g. arrow label) to a CGImage.
    private static func renderLabelToImage(text: String, bounds: CGRect) -> CGImage? {
        let font = NSFont.systemFont(ofSize: 14)
        let color = NSColor.textColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return renderTextToCGImage(text: text, font: font, color: color, paragraphStyle: paragraphStyle, bounds: bounds)
    }

    /// Renders text to a CGImage. Required because CATextLayer text does not render
    /// in AVVideoCompositionCoreAnimationTool on macOS.
    /// Font is scaled up for export so it matches the app's display (app uses points at Retina scale).
    private static let exportFontScale: CGFloat = 1.5

    private static func renderTextToImage(text: String, style: BubbleStyle, bounds: CGRect) -> CGImage? {
        let baseSize = CGFloat(style.fontSize)
        let exportSize = baseSize * exportFontScale
        let font: NSFont = switch style.fontName {
        case "rounded": NSFont.systemFont(ofSize: exportSize, weight: .regular)
        case "serif": NSFont.systemFont(ofSize: exportSize, weight: .regular)
        case "mono": NSFont.monospacedSystemFont(ofSize: exportSize, weight: .regular)
        case "": NSFont.systemFont(ofSize: exportSize)
        default: NSFont(name: style.fontName, size: exportSize) ?? NSFont.systemFont(ofSize: exportSize)
        }
        let tc = style.textColor
        let alpha = tc.alpha < 0.01 ? 1.0 : tc.alpha
        let color = NSColor(red: tc.red, green: tc.green, blue: tc.blue, alpha: alpha)
        let paragraphStyle = NSMutableParagraphStyle()
        switch style.textAlignment {
        case .leading: paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .trailing: paragraphStyle.alignment = .right
        }
        paragraphStyle.lineBreakMode = .byWordWrapping
        return renderTextToCGImage(text: text.isEmpty ? " " : text, font: font, color: color, paragraphStyle: paragraphStyle, bounds: bounds)
    }

    private static func renderTextToCGImage(text: String, font: NSFont, color: NSColor, paragraphStyle: NSParagraphStyle, bounds: CGRect) -> CGImage? {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale: CGFloat = 2
        let pixelW = Int(size.width * scale)
        let pixelH = Int(size.height * scale)
        guard pixelW > 0, pixelH > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.scaleBy(x: scale, y: scale)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), path, nil)
        ctx.textPosition = .zero
        CTFrameDraw(frame, ctx)
        return ctx.makeImage()
    }

    /// Add opacity keyframe animation so layer is visible only between startTime and endTime.
    /// totalDuration should be the composition duration; keyTimes are normalized 0..1.
    static func addTimeRangeAnimation(to layer: CALayer, startTime: TimeInterval, endTime: TimeInterval, totalDuration: TimeInterval) {
        layer.opacity = 0
        let total = max(totalDuration, endTime + 0.5)

        let fadeIn = max(0.001, startTime) / total
        let visibleEnd = endTime / total
        let fadeOut = min(1.0, (endTime + 0.05) / total)

        let anim = CAKeyframeAnimation(keyPath: "opacity")
        if startTime < 0.01 {
            anim.keyTimes = [
                NSNumber(value: 0),
                NSNumber(value: visibleEnd),
                NSNumber(value: fadeOut)
            ]
            anim.values = [1, 1, 0]
        } else {
            anim.keyTimes = [
                NSNumber(value: 0),
                NSNumber(value: fadeIn - 0.001),
                NSNumber(value: fadeIn),
                NSNumber(value: visibleEnd),
                NSNumber(value: fadeOut)
            ]
            anim.values = [0, 0, 1, 1, 0]
        }
        anim.duration = total
        anim.beginTime = AVCoreAnimationBeginTimeAtZero
        anim.isRemovedOnCompletion = false
        anim.fillMode = .both
        layer.add(anim, forKey: "timeRange")
    }
}
