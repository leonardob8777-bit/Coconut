// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import CompatibilityManager

/// Ajustes: separa el alcance del motor Coconut de los rangos publicados por terceros.
struct CompatibilityView: View {
    private let assessment = DeviceInfo.assessment
    private let version = IOSVersion(DeviceInfo.systemVersion)
    @State private var showingAbout = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    SectionTitle(L.text("Este iPhone"))
                    summary
                }

                VStack(spacing: 8) {
                    SectionTitle(L.text("PosterBoard · rangos publicados"))
                    VStack(spacing: 0) {
                        ForEach(Array(VersionRange.all.enumerated()), id: \.offset) { index, range in
                            if index > 0 { Divider().padding(.leading, 16) }
                            VersionRow(range: range, isCurrent: version.map(range.contains) ?? false)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .card(padding: 0)
                    Text(L.text("Estos rangos describen referencias de Pocket Poster, no pruebas de Coconut. El acceso DarkSword integrado solo permite un intento en iPhone 16 Pro con iOS 18.6.2 (22G100); la aparición y selección del fondo siguen sin verificarse."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    SectionTitle(L.text("Qué puede hacer Coconut"))
                    VStack(alignment: .leading, spacing: 14) {
                        RequirementRow(text: L.text("Importar .tendies desde Archivos, sin Mac"), status: L.text("Disponible"))
                        RequirementRow(text: L.text("Comprobar ZIP, CRC, SHA-256 y estructura"), status: L.text("Disponible"))
                        RequirementRow(text: L.text("Leer el lienzo declarado por el tema"), status: L.text("Disponible"))
                        RequirementRow(text: L.text("Intentar añadir a PosterBoard sin Mac"), status: "Experimental")
                    }
                    .card()
                }

                if let assessment {
                    VStack(spacing: 8) {
                        SectionTitle(L.text("Fuentes"))
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(assessment.sourceURLs, id: \.self) { source in
                                if let url = URL(string: source) {
                                    Link(destination: url) {
                                        HStack {
                                            Text(url.path.isEmpty ? source : String(url.path.dropFirst()))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }
                        .card()
                    }
                }

                Button { showingAbout = true } label: {
                    HStack(spacing: 12) {
                        IconTile(systemName: "info.circle", size: 32)
                        Text(L.text("Acerca de y licencias"))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.canvas)
        .navigationTitle(L.text("Ajustes"))
        .sheet(isPresented: $showingAbout) { AboutView() }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(systemName: assessment?.evidence.symbol ?? "questionmark.circle",
                         tint: assessment?.evidence.tint ?? .secondary, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(assessment?.evidence.title ?? L.text("Versión no reconocida"))
                        .font(.title3.weight(.semibold))
                    Text("\(DeviceInfo.modelName) · iOS \(DeviceInfo.systemVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let assessment {
                Text(assessment.evidence.detail)
                    .font(.subheadline)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                FactRow(label: L.text("Probado con Coconut"),
                        value: assessment?.installationVerifiedByCoconut == true ? L.text("Sí") : L.text("Todavía no"))
                FactRow(label: L.text("Lienzo del iPhone"), value: DeviceInfo.logicalScreenClass ?? L.text("No disponible"))
                FactRow(label: L.text("Primera prueba"),
                        value: assessment?.matchesInitialExperimentalTarget == true ? L.text("Este iPhone") : "iPhone 16 Pro · 18.6.2")
                if DeviceInfo.isSimulator {
                    FactRow(label: L.text("Entorno"), value: L.text("Simulador"))
                }
            }
        }
        .card()
    }
}

/// Un tramo de versiones de la tabla.
struct VersionRange: Sendable {
    let label: String
    let evidence: SupportEvidence
    let contains: @Sendable (IOSVersion) -> Bool

    static let all: [VersionRange] = [
        .init(label: "15 y anteriores", evidence: .outsidePublishedScope) { $0.major <= 15 },
        .init(label: "16.x", evidence: .preliminary) { $0.major == 16 },
        .init(label: "17.x", evidence: .announcedCandidate) { $0.major == 17 },
        .init(label: "18.0 – 18.7.4", evidence: .announcedCandidate) { $0.major == 18 && $0 < IOSVersion("18.7.5")! },
        .init(label: "18.7.5 y posteriores", evidence: .patchedAccordingToUpstream) { $0.major == 18 && $0 >= IOSVersion("18.7.5")! },
        .init(label: "26.0 – 26.1", evidence: .announcedCandidate) { $0.major == 26 && $0 < IOSVersion("26.2")! },
        .init(label: "26.2 y posteriores", evidence: .patchedAccordingToUpstream) { $0.major == 26 && $0 >= IOSVersion("26.2")! },
        .init(label: "27 y posteriores", evidence: .outsidePublishedScope) { $0.major >= 27 },
    ]
}

private struct VersionRow: View {
    let range: VersionRange
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(range.evidence.tint)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("iOS \(L.text(range.label))")
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                if isCurrent {
                    Text(L.text("Tu versión"))
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            Text(range.evidence.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrent ? Theme.accent.opacity(0.08) : .clear)
    }
}

private struct RequirementRow: View {
    let text: String
    var status = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status == L.text("Disponible") ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(status == L.text("Disponible") ? Theme.accent : .secondary)
            Text(text)
                .font(.subheadline)
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}
