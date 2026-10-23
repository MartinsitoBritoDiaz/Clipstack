import AppKit

/// Panel sin bordes y "no activador": recibe el teclado sin quitarle el foco
/// a la app en la que estás, así ⌘V termina pegando en el lugar correcto.
final class FloatingPanel: NSPanel {
    var onResignKey: (@MainActor () -> Void)?

    init() {
        super.init(contentRect: .zero,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    /// Se oculta al hacer clic fuera.
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
