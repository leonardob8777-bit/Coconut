// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import CompatibilityManager

/// Datos del iPhone en el que corre la app y su evaluación de compatibilidad.
@MainActor
enum DeviceInfo {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// Identificador interno del modelo, por ejemplo "iPhone17,1".
    static var productType: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? L.text("Simulador")
        #else
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #endif
    }

    static var systemVersion: String { UIDevice.current.systemVersion }

    /// Current iPhone's native portrait canvas in points. This describes layout
    /// sizing only; it is not an installation compatibility signal.
    static var logicalScreenClass: String? {
        guard let screen = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.screen else { return nil }
        let pixels = screen.nativeBounds.size
        let scale = screen.nativeScale
        guard scale > 0 else { return nil }
        let width = Int((min(pixels.width, pixels.height) / scale).rounded())
        let height = Int((max(pixels.width, pixels.height) / scale).rounded())
        return "\(width)w-\(height)h@\(Int(scale))x~iphone"
    }

    /// Nombre comercial solo para los modelos que conocemos con seguridad.
    static var modelName: String {
        let names = [
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
        ]
        return names[productType] ?? productType
    }

    static var assessment: CompatibilityAssessment? {
        guard let version = IOSVersion(systemVersion) else { return nil }
        return CompatibilityManager.assess(version: version, productType: productType, isSimulator: isSimulator)
    }
}

/// Cómo se presenta cada nivel de evidencia en pantalla.
extension SupportEvidence {
    @MainActor var title: String {
        switch self {
        case .announcedCandidate: L.text("Candidato")
        case .preliminary: L.text("Preliminar")
        case .patchedAccordingToUpstream: L.text("Parcheado")
        case .outsidePublishedScope: L.text("Fuera de alcance")
        case .unknownReleaseFamily: L.text("Sin datos")
        }
    }

    @MainActor var detail: String {
        switch self {
        case .announcedCandidate: L.text("Dentro del rango que anuncia Pocket Poster.")
        case .preliminary: L.text("Soporte preliminar; algunos fondos no funcionan.")
        case .patchedAccordingToUpstream: L.text("Apple cerró el mecanismo en esta versión.")
        case .outsidePublishedScope: L.text("Fuera del rango publicado.")
        case .unknownReleaseFamily: L.text("No hay información para esta versión.")
        }
    }

    var tint: Color {
        switch self {
        case .announcedCandidate: Theme.accent
        case .preliminary: .orange
        case .patchedAccordingToUpstream: .red
        case .outsidePublishedScope, .unknownReleaseFamily: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .announcedCandidate: "checkmark.seal"
        case .preliminary: "exclamationmark.triangle"
        case .patchedAccordingToUpstream: "xmark.octagon"
        case .outsidePublishedScope, .unknownReleaseFamily: "questionmark.circle"
        }
    }
}
