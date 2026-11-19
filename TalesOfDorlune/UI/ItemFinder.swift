import SwiftUI
import UIKit

/// How a list of things you carry is ordered (the Bag, the bank, the gear for a slot), remembered
/// between visits. Nonisolated like the other enums shown with `ForEach(id: \.self)`.
nonisolated enum ItemSort: String, CaseIterable {
    /// Your order of the bag or the bank (`GameSession+ItemOrder`): as the game lists them
    /// (content/items.json) till you move something.
    case standard
    /// As the game lists them, whatever your order: kind by kind, plainest first.
    case kind
    /// What you can wear now before what you can't, each by what it's worth to you
    /// (`GameSession.gearValue`), the best first; the rest as they come.
    case best
    case name, level, price, count

    var title: String {
        switch self {
        case .standard: L("Bag order")
        case .kind: L("Kind")
        case .best: L("Best for you")
        case .name: L("Name")
        case .level: L("Level")
        case .price: L("Price")
        case .count: L("How many")
        }
    }

    /// What it's called in the bank, where your order is the bank's.
    var bankTitle: String { self == .standard ? L("Bank order") : title }
}

/// Which kinds of thing a grid shows (the Bag, the bank). Nonisolated like the other enums in a
/// `ForEach(id: \.self)`.
nonisolated enum ItemShelf: String, CaseIterable {
    case all, items, gear, materials

    var title: String {
        switch self {
        case .all: L("All")
        case .items: L("Items")
        case .gear: L("Gear")
        case .materials: L("Materials")
        }
    }

    func holds(_ item: ItemDef) -> Bool {
        switch self {
        case .all: true
        case .items: item.type == .consumable
        case .gear: ItemType.equipmentSlots.contains(item.type)
        case .materials: item.type == .material
        }
    }
}

enum ItemFinder {
    /// `items` narrowed to those whose name (or kind, "boots") holds `search`, in `sort`'s order.
    /// Ties keep the order they came in. `side`: where they are, for how many there are.
    static func arrange(_ items: [ItemDef], search: String, sort: ItemSort, session: GameSession,
                        on side: BankSide = .bag) -> [ItemDef] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = query.isEmpty ? items : items.filter {
            $0.name.localizedStandardContains(query) || $0.type.displayName.localizedStandardContains(query)
        }
        let value: (ItemDef) -> Double
        switch sort {
        case .standard: return found
        case .kind:
            let rank = Dictionary(session.content.items.enumerated().map { ($0.element.id, $0.offset) }) { first, _ in first }
            value = { -Double(rank[$0.baseID] ?? Int.max) }
        case .name: return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // What you can wear comes first, however good the rest is: no gear is worth anywhere near this.
        case .best: value = { (session.equipIssue($0) == nil ? 1_000_000 : 0) + session.gearValue($0) }
        case .level: value = { Double($0.level ?? 0) }
        case .price: value = { Double($0.price) }
        case .count: value = { Double(session.held($0.id, on: side)) }
        }
        return found.enumerated()
            .map { (item: $0.element, place: $0.offset, value: value($0.element)) }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.place < $1.place }
            .map { $0.item }
    }
}

/// A search field in the game's look: a magnifier, what you typed, and a clear button once there's
/// something to clear.
struct ItemSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            IconImage(.search, size: 14)
                .foregroundStyle(HUDStyle.dim)
            // The prompt in the HUD's dim cream: the system's grey hardly shows on the window's blue.
            TextField("", text: $text, prompt: Text(L("Search")).foregroundStyle(HUDStyle.dim))
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.cream)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    IconImage(.close, size: 12)
                        .foregroundStyle(HUDStyle.dim)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Clear search"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 32)
        .background(Capsule().fill(.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

/// Sort: a button with the sort icon that opens the orders in a small panel under it, in the HUD
/// menu's look (playtesting 2026-10-26: "The 'Bag order' sorting button should just say 'Sort' with
/// the same leading icon. That button should open the same menu style as the hamburger menu, so no
/// native iOS dropdown menu"): the one in use white on a dark plate, a tick at its right; a tap on one, or anywhere else,
/// closes it. Any list's orders (the Bag's and the bank's `ItemSort`, the Quests'), each named by
/// `title`. The row it sits in needs `.zIndex(1)`, so the panel lies over what's under the row.
struct SortMenu<Option: Hashable>: View {
    @Binding var sort: Option
    let options: [Option]
    let title: (Option) -> String
    /// Debug `sortopen`: out from the start.
    @State private var open = DebugLaunch.opensSort

    var body: some View {
        Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { open.toggle() }
        } label: {
            HStack(spacing: 5) {
                IconImage(.sort, size: 14)
                Text(L("Sort"))
                    .lineLimit(1)
            }
            .font(HUDStyle.font(11))
            .foregroundStyle(HUDStyle.cream)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Capsule().fill(Color.white.opacity(open ? 0.2 : 0.1)))
            .fixedSize()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Sort"))
        .accessibilityValue(title(sort))
        // Anywhere else closes it: a tap catcher over the window round the button, under the panel.
        .overlay {
            if open {
                Color.clear
                    .frame(width: 4000, height: 4000)
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if open {
                panel
                    .offset(y: 38)
                    .transition(.scale(scale: 0.6, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { open = false }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(options, id: \.self) { row($0) }
        }
        // As far in all round (`WorldAtlas.filterPanel` too).
        .padding(6)
        .frame(minWidth: 160, alignment: .leading)
        .background(HUDStyle.panelSurface(RoundedRectangle(cornerRadius: 14)))
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private func row(_ option: Option) -> some View {
        let selected = option == sort
        return Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            sort = option
            close()
        } label: {
            DropdownRow(title: title(option), selected: selected)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A row of a dropdown panel in the HUD menu's look (`SortMenu`, the world map's filter): its name in
/// white, after `leading` if it has one; the one in use on a dark plate, its tick at the right end
/// (the user, 2026-11-16: "The checkmark icon should always be on the right. Also the selected item
/// should have a dark bg with white label + icon, instead of this yellow, because this is hard to
/// read"; then "Same style should apply here", on the map's filter).
struct DropdownRow<Leading: View>: View {
    let title: String
    let selected: Bool
    let leading: Leading

    init(title: String, selected: Bool, @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.selected = selected
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
            Text(title)
                .font(HUDStyle.font(13))
                .foregroundStyle(.white)
                .shadow(color: selected ? .clear : HUDStyle.frameDark, radius: 0, x: 1, y: 1)
                .lineLimit(1)
            Spacer(minLength: 12)
            IconImage(.check, size: 14)
                .foregroundStyle(.white)
                .opacity(selected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(HUDStyle.ink.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
    }
}

extension DropdownRow where Leading == EmptyView {
    init(title: String, selected: Bool) {
        self.init(title: title, selected: selected) { EmptyView() }
    }
}

/// The Sort button for things you carry (the Bag, the bank, the gear for a slot): `SortMenu` with
/// `ItemSort`'s names, the bank's own order called the bank's.
struct ItemSortMenu: View {
    @Binding var sort: ItemSort
    let options: [ItemSort]
    /// In the bank: your order is the bank's.
    var bank = false

    var body: some View {
        let bank = self.bank
        SortMenu(sort: $sort, options: options, title: { bank ? $0.bankTitle : $0.title })
    }
}

/// One of a few kinds to show, or a filter you turn on and off: gold while it's on.
struct FilterChip: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            action()
        } label: {
            Text(title)
                .font(HUDStyle.font(11))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(on ? HUDStyle.ink : HUDStyle.cream)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(on ? HUDStyle.gold : .white.opacity(0.08)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The slots of the Bag or one side of the bank, one grid for every kind of thing, in your order
/// (playtesting 2026-10-26: "Make sure 6 grid items fit on the same row"): six to a row on a phone
/// held upright, the slots as big as the width allows; more on a wider window. A tap opens its card;
/// held, a slot lifts and goes where you drop it, onto another slot of the same grid, which it takes
/// the place of (`onMove`, `GameSession.moveItem`: "In the bank and inventory I should be able to
/// reorder any items"). The lift is iOS's own drag and drop (playtesting 2026-10-30: "I'm not able to
/// scroll in the bank modal"): the hold-then-drag gesture of our own it replaced, a drag from the first
/// touch on every slot, kept the window from scrolling under a finger on the slots. VoiceOver moves
/// a slot a place at a time.
struct ItemSlotGrid<Tile: View>: View {
    let items: [ItemDef]
    let label: (ItemDef) -> String
    let hint: String?
    let onTap: (ItemDef) -> Void
    /// Puts the first id where the second is.
    let onMove: (_ id: String, _ target: String) -> Void
    let tile: (_ item: ItemDef, _ size: CGFloat) -> Tile
    /// Slots the bag has room for still, after the items: drawn faint and empty, so how full it is
    /// reads at a glance (the Bag, unfiltered; the user's UI review, 2026-11-19). Plain shapes, so
    /// a hundred of them cost next to nothing.
    var emptySlots = 0
    /// A long press on a slot: its main action without its card (the Bag: Equip, or Use), for the
    /// items that have one (`holdLabel` says what it is, for VoiceOver); nil, none.
    var onHold: ((ItemDef) -> Void)?
    var holdLabel: (ItemDef) -> String? = { _ in nil }

    init(items: [ItemDef],
         label: @escaping (ItemDef) -> String, hint: String? = nil,
         emptySlots: Int = 0,
         onTap: @escaping (ItemDef) -> Void, onMove: @escaping (_ id: String, _ target: String) -> Void,
         onHold: ((ItemDef) -> Void)? = nil, holdLabel: @escaping (ItemDef) -> String? = { _ in nil },
         @ViewBuilder tile: @escaping (_ item: ItemDef, _ size: CGFloat) -> Tile) {
        self.items = items
        self.label = label
        self.hint = hint
        self.emptySlots = max(0, emptySlots)
        self.onTap = onTap
        self.onMove = onMove
        self.onHold = onHold
        self.holdLabel = holdLabel
        self.tile = tile
    }

    /// The room width the grid has, measured.
    @State private var width: CGFloat = 0
    /// What a dragged slot carries besides its item: this grid's own mark, so a slot dropped on
    /// another grid (the bag's on the bank's) moves nothing there.
    @State private var scope = UUID().uuidString
    /// The slot just held for its main action, and when: the tap its finger lifting may still make
    /// is swallowed, so the card doesn't open over what the hold did.
    @State private var held: (id: String, at: Date)?

    /// Between slots, and the most a slot grows to before another fits in the row.
    private static var spacing: CGFloat { 6 }
    private static var widest: CGFloat { 66 }
    private static var settle: Animation { .spring(response: 0.3, dampingFraction: 0.8) }

    private var columns: Int {
        guard width > 0 else { return 6 }
        return max(6, Int((width + Self.spacing) / (Self.widest + Self.spacing)))
    }

    private var slot: CGFloat {
        guard width > 0 else { return 52 }
        return floor((width - Self.spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    /// The top-left corner of a cell.
    private func corner(_ cell: Int) -> CGPoint {
        let step = slot + Self.spacing
        return CGPoint(x: CGFloat(cell % columns) * step, y: CGFloat(cell / columns) * step)
    }

    var body: some View {
        let slot = self.slot
        let cells = items.count + emptySlots
        let rows = max(1, (cells + columns - 1) / columns)
        let height = CGFloat(rows) * slot + CGFloat(rows - 1) * Self.spacing
        ZStack(alignment: .topLeading) {
            // The room left, under the items so a lifted slot passes over it.
            if emptySlots > 0 {
                ForEach(items.count..<cells, id: \.self) { index in
                    emptySlot(slot)
                        .offset(x: corner(index).x, y: corner(index).y)
                }
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                cell(item, at: index, slot: slot)
            }
        }
        .frame(width: width > 0 ? width : nil, height: height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// An empty slot: a faint sunk tile where an item's would be, inset as the Bag's tiles are (5
    /// points from the top and the right, for their count and arrow badges).
    private func emptySlot(_ slot: CGFloat) -> some View {
        let size = max(1, slot - 5)
        let shape = RoundedRectangle(cornerRadius: size * 0.26)
        return shape
            .fill(Color.black.opacity(0.16))
            .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1))
            .frame(width: size, height: size)
            .padding(.top, 5)
            .padding(.trailing, 5)
            .frame(width: slot, height: slot)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Held a moment (before iOS lifts it to move it), a slot with a main action does it, with a
    /// tap of the haptics.
    private func hold(_ item: ItemDef) -> some Gesture {
        LongPressGesture(minimumDuration: Self.holdTime, maximumDistance: 10)
            .onEnded { _ in
                guard let onHold else { return }
                held = (item.id, Date())
                Haptics.impact(.medium)
                onHold(item)
            }
    }

    /// How long a press is held for the main action.
    private static var holdTime: Double { 0.3 }

    private func cell(_ item: ItemDef, at index: Int, slot: CGFloat) -> some View {
        let place = corner(index)
        let before = index > 0 ? items[index - 1] : nil
        let after = index + 1 < items.count ? items[index + 1] : nil
        return tile(item, slot)
            .frame(width: slot, height: slot)
            .contentShape(Rectangle())
            .onTapGesture {
                if let held, held.id == item.id, Date().timeIntervalSince(held.at) < 1.5 {
                    self.held = nil
                    return
                }
                onTap(item)
            }
            // Only on the slots with a main action: on the rest, holding lifts it straight away.
            .simultaneousGesture(hold(item), including: onHold != nil && holdLabel(item) != nil ? .all : .none)
            .draggable(scope + "|" + item.id) {
                tile(item, slot).frame(width: slot, height: slot)
            }
            .dropDestination(for: String.self) { payloads, _ in
                guard let payload = payloads.first, payload.hasPrefix(scope + "|") else { return false }
                let id = String(payload.dropFirst(scope.count + 1))
                guard id != item.id, items.contains(where: { $0.id == id }) else { return false }
                withAnimation(Self.settle) { onMove(id, item.id) }
                return true
            }
            .offset(x: place.x, y: place.y)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(item))
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap(item) }
            .accessibilityActions {
                if let action = holdLabel(item) {
                    Button(action) { onHold?(item) }
                }
            }
            .accessibilityAction(named: L("Move earlier")) { if let before { onMove(item.id, before.id) } }
            .accessibilityAction(named: L("Move later")) { if let after { onMove(item.id, after.id) } }
    }
}
