import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let prefs = Preferences.shared
    private let store = HistoryStore()
    private var monitor: ClipboardMonitor!
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var hotKey: HotKey?
    private var settingsWindow: NSWindow?
    private var prefsObserver: AnyCancellable?

    private var menu: NSMenu!
    private var recentMenuItems: [NSMenuItem] = []
    private var openItem: NSMenuItem!
    private var pauseItem: NSMenuItem!

    private var baseIcon: NSImage?
    private var hasNewClip = false

    private var panelHeight: CGFloat { prefs.cardSize == .compact ? 276 : 340 }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // sin icono en el Dock

        monitor = ClipboardMonitor(store: store)
        monitor.onNewClip = { [weak self] in self?.clipAdded() }
        monitor.start()

        panel = FloatingPanel()
        panel.onResignKey = { [weak self] in self?.hidePanel() }
        setupStatusItem()

        registerHotKey(prefs.hotKeyCode, prefs.hotKeyModifiers)
        applyPreferences()
        prefsObserver = prefs.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.applyPreferences() } }

        if !Paster.isTrusted { Paster.requestAccess() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if prefs.clearOnQuit { store.clearUnpinned() }
    }

    /// Aplica los ajustes que no se leen en el momento de usarlos.
    private func applyPreferences() {
        statusItem.isVisible = prefs.showMenuBarIcon
        switch prefs.theme {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        if store.maxItems != prefs.maxItems {
            store.maxItems = prefs.maxItems
            store.applyLimit()
        }
        if !prefs.newClipDot { hasNewClip = false }
        updateStatusIcon()
        let shortcut = prefs.hotKeyMenuEquivalent
        openItem.keyEquivalent = shortcut.key
        openItem.keyEquivalentModifierMask = shortcut.mask
    }

    // MARK: - Atajo global

    @discardableResult
    private func registerHotKey(_ code: UInt32, _ modifiers: UInt32) -> Bool {
        hotKey = nil // libera el registro anterior
        let key = HotKey(keyCode: code, modifiers: modifiers) { [weak self] in
            MainActor.assumeIsolated { self?.togglePanel() }
        }
        guard key.isRegistered else { return false }
        hotKey = key
        return true
    }

    /// Cambia el atajo desde Configuración; si el nuevo está ocupado, vuelve al anterior.
    private func setHotKey(_ code: UInt32, _ modifiers: UInt32, _ key: String) -> Bool {
        guard registerHotKey(code, modifiers) else {
            registerHotKey(prefs.hotKeyCode, prefs.hotKeyModifiers)
            return false
        }
        prefs.hotKeyCode = code
        prefs.hotKeyModifiers = modifiers
        prefs.hotKeyKey = key
        return true
    }

    // MARK: - Barra de menús

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        baseIcon = Self.menuBarIcon()
        statusItem.button?.image = baseIcon

        menu = NSMenu()
        menu.delegate = self
        menu.addItem(.separator())
        openItem = addItem(to: menu, "Abrir historial", #selector(showFromMenu))
        pauseItem = addItem(to: menu, "", #selector(togglePause))
        let settings = addItem(to: menu, "Configuración…", #selector(openSettings))
        settings.keyEquivalent = ","
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir de ClipStack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    /// El icono de la marca si va en el bundle (ver build_app.sh); si no, el SF Symbol.
    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipStack")
    }

    /// Clip nuevo: sonido y punto en el icono, según Configuración.
    private func clipAdded() {
        if prefs.soundOnCopy { NSSound(named: "Tink")?.play() }
        if prefs.newClipDot && !panel.isVisible {
            hasNewClip = true
            updateStatusIcon()
        }
    }

    private func updateStatusIcon() {
        guard let baseIcon else { return }
        statusItem.button?.image = hasNewClip ? Self.withDot(baseIcon) : baseIcon
    }

    private static func withDot(_ base: NSImage) -> NSImage {
        let image = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            NSBezierPath(ovalIn: NSRect(x: rect.maxX - 5, y: rect.maxY - 5, width: 5, height: 5)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        hasNewClip = false
        updateStatusIcon()
        pauseItem.title = prefs.isPaused ? "Reanudar" : "Pausar \(prefs.pauseLabel)"
        updateRecentClips()
    }

    private func updateRecentClips() {
        recentMenuItems.forEach(menu.removeItem)
        recentMenuItems = []
        guard prefs.menuClipCount > 0 else { return }

        var items: [NSMenuItem] = [.sectionHeader(title: "Últimos clips")]
        let recent = Array(store.items.sorted { $0.date > $1.date }.prefix(prefs.menuClipCount))
        if recent.isEmpty {
            let empty = NSMenuItem(title: "Copia algo y aparecerá aquí", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            items.append(empty)
        } else if prefs.menuShowsCards {
            let view = RecentClipsView(items: recent, store: store) { [weak self] item in
                self?.pasteFromMenu(item)
            }
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = hosting.fittingSize
            let cards = NSMenuItem()
            cards.view = hosting
            items.append(cards)
        } else {
            for clip in recent {
                let title = clip.title.split(whereSeparator: \.isNewline).first.map(String.init) ?? clip.title
                let item = NSMenuItem(title: String(title.prefix(48)), action: #selector(pasteMenuItem(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = clip.id
                items.append(item)
            }
        }
        for (i, item) in items.enumerated() { menu.insertItem(item, at: i) }
        recentMenuItems = items
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showFromMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.showPanel() }
    }

    @objc private func togglePause() {
        prefs.setPaused(!prefs.isPaused)
    }

    @objc private func pasteMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        pasteFromMenu(item)
    }

    private func pasteFromMenu(_ item: ClipItem) {
        statusItem.menu?.cancelTracking()
        // Espera a que se cierre el menú para que ⌘V llegue a la app de destino.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.paste(item) }
    }

    // MARK: - Configuración

    @objc private func openSettings() {
        hidePanel(animated: false)
        if settingsWindow == nil {
            let view = SettingsView(prefs: prefs, store: store, actions: SettingsActions(
                setHotKey: { [weak self] code, mods, key in self?.setHotKey(code, mods, key) ?? false }))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Configuración"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // Una barra de herramientas vacía da a la barra de título los 52 pt del diseño.
            window.toolbar = NSToolbar()
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = DS.surface
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }
        // A diferencia del panel, esta ventana sí activa la app: necesita su propio teclado.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel

    private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        hasNewClip = false
        updateStatusIcon()

        let view = HistoryView(
            store: store,
            onPaste: { [weak self] item in self?.paste(item) },
            onClose: { [weak self] in self?.hidePanel() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            cardSize: prefs.cardSize == .compact ? ClipCard.compactSize : ClipCard.regularSize
        )
        // Se recrea cada vez para limpiar la búsqueda y la selección.
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        panel.contentView = hosting

        // Aparece abajo (o arriba) en la pantalla donde está el cursor.
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        let top = prefs.panelPosition == .top
        let y = top ? vf.maxY - 10 - panelHeight : vf.minY + 10
        let target = NSRect(x: vf.minX + 10, y: y, width: vf.width - 20, height: panelHeight)

        var start = target
        start.origin.y += top ? 40 : -40
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanel(animated: Bool = true) {
        guard panel.isVisible else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        var end = panel.frame
        end.origin.y += prefs.panelPosition == .top ? 40 : -40
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().setFrame(end, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        })
    }

    private func paste(_ item: ClipItem) {
        monitor.ignoreChangeCount = Paster.write(item, store: store)
        if prefs.bumpOnPaste { store.bump(item) }
        hidePanel(animated: false)

        // En "Solo copiar", o sin permiso de Accesibilidad, el clip queda copiado y se pega con ⌘V a mano.
        guard prefs.pasteMode == .paste, Paster.isTrusted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Paster.sendCommandV()
        }
    }
}
