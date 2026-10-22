// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import WallpaperPackageManager

/// Diagnóstico de un paquete importado: cifras, huella, lienzo y avisos.
struct DiagnosticView: View {
    @Environment(PackageLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    let package: ImportedPackage
    @State private var showingJSON = false
    @State private var showingExport = false

    private var inspection: Inspection { package.inspection }
    private var geometryNote: String? {
        guard let descriptor = inspection.descriptors.first,
              let packageClass = descriptor.logicalScreenClass,
              let deviceClass = DeviceInfo.logicalScreenClass,
              packageClass != deviceClass else { return nil }
        return L.format("El paquete declara %@; este iPhone usa %@. La diferencia de lienzo puede desplazar o recortar capas.", packageClass, deviceClass)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                stats
                if let geometryNote {
                    Label(geometryNote, systemImage: "ruler")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }

                VStack(spacing: 8) {
                    SectionTitle(L.text("Huella SHA-256"))
                    // Dos mitades fijas: así iOS no parte la huella con un guion.
                    Text(inspection.sha256.prefix(32) + "\n" + inspection.sha256.dropFirst(32))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .card()
                }

                VStack(spacing: 8) {
                    SectionTitle(L.text("Contenido"))
                    VStack(alignment: .leading, spacing: 12) {
                        if inspection.descriptors.isEmpty {
                            Text(L.text("No se encontró ningún descriptor."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(inspection.descriptors, id: \.relativePath) { descriptor in
                            HStack(spacing: 12) {
                                IconTile(systemName: "doc.text", size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(descriptor.provider)
                                        .font(.subheadline.weight(.semibold))
                                    Text(descriptor.relativePath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                    if let screenClass = descriptor.logicalScreenClass {
                                        Text(L.format("Lienzo %@ × %@ pt · %@", descriptor.canvasWidth.map(String.init) ?? "?", descriptor.canvasHeight.map(String.init) ?? "?", screenClass))
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                        }
                    }
                    .card()
                }

                VStack(spacing: 8) {
                    SectionTitle(L.text("Avisos"))
                    VStack(alignment: .leading, spacing: 12) {
                        if inspection.warnings.isEmpty {
                            Label(L.text("Sin avisos"), systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(inspection.warnings, id: \.self) { warning in
                            Label {
                                Text(L.message(warning)).font(.subheadline)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                            }
                        }
                    }
                    .card()
                }

                export

                DisclosureGroup(L.text("Informe completo (JSON)"), isExpanded: $showingJSON) {
                    Text(package.reportJSON)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .font(.subheadline)
                .card()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L.text("Diagnóstico"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExport) { ExportPackageSheet(package: package) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(L.text("Exportar diagnóstico"), item: package.reportJSON)
                    Button(L.text("Quitar de la lista"), systemImage: "trash", role: .destructive) {
                        library.remove(package)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(systemName: "shippingbox", size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(package.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(L.format("Importado el %@", package.importedAt.formatted(.dateTime.day().month().hour().minute().locale(AppLanguageStore.shared.locale))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            Stat(value: Format.bytes(Int64(inspection.compressedBytes)), label: L.text("Comprimido"))
            Divider().frame(height: 36)
            Stat(value: Format.bytes(Int64(clamping: inspection.expandedBytes)), label: L.text("Expandido"))
            Divider().frame(height: 36)
            Stat(value: "\(inspection.entryCount)", label: L.text("Archivos"))
        }
        .card(padding: 14)
    }

    private var export: some View {
        VStack(spacing: 10) {
            Button { showingExport = true } label: {
                Label(L.text("Compartir paquete"), systemImage: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text(L.text("Valida y comparte el .tendies desde el iPhone. La estructura del archivo no confirma que PosterBoard pueda instalarlo."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
