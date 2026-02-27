import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = TimelineState()
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var exportEngine = ExportEngine()
    @State private var timelineEngine = TimelineEngine()
    @State private var showExport = false
    @State private var showHelp = false
    @State private var errorMessage: String?

    private var hasVideo: Bool { currentVideoURL() != nil }

    var body: some View {
        mainContent
            .frame(minWidth: 900, minHeight: 600)
            .onAppear { syncStateWithPlayer(); state.projectDuration = playerVM.duration }
            .onChange(of: playerVM.currentTime) { _, t in
                guard !state.isSeeking, abs(state.currentTime - t) > 0.03 else { return }
                state.currentTime = t
            }
            .onChange(of: playerVM.duration) { _, d in state.projectDuration = d }
            .toolbar {
                toolbarContentPart1
                toolbarContentPart2
            }
            .onDeleteCommand {
                if let id = state.selectedAnnotationID { state.removeAnnotation(id: id) }
            }
            .sheet(isPresented: $showExport) { exportSheet }
            .sheet(isPresented: $showHelp) { KeyboardShortcutsHelpView() }
            .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in showHelp = true }
            .onOpenURL { url in
                if url.pathExtension == ProjectPersistence.projectExtension { openProject(url: url) }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
    }

    private var mainContent: some View {
        Group {
            if hasVideo {
                editorContent
            } else {
                WelcomeView(
                    onImportVideo: openImportPanel,
                    onOpenProject: openProjectPanel
                )
            }
        }
    }

    private var editorContent: some View {
        HSplitView {
            InspectorView(state: state, timelineEngine: timelineEngine)
                .frame(minWidth: 200, maxWidth: 280)
            VStack(spacing: 0) {
                videoSection
                    .layoutPriority(1)
                TimelineView(state: state, timelineEngine: timelineEngine, onSeek: { time in
                    state.isSeeking = true
                    playerVM.seek(to: time)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        state.isSeeking = false
                    }
                })
                    .frame(maxWidth: .infinity, minHeight: 96, idealHeight: 96, maxHeight: 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContentPart1: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Open Project…") { openProjectPanel() }
                .keyboardShortcut("o", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Save Project") { saveProject() }
                .keyboardShortcut("s", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: openImportPanel) { Label("Import Video", systemImage: "square.and.arrow.down") }
                .keyboardShortcut("i", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showExport = true }) { Label("Export", systemImage: "square.and.arrow.up") }
                .keyboardShortcut("e", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { playerVM.togglePlayPause() }) { Label("Play / Pause", systemImage: "playpause.fill") }
                .keyboardShortcut(.space, modifiers: [])
        }
    }

    @ToolbarContentBuilder
    private var toolbarContentPart2: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: stepBackward) { Label("Step Back", systemImage: "backward.frame") }
                .keyboardShortcut(.leftArrow, modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: stepForward) { Label("Step Forward", systemImage: "forward.frame") }
                .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: addBubble) { Label("Add Bubble", systemImage: "bubble.left") }
                .keyboardShortcut("b", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: addArrow) { Label("Add Arrow", systemImage: "arrow.up.right") }
                .keyboardShortcut("a", modifiers: [.command, .shift])
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { state.zoomTimelineIn() }) { Label("Zoom In", systemImage: "plus.magnifyingglass") }
                .keyboardShortcut("=", modifiers: [])
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { state.zoomTimelineOut() }) { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: [])
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showHelp = true }) { Label("Keyboard Shortcuts", systemImage: "questionmark.circle") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }

    private var videoSection: some View {
        ZStack {
            AVPlayerView(player: playerVM.player)
            GeometryReader { geo in
                OverlayEditorView(
                    annotations: state.annotations,
                    currentTime: state.currentTime,
                    selectedID: state.selectedAnnotationID,
                    onSelect: { state.setSelection($0) },
                    onUpdateBubbleGeometry: { state.updateBubbleGeometry(id: $0, geometry: $1) },
                    onUpdateBubbleText: { state.updateBubbleData(id: $0, text: $1) },
                    onUpdateArrowGeometry: { state.updateArrowGeometry(id: $0, geometry: $1) }
                )
            }
        }
        .frame(minHeight: 300)
    }

    private func openImportPanel() {
        let panel = NSOpenPanel()
        let videoTypes: [UTType] = [
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "mp4") ?? .mpeg4Movie,
            UTType(filenameExtension: "mov") ?? .quickTimeMovie,
        ]
        panel.allowedContentTypes = videoTypes
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(url: url)
        }
    }

    private var exportSheet: some View {
        ExportSheet(
            exportEngine: exportEngine,
            currentSettings: state.project.exportSettings,
            onExport: { runExport() },
            onCancel: { showExport = false }
        )
    }

    private func currentVideoURL() -> URL? {
        if let bookmark = state.project.sourceVideoBookmark {
            return try? ProjectPersistence.resolveBookmark(bookmark)
        }
        return nil
    }

    private func loadVideo(url: URL) {
        url.startAccessingSecurityScopedResource()
        do {
            let bookmark = try ProjectPersistence.bookmark(for: url)
            state.project.sourceVideoBookmark = bookmark
            state.project.sourceVideoPath = url.path
            state.project.annotations = []
            playerVM.load(url: url)
            let asset = AVAsset(url: url)
            timelineEngine.updateFrameDuration(from: asset)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncStateWithPlayer() {
        state.currentTime = playerVM.currentTime
    }

    private func addBubble() {
        let start = timelineEngine.snapToFrame(state.currentTime)
        let end = start + 3
        let item = AnnotationItem.bubble(start: start, end: end)
        state.addAnnotation(item)
        state.setSelection(item.id)
    }

    private func addArrow() {
        let start = timelineEngine.snapToFrame(state.currentTime)
        let end = start + 3
        state.addAnnotation(.arrow(start: start, end: end))
    }

    private func stepBackward() {
        state.currentTime = timelineEngine.nudgeBackward(state.currentTime)
        playerVM.seek(to: state.currentTime)
    }

    private func stepForward() {
        state.currentTime = timelineEngine.nudgeForward(state.currentTime)
        playerVM.seek(to: state.currentTime)
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: ProjectPersistence.projectExtension) ?? .data]
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            openProject(url: url)
        }
    }

    private func openProject(url: URL) {
        do {
            var project = try ProjectPersistence.load(from: url)
            if let bookmark = project.sourceVideoBookmark {
                let videoURL = try ProjectPersistence.resolveBookmark(bookmark)
                videoURL.startAccessingSecurityScopedResource()
                project.sourceVideoPath = videoURL.path
                state.project = project
                state.documentURL = url
                playerVM.load(url: videoURL)
                if let asset = AVAsset(url: videoURL) as AVAsset? {
                    timelineEngine.updateFrameDuration(from: asset)
                }
            } else {
                state.project = project
                state.documentURL = url
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveProject() {
        if let url = state.documentURL {
            do {
                try ProjectPersistence.save(state.project, to: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: ProjectPersistence.projectExtension) ?? .data]
            panel.nameFieldStringValue = "Untitled.\(ProjectPersistence.projectExtension)"
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try ProjectPersistence.save(state.project, to: url)
                    state.documentURL = url
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func runExport() {
        guard let url = currentVideoURL() else {
            errorMessage = "No video loaded."
            return
        }
        let preset = state.project.exportSettings.preset
        let cropMode = state.project.exportSettings.cropMode
        let duration = state.duration
        let frameDuration = timelineEngine.frameDuration

        Task { @MainActor in
            do {
                let outputURL = try await exportEngine.export(
                    sourceURL: url,
                    annotations: state.annotations,
                    preset: preset,
                    cropMode: cropMode,
                    videoDuration: duration,
                    frameDuration: frameDuration
                )
                showExport = false
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.mpeg4Movie]
                savePanel.nameFieldStringValue = "BubbleAnnotate_\(preset.name.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).mp4"
                if savePanel.runModal() == .OK, let dest = savePanel.url {
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: outputURL, to: dest)
                }
                try? FileManager.default.removeItem(at: outputURL)
            } catch {
                showExport = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
