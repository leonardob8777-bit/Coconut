// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@MainActor enum ThemeSearch {
    static func normalized(_ query: String) -> String {
        String(query.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(100))
    }
    static func matches(_ theme: CatalogTheme, query: String) -> Bool {
        let fields = [theme.id, theme.name, L.text(theme.name, language: .english), L.text(theme.name, language: .spanish),
                      theme.collection.rawValue, L.text(theme.collection.rawValue, language: .english)].joined(separator: " ")
        return matches(fields: fields, query: query)
    }

    static func matches(_ package: ImportedPackage, query: String) -> Bool {
        matches(fields: [package.displayName, package.fileName].joined(separator: " "), query: query)
    }

    private static func matches(fields: String, query: String) -> Bool {
        let terms = normalized(query).split(separator: " ")
        return terms.allSatisfy {
            fields.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive], locale: AppLanguageStore.shared.locale) != nil
        }
    }
}
