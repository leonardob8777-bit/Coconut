// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct ShowcaseOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Showcase videos are downloaded to a small on-device cache before they play.
/// GitHub serves release assets as `application/octet-stream` from URLs without an
/// `.mp4` extension, which AVPlayer refuses to stream; a local `.mp4` always plays.
actor ShowcaseVideoCache {
    static let shared = ShowcaseVideoCache()
    private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ShowcaseVideos", isDirectory: true)
    private var inFlight: [String: Task<URL, Error>] = [:]
    nonisolated static func isCached(_ id: String) -> Bool {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ShowcaseVideos", isDirectory: true)
        return FileManager.default.fileExists(atPath: folder.appendingPathComponent(id + ".mp4").path)
    }
    nonisolated static func cachedFile(_ id: String) -> URL? {
        guard isCached(id) else { return nil }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ShowcaseVideos/" + id + ".mp4")
    }
    private let limit = 8

    func localFile(for id: String, remote: URL) async throws -> URL {
        if remote.isFileURL { return remote }
        let target = folder.appendingPathComponent(id + ".mp4")
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: target.path)
            return target
        }
        if let running = inFlight[id] { return try await running.value }
        let folder = folder
        let task = Task<URL, Error> {
            var request = URLRequest(url: remote)
            request.timeoutInterval = 45
            let (temporary, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                try? FileManager.default.removeItem(at: temporary)
                throw URLError(.badServerResponse)
            }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: temporary, to: target)
            return target
        }
        inFlight[id] = task
        defer { inFlight[id] = nil }
        let file = try await task.value
        trim()
        return file
    }

    /// Files are keyed by the published file name, so a re-recorded preview (new name) is downloaded again.
    /// Keeps only the most recently used videos so the cache never grows without bound.
    private func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return }
        let dated = files.map { ($0, (try? $0.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast) }
        for (file, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(limit) { try? FileManager.default.removeItem(at: file) }
    }
}

/// Decorative header: the newest wallpapers play one after another, in random order,
/// each for its full preview. Cards stay still; only this header and an opened detail play video.
struct WallpaperShowcase: View {
    let themes: [CatalogTheme]
    let scrollOffset: CGFloat
    let active: Bool
    var onThemeChange: (CatalogTheme?) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var playlist: [CatalogTheme] = []
    @State private var index = 0
    /// The downloaded video of the current theme (id + local file), so a late download never plays on the wrong theme.
    @State private var ready: (id: String, file: URL)?
    /// Only the newest part of the catalog takes part: the catalog is ordered newest first.
    private let recentPool = 40
    private var current: CatalogTheme? { playlist.indices.contains(index) ? playlist[index] : nil }
    private var upcoming: CatalogTheme? { playlist.count > 1 ? playlist[(index + 1) % playlist.count] : nil }
    /// How far the page scrolls before the phone stops moving; past it the phone stays put, looking exactly as it does here.
    static let stop: CGFloat = 190
    /// Extra room above the header where the blurred phone can fade out.
    static let bleed: CGFloat = 200
    private var settled: CGFloat { max(scrollOffset, -Self.stop) }
    /// 0 at rest, 1 once the phone has stopped: drives the extra blur that melts the frame into a soft glow
    /// when it is parked at the top (the resting phone looks exactly as before).
    private var parked: Double { min(1, Double(max(0, -settled)) / Double(Self.stop)) }
    private var fade: Double { max(0, 1 - Double(max(0, -settled)) / 520) }
    private var visible: Bool { active && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.86, 350)
            ZStack(alignment: .top) {
                if let theme = current ?? themes.first {
                    PhonePreviewFrame {
                        ZStack {
                            WallpaperArtwork(url: theme.artworkURL)
                            ReviewClockPlaceholder()
                            if !reduceMotion, let ready, ready.id == theme.id {
                                WallpaperMotionPreview(url: ready.file, playing: visible, loops: false, decorative: true,
                                                       onFinished: { advance(after: theme.id) },
                                                       onAvailabilityChange: { available in
                                                           // A video that cannot play is skipped instead of freezing the header.
                                                           if !available { advance(after: theme.id) }
                                                       })
                                    .id(theme.id)
                            }
                        }
                    }
                    .id(theme.id)
                    .transition(.opacity)
                    .frame(width: width, height: width / 0.477)
                    .padding(.top, 22 + Self.bleed)
                    .offset(y: max(-35, settled * 0.12))
                    .blur(radius: (1 - fade) * 10 + parked * parked * 26)
                    .opacity(fade)
                }
                PreviewMist().padding(.top, Self.bleed)
            }
            // Drawn in a taller area that reaches `bleed` pt above the header: the blurred phone fades out
            // there instead of being cut by a straight edge at the top of the header.
            .frame(width: geometry.size.width, height: geometry.size.height + Self.bleed, alignment: .top)
            .clipped()
            .mask(LinearGradient(stops: (0...40).map { step in
                let position = Double(step) / 40
                func smooth(_ value: Double) -> Double {
                    let t = min(1, max(0, value))
                    return t * t * (3 - 2 * t)
                }
                // Same bottom fade as before, measured on the original 350 pt header below the bleed area.
                let header = (position * (350 + Double(Self.bleed)) - Double(Self.bleed)) / 350
                // ...and a soft fade-in over the bleed area, so its own top edge never shows either.
                let top = smooth(position * (350 + Double(Self.bleed)) / (Double(Self.bleed) * 0.9))
                let alpha = (1 - smooth((header - 0.45) / 0.55)) * top
                return Gradient.Stop(color: .black.opacity(alpha), location: position)
            }, startPoint: .top, endPoint: .bottom))
            .offset(y: -Self.bleed)
            // Once parked, an opaque base under the blurred phone hides the wallpapers scrolling up; it reaches
            // just below the pinned "The collection" title and fades out there, so cards appear from that line down.
            .background(alignment: .top) {
                // Long eased fade (no visible edge): fully opaque behind the phone and the pinned title, then it
                // dissolves over ~200 pt so the wallpapers reappear gradually.
                // It also starts `bleed` pt higher with a soft fade-in, so its top edge never shows as a line.
                Theme.canvas
                    .frame(height: 500 + Self.bleed)
                    .mask(LinearGradient(stops: (0...60).map { step in
                        let position = Double(step) / 60
                        let y = position * (500 + Double(Self.bleed)) - Double(Self.bleed)      // pt from the header top
                        func smooth(_ v: Double) -> Double { let t = min(1, max(0, v)); return t * t * (3 - 2 * t) }
                        let alpha = smooth((y + Double(Self.bleed)) / (Double(Self.bleed) * 0.9)) * (1 - smooth((y - 250) / 250))
                        return Gradient.Stop(color: .black.opacity(alpha), location: position)
                    }, startPoint: .top, endPoint: .bottom))
                    .offset(y: -Self.bleed)
                    .opacity(0.97 * parked)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 350)
        // Past the stop point, cancel the scroll so the phone stays exactly where it stopped.
        .offset(y: max(0, -scrollOffset - Self.stop))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("catalog.showcase")
        .onChange(of: (current ?? themes.first)?.id, initial: true) { _, _ in
            onThemeChange(current ?? themes.first)
        }
        .task(id: themes.filter { $0.motionURL != nil }.prefix(recentPool).map { $0.id + ($0.motionURL?.absoluteString ?? "") }) {
            let candidates = Array(themes.filter { $0.motionURL != nil }.prefix(recentPool))
            let currentID = current?.id
            if playlist.isEmpty {
                // Open on a video that is already on the phone, so the header moves at once.
                var order = candidates.shuffled()
                if let cached = order.firstIndex(where: { $0.motionURL.map { ShowcaseVideoCache.isCached($0.deletingPathExtension().lastPathComponent) } ?? false }) { order.swapAt(0, cached) }
                playlist = order
            }
            else {
                // Adopt newly published previews without interrupting the active video.
                let ids = Set(playlist.map(\.id))
                playlist.append(contentsOf: candidates.filter { !ids.contains($0.id) })
                if let currentID, let position = playlist.firstIndex(where: { $0.id == currentID }) { index = position }
            }
        }
        .task(id: current?.id) {
            // Play at once: the downloaded copy if there is one, otherwise stream it (it is cached for next time).
            // Then prefetch the next video while this one plays.
            guard !reduceMotion, let theme = current, let remote = theme.motionURL else { return }
            let key = remote.deletingPathExtension().lastPathComponent
            ready = (theme.id, ShowcaseVideoCache.cachedFile(key) ?? remote)
            if let next = upcoming, let nextURL = next.motionURL {
                _ = try? await ShowcaseVideoCache.shared.localFile(for: nextURL.deletingPathExtension().lastPathComponent, remote: nextURL)
            }
        }
    }

    private func advance(after completedID: String) {
        // Ignore delayed callbacks from a video removed during the crossfade.
        guard current?.id == completedID, playlist.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.65)) {
            if index + 1 < playlist.count { index += 1 }
            else {
                // A new random order each round, never repeating the wallpaper that just played.
                var next = playlist.shuffled()
                if next.first?.id == completedID { next.swapAt(0, next.count - 1) }
                playlist = next
                index = 0
            }
        }
    }
}

/// The locked-screen clock exactly as the review videos draw it (iOS 26 tall numerals), shown over the
/// artwork while a video loads so nothing jumps when the video takes over.
struct ReviewClockPlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            let k = geometry.size.width / 390
            // Videos are 720x1566 and fill the frame (aspect fill), so the top is cropped by this much.
            let crop = max(0, (geometry.size.width * 1566 / 720 - geometry.size.height) / 2)
            ZStack(alignment: .top) {
                Text("Wednesday, October 21")
                    .font(.system(size: 19 * k, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: geometry.size.width, height: 26 * k)
                    .offset(y: 62 * k - crop)
                Text("9:41")
                    .font(.system(size: 96 * k, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.97), Color(white: 0.93).opacity(0.86), .white.opacity(0.78)],
                                                    startPoint: .top, endPoint: .bottom))
                    .frame(width: geometry.size.width, height: 112 * k)
                    .scaleEffect(x: 1, y: 1.75, anchor: .top)
                    .shadow(color: .black.opacity(0.18), radius: 10 * k, y: 2 * k)
                    .offset(y: 84 * k - crop)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
