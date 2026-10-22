// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

@MainActor @Observable
final class AppLanguageStore {
    static let shared = AppLanguageStore()
    enum Language: String, CaseIterable { case english = "en", spanish = "es" }
    private let defaults: UserDefaults
    var language: Language {
        didSet { defaults.set(language.rawValue, forKey: "Coconut.language") }
    }
    var locale: Locale { Locale(identifier: language.rawValue) }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = Language(rawValue: defaults.string(forKey: "Coconut.language") ?? "en") ?? .english
    }
}

/// Explicit locale selection also covers runtime strings and persisted diagnostics.
@MainActor enum L {
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: ["en", "es"].map { code in
        (code, Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main)
    })
    private static let tables: [[String: String]] = ["es", "en"].compactMap { code in
        guard let url = bundles[code]?.url(forResource: "Localizable", withExtension: "strings"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: String]
    }
    private static var bundle: Bundle {
        bundles[AppLanguageStore.shared.language.rawValue] ?? .main
    }
    static func text(_ key: String) -> String { bundle.localizedString(forKey: key, value: key, table: nil) }
    static func text(_ key: String, language: AppLanguageStore.Language) -> String {
        (bundles[language.rawValue] ?? .main).localizedString(forKey: key, value: key, table: nil)
    }
    static func format(_ key: String, _ values: String...) -> String {
        String(format: text(key), locale: AppLanguageStore.shared.locale, arguments: values)
    }
    /// Engine diagnostics retain stable source text; presentation follows the chosen language.
    static func message(_ source: String) -> String {
        if text(source) != source { return text(source) }
        for dictionary in tables {
            for (key, value) in dictionary {
                if value == source { return text(key) }
                guard value.contains("%@") else { continue }
                let pattern = "^" + value.components(separatedBy: "%@").map(NSRegularExpression.escapedPattern(for:)).joined(separator: "(.+?)") + "$"
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { continue }
                let args = (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: source).map { String(source[$0]) } }
                return String(format: text(key), locale: AppLanguageStore.shared.locale, arguments: args)
            }
        }
        return source
    }
}
