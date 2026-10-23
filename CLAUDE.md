# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ClipStack — instrucciones para el agente

Eres el ingeniero principal de ClipStack, un gestor de portapapeles nativo para macOS 14+ escrito en Swift + SwiftUI/AppKit, sin dependencias externas. Tu trabajo tiene dos fases: primero implementar el design system de la marca en la app existente, y después añadir funcionalidades nuevas sin romper lo que ya funciona.

## El proyecto

Swift Package (`Package.swift`) en `Sources/ClipStack/`, que se empaqueta como `.app` con `./build_app.sh`.

- `AppDelegate.swift`: icono de barra de menús, atajo global ⇧⌘V, mostrar/ocultar el panel y la lógica de pegado.
- `ClipboardMonitor.swift`: consulta `NSPasteboard.changeCount` cada 0,4 s; ignora los tipos concealed/transient y los gestores de contraseñas.
- `HistoryStore.swift`: historial en `~/Library/Application Support/ClipStack/` (JSON + PNGs), deduplicación por SHA-256, fijados y límite de 20 elementos (sin contar los fijados).
- `HistoryView.swift`: panel con búsqueda, filtros y tarjetas horizontales (`ClipCard`).
- `AppStyle.swift`: color dominante del icono de cada app, cachés y `VisualEffectBackground`.
- `FloatingPanel.swift`: `NSPanel` borderless y `.nonactivatingPanel`. Recibe el teclado sin robarle el foco a la app de destino. **No cambies esto**: es lo que hace que ⌘V pegue en el lugar correcto.
- `Preferences.swift`: ajustes del usuario en `UserDefaults` (`Preferences.shared`). `AppDelegate` observa sus cambios y aplica los que no se leen al usarse (icono, tema, límite del historial).
- `SettingsView.swift` y `SettingsControls.swift`: ventana de Configuración (⌘,) según el diseño de Claude Design (https://claude.ai/artifact/Vap6LDWVoVYx2UhPCZ9ugQ). Es un `NSWindow` normal que sí activa la app, al contrario que el panel.
- `DesignSystem.swift`: tokens de `tokens.json` (`DS`). Único archivo con colores hex.
- `HotKey.swift`: atajo global con Carbon. `Paster.swift`: escribe en el pasteboard y simula ⌘V con `CGEvent` (requiere el permiso de Accesibilidad).

## Design system (fuente de verdad)

Lee `DESIGN.md` y `tokens.json` antes de tocar la UI. Mandan sobre cualquier valor que haya hoy en el código. Los assets están en `assets/` (`Iconos`, `MenuBar`, `Logotipos`) y la dirección elegida es **abanico**. El original es el design system "ClipStack" de Claude Design: https://claude.ai/artifact/GZ7w1BN8UMt1p3Dt4aVR8X

Resumen de lo esencial:

- **Color**: crea `Sources/ClipStack/DesignSystem.swift` con un token por cada entrada de `tokens.json`, con sus variantes clara y oscura. Usa `NSColor(name:dynamicProvider:)` para que cambien con la apariencia del sistema. Los tokens son `surface`, `surface-raised`, `line`, `ink`, `ink-muted`, `brand-ink`, `coral-ink`, `focus-ring`, `on-brand`, `on-coral`, `indigo`, `blue`, `indigo-deep`, `coral`, `orange`, `card`, `card-tint` y `glass`. Los degradados son `gradient-brand` (indigo → blue, 135°), `gradient-warm` (coral → orange) y `gradient-card`. Ningún color hex suelto fuera de ese archivo.
- **Tipografía**: dentro de la app, SF Pro del sistema (no incrustes Inter), con la escala de `tokens.json`: title 20/26 600 (−0,01 em), body 15/22 400, label 13/18 500, caption 12/16 400 y shortcut 13/18 500. Los atajos van con símbolos (⇧⌘V) en una pastilla `surface-raised` con `radius-sm`.
- **Forma**: espacios `space-1`…`space-8` (4, 8, 12, 16, 24 y 32). Radios `radius-sm` 6, `radius-md` 10, `radius-lg` 16 (tarjetas) y `radius-xl` 24 (el panel), siempre con `style: .continuous`. Una sola sombra `shadow-card` por tarjeta, teñida de `indigo-deep` en claro y negra al 55 % en oscuro.
- **Selección y foco**: la tarjeta seleccionada usa `brand-ink`. El foco de teclado es un anillo sólido de 2 px en `focus-ring` con 2 px de separación, siempre visible.
- **Acento cálido**: `coral` solo en un elemento a la vez. `coral-ink` se usa para acciones destructivas (eliminar o borrar el historial). El texto sobre coral va en `on-coral`, nunca en blanco.
- **Cabeceras de tarjeta**: hoy usan el color dominante del icono de la app de origen. Conserva esa función, pero ajusta esos colores para que convivan con la paleta y respeten el contraste. Si el resultado choca con el design system, propónme alternativas antes de decidir.
- **Icono de app**: genera `AppIcon.icns` con `sips` + `iconutil` a partir de `assets/Iconos/abanico-app-icon-1024.png`. Añade `CFBundleIconFile` al Info.plist que crea `build_app.sh`. No añadas sombra ni borde, porque ya vienen en el PNG.
- **Icono de barra de menús**: reemplaza el SF Symbol por `assets/MenuBar/abanico-menubar-template-18.svg`, cargado como `NSImage` con `isTemplate = true`. No lo modifiques, porque los huecos de 0,55 pt entre tarjetas son intencionales. Para indicar algo nuevo en el historial, usa un punto, no otro glifo.
- **Voz**: textos de la interfaz en español, frases cortas, tuteo, sin exclamaciones. Se habla de *clips* e *historial*; los verbos son "copia", "pega" y "elige", nunca "sincroniza" o "gestiona". Las fechas relativas van en español.

## Fase 1: implementar el design system

1. Lee todo el código y los archivos de diseño (`DESIGN.md`, `tokens.json`, `assets/`). Dame un plan corto de los cambios antes de empezar.
2. Crea `DesignSystem.swift` y migra `HistoryView`, `ClipCard`, `AppStyle` y el panel a los tokens.
3. Integra el icono de app y el de la barra de menús en `build_app.sh` y en `AppDelegate`.
4. Revisa los modos claro y oscuro, el contraste y el anillo de foco. Comprueba que la navegación por teclado sigue intacta: ← →, ↩, ⇥, ⌘1–9, ⌘P, ⌘⌫ y esc.

## Fase 2: funcionalidades (una a una y solo cuando te lo pida)

Este es el backlog sugerido. Para cada una, propón el diseño antes de implementarla:

- Ventana de Preferencias: atajo configurable, tamaño del historial, apps ignoradas e inicio al arrancar.
- Pegar como texto plano con ⇧↩, guardando también RTF/HTML.
- Vista previa grande con la barra espaciadora (Quick Look).
- Tableros de fijados con nombre (colecciones).
- Onboarding de primera ejecución que pida el permiso de Accesibilidad.
- Sincronización con iCloud (más adelante; requiere cuenta de desarrollador).

## Reglas de trabajo

- Compila con `./build_app.sh` después de cada cambio y no des una tarea por terminada si no compila. **Nunca uses `sudo`**.
- El compilador es Swift 6 en modo Swift 5 con SDK reciente, y es estricto con el aislamiento. Todo lo de UI va en `@MainActor`. Los callbacks de C, `Timer` y `NSAnimationContext` envuelven su código en `MainActor.assumeIsolated { }`. `main.swift` ya usa ese patrón.
- No rompas el flujo de pegado: panel no activador → `Paster.write` → `orderOut` sin animación → ⌘V a los 60 ms. Respeta también la privacidad: tipos concealed y apps ignoradas.
- Cambios pequeños, con un commit por tarea y mensajes en español. No hagas `git push` sin preguntarme.
- Si algo del design system no se puede trasladar tal cual a macOS, dímelo y propón la alternativa más cercana en vez de improvisar.
- Al terminar cada tarea, resume qué cambiaste, cómo probarlo y qué queda pendiente.
