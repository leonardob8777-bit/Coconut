// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(PackageLibrary.self) private var library
    @Environment(CatalogStore.self) private var catalog
    @Environment(GalleryPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 42.0
    @AppStorage("Coconut.librarySort") private var sortOrder = "recent"
    @State private var query = ""
    @State private var importing = false
    @State private var filter = LibraryFilter.saved
    @State private var selectedTheme: CatalogTheme?
    @State private var selectedPackage: ImportedPackage?
    @State private var removing: ImportedPackage?
    private enum LibraryFilter: String, CaseIterable { case saved = "Guardados", favorites = "Favoritos" }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 14), count: dynamicType.isAccessibilitySize ? 1 : 2) }
    private var themes: [CatalogTheme] {
        if case .loaded(let themes) = catalog.state { return themes }
        return []
    }
    private var visibleThemes: [CatalogTheme] {
        themes.filter { theme in
            (filter == .favorites ? preferences.favorites.contains(theme.id) : library.package(withSHA256: theme.sha256) != nil)
                && ThemeSearch.matches(theme, query: query)
        }.sorted { lhs, rhs in
            if sortOrder == "name" {
                return LibraryOrdering.namePrecedes(lhs.displayName, rhs.displayName, lhsID: lhs.id, rhsID: rhs.id)
            }
            let left = (filter == .favorites ? preferences.favoriteAddedAt(lhs.id) : library.package(withSHA256: lhs.sha256)?.importedAt) ?? .distantPast
            let right = (filter == .favorites ? preferences.favoriteAddedAt(rhs.id) : library.package(withSHA256: rhs.sha256)?.importedAt) ?? .distantPast
            return left == right ? lhs.id < rhs.id : left > right
        }
    }
    private var imported: [ImportedPackage] {
        library.packages.filter { package in
            !themes.contains { $0.sha256 == package.inspection.sha256 }
                && ThemeSearch.matches(package, query: query)
        }.sorted { lhs, rhs in
            if sortOrder == "name" { return LibraryOrdering.namePrecedes(lhs.displayName, rhs.displayName, lhsID: lhs.id.uuidString, rhsID: rhs.id.uuidString) }
            return lhs.importedAt == rhs.importedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.importedAt > rhs.importedAt
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.text("Tu espacio."))
                            .font(.system(size: titleSize, weight: .semibold)).tracking(-1.7)
                        Text(L.text("Lo que eliges, en un solo lugar."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(collectionSummary)
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("library.summary")
                        Spacer()
                    }
                    Picker(L.text("Colección"), selection: $filter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { Text(L.text($0.rawValue)).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("library.filter")
                    if visibleThemes.isEmpty && (filter == .favorites || imported.isEmpty) {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 26) {
                            ForEach(visibleThemes) { theme in
                                GalleryThemeCard(theme: theme, isSaved: library.package(withSHA256: theme.sha256) != nil) {
                                    selectedTheme = theme
                                }
                                .contextMenu {
                                    Button(preferences.favorites.contains(theme.id) ? L.text("Quitar de favoritos") : L.text("Añadir a favoritos"), systemImage: "heart") { preferences.toggle(theme.id) }
                                    if let package = library.package(withSHA256: theme.sha256) {
                                        Button { selectedPackage = package } label: { Label(L.text("Ver archivo guardado"), systemImage: "doc") }
                                            .accessibilityIdentifier("library.file")
                                        ShareLink(item: package.archiveURL) { Label(L.text("Compartir tema"), systemImage: "square.and.arrow.up") }
                                        Button(L.text("Eliminar de guardados"), systemImage: "trash", role: .destructive) { removing = package }
                                    }
                                }
                            }
                        }
                        if filter == .saved && !imported.isEmpty {
                            SectionTitle(L.text("IMPORTADOS"))
                            ForEach(imported) { package in
                                Button { selectedPackage = package } label: {
                                    HStack(spacing: 16) {
                                        WallpaperFrame(previewURL: package.previewURL, cornerRadius: 10).frame(width: 48)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(package.displayName).font(.subheadline.weight(.semibold))
                                            Text(Format.bytes(Int64(package.inspection.compressedBytes)))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.subheadline).foregroundStyle(.secondary)
                                    }.card()
                                }.buttonStyle(.plain)
                                .accessibilityIdentifier("library.imported.\(package.id)")
                                .contextMenu {
                                    ShareLink(item: package.archiveURL) { Label(L.text("Compartir tema"), systemImage: "square.and.arrow.up") }
                                    Button(L.text("Eliminar"), systemImage: "trash", role: .destructive) { removing = package }
                                }
                            }
                        }
                    }
                    importButton
                }
                .padding(.horizontal, Theme.gutter).padding(.top, 16).padding(.bottom, 30)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(L.text("Mi colección"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { sortOrder = "recent" } label: { Label(L.text("Más recientes"), systemImage: sortOrder == "recent" ? "checkmark" : "clock") }
                            .accessibilityIdentifier("library.sort.recent")
                        Button { sortOrder = "name" } label: { Label(L.text("Nombre"), systemImage: sortOrder == "name" ? "checkmark" : "textformat.abc") }
                            .accessibilityIdentifier("library.sort.name")
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                    .accessibilityLabel(L.text("Ordenar colección"))
                    .accessibilityIdentifier("library.sort")
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(L.text("Importar .tendies"))
                        .accessibilityIdentifier("library.import")
                        .disabled(library.busy)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L.text("Buscar en tu colección"))
            .confirmationDialog(L.text("¿Eliminar este fondo de guardados?"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button(L.text("Eliminar"), role: .destructive) { if let removing { library.remove(removing) }; removing = nil }
                Button(L.text("Cancelar"), role: .cancel) { removing = nil }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .data],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .failure(let error): library.lastError = error.localizedDescription
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { if let id = await library.importPackage(at: url) { router.showImported(id) } }
                }
            }
            .onChange(of: router.focusedPackageID, initial: true) { _, id in
                if let id {
                    filter = .saved
                    query = ""
                    if let package = library.packages.first(where: { $0.id == id }) {
                        if let theme = themes.first(where: { $0.sha256.caseInsensitiveCompare(package.inspection.sha256) == .orderedSame }) {
                            selectedTheme = theme
                        } else {
                            selectedPackage = package
                        }
                    }
                    router.focusedPackageID = nil
                }
            }
        }
        .sheet(item: $selectedTheme) { WallpaperDetailView(theme: $0) }
        .sheet(item: $selectedPackage) { SavedPackageView(package: $0) }
    }

    private var collectionSummary: String {
        if filter == .favorites {
            let count = themes.filter { preferences.favorites.contains($0.id) }.count
            return L.format(count == 1 ? "%@ favorito" : "%@ favoritos", String(count))
        }
        return L.format(library.packages.count == 1 ? "%@ guardado · %@" : "%@ guardados · %@", String(library.packages.count), Format.bytes(library.storedBytes))
    }

    @ViewBuilder private var emptyState: some View {
        if !ThemeSearch.normalized(query).isEmpty {
            VStack(spacing: 12) {
                QuietEmptyState(symbol: "magnifyingglass", title: L.text("No hay coincidencias"), message: L.text("Prueba otro nombre o colección."))
                Button(L.text("Borrar búsqueda")) { query = "" }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("library.clearSearch")
            }
        } else {
            VStack(spacing: 16) {
                QuietEmptyState(symbol: filter == .favorites ? "heart" : "square.stack", title: filter == .favorites ? L.text("Haz sitio a tus favoritos") : L.text("Empieza tu colección"), message: filter == .favorites ? L.text("Toca el corazón de un tema para encontrarlo aquí.") : L.text("Guarda los temas que te gustan o importa los tuyos."))
                Button(L.text("Explorar temas")) { router.tab = .download }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("library.explore")
            }.padding(.vertical, 26)
        }
    }
    private var importButton: some View {
        Button { importing = true } label: {
            HStack(spacing: 15) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 21, weight: .light))
                VStack(alignment: .leading, spacing: 5) {
                    Text(L.text(library.busy ? "Importando tema…" : "Trae tu propio fondo")).font(.subheadline.weight(.semibold))
                    Text(L.text("Importar un archivo .tendies")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if library.busy { ProgressView() }
                else { Image(systemName: "plus").font(.system(size: 15, weight: .medium)) }
            }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain).disabled(library.busy)
    }
}
