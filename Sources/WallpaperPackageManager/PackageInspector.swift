// SPDX-License-Identifier: GPL-3.0-only
// Original package inspection implementation. No Pocket Poster source copied here.
import Foundation
import CryptoKit
import ZIPFoundation

public struct Descriptor: Codable, Sendable {
    public let relativePath: String
    public let provider: String
    public let logicalScreenClass: String?
    public let canvasWidth: Int?
    public let canvasHeight: Int?
}

public struct Inspection: Codable, Sendable {
    public let sha256: String
    public let compressedBytes: Int
    public let expandedBytes: UInt64
    public let entryCount: Int
    public let descriptors: [Descriptor]
    public let warnings: [String]
    public let installationVerified: Bool
}

public struct InspectionLimits: Sendable {
    public var archiveBytes: Int = 128 * 1024 * 1024
    public var expandedBytes: UInt64 = 512 * 1024 * 1024
    public var entryBytes: UInt64 = 128 * 1024 * 1024
    public var entryCount = 10_000
    public init() {}
}

public enum PackageError: Error, LocalizedError {
    case rejected(String)
    public var errorDescription: String? {
        switch self { case .rejected(let reason): return reason }
    }
}

public struct StagedPackage: Sendable {
    public let directory: URL
    public let inspection: Inspection
}

public struct PackageInspector: Sendable {
    public let limits: InspectionLimits
    public init(limits: InspectionLimits = .init()) { self.limits = limits }

    /// Uses a private temporary directory, streams decompression, checks CRC, and never
    /// accesses PosterBoard. The caller owns the returned directory and must remove it.
    public func stage(_ source: URL, expectedSHA256: String? = nil) throws -> StagedPackage {
        let fm = FileManager.default
        guard source.pathExtension.lowercased() == "tendies" else {
            throw PackageError.rejected("Se requiere un archivo .tendies.")
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= limits.archiveBytes else {
            throw PackageError.rejected("Archivo vacío, enlace o tamaño superior al límite de importación.")
        }
        let workspace = fm.temporaryDirectory.appendingPathComponent("WallpaperLab-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: workspace, withIntermediateDirectories: false)
        var keep = false
        defer { if !keep { try? fm.removeItem(at: workspace) } }
        // Snapshot first: validation and extraction refer to the same bytes.
        let snapshot = workspace.appendingPathComponent("package.tendies")
        try fm.copyItem(at: source, to: snapshot)
        guard let snapshotSize = try snapshot.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              snapshotSize <= limits.archiveBytes else { throw PackageError.rejected("Archivo demasiado grande.") }
        let input = try FileHandle(forReadingFrom: snapshot)
        defer { try? input.close() }
        var hash = SHA256()
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        if let expectedSHA256 {
            guard expectedSHA256.count == 64, expectedSHA256.allSatisfy({ $0.isASCII && $0.isHexDigit }),
                  digest == expectedSHA256.lowercased() else {
                throw PackageError.rejected("SHA-256 distinto del valor esperado.")
            }
        }

        let archive = try Archive(url: snapshot, accessMode: .read)
        var entries: [Entry] = []
        var names = Set<String>()
        var declaredTotal: UInt64 = 0
        var types: [String: Bool] = [:]
        for entry in archive {
            guard entries.count < limits.entryCount else { throw PackageError.rejected("Demasiadas entradas ZIP.") }
            let path = entry.path
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.isEmpty, path.utf8.count <= 1024, !path.hasPrefix("/"), !path.contains("\\"),
                  !path.contains(":"), !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !parts.contains(".."), !parts.contains("."),
                  !parts.dropLast().contains(""),
                  entry.type == .file || entry.type == .directory,
                  (entry.type == .directory) == path.hasSuffix("/") else {
                throw PackageError.rejected("Ruta o tipo ZIP no permitido: \(path)")
            }
            let key = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .precomposedStringWithCanonicalMapping.lowercased()
            guard names.insert(key).inserted else { throw PackageError.rejected("Ruta duplicada o ambigua: \(path)") }
            types[key] = entry.type == .directory
            guard entry.uncompressedSize <= limits.entryBytes,
                  declaredTotal <= limits.expandedBytes,
                  entry.uncompressedSize <= limits.expandedBytes - declaredTotal else {
                throw PackageError.rejected("El ZIP supera el límite de descompresión.")
            }
            declaredTotal += entry.uncompressedSize
            entries.append(entry)
        }
        guard !entries.isEmpty else { throw PackageError.rejected("ZIP vacío.") }
        for key in names {
            var parent = key as NSString
            while parent.deletingLastPathComponent != ".", !parent.deletingLastPathComponent.isEmpty {
                parent = parent.deletingLastPathComponent as NSString
                if types[parent as String] == false { throw PackageError.rejected("Un archivo se usa como directorio.") }
            }
        }

        let payload = workspace.appendingPathComponent("payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: false)
        var actualTotal: UInt64 = 0
        for entry in entries {
            let destination = payload.appendingPathComponent(entry.path)
            if entry.type == .directory {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
                continue
            }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fm.createFile(atPath: destination.path, contents: nil) else { throw PackageError.rejected("No se pudo crear staging.") }
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            var bytes: UInt64 = 0
            let crc = try archive.extract(entry, bufferSize: 64 * 1024) { data in
                let count = UInt64(data.count)
                guard bytes <= entry.uncompressedSize, count <= entry.uncompressedSize - bytes,
                      actualTotal <= limits.expandedBytes, count <= limits.expandedBytes - actualTotal else {
                    throw PackageError.rejected("Descompresión superior al tamaño declarado.")
                }
                bytes += count
                actualTotal += count
                try output.write(contentsOf: data)
            }
            guard bytes == entry.uncompressedSize, crc == entry.checksum else {
                throw PackageError.rejected("CRC o tamaño incorrecto: \(entry.path)")
            }
        }
        let roots = try fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != "__MACOSX" && !$0.lastPathComponent.hasPrefix(".") }
        let providers = [
            "descriptor": "com.apple.WallpaperKit.CollectionsPoster",
            "descriptors": "com.apple.WallpaperKit.CollectionsPoster",
            "ordered-descriptor": "com.apple.WallpaperKit.CollectionsPoster",
            "ordered-descriptors": "com.apple.WallpaperKit.CollectionsPoster",
            "video-descriptor": "com.apple.PhotosUIPrivate.PhotosPosterProvider",
            "video-descriptors": "com.apple.PhotosUIPrivate.PhotosPosterProvider"
        ]
        guard roots.count == 1, let root = roots.first, let provider = providers[root.lastPathComponent.lowercased()] else {
            throw PackageError.rejected("La PoC acepta una sola raíz descriptor(s), ordered-descriptor(s) o video-descriptor(s). Container y otros formatos requieren revisión.")
        }
        let folders = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { !$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != "__MACOSX" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard folders.count == 1 else { throw PackageError.rejected("La PoC exige exactamente un descriptor por paquete.") }
        var descriptors: [Descriptor] = []
        for folder in folders {
            let identifier = folder.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier")
            let versions = folder.appendingPathComponent("versions")
            guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true,
                  fm.fileExists(atPath: identifier.path),
                  try versions.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                throw PackageError.rejected("Descriptor incompleto: faltan identifier o versions.")
            }
            let screenClass = try Self.readLogicalScreenClass(in: versions, fileManager: fm)
            let dimensions = screenClass.flatMap(Self.parseScreenClass)
            descriptors.append(Descriptor(relativePath: root.lastPathComponent + "/" + folder.lastPathComponent,
                                          provider: provider, logicalScreenClass: screenClass,
                                          canvasWidth: dimensions?.width, canvasHeight: dimensions?.height))
        }
        var warnings = [
            "Estructura y CRC comprobados; el contenido visual y la compatibilidad de PosterBoard no están validados.",
            expectedSHA256 == nil ? "SHA-256 calculado sin digest de confianza: no autentica al autor." : "SHA-256 coincide con el valor proporcionado; su autenticidad depende del origen de ese valor.",
            "No se interpreta CAML ni se ejecuta contenido del paquete."
        ]
        if descriptors.contains(where: { $0.logicalScreenClass == nil }) {
            warnings.append("No se encontró logicalScreenClass en Wallpaper.plist; no se puede comparar el lienzo con el iPhone.")
        }
        let inspection = Inspection(sha256: digest, compressedBytes: snapshotSize, expandedBytes: actualTotal,
                                    entryCount: entries.count, descriptors: descriptors, warnings: warnings,
                                    installationVerified: false)
        keep = true
        return StagedPackage(directory: workspace, inspection: inspection)
    }

    private static func readLogicalScreenClass(in versions: URL, fileManager fm: FileManager) throws -> String? {
        guard let enumerator = fm.enumerator(at: versions, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            throw PackageError.rejected("No se pudieron revisar los metadatos del descriptor.")
        }
        var values = Set<String>()
        for case let url as URL in enumerator where url.lastPathComponent == "Wallpaper.plist" {
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard resource.isRegularFile == true, resource.isSymbolicLink != true else {
                throw PackageError.rejected("Wallpaper.plist no es un archivo regular.")
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= 1_048_576,
                  let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                throw PackageError.rejected("Wallpaper.plist inválido o demasiado grande.")
            }
            if let value = plist["logicalScreenClass"] as? String, !value.isEmpty { values.insert(value) }
        }
        guard values.count <= 1 else {
            throw PackageError.rejected("El paquete mezcla varios logicalScreenClass en un mismo descriptor.")
        }
        return values.first
    }

    private static func parseScreenClass(_ value: String) -> (width: Int, height: Int)? {
        let pattern = #"^(\d+)w-(\d+)h(?:@\d+x)?~iphone$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let widthRange = Range(match.range(at: 1), in: value),
              let heightRange = Range(match.range(at: 2), in: value),
              let width = Int(value[widthRange]), let height = Int(value[heightRange]),
              (100...10_000).contains(width), (100...20_000).contains(height) else { return nil }
        return (width, height)
    }
}
