import SwiftUI

private struct DraggableBubbleContent: View {
    let item: AnnotationItem
    let data: BubbleData
    let contentRect: CGRect
    let isSelected: Bool
    let onSelect: (AnnotationID?) -> Void
    let onUpdateBubbleGeometry: (AnnotationID, BubbleGeometry) -> Void
    let onUpdateBubbleText: (AnnotationID, String) -> Void

    @State private var dragStartGeometry: BubbleGeometry?
    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var editorFocused: Bool

    private var textColor: Color { data.style.textColor.swiftUI }

    var body: some View {
        let g = data.geometry
        let x = contentRect.minX + contentRect.width * g.originX
        let y = contentRect.minY + contentRect.height * (1 - g.originY - g.height)
        let w = contentRect.width * g.width
        let h = contentRect.height * g.height
        let frame = CGRect(x: x, y: y, width: w, height: h)
        let bubbleW = max(44, w)
        let bubbleH = max(28, h)

        let cornerRadius = CGFloat(data.style.cornerRadius)
        let borderWidth = max(0, CGFloat(data.style.borderWidth))
        let pad = CGFloat(data.style.padding)
        let fontSize = CGFloat(data.style.fontSize)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(data.style.backgroundColor.swiftUI.opacity(0.9))
                .overlay(
                    Group {
                        if borderWidth > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(data.style.borderColor.swiftUI, lineWidth: borderWidth)
                        }
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    }
                )
                .shadow(color: .black.opacity(data.style.shadowOpacity), radius: data.style.shadowRadius)

            // Content: TextEditor when editing, otherwise Text + emoji
            Group {
                if isEditing {
                    TextEditor(text: $editingText)
                        .font(data.style.makeFont(size: fontSize))
                        .foregroundColor(textColor)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .focused($editorFocused)
                        .multilineTextAlignment(data.style.textAlignment.textAlignment)
                        .padding(.horizontal, pad - 4)
                        .padding(.vertical, pad - 4)
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        if let emoji = data.leadingEmoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(data.style.makeFont(size: fontSize))
                                .foregroundColor(textColor)
                        }
                        Text(data.text)
                            .font(data.style.makeFont(size: fontSize))
                            .foregroundColor(textColor)
                            .multilineTextAlignment(data.style.textAlignment.textAlignment)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(pad)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(width: bubbleW, height: bubbleH)

            if isSelected {
                resizeHandles(bubbleWidth: bubbleW, bubbleHeight: bubbleH,
                              contentRect: contentRect, itemID: item.id, data: data)
            }
        }
        .frame(width: bubbleW, height: bubbleH)
        .position(x: frame.midX, y: frame.midY)
        // Double-tap starts inline editing; single-tap selects
        .onTapGesture(count: 2) {
            guard !isEditing else { return }
            editingText = data.text
            isEditing = true
            onSelect(item.id)
        }
        .onTapGesture(count: 1) {
            guard !isEditing else { return }
            onSelect(item.id)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !isEditing else { return }
                    let base = dragStartGeometry ?? data.geometry
                    if dragStartGeometry == nil { dragStartGeometry = data.geometry }
                    let dx = value.translation.width / contentRect.width
                    let dy = -value.translation.height / contentRect.height
                    onUpdateBubbleGeometry(item.id, BubbleGeometry(
                        originX: base.originX + dx,
                        originY: base.originY + dy,
                        width: base.width,
                        height: base.height
                    ))
                }
                .onEnded { _ in dragStartGeometry = nil }
        )
        // Commit edit when bubble is deselected (user clicked elsewhere)
        .onChange(of: isSelected) { _, selected in
            if !selected && isEditing {
                onUpdateBubbleText(item.id, editingText)
                isEditing = false
            }
        }
        // Focus the TextEditor as soon as editing mode activates
        .onChange(of: isEditing) { _, editing in
            editorFocused = editing
        }
        // Cursor hints: tracked on the parent ZStack so child tracking areas don't block drag
        .onContinuousHover(coordinateSpace: .local) { phase in
            guard isSelected else { return }
            switch phase {
            case .active(let loc):
                let edgeZone: CGFloat = 16
                let nearLeft   = loc.x < edgeZone
                let nearRight  = loc.x > bubbleW - edgeZone
                let nearTop    = loc.y < edgeZone
                let nearBottom = loc.y > bubbleH - edgeZone
                if (nearLeft || nearRight) && (nearTop || nearBottom) {
                    NSCursor.crosshair.set()
                } else if nearTop || nearBottom {
                    NSCursor.resizeUpDown.set()
                } else if nearLeft || nearRight {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.openHand.set()
                }
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }

    @State private var resizeStartGeometry: BubbleGeometry?

    // Coordinate system:
    //   originX = left edge (0=left, 1=right of video)
    //   originY = bottom edge of bubble (0=bottom, 1=top of video)
    //   view_top    = contentRect.height * (1 - originY - height)
    //   view_bottom = contentRect.height * (1 - originY)
    //
    // cornerDrag dy: positive = drag UP in view (negated view delta)
    // edgeDrag   dy: positive = drag DOWN in view (raw view delta)
    private func resizeHandles(bubbleWidth: CGFloat, bubbleHeight: CGFloat,
                               contentRect: CGRect, itemID: AnnotationID, data: BubbleData) -> some View {
        let handleSize: CGFloat = 12
        let strokeWidth: CGFloat = 2
        let hitExtra: CGFloat = 10
        let edgeHandleLength: CGFloat = 24

        func cornerHandle(x: CGFloat, y: CGFloat) -> some View {
            Circle()
                .fill(Color.accentColor)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: strokeWidth))
                .frame(width: handleSize, height: handleSize)
                .padding(hitExtra)
                .contentShape(Circle())
                .position(x: x, y: y)
        }

        func edgeHandle(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white, lineWidth: strokeWidth))
                .frame(width: width, height: height)
                .padding(hitExtra / 2)
                .contentShape(Rectangle())
                .position(x: x, y: y)
        }

        return ZStack(alignment: .topLeading) {
            // Top-left: TL moves, BR fixed
            cornerHandle(x: 0, y: 0)
                .gesture(cornerDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newOriginX = g.originX + dx
                    let newW = g.width - dx
                    let newH = g.height + dy
                    if newW > 0.05 && newH > 0.03 && newOriginX >= 0 && g.originY + newH <= 1 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: newOriginX, originY: g.originY, width: newW, height: newH))
                    }
                })

            // Top-right: TR moves, BL fixed
            cornerHandle(x: bubbleWidth, y: 0)
                .gesture(cornerDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newW = g.width + dx
                    let newH = g.height + dy
                    if newW > 0.05 && newH > 0.03 && g.originY + newH <= 1 && g.originX + newW <= 1 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: g.originX, originY: g.originY, width: newW, height: newH))
                    }
                })

            // Bottom-left: BL moves, TR fixed
            cornerHandle(x: 0, y: bubbleHeight)
                .gesture(cornerDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newOriginX = g.originX + dx
                    let newOriginY = g.originY + dy
                    let newW = g.width - dx
                    let newH = g.height - dy
                    if newW > 0.05 && newH > 0.03 && newOriginX >= 0 && newOriginY >= 0 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: newOriginX, originY: newOriginY, width: newW, height: newH))
                    }
                })

            // Bottom-right: BR moves, TL fixed
            cornerHandle(x: bubbleWidth, y: bubbleHeight)
                .gesture(cornerDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newOriginY = g.originY + dy
                    let newW = g.width + dx
                    let newH = g.height - dy
                    if newW > 0.05 && newH > 0.03 && g.originX + newW <= 1 && newOriginY >= 0 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: g.originX, originY: newOriginY, width: newW, height: newH))
                    }
                })

            // Top edge: fix bottom, move top
            edgeHandle(width: edgeHandleLength, height: 4, x: bubbleWidth / 2, y: 0)
                .gesture(edgeDrag(contentRect: contentRect, itemID: itemID, data: data) { _, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newH = g.height - dy
                    if newH > 0.03 && g.originY + newH <= 1 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: g.originX, originY: g.originY, width: g.width, height: newH))
                    }
                })

            // Bottom edge: fix top, move bottom
            edgeHandle(width: edgeHandleLength, height: 4, x: bubbleWidth / 2, y: bubbleHeight)
                .gesture(edgeDrag(contentRect: contentRect, itemID: itemID, data: data) { _, dy in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newOriginY = g.originY - dy
                    let newH = g.height + dy
                    if newH > 0.03 && newOriginY >= 0 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: g.originX, originY: newOriginY, width: g.width, height: newH))
                    }
                })

            // Left edge
            edgeHandle(width: 4, height: edgeHandleLength, x: 0, y: bubbleHeight / 2)
                .gesture(edgeDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, _ in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newOriginX = g.originX + dx
                    let newW = g.width - dx
                    if newW > 0.05 && newOriginX >= 0 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: newOriginX, originY: g.originY, width: newW, height: g.height))
                    }
                })

            // Right edge
            edgeHandle(width: 4, height: edgeHandleLength, x: bubbleWidth, y: bubbleHeight / 2)
                .gesture(edgeDrag(contentRect: contentRect, itemID: itemID, data: data) { dx, _ in
                    let g = resizeStartGeometry ?? data.geometry
                    if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                    let newW = g.width + dx
                    if newW > 0.05 && g.originX + newW <= 1 {
                        onUpdateBubbleGeometry(itemID, BubbleGeometry(originX: g.originX, originY: g.originY, width: newW, height: g.height))
                    }
                })
        }
    }

    // cornerDrag: dy = -view_translation.height / height  (positive = dragged upward)
    private func cornerDrag(contentRect: CGRect, itemID: AnnotationID, data: BubbleData,
                            onChange: @escaping (Double, Double) -> Void) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = Double(value.translation.width / contentRect.width)
                let dy = -Double(value.translation.height / contentRect.height)
                if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                onChange(dx, dy)
            }
            .onEnded { _ in resizeStartGeometry = nil }
    }

    // edgeDrag: dy = view_translation.height / height  (positive = dragged downward)
    private func edgeDrag(contentRect: CGRect, itemID: AnnotationID, data: BubbleData,
                          onChange: @escaping (Double, Double) -> Void) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = Double(value.translation.width / contentRect.width)
                let dyH = Double(value.translation.height / contentRect.height)
                if resizeStartGeometry == nil { resizeStartGeometry = data.geometry }
                onChange(dx, dyH)
            }
            .onEnded { _ in resizeStartGeometry = nil }
    }
}

/// Interactive overlay: draws annotations for current time, hit-testing, selection, and drag handles.
struct OverlayEditorView: View {
    let annotations: [AnnotationItem]
    let currentTime: TimeInterval
    let selectedID: AnnotationID?
    let onSelect: (AnnotationID?) -> Void
    let onUpdateBubbleGeometry: (AnnotationID, BubbleGeometry) -> Void
    let onUpdateBubbleText: (AnnotationID, String) -> Void
    let onUpdateArrowGeometry: (AnnotationID, ArrowGeometry) -> Void

    var body: some View {
        GeometryReader { geo in
            let contentRect = CGRect(origin: .zero, size: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(visibleItems(in: contentRect)) { item in
                    editableAnnotationView(item: item, contentRect: contentRect)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let hit = hitTest(location: location, in: contentRect)
                onSelect(hit)
            }
        }
    }

    private func visibleItems(in rect: CGRect) -> [AnnotationItem] {
        annotations
            .filter { currentTime >= $0.annotation.startTime && currentTime <= $0.annotation.endTime }
            .sorted { $0.annotation.zIndex < $1.annotation.zIndex }
    }

    @ViewBuilder
    private func editableAnnotationView(item: AnnotationItem, contentRect: CGRect) -> some View {
        let isSelected = selectedID == item.id
        switch item.content {
        case .bubble(let data):
            editableBubble(item: item, data: data, contentRect: contentRect, isSelected: isSelected)
        case .arrow(let data):
            editableArrow(item: item, data: data, contentRect: contentRect, isSelected: isSelected)
        }
    }

    private func editableBubble(item: AnnotationItem, data: BubbleData,
                                contentRect: CGRect, isSelected: Bool) -> some View {
        DraggableBubbleContent(
            item: item,
            data: data,
            contentRect: contentRect,
            isSelected: isSelected,
            onSelect: onSelect,
            onUpdateBubbleGeometry: onUpdateBubbleGeometry,
            onUpdateBubbleText: onUpdateBubbleText
        )
    }

    private func editableArrow(item: AnnotationItem, data: ArrowData,
                               contentRect: CGRect, isSelected: Bool) -> some View {
        let g = data.geometry
        let startX = contentRect.minX + contentRect.width * g.startX
        let startY = contentRect.minY + contentRect.height * (1 - g.startY)
        let endX = contentRect.minX + contentRect.width * g.endX
        let endY = contentRect.minY + contentRect.height * (1 - g.endY)

        func normX(_ x: CGFloat) -> Double { Double((x - contentRect.minX) / contentRect.width) }
        func normY(_ y: CGFloat) -> Double { Double(1 - (y - contentRect.minY) / contentRect.height) }

        return ZStack {
            ArrowShape(start: CGPoint(x: startX, y: startY), end: CGPoint(x: endX, y: endY),
                       headSize: CGFloat(data.style.headSize))
                .stroke(data.style.color.swiftUI, style: StrokeStyle(
                    lineWidth: CGFloat(data.style.thickness), lineCap: .round, lineJoin: .round,
                    dash: data.style.isDashed ? [CGFloat(data.style.dashLength)] : []))
            if isSelected {
                Circle().fill(Color.accentColor).frame(width: 12, height: 12).position(x: startX, y: startY)
                    .gesture(DragGesture().onChanged { value in
                        onUpdateArrowGeometry(item.id, ArrowGeometry(
                            startX: normX(value.location.x), startY: normY(value.location.y),
                            endX: g.endX, endY: g.endY))
                    })
                Circle().fill(Color.accentColor).frame(width: 12, height: 12).position(x: endX, y: endY)
                    .gesture(DragGesture().onChanged { value in
                        onUpdateArrowGeometry(item.id, ArrowGeometry(
                            startX: g.startX, startY: g.startY,
                            endX: normX(value.location.x), endY: normY(value.location.y)))
                    })
            }
            if let label = data.label, !label.isEmpty {
                Text(label).font(.system(size: 12)).padding(4).background(.ultraThinMaterial)
                    .position(x: (startX + endX) / 2, y: (startY + endY) / 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(item.id) }
    }

    private func hitTest(location: CGPoint, in contentRect: CGRect) -> AnnotationID? {
        let items = visibleItems(in: contentRect).reversed()
        for item in items {
            switch item.content {
            case .bubble(let data):
                let g = data.geometry
                let x = contentRect.minX + contentRect.width * g.originX
                let y = contentRect.minY + contentRect.height * (1 - g.originY - g.height)
                let w = contentRect.width * g.width
                let h = contentRect.height * g.height
                if location.x >= x && location.x <= x + w && location.y >= y && location.y <= y + h {
                    return item.id
                }
            case .arrow(let data):
                let g = data.geometry
                let sx = contentRect.minX + contentRect.width * g.startX
                let sy = contentRect.minY + contentRect.height * (1 - g.startY)
                let ex = contentRect.minX + contentRect.width * g.endX
                let ey = contentRect.minY + contentRect.height * (1 - g.endY)
                if distanceFromPoint(location, toSegment: (CGPoint(x: sx, y: sy), CGPoint(x: ex, y: ey))) < 20 {
                    return item.id
                }
            }
        }
        return nil
    }

    private func distanceFromPoint(_ p: CGPoint, toSegment seg: (CGPoint, CGPoint)) -> CGFloat {
        let (a, b) = seg
        let d = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)
        if d == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / d
        t = max(0, min(1, t))
        let proj = CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
        return hypot(p.x - proj.x, p.y - proj.y)
    }
}
