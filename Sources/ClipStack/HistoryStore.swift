import AppKit
import CryptoKit

/// Guarda el historial en ~/Library/Application Support/ClipStack
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    /// Máximo de elementos NO fijados que se conservan.
    var maxItems = Preferences.shared.maxItems

    let baseURL: URL
    private let imagesDir: URL
    private let dbURL: URL
    private let thumbCache = NSCache<NSString, NSImage>()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = support.appendingPathComponent("ClipStack", isDirectory: true)
        baseURL = base
        imagesDir = base.appendingPathComponent("images", isDirectory: true)
        dbURL = base.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Añadir

    var unpinnedCount: Int { items.filter { !$0.pinned }.count }

    @discardableResult
    func addText(_ text: String, app: NSRunningApplication?) -> Bool {
        insert(ClipItem(kind: .text,
                        text: text,
                        contentHash: Self.hash(Data(text.utf8)),
                        sourceAppName: app?.localizedName,
                        sourceBundleID: app?.bundleIdentifier))
    }

    @discardableResult
    func addImage(png: Data, app: NSRunningApplication?) -> Bool {
        guard Preferences.shared.allows(.image) else { return false }
        let h = Self.hash(png)
        let name = "\(h).png"
        let url = imagesDir.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? png.write(to: url)
        }
        return insert(ClipItem(kind: .image,
                        imageFile: name,
                        contentHash: h,
                        sourceAppName: app?.localizedName,
                        sourceBundleID: app?.bundleIdentifier))
    }

    @discardableResult
    func addFiles(_ urls: [URL], app: NSRunningApplication?) -> Bool {
        let strings = urls.map(\.absoluteString)
        return insert(ClipItem(kind: .files,
                        fileURLs: strings,
                        contentHash: Self.hash(Data(strings.joined(separator: "\n").utf8)),
                        sourceAppName: app?.localizedName,
                        sourceBundleID: app?.bundleIdentifier))
    }

    /// Devuelve false si el tipo de clip no se guarda (ver Configuración › Historial).
    private func insert(_ newItem: ClipItem) -> Bool {
        guard Preferences.shared.allows(newItem.displayKind) else { return false }
        var item = newItem
        // Si ya existe, lo sube arriba conservando su id y si estaba fijado.
        if let idx = items.firstIndex(where: { $0.contentHash == item.contentHash }) {
            item.id = items[idx].id
            item.pinned = items[idx].pinned
            items.remove(at: idx)
        }
        items.insert(item, at: 0)
        trim()
        save()
        return true
    }

    // MARK: - Acciones

    /// Mueve un elemento arriba del todo cuando se vuelve a pegar.
    func bump(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var it = items.remove(at: idx)
        it.date = Date()
        items.insert(it, at: 0)
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].pinned.toggle()
        save()
    }

    func delete(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        removeImageFile(of: items.remove(at: idx))
        save()
    }

    func clearUnpinned() {
        items.filter { !$0.pinned }.forEach(removeImageFile)
        items.removeAll { !$0.pinned }
        save()
    }

    // MARK: - Imágenes

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard let file = item.imageFile else { return nil }
        if let cached = thumbCache.object(forKey: file as NSString) { return cached }
        guard let img = NSImage(contentsOf: imagesDir.appendingPathComponent(file)) else { return nil }
        thumbCache.setObject(img, forKey: file as NSString)
        return img
    }

    private func removeImageFile(of item: ClipItem) {
        guard let file = item.imageFile else { return }
        try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file))
        thumbCache.removeObject(forKey: file as NSString)
    }

    /// Aplica un `maxItems` nuevo.
    func applyLimit() {
        trim()
        save()
    }

    // MARK: - Persistencia

    private func trim() {
        var unpinned = 0
        var kept: [ClipItem] = []
        for it in items {
            if it.pinned {
                kept.append(it)
            } else {
                unpinned += 1
                if unpinned <= maxItems { kept.append(it) } else { removeImageFile(of: it) }
            }
        }
        items = kept
    }

    private func load() {
        guard let data = try? Data(contentsOf: dbURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
        // Aplica el límite también a historiales guardados con un máximo mayor.
        let count = items.count
        trim()
        if items.count != count { save() }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: dbURL, options: .atomic)
    }
}
