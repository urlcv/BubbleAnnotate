import Foundation
import AVFoundation

/// Snapping and frame-based time logic. Uses video fps when available, else fallback (e.g. 30).
final class TimelineEngine {
    var frameDuration: TimeInterval = 1.0 / 30.0

    func updateFrameDuration(from asset: AVAsset?) {
        guard let asset = asset else {
            frameDuration = 1.0 / 30.0
            return
        }
        let tracks = asset.tracks(withMediaType: .video)
        if let track = tracks.first {
            let rate = track.nominalFrameRate
            if rate > 0 {
                frameDuration = 1.0 / Double(rate)
            } else {
                frameDuration = 1.0 / 30.0
            }
        } else {
            frameDuration = 1.0 / 30.0
        }
    }

    func snapToFrame(_ time: TimeInterval) -> TimeInterval {
        let frames = (time / frameDuration).rounded()
        return max(0, frames * frameDuration)
    }

    func nudgeForward(_ time: TimeInterval) -> TimeInterval { snapToFrame(time + frameDuration) }
    func nudgeBackward(_ time: TimeInterval) -> TimeInterval { max(0, snapToFrame(time - frameDuration)) }
}
