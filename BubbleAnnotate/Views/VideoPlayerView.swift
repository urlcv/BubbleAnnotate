import SwiftUI
import AVKit
import AVFoundation

/// AVPlayer wrapped for SwiftUI; exposes current time and duration.
final class PlayerViewModel: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?

    init() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        statusObserver = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, _ in
            guard player.currentItem?.status == .readyToPlay else { return }
            Task { @MainActor in
                self?.duration = player.currentItem?.duration.seconds ?? 0
            }
        }
    }

    deinit {
        if let o = timeObserver { player.removeTimeObserver(o) }
    }

    func load(url: URL) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        currentTime = 0
        duration = 0
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }
}

/// NSView wrapping AVPlayerLayer for SwiftUI.
struct AVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = PlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PlayerNSView)?.player = player
    }
}

final class PlayerNSView: NSView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
