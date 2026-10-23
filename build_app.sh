#!/bin/bash
# Compila ClipStack y genera ClipStack.app en esta carpeta.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "No ejecutes este script con sudo. Usa: ./build_app.sh"
  exit 1
fi
cd "$(dirname "$0")"

APP="ClipStack"
# Dirección del logo elegida (ver DESIGN.md). Si faltan los assets, se usan los iconos por defecto.
DIRECTION="${DIRECTION:-abanico}"
ICON_PNG="assets/Iconos/$DIRECTION-app-icon-1024.png"
MENUBAR_SVG="assets/MenuBar/$DIRECTION-menubar-template-18.svg"
LOGO_LIGHT="assets/Logotipos/$DIRECTION-logo-horizontal-light.svg"
LOGO_DARK="assets/Logotipos/$DIRECTION-logo-horizontal-dark.svg"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP"

rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS" "$APP.app/Contents/Resources"
cp "$BIN" "$APP.app/Contents/MacOS/$APP"

ICON_KEY=""
if [ -n "$DIRECTION" ]; then
  if [ -f "$ICON_PNG" ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
      sips -z $((s * 2)) $((s * 2)) "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP.app/Contents/Resources/AppIcon.icns"
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
  else
    echo "Aviso: no encuentro $ICON_PNG; se usa el icono por defecto."
  fi
  if [ -f "$MENUBAR_SVG" ]; then
    cp "$MENUBAR_SVG" "$APP.app/Contents/Resources/MenuBarIcon.svg"
  else
    echo "Aviso: no encuentro $MENUBAR_SVG; se usa el SF Symbol."
  fi
  # Logotipo de Configuración › Acerca de
  if [ -f "$LOGO_LIGHT" ] && [ -f "$LOGO_DARK" ]; then
    cp "$LOGO_LIGHT" "$APP.app/Contents/Resources/LogoLight.svg"
    cp "$LOGO_DARK" "$APP.app/Contents/Resources/LogoDark.svg"
  fi
fi

cat > "$APP.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP</string>
    <key>CFBundleDisplayName</key><string>$APP</string>
    <key>CFBundleIdentifier</key><string>com.local.clipstack</string>
    <key>CFBundleExecutable</key><string>$APP</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    $ICON_KEY
</dict>
</plist>
PLIST

# Firma ad-hoc (necesaria para que macOS recuerde el permiso de Accesibilidad)
codesign --force --deep --sign - "$APP.app"

echo ""
echo "Listo: $(pwd)/$APP.app"
echo "Muévela a /Applications y ábrela:  mv $APP.app /Applications/ && open /Applications/$APP.app"
