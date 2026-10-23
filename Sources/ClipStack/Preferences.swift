import AppKit
import Carbon.HIToolbox

/// Ajustes del usuario, guardados en UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    enum PasteMode: String { case paste, copy }
    enum Theme: String { case system, light, dark }
    enum HeaderColor: String { case app, brand }
    enum PanelPosition: String { case bottom, top }
    enum CardSize: String { case normal, compact }

    struct IgnoredApp: Codable, Equatable, Identifiable {
        var name: String
        var bundleID: String
        var id: String { bundleID }
    }

    static let defaultHotKey = (keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), key: "V")
    static let maxItemsOptions = [20, 50, 100, 200, 500]
    static let menuClipOptions = [0, 3, 5, 10]
    static let defaultIgnoredApps = [
        IgnoredApp(name: "1Password", bundleID: "com.1password.1password"),
        IgnoredApp(name: "1Password 7", bundleID: "com.agilebits.onepassword7"),
        IgnoredApp(name: "Bitwarden", bundleID: "com.bitwarden.desktop"),
        IgnoredApp(name: "LastPass", bundleID: "com.lastpass.LastPass"),
        IgnoredApp(name: "Contraseñas", bundleID: "com.apple.Passwords"),
        IgnoredApp(name: "Acceso a Llaveros", bundleID: "com.apple.keychainaccess"),
    ]

    private let defaults = UserDefaults.standard

    // General
    @Published var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, "showMenuBarIcon") } }
    @Published var soundOnCopy: Bool { didSet { save(soundOnCopy, "soundOnCopy") } }

    // Atajos
    @Published var hotKeyCode: UInt32 { didSet { save(Int(hotKeyCode), "hotKeyCode") } }
    @Published var hotKeyModifiers: UInt32 { didSet { save(Int(hotKeyModifiers), "hotKeyModifiers") } }
    @Published var hotKeyKey: String { didSet { save(hotKeyKey, "hotKeyKey") } }

    // Historial
    @Published var maxItems: Int { didSet { save(maxItems, "maxItems") } }
    @Published var savedKinds: Set<String> { didSet { save(Array(savedKinds), "savedKinds") } }
    @Published var menuClipCount: Int { didSet { save(menuClipCount, "menuClipCount") } }
    @Published var clearOnQuit: Bool { didSet { save(clearOnQuit, "clearOnQuit") } }

    // Privacidad
    @Published var ignoredApps: [IgnoredApp] {
        didSet { save(try? JSONEncoder().encode(ignoredApps), "ignoredApps") }
    }
    @Published var pauseMinutes: Int { didSet { save(pauseMinutes, "pauseMinutes") } }
    @Published var pausedUntil: Date? { didSet { save(pausedUntil, "pausedUntil") } }

    // Pegado
    @Published var pasteMode: PasteMode { didSet { save(pasteMode.rawValue, "pasteMode") } }
    @Published var bumpOnPaste: Bool { didSet { save(bumpOnPaste, "bumpOnPaste") } }

    // Apariencia
    @Published var theme: Theme { didSet { save(theme.rawValue, "theme") } }
    @Published var headerColor: HeaderColor { didSet { save(headerColor.rawValue, "headerColor") } }
    @Published var panelPosition: PanelPosition { didSet { save(panelPosition.rawValue, "panelPosition") } }
    @Published var cardSize: CardSize { didSet { save(cardSize.rawValue, "cardSize") } }

    // Barra de menús
    @Published var menuShowsCards: Bool { didSet { save(menuShowsCards, "menuShowsCards") } }
    @Published var newClipDot: Bool { didSet { save(newClipDot, "newClipDot") } }

    private init() {
        let d = UserDefaults.standard
        showMenuBarIcon = d.object(forKey: "showMenuBarIcon") as? Bool ?? true
        soundOnCopy = d.object(forKey: "soundOnCopy") as? Bool ?? false
        hotKeyCode = (d.object(forKey: "hotKeyCode") as? Int).map(UInt32.init) ?? Self.defaultHotKey.keyCode
        hotKeyModifiers = (d.object(forKey: "hotKeyModifiers") as? Int).map(UInt32.init) ?? Self.defaultHotKey.modifiers
        hotKeyKey = d.string(forKey: "hotKeyKey") ?? Self.defaultHotKey.key
        maxItems = d.object(forKey: "maxItems") as? Int ?? 20
        savedKinds = Set(d.stringArray(forKey: "savedKinds") ?? DisplayKind.allCases.map(\.rawValue))
        menuClipCount = d.object(forKey: "menuClipCount") as? Int ?? 5
        clearOnQuit = d.object(forKey: "clearOnQuit") as? Bool ?? false
        ignoredApps = d.data(forKey: "ignoredApps").flatMap { try? JSONDecoder().decode([IgnoredApp].self, from: $0) }
            ?? Self.defaultIgnoredApps
        pauseMinutes = d.object(forKey: "pauseMinutes") as? Int ?? 15
        pausedUntil = d.object(forKey: "pausedUntil") as? Date
        pasteMode = PasteMode(rawValue: d.string(forKey: "pasteMode") ?? "") ?? .paste
        bumpOnPaste = d.object(forKey: "bumpOnPaste") as? Bool ?? true
        theme = Theme(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        headerColor = HeaderColor(rawValue: d.string(forKey: "headerColor") ?? "") ?? .app
        panelPosition = PanelPosition(rawValue: d.string(forKey: "panelPosition") ?? "") ?? .bottom
        cardSize = CardSize(rawValue: d.string(forKey: "cardSize") ?? "") ?? .normal
        menuShowsCards = d.object(forKey: "menuShowsCards") as? Bool ?? true
        newClipDot = d.object(forKey: "newClipDot") as? Bool ?? true
    }

    private func save(_ value: Any?, _ key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: - Derivados

    var isPaused: Bool { (pausedUntil ?? .distantPast) > Date() }

    func setPaused(_ paused: Bool) {
        pausedUntil = paused ? Date().addingTimeInterval(TimeInterval(pauseMinutes * 60)) : nil
    }

    var pauseLabel: String { pauseMinutes >= 60 ? "1 h" : "\(pauseMinutes) min" }

    func allows(_ kind: DisplayKind) -> Bool { savedKinds.contains(kind.rawValue) }

    var ignoredBundleIDs: Set<String> { Set(ignoredApps.map(\.bundleID)) }

    /// El atajo con símbolos de macOS, p. ej. ⇧⌘V.
    var hotKeyDisplay: String { Self.display(modifiers: hotKeyModifiers, key: hotKeyKey) }

    static func display(modifiers: UInt32, key: String) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    /// Para mostrar el atajo en el menú de la barra.
    var hotKeyMenuEquivalent: (key: String, mask: NSEvent.ModifierFlags) {
        var mask: NSEvent.ModifierFlags = []
        if hotKeyModifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        if hotKeyModifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if hotKeyModifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if hotKeyModifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        let key = hotKeyKey.count == 1 ? hotKeyKey.lowercased() : ""
        return (key, mask)
    }

    /// Vuelve a los valores de fábrica. El historial, los fijados y el inicio de sesión no se tocan.
    func reset() {
        showMenuBarIcon = true
        soundOnCopy = false
        hotKeyCode = Self.defaultHotKey.keyCode
        hotKeyModifiers = Self.defaultHotKey.modifiers
        hotKeyKey = Self.defaultHotKey.key
        maxItems = 20
        savedKinds = Set(DisplayKind.allCases.map(\.rawValue))
        menuClipCount = 5
        clearOnQuit = false
        ignoredApps = Self.defaultIgnoredApps
        pauseMinutes = 15
        pausedUntil = nil
        pasteMode = .paste
        bumpOnPaste = true
        theme = .system
        headerColor = .app
        panelPosition = .bottom
        cardSize = .normal
        menuShowsCards = true
        newClipDot = true
    }
}
