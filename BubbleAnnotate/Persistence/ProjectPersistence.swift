import Foundation
import AppKit

enum ProjectPersistenceError: LocalizedError {
    case noBookmark
    case invalidBookmark
    case decodeFailed(Error)
    case encodeFailed(Error)
    case writeFailed(Error)
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noBookmark: return "No security-scoped bookmark for the video."
        case .invalidBookmark: return "Could not resolve the video file. It may have been moved."
        case .decodeFailed(let e): return "Project file is invalid: \(e.localizedDescription)"
        case .encodeFailed(let e): return "Could not save project: \(e.localizedDescription)"
        case .writeFailed(let e): return "Could not write file: \(e.localizedDescription)"
        case .readFailed(let e): return "Could not read file: \(e.localizedDescription)"
        }
    }
}

final class ProjectPersistence {
    static let projectExtension = "bubbleproj"
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Create a security-scoped bookmark for the video URL (for sandbox/resolution later).
    static func bookmark(for url: URL) throws -> Data {
        var isStale = false
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        return data
    }

    /// Resolve bookmark to URL and start security-scoped access.
    static func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            // Could refresh bookmark here; for MVP we still return the URL
        }
        return url
    }

    static func load(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        let project = try decoder.decode(Project.self, from: data)
        return project
    }

    static func save(_ project: Project, to url: URL) throws {
        var copy = project
        copy.lastModified = Date()
        let data = try encoder.encode(copy)
        try data.write(to: url)
    }

    /// Resolve project's video URL from bookmark; call when opening project.
    static func resolveVideoURL(for project: Project) -> URL? {
        guard let bookmark = project.sourceVideoBookmark else { return nil }
        return try? resolveBookmark(bookmark)
    }
}
