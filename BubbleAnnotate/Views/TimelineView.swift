import SwiftUI
import AppKit

// MARK: - NSView-based timeline that avoids SwiftUI ScrollView gesture conflicts

final class TimelineNSView: NSView {
    var pps: Double = 120
    var duration: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var annotations: [AnnotationItem] = []
    var selectedID: AnnotationID?
    var onSeek: ((TimeInterval) -> Void)?
    var onSelect: ((AnnotationID?) -> Void)?
    var onDelete: ((AnnotationID) -> Void)?
    var onMoveClip: ((AnnotationID, TimeInterval) -> Void)?
    var onResizeClipLeft: ((AnnotationID, TimeInterval, TimeInterval) -> Void)?
    var onResizeClipRight: ((AnnotationID, TimeInterval, TimeInterval) -> Void)?

    private var isDraggingPlayhead = false
    private var isDraggingClip = false
    private var dragClipID: AnnotationID?
    private var dragClipInitialStart: TimeInterval = 0
    private var dragClipDuration: TimeInterval = 0
    private var dragOriginX: CGFloat = 0
    private var dragEdge: DragEdge = .none

    private enum DragEdge { case none, left, right, body }

    private let rulerHeight: CGFloat = 24
    private let trackHeight: CGFloat = 32
    private let trackGap: CGFloat = 4
    private let leftMargin: CGFloat = 60
    private let contentLeftPad: CGFloat = 20
    private let clipCornerRadius: CGFloat = 4
    private let edgeHandleWidth: CGFloat = 10
    private let playheadHitWidth: CGFloat = 12

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    var totalHeight: CGFloat { rulerHeight + (trackHeight + trackGap) * 2 + trackGap }

    var visibleWidth: CGFloat = 400

    var contentWidth: CGFloat {
        max(visibleWidth, leftMargin + contentLeftPad + CGFloat(duration) * pps + contentLeftPad)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: contentWidth, height: totalHeight)
    }

    func timeToX(_ t: TimeInterval) -> CGFloat {
        leftMargin + contentLeftPad + CGFloat(t) * pps
    }

    func xToTime(_ x: CGFloat) -> TimeInterval {
        Double((x - leftMargin - contentLeftPad) / pps)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let bgColor = NSColor.controlBackgroundColor
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        drawRuler(ctx)
        drawTrack(ctx, trackIndex: 0, label: "Bubbles", type: .bubble)
        drawTrack(ctx, trackIndex: 1, label: "Arrows", type: .arrow)
        drawPlayhead(ctx)
    }

    private func drawRuler(_ ctx: CGContext) {
        let sepColor = NSColor.separatorColor
        ctx.setStrokeColor(sepColor.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: leftMargin, y: rulerHeight - 0.5))
        ctx.addLine(to: CGPoint(x: bounds.width, y: rulerHeight - 0.5))
        ctx.strokePath()

        let visibleSeconds = Double(bounds.width) / pps
        let step = max(0.5, visibleSeconds / 20)
        var t: TimeInterval = 0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        while t <= duration + 1 {
            let x = timeToX(t)
            if x > leftMargin - 10 && x < bounds.width + 10 {
                ctx.setStrokeColor(sepColor.cgColor)
                ctx.move(to: CGPoint(x: x, y: rulerHeight - 6))
                ctx.addLine(to: CGPoint(x: x, y: rulerHeight - 1))
                ctx.strokePath()

                let label = formatTime(t) as NSString
                let size = label.size(withAttributes: attrs)
                label.draw(at: CGPoint(x: x - size.width / 2, y: 2), withAttributes: attrs)
            }
            t += step
        }
    }

    private func trackYOrigin(_ index: Int) -> CGFloat {
        rulerHeight + trackGap + CGFloat(index) * (trackHeight + trackGap)
    }

    private func drawTrack(_ ctx: CGContext, trackIndex: Int, label: String, type: AnnotationType) {
        let y = trackYOrigin(trackIndex)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        (label as NSString).draw(at: CGPoint(x: 8, y: y + 8), withAttributes: labelAttrs)

        let trackItems = annotations.filter { $0.annotation.type == type }
        for item in trackItems {
            drawClip(ctx, item: item, y: y)
        }
    }

    private func drawClip(_ ctx: CGContext, item: AnnotationItem, y: CGFloat) {
        let x = timeToX(item.annotation.startTime)
        let w = max(20, CGFloat(item.annotation.endTime - item.annotation.startTime) * pps)
        let rect = CGRect(x: x, y: y, width: w, height: trackHeight)
        let isSelected = item.id == selectedID

        let isArrow: Bool
        let clipColor: NSColor
        switch item.content {
        case .bubble:
            isArrow = false
            clipColor = NSColor.controlAccentColor
        case .arrow(let d):
            isArrow = true
            let c = d.style.color
            clipColor = NSColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        }

        let path = CGPath(roundedRect: rect, cornerWidth: clipCornerRadius, cornerHeight: clipCornerRadius, transform: nil)
        let fillColor = isSelected
            ? clipColor.withAlphaComponent(0.65)
            : clipColor.withAlphaComponent(0.35)
        ctx.addPath(path)
        ctx.setFillColor(fillColor.cgColor)
        ctx.fillPath()

        ctx.addPath(path)
        ctx.setStrokeColor(clipColor.withAlphaComponent(isSelected ? 1.0 : 0.55).cgColor)
        ctx.setLineWidth(isSelected ? 1.5 : 1.0)
        ctx.strokePath()

        _ = isArrow

        let label: String
        switch item.content {
        case .bubble(let d): label = String(d.text.prefix(14))
        case .arrow(let d): label = String((d.label ?? "Arrow").prefix(14))
        }
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white
        ]
        let textSize = (label as NSString).size(withAttributes: textAttrs)
        let textX = rect.midX - textSize.width / 2
        let textY = rect.midY - textSize.height / 2
        if textSize.width < w - 20 {
            (label as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttrs)
        }

        if isSelected {
            let xBtnSize: CGFloat = 14
            let xBtnRect = CGRect(x: rect.maxX - xBtnSize - 3, y: rect.minY + (trackHeight - xBtnSize) / 2, width: xBtnSize, height: xBtnSize)
            ctx.setFillColor(NSColor.systemRed.withAlphaComponent(0.8).cgColor)
            ctx.fillEllipse(in: xBtnRect)
            let xAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let xStr = "\u{2715}" as NSString
            let xSize = xStr.size(withAttributes: xAttrs)
            xStr.draw(at: CGPoint(x: xBtnRect.midX - xSize.width / 2, y: xBtnRect.midY - xSize.height / 2), withAttributes: xAttrs)
        }

        let handleColor = isSelected
            ? NSColor.white.withAlphaComponent(0.55)
            : NSColor.white.withAlphaComponent(0.22)
        ctx.setFillColor(handleColor.cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: edgeHandleWidth, height: trackHeight))
        ctx.fill(CGRect(x: rect.maxX - edgeHandleWidth, y: rect.minY, width: edgeHandleWidth, height: trackHeight))
    }

    private func drawPlayhead(_ ctx: CGContext) {
        let x = timeToX(max(0, min(currentTime, duration)))

        ctx.setFillColor(NSColor.systemRed.cgColor)
        ctx.fill(CGRect(x: x - 1, y: 0, width: 2, height: bounds.height))

        let triangleSize: CGFloat = 8
        ctx.move(to: CGPoint(x: x - triangleSize / 2, y: 0))
        ctx.addLine(to: CGPoint(x: x + triangleSize / 2, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: triangleSize))
        ctx.closePath()
        ctx.fillPath()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Hit Testing

    private func clipAt(point: NSPoint) -> (item: AnnotationItem, edge: DragEdge)? {
        for trackIndex in 0..<2 {
            let y = trackYOrigin(trackIndex)
            guard point.y >= y && point.y <= y + trackHeight else { continue }
            let type: AnnotationType = trackIndex == 0 ? .bubble : .arrow
            let trackItems = annotations.filter { $0.annotation.type == type }
            for item in trackItems.reversed() {
                let x = timeToX(item.annotation.startTime)
                let w = max(20, CGFloat(item.annotation.endTime - item.annotation.startTime) * pps)
                let rect = CGRect(x: x, y: y, width: w, height: trackHeight)
                guard rect.contains(point) else { continue }

                if item.id == selectedID {
                    let xBtnSize: CGFloat = 14
                    let xBtnRect = CGRect(x: rect.maxX - xBtnSize - 3, y: rect.minY + (trackHeight - xBtnSize) / 2, width: xBtnSize, height: xBtnSize)
                    if xBtnRect.insetBy(dx: -4, dy: -4).contains(point) {
                        return (item, .none)
                    }
                }

                if point.x < x + edgeHandleWidth {
                    return (item, .left)
                } else if point.x > x + w - edgeHandleWidth {
                    return (item, .right)
                } else {
                    return (item, .body)
                }
            }
        }
        return nil
    }

    private func isOnPlayhead(_ point: NSPoint) -> Bool {
        let x = timeToX(max(0, min(currentTime, duration)))
        return abs(point.x - x) < playheadHitWidth
    }

    private func deleteButtonHit(point: NSPoint) -> AnnotationID? {
        guard let selID = selectedID else { return nil }
        for trackIndex in 0..<2 {
            let y = trackYOrigin(trackIndex)
            let type: AnnotationType = trackIndex == 0 ? .bubble : .arrow
            let trackItems = annotations.filter { $0.annotation.type == type }
            for item in trackItems where item.id == selID {
                let x = timeToX(item.annotation.startTime)
                let w = max(20, CGFloat(item.annotation.endTime - item.annotation.startTime) * pps)
                let xBtnSize: CGFloat = 14
                let xBtnRect = CGRect(x: x + w - xBtnSize - 3, y: y + (trackHeight - xBtnSize) / 2, width: xBtnSize, height: xBtnSize)
                if xBtnRect.insetBy(dx: -4, dy: -4).contains(point) {
                    return selID
                }
            }
        }
        return nil
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        super.resetCursorRects()

        let playheadX = timeToX(max(0, min(currentTime, duration)))
        let playheadRect = CGRect(x: playheadX - playheadHitWidth, y: 0, width: playheadHitWidth * 2, height: bounds.height)
        addCursorRect(playheadRect, cursor: .resizeLeftRight)

        for trackIndex in 0..<2 {
            let y = trackYOrigin(trackIndex)
            let type: AnnotationType = trackIndex == 0 ? .bubble : .arrow
            let trackItems = annotations.filter { $0.annotation.type == type }
            for item in trackItems {
                let x = timeToX(item.annotation.startTime)
                let w = max(20, CGFloat(item.annotation.endTime - item.annotation.startTime) * pps)
                addCursorRect(CGRect(x: x, y: y, width: edgeHandleWidth, height: trackHeight), cursor: .resizeLeftRight)
                addCursorRect(CGRect(x: x + w - edgeHandleWidth, y: y, width: edgeHandleWidth, height: trackHeight), cursor: .resizeLeftRight)
                addCursorRect(CGRect(x: x + edgeHandleWidth, y: y, width: max(0, w - edgeHandleWidth * 2), height: trackHeight), cursor: .openHand)
            }
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        if let delID = deleteButtonHit(point: point) {
            onDelete?(delID)
            return
        }

        if isOnPlayhead(point) {
            isDraggingPlayhead = true
            return
        }

        if let (item, edge) = clipAt(point: point) {
            onSelect?(item.id)
            if edge != .none {
                isDraggingClip = true
                dragClipID = item.id
                dragEdge = edge
                dragClipInitialStart = item.annotation.startTime
                dragClipDuration = item.annotation.endTime - item.annotation.startTime
                dragOriginX = point.x
            }
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            return
        }

        let time = xToTime(point.x)
        let clamped = max(0, min(time, duration))
        onSeek?(clamped)
        onSelect?(nil)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isDraggingPlayhead {
            let time = xToTime(point.x)
            onSeek?(max(0, min(time, duration)))
            return
        }

        if isDraggingClip, let clipID = dragClipID {
            let dx = point.x - dragOriginX
            let dt = Double(dx) / pps
            switch dragEdge {
            case .body:
                let newStart = max(0, dragClipInitialStart + dt)
                onMoveClip?(clipID, newStart)
            case .left:
                let newStart = max(0, dragClipInitialStart + dt)
                let origEnd = dragClipInitialStart + dragClipDuration
                if origEnd - newStart >= 0.1 {
                    onResizeClipLeft?(clipID, newStart, origEnd)
                }
            case .right:
                let newEnd = max(dragClipInitialStart + 0.1, dragClipInitialStart + dragClipDuration + dt)
                onResizeClipRight?(clipID, dragClipInitialStart, newEnd)
            case .none:
                break
            }
            return
        }

        let time = xToTime(point.x)
        onSeek?(max(0, min(time, duration)))
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingPlayhead = false
        isDraggingClip = false
        dragClipID = nil
        dragEdge = .none
        window?.invalidateCursorRects(for: self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let deleteKeyCodes: Set<UInt16> = [51, 117]
        if deleteKeyCodes.contains(event.keyCode), let selID = selectedID {
            onDelete?(selID)
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - NSScrollView wrapper

final class TimelineScrollView: NSScrollView {
    let timelineContent = TimelineNSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        hasHorizontalScroller = true
        hasVerticalScroller = false
        autohidesScrollers = true
        drawsBackground = true
        backgroundColor = .controlBackgroundColor
        documentView = timelineContent
        contentView.postsBoundsChangedNotifications = true
    }

    func updateContentSize() {
        timelineContent.visibleWidth = contentView.bounds.width
        let w = timelineContent.contentWidth
        let h = timelineContent.totalHeight
        timelineContent.frame = NSRect(x: 0, y: 0, width: w, height: h)
        timelineContent.needsDisplay = true
        timelineContent.window?.invalidateCursorRects(for: timelineContent)
    }
}

// MARK: - SwiftUI bridge

struct TimelineView: NSViewRepresentable {
    @ObservedObject var state: TimelineState
    let timelineEngine: TimelineEngine
    let onSeek: (TimeInterval) -> Void

    func makeNSView(context: Context) -> TimelineScrollView {
        let scrollView = TimelineScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 100))
        let content = scrollView.timelineContent
        content.frame = NSRect(x: 0, y: 0, width: max(400, CGFloat(state.duration) * state.timelineScale.pixelsPerSecond + 80), height: content.totalHeight)
        content.onSeek = { [weak state] time in
            guard let state = state else { return }
            state.currentTime = time
            onSeek(time)
        }
        content.onSelect = { [weak state] id in
            state?.setSelection(id)
        }
        content.onDelete = { [weak state] id in
            state?.removeAnnotation(id: id)
        }
        content.onMoveClip = { [weak state] id, newStart in
            guard let state = state else { return }
            guard let item = state.annotations.first(where: { $0.id == id }) else { return }
            let dur = item.annotation.endTime - item.annotation.startTime
            let snapped = timelineEngine.snapToFrame(newStart)
            state.updateAnnotationTime(id: id, startTime: snapped, endTime: snapped + dur)
        }
        content.onResizeClipLeft = { [weak state] id, newStart, end in
            guard let state = state else { return }
            let snapped = timelineEngine.snapToFrame(max(0, newStart))
            state.updateAnnotationTime(id: id, startTime: snapped, endTime: end)
        }
        content.onResizeClipRight = { [weak state] id, start, newEnd in
            guard let state = state else { return }
            let snapped = timelineEngine.snapToFrame(newEnd)
            state.updateAnnotationTime(id: id, startTime: start, endTime: snapped)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: TimelineScrollView, context: Context) {
        let content = scrollView.timelineContent
        content.pps = state.timelineScale.pixelsPerSecond
        content.duration = state.duration
        content.currentTime = state.currentTime
        content.annotations = state.annotations
        content.selectedID = state.selectedAnnotationID
        scrollView.updateContentSize()
    }
}
