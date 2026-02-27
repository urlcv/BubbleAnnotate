# BubbleAnnotate

A production-quality macOS app MVP (macOS 14+ Sonoma) that lets you import a video, add annotation bubbles and arrows on a timeline, and export to formats suitable for LinkedIn, Reddit, and the web.

## How to run

1. **Open in Xcode**  
   Open `BubbleAnnotate.xcodeproj` in Xcode (must use Xcode, not only Command Line Tools).

2. **Select the scheme**  
   Choose the **BubbleAnnotate** scheme and **My Mac** as the run destination.

3. **Build and run**  
   Press **⌘R** or click the Run button.

4. **First use**  
   Use **Import Video** (or **⌘I**) to load a video, then add bubbles/arrows from the toolbar or **⌘E** to export.

## How it works

- **Architecture**  
  Single-target Swift/SwiftUI app with clear separation:
  - **Models**: `Annotation`, `AnnotationItem`, `BubbleStyle`, `ArrowStyle`, `Project`, `TimelineState` (selection, undo).
  - **Engine**: `TimelineEngine` (frame snapping from video FPS, 1/30s fallback), `ExportEngine` (composition + Core Animation overlay, `AVAssetExportSession`).
  - **Renderer**: `OverlayRenderer` (SwiftUI preview overlay), `ExportOverlayBuilder` (CALayer tree with time-range opacity for export).
  - **UI**: `VideoPlayerView` (AVPlayer via `NSViewRepresentable`), `OverlayEditorView` (canvas, hit-testing, drag/resize), `TimelineView` (ruler, playhead, draggable clips, zoom), `InspectorView`, `ExportSheet`.

- **Video & timeline**  
  AVFoundation loads the asset; the timeline snaps to frame boundaries using the track’s nominal frame rate (or 1/30s). Annotations have `startTime`/`endTime` and normalized geometry (0–1) for layout and export.

- **Preview**  
  Annotations visible at the current playhead time are drawn in SwiftUI on top of the player view. Selection and drag/resize update the shared `TimelineState` (with undo).

- **Export**  
  `AVMutableComposition` copies video (and audio) track; `AVMutableVideoComposition` uses `AVVideoCompositionCoreAnimationTool` with a CALayer overlay. Overlay layers get keyframe opacity so they only appear between each annotation’s `startTime` and `endTime`. Output size and crop (fit/fill) come from the chosen preset; export runs via `AVAssetExportSession` with progress and cancel.

- **Project persistence**  
  `.bubbleproj` is JSON: source video (security-scoped bookmark), annotations and styles, export settings. Open/Save use `ProjectPersistence`; optional autosave can be added later.

## Keyboard shortcuts

- **Space**: Play / Pause  
- **⌘I**: Import Video  
- **⌘O**: Open Project  
- **⌘S**: Save Project  
- **⌘E**: Export  
- **Delete**: Remove selected annotation  
- **+** / **−**: Zoom timeline in / out  

## Known limitations / next steps

- **Timeline**: Resizing an annotation by dragging the clip’s in/out points (rather than moving the whole clip) is not implemented; only move-in-time is supported.
- **Variable frame rate**: Snapping uses nominal FPS or 1/30s; true VFR-aware snapping would need sample timing.
- **Export bitrate**: Preset `maxBitrateMbps` is not yet applied to `AVAssetExportSession` (MVP uses highest quality); a custom export preset or `AVAssetWriter` would be needed for strict bitrate limits.
- **Autosave**: Project autosave/recovery is not implemented; Save and Open are manual.
- **Animations**: Bubble entrance/exit (fade, scale, slide) are defined in the model but only opacity is used in the export overlay; full animation would require mapping to CA animations with the correct time range.
- **Playback**: Looping and “stop at end” are not configured; the player runs until paused.

## File layout

```
BubbleAnnotate/
├── BubbleAnnotate.xcodeproj/
├── BubbleAnnotate/
│   ├── BubbleAnnotateApp.swift    # @main
│   ├── ContentView.swift          # Main layout, import/export/save/load
│   ├── Info.plist
│   ├── BubbleAnnotate.entitlements
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Annotation.swift
│   │   ├── BubbleStyle.swift
│   │   ├── ArrowStyle.swift
│   │   ├── Project.swift
│   │   └── TimelineState.swift
│   ├── Engine/
│   │   ├── TimelineEngine.swift
│   │   └── ExportEngine.swift
│   ├── Renderer/
│   │   ├── OverlayRenderer.swift
│   │   └── ExportOverlayBuilder.swift
│   ├── Persistence/
│   │   └── ProjectPersistence.swift
│   └── Views/
│       ├── VideoPlayerView.swift
│       ├── OverlayEditorView.swift
│       ├── TimelineView.swift
│       ├── InspectorView.swift
│       └── ExportSheet.swift
└── README.md
```

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ (for building)
- Swift 5, SwiftUI, AVFoundation, AppKit (no third-party dependencies)
