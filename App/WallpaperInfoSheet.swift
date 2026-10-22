// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct WallpaperInfoSheet: View {
    let theme: CatalogTheme
    let package: ImportedPackage?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 20) {
                        WallpaperFrame(previewURL: theme.artworkURL, cornerRadius: 14).frame(width: 68)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(theme.displayName).font(.title2.weight(.semibold)).tracking(-0.5)
                            Text(theme.collection.title).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    VStack(spacing: 0) {
                        fact("Origen", value: L.text(theme.packageURL.isFileURL ? "Incluido en Coconut" : "Catálogo remoto"))
                        if let package {
                            Divider()
                            fact("Tamaño", value: Format.bytes(Int64(clamping: package.inspection.compressedBytes)))
                            if let descriptor = package.inspection.descriptors.first,
                               let width = descriptor.canvasWidth, let height = descriptor.canvasHeight {
                                Divider()
                                fact("Lienzo", value: "\(width) × \(height) pt")
                            }
                        }
                    }.card()
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(L.text("Vista de referencia"))
                        Text(L.text("El vídeo muestra el diseño original; no simula la instalación en iOS."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(L.text("El reloj es una referencia de vista previa y no modifica el paquete."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let package {
                        NavigationLink { DiagnosticView(package: package) } label: {
                            Label(L.text("Detalles del paquete"), systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("info.packageDetails")
                        ShareLink(item: package.archiveURL) { Label(L.text("Compartir tema"), systemImage: "square.and.arrow.up") }
                            .font(.subheadline).frame(maxWidth: .infinity)
                    } else {
                        Text(L.text("Guardar el tema permite consultar su paquete y su lienzo."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(Theme.gutter)
            }
            .background(Theme.canvas)
            .navigationTitle(L.text("Sobre este tema")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.text("Cerrar")).accessibilityIdentifier("info.close")
                }
            }
        }.presentationDragIndicator(.visible).presentationCornerRadius(32)
    }
    private func fact(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L.text(label)).foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value).multilineTextAlignment(.trailing)
        }.font(.subheadline).padding(.vertical, 13)
    }
}
