# ClipStack

Gestor de portapapeles para macOS (14 Sonoma o superior), estilo PasteNow.
Vive en la barra de menús, guarda todo lo que copias y lo vuelves a pegar con el teclado.

## Qué hace

- Guarda texto, imágenes (capturas, imágenes copiadas) y archivos copiados en Finder.
- `⇧⌘V` abre un panel translúcido en la parte inferior de la pantalla con el historial en tarjetas horizontales.
- Cada tarjeta tiene una cabecera del color de la app de origen, su icono, el tipo (texto, enlace, color, imagen, archivo) y hace cuánto se copió.
- Filtros: Historial, Fijados, Texto, Enlaces, Imágenes y Archivos (`⇥` para cambiar).
- `← →` para moverte, `↩` o doble clic para pegar directamente en la app donde estabas.
- `⌘1`–`⌘9` pegan los nueve primeros elementos al instante.
- `⌘P` fija un elemento (los fijados nunca se borran y van arriba), `⌘⌫` lo elimina.
- No repite elementos: si copias algo que ya estaba, sube arriba.
- Ignora contraseñas: respeta el marcador “concealed” que usan los gestores de contraseñas y no guarda nada de 1Password, Bitwarden, Llavero, etc.
- Conserva los últimos 20 elementos (cambia `maxItems` en `HistoryStore.swift`).
- Opción “Abrir al iniciar sesión” en el menú.

El historial se guarda en `~/Library/Application Support/ClipStack/`.

## Compilar

Necesitas Xcode 15 o superior (o al menos las Command Line Tools: `xcode-select --install`).

```bash
cd ClipStack
./build_app.sh
mv ClipStack.app /Applications/
open /Applications/ClipStack.app
```

Para desarrollar, también puedes abrir `Package.swift` con Xcode y ejecutar desde ahí.

## Permiso de Accesibilidad

Para pegar automáticamente, la app simula `⌘V`, y macOS exige el permiso de Accesibilidad:
Configuración del Sistema → Privacidad y seguridad → Accesibilidad → activar ClipStack.

Sin ese permiso todo funciona igual, pero al elegir un elemento solo se copia y tienes que pulsar `⌘V` tú.

Cada vez que recompilas cambia la firma ad-hoc, así que macOS puede “olvidar” el permiso. Si deja de pegar, quita ClipStack de la lista de Accesibilidad y vuelve a añadirlo.

## Estructura

| Archivo | Función |
|---|---|
| `AppDelegate.swift` | Icono en la barra de menús, atajo global y lógica de pegado |
| `ClipboardMonitor.swift` | Detecta cambios en el portapapeles (consulta cada 0,4 s) |
| `HistoryStore.swift` | Historial, duplicados, fijados y guardado en disco |
| `HistoryView.swift` | Interfaz SwiftUI del panel y las tarjetas |
| `AppStyle.swift` | Colores por app, iconos y fondo translúcido |
| `FloatingPanel.swift` | Ventana flotante que no le roba el foco a tu app |
| `HotKey.swift` | Registro del atajo global `⇧⌘V` |
| `Paster.swift` | Escribe en el portapapeles y simula `⌘V` |

## Ideas para seguir

- Conservar formato enriquecido (RTF/HTML) y pegar como texto plano con `⇧↩`.
- Atajo configurable desde una ventana de ajustes.
- Snippets / colecciones con nombre.
- Sincronizar entre Macs con CloudKit (requiere cuenta de desarrollador de Apple).
- Vista previa grande con la barra espaciadora.
