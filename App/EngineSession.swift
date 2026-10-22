// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import WallpaperInstaller

/// Configuration persists; privileged access does not. Apply never starts discovery.
@MainActor @Observable
final class EngineSession {
    enum State { case idle, activating, ready, failed, unavailable }
    static let uuidKey = "Coconut.posterBoardUUID"
    private(set) var state: State
    private(set) var access: PreparedPosterBoardAccess?
    private(set) var failure: String?
    private(set) var savedUUID: String?
    private var attempted = false
    private let isSimulator: Bool
    let installationSupported: Bool
    let automaticDiscoverySupported: Bool
    private let defaults: UserDefaults
    private let prepare: @Sendable () async throws -> PreparedPosterBoardAccess
    private let validate: @Sendable (PreparedPosterBoardAccess) async throws -> Void

    init(isSimulator: Bool = DeviceInfo.isSimulator,
         defaults: UserDefaults = .standard,
         installationSupported: Bool = PosterBoardAccessCoordinator.supportsSavedUUID(),
         automaticDiscoverySupported: Bool = true,
         prepare: @escaping @Sendable () async throws -> PreparedPosterBoardAccess = { try await PosterBoardAccessCoordinator.prepare() },
         validate: @escaping @Sendable (PreparedPosterBoardAccess) async throws -> Void = { try await PosterBoardAccessCoordinator.validate($0) }) {
        self.isSimulator = isSimulator
        self.defaults = defaults
        self.installationSupported = installationSupported
        self.automaticDiscoverySupported = automaticDiscoverySupported
        self.prepare = prepare
        self.validate = validate
        let restoredUUID = defaults.string(forKey: Self.uuidKey).flatMap { UUID(uuidString: $0)?.uuidString }
        savedUUID = restoredUUID
        access = restoredUUID.map { PreparedPosterBoardAccess(containerUUID: $0, route: .pocketPoster) }
        state = isSimulator || !installationSupported ? .unavailable : (restoredUUID == nil ? .idle : .ready)
    }
    var isReady: Bool { state == .ready && access != nil && !isSimulator && installationSupported }
    var canActivate: Bool { !isSimulator && installationSupported && automaticDiscoverySupported && !attempted && state != .activating }
    var title: String {
        if state == .activating { return L.text("Buscando UUID…") }
        if savedUUID != nil { return L.text("UUID guardado") }
        return state == .failed ? L.text("No se pudo obtener el UUID") : L.text("Configuración inicial")
    }
    var detail: String {
        if isSimulator { return L.text("Puedes revisar la configuración aquí. Aplicar fondos requiere un iPhone compatible.") }
        if !installationSupported { return L.text("Esta versión de iOS no admite la instalación con UUID guardado. Obtenerlo desde un ordenador no cambia esa compatibilidad. Puedes exportar el tema para otra herramienta compatible.") }
        if let failure { return L.message(failure) }
        if savedUUID != nil { return L.text("Coconut recuerda el UUID de PosterBoard. Añadir fondos no vuelve a activar DarkSword. Si el contenedor cambia, actualiza el UUID.") }
        return L.text("Configura PosterBoard una vez: obtén su UUID en este iPhone compatible o introduce el que conseguiste con un ordenador.")
    }
    func saveUUID(_ text: String) throws {
        guard state != .activating else { throw SessionError.busy }
        guard let uuid = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SessionError.invalidUUID
        }
        store(uuid.uuidString)
    }
    private func store(_ uuid: String) {
        defaults.set(uuid, forKey: Self.uuidKey)
        savedUUID = uuid
        access = PreparedPosterBoardAccess(containerUUID: uuid, route: .pocketPoster)
        failure = nil
        state = isSimulator || !installationSupported ? .unavailable : .ready
    }
    func forgetUUID() {
        guard state != .activating else { return }
        defaults.removeObject(forKey: Self.uuidKey)
        savedUUID = nil
        access = nil
        failure = nil
        state = isSimulator || !installationSupported ? .unavailable : .idle
    }
    /// Explicit one-time discovery. Only the UUID is persisted, never an access grant.
    func activate() async {
        guard canActivate else { return }
        attempted = true
        state = .activating
        failure = nil
        do {
            let prepared = try await prepare()
            try await validate(prepared)
            guard let uuid = UUID(uuidString: prepared.containerUUID) else { throw SessionError.invalidUUID }
            store(uuid.uuidString)
        } catch {
            failure = error.localizedDescription
            state = savedUUID == nil ? .failed : .ready
        }
    }
    /// A saved UUID is configuration, not proof of read access or installation.
    func validatedAccess() async throws -> PreparedPosterBoardAccess {
        guard isReady, let access, UUID(uuidString: access.containerUUID) != nil else {
            throw SessionError.notConfigured
        }
        return access
    }
    private enum SessionError: LocalizedError {
        case notConfigured, invalidUUID, busy
        var errorDescription: String? {
            switch self {
            case .notConfigured: "Configura el UUID de PosterBoard antes de aplicar un fondo."
            case .invalidUUID: "Introduce un UUID de PosterBoard válido. No es el UDID del iPhone."
            case .busy: "Espera a que termine la obtención del UUID."
            }
        }
    }
}

struct EngineAccessCard: View {
    var showsActivationButton = true
    @Environment(EngineSession.self) private var engine
    @State private var uuidText = ""
    @State private var inputError: String?
    @FocusState private var editingUUID: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: engine.savedUUID == nil ? "key" : "checkmark.circle")
                    .font(.title2.weight(.light))
                VStack(alignment: .leading, spacing: 3) {
                    Text("PosterBoard").font(.headline)
                    Text(engine.title).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("engine.status")
                }
                Spacer(minLength: 0)
                if engine.state == .activating { ProgressView() }
            }
            Text(engine.detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let uuid = engine.savedUUID {
                Text(uuid).font(.caption.monospaced()).textSelection(.enabled)
                    .accessibilityIdentifier("engine.savedUUID")
            }
            if showsActivationButton {
                if engine.savedUUID == nil {
                    Button { Task { await engine.activate() } } label: {
                        Label(L.text("Obtener UUID automáticamente"), systemImage: "iphone")
                    }.buttonStyle(SecondaryButtonStyle()).disabled(!engine.canActivate)
                        .accessibilityIdentifier("engine.activate")
                    Text(L.text("Coconut primero busca el UUID con el acceso disponible. Si necesita DarkSword, comprueba la compatibilidad del motor antes del intento. Puede reiniciar el iPhone."))
                        .font(.caption).foregroundStyle(.secondary)
                    if engine.state == .failed {
                        Text(L.text("Puedes introducir el UUID obtenido con un ordenador. Para repetir la obtención automática, cierra Coconut por completo."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text(L.text("Usar un UUID existente")).font(.subheadline.weight(.medium))
                Text(L.text("Pega el UUID de PosterBoard obtenido con un ordenador o copiado de tu configuración de Pocket Poster. Se guarda solo en Coconut."))
                    .font(.footnote).foregroundStyle(.secondary)
                TextField(L.text("UUID de PosterBoard"), text: $uuidText)
                    .font(.footnote.monospaced()).textInputAutocapitalization(.characters)
                    .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    .focused($editingUUID).submitLabel(.done).onSubmit { saveConfiguration() }
                    .accessibilityIdentifier("engine.uuidInput")
                if let inputError { Text(L.message(inputError)).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("engine.uuidError") }
                Button { saveConfiguration() } label: { Label(L.text("Guardar UUID"), systemImage: "checkmark") }
                    .buttonStyle(SecondaryButtonStyle()).disabled(uuidText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.state == .activating)
                    .accessibilityIdentifier("engine.saveUUID")
                DisclosureGroup(L.text("Obtenerlo con un ordenador")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.text("Conecta tu iPhone al ordenador y acepta la relación de confianza. En Nugget, abre Settings → Pocket Poster Helper. Sigue su configuración para Pocket Poster y copia el App UUID de PosterBoard en el campo de arriba."))
                        Link(L.text("Abrir Nugget para ordenador"), destination: URL(string: "https://github.com/leminlimez/Nugget")!)
                        Link(L.text("Instrucciones de Pocket Poster"), destination: URL(string: "https://github.com/leminlimez/Pocket-Poster#getting-started")!)
                        Text(L.text("Usa el UUID de este mismo iPhone. Si restauras el dispositivo o cambia el contenedor, tendrás que obtenerlo de nuevo."))
                    }.font(.footnote).padding(.top, 10)
                }.accessibilityIdentifier("engine.computerHelp")
                if engine.savedUUID != nil {
                    Button(L.text("Olvidar UUID")) { engine.forgetUUID(); uuidText = ""; inputError = nil }
                        .font(.footnote).accessibilityIdentifier("engine.forgetUUID")
                        .disabled(engine.state == .activating)
                }
            }
        }.card()
        .onAppear { uuidText = engine.savedUUID ?? "" }
    }
    private func saveConfiguration() {
        do {
            try engine.saveUUID(uuidText)
            uuidText = engine.savedUUID ?? ""
            inputError = nil
            editingUUID = false
        } catch { inputError = error.localizedDescription }
    }

}

struct EngineAccessSheet: View {
    @Environment(EngineSession.self) private var engine
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { EngineAccessCard().padding(Theme.gutter) }
                .background(Theme.canvas)
                .navigationTitle(L.text("Configurar PosterBoard")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel(L.text("Cerrar"))
                            .accessibilityIdentifier("engine.close")
                            .disabled(engine.state == .activating)
                    }
                }
        }.interactiveDismissDisabled(engine.state == .activating)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
