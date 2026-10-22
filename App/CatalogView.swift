// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct CatalogView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(AppRouter.self) private var router
    @Environment(EngineSession.self) private var engine
    @Environment(PackageLibrary.self) private var library
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var selection: ThemeCollection = .all
    @AppStorage("Coconut.catalogSort") private var sortOrder = "curated"
    @State private var onlyMotion = false
    @State private var hideSaved = false
    @State private var showingEngine = false
    @State private var searching = false
    @State private var selectedTheme: CatalogTheme?
    @State private var backdropTheme: CatalogTheme?
    @State private var heroOffset: CGFloat = 0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 14), count: dynamicType.isAccessibilitySize ? 1 : 2) }
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 42.0

    private var themes: [CatalogTheme] {
        if case .loaded(let themes) = catalog.state {
            let order = ["niebla", "papel", "rostro", "blanca", "pipa", "polillas", "leona", "maniqui", "fuego", "eco", "torre", "rosa", "cabana", "capibara", "globos", "escalera", "david", "calma", "casco", "nike", "escaner", "batman", "baymax", "deadpool", "mono", "invincible", "arcoiris"]
            let ranks = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
            // Los temas con giroscopio (los más nuevos) van primero, en el orden del catálogo; después la selección fija
            // y luego el resto. El índice del catálogo desempata para que el orden sea siempre el mismo.
            func rank(_ theme: CatalogTheme, _ index: Int) -> (Int, Int) {
                if theme.packageURL.absoluteString.contains("gyroscope-") { return (0, index) }
                if let pinned = ranks[theme.id] { return (1, pinned) }
                return (2, index)
            }
            return themes.enumerated().sorted { rank($0.element, $0.offset) < rank($1.element, $1.offset) }.map(\.element)
        }
        return []
    }
    private var filtered: [CatalogTheme] {
        let result = themes.filter {
            (selection == .all || $0.collection == selection)
                && (!onlyMotion || $0.motionURL != nil)
                && (!hideSaved || library.package(withSHA256: $0.sha256) == nil)
        }
        return sortOrder == "name" ? result.sorted { LibraryOrdering.namePrecedes($0.displayName, $1.displayName, lhsID: $0.id, rhsID: $1.id) } : result
    }
    private var hasFilters: Bool { onlyMotion || hideSaved }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Scrolls up with the page like before, then stops at a fixed spot and stays there playing
                    // (see WallpaperShowcase.stop); the collection keeps scrolling over it.
                    WallpaperShowcase(themes: themes, scrollOffset: heroOffset,
                                      active: router.tab == .download && selectedTheme == nil && !searching && !showingEngine,
                                      onThemeChange: { backdropTheme = $0 })
                        // Preference keys stopped updating while scrolling; onGeometryChange reports every frame.
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("catalog.scroll")).minY } action: { heroOffset = $0 }
                        .zIndex(2)   // the wallpapers pass under the phone
                    // "The collection" scrolls up with the phone and then stays pinned just under it, sharp, above the
                    // glow; its unshifted position is the phone's position + its height (350) + the stack spacing (28).
                    collectionHeader
                        .offset(y: max(0, 12 - (heroOffset + 350 + 28)))
                        .zIndex(3)
                    collection
                }
                .padding(.top, 6).padding(.bottom, 30)
            }
            .coordinateSpace(name: "catalog.scroll")
            .modifier(NoTopScrollEdgeBand())
            .background {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Theme.canvas
                        WallpaperAtmosphere(url: (backdropTheme ?? themes.first)?.artworkURL)
                            .frame(height: 560 + geometry.safeAreaInsets.top)
                            .mask(LinearGradient(stops: (0...40).map { step in
                                let position = Double(step) / 40
                                let t = min(1, max(0, (position - 0.5) / 0.5))
                                return Gradient.Stop(color: .black.opacity(1 - t * t * (3 - 2 * t)), location: position)
                            }, startPoint: .top, endPoint: .bottom))
                            .opacity(max(0, 1 - Double(min(WallpaperShowcase.stop, max(0, -heroOffset))) / 350))
                    }.ignoresSafeArea()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Coconut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Wordmark: the coconut sits half tucked under the "C".
                    Text("Coconut")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                        .background(alignment: .leading) {
                            Image("CoconutMark").resizable().scaledToFit()
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-12))
                                .offset(x: -13, y: 3)
                                .accessibilityHidden(true)
                        }
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingEngine = true } label: { Image(systemName: engine.savedUUID != nil ? "checkmark.circle" : "key") }
                        .accessibilityLabel(L.text("Configurar PosterBoard"))
                        .accessibilityIdentifier("catalog.engine")
                        .accessibilityValue(engine.title)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { searching = true } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel(L.text("Buscar temas"))
                    NavigationLink { CoconutSettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(L.text("Ajustes"))
                        .accessibilityIdentifier("catalog.settings")
                }
            }
            .refreshable { await catalog.load() }
        }
        .task { if themes.isEmpty { await catalog.load() } }
        .sheet(isPresented: $showingEngine) { EngineAccessSheet() }
        .sheet(isPresented: $searching) { CatalogSearchView(themes: themes) }
        .sheet(item: $selectedTheme) { WallpaperDetailView(theme: $0) }
    }

    private var collectionHeader: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(selection == .all ? L.text("La colección") : selection.title)
                        .font(.title2.weight(.semibold)).tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Menu {
                        Toggle(L.text("Solo con movimiento"), isOn: $onlyMotion).accessibilityIdentifier("catalog.onlyMotion")
                        Toggle(L.text("Ocultar guardados"), isOn: $hideSaved).accessibilityIdentifier("catalog.hideSaved")
                        Divider()
                        Button { sortOrder = "curated" } label: { Label(L.text("Selección Coconut"), systemImage: sortOrder == "curated" ? "checkmark" : "square.grid.2x2") }
                            .accessibilityIdentifier("catalog.sort.curated")
                        Button { sortOrder = "name" } label: { Label(L.text("Nombre"), systemImage: sortOrder == "name" ? "checkmark" : "textformat.abc") }
                            .accessibilityIdentifier("catalog.sort.name")
                    } label: { Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel(L.text("Filtrar colección")).accessibilityIdentifier("catalog.filters")
                }
                Text(L.format(filtered.count == 1 ? "%@ tema" : "%@ temas", String(filtered.count)))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("catalog.resultCount")
            }
            .padding(.horizontal, Theme.gutter)
    }

    @ViewBuilder private var collection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if hasFilters {
                VStack(alignment: .leading, spacing: 8) {
                    let layout = dynamicType.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        if onlyMotion {
                            filterChip("Solo con movimiento", identifier: "catalog.removeMotion") { onlyMotion = false }
                        }
                        if hideSaved {
                            filterChip("Ocultar guardados", identifier: "catalog.removeHiddenSaved") { hideSaved = false }
                        }
                    }
                    Button(L.text("Restablecer")) { onlyMotion = false; hideSaved = false }
                        .font(.caption.weight(.semibold)).frame(minHeight: 44)
                        .accessibilityIdentifier("catalog.resetFilters")
                }
            }
            if filtered.isEmpty {
                if case .failed(let error) = catalog.state {
                    QuietEmptyState(symbol: "wifi.exclamationmark", title: L.text("La colección no está disponible"), message: error)
                    Button(L.text("Volver a intentar")) { Task { await catalog.load() } }.buttonStyle(SecondaryButtonStyle())
                } else if case .loading = catalog.state {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                } else if hasFilters {
                    QuietEmptyState(symbol: "magnifyingglass", title: L.text("Otra búsqueda, otra perspectiva"), message: L.text("Prueba a restablecer los filtros."))
                } else {
                    QuietEmptyState(symbol: "square.grid.2x2", title: L.text("Una colección en camino"), message: L.text("Los nuevos temas aparecerán aquí."))
                }
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                    ForEach(filtered) { theme in
                        GalleryThemeCard(theme: theme, isSaved: library.package(withSHA256: theme.sha256) != nil) {
                            selectedTheme = theme
                        }
                    }
                }
            }
        }.padding(.horizontal, Theme.gutter)
    }

    private func filterChip(_ title: String, identifier: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 8) {
                Text(L.text(title)).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "xmark").font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
            .padding(.vertical, 4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.format("Quitar filtro: %@", L.text(title)))
        .accessibilityIdentifier(identifier)
    }
}

struct GalleryThemeCard: View {
    let theme: CatalogTheme
    var isSaved = false
    var accessibilityPrefix = "catalog"
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicType
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button(action: action) {
                WallpaperArtwork(url: theme.artworkURL)
                    .aspectRatio(390.0 / 844.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    .overlay(alignment: .topLeading) {
                        if theme.isHot { HotBadge().padding(9) }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if theme.motionURL != nil {
                            Image(systemName: "livephoto").font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white).padding(11)
                                .shadow(color: .black.opacity(0.5), radius: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.format("Vista previa de %@", theme.displayName))
            .accessibilityValue(isSaved ? L.text("Guardado") : "")
            .accessibilityIdentifier("\(accessibilityPrefix).preview.\(theme.id)")
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName).font(.system(.subheadline, weight: .semibold))
                        .lineLimit(dynamicType.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSaved {
                        Label(L.text("Guardado"), systemImage: "checkmark.circle.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                FavoriteButton(id: theme.id, wallpaperName: theme.displayName,
                               accessibilityPrefix: "\(accessibilityPrefix).favorite", targetSize: 44)
            }.padding(.horizontal, 2)
        }
    }
}


private struct CatalogSearchView: View {
    let themes: [CatalogTheme]
    @Environment(\.dismiss) private var dismiss
    @Environment(PackageLibrary.self) private var library
    @Environment(GalleryPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var query = ""
    @State private var selected: CatalogTheme?
    private var results: [CatalogTheme] {
        themes.filter { ThemeSearch.matches($0, query: query) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(ThemeSearch.normalized(query).isEmpty ? L.text("Encuentra tu próximo fondo") : L.format(results.count == 1 ? "%@ resultado" : "%@ resultados", String(results.count)))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if ThemeSearch.normalized(query).isEmpty {
                        searchSuggestions
                    } else if results.isEmpty {
                        QuietEmptyState(symbol: "magnifyingglass", title: L.text("Prueba con otro nombre"), message: L.text("No hay temas que coincidan con tu búsqueda."))
                    }
                    if !ThemeSearch.normalized(query).isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: dynamicType.isAccessibilitySize ? 1 : 2), spacing: 24) {
                        ForEach(results) { theme in
                            GalleryThemeCard(theme: theme, isSaved: library.package(withSHA256: theme.sha256) != nil, accessibilityPrefix: "search") { preferences.rememberSearch(query); selected = theme }
                        }
                    }
                    }
                }.padding(Theme.gutter)
            }
            .background(Theme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L.text("Buscar")).navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L.text("Nombre o colección"))
            .onSubmit(of: .search) { preferences.rememberSearch(query) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(L.text("Cerrar búsqueda"))
                }
            }
            .sheet(item: $selected) { WallpaperDetailView(theme: $0) }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
    private var searchSuggestions: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !preferences.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionTitle(L.text("Búsquedas recientes"))
                        Button(L.text("Borrar")) { preferences.clearRecentSearches() }
                            .font(.caption.weight(.medium)).frame(minHeight: 44)
                            .accessibilityIdentifier("search.clearHistory")
                    }
                    ForEach(preferences.recentSearches, id: \.self) { recent in
                        Button { query = recent } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                Text(recent)
                                Spacer()
                                Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.secondary)
                            }.font(.subheadline).padding(.vertical, 12)
                        }.buttonStyle(.plain).accessibilityLabel(recent).accessibilityIdentifier("search.recent.\(recent)")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(L.text("Explora por colección"))
                ForEach(ThemeCollection.allCases.filter { $0 != .all }) { collection in
                    Button { query = collection.title } label: {
                        HStack {
                            Text(collection.title).font(.body.weight(.medium))
                            Spacer()
                            Text(String(themes.filter { $0.collection == collection }.count)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).accessibilityLabel(collection.title).accessibilityIdentifier("search.collection.\(collection.id)")
                }
            }
        }
    }

}

/// iOS 26 darkens content under the transparent navigation bar with a band that ends in a visible line while
/// scrolling; the header here supplies its own soft glow, so the system band is turned off.
private struct NoTopScrollEdgeBand: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.scrollEdgeEffectHidden(true, for: .top) } else { content }
    }
}

/// "HOT" label for the most epic themes.
struct HotBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 9, weight: .bold))
            Text("HOT").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.12), Color(red: 0.93, green: 0.11, blue: 0.29)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: Color(red: 0.95, green: 0.2, blue: 0.2).opacity(0.45), radius: 6, y: 2)
        .accessibilityLabel(Text("Hot"))
    }
}
