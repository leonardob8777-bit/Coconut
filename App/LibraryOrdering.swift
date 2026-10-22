// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@MainActor enum LibraryOrdering {
    static func namePrecedes(_ lhs: String, _ rhs: String, lhsID: String, rhsID: String) -> Bool {
        let result = lhs.compare(rhs, options: [.numeric, .caseInsensitive, .diacriticInsensitive], locale: AppLanguageStore.shared.locale)
        return result == .orderedSame ? lhsID < rhsID : result == .orderedAscending
    }
}
