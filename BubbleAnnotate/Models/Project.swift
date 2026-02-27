import Foundation

/// Export preset: output size and optional constraints.
struct ExportPreset: Codable, Equatable, Hashable {
    var name: String
    var width: Int
    var height: Int
    var maxBitrateMbps: Double?
    var isWebOptimized: Bool

    /// Export at original video dimensions only (no resize/crop).
    static let original = ExportPreset(name: "Original", width: 0, height: 0, maxBitrateMbps: 12, isWebOptimized: true)
}

enum CropMode: String, Codable, CaseIterable {
    case fit  // letterbox/pillarbox to fit inside target
    case fill // crop to fill target
}

struct ExportSettings: Codable, Equatable {
    var preset: ExportPreset
    var cropMode: CropMode

    init(preset: ExportPreset = .original, cropMode: CropMode = .fit) {
        self.preset = preset
        self.cropMode = cropMode
    }
}

/// Top-level project: source video reference and annotations.
struct Project: Codable {
    var version: Int
    var sourceVideoBookmark: Data?
    var sourceVideoPath: String? // resolved path for display; bookmark used for access
    var annotations: [AnnotationItem]
    var exportSettings: ExportSettings
    var lastModified: Date?

    init(
        version: Int = 1,
        sourceVideoBookmark: Data? = nil,
        sourceVideoPath: String? = nil,
        annotations: [AnnotationItem] = [],
        exportSettings: ExportSettings = ExportSettings(),
        lastModified: Date? = nil
    ) {
        self.version = version
        self.sourceVideoBookmark = sourceVideoBookmark
        self.sourceVideoPath = sourceVideoPath
        self.annotations = annotations
        self.exportSettings = exportSettings
        self.lastModified = lastModified
    }
}
