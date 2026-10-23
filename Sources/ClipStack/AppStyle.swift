import AppKit
import SwiftUI

/// Iconos de apps y su color dominante (para la cabecera de cada tarjeta).
@MainActor
enum AppIcons {
    private static var iconCache: [String: NSImage] = [:]
    private static var colorCache: [String: NSColor] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let id = bundleID else { return nil }
        if let cached = iconCache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[id] = img
        return img
    }

    static func color(for bundleID: String?) -> NSColor {
        let fallback = NSColor(deviceRed: 0.42, green: 0.45, blue: 0.52, alpha: 1)
        guard let id = bundleID else { return fallback }
        if let cached = colorCache[id] { return cached }
        let c = icon(for: id).flatMap(dominantColor) ?? fallback
        colorCache[id] = c
        return c
    }

    /// Promedio de los píxeles del icono, dando más peso a los colores saturados.
    private static func dominantColor(of image: NSImage) -> NSColor? {
        let size = 24
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()

        var r = 0.0, g = 0.0, b = 0.0, total = 0.0
        for x in 0..<size {
            for y in 0..<size {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 else { continue }
                let s = Double(c.saturationComponent)
                let w = 0.1 + s * s * 4
                r += Double(c.redComponent) * w
                g += Double(c.greenComponent) * w
                b += Double(c.blueComponent) * w
                total += w
            }
        }
        guard total > 0 else { return nil }
        let avg = NSColor(deviceRed: r / total, green: g / total, blue: b / total, alpha: 1)
        // Normaliza para que todas las cabeceras tengan una intensidad parecida.
        return NSColor(deviceHue: avg.hueComponent,
                       saturation: min(avg.saturationComponent * 1.2, 0.85),
                       brightness: min(max(avg.brightnessComponent, 0.5), 0.88),
                       alpha: 1)
    }
}

/// Colores de la cabecera de una tarjeta: el de la app de origen o el de marca (Configuración › Apariencia).
@MainActor
enum CardHeaderStyle {
    static func colors(for bundleID: String?, prefs: Preferences? = nil)
        -> (background: Color, ink: Color, chip: Color) {
        if (prefs ?? .shared).headerColor == .brand {
            return (Color.ds(DS.brandInk), Color.ds(DS.onBrandInk), Color.ds(DS.onBrandInk))
        }
        let accent = AppIcons.color(for: bundleID)
        return (Color(nsColor: accent), Color.ds(accent.isLight ? DS.onCoral : DS.onBrand), Color.ds(DS.card))
    }
}

extension NSColor {
    var isLight: Bool {
        let c = usingColorSpace(.deviceRGB) ?? self
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.7
    }
}

/// Fondo translúcido nativo de macOS (desenfoca lo que hay detrás).
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
