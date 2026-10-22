// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import WallpaperInstaller

/// One tap starts one bounded attempt. PosterBoard must confirm the result.
struct ApplyWallpaperSheet: View {
    let package: ImportedPackage
    @Environment(\.dismiss) private var dismiss
    @Environment(EngineSession.self) private var engine
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(CatalogStore.self) private var catalog
    private var artworkURL: URL? {
        if case .loaded(let themes) = catalog.state, let theme = themes.first(where: { $0.sha256 == package.inspection.sha256 }) { return theme.artworkURL }
        return package.previewURL
    }
    @State private var showingEngine = false
    @State private var openingError: String?
    @State private var started = false
    @State private var busy = false
    @State private var error: String?
    @State private var receipt: WriteAttemptReceipt?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(statusTitle).font(.system(.largeTitle, weight: .semibold)).tracking(-0.8)
                        .padding(.top, 12)
                    let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(spacing: 22))
                    layout {
                        WallpaperFrame(previewURL: artworkURL, cornerRadius: 16)
                            .frame(height: 122)
                            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        VStack(alignment: .leading, spacing: 9) {
                            Text(package.displayName).font(.title2.weight(.semibold)).tracking(-0.5)
                            Text(L.text("Pantalla bloqueada")).font(.subheadline).foregroundStyle(.secondary)
                            Text(Format.bytes(Int64(clamping: package.inspection.compressedBytes)))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if started { Text(statusMessage).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3) }
                    if busy && started { ProgressView().controlSize(.large).frame(maxWidth: .infinity) }
                    if let error {
                        Label(L.message(error), systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.secondary).card()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(L.text("Preparación"))
                        preparationStep("Archivo verificado", detail: nil, symbol: "checkmark.circle")
                        Divider()
                        Button { showingEngine = true } label: {
                            HStack {
                                preparationStep("Configuración de PosterBoard", detail: engine.title, symbol: engine.savedUUID != nil ? "checkmark.circle" : "key")
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }.buttonStyle(.plain).disabled(busy || engine.state == .activating)
                            .accessibilityIdentifier("apply.engineDetails")
                        Divider()
                        preparationStep("Seleccionar en iOS", detail: L.text("Después de copiar, cierra PosterBoard desde el selector de apps y elige el tema en Colecciones."), symbol: "square.stack")
                    }.card()
                    if engine.state == .failed && !started {
                        Text(engine.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                    NavigationLink { DiagnosticView(package: package) } label: {
                        Label(L.text("Detalles del paquete"), systemImage: "doc.text.magnifyingglass")
                            .font(.footnote)
                    }.disabled(busy || engine.state == .activating)
                        .accessibilityIdentifier("apply.packageDetails")
                }.padding(.horizontal, Theme.gutter).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(L.text("Tu nuevo fondo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(L.text("Cerrar"))
                        .accessibilityIdentifier("apply.close")
                        .disabled(busy || engine.state == .activating)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if !started {
                        if !engine.isReady {
                            Button { showingEngine = true } label: {
                                Label(L.text("Configurar PosterBoard"), systemImage: "key")
                            }.buttonStyle(SecondaryButtonStyle())
                                .accessibilityIdentifier("apply.configure")
                        }
                        Button { Task { await applyOnce() } } label: {
                            Label(L.text("Aplicar fondo"), systemImage: "checkmark")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("apply.confirm")
                        .disabled(!engine.isReady)
                        #if targetEnvironment(simulator)
                        Text(L.text("La aplicación del fondo requiere un iPhone compatible."))
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        #else
                        Text(engine.isReady ? L.text("Se usará el UUID guardado. No se activará DarkSword.") : L.text("Configura el UUID una vez para añadir tus fondos."))
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        #endif
                    } else if receipt != nil {
                        Button { openGallery() } label: { Text(L.text("Abrir fondos de iOS")) }
                            .buttonStyle(PrimaryButtonStyle())
                    } else if error != nil {
                        Button { dismiss() } label: { Text(L.text("Volver al tema")) }.buttonStyle(PrimaryButtonStyle())
                    }
                    if started && !busy {
                        ShareLink(item: package.archiveURL) { Label(L.text("Compartir archivo"), systemImage: "square.and.arrow.up") }
                            .font(.subheadline)
                    }
                }
                .padding(Theme.gutter).background(Theme.canvas)
            }
        }
        .sheet(isPresented: $showingEngine) { EngineAccessSheet() }
        .interactiveDismissDisabled(busy || engine.state == .activating)
        .alert(L.text("No se pudo completar"), isPresented: Binding(get: { openingError != nil }, set: { if !$0 { openingError = nil } })) {
            Button(L.text("Aceptar"), role: .cancel) {}
        } message: { Text(L.message(openingError ?? "")) }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private var statusTitle: String {
        if !started { return L.text("Hazlo tuyo.") }
        if busy { return L.text("Preparando tu fondo") }
        if error != nil { return L.text("No se pudo completar") }
        return L.text(receipt?.descriptorVerified == true ? "Listo para seleccionar" : "Comprueba la galería")
    }
    private var statusMessage: String {
        if !started { return L.format("%@, en tu pantalla. Comprueba el diseño antes de continuar.", package.displayName) }
        if busy { return L.text("Coconut está preparando el tema para la galería de fondos de iOS.") }
        if error != nil { return L.text("Tu tema sigue guardado en la colección.") }
        if receipt?.descriptorVerified != true {
            return L.text("El método de Pocket Poster terminó sin error. Cierra PosterBoard desde el selector de apps y busca el tema en Ajustes → Fondo de pantalla → Añadir nuevo fondo → Colecciones. Coconut no puede verificar la copia con este acceso; si no aparece, revisa el UUID guardado.")
        }
        return L.text("La copia del descriptor se verificó. Cierra PosterBoard desde el selector de apps y busca el tema en Ajustes → Fondo de pantalla → Añadir nuevo fondo → Colecciones.")
    }
    private func preparationStep(_ title: String, detail: String?, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).font(.system(size: 20, weight: .light)).frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(L.text(title)).font(.subheadline.weight(.medium))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor private func openGallery() {
        if !PosterBoardLauncher.open() {
            openingError = L.text("No se pudo abrir la galería de iOS. Ábrela desde Ajustes → Fondo de pantalla.")
        }
    }

    @MainActor private func applyOnce() async {
        guard !started, engine.isReady else { return }
        started = true
        busy = true
        do {
            let access = try await engine.validatedAccess()
            let result = try await WallpaperApplySession().apply(
                archive: package.archiveURL,
                expectedSHA256: package.inspection.sha256,
                containerUUID: access.containerUUID,
                accessRoute: access.route)
            receipt = result
            // Match upstream: let the completed filesystem operation settle before
            // opening PosterBoard. Never reset collections or change language here.
            // Cancellation after a completed write must not turn it into a failed write.
            try? await Task.sleep(for: .milliseconds(350))
            busy = false
            if !Task.isCancelled { openGallery() }
        } catch {
            self.error = error.localizedDescription
            busy = false
        }
    }
}

struct ExportPackageSheet: View {
    let package: ImportedPackage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(Theme.accent)
                Text(L.format("%@ está preparado", package.displayName)).font(.headline)
                Text(L.text("Coconut verificó el archivo y su estructura. Puedes compartir el .tendies desde el iPhone."))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                ShareLink(item: package.archiveURL) {
                    Label(L.text("Compartir .tendies"), systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(L.text("Exportar tema"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.text("Cerrar")) { dismiss() } }
            }
        }
    }
}
