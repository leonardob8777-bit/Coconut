// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

/// Compares reference artwork only. Opening a theme uses the existing save/apply flow.
struct WallpaperComparisonView: View {
    let themes: [CatalogTheme]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var firstID: String
    @State private var secondID: String
    @State private var selected: CatalogTheme?

    init(themes: [CatalogTheme], initialID: String? = nil) {
        self.themes = themes
        let first = themes.first { $0.id == initialID } ?? themes.first
        _firstID = State(initialValue: first?.id ?? "")
        _secondID = State(initialValue: themes.first { $0.id != first?.id }?.id ?? "")
    }
    private var first: CatalogTheme? { themes.first { $0.id == firstID } }
    private var second: CatalogTheme? { themes.first { $0.id == secondID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L.text("Compara los diseños y abre el que más te guste."))
                        .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                    if let first, let second {
                        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 26)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                        layout {
                            column(theme: first, id: $firstID, excluding: secondID, slot: "first", label: "Primer tema")
                            column(theme: second, id: $secondID, excluding: firstID, slot: "second", label: "Segundo tema")
                        }
                    } else {
                        QuietEmptyState(symbol: "rectangle.split.2x1", title: L.text("Comparar temas"), message: L.text("Se necesitan dos temas para comparar."))
                    }
                }.padding(Theme.gutter)
            }
            .background(Theme.canvas)
            .navigationTitle(L.text("Comparar")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { let previous = firstID; firstID = secondID; secondID = previous } label: { Image(systemName: "arrow.left.arrow.right") }
                        .accessibilityLabel(L.text("Intercambiar temas")).accessibilityIdentifier("compare.swap")
                        .disabled(first == nil || second == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.text("Cerrar")).accessibilityIdentifier("compare.close")
                }
            }
        }
        .sheet(item: $selected) { WallpaperDetailView(theme: $0) }
        .presentationDragIndicator(.visible).presentationCornerRadius(32)
    }
    private func column(theme: CatalogTheme, id: Binding<String>, excluding otherID: String, slot: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(L.text(label))
            Menu {
                ForEach(themes.filter { $0.id != otherID }) { candidate in
                    Button { id.wrappedValue = candidate.id } label: {
                        Label(candidate.displayName, systemImage: candidate.id == id.wrappedValue ? "checkmark" : "photo")
                    }.accessibilityIdentifier("compare.\(slot).option.\(candidate.id)")
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(theme.displayName).font(.headline).lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityLabel(L.text(label) + ": " + theme.displayName)
                .accessibilityIdentifier("compare.\(slot).choose")
            WallpaperFrame(previewURL: theme.artworkURL, cornerRadius: 20)
                .frame(maxHeight: dynamicType.isAccessibilitySize ? 300 : nil)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.format("Vista previa de %@", theme.displayName))
                .accessibilityIdentifier("compare.\(slot).artwork")
            Text(theme.collection.title).font(.caption).foregroundStyle(.secondary)
            Button { selected = theme } label: { Text(L.text("Vista previa")) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel(L.format("Vista previa de %@", theme.displayName))
                .accessibilityIdentifier("compare.\(slot).open")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
