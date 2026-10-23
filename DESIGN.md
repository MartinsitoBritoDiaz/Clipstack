ClipStack es un gestor de portapapeles para macOS que vive en la barra de menús. Guarda todo lo que copias (texto, enlaces, imágenes, archivos y colores) y con ⇧⌘V abre un panel translúcido en la parte inferior de la pantalla con el historial en tarjetas horizontales; eliges una y se pega. Rápida, discreta, para gente que trabaja todo el día con el teclado. Esta identidad sale de una sola idea: **tarjetas apiladas con un ligero desplazamiento**, que dicen historial y orden sin recurrir al portapapeles con pinza.

## La idea y las tres direcciones

Las tres propuestas comparten el mismo sistema: un squircle con el degradado `gradient-brand` (`indigo` → `blue`, 135°), tarjetas de cantos redondeados con sombra `indigo-deep` al 32 %, una tarjeta frontal `gradient-card` y **una sola tarjeta cálida** en `gradient-warm` (`coral` → `orange`). Cambia solo cómo se apilan las tarjetas. Nada de texto dentro del icono.

**A · Abanico.** Tres tarjetas giradas ±24° alrededor de un punto bajo el icono, como un abanico de naipes en la mano: la frontal blanca, la coral a la izquierda y una `glass` a la derecha. Es la dirección más expresiva y la que más se parece a "elegir una tarjeta". Lee bien hasta 32 px; a 16 px queda una tarjeta blanca con el borde coral asomando, que sigue siendo reconocible. En la barra de menús se reduce a dos tarjetas (una recta y otra girada detrás), porque tres contornos girados a 16 px se convierten en una mancha.

**B · Pila.** Una tarjeta frontal horizontal y dos capas que retroceden hacia arriba, cada una un poco más estrecha: la de arriba coral (el clip más reciente), la del medio `glass`. Es la más sobria y la que mejor aguanta a 16 px: un rectángulo blanco con dos franjas encima. Habla de orden y de historial sin movimiento. La versión monocromática es la misma pila en líneas.

**C · Carrusel.** Tres tarjetas en fila que se solapan, con la central delante, más alta y en coral: es exactamente el panel de ⇧⌘V con la tarjeta que vas a pegar seleccionada. Es la dirección que más cuenta la interacción de la app y la que da una silueta más distinta en el Dock (ancha, con el acento en el centro). En la barra de menús las tres tarjetas en línea leen como una galería.

Elige una dirección y retira las otras dos del sistema: los tres iconos no conviven en un mismo producto. Los archivos de las tres están en `assets/Iconos`, `assets/MenuBar` y `assets/Logotipos`, con el mismo prefijo (`abanico-`, `pila-`, `carrusel-`), y las hojas de legibilidad en `assets/Pruebas`.

## Icono de app

- Usa el PNG `<dirección>-app-icon-1024.png` tal cual para el asset catalog de Xcode (o genera el `.icns` con `iconutil`). Sigue la cuadrícula de iconos de macOS: lienzo de 1024 px, squircle de 824 px centrado (margen de 100 px), radio continuo del 22,37 % del lado, y la sombra del sistema `shadow-icon` ya incluida; no añadas otra.
- El SVG `<dirección>-app-icon-1024.svg` es el original editable; el `-flat.svg` es el mismo icono sin la sombra exterior y a sangre, y es el mark que usa el logotipo.
- Los tamaños pequeños salen del mismo original: el icono está pensado para que a 32 px lea la estructura y a 16 px lea la silueta (tarjeta blanca + acento coral sobre azul). No simplifiques el dibujo a mano para 16 px; si hace falta, sube la opacidad de `glass`, nunca añadas contorno.
- El icono es el mismo en modo claro y oscuro: el degradado `indigo` → `blue` tiene contraste de sobra sobre `surface` en los dos temas, y la tarjeta blanca sigue siendo lo más claro del Dock. No hagas una variante oscura.
- Lo que no se hace: nada de texto ni letras dentro del squircle, ningún portapapeles con pinza, ningún borde alrededor del squircle, ningún brillo o reflejo más fuerte que el velo blanco del 14 % que ya tiene arriba, y nunca más de una tarjeta cálida.

## Icono de barra de menús (template)

- Son `<dirección>-menubar-template-16.svg` y `-18.svg`: solo líneas, un color, trazo de 1,5 pt con terminaciones redondas, sin rellenos ni máscaras. Márcalos como *template* (`isTemplate = true`) para que macOS los tiña según la barra; `menubar-ink` solo sirve para previsualizarlos.
- Lienzo de 18 × 18 pt (el estándar de la barra de menús) con el dibujo en unos 13 × 12 pt, y la versión de 16 × 16 para listas y ajustes. Exporta a @1x y @2x o usa el SVG en el asset catalog con *Preserve Vector Data*.
- Las partes de una tarjeta que quedan detrás de otra no se dibujan: el contorno se interrumpe con 0,55 pt de aire antes de llegar a la tarjeta de delante. Ese hueco es lo que mantiene las capas legibles a 16 px; no lo cierres.
- Cuando la app tiene algo nuevo en el historial, no cambies el glifo: usa el punto estándar del sistema.

## Logotipo

- Lockup horizontal: el mark (el `-flat.svg` del icono, a 80 px) y la palabra **ClipStack** en Inter SemiBold a 48 px con tracking −0,02 em (estilo `wordmark`), con la altura de las mayúsculas centrada en el mark y 20 px de hueco. En los SVG la palabra va convertida a trazados, así que no dependen de la fuente.
- `-light.svg` pone la palabra en `ink` sobre fondos claros; `-dark.svg` la pone en el `ink` del tema oscuro sobre fondos oscuros. El mark no cambia. No recolorees la palabra con `indigo` ni `coral`, y no la pongas sobre el degradado.
- Área de respeto: un cuarto de la altura del mark por cada lado (`space-6` con el mark a 96 px). Tamaño mínimo del lockup: 24 px de alto; por debajo, usa el mark solo.
- La palabra siempre se escribe ClipStack, en una sola palabra y con esas dos mayúsculas, también en texto corrido.

## Color

- `gradient-brand` es el único fondo de marca: siempre a 135°, de `indigo` arriba-izquierda a `blue` abajo-derecha. Como color plano, la marca es `brand-ink` (en texto, enlaces y la tarjeta seleccionada), que cumple 6,9:1 sobre `surface` y `surface-raised` en los dos temas.
- `coral` y `orange` son el acento cálido y aparecen **en una sola tarjeta**; en interfaz, `coral-ink` para avisos y acciones destructivas. El texto encima de un relleno coral es `on-coral` (oscuro), nunca blanco.
- Sobre el degradado, `on-brand` (blanco) solo para iconos y texto grande; el texto pequeño va en una tarjeta `card` con `ink`.
- Texto: `ink` para todo lo principal, `ink-muted` para metadatos; los dos cumplen 4,5:1 o más sobre `surface` y `surface-raised` en claro y en oscuro. `line` es decorativo y no marca estados.
- Foco de teclado: anillo sólido de 2 px en `focus-ring` con 2 px de separación, visible sobre cualquier superficie de los dos temas. En una app de teclado, el foco se ve siempre.

## Tipografía

Inter (400, 500, 600) en web y materiales; dentro de la app, SF Pro del sistema con los mismos tamaños, porque `families.sans` cae en `-apple-system`. Los titulares y la palabra de marca llevan tracking negativo (`wordmark`, `display`); el texto de interfaz, no. Los atajos de teclado se escriben con los símbolos de macOS (⇧⌘V) en `shortcut`, dentro de una pastilla `surface-raised` con `radius-sm`.

## Forma, espacio y profundidad

- Cantos continuos siempre: `radius-lg` en las tarjetas del panel, `radius-xl` en el panel, y en el icono la proporción 56/1024 de las tarjetas.
- Profundidad sutil: una sombra `shadow-card` por tarjeta, teñida de `indigo-deep`, nunca negra ni más de una. Sin biseles, sin brillos, sin desenfoques decorativos; la translucidez del panel es la del sistema.
- El panel de historial vive abajo, a lo ancho, y las tarjetas se separan `space-3`; el icono C es ese panel en miniatura.

## Voz

Frases cortas, tuteo, sin exclamaciones. Se habla de *clips* y de *historial*; se dice "copia", "pega" y "elige", nunca "sincroniza" o "gestiona". Los atajos van siempre con símbolos, no con palabras.
