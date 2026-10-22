// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import ImageIO

/// Decode off the main actor and share a bounded cache across gallery and preview.
actor ArtworkRepository {
    static let shared = ArtworkRepository()
    private let cache = NSCache<NSURL, CGImage>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(at url: URL) async throws -> CGImage {
        try Task.checkCancellation()
        if let image = cache.object(forKey: url as NSURL) { return image }
        let local: URL
        if url.isFileURL { local = url }
        else {
            guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { throw URLError(.unsupportedURL) }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (temporary, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                try? FileManager.default.removeItem(at: temporary)
                throw URLError(.badServerResponse)
            }
            local = temporary
        }
        defer { if !url.isFileURL { try? FileManager.default.removeItem(at: local) } }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(local as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 3000,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        cache.setObject(image, forKey: url as NSURL, cost: image.bytesPerRow * image.height)
        return image
    }
}

/// Loading and failure retain the same portrait geometry as the finished artwork.
struct WallpaperArtwork: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var allowsRetry = false
    var onAvailabilityChange: (Bool) -> Void = { _ in }
    @State private var phase = Phase.loading
    @State private var attempt = 0
    private enum Phase { case loading, ready(CGImage), unavailable }
    private struct Request: Equatable { let url: URL?; let attempt: Int }

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch phase {
                case .ready(let image):
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
                case .loading:
                    Theme.surface.overlay {
                        ProgressView().tint(.secondary)
                            .accessibilityLabel(L.text("Cargando imagen…"))
                    }
                case .unavailable:
                    Theme.surface.overlay {
                        VStack(spacing: 12) {
                            if geometry.size.width >= 160 || !allowsRetry {
                                Image(systemName: "photo").font(.system(size: 24, weight: .ultraLight)).foregroundStyle(.secondary)
                            }
                            if allowsRetry && geometry.size.width >= 160 {
                                Text(L.text("Vista previa no disponible")).font(.subheadline.weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .accessibilityIdentifier("preview.artwork.failure")
                                if url != nil {
                                    Button { attempt += 1 } label: {
                                        Label(L.text("Volver a intentar"), systemImage: "arrow.clockwise")
                                            .font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
                                    }
                                    .buttonStyle(.plain).coconutGlass()
                                    .accessibilityIdentifier("preview.artwork.retry")
                                }
                            } else if allowsRetry && url != nil {
                                Button { attempt += 1 } label: {
                                    Image(systemName: "arrow.clockwise").font(.system(size: 18, weight: .medium))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).coconutGlass()
                                .accessibilityLabel(L.text("Volver a intentar"))
                                .accessibilityHint(L.text("Vista previa no disponible"))
                                .accessibilityIdentifier("preview.artwork.retry")
                            }
                        }.padding(18)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityElement(children: .contain)
        .accessibilityHidden(!allowsRetry)
        .task(id: Request(url: url, attempt: attempt)) {
            phase = .loading
            onAvailabilityChange(false)
            guard let url else { phase = .unavailable; return }
            do {
                let image = try await ArtworkRepository.shared.image(at: url)
                try Task.checkCancellation()
                phase = .ready(image)
                onAvailabilityChange(true)
            } catch {
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }
}
