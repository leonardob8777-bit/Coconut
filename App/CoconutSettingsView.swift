// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct CoconutSettingsView: View {
    @Environment(AppLanguageStore.self) private var language
    @Environment(CatalogStore.self) private var catalog
    @AppStorage("Coconut.appearance") private var appearance = "system"
    @State private var showingAbout = false
    var body: some View {
        @Bindable var language = language
        List {
            Section {
                // Creator card: opens the GitHub profile.
                Link(destination: URL(string: "https://github.com/leonardob8777-bit")!) {
                    HStack(spacing: 16) {
                        Image("CreatorAvatar").resizable().scaledToFill()
                            .frame(width: 58, height: 58).clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Leonardo").font(.headline)
                            Text(L.text("Creador de Coconut")).font(.subheadline).foregroundStyle(.secondary)
                            Label("@leonardob8777-bit", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.caption).foregroundStyle(.tertiary).labelStyle(.titleAndIcon)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(L.text("Abre su perfil de GitHub"))
                .accessibilityIdentifier("settings.creator")
            }
            Section(L.text("Tu experiencia")) {
                Picker(selection: $language.language) {
                    Text("English").tag(AppLanguageStore.Language.english)
                    Text("Español").tag(AppLanguageStore.Language.spanish)
                } label: { Label(L.text("Idioma"), systemImage: "globe") }
                .accessibilityIdentifier("settings.language")
                Picker(selection: $appearance) {
                    Text(L.text("Sistema")).tag("system")
                    Text(L.text("Claro")).tag("light")
                    Text(L.text("Oscuro")).tag("dark")
                } label: { Label(L.text("Apariencia"), systemImage: "circle.lefthalf.filled") }
                .accessibilityIdentifier("settings.appearance")
                NavigationLink { CompatibilityView() } label: {
                    Label(L.text("Dispositivo y compatibilidad"), systemImage: "iphone")
                }
            }
            Section {
                Label(L.text(collectionStatus), systemImage: catalog.updateState == .current ? "checkmark.circle" : "square.stack")
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L.text(collectionStatus))
                    .accessibilityIdentifier("settings.collectionStatus")
                if let updated = catalog.lastUpdatedAt {
                    LabeledContent(L.text("Última actualización")) {
                        Text(updated, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .multilineTextAlignment(.trailing)
                    }.font(.subheadline)
                }
                Button { Task { await catalog.load() } } label: {
                    HStack(spacing: 12) {
                        Text(L.text(catalog.updateState == .checking ? "Buscando nuevos temas…" : "Buscar nuevos temas"))
                        Spacer(minLength: 8)
                        if catalog.updateState == .checking { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }.frame(minHeight: 44)
                }
                .disabled(catalog.updateState == .checking)
                .accessibilityIdentifier("settings.refreshCollection")
            } header: { Text(L.text("La colección")) } footer: {
                Text(L.text(catalog.updateState == .unavailable
                    ? "Puedes seguir explorando la colección. Los fondos que hayas guardado están disponibles sin conexión."
                    : "Comprueba si hay nuevos temas sin salir de Coconut."))
            }
            Section(L.text("Configurar PosterBoard")) { EngineAccessCard().listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            Section("Coconut") {
                Button { showingAbout = true } label: {
                    Label(L.text("Acerca de y licencias"), systemImage: "info.circle").foregroundStyle(.primary)
                }
                HStack {
                    Text(L.text("Versión"))
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.canvas)
        .navigationTitle(L.text("Ajustes")).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAbout) { AboutView() }
    }

    private var collectionStatus: String {
        switch catalog.updateState {
        case .idle: "Colección incluida"
        case .checking: "Comprobando la colección"
        case .current: "Colección actualizada"
        case .unavailable: "No se pudieron comprobar las novedades"
        }
    }
}
