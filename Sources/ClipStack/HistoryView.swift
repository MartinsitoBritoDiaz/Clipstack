import SwiftUI

enum ClipFilter: String, CaseIterable, Identifiable {
    case all = "Historial"
    case pinned = "Fijados"
    case text = "Texto"
    case links = "Enlaces"
    case images = "Imágenes"
    case files = "Archivos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:    return "clock"
        case .pinned: return "pin"
        case .text:   return "text.alignleft"
        case .links:  return "link"
        case .images: return "photo"
        case .files:  return "doc"
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all:    return true
        case .pinned: return item.pinned
        case .text:   return item.displayKind == .text || item.displayKind == .color
        case .links:  return item.displayKind == .link
        case .images: return item.displayKind == .image
        case .files:  return item.displayKind == .files
        }
    }
}

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    let onPaste: @MainActor (ClipItem) -> Void
    let onClose: @MainActor () -> Void
    var onOpenSettings: @MainActor () -> Void = {}
    var cardSize = ClipCard.regularSize

    @State private var query = ""
    @State private var filter: ClipFilter = .all
    @State private var selectedID: UUID?
    @State private var scrollTarget: UUID?
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.items.filter { item in
            guard filter.matches(item) else { return false }
            guard !q.isEmpty else { return true }
            return item.searchableText.localizedCaseInsensitiveContains(q)
                || (item.sourceAppName ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        let list = filtered
        VStack(spacing: 14) {
            topBar
            if list.isEmpty {
                emptyState
            } else {
                cards(list)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            selectedID = list.first?.id
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: query) { _, _ in resetSelection() }
        .onChange(of: filter) { _, _ in resetSelection() }
    }

    // MARK: - Barra superior

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                    .onKeyPress(phases: .down, action: handleKey)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(width: 230)
            .background(Capsule().fill(Color.primary.opacity(0.07)))

            ForEach(ClipFilter.allCases) { f in
                Button { filter = f } label: {
                    Label(f.rawValue, systemImage: f.icon)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(filter == f ? Color.accentColor : Color.primary.opacity(0.06)))
                        .foregroundStyle(filter == f ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("← → mover   ↩ pegar   ⇥ filtro   ⌘P fijar   ⌘⌫ eliminar")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Tarjetas

    private func cards(_ list: [ClipItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                        ClipCard(item: item,
                                 index: index,
                                 isSelected: item.id == selectedID,
                                 thumbnail: store.thumbnail(for: item),
                                 size: cardSize)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onPaste(item) }
                            .onTapGesture { selectedID = item.id }
                            .contextMenu {
                                Button("Pegar") { onPaste(item) }
                                Button(item.pinned ? "Quitar de fijados" : "Fijar") { store.togglePin(item) }
                                Divider()
                                Button("Eliminar", role: .destructive) { store.delete(item) }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .onChange(of: scrollTarget) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(query.isEmpty ? "Copia algo y aparecerá aquí" : "Sin resultados para “\(query)”")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Teclado

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .rightArrow, .downArrow: move(1); return .handled
        case .leftArrow, .upArrow:    move(-1); return .handled
        case .return:                 pasteSelected(); return .handled
        case .tab:                    cycleFilter(press.modifiers.contains(.shift) ? -1 : 1); return .handled
        case .escape:
            if query.isEmpty { onClose() } else { query = "" }
            return .handled
        default: break
        }

        guard press.modifiers.contains(.command) else { return .ignored }

        if press.key == .delete {
            if let item = selectedItem { move(1); store.delete(item) }
            return .handled
        }
        if press.characters == "," {
            onOpenSettings()
            return .handled
        }
        if press.characters.lowercased() == "p" {
            if let item = selectedItem { store.togglePin(item) }
            return .handled
        }
        if let n = Int(press.characters), (1...9).contains(n) {
            let list = filtered
            if n <= list.count { onPaste(list[n - 1]) }
            return .handled
        }
        return .ignored
    }

    private var selectedItem: ClipItem? {
        filtered.first { $0.id == selectedID }
    }

    private func move(_ delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selectedID } ?? -1
        let next = min(max(current + delta, 0), list.count - 1)
        selectedID = list[next].id
        scrollTarget = selectedID
    }

    private func cycleFilter(_ delta: Int) {
        let all = ClipFilter.allCases
        let i = all.firstIndex(of: filter) ?? 0
        filter = all[(i + delta + all.count) % all.count]
    }

    private func resetSelection() {
        selectedID = filtered.first?.id
        scrollTarget = selectedID
    }

    private func pasteSelected() {
        if let item = selectedItem { onPaste(item) }
    }
}

// MARK: - Tarjeta

struct ClipCard: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let thumbnail: NSImage?
    var size = ClipCard.regularSize
    var showsShortcut = true

    static let regularSize = CGSize(width: 236, height: 248)
    static let compactSize = CGSize(width: 176, height: 184)

    private let corner: CGFloat = 14

    var body: some View {
        let style = CardHeaderStyle.colors(for: item.sourceBundleID)

        VStack(spacing: 0) {
            header(textColor: style.ink)
                .background(style.background)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .bottom) { footer }
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                              lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 12 : 5, y: 4)
        .scaleEffect(isSelected ? 1 : 0.965)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private func header(textColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(kindTitle)
                        .font(.system(size: 15, weight: .semibold))
                    if item.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 10))
                    }
                }
                Text(item.date.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .opacity(0.8)
            }
            Spacer(minLength: 0)
            if let icon = AppIcons.icon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 58)
    }

    @ViewBuilder private var content: some View {
        switch item.displayKind {
        case .text:
            Text(item.title)
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .lineLimit(9)
                .padding(12)

        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text(URL(string: item.trimmedText)?.host ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(item.trimmedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .padding(12)

        case .color:
            if let rgb = ClipItem.hexColor(from: item.trimmedText) {
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                        .frame(maxHeight: 104)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
                    Text(item.trimmedText.uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
                .padding(12)
            }

        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
            } else {
                Text("Imagen no disponible")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }

        case .files:
            VStack(spacing: 8) {
                if let first = item.fileURLs?.first, let url = URL(string: first) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 64, height: 64)
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        let bg = Color(nsColor: .textBackgroundColor)
        return HStack {
            Text(detail)
            Spacer()
            if showsShortcut, index < 9 { Text("⌘\(index + 1)") }
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(LinearGradient(colors: [bg.opacity(0), bg, bg], startPoint: .top, endPoint: .bottom))
    }

    private var kindTitle: String {
        switch item.displayKind {
        case .text:  return "Texto"
        case .link:  return "Enlace"
        case .color: return "Color"
        case .image: return "Imagen"
        case .files: return item.fileNames.count == 1 ? "Archivo" : "\(item.fileNames.count) archivos"
        }
    }

    private var detail: String {
        switch item.displayKind {
        case .text, .link, .color:
            return "\(item.trimmedText.count) caracteres"
        case .image:
            if let rep = thumbnail?.representations.first {
                return "\(rep.pixelsWide) × \(rep.pixelsHigh)"
            }
            return ""
        case .files:
            return item.sourceAppName ?? ""
        }
    }
}

// MARK: - Últimos clips (menú de la barra)

/// Los últimos clips en el menú de la barra, con las mismas tarjetas que el panel.
struct RecentClipsView: View {
    let items: [ClipItem]
    let store: HistoryStore
    let onPaste: @MainActor (ClipItem) -> Void

    @State private var hoveredID: UUID?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { onPaste(item) } label: {
                    ClipCard(item: item,
                             index: index,
                             isSelected: item.id == hoveredID,
                             thumbnail: store.thumbnail(for: item),
                             size: ClipCard.compactSize,
                             showsShortcut: false)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { hoveredID = item.id } else if hoveredID == item.id { hoveredID = nil }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
