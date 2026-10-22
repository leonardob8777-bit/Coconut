// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

@MainActor @Observable
final class GalleryPreferences {
    private(set) var favorites: Set<String>
    private(set) var recentSearches: [String]
    private var favoriteDates: [String: Double]
    private let defaults: UserDefaults
    private let now: () -> Date
    var autoplayPreviews: Bool {
        didSet { defaults.set(autoplayPreviews, forKey: "Coconut.previewAutoplay") }
    }
    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        recentSearches = Array((defaults.stringArray(forKey: "Coconut.recentSearches") ?? []).filter { !ThemeSearch.normalized($0).isEmpty }.prefix(6))
        if let snapshot = defaults.dictionary(forKey: "Coconut.favoritesState"),
           let ids = snapshot["ids"] as? [String] {
            let restored = Set(ids)
            favorites = restored
            favoriteDates = (snapshot["addedAt"] as? [String: Double] ?? [:]).filter { restored.contains($0.key) && $0.value.isFinite }
        } else {
            favorites = Set(defaults.stringArray(forKey: "Coconut.favoriteThemes") ?? [])
            favoriteDates = [:] // Existing favorites have no known timestamp; do not invent one.
        }
        autoplayPreviews = defaults.object(forKey: "Coconut.previewAutoplay") == nil ? true : defaults.bool(forKey: "Coconut.previewAutoplay")
    }
    func rememberSearch(_ query: String) {
        let cleaned = ThemeSearch.normalized(query)
        guard !cleaned.isEmpty else { return }
        recentSearches = [cleaned] + recentSearches.filter {
            $0.compare(cleaned, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        }
        recentSearches = Array(recentSearches.prefix(6))
        defaults.set(recentSearches, forKey: "Coconut.recentSearches")
    }
    func clearRecentSearches() {
        recentSearches = []
        defaults.removeObject(forKey: "Coconut.recentSearches")
    }
    func favoriteAddedAt(_ id: String) -> Date? { favoriteDates[id].map(Date.init(timeIntervalSince1970:)) }
    func toggle(_ id: String) {
        if favorites.remove(id) != nil { favoriteDates.removeValue(forKey: id) }
        else { favorites.insert(id); favoriteDates[id] = now().timeIntervalSince1970 }
        defaults.set(["ids": Array(favorites).sorted(), "addedAt": favoriteDates], forKey: "Coconut.favoritesState")
        defaults.set(Array(favorites).sorted(), forKey: "Coconut.favoriteThemes")
    }
}

enum ThemeCollection: String, CaseIterable, Identifiable {
    case all = "Todos", art = "Arte", nature = "Naturaleza", characters = "Personajes", abstract = "Abstractos"
    var id: String {
        switch self { case .all: "all"; case .art: "art"; case .nature: "nature"; case .characters: "characters"; case .abstract: "abstract" }
    }
    @MainActor var title: String { L.text(rawValue) }
}

extension CatalogTheme {
    @MainActor var displayName: String { L.text(name) }
    /// The most epic themes carry a "HOT" label in the collection.
    static let hotIDs: Set<String> = ["fr-focus", "fr-noexcuses", "ar-pinkfriday", "ar-gnx", "ar-redbottoms", "ar-candyshop",
                                      "ob-champion", "ob-king", "ob-highlife", "ob-kush", "ob-supercar", "ep-chandelier",
                                      "ep-rain", "ep-diamond", "kn-wall", "kn-thunder", "is-dunk", "cu-disco", "cu-rolex",
                                      "pr-cr7", "sc-spider"]
    var isHot: Bool { Self.hotIDs.contains(id) }
    var collection: ThemeCollection {
        switch id {
        case "cabana", "capibara", "leona", "blanca", "rosa": .nature
        case "arcoiris", "batman", "baymax", "deadpool", "invincible", "mono": .characters
        case "calma", "escaner", "maniqui", "torre": .abstract
        default: .art
        }
    }
    @MainActor var editorialLine: String {
        switch id {
        case "polillas": L.text("La belleza\nde lo sutil.")
        case "niebla": L.text("Menos ruido.\nMás presencia.")
        case "rostro": L.text("Entre luz\ny silencio.")
        default: L.text("Otra forma\nde mirar.")
        }
    }
    @MainActor var shortDescription: String {
        switch id {
        case "polillas": L.text("Luz suave y movimiento suspendido.")
        case "niebla": L.text("Un retrato en tonos esenciales.")
        case "rostro": L.text("Texturas que dejan respirar la pantalla.")
        default: L.text("Una nueva perspectiva para tu pantalla.")
        }
    }
    /// Clean renders are optional so older remote catalogs continue to work.
    var artworkURL: URL? {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["COCONUT_PREVIEW_ARTWORK_URL"], let url = URL(string: override) { return url }
        #endif
        guard previewURL?.isFileURL == true else { return previewURL }
        return Bundle.main.url(forResource: id + "-artwork", withExtension: "jpg", subdirectory: "BundledCatalog") ?? previewURL
    }
    var motionURL: URL? {
        #if DEBUG
        // Simulator QA can exercise media failure without damaging a bundled theme.
        if let override = ProcessInfo.processInfo.environment["COCONUT_PREVIEW_VIDEO_URL"], let url = URL(string: override) { return url }
        #endif
        return Bundle.main.url(forResource: id + "-motion", withExtension: "mp4", subdirectory: "BundledCatalog") ?? previewVideoURL
    }
    /// Short, light loop (~8 s, ~0.5 MB) for the opened theme: shows what it does without weighing on the phone.
    /// The long review with the clock (`motionURL`) only plays in the header showcase. The loop is published
    /// next to the review (`<id>-loop.mp4` beside `<id>-motion.mp4`); older catalogs fall back to the review.
    var loopURL: URL? {
        if let bundled = Bundle.main.url(forResource: id + "-loop", withExtension: "mp4", subdirectory: "BundledCatalog") { return bundled }
        // <id>-motion[-vN].mp4 -> <id>-loop[-vN].mp4
        guard let motion = motionURL, !motion.isFileURL, motion.lastPathComponent.hasPrefix(id + "-motion") else { return motionURL }
        let loopName = id + "-loop" + motion.lastPathComponent.dropFirst((id + "-motion").count)
        return motion.deletingLastPathComponent().appendingPathComponent(loopName)
    }
    var hasCleanArtwork: Bool { artworkURL?.lastPathComponent == id + "-artwork.jpg" }
    var fullResolutionArtworkURL: URL? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["COCONUT_PREVIEW_ARTWORK_URL"] != nil { return artworkURL }
        #endif
        return fullResolutionPreviewURL ?? artworkURL
    }
}

struct CollectionFilters: View {
    @Binding var selection: ThemeCollection
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ThemeCollection.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = item }
                    } label: {
                        Text(item.title).font(.subheadline.weight(selection == item ? .semibold : .medium))
                            .padding(.horizontal, 18).frame(minHeight: 42)
                            .foregroundStyle(selection == item ? Theme.inverseInk : Theme.ink.opacity(0.65))
                            .background(selection == item ? Theme.ink : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == item ? .isSelected : [])
                    .accessibilityIdentifier("catalog.filter.\(item.id)")
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct FavoriteButton: View {
    let id: String
    var wallpaperName: String? = nil
    var accessibilityPrefix = "favorite"
    var targetSize: CGFloat = 24
    @Environment(GalleryPreferences.self) private var preferences
    private var isFavorite: Bool { preferences.favorites.contains(id) }
    private var label: String {
        if let wallpaperName {
            return L.format(isFavorite ? "Quitar %@ de favoritos" : "Añadir %@ a favoritos", wallpaperName)
        }
        return L.text(isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
    }
    var body: some View {
        Button { preferences.toggle(id) } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .regular))
                .frame(width: targetSize, height: targetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: preferences.favorites)
        .accessibilityLabel(label)
        .accessibilityIdentifier("\(accessibilityPrefix).\(id)")
    }
}

struct WallpaperFrame: View {
    let previewURL: URL?
    var cornerRadius: CGFloat = 28
    var showsPlaceholder = true
    var body: some View {
        WallpaperArtwork(url: previewURL).aspectRatio(390.0 / 844.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.primary.opacity(0.07), lineWidth: 0.5))
    }
}
