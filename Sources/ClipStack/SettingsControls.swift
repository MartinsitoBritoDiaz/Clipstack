import SwiftUI
import AppKit

// Controles de la ventana de Configuración (componentes del diseño de Claude Design).

/// Anillo de foco del design system: sólido de 2 px con 2 px de separación.
struct FocusRing: ViewModifier {
    var radius: CGFloat
    var isFocused: Bool

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                .stroke(Color.ds(DS.focusRing), lineWidth: 2)
                .padding(-3)
                .opacity(isFocused ? 1 : 0)
                .allowsHitTesting(false)
        )
    }
}

/// Hace que una vista se active con clic, espacio o ↩, y muestre el anillo de foco con ⇥.
struct Pressable: ViewModifier {
    var radius: CGFloat
    var enabled = true
    var action: () -> Void
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { if enabled { action() } }
            .focusable(enabled)
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.space, .return]) { _ in
                guard enabled else { return .ignored }
                action()
                return .handled
            }
            .modifier(FocusRing(radius: radius, isFocused: focused))
            .opacity(enabled ? 1 : 0.45)
    }
}

extension View {
    func pressable(radius: CGFloat = DS.radiusSm, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(Pressable(radius: radius, enabled: enabled, action: action))
    }
}

// MARK: - Fila y grupo

struct SettingGroup<Content: View>: View {
    var verticalPadding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, DS.space4)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds(DS.surfaceRaised),
                        in: RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    var hint: String?
    var hintMono = false
    var divider = false
    var enabled = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: DS.space4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.body)
                if let hint {
                    Text(hint)
                        .font(hintMono ? .system(size: 12, design: .monospaced) : DS.caption)
                        .foregroundStyle(Color.ds(DS.inkMuted))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(enabled ? 1 : 0.45)
            trailing
        }
        .padding(.vertical, DS.space3)
        .overlay(alignment: .top) { if divider { Divider().overlay(Color.ds(DS.line)) } }
    }
}

// MARK: - Interruptor

struct DSToggle: View {
    @Binding var isOn: Bool
    var enabled = true

    var body: some View {
        Capsule()
            .fill(Color.ds(isOn ? DS.brandInk : DS.line))
            .frame(width: 40, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.ds(isOn ? DS.onBrandInk : DS.knob))
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.12), value: isOn)
            .pressable(radius: 12, enabled: enabled) { isOn.toggle() }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "Activado" : "Desactivado")
    }
}

// MARK: - Segmentado

struct DSSegmented<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let selected = options[i].value == selection
                Text(options[i].label)
                    .font(DS.label)
                    .lineLimit(1)
                    .padding(.horizontal, DS.space3)
                    .frame(height: 24)
                    .foregroundStyle(Color.ds(selected ? DS.ink : DS.inkMuted))
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.ds(DS.segOn))
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = options[i].value }
            }
        }
        .padding(2)
        .background(Color.ds(DS.segTrack), in: RoundedRectangle(cornerRadius: DS.radiusMd, style: .continuous))
        .fixedSize()
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            move(press.key == .rightArrow ? 1 : -1)
            return .handled
        }
        .modifier(FocusRing(radius: DS.radiusMd, isFocused: focused))
    }

    private func move(_ delta: Int) {
        guard let i = options.firstIndex(where: { $0.value == selection }) else { return }
        selection = options[min(max(i + delta, 0), options.count - 1)].value
    }
}

// MARK: - Botón secundario y selector

struct DSButton: View {
    let title: String
    var destructive = false
    var enabled = true
    var action: () -> Void

    var body: some View {
        Text(title)
            .font(destructive ? DS.label : DS.control)
            .foregroundStyle(Color.ds(destructive ? DS.coralInk : DS.ink))
            .lineLimit(1)
            .padding(.horizontal, DS.space3)
            .frame(height: 26)
            .background(Color.ds(DS.surface), in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous)
                .strokeBorder(Color.ds(DS.line)))
            .fixedSize()
            .pressable(enabled: enabled, action: action)
    }
}

/// Botón con menú desplegable (la lista es el menú nativo de macOS).
struct DSPicker<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    var onSelect: ((Value) -> Void)?

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    if let onSelect { onSelect(options[i].value) } else { selection = options[i].value }
                } label: {
                    if options[i].value == selection {
                        Label(options[i].label, systemImage: "checkmark")
                    } else {
                        Text(options[i].label)
                    }
                }
            }
        } label: {
            HStack(spacing: DS.space2) {
                Text(options.first { $0.value == selection }?.label ?? "")
                    .font(DS.control)
                    .foregroundStyle(Color.ds(DS.ink))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.ds(DS.inkMuted))
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(minWidth: 76, minHeight: 26)
            .background(Color.ds(DS.surface), in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous)
                .strokeBorder(Color.ds(DS.line)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Casilla

struct DSCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.ds(isOn ? DS.brandInk : DS.surface))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.ds(isOn ? DS.brandInk : DS.inkMuted)))
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.ds(DS.onBrandInk))
                    }
                }
                .frame(width: 14, height: 14)
            Text(title).font(DS.control)
        }
        .pressable(radius: 4) { isOn.toggle() }
    }
}

// MARK: - Atajos

struct ShortcutPill: View {
    let keys: String
    var raised = false

    var body: some View {
        Text(keys)
            .font(DS.shortcut)
            .foregroundStyle(Color.ds(raised ? DS.ink : DS.inkMuted))
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Color.ds(raised ? DS.surfaceRaised : DS.surface),
                        in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous)
                .strokeBorder(Color.ds(DS.line)))
            .fixedSize()
    }
}

/// Campo que graba un atajo nuevo al pulsarlo. Devuelve false en `onRecord` si el atajo está ocupado.
struct ShortcutRecorder: View {
    let value: String
    var canRestore = false
    var enabled = true
    var onRecord: (UInt32, UInt32, String) -> Bool = { _, _, _ in true }
    var onRestore: () -> Void = {}

    @State private var recording = false
    @State private var conflict: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: DS.space3) {
                Group {
                    if recording {
                        Text("Pulsa el atajo nuevo…")
                            .font(DS.caption.italic())
                            .foregroundStyle(Color.ds(DS.inkMuted))
                    } else {
                        ShortcutPill(keys: value, raised: true)
                    }
                }
                .frame(width: 168, height: 30)
                .background(Color.ds(DS.surface), in: RoundedRectangle(cornerRadius: DS.radiusMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.radiusMd, style: .continuous)
                    .strokeBorder(Color.ds(recording ? DS.brandInk : (conflict != nil ? DS.coralInk : DS.line))))
                .modifier(FocusRing(radius: DS.radiusMd, isFocused: recording))
                .pressable(radius: DS.radiusMd, enabled: enabled) { recording ? stop() : start() }
                if canRestore && !recording {
                    Text("Restaurar")
                        .font(DS.label)
                        .foregroundStyle(Color.ds(DS.brandInk))
                        .pressable { conflict = nil; onRestore() }
                }
            }
            if let conflict {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 11))
                    Text(conflict).font(DS.caption)
                }
                .foregroundStyle(Color.ds(DS.coralInk))
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        conflict = nil
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let key = Self.keyName(code: code, characters: event.charactersIgnoringModifiers)
            MainActor.assumeIsolated { record(code: code, flags: flags, key: key) }
            return nil
        }
    }

    private func record(code: UInt16, flags: NSEvent.ModifierFlags, key: String) {
        if code == 53 { stop(); return } // esc cancela
        guard !flags.intersection([.command, .option, .control]).isEmpty else {
            NSSound.beep()
            return
        }
        let mods = Preferences.carbonModifiers(flags)
        if !onRecord(UInt32(code), mods, key) {
            conflict = "\(Preferences.display(modifiers: mods, key: key)) ya está en uso. Elige otro."
        }
        stop()
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private static func keyName(code: UInt16, characters: String?) -> String {
        switch Int(code) {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Espacio"
        case 51: return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return (characters ?? "").uppercased()
        }
    }
}

// MARK: - Diálogo de confirmación

struct ConfirmDialog: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: @MainActor () -> Void
}

struct ConfirmDialogView: View {
    let dialog: ConfirmDialog
    let onDismiss: () -> Void
    @FocusState private var cancelFocused: Bool

    var body: some View {
        ZStack {
            Color.ds(DS.scrim).onTapGesture(perform: onDismiss)
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .padding(.bottom, 6)
                Text(dialog.title).font(.system(size: 15, weight: .semibold))
                Text(dialog.message)
                    .font(DS.control)
                    .foregroundStyle(Color.ds(DS.inkMuted))
                    .multilineTextAlignment(.center)
                HStack(spacing: DS.space2) {
                    Text(dialog.confirmTitle)
                        .font(DS.label)
                        .foregroundStyle(Color.ds(DS.coralInk))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(Color.ds(DS.surface), in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous)
                            .strokeBorder(Color.ds(DS.line)))
                        .pressable { dialog.onConfirm(); onDismiss() }
                    Text("Cancelar")
                        .font(DS.label)
                        .foregroundStyle(Color.ds(DS.onBrandInk))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(Color.ds(DS.brandInk), in: RoundedRectangle(cornerRadius: DS.radiusSm, style: .continuous))
                        .pressable(action: onDismiss)
                }
                .padding(.top, DS.space3)
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
            .frame(width: 296)
            .background(Color.ds(DS.surfaceRaised), in: RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
            .shadow(color: Color.ds(DS.shadowCard), radius: 12, y: 8)
            .onKeyPress(.escape) { onDismiss(); return .handled }
        }
    }
}
