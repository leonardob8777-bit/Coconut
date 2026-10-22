// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import WallpaperInstaller

/// A visual presentation of the author's artwork, separate from installation state.
struct WallpaperDetailView: View {
    let selectedTheme: CatalogTheme
    private var theme: CatalogTheme {
        if case .loaded(let themes) = catalog.state, let current = themes.first(where: { $0.id == selectedTheme.id }) { return current }
        return selectedTheme
    }
    init(theme: CatalogTheme) { selectedTheme = theme }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(EngineSession.self) private var engine
    @Environment(PackageLibrary.self) private var library
    @Environment(CatalogStore.self) private var catalog
    @ScaledMetric(relativeTo: .title) private var themeNameSize = 27.0
    @State private var pendingAction = DetailAction.save
    @State private var downloadError: String?
    @State private var preparing = false
    @State private var canRetry = true
    @State private var immersive = false
    @State private var showingInfo = false
    @State private var removing = false
    @State private var comparing = false

    private var comparisonThemes: [CatalogTheme] {
        if case .loaded(let themes) = catalog.state { return themes }
        return [theme]
    }
    private var saved: ImportedPackage? { library.package(withSHA256: theme.sha256) }
    private enum DetailAction { case save, use }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 22) {
                        preview(height: dynamicType.isAccessibilitySize ? 180 : max(280, min(590, geometry.size.height - 90)))
                            .overlay(alignment: .bottomTrailing) {
                                Button { immersive = true } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 13, weight: .medium)).frame(width: 44, height: 44)
                                        .contentShape(Circle())
                                        .coconutGlass()
                                }
                                .buttonStyle(.plain).padding(10)
                                .accessibilityLabel(L.text("Ampliar vista previa"))
                                .accessibilityIdentifier("detail.expand")
                            }
                            .frame(maxWidth: .infinity)
                        title
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 16).padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
            }
            actions
        }
            .background(Color.clear)
            .alert(L.text("No se pudo completar"), isPresented: Binding(get: { downloadError != nil }, set: { if !$0 { downloadError = nil } })) {
                if canRetry { Button(L.text("Volver a intentar")) { perform(pendingAction) } }
                Button(L.text("Cancelar"), role: .cancel) { downloadError = nil }
            } message: { Text(L.message(downloadError ?? "")) }
            .confirmationDialog(L.text("¿Eliminar este fondo de guardados?"), isPresented: $removing, titleVisibility: .visible) {
                Button(L.text("Eliminar"), role: .destructive) { if let saved { library.remove(saved) } }
                Button(L.text("Cancelar"), role: .cancel) {}
            }
            .sheet(isPresented: $comparing) { WallpaperComparisonView(themes: comparisonThemes, initialID: theme.id) }
            .sheet(isPresented: $showingInfo) { WallpaperInfoSheet(theme: theme, package: saved) }
            .fullScreenCover(isPresented: $immersive) {
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()
                    GeometryReader { geometry in
                        let width = min(geometry.size.width, geometry.size.height * 390 / 844)
                        WallpaperPreviewSurface(theme: theme, motion: theme.loopURL != nil, showsClock: false, playing: !reduceMotion)
                            .frame(width: width, height: width * 844 / 390)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.ignoresSafeArea()
                    Button { immersive = false } label: {
                        Image(systemName: "xmark").font(.body.weight(.medium))
                            .frame(width: 44, height: 44).coconutGlass()
                    }
                    .buttonStyle(.plain).padding(24)
                    .accessibilityLabel(L.text("Cerrar vista completa"))
                }
                .preferredColorScheme(.dark).statusBarHidden(true)
            }
        .background { WallpaperAtmosphere(url: theme.artworkURL).ignoresSafeArea() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(36)
        .presentationBackground {
            if reduceTransparency { Theme.canvas }
            else { Rectangle().fill(.regularMaterial) }
        }

    }

    private var detailHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.medium)).frame(width: 44, height: 44)
            }
            .coconutGlass()
            .accessibilityLabel(L.text("Cerrar vista previa"))
            .accessibilityIdentifier("detail.close")
            .frame(width: 88, alignment: .leading)
            Spacer(minLength: 4)
            Text(theme.displayName).font(.headline).lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                FavoriteButton(id: theme.id)
                    Menu {
                        Button { showingInfo = true } label: { Label(L.text("Sobre este tema"), systemImage: "info.circle") }
                            .accessibilityIdentifier("detail.info")
                        Button { comparing = true } label: { Label(L.text("Comparar con otro tema"), systemImage: "rectangle.split.2x1") }
                            .disabled(comparisonThemes.count < 2).accessibilityIdentifier("detail.compare")
                        if let saved {
                            ShareLink(item: saved.archiveURL) { Label(L.text("Compartir tema"), systemImage: "square.and.arrow.up") }
                            Button(role: .destructive) { removing = true } label: { Label(L.text("Eliminar de guardados"), systemImage: "trash") }
                                .accessibilityIdentifier("detail.remove")
                        }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel(L.text("Más opciones"))
                    .accessibilityIdentifier("detail.more")

            }.coconutGlass()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.gutter).padding(.top, 14).padding(.bottom, 8)
    }

    private func preview(height: CGFloat) -> some View {
        PhonePreviewFrame {
            WallpaperPreviewSurface(theme: theme, motion: theme.loopURL != nil, showsClock: false,
                                    playing: !reduceMotion && !preparing && !immersive && !showingInfo && !comparing)
        }
        .frame(width: height * 0.477, height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.format("Vista previa de %@", theme.displayName))
    }

    private var title: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.displayName).font(.system(size: themeNameSize, weight: .semibold)).tracking(-0.7)
                Text(theme.collection.title)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let saved {
                ShareLink(item: saved.archiveURL) { Image(systemName: "square.and.arrow.up").font(.system(size: 20)).frame(width: 44, height: 44) }
                    .accessibilityLabel(L.text("Compartir tema"))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if preparing {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(L.text(pendingAction == .use ? "Preparando tu fondo" : "Guardando tema…"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("detail.preparing")
            }
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Button { perform(.save) } label: {
                    Label(saved == nil ? L.text("Guardar") : L.text("Guardado"), systemImage: saved == nil ? "plus" : "checkmark")
                }
                .buttonStyle(SecondaryButtonStyle()).frame(width: dynamicType.isAccessibilitySize ? nil : 135)
                .disabled(preparing || saved != nil)
                .accessibilityIdentifier("detail.save")
                Button {
                    perform(.use)
                } label: {
                    HStack(spacing: 9) {
                        Text(L.text("Aplicar"))
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).accessibilityHidden(true)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(preparing)
                .accessibilityIdentifier("detail.use")
            }

        }
        .padding(.horizontal, Theme.gutter).padding(.top, 16).padding(.bottom, 12)

    }

    @MainActor private func perform(_ action: DetailAction) {
        guard !preparing else { return }
        pendingAction = action
        downloadError = nil
        canRetry = true
        preparing = true
        Task {
            defer { preparing = false }
            do {
                let package: ImportedPackage
                if let saved { package = saved }
                else {
                    let id = try await catalog.download(theme, into: library)
                    guard let downloaded = library.packages.first(where: { $0.id == id }) else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    package = downloaded
                }
                if action == .use {
                    let access = try await engine.validatedAccess()
                    _ = try await WallpaperApplySession().apply(
                        archive: package.archiveURL,
                        expectedSHA256: package.inspection.sha256,
                        containerUUID: access.containerUUID,
                        accessRoute: access.route)
                    try? await Task.sleep(for: .milliseconds(350))
                    if !PosterBoardLauncher.open() {
                        canRetry = false
                        downloadError = L.text("No se pudo abrir la galería de iOS. Ábrela desde Ajustes → Fondo de pantalla.")
                    }
                }
            } catch { downloadError = error.localizedDescription }
        }
    }

}

/// The same composition is used in the card and full screen, including its optional clock.
private struct WallpaperPreviewSurface: View {
    let theme: CatalogTheme
    let motion: Bool
    let showsClock: Bool
    let playing: Bool
    var onVideoAvailability: (Bool) -> Void = { _ in }
    @State private var artworkAvailable = false
    var body: some View {
        ZStack {
            WallpaperArtwork(url: theme.fullResolutionArtworkURL, allowsRetry: !motion,
                             onAvailabilityChange: { artworkAvailable = $0 })
            if motion, let url = theme.loopURL {
                WallpaperMotionPreview(url: url, playing: playing, onAvailabilityChange: onVideoAvailability).id(url)
            }
            if showsClock && theme.hasCleanArtwork && artworkAvailable {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        Text(ReferenceClock.dateLabel)
                            .font(.system(size: geometry.size.width * 0.043, weight: .medium))
                        Text("9:41")
                            .font(.system(size: geometry.size.width * 0.235, weight: .medium, design: .rounded))
                            .tracking(-geometry.size.width * 0.01)
                    }
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.18), radius: 10, y: 2)
                    .frame(maxWidth: .infinity).padding(.top, geometry.size.height * 0.1)
                }.accessibilityHidden(true)
            }
        }
    }
}

@MainActor enum ReferenceClock {
    static var dateLabel: String {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9, minute: 41)) ?? .distantPast
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(AppLanguageStore.shared.locale))
    }
}

