import AppKit
import SwiftUI

/// Tokens del design system (tokens.json). Es el único archivo con colores hex.
@MainActor
enum DS {
    // MARK: - Color (cambian con la apariencia del sistema)

    static let surface = dynamic("surface", light: 0xffffff, dark: 0x0f1020)
    static let surfaceRaised = dynamic("surface-raised", light: 0xf2f3f7, dark: 0x1a1b2e)
    static let line = dynamic("line", light: 0xe3e5ef, dark: 0x2a2c44)
    static let ink = dynamic("ink", light: 0x14142b, dark: 0xf2f3ff)
    static let inkMuted = dynamic("ink-muted", light: 0x5b5f7a, dark: 0xa3a7c2)
    static let brandInk = dynamic("brand-ink", light: 0x3f32e0, dark: 0x8fb8ff)
    static let coralInk = dynamic("coral-ink", light: 0xc8402b, dark: 0xff8a74)
    static let focusRing = dynamic("focus-ring", light: 0x3f32e0, dark: 0x8fb8ff)

    /// Texto sobre un relleno `brand-ink`: blanco en claro y oscuro en el tema oscuro,
    /// porque ahí `brand-ink` es un azul claro (diseño de Configuración).
    static let onBrandInk = dynamic("on-brand-ink", light: 0xffffff, dark: 0x0f1020)

    // Controles de Configuración (diseño de Claude Design).
    static let knob = dynamic("knob", light: 0xffffff, dark: 0xf2f3ff)
    static let segTrack = dynamic("seg-track", light: 0xe3e5ef, dark: 0x0f1020)
    static let segOn = dynamic("seg-on", light: 0xffffff, dark: 0x2a2c44)

    static let shadowCard = dynamic("shadow-card", light: 0x1b1570, lightAlpha: 0.18, dark: 0x000000, darkAlpha: 0.55)
    static let scrim = NSColor(hex: 0x0f1020, alpha: 0.35)

    // Iguales en los dos temas.
    static let indigo = NSColor(hex: 0x3f32e0)
    static let blue = NSColor(hex: 0x2e8eff)
    static let indigoDeep = NSColor(hex: 0x1b1570)
    static let coral = NSColor(hex: 0xff6b57)
    static let orange = NSColor(hex: 0xff8f4d)
    static let card = NSColor(hex: 0xffffff)
    static let cardTint = NSColor(hex: 0xe8efff)
    static let glass = NSColor(hex: 0xd9e4ff)
    static let onBrand = NSColor(hex: 0xffffff)
    static let onCoral = NSColor(hex: 0x14142b)

    // MARK: - Tipografía (SF Pro del sistema con la escala de tokens.json)

    nonisolated static let title = Font.system(size: 20, weight: .semibold)
    nonisolated static let body = Font.system(size: 15)
    nonisolated static let label = Font.system(size: 13, weight: .medium)
    nonisolated static let control = Font.system(size: 13)
    nonisolated static let caption = Font.system(size: 12)
    nonisolated static let shortcut = Font.system(size: 13, weight: .medium, design: .monospaced)
    nonisolated static let titleTracking: CGFloat = -0.2

    // MARK: - Forma

    nonisolated static let space1: CGFloat = 4
    nonisolated static let space2: CGFloat = 8
    nonisolated static let space3: CGFloat = 12
    nonisolated static let space4: CGFloat = 16
    nonisolated static let space6: CGFloat = 24
    nonisolated static let space8: CGFloat = 32

    nonisolated static let radiusSm: CGFloat = 6
    nonisolated static let radiusMd: CGFloat = 10
    nonisolated static let radiusLg: CGFloat = 16
    nonisolated static let radiusXl: CGFloat = 24

    private static func dynamic(_ name: String, light: UInt32, lightAlpha: CGFloat = 1,
                                dark: UInt32, darkAlpha: CGFloat = 1) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: darkAlpha)
                : NSColor(hex: light, alpha: lightAlpha)
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    @MainActor static func ds(_ color: NSColor) -> Color { Color(nsColor: color) }
}
