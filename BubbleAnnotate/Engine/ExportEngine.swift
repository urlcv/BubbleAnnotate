import Foundation
import AVFoundation
import CoreMedia
import Combine

enum ExportError: LocalizedError {
    case noVideoTrack
    case compositionFailed
    case exportFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "Video has no video track."
        case .compositionFailed: return "Could not build composition."
        case .exportFailed(let e): return "Export failed: \(e.localizedDescription)"
        }
    }
}

struct ExportProgress {
    var progress: Float
    var isComplete: Bool
    var error: Error?
}

final class ExportEngine: ObservableObject {
    @Published var progress: ExportProgress = ExportProgress(progress: 0, isComplete: false, error: nil)
    private var exportSession: AVAssetExportSession?
    private var cancelRequested = false

    func cancelExport() {
        cancelRequested = true
        exportSession?.cancelExport()
    }

    func resetProgress() {
        progress = ExportProgress(progress: 0, isComplete: false, error: nil)
    }

    func export(
        sourceURL: URL,
        annotations: [AnnotationItem],
        preset: ExportPreset,
        cropMode: CropMode,
        videoDuration: TimeInterval,
        frameDuration: TimeInterval
    ) async throws -> URL {
        cancelRequested = false
        progress = ExportProgress(progress: 0, isComplete: false, error: nil)

        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ExportError.noVideoTrack
        }

        let (outputSize, transform, contentRect) = try await computeOutputSizeAndTransform(
            sourceTrack: videoTrack,
            preset: preset,
            cropMode: cropMode,
            asset: asset
        )

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.compositionFailed
        }

        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: videoDuration, preferredTimescale: 600))
        try compVideoTrack.insertTimeRange(range, of: videoTrack, at: .zero)

        let audioTracks = try? await asset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks?.first,
           let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(range, of: audioTrack, at: .zero)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(1.0 / frameDuration))
        videoComposition.instructions = []

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: outputSize)
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: outputSize)
        parentLayer.addSublayer(videoLayer)

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: outputSize)
        parentLayer.addSublayer(overlayLayer)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let durationSeconds = videoDuration
        let timescale: Int32 = 600
        let totalFrames = Int(durationSeconds / frameDuration) + 1

        for item in annotations.sorted(by: { $0.annotation.zIndex < $1.annotation.zIndex }) {
            let start = item.annotation.startTime
            let end = item.annotation.endTime
            let layer: CALayer? = switch item.content {
            case .bubble(let data):
                ExportOverlayBuilder.makeBubbleLayer(
                    data: data,
                    containerSize: outputSize,
                    contentRect: contentRect,
                    startTime: start,
                    endTime: end,
                    totalDuration: videoDuration
                )
            case .arrow(let data):
                ExportOverlayBuilder.makeArrowLayer(
                    data: data,
                    containerSize: outputSize,
                    contentRect: contentRect,
                    startTime: start,
                    endTime: end,
                    totalDuration: videoDuration
                )
            }
            if let layer = layer {
                overlayLayer.addSublayer(layer)
            }
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BubbleAnnotate_\(preset.name.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).mp4")

        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.compositionFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition

        exportSession = session

        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress = ExportProgress(progress: session.progress, isComplete: false, error: nil)
            }
        }
        timer.tolerance = 0.1

        await session.export()
        timer.invalidate()
        exportSession = nil

        if cancelRequested {
            try? FileManager.default.removeItem(at: outputURL)
            progress = ExportProgress(progress: 0, isComplete: false, error: nil)
            throw ExportError.exportFailed(NSError(domain: "BubbleAnnotate", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
        }

        if let error = session.error {
            try? FileManager.default.removeItem(at: outputURL)
            progress = ExportProgress(progress: 0, isComplete: false, error: error)
            throw ExportError.exportFailed(error)
        }

        progress = ExportProgress(progress: 1, isComplete: true, error: nil)
        return outputURL
    }

    /// Export at original video dimensions only (no resize, no crop).
    /// Returns (outputSize, transform for video layer, contentRect = full frame for overlay).
    private func computeOutputSizeAndTransform(
        sourceTrack: AVAssetTrack,
        preset: ExportPreset,
        cropMode: CropMode,
        asset: AVAsset
    ) async throws -> (CGSize, CGAffineTransform, CGRect) {
        let naturalSize = try await sourceTrack.load(.naturalSize)
        let preferredTransform = try await sourceTrack.load(.preferredTransform)
        let outputSize = naturalSize
        let contentRect = CGRect(origin: .zero, size: outputSize)
        return (outputSize, preferredTransform, contentRect)
    }
}
