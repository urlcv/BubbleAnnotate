import Foundation
import Combine

/// Timeline scale: pixels per second.
struct TimelineScale {
    var pixelsPerSecond: Double
    static let minPPS: Double = 50
    static let maxPPS: Double = 500
    static let defaultPPS: Double = 120

    mutating func zoomIn() {
        pixelsPerSecond = min(TimelineScale.maxPPS, pixelsPerSecond * 1.2)
    }

    mutating func zoomOut() {
        pixelsPerSecond = max(TimelineScale.minPPS, pixelsPerSecond / 1.2)
    }
}

/// App-wide state: project, selection, player time, timeline scale, undo.
final class TimelineState: ObservableObject {
    @Published var project: Project
    @Published var selectedAnnotationID: AnnotationID?
    @Published var currentTime: TimeInterval = 0
    @Published var timelineScale: TimelineScale
    @Published var isPlaying: Bool = false
    @Published var documentURL: URL?
    @Published var isSeeking: Bool = false

    let undoManager = UndoManager()

    var annotations: [AnnotationItem] {
        get { project.annotations }
        set {
            let old = project.annotations
            var proj = project
            proj.annotations = newValue
            proj.lastModified = Date()
            project = proj
            undoManager.registerUndo(withTarget: self) { state in
                var p = state.project
                p.annotations = old
                p.lastModified = Date()
                state.project = p
            }
        }
    }

    var selectedItem: AnnotationItem? {
        guard let id = selectedAnnotationID else { return nil }
        return project.annotations.first { $0.id == id }
    }

    var duration: TimeInterval { projectDuration ?? 0 }
    var projectDuration: TimeInterval?

    init(project: Project = Project(), timelineScale: TimelineScale = TimelineScale(pixelsPerSecond: TimelineScale.defaultPPS)) {
        self.project = project
        self.timelineScale = timelineScale
    }

    func setSelection(_ id: AnnotationID?) {
        selectedAnnotationID = id
    }

    func addAnnotation(_ item: AnnotationItem) {
        var list = project.annotations
        list.append(item)
        list.sort { $0.annotation.startTime < $1.annotation.startTime }
        annotations = list
    }

    func removeAnnotation(id: AnnotationID) {
        var list = project.annotations
        list.removeAll { $0.id == id }
        if selectedAnnotationID == id { selectedAnnotationID = nil }
        annotations = list
    }

    func updateAnnotation(_ id: AnnotationID, _ update: (inout AnnotationItem) -> Void) {
        guard let idx = project.annotations.firstIndex(where: { $0.id == id }) else { return }
        var item = project.annotations[idx]
        update(&item)
        item.annotation.clampDuration()
        var list = project.annotations
        list[idx] = item
        var proj = project
        proj.annotations = list
        project = proj
    }

    func updateAnnotationTime(id: AnnotationID, startTime: TimeInterval? = nil, endTime: TimeInterval? = nil) {
        updateAnnotation(id) { item in
            if let s = startTime { item.annotation.startTime = s }
            if let e = endTime { item.annotation.endTime = e }
        }
    }

    func updateBubbleGeometry(id: AnnotationID, geometry: BubbleGeometry) {
        updateAnnotation(id) { item in
            if var data = item.content.bubble {
                data.geometry = geometry
                item.content = .bubble(data)
            }
        }
    }

    func updateBubbleData(id: AnnotationID, text: String? = nil, style: BubbleStyle? = nil, emoji: String?? = nil) {
        updateAnnotation(id) { item in
            if var data = item.content.bubble {
                if let t = text { data.text = t }
                if let s = style { data.style = s }
                if let e = emoji { data.leadingEmoji = e }
                item.content = .bubble(data)
            }
        }
    }

    /// Update only the bubble style (e.g. one property at a time).
    func updateBubbleStyle(id: AnnotationID, _ update: (inout BubbleStyle) -> Void) {
        updateAnnotation(id) { item in
            if var data = item.content.bubble {
                update(&data.style)
                item.content = .bubble(data)
            }
        }
    }

    func updateArrowGeometry(id: AnnotationID, geometry: ArrowGeometry) {
        updateAnnotation(id) { item in
            if var data = item.content.arrow {
                data.geometry = geometry
                item.content = .arrow(data)
            }
        }
    }

    func updateArrowData(id: AnnotationID, style: ArrowStyle? = nil, label: String?? = nil) {
        updateAnnotation(id) { item in
            if var data = item.content.arrow {
                if let s = style { data.style = s }
                if let l = label { data.label = l }
                item.content = .arrow(data)
            }
        }
    }

    /// Update only the arrow style.
    func updateArrowStyle(id: AnnotationID, _ update: (inout ArrowStyle) -> Void) {
        updateAnnotation(id) { item in
            if var data = item.content.arrow {
                update(&data.style)
                item.content = .arrow(data)
            }
        }
    }

    func annotationsInRange(start: TimeInterval, end: TimeInterval) -> [AnnotationItem] {
        project.annotations.filter { item in
            item.annotation.endTime > start && item.annotation.startTime < end
        }
    }

    func zoomTimelineIn() {
        timelineScale.zoomIn()
    }

    func zoomTimelineOut() {
        timelineScale.zoomOut()
    }
}
