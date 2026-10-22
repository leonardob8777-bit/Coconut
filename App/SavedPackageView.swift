// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import WallpaperInstaller

/// A saved file is presented before the user chooses to enter installation.
struct SavedPackageView: View {
    let package: ImportedPackage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(EngineSession.self) private var engine
    @State private var applying = false
    @State private var applyError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let preview = package.previewURL {
                        WallpaperFrame(previewURL: preview, cornerRadius: 20)
                            .frame(width: dynamicType.isAccessibilitySize ? 80 : 120)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 40, weight: .ultraLight))
                            .frame(width: 100, height: 120)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                            .accessibilityHidden(true)
                    }
                    VStack(spacing: 8) {
                        Text(package.displayName).font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center).textSelection(.enabled)
                        Label(L.text("Guardado en tu iPhone"), systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if package.previewURL == nil {
                        Text(L.text("Este archivo no incluye una vista previa en Coconut."))
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L.text("Archivo")).foregroundStyle(.secondary)
                            Text(package.fileName).textSelection(.enabled)
                                .accessibilityIdentifier("package.filename")
                        }
                        Divider()
                        LabeledContent(L.text("Tamaño"), value: Format.bytes(Int64(clamping: package.inspection.compressedBytes)))
                        Divider()
                        LabeledContent(L.text("Añadido")) {
                            Text(package.importedAt, format: .dateTime.day().month(.wide).year())
                        }
                    }.font(.subheadline).card()
                    NavigationLink { DiagnosticView(package: package) } label: {
                        Label(L.text("Detalles del paquete"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("package.details")
                    ShareLink(item: package.archiveURL) {
                        Label(L.text("Compartir tema"), systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }.font(.subheadline).accessibilityIdentifier("package.share")
                }.padding(Theme.gutter).frame(maxWidth: .infinity)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(L.text("Archivo guardado")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.text("Cerrar"))
                        .accessibilityIdentifier("package.close")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { apply() } label: {
                    if applying { ProgressView() } else { Text(L.text("Aplicar")) }
                }.disabled(applying)
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("package.use")
                    .padding(.horizontal, Theme.gutter).padding(.vertical, 12)
                    .background(.regularMaterial)
            }
        }
        .presentationDragIndicator(.visible).presentationCornerRadius(32)
        .alert(L.text("No se pudo completar"), isPresented: Binding(get: { applyError != nil }, set: { if !$0 { applyError = nil } })) {
            Button(L.text("Cerrar"), role: .cancel) { applyError = nil }
        } message: { Text(L.message(applyError ?? "")) }
    }
    @MainActor private func apply() {
        guard !applying else { return }
        applying = true
        Task {
            defer { applying = false }
            do {
                let access = try await engine.validatedAccess()
                _ = try await WallpaperApplySession().apply(
                    archive: package.archiveURL, expectedSHA256: package.inspection.sha256,
                    containerUUID: access.containerUUID, accessRoute: access.route)
                try? await Task.sleep(for: .milliseconds(350))
                if !PosterBoardLauncher.open() {
                    applyError = L.text("No se pudo abrir la galería de iOS. Ábrela desde Ajustes → Fondo de pantalla.")
                }
            } catch { applyError = error.localizedDescription }
        }
    }

}
