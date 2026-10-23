import AppKit
import ApplicationServices

enum Paster {
    /// Para simular ⌘V hace falta el permiso de Accesibilidad.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Escribe el elemento en el portapapeles y devuelve el nuevo changeCount.
    @MainActor @discardableResult
    static func write(_ item: ClipItem, store: HistoryStore) -> Int {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text ?? "", forType: .string)
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                pb.writeObjects([img])
            }
        case .files:
            let urls = (item.fileURLs ?? []).compactMap { URL(string: $0) }
            pb.writeObjects(urls.map { $0 as NSURL })
        }
        return pb.changeCount
    }

    /// Envía ⌘V a la app que está al frente.
    static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
