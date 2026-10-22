// SPDX-License-Identifier: AGPL-3.0-only
// Adapted for Coconut from Eagle's AnimatedWallpapersView.swift refreshCollections,
// https://github.com/leonardob8777-bit/Eagle (AGPL-3.0).
import Foundation
import UIKit

@MainActor
enum PosterBoardRefresh {
    /// Requests a gallery reload after a write attempt; flags require verified readback.
    /// This does not select the wallpaper or prove that it renders correctly.
    static func request(containerUUID: String, descriptorVerified: Bool) -> Bool {
        guard UUID(uuidString: containerUUID) != nil else { return false }
        let flagsWritten = descriptorVerified && writeRefreshFlags(containerUUID: containerUUID)
        var languageRequested = false
        if #available(iOS 18.0, *),
           let language = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first,
           let utility = objc_getClass("IPSettingsUtilities") as? NSObject {
            let selector = NSSelectorFromString("setLanguage:")
            if utility.responds(to: selector) {
                _ = utility.perform(selector, with: language)
                languageRequested = true
            }
        }
        return flagsWritten || languageRequested
    }

    private static func writeRefreshFlags(containerUUID: String) -> Bool {
        let preferences = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application", isDirectory: true)
            .appendingPathComponent(containerUUID, isDirectory: true)
            .appendingPathComponent("Library/Preferences/com.apple.PosterBoard.unprotectedUserDefaults.plist")
        do {
            var values: [String: Any] = [:]
            var format: PropertyListSerialization.PropertyListFormat = .binary
            if FileManager.default.fileExists(atPath: preferences.path) {
                let metadata = try preferences.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard metadata.isRegularFile == true, metadata.isSymbolicLink != true,
                      let size = metadata.fileSize, size <= 4 * 1024 * 1024 else { return false }
                let data = try Data(contentsOf: preferences)
                guard let dictionary = try PropertyListSerialization.propertyList(
                    from: data, options: [], format: &format) as? [String: Any] else { return false }
                values = dictionary
            }
            values["PBF_LOCALE_DID_CHANGE"] = false
            values["PBF_RESET_FILE_PROTECTIONS"] = true
            let data = try PropertyListSerialization.data(
                fromPropertyList: values,
                format: format == .openStep ? .binary : format,
                options: 0)
            guard !data.isEmpty, data.count <= 4 * 1024 * 1024 else { return false }
            try data.write(to: preferences, options: .atomic)
            return try Data(contentsOf: preferences) == data
        } catch {
            return false
        }
    }
}
