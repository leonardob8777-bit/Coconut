// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import WallpaperPackageManager
import CompatibilityManager

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--compatibility" {
    guard arguments.count == 3, let version = IOSVersion(arguments[1]) else {
        FileHandle.standardError.write(Data("Uso: wallpaper-inspect --compatibility VERSION_RELEASE MODELO\n".utf8))
        exit(64)
    }
    let assessment = CompatibilityManager.assess(version: version, productType: arguments[2])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    do { print(String(decoding: try encoder.encode(assessment), as: UTF8.self)) }
    catch { exit(1) }
    exit(0)
}
guard arguments.count == 1 || arguments.count == 3 && arguments[1] == "--sha256" else {
    FileHandle.standardError.write(Data("Uso: wallpaper-inspect archivo.tendies [--sha256 DIGEST]\n".utf8))
    exit(64)
}
do {
    let staged = try PackageInspector().stage(URL(fileURLWithPath: arguments[0]), expectedSHA256: arguments.count == 3 ? arguments[2] : nil)
    defer { try? FileManager.default.removeItem(at: staged.directory) }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(staged.inspection), as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("Importación rechazada: \(error.localizedDescription)\n".utf8))
    exit(1)
}
