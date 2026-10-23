import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, atajos, historial, privacidad, pegado, apariencia, menubar, acerca

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .atajos:     return "Atajos"
        case .historial:  return "Historial"
        case .privacidad: return "Privacidad"
        case .pegado:     return "Pegado"
        case .apariencia: return "Apariencia"
        case .menubar:    return "Barra de menús"
        case .acerca:     return "Acerca de"
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gearshape"
        case .atajos:     return "keyboard"
        case .historial:  return "clock"
        case .privacidad: return "lock"
        case .pegado:     return "arrow.down.doc"
        case .apariencia: return "circle.lefthalf.filled"
        case .menubar:    return "menubar.rectangle"
        case .acerca:     return "info.circle"
        }
    }
}

/// Lo que la ventana necesita de AppDelegate.
struct SettingsActions {
    /// Registra el atajo; devuelve false si está ocupado.
    var setHotKey: @MainActor (UInt32, UInt32, String) -> Bool
}

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: HistoryStore
    let actions: SettingsActions

    @State private var section: SettingsSection = .general
    @State private var dialog: ConfirmDialog?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(DS.title)
                    .tracking(DS.titleTracking)
                    .padding(.horizontal, DS.space8)
                    .frame(height: 52)
                ScrollView {
                    content
                        .padding(EdgeInsets(top: 4, leading: DS.space8, bottom: DS.space8, trailing: DS.space8))
                }
                .scrollIndicators(.automatic)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 760, height: 520)
        .background(Color.ds(DS.surface))
        .foregroundStyle(Color.ds(DS.ink))
        .overlay {
            if let dialog {
                ConfirmDialogView(dialog: dialog) { self.dialog = nil }
            }
        }
    }

    // MARK: - Barra lateral

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { s in
                let active = s == section
                HStack(spacing: 9) {
                    Image(systemName: s.icon)
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text(s.title).font(DS.label)
                }
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .foregroundStyle(Color.ds(active ? DS.onBrandInk : DS.ink))
                .background(active ? Color.ds(DS.brandInk) : .clear,
                            in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
                .pressable { section = s }
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 56, leading: 10, bottom: DS.space4, trailing: 10))
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(Color.ds(DS.surfaceRaised))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.ds(DS.line)).frame(width: 1) }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .general:    GeneralSection(prefs: prefs)
        case .atajos:     AtajosSection(prefs: prefs, actions: actions)
        case .historial:  HistorialSection(prefs: prefs, store: store, dialog: $dialog)
        case .privacidad: PrivacidadSection(prefs: prefs)
        case .pegado:     PegadoSection(prefs: prefs)
        case .apariencia: AparienciaSection(prefs: prefs)
        case .menubar:    MenuBarSection(prefs: prefs, store: store)
        case .acerca:     AcercaSection(prefs: prefs, dialog: $dialog)
        }
    }
}

// MARK: - General

private struct GeneralSection: View {
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        SettingGroup {
            SettingRow(title: "Abrir al iniciar sesión",
                       hint: "ClipStack se abre solo cuando inicias sesión.") {
                DSToggle(isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            }
            SettingRow(title: "Mostrar el icono en la barra de menús",
                       hint: "Si lo ocultas, abre el historial con \(prefs.hotKeyDisplay).", divider: true) {
                DSToggle(isOn: $prefs.showMenuBarIcon)
            }
            SettingRow(title: "Sonido al copiar",
                       hint: "Un clic suave cada vez que guardas un clip.", divider: true) {
                DSToggle(isOn: $prefs.soundOnCopy)
            }
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("ClipStack: no se pudo cambiar el inicio automático: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Atajos

private struct AtajosSection: View {
    @ObservedObject var prefs: Preferences
    let actions: SettingsActions

    private let panelShortcuts: [(String, [String])] = [
        ("Moverse entre clips", ["←", "→"]),
        ("Pegar el clip elegido", ["↩"]),
        ("Cambiar de tipo de clip", ["⇥"]),
        ("Pegar por posición", ["⌘1–9"]),
        ("Fijar o soltar un clip", ["⌘P"]),
        ("Borrar el clip", ["⌘⌫"]),
        ("Abrir Configuración", ["⌘,"]),
        ("Cerrar el panel", ["esc"]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space6) {
            SettingGroup {
                SettingRow(title: "Abrir el historial",
                           hint: "Funciona en cualquier app, con el panel cerrado.") {
                    ShortcutRecorder(
                        value: prefs.hotKeyDisplay,
                        canRestore: prefs.hotKeyCode != Preferences.defaultHotKey.keyCode
                            || prefs.hotKeyModifiers != Preferences.defaultHotKey.modifiers,
                        onRecord: { code, mods, key in actions.setHotKey(code, mods, key) },
                        onRestore: {
                            let d = Preferences.defaultHotKey
                            _ = actions.setHotKey(d.keyCode, d.modifiers, d.key)
                        })
                }
                SettingRow(title: "Pegar como texto plano",
                           hint: "Dentro del panel, al elegir un clip. Llega cuando se guarde el formato de cada clip.",
                           divider: true, enabled: false) {
                    ShortcutRecorder(value: "⇧↩", enabled: false)
                }
            }

            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Atajos del panel").font(DS.label).foregroundStyle(Color.ds(DS.inkMuted))
                    Spacer()
                    Text("No se pueden cambiar.").font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                }
                .padding(.horizontal, DS.space1)
                SettingGroup(verticalPadding: DS.space1) {
                    ForEach(panelShortcuts.indices, id: \.self) { i in
                        HStack {
                            Text(panelShortcuts[i].0).font(DS.control)
                            Spacer()
                            HStack(spacing: DS.space1) {
                                ForEach(panelShortcuts[i].1, id: \.self) { ShortcutPill(keys: $0) }
                            }
                        }
                        .frame(height: 30)
                        .overlay(alignment: .top) { if i > 0 { Divider().overlay(Color.ds(DS.line)) } }
                    }
                }
            }
        }
    }
}

// MARK: - Historial

private struct HistorialSection: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: HistoryStore
    @Binding var dialog: ConfirmDialog?

    private let kinds: [(String, DisplayKind)] = [
        ("Texto", .text), ("Enlaces", .link), ("Colores", .color), ("Imágenes", .image), ("Archivos", .files),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup {
                SettingRow(title: "Clips que se guardan",
                           hint: "Los más antiguos se borran solos; los fijados, no.") {
                    DSPicker(options: Preferences.maxItemsOptions.map { ("\($0)", $0) },
                             selection: $prefs.maxItems,
                             onSelect: setMaxItems)
                }
                VStack(alignment: .leading, spacing: DS.space2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tipos que se guardan").font(DS.body)
                        Text("Desmarca un tipo para que no entre en el historial.")
                            .font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                    }
                    HStack(spacing: 18) {
                        ForEach(kinds, id: \.1) { title, kind in
                            DSCheckbox(title: title, isOn: Binding(
                                get: { prefs.savedKinds.contains(kind.rawValue) },
                                set: { on in
                                    if on { prefs.savedKinds.insert(kind.rawValue) } else { prefs.savedKinds.remove(kind.rawValue) }
                                }))
                        }
                    }
                }
                .padding(.vertical, DS.space3)
                .overlay(alignment: .top) { Divider().overlay(Color.ds(DS.line)) }
                SettingRow(title: "Clips en el menú de la barra",
                           hint: "Los más recientes, al abrir el icono de la barra.", divider: true) {
                    DSPicker(options: Preferences.menuClipOptions.map { ($0 == 0 ? "Ninguno" : "\($0)", $0) },
                             selection: $prefs.menuClipCount)
                }
            }

            SettingGroup {
                SettingRow(title: "Borrar el historial al salir",
                           hint: "Al cerrar ClipStack, el historial se vacía. Los fijados se conservan.") {
                    DSToggle(isOn: $prefs.clearOnQuit)
                }
                SettingRow(title: "Ubicación del historial",
                           hint: "~/Library/Application Support/ClipStack", hintMono: true, divider: true) {
                    DSButton(title: "Mostrar en Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.baseURL])
                    }
                }
            }

            SettingGroup {
                SettingRow(title: "Borrar historial",
                           hint: "Se borran todos los clips. Los fijados se conservan.") {
                    DSButton(title: "Borrar historial…", destructive: true, enabled: store.unpinnedCount > 0) {
                        let n = store.unpinnedCount, pinned = store.items.count - n
                        dialog = ConfirmDialog(
                            title: "¿Borrar el historial?",
                            message: "Se borrarán \(clips(n))." + (pinned > 0 ? " \(pinnedText(pinned))." : ""),
                            confirmTitle: "Borrar \(clips(n))",
                            onConfirm: { store.clearUnpinned() })
                    }
                }
            }
        }
    }

    /// Bajar el límite borra clips: antes se confirma.
    private func setMaxItems(_ value: Int) {
        let lost = store.unpinnedCount - value
        guard lost > 0 else { prefs.maxItems = value; return }
        dialog = ConfirmDialog(
            title: "¿Guardar solo \(value) clips?",
            message: "Se borrarán los \(clips(lost)) más antiguos. Los fijados se conservan.",
            confirmTitle: "Borrar \(clips(lost))",
            onConfirm: { prefs.maxItems = value })
    }

    private func clips(_ n: Int) -> String { n == 1 ? "1 clip" : "\(n) clips" }
    private func pinnedText(_ n: Int) -> String { n == 1 ? "El fijado se conserva" : "Los \(n) fijados se conservan" }
}

// MARK: - Privacidad

private struct PrivacidadSection: View {
    @ObservedObject var prefs: Preferences
    @State private var trusted = Paster.isTrusted
    @State private var selectedApp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space6) {
            SettingGroup {
                VStack(alignment: .leading, spacing: DS.space2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apps ignoradas").font(DS.body)
                        Text("Elige qué apps no se guardan en el historial.")
                            .font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                    }
                    appList
                }
                .padding(.vertical, DS.space3)
                SettingRow(title: "Contenido privado",
                           hint: "Lo que una app marca como privado nunca se guarda.", divider: true) {
                    Label("Siempre activo", systemImage: "lock")
                        .font(DS.control)
                        .foregroundStyle(Color.ds(DS.inkMuted))
                }
            }

            SettingGroup {
                HStack(spacing: DS.space4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permiso de Accesibilidad").font(DS.body)
                        if trusted {
                            Text("Hace falta para pegar en la app activa.")
                                .font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                        } else {
                            Label("No concedido. Sin él, ClipStack solo copia.", systemImage: "exclamationmark.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.ds(DS.coralInk))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if trusted {
                        Label("Concedido", systemImage: "checkmark.circle").font(DS.label)
                    } else {
                        DSButton(title: "Abrir Ajustes del Sistema") { openAccessibility() }
                    }
                }
                .padding(.vertical, DS.space3)
            }

            SettingGroup {
                SettingRow(title: "Pausar ClipStack", hint: "Deja de guardar clips un rato.") {
                    HStack(spacing: DS.space3) {
                        DSSegmented(options: [("15 min", 15), ("1 h", 60)], selection: Binding(
                            get: { prefs.pauseMinutes },
                            set: { prefs.pauseMinutes = $0; if prefs.isPaused { prefs.setPaused(true) } }))
                        DSToggle(isOn: Binding(get: { prefs.isPaused }, set: { prefs.setPaused($0) }))
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = Paster.isTrusted
        }
    }

    private var appList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                if prefs.ignoredApps.isEmpty {
                    VStack(spacing: 2) {
                        Text("Ninguna app ignorada").font(DS.control)
                        Text("Añade una con el botón +").font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                } else {
                    ForEach(prefs.ignoredApps) { app in
                        let selected = app.bundleID == selectedApp
                        HStack(spacing: 10) {
                            appIcon(app)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(app.name).font(DS.control)
                                Text(app.bundleID)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.ds(selected ? DS.onBrandInk : DS.inkMuted))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(Color.ds(selected ? DS.onBrandInk : DS.ink))
                        .background(selected ? Color.ds(DS.brandInk) : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedApp = app.bundleID }
                        .overlay(alignment: .bottom) { Divider().overlay(Color.ds(DS.line)) }
                    }
                }
            }
            .background(Color.ds(DS.surface))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: DS.radiusMd, topTrailingRadius: DS.radiusMd, style: .continuous))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: DS.radiusMd, topTrailingRadius: DS.radiusMd, style: .continuous)
                .strokeBorder(Color.ds(DS.line)))

            HStack(spacing: 0) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 24)
                    .pressable(radius: 0) { addApp() }
                    .accessibilityLabel("Añadir app")
                Rectangle().fill(Color.ds(DS.line)).frame(width: 1, height: 24)
                Image(systemName: "minus")
                    .frame(width: 30, height: 24)
                    .pressable(radius: 0, enabled: selectedApp != nil) { removeSelected() }
                    .accessibilityLabel("Quitar app")
            }
            .font(.system(size: 11, weight: .medium))
            .background(Color.ds(DS.surfaceRaised))
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: DS.radiusMd, bottomTrailingRadius: DS.radiusMd, style: .continuous))
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: DS.radiusMd, bottomTrailingRadius: DS.radiusMd, style: .continuous)
                .strokeBorder(Color.ds(DS.line)))
            .offset(y: -1)
        }
    }

    @ViewBuilder private func appIcon(_ app: Preferences.IgnoredApp) -> some View {
        if let icon = AppIcons.icon(for: app.bundleID) {
            Image(nsImage: icon).resizable().frame(width: 24, height: 24)
        } else {
            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.ds(DS.inkMuted))
                .frame(width: 24, height: 24)
                .background(Color.ds(DS.surfaceRaised), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignorar"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  !prefs.ignoredApps.contains(where: { $0.bundleID == id }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            prefs.ignoredApps.append(.init(name: name, bundleID: id))
        }
    }

    private func removeSelected() {
        prefs.ignoredApps.removeAll { $0.bundleID == selectedApp }
        selectedApp = nil
    }

    private func openAccessibility() {
        Paster.requestAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Pegado

private struct PegadoSection: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space6) {
            SettingGroup {
                SettingRow(title: "Al elegir un clip",
                           hint: prefs.pasteMode == .paste
                               ? "El clip se pega en la app activa; el panel se cierra."
                               : "El clip se queda en el portapapeles y lo pegas tú con ⌘V.") {
                    DSSegmented(options: [("Pegar en la app", Preferences.PasteMode.paste), ("Solo copiar", .copy)],
                                selection: $prefs.pasteMode)
                }
                SettingRow(title: "Mover el clip pegado arriba",
                           hint: "El clip que pegas pasa a ser el más reciente.", divider: true) {
                    DSToggle(isOn: $prefs.bumpOnPaste)
                }
                SettingRow(title: "Pegar siempre sin formato",
                           hint: "Quita negritas, colores y tamaños al pegar. Llega cuando se guarde el formato de cada clip.",
                           divider: true, enabled: false) {
                    DSToggle(isOn: .constant(false), enabled: false)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("Para pegar en la app activa, ClipStack necesita el permiso de Accesibilidad. Lo revisas en Privacidad.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(DS.caption)
            .foregroundStyle(Color.ds(DS.inkMuted))
            .padding(.horizontal, DS.space1)
        }
    }
}

// MARK: - Apariencia

private struct AparienciaSection: View {
    @ObservedObject var prefs: Preferences
    private let sample = "Lista de la compra: pan, café, leche, tomates, aceite y dos cajas de pasta."

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space6) {
            SettingGroup {
                SettingRow(title: "Tema", hint: "Sigue al sistema o fuerza uno.") {
                    DSSegmented(options: [("Sistema", Preferences.Theme.system), ("Claro", .light), ("Oscuro", .dark)],
                                selection: $prefs.theme)
                }
                SettingRow(title: "Color de la cabecera de las tarjetas",
                           hint: "El de la app de la que copiaste, o el de ClipStack.", divider: true) {
                    DSSegmented(options: [("Color de la app", Preferences.HeaderColor.app), ("Color de marca", .brand)],
                                selection: $prefs.headerColor)
                }
                SettingRow(title: "Vista previa",
                           hint: prefs.headerColor == .brand
                               ? "Todas las tarjetas llevan el color de ClipStack."
                               : "Cada tarjeta lleva el color de su app.",
                           divider: true) {
                    preview
                }
            }
            SettingGroup {
                SettingRow(title: "Posición del panel", hint: "Dónde aparece el historial al pulsar \(prefs.hotKeyDisplay).") {
                    DSSegmented(options: [("Abajo", Preferences.PanelPosition.bottom), ("Arriba", .top)],
                                selection: $prefs.panelPosition)
                }
                SettingRow(title: "Tamaño de las tarjetas", hint: "Compacto enseña más clips a la vez.", divider: true) {
                    DSSegmented(options: [("Normal", Preferences.CardSize.normal), ("Compacto", .compact)],
                                selection: $prefs.cardSize)
                }
            }
        }
    }

    private var preview: some View {
        let header = CardHeaderStyle.colors(for: "com.apple.Notes", prefs: prefs)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(header.chip).frame(width: 12, height: 12)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.15)))
                    Text("Notas")
                }
                Spacer()
                Text("hace 2 min").fontWeight(.regular)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(header.ink)
            .padding(.horizontal, DS.space3)
            .frame(height: 30)
            .background(header.background)
            Text(sample)
                .font(DS.caption)
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12))
            Text("Texto · \(sample.count) caracteres")
                .font(.system(size: 11))
                .foregroundStyle(Color.ds(DS.inkMuted))
                .padding(EdgeInsets(top: 0, leading: 12, bottom: 10, trailing: 12))
        }
        .frame(width: 236)
        .background(Color.ds(DS.surface))
        .clipShape(RoundedRectangle(cornerRadius: DS.space3, style: .continuous))
        .shadow(color: Color.ds(DS.shadowCard), radius: 12, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vista previa de una tarjeta del historial")
    }
}

// MARK: - Barra de menús

private struct MenuBarSection: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space6) {
            SettingGroup {
                SettingRow(title: "Mostrar los últimos clips como tarjetas",
                           hint: "Apagado, se muestran como una lista de texto.") {
                    DSToggle(isOn: $prefs.menuShowsCards)
                }
                SettingRow(title: "Punto de clip nuevo",
                           hint: "Un punto en el icono cuando hay un clip que aún no has usado.", divider: true) {
                    DSToggle(isOn: $prefs.newClipDot)
                }
            }
            SettingGroup {
                SettingRow(title: "Vista previa del menú",
                           hint: prefs.menuShowsCards
                               ? "Los clips como tarjetas con el color de su app."
                               : "Los clips como texto, de un vistazo.") {
                    menuPreview
                }
            }
        }
    }

    private var recent: [ClipItem] {
        Array(store.items.sorted { $0.date > $1.date }.prefix(prefs.menuShowsCards ? 3 : 5))
    }

    private var menuPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Últimos clips")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.ds(DS.inkMuted))
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 2, trailing: 8))
            if recent.isEmpty {
                Text("Copia algo y aparecerá aquí")
                    .foregroundStyle(Color.ds(DS.inkMuted))
                    .frame(height: 22).padding(.horizontal, 8)
            } else if prefs.menuShowsCards {
                HStack(spacing: 6) {
                    ForEach(recent) { item in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(CardHeaderStyle.colors(for: item.sourceBundleID, prefs: prefs).background)
                                .frame(height: 7)
                            Text(item.title)
                                .font(.system(size: 10))
                                .lineLimit(3)
                                .padding(.horizontal, 7).padding(.vertical, 5)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .topLeading)
                        .background(Color.ds(DS.surfaceRaised))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ds(DS.line)))
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
            } else {
                ForEach(recent) { item in
                    Text(item.title).lineLimit(1).frame(height: 22).padding(.horizontal, 8)
                }
            }
            Divider().overlay(Color.ds(DS.line)).padding(.vertical, 4).padding(.horizontal, 8)
            menuLine("Abrir historial", prefs.hotKeyDisplay)
            menuLine("Pausar \(prefs.pauseLabel)", nil)
            menuLine("Configuración…", "⌘,")
            Divider().overlay(Color.ds(DS.line)).padding(.vertical, 4).padding(.horizontal, 8)
            menuLine("Salir de ClipStack", "⌘Q")
        }
        .font(DS.control)
        .padding(4)
        .frame(width: 250)
        .background(Color.ds(DS.surface), in: RoundedRectangle(cornerRadius: DS.radiusMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.radiusMd, style: .continuous).strokeBorder(Color.ds(DS.line)))
        .shadow(color: Color.ds(DS.shadowCard), radius: 12, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vista previa del menú de la barra")
    }

    private func menuLine(_ title: String, _ keys: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let keys {
                Text(keys).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.ds(DS.inkMuted))
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 8)
    }
}

// MARK: - Acerca de

private struct AcercaSection: View {
    @ObservedObject var prefs: Preferences
    @Binding var dialog: ConfirmDialog?
    @Environment(\.colorScheme) private var colorScheme

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Versión \(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 6) {
                if let logo = Self.logo(dark: colorScheme == .dark) {
                    Image(nsImage: logo).resizable().frame(width: 248, height: 72).padding(.bottom, 6)
                        .accessibilityLabel("ClipStack")
                } else {
                    Text("ClipStack").font(.system(size: 32, weight: .semibold)).tracking(-0.64)
                }
                Text(version).font(DS.label)
                Text("Hecho para gente que vive en el teclado.")
                    .font(DS.caption).foregroundStyle(Color.ds(DS.inkMuted))
                DSButton(title: "Comprobar actualizaciones", enabled: false) {}
                    .padding(.top, DS.space3)
            }
            .padding(EdgeInsets(top: 28, leading: DS.space4, bottom: DS.space6, trailing: DS.space4))
            .frame(maxWidth: .infinity)
            .background(Color.ds(DS.surfaceRaised), in: RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))

            SettingGroup {
                SettingRow(title: "Restablecer ajustes",
                           hint: "Vuelve a los valores de fábrica. El historial y los fijados no se tocan.") {
                    DSButton(title: "Restablecer…", destructive: true) {
                        dialog = ConfirmDialog(
                            title: "¿Restablecer los ajustes?",
                            message: "Vuelven los valores de fábrica. El historial y los fijados no se tocan.",
                            confirmTitle: "Restablecer",
                            onConfirm: { prefs.reset() })
                    }
                }
            }
        }
    }

    private static func logo(dark: Bool) -> NSImage? {
        Bundle.main.url(forResource: dark ? "LogoDark" : "LogoLight", withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))
    }
}
