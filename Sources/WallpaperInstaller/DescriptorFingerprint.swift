// SPDX-License-Identifier: GPL-3.0-only
import CryptoKit
import Foundation

/// A bounded, content-based comparison of a staged and imported descriptor.
/// It verifies the filesystem copy, not PosterBoard's visual rendering.
struct DescriptorFingerprint: Equatable {
    struct File: Equatable {
        let relativePath: String
        let byteCount: UInt64
        let sha256: Data
    }

    let files: [File]

    static func capture(at root: URL) throws -> Self {
        let fm = FileManager.default
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw InstallerError.stopped("El descriptor no es una carpeta segura.")
        }
        let required = [
            "com.apple.posterkit.provider.descriptor.identifier",
            "com.apple.posterkit.role.identifier",
            "providerInfo.plist",
            "versions"
        ]
        guard required.allSatisfy({ fm.fileExists(atPath: root.appendingPathComponent($0).path) }),
              let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
              ]) else {
            throw InstallerError.stopped("Faltan archivos necesarios del descriptor.")
        }

        let base = root.standardizedFileURL.path + "/"
        var files: [File] = []
        var totalBytes: UInt64 = 0
        for case let url as URL in enumerator {
            let metadata = try url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
            ])
            guard metadata.isSymbolicLink != true else {
                throw InstallerError.stopped("El descriptor contiene un enlace simbólico.")
            }
            guard metadata.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(base), files.count < 20_000,
                  let size = metadata.fileSize, size > 0,
                  size <= 256 * 1024 * 1024 else {
                throw InstallerError.stopped("El descriptor supera los límites de archivo.")
            }
            let relative = String(path.dropFirst(base.count))
            let components = relative.split(separator: "/", omittingEmptySubsequences: false)
            guard !relative.isEmpty, relative.utf8.count <= 4_096,
                  components.count <= 64,
                  components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }) else {
                throw InstallerError.stopped("El descriptor contiene una ruta inválida.")
            }
            let byteCount = UInt64(size)
            guard totalBytes <= 1_073_741_824 - byteCount else {
                throw InstallerError.stopped("El descriptor supera el límite total.")
            }
            totalBytes += byteCount
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var digest = SHA256()
            var read: UInt64 = 0
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                read += UInt64(chunk.count)
                guard read <= byteCount else {
                    throw InstallerError.stopped("Un archivo cambió durante la verificación.")
                }
                digest.update(data: chunk)
            }
            guard read == byteCount else {
                throw InstallerError.stopped("Un archivo cambió durante la verificación.")
            }
            files.append(File(relativePath: relative, byteCount: byteCount, sha256: Data(digest.finalize())))
        }
        files.sort { $0.relativePath < $1.relativePath }
        guard files.count >= 4, totalBytes > 64 else {
            throw InstallerError.stopped("El descriptor está incompleto.")
        }
        return Self(files: files)
    }
}
