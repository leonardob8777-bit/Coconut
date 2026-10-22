// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import AVFoundation

/// A failed reference video must never hide the artwork or prevent saving a theme.
@MainActor @Observable
final class WallpaperMotionPlayer {
    enum Phase: Equatable { case loading, ready, failed }
    private(set) var phase: Phase = .loading
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    @ObservationIgnored private(set) var player = AVQueuePlayer()
    @ObservationIgnored private let url: URL
    @ObservationIgnored private let loops: Bool
    @ObservationIgnored private let onFinished: @MainActor () -> Void
    @ObservationIgnored private var endObservation: NSObjectProtocol?
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var currentItemObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var playerObservation: NSKeyValueObservation?
    @ObservationIgnored private var loopObservation: NSKeyValueObservation?
    @ObservationIgnored private var playbackObservation: NSKeyValueObservation?
    @ObservationIgnored private var requestedPlayback = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var didFinish = false
    @ObservationIgnored private var download: Task<Void, Never>?

    init(url: URL, loops: Bool = true, onFinished: @escaping @MainActor () -> Void = {}) {
        self.url = url
        self.loops = loops
        self.onFinished = onFinished
        player.isMuted = true
    }

    func start(playing: Bool) {
        requestedPlayback = playing
        if !started { load() }
        else { setPlayback(playing) }
    }

    func setPlayback(_ enabled: Bool) {
        requestedPlayback = enabled
        guard started, phase != .failed else { return }
        enabled ? player.play() : player.pause()
        refreshState()
        guard enabled else { return }
        // A play() issued while another preview is still closing (e.g. a sheet being dismissed) can be
        // dropped by the system; check again shortly and resume if it did not start.
        let version = generation
        Task { @MainActor [weak self] in
            for delay in [0.4, 1.0, 2.0] {
                try? await Task.sleep(for: .seconds(delay))
                guard let self, self.generation == version, self.requestedPlayback, self.started else { return }
                if self.player.timeControlStatus == .playing { return }
                if self.phase == .failed { self.retry(); return }
                self.player.play()
            }
        }
    }

    func retry() {
        guard phase == .failed else { return }
        load()
    }

    func stop() {
        generation += 1
        started = false
        download?.cancel(); download = nil
        invalidateObservations()
        if let endObservation { NotificationCenter.default.removeObserver(endObservation) }
        endObservation = nil
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        phase = .loading
        isPlaying = false
        isBuffering = false
    }

    private func load() {
        let intent = requestedPlayback
        stop()
        requestedPlayback = intent
        // A player that reached .failed cannot be reused for a new attempt.
        player = AVQueuePlayer()
        player.isMuted = true
        started = true
        didFinish = false
        let version = generation
        phase = .loading
        guard !url.isFileURL else { attach(url, generation: version); return }
        let key = url.deletingPathExtension().lastPathComponent
        if let cached = ShowcaseVideoCache.cachedFile(key) { attach(cached, generation: version); return }
        // Not on the phone yet: stream it now (starts after the first few hundred KB) and save it
        // for next time in the background. GitHub serves these as octet-stream, so the type is declared.
        attach(url, generation: version)
        let remote = url
        download = Task { _ = try? await ShowcaseVideoCache.shared.localFile(for: key, remote: remote) }
    }

    private func attach(_ file: URL, generation version: Int) {
        let asset = file.isFileURL ? AVURLAsset(url: file) : AVURLAsset(url: file, options: [AVURLAssetOverrideMIMETypeKey: "video/mp4"])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2
        if loops {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            endObservation = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == version, !self.didFinish else { return }
                    self.didFinish = true
                    self.onFinished()
                }
            }
        }
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == version else { return }
                self.observeCurrentItem(generation: version)
            }
        }
        playerObservation = player.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == version else { return }
                self.refreshState()
            }
        }
        loopObservation = looper?.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == version else { return }
                self.refreshState()
            }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == version else { return }
                self.refreshState()
            }
        }
        setPlayback(requestedPlayback)
    }

    private func observeCurrentItem(generation version: Int) {
        itemObservation?.invalidate()
        itemObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == version else { return }
                self.refreshState()
            }
        }
        refreshState()
    }

    private func refreshState() {
        guard started else { return }
        if player.status == .failed || player.currentItem?.status == .failed || looper?.status == .failed {
            phase = .failed
            player.pause()
            isPlaying = false
            isBuffering = false
            return
        }
        if player.currentItem?.status == .readyToPlay { phase = .ready }
        isPlaying = player.timeControlStatus == .playing
        isBuffering = requestedPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    private func invalidateObservations() {
        currentItemObservation?.invalidate(); currentItemObservation = nil
        itemObservation?.invalidate(); itemObservation = nil
        playerObservation?.invalidate(); playerObservation = nil
        loopObservation?.invalidate(); loopObservation = nil
        playbackObservation?.invalidate(); playbackObservation = nil
    }
}

struct WallpaperMotionPreview: View {
    let playing: Bool
    let onAvailabilityChange: (Bool) -> Void
    let decorative: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: WallpaperMotionPlayer

    init(url: URL, playing: Bool, loops: Bool = true, decorative: Bool = false,
         onFinished: @escaping @MainActor () -> Void = {}, onAvailabilityChange: @escaping (Bool) -> Void = { _ in }) {
        self.playing = playing
        self.decorative = decorative
        self.onAvailabilityChange = onAvailabilityChange
        _session = State(initialValue: WallpaperMotionPlayer(url: url, loops: loops, onFinished: onFinished))
    }

    var body: some View {
        ZStack {
            if session.phase != .failed {
                MotionVideoLayer(player: session.player, state: accessibilityState)
                    .allowsHitTesting(false)
                    // Fade in once frames flow instead of popping over the artwork.
                    .opacity(session.isPlaying || session.phase == .ready ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: session.isPlaying || session.phase == .ready)
            }
            if session.phase == .failed && !decorative {
                VStack(spacing: 8) {
                    Text(L.text("El vídeo no está disponible"))
                        .font(.caption.weight(.medium)).multilineTextAlignment(.center)
                    Button { session.retry() } label: {
                        Label(L.text("Volver a intentar"), systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold)).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("preview.video.retry")
                }
                .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(12).accessibilityElement(children: .contain)
                .accessibilityIdentifier("preview.video.failure")
            } else if !decorative && (session.phase == .loading || session.isBuffering) {
                ProgressView().padding(14).background(.regularMaterial, in: Circle())
                    .accessibilityLabel(L.text("Cargando vídeo…"))
                    .accessibilityIdentifier("preview.video.loading")
            }
        }
        .task { session.start(playing: playing && scenePhase == .active) }
        .onChange(of: playing) { _, value in
            session.setPlayback(value && scenePhase == .active)
            if decorative && value && scenePhase == .active && session.phase == .failed { session.retry() }
        }
        .onChange(of: scenePhase) { _, phase in session.setPlayback(playing && phase == .active) }
        .onChange(of: session.phase) { _, phase in onAvailabilityChange(phase != .failed) }
        .onDisappear { session.stop() }
        .task(id: session.phase) {
            // Keep the current theme on a network failure; retry it instead of
            // rapidly skipping through the playlist. Only playback end advances.
            guard decorative, session.phase == .failed else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard !Task.isCancelled, playing, scenePhase == .active else { return }
            session.retry()
        }
    }

    private var accessibilityState: String {
        if session.phase == .failed { return L.text("El vídeo no está disponible") }
        if session.phase == .loading || session.isBuffering { return L.text("Cargando vídeo…") }
        return L.text(session.isPlaying ? "Reproduciendo" : "En pausa")
    }
}

private struct MotionVideoLayer: UIViewRepresentable {
    let player: AVQueuePlayer
    let state: String
    func makeUIView(context: Context) -> MotionVideoSurface {
        let view = MotionVideoSurface()
        view.videoLayer.player = player
        view.videoLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: MotionVideoSurface, context: Context) {
        view.videoLayer.player = player
        view.accessibilityLabel = L.text("Vídeo de referencia")
        view.accessibilityValue = state
    }
    static func dismantleUIView(_ view: MotionVideoSurface, coordinator: ()) { view.videoLayer.player = nil }
}

private final class MotionVideoSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityIdentifier = "preview.video"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
