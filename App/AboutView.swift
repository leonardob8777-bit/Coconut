// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

/// Créditos y licencias. Mismo texto legal que tenía la pantalla de laboratorio.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L.text("Coconut · AGPL-3.0 por la integración de Eagle/Lara. El inspector propio y el escritor adaptado de Pocket Poster conservan GPL-3.0; ZIPFoundation se distribuye bajo MIT. La ruta de PosterBoard es experimental y está limitada al iPhone 16 Pro con iOS 18.6.2."))
                        .font(.footnote)
                    Text(L.text("Esta versión incluye una colección de fondos para pruebas privadas. La procedencia y licencia de sus imágenes deben comprobarse antes de publicarlos. Una operación de archivo no confirma que el tema aparezca o quede seleccionado en PosterBoard."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Pocket Poster") {
                    Text(L.text("Instalador adaptado de Pocket Poster, creado por lemin (leminlimez), bajo GPL-3.0. Créditos del mecanismo: Nathan / verygenericname y DuyKhanhTran / khanhduytran0."))
                        .font(.footnote)
                    Link(L.text("Código fuente de Pocket Poster"), destination: URL(string: "https://github.com/leminlimez/Pocket-Poster")!)
                }
                Section {
                    NavigationLink(L.text("Ver licencias")) {
                        ScrollView {
                            Text(Self.licenseText)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }
                        .navigationTitle(L.text("Licencias"))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(L.text("Acerca de"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.text("Listo")) { dismiss() } }
            }
        }
    }

    private static var licenseText: String {
        ["AGPL-3.0", "GPL-3.0", "ZIPFoundation-MIT"].map { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                return L.format("%@: consultar LICENSE en el código fuente.", name)
            }
            return text
        }.joined(separator: "\n\n")
    }
}
