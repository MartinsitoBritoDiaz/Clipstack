import AppKit

// El código de nivel superior no está aislado al MainActor en los compiladores nuevos,
// así que se ejecuta explícitamente en el hilo principal.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
