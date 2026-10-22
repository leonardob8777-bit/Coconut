// SPDX-License-Identifier: GPL-3.0-only
// Adapted from leminlimez/Pocket-Poster, PosterBoardManager.swift:50-58,
// revision fb07aa45586ea4d2590c6f6d258777b207e1b8c9, created by lemin (2025).
// Modified 2026-10-16: isolate optional, user-triggered launch; no resets.
import UIKit

@MainActor
enum PosterBoardLauncher {
    static func open() -> Bool {
        guard let type = objc_getClass("LSApplicationWorkspace") as? NSObject,
              let workspace = type.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject,
              workspace.responds(to: Selector(("openApplicationWithBundleID:"))) else { return false }
        // This private API returns BOOL, not an Objective-C object.
        let selector = Selector(("openApplicationWithBundleID:"))
        typealias OpenApplication = @convention(c) (AnyObject, Selector, NSString) -> Bool
        let open = unsafeBitCast(workspace.method(for: selector), to: OpenApplication.self)
        return open(workspace, selector, "com.apple.PosterBoard")
    }
}
