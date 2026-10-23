import Foundation

enum ClipKind: String, Codable {
    case text, image, files
}

/// Cómo se muestra la tarjeta (se deduce del contenido).
enum DisplayKind: String, CaseIterable {
    case text, link, color, image, files
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var imageFile: String?       // nombre del PNG dentro de Application Support/ClipStack/images
    var fileURLs: [String]?      // URLs absolutas (file://...)
    var contentHash: String      // para evitar duplicados
    var sourceAppName: String?
    var sourceBundleID: String?
    var date = Date()
    var pinned = false

    var fileNames: [String] {
        (fileURLs ?? []).compactMap { URL(string: $0)?.lastPathComponent }
    }

    var trimmedText: String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayKind: DisplayKind {
        switch kind {
        case .image: return .image
        case .files: return .files
        case .text:
            let t = trimmedText
            if Self.hexColor(from: t) != nil { return .color }
            if !t.contains(where: \.isWhitespace),
               let url = URL(string: t),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https",
               url.host != nil {
                return .link
            }
            return .text
        }
    }

    /// Texto que se usa para la búsqueda.
    var searchableText: String {
        switch kind {
        case .text:  return text ?? ""
        case .image: return "imagen image"
        case .files: return fileNames.joined(separator: " ")
        }
    }

    /// Texto que se muestra en la tarjeta.
    var title: String {
        switch kind {
        case .text:
            return String(trimmedText.prefix(600))
        case .image:
            return "Imagen"
        case .files:
            let names = fileNames
            if names.count == 1 { return names[0] }
            return names.prefix(3).joined(separator: ", ") + (names.count > 3 ? "…" : "")
        }
    }

    /// "#RRGGBB" → componentes 0...1
    static func hexColor(from s: String) -> (r: Double, g: Double, b: Double)? {
        guard s.hasPrefix("#") else { return nil }
        let hex = String(s.dropFirst())
        guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}
