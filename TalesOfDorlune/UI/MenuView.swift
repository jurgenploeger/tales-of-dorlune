import SwiftUI

/// One of the menu's windows: Hero, Companions, Friends, Inventory, Quests or Settings, each on its own
/// (playtesting 2026-10-25: "The menu items hero etc should become their own modal window"), its own
/// pages its tabs (the Hero's Hero, Skills and Titles; the Companions' and the Monster Book...). It
/// just opens, as every window does, and its close button closes it back to the map (playtesting
/// 2026-10-26: "it shouldn't morph into it any more but just open. When you press close, everything
/// closes").
struct MenuView: View {
    let session: GameSession
    let onClose: () -> Void
    var onQuitToTitle: (() -> Void)?
    /// Which of the menu's windows this is.
    let window: MenuTab
    /// A language switch (in Settings) rebuilds the panel's text, staying on the same tab.
    @State private var localizer = Localizer.shared
    /// Use or Give in the Bag: who gets it, in a window over the menu.
    @State private var picking: ItemDef? = DebugLaunch.picksTargetFor.flatMap { Content.shared.item($0) }
    /// What the last thing used from the Bag did.
    @State private var bagNote: String?
    /// Change on the Character tab: the grid of gear for that slot, in a window over the menu.
    @State private var changing: ItemType? = DebugLaunch.changingSlot
    /// The window's pages (Character, Companions and Quests have more than one), its tabs. Debug
    /// `sub=<page>` opens one.
    @State private var characterPage: CharacterPage = DebugLaunch.subTab.flatMap(CharacterPage.init(rawValue:)) ?? .hero
    @State private var companionsPage: CompanionsPage = DebugLaunch.opensMonsterBook ? .book : .companions
    @State private var questsPage: QuestsPage = DebugLaunch.subTab.flatMap(QuestsPage.init(rawValue:)) ?? .quests
    @State private var settingsPage: SettingsPage = DebugLaunch.subTab.flatMap(SettingsPage.init(rawValue:)) ?? .general
    /// An egg to hatch, chosen on its card: the Bag plays the hatching.
    @State private var hatchRequest: ItemDef?
    /// A tap on something in the Bag: its card, over the menu. Debug `inspect=<item>` opens one
    /// (unless it's for the gear grid, `change=`).
    @State private var inspecting: ItemDef? = DebugLaunch.changingSlot == nil ? DebugLaunch.inspectedItem.flatMap { Content.shared.item($0) } : nil
    /// A tap on a quest in the Quests list: its window, over the menu. Debug `questcard=<quest>` opens
    /// one, and so does the HUD's tracked quest, tapped (`GameSession.questToOpen`).
    @State private var openQuest: QuestDef? = DebugLaunch.openedQuest.flatMap { Content.shared.quest($0) }
    /// A tap on a friend: where they are, in a window over the menu (`FriendMapWindow`).
    @State private var openFriend: Adventurer?
    /// How it works, tapped: its text in a small window over the menu (`ExplainWindow`).
    @State private var explaining: String?

    init(session: GameSession, window: MenuTab, onClose: @escaping () -> Void, onQuitToTitle: (() -> Void)? = nil) {
        self.session = session
        self.onClose = onClose
        self.onQuitToTitle = onQuitToTitle
        self.window = window
        if window == .quests, let id = session.questToOpen, let quest = Content.shared.quest(id) {
            _openQuest = State(initialValue: quest)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            // As big as the HUD's margins allow; only the window scales as it opens (popIn).
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gameWindow()
                .windowCloseButton(close)
                .accessibilityAction(.escape) { close() }
                .popIn()
                .menuWindowMargins()

            if let slot = changing {
                // Fades in; only its window scales (popIn), so its backdrop always fills the screen.
                EquipmentPicker(session: session, slot: slot) {
                    withAnimation(.easeOut(duration: 0.2)) { changing = nil }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if let item = inspecting {
                let close = { withAnimation(.easeOut(duration: 0.2)) { inspecting = nil } }
                // From the Bag: what you can do with it there, on its card.
                let fromBag = window == .bag
                let wearable = fromBag && ItemType.equipmentSlots.contains(item.type) && session.count(of: item.id) > 0
                let equip: (() -> Void)? = wearable ? { session.equip(item.id); close() } : nil
                ItemInfoCard(session: session, item: item, onClose: close, onEquip: equip,
                             action: fromBag ? bagAction(for: item, close: close) : nil,
                             extraAction: fromBag ? dyeAction(for: item, close: close) : nil,
                             note: fromBag ? bagNote(for: item) : nil,
                             fromBag: fromBag)
                .transition(.opacity)
                .zIndex(1)
            }

            if let text = explaining {
                ExplainWindow(text: text) {
                    withAnimation(.easeOut(duration: 0.2)) { explaining = nil }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if let friend = openFriend ?? (DebugLaunch.opensFriendMap ? session.friends.first : nil) {
                FriendMapWindow(session: session, friend: friend) {
                    withAnimation(.easeOut(duration: 0.2)) { openFriend = nil }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if let quest = openQuest {
                QuestWindow(session: session, quest: quest) {
                    withAnimation(.easeOut(duration: 0.2)) { openQuest = nil }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            // Over the item's card when it's opened from there: the card shows again once it closes,
            // unless the last of it is gone.
            if let item = picking {
                ItemTargetPicker(session: session, item: item) { note in
                    if let note { bagNote = note }
                    withAnimation(.easeOut(duration: 0.2)) {
                        picking = nil
                        if session.count(of: item.id) == 0 { inspecting = nil }
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .foregroundStyle(HUDStyle.cream)
        // The HUD's tracked quest opens once: the menu's Quests opens on the list next time.
        .onAppear { session.questToOpen = nil }
    }
}

extension MenuView {
    /// The window's page: its tabs along the top, or its name (the round close button over the
    /// window's corner), and what's on the tab you're on.
    private var page: some View {
        VStack(spacing: 0) {
            tabs

            ScrollView {
                Group {
                    switch window {
                    case .character:
                        CharacterTab(session: session, page: $characterPage) { slot in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { changing = slot }
                        }
                    case .companions:
                        CompanionsTab(session: session, page: $companionsPage, onExplain: explain)
                    case .friends:
                        FriendsTab(session: session, onOpen: { friend in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { openFriend = friend }
                        }, onExplain: explain)
                    case .bag:
                        BagTab(session: session, note: $bagNote, hatchRequest: $hatchRequest,
                               onInspect: { item in withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { inspecting = item } },
                               quickAction: { quickAction(for: $0) })
                    case .quests:
                        QuestsTab(session: session, page: $questsPage) { quest in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { openQuest = quest }
                        }
                    case .settings: SettingsView(session: session, onQuitToTitle: onQuitToTitle, page: settingsPage)
                    }
                }
                .padding(HUDStyle.windowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                // A page of its own for each tab, sliding in from its tab's side.
                .pageSlide(shownPage)
            }
            // Debug `bottom`: opens at the end of the page (screenshots of the skills).
            .defaultScrollAnchor(DebugLaunch.opensMenuAtBottom ? .bottom : nil)
        }
        .id(localizer.language)
    }

    private func close() {
        onClose()
    }

    /// The window's page now, for its slide between tabs (`pageSlide`).
    private var shownPage: String {
        switch window {
        case .character: "\(characterPage)"
        case .companions: "\(companionsPage)"
        case .quests: "\(questsPage)"
        case .settings: "\(settingsPage)"
        case .friends, .bag: "\(window)"
        }
    }

    /// Opens an explanation (`HowItWorks`) in a small window over the menu.
    private func explain(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { explaining = text }
    }

    /// The window's tabs: its pages, or its own name alone when it has just the one.
    @ViewBuilder
    private var tabs: some View {
        switch window {
        case .character:
            // A path to choose (at a guild master) or better gear, or a skill point to spend.
            PageTabs(page: $characterPage, title: { $0.title }) { page in
                switch page {
                case .hero: session.canChooseClass || session.hasGearUpgrade
                case .skills: session.canSpendSkillPoint || session.hasNewSkills
                case .titles: false
                }
            }
        case .companions:
            PageTabs(page: $companionsPage, title: { $0.title })
        case .quests:
            // A quest to report back on, or a bounty or the bonus to claim.
            PageTabs(page: $questsPage, title: { $0.title }) { page in
                switch page {
                case .quests:
                    session.activeQuests.contains { session.status(of: $0) == .ready }
                case .daily:
                    (session.data.bounties?.bounties ?? []).contains { $0.isDone && !$0.claimed } || session.canClaimBountyBonus
                }
            }
        case .settings:
            PageTabs(page: $settingsPage, title: { $0.title })
        case .friends:
            // How many friends you have, a badge after the name.
            WindowTitle(window.menuTitle, badge: session.friends.isEmpty ? nil : "\(session.friends.count)")
                .padding(.bottom, 2)
        case .bag:
            // How full the bag is after its name (playtesting 2026-10-26: "add the x/50 behind the big
            // 'Inventory' title"): 50 slots, one for every item (`GameSession+Bank`); coins take none.
            // In the same badge as the Friends window's count (the user, 2026-11-19), orange when full.
            WindowTitle(window.menuTitle, badge: "\(session.bagSlotsUsed)/\(session.bagSize)",
                        badgeFill: session.bagSlotsFree == 0 ? HUDStyle.orange : nil)
                .accessibilityValue(L("{used} of {slots} slots", ["used": session.bagSlotsUsed, "slots": session.bagSize]))
                .padding(.bottom, 2)
        }
    }

    /// What an item in the Bag can do, on its card: drink it (or give it) to someone, give a toy to
    /// a companion, fly home on a feather, or hatch an egg.
    func bagAction(for item: ItemDef, close: @escaping () -> Void) -> ItemInfoCard.Action? {
        // Who gets it, in a window over the card (the card stays behind it).
        let pick = { withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { picking = item } }
        if item.hatches != nil {
            return ItemInfoCard.Action(title: L("Hatch"), icon: .egg) { close(); hatchRequest = item }
        }
        if (item.heal ?? 0) > 0 || (item.mp ?? 0) > 0 {
            return ItemInfoCard.Action(title: L("Use"), run: pick)
        }
        if item.travel == true {
            // Back to your checkpoint, like Bridge of Light (closes the menu).
            return ItemInfoCard.Action(title: L("Use"), enabled: session.onTravel != nil) { close(); session.onTravel?(item) }
        }
        if item.toy == true, !session.data.pets.isEmpty {
            return ItemInfoCard.Action(title: L("Give"), icon: .gift, run: pick)
        }
        // A piece of what a quest asks you to bring: carve it or piece it together, once the bag
        // holds all it takes (`ItemDef.make`). A gem: mix its dye, with a Sheepskin.
        if let made = session.handmade(using: item) { return makeAction(made, close: close) }
        return nil
    }

    /// What a long press on an item in the Bag does, without opening its card (the user's UI review,
    /// 2026-11-19): Equip for gear you can put on now, Use for what can be used here and now (a potion,
    /// a feather home), through the same steps as its card's button. Nil for the rest: a hold lifts
    /// them to move them, a tap opens their card.
    func quickAction(for item: ItemDef) -> ItemInfoCard.Action? {
        if ItemType.equipmentSlots.contains(item.type) {
            guard session.count(of: item.id) > 0, session.equipIssue(item) == nil else { return nil }
            return ItemInfoCard.Action(title: L("Equip")) { session.equip(item.id) }
        }
        let usable = (item.heal ?? 0) > 0 || (item.mp ?? 0) > 0 || item.travel == true
        guard usable, let action = bagAction(for: item, close: {}), action.enabled else { return nil }
        return action
    }

    /// A gem a quest wants pieced into something still mixes its dye (playtesting 2026-10-31: "I
    /// should be able to create a dye even when on a quest"): beside the quest's, when that's the
    /// card's own action.
    func dyeAction(for item: ItemDef, close: @escaping () -> Void) -> ItemInfoCard.Action? {
        guard let dye = session.dye(mixedFrom: item), let made = session.handmade(using: item), made.id != dye.id else { return nil }
        return makeAction(dye, close: close)
    }

    /// Carving, piecing together or mixing `made` from the bag.
    private func makeAction(_ made: ItemDef, close: @escaping () -> Void) -> ItemInfoCard.Action {
        let title: String = switch made.make ?? .carve {
        case .join: L("Piece together {item}", ["item": made.name])
        case .mix: L("Mix {item}", ["item": made.name])
        case .carve: L("Carve {item}", ["item": made.name])
        }
        return ItemInfoCard.Action(title: title, icon: made.make == .mix ? .palette : .hammer, enabled: session.canCraft(made)) {
            close()
            session.make(made.id)
            session.save()
        }
    }

    /// Why an item in the Bag has nothing to do there.
    func bagNote(for item: ItemDef) -> String? {
        if item.capture == true { return L("For battle") }
        if item.toy == true, session.data.pets.isEmpty { return L("No companions yet") }
        return nil
    }
}

// MARK: - Tabs

/// A window's tabs along its top, its pages' names and nothing else (playtesting 2026-10-26: "The tabs
/// don't need icons and shouldn't get truncated. If it doesn't fit, there should just be a horizontal
/// scroll"): folder tabs on the window's title bar (`WindowBar`; the user, 2026-11-10: "We can have the
/// title bars with the tabs"), the one you're on the window's own glass with its name in gold, joined
/// to the page under it, the others sunk into the bar; each name in full, the row scrolling sideways
/// when they don't all fit (the one you're on kept in view), clear of the close button over the
/// window's corner. One you're not on wears the HUD's gold dot when something there waits for you
/// (`waiting`). The pages are a nonisolated enum (its raw value is the debug name, `sub=skills`).
struct PageTabs<Page: Hashable & CaseIterable>: View {
    @Binding var page: Page
    let title: (Page) -> String
    /// The pages to show, in order, where not all of them are (someone's profile with no companion);
    /// all of them when nil.
    var shown: [Page]? = nil
    var waiting: (Page) -> Bool = { _ in false }
    /// Where each tab is in the strip as it shows now, for the chevrons to find the first hidden.
    @State private var frames: [Page: CGRect] = [:]
    /// Where each tab is in the row of tabs itself (scrolling with it), for the one you're on's glass
    /// (`highlight`).
    @State private var places: [Page: CGRect] = [:]
    @State private var shownWidth: CGFloat = 0

    /// The pages in order.
    private var pages: [Page] { shown ?? Array(Page.allCases) }

    var body: some View {
        ScrollViewReader { reader in
            // Faded at an edge with more tabs past it, a chevron there (`SideScroll`): tapped, the
            // nearest tab hidden that way scrolls into the middle.
            SideScroll(step: { edge in
                guard let next = hidden(toward: edge) else { return }
                withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo(next, anchor: .center) }
            }, chevronTop: TabEdge.inset / 2) {
                // Standing on the bar's foot, the one you're on a little taller, the others only their
                // names on the bar, a faint upright line between two of them.
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element) { index, item in
                        tab(item)
                            .id(item)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.strip)) } action: { frames[item] = $0 }
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.row)) } action: { places[item] = $0 }
                            .overlay(alignment: .trailing) {
                                if index + 1 < pages.count, item != page, pages[index + 1] != page {
                                    HUDStyle.frameDark.opacity(0.4).frame(width: 1, height: 16)
                                        .padding(.bottom, 3)
                                        .offset(x: 0.5)
                                }
                            }
                    }
                }
                // In from the window's side past the page's rounded corner (`PageCorner`), so the first
                // tab, when it's the one you're on, flares out of the corner's round straight into its
                // own (the user, 2026-11-16: "the first tab should be more inserted so it also shows the
                // rounded corner in the bottom left"); the last clear of the close button's room.
                .coordinateSpace(name: Self.row)
                // The one you're on's glass, one piece that slides from tab to tab as you switch (the
                // user, 2026-11-16: "The tabs should slide between each other when you click on one
                // another"), under their names.
                .background(alignment: .topLeading) { highlight }
                .padding(.leading, PageFillet.side + FlaredTab.flare)
                .padding(.trailing, OrangeCloseButton.room + 8)
                .padding(.top, TabEdge.inset)
            }
            .coordinateSpace(name: Self.strip)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { shownWidth = $0 }
            .onAppear { reader.scrollTo(page, anchor: .center) }
            .onChange(of: page) {
                withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(page, anchor: .center) }
            }
        }
        // The bar, transparent under the tabs; and the page's light edge along its foot, from the
        // page's top corners (`PageCorner`) to the feet of the tab you're on's flares, and on from
        // them: not under them, where it doubled their line (playtesting 2026-11-16).
        .background {
            WindowBar(foot: false)
                .overlay {
                    // Its gap follows the tab you're on as it slides (`BarLine`).
                    BarLine(gap: frames[page].map { $0.minX - FlaredTab.flare } ?? 0,
                            gapEnd: frames[page].map { $0.maxX + FlaredTab.flare } ?? 0)
                        .stroke(HUDStyle.frameLight.opacity(0.8), lineWidth: 1.5)
                    .allowsHitTesting(false)
                }
        }
        // The page's top corners, rounded where its edge meets the bar's foot (the user, 2026-11-16:
        // "If another tab than the first is selected, there should be a corner radius like this"),
        // hanging under the bar, their line level with the bar's (`PageFillet.lift`).
        .overlay(alignment: .bottomLeading) {
            PageCorner(edge: .leading).offset(y: PageFillet.radius - PageFillet.lift)
        }
        .overlay(alignment: .bottomTrailing) {
            PageCorner(edge: .trailing).offset(y: PageFillet.radius - PageFillet.lift)
        }
        // Over the page under it, where its corners hang.
        .zIndex(1)
    }

    /// The strip as it shows, for the tabs' frames (`frames`).
    private static var strip: String { "PageTabs.strip" }
    /// The row of tabs, for where each stands in it (`places`).
    private static var row: String { "PageTabs.row" }

    /// The glass of the tab you're on, where it stands in the row: flaring at its foot into the bar,
    /// edged light up its sides and over its top.
    @ViewBuilder
    private var highlight: some View {
        if let place = places[page] {
            ZStack {
                FlaredTab().fill(HUDStyle.glassTop)
                FlaredTab(open: true).stroke(HUDStyle.frameLight.opacity(0.8), lineWidth: 1.5)
            }
            .frame(width: place.width + 2 * FlaredTab.flare, height: place.height)
            .offset(x: place.minX - FlaredTab.flare, y: place.minY)
            .allowsHitTesting(false)
        }
    }

    /// The nearest tab hidden past `edge`, under its chevron or beyond it.
    private func hidden(toward edge: HorizontalEdge) -> Page? {
        let room = SideScroll<EmptyView>.chevronRoom
        let tabs = pages
        switch edge {
        case .trailing: return tabs.first { (frames[$0]?.maxX ?? 0) > shownWidth - room }
        case .leading: return tabs.last { (frames[$0]?.minX ?? 0) < room }
        }
    }

    private func tab(_ item: Page) -> some View {
        let selected = item == page
        let marked = !selected && waiting(item)
        return Button {
            guard !selected else { return }
            SoundEffects.shared.play(.tap, volume: 0.7)
            // The pages slide across toward the side its tab is on (`pageSlide`): the way set first,
            // so the page you leave has it too, then the page a moment later.
            let order = pages
            let forward = (order.firstIndex(of: item) ?? 0) > (order.firstIndex(of: page) ?? 0)
            let turn = $page
            if PageSlide.shared.forward == forward {
                withAnimation(PageSlide.animation) { turn.wrappedValue = item }
            } else {
                PageSlide.shared.forward = forward
                DispatchQueue.main.async {
                    withAnimation(PageSlide.animation) { turn.wrappedValue = item }
                }
            }
        } label: {
            Text(title(item))
                .font(HUDStyle.title(13))
                .lineLimit(1)
                .fixedSize()
                // The one you're on in gold on the glass; the others in the title bar's lettering
                // (`HUDStyle.barText`), readable on its light blue.
                .foregroundStyle(selected ? HUDStyle.gold : HUDStyle.barText)
                .shadow(color: selected ? .clear : HUDStyle.barTextShadow, radius: 0, x: 0, y: 1)
                .padding(.horizontal, 13)
                // Every tab as tall, so a name stays where it is as the glass slides under it (the user,
                // 2026-11-16: "The labels shouldn't move in y position from inactive and active").
                .padding(.vertical, 9)
                .background {
                    // The one you're on flares out at its foot, its bottom corners rounded the other way
                    // into the bar (the user, 2026-11-11: "The bottom of the tabs should have rounded
                    // corners that are inverted to the other side"), so it runs into the page as a
                    // folder's tab does.
                    // None of its own: the one you're on's glass slides under it (`highlight`); the others
                    // have none, their names on the bar (the user, 2026-11-16: "the inactive tabs
                    // shouldn't have a tab fill, just transparent").
                    EmptyView()
                }
                .overlay {
                    // A light edge up its sides, over its top and out along its flares; none along its
                    // foot, where it's the page's. One you're not on edged faintly in the bar's dark.
                    EmptyView()
                }
                .overlay(alignment: .topTrailing) {
                    if marked {
                        Circle().fill(HUDStyle.gold).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(HUDStyle.ink, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(marked ? L("Something to do") : "")
    }
}

extension PageTabs {
    /// A folder tab: round at the top, square where it stands on the bar's foot.
    fileprivate static var tabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: TabEdge.radius, bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                               topTrailingRadius: TabEdge.radius, style: .circular)
    }
}

/// The tab you're on (`PageTabs`), drawn `flare` wider on each side than the tab: round at the top,
/// and at its foot its corners rounded the other way, curving out into the bar it stands on. `open`:
/// its edge only, for the stroke, with no line along its foot.
private nonisolated struct FlaredTab: Shape {
    static let flare: CGFloat = 6
    var open = false
    /// Whether it flares at its left: not the first tab, which stands at the window's side and runs
    /// straight down into the page's (then drawn no wider than the tab on that side).
    var leading = true

    func path(in rect: CGRect) -> Path {
        let flare = Self.flare, radius = TabEdge.radius
        // Inside by half the stroke's width at the top and sides, so a stroke stays on it.
        let left = rect.minX + (leading ? flare : 0) + 0.75, right = rect.maxX - flare - 0.75, top = rect.minY + 0.75
        // Its line ends on the middle of the page's line along the bar's foot (1.5 wide), not under it.
        let bottom = open ? rect.maxY - 0.75 : rect.maxY
        var path = Path()
        // Round arcs, as the window's corners are, the flares as the top's turned the other way.
        if leading {
            path.move(to: CGPoint(x: rect.minX, y: bottom))
            path.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: left, y: top), radius: flare)
        } else {
            path.move(to: CGPoint(x: left, y: bottom))
        }
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: radius)
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: bottom), radius: radius)
        path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: rect.maxX, y: bottom), radius: flare)
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        if !open { path.closeSubpath() }
        return path
    }
}

/// Which way a window's pages slide as you switch tabs (the user, 2026-11-16: "When switching the
/// modal window tabs, can we have them move horizontally?", then "the tabs should move across
/// horizontally, instead of this fade"): `PageTabs` sets `forward` as you tap a tab right of the one
/// you're on, and `pageSlide` pushes the pages across that way. Observed, so a window's pages take
/// the new way before the page changes (`PageTabs` changes it a moment later): the page leaving goes
/// out the side the way says, not the way the last switch went.
@MainActor @Observable final class PageSlide {
    static let shared = PageSlide()
    var forward = true
    static let animation = Animation.easeInOut(duration: 0.3)
}

extension View {
    /// What a window shows on its page `page` (`PageTabs`): a page of its own, pushed across as you
    /// switch tabs, the new one in from the side of the tab you tapped and the old one out the other
    /// (`PageSlide.forward`).
    @MainActor func pageSlide(_ page: some Hashable) -> some View {
        id(page)
            .transition(.push(from: PageSlide.shared.forward ? .trailing : .leading))
    }
}

/// The page's light edge along the bar's foot under a window's tabs (`PageTabs`): from the page's top
/// corners (`PageFillet.side` in from each side), with a gap from `gap` to `gapEnd` where the tab
/// you're on stands, which slides as it does (`animatableData`). No gap where both are 0.
private nonisolated struct BarLine: Shape {
    var gap: CGFloat
    var gapEnd: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(gap, gapEnd) }
        set {
            gap = newValue.first
            gapEnd = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let y = rect.maxY - 0.75
        let from = PageFillet.side, to = rect.width - PageFillet.side
        let runs = gapEnd > gap ? [(from, min(to, gap)), (max(from, gapEnd), to)] : [(from, to)]
        var path = Path()
        for (start, end) in runs where end > start {
            path.move(to: CGPoint(x: start, y: y))
            path.addLine(to: CGPoint(x: end, y: y))
        }
        return path
    }
}

/// A page's top corner under its window's tabs (`PageTabs`): the bar's light blue round the outside
/// of a quarter round `PageFillet.radius` across, and the page's light edge along it, from the bar's
/// foot down to the window's side (inside its frame), where the frame's own edge runs on.
private struct PageCorner: View {
    let edge: HorizontalEdge

    var body: some View {
        ZStack {
            PageFillet(edge: edge, open: false).fill(HUDStyle.frameMid)
            PageFillet(edge: edge, open: true).stroke(HUDStyle.frameLight.opacity(0.8), lineWidth: 1.5)
        }
        .frame(width: PageFillet.side, height: PageFillet.radius)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// `PageCorner`'s shape, top down: the bar's colour outside the round, or with `open` the round
/// alone, for the line. Drawn for the left, mirrored for the right.
private nonisolated struct PageFillet: Shape {
    /// The corner's round (the user's, 2026-11-16: 16), and how far in from the window's edge its line
    /// comes down: onto the frame's light bevel (`HUDStyle.frame`, 3 wide), so it runs on into the
    /// window's light border (the user, 2026-11-16: "the line all the way on the left should go into
    /// the light border line of the modal"; ending inside the frame, the frame's dark inner line cut it off).
    static let radius: CGFloat = 16
    static let frameWidth: CGFloat = 1.5
    /// How far in from the window's side the page's edge along the bar's foot begins.
    static var side: CGFloat { frameWidth + radius }
    /// How far up into the bar it reaches: its line's width, so its line lies on the bar's own along
    /// its foot (hung just under it, it showed a step below the line, playtesting 2026-11-16).
    static let lift: CGFloat = 1.5

    let edge: HorizontalEdge
    let open: Bool

    func path(in rect: CGRect) -> Path {
        let r = Self.radius, inner = Self.frameWidth
        let line: CGFloat = open ? 0.75 : 0
        var path = Path()
        path.move(to: CGPoint(x: inner + line, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: inner + line, y: line), tangent2End: CGPoint(x: inner + r, y: line), radius: r - line)
        path.addLine(to: CGPoint(x: inner + r, y: line))
        if !open {
            path.addLine(to: CGPoint(x: inner + r, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
        guard edge == .trailing else { return path }
        return path.applying(CGAffineTransform(translationX: rect.width, y: 0).scaledBy(x: -1, y: 1))
    }
}

/// A folder tab's edge (`PageTabs`): up its left side, over its top and down its right, open along
/// its foot.
private nonisolated struct TabEdge: Shape {
    /// How far the tabs stand in from the window's top and side.
    static let inset: CGFloat = 10
    /// A tab's top corners: the window's own (`HUDStyle.windowRadius`, 22) less how far in the tabs
    /// stand (`inset`), so the first tab's corner runs alongside the window's, the same distance off
    /// all the way round (the user, 2026-11-11: "Have the tabs rounded corners the right corner based
    /// on the inset in the modal").
    static let radius: CGFloat = 22 - TabEdge.inset

    func path(in rect: CGRect) -> Path {
        // Inside the tab by half the line's width, so the stroke stays on it.
        let left = rect.minX + 0.75, right = rect.maxX - 0.75, top = rect.minY + 0.75, radius = Self.radius
        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: radius)
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: rect.maxY), radius: radius)
        path.addLine(to: CGPoint(x: right, y: rect.maxY))
        return path
    }
}

/// A window's explanation. While you have none of what it explains (no companions yet, no friends)
/// it's there on the page; after that a gold "How it works" opens it in a small window over the menu
/// (`ExplainWindow`; the user, 2026-11-11: "The How it works should open a smaller overlayed
/// modal"), where it unrolled in the page before.
private struct HowItWorks: View {
    let text: String
    /// Shown on the page, as there's nothing else to show.
    let open: Bool
    /// Opens the text in a window over the menu (`MenuView`'s `explaining`).
    let onOpen: (String) -> Void

    init(_ text: String, open: Bool, onOpen: @escaping (String) -> Void) {
        self.text = text
        self.open = open
        self.onOpen = onOpen
    }

    var body: some View {
        if open {
            Text(text)
                .font(HUDStyle.font(11))
                .foregroundStyle(HUDStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Button {
                SoundEffects.shared.play(.tap, volume: 0.7)
                onOpen(text)
            } label: {
                HStack(spacing: 5) {
                    IconImage(.book, size: 13)
                    Text(L("How it works"))
                    IconImage(.chevronDown, size: 14)
                        .rotationEffect(.degrees(-90))
                }
                .font(HUDStyle.font(11))
                .foregroundStyle(HUDStyle.gold)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L("Shows the explanation"))
        }
    }
}

/// An explanation (`HowItWorks`) in a small window of its own over the menu: its title on the bar,
/// the text under it, scrolling only if it can't all fit.
struct ExplainWindow: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                WindowTitle(L("How it works"), onClose: onClose)
                FitOrScroll {
                    VStack(alignment: .leading, spacing: 10) {
                        // A paragraph a line of the text, apart.
                        ForEach(Array(text.split(separator: "\n").enumerated()), id: \.offset) { _, paragraph in
                            Text(String(paragraph))
                                .font(HUDStyle.body(12))
                                .foregroundStyle(HUDStyle.cream)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
            .gameWindow()
            .popIn()
            .padding(24)
        }
        .foregroundStyle(HUDStyle.cream)
        .accessibilityAction(.escape, onClose)
    }
}

/// A group's name over it, in gold capitals, and how many it holds (`detail`: "Party · 3/4"), a
/// faint gold rule running on after it so the window reads as groups (the user, 2026-11-11).
struct SectionTitle: View {
    let text: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text((detail.map { text + " · " + $0 } ?? text).uppercased())
                .font(HUDStyle.title(11))
                .foregroundStyle(HUDStyle.gold)
                .monospacedDigit()
                .fixedSize()
            HUDStyle.gold.opacity(0.3).frame(height: 1)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Character

/// The Character tab's pages.
private nonisolated enum CharacterPage: String, CaseIterable {
    /// Who you are: the hero, their stats and what they wear.
    case hero
    /// What you know and can learn, and what your class unlocks later.
    case skills
    /// The titles you've earned, and those still to earn.
    case titles

    var title: String {
        switch self {
        case .hero: L("Hero")
        case .skills: L("Skills")
        case .titles: L("Titles")
        }
    }
}

private struct CharacterTab: View {
    let session: GameSession
    @Binding var page: CharacterPage
    /// Change on an equipment row: MenuView opens the grid of gear for that slot.
    let onChange: (ItemType) -> Void
    /// The skills your class unlocks later: the next two, or all of them.
    @State private var showsAllUpcoming = false

    var body: some View {
        let hero = session.data.hero
        let stats = session.heroStats
        // Looks are chosen once, when the hero is made (LookEditor on the title screen).
        VStack(alignment: .leading, spacing: 14) {
            switch page {
            case .hero: overview(hero: hero, stats: stats)
            case .skills: skills(hero: hero)
            case .titles: TitlesSection(session: session)
            }
        }
    }

    @ViewBuilder
    private func overview(hero: Hero, stats: Stats) -> some View {
        AdaptiveStack(spacing: 18) {
            VStack(spacing: 6) {
                // The hero in the middle, what they wear in the slots around them.
                PaperDoll(session: session, change: onChange)
                // The name is chosen when the hero is made and stays.
                Text(hero.name).font(HUDStyle.title(18))
                if let title = session.wornTitle {
                    TitleBadge(title: title, size: 12)
                }
                Text("\(session.heroRace.name) · \(session.heroClass.name)")
                    .font(HUDStyle.font(12))
                    .foregroundStyle(HUDStyle.gold)
                if session.canChooseClass {
                    Text(L("Ready to choose a path! Visit a guild master in Meadowbrook."))
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.green)
                        .multilineTextAlignment(.center)
                        .frame(width: 170)
                }
            }
            .frame(minWidth: 250)
            .frame(maxWidth: .infinity)

            StatsPanel(level: L("Level {level}", ["level": hero.level]),
                       exp: hero.exp, expToNext: GameSession.expToNext(level: hero.level), hp: hero.hp, mp: hero.mp, stats: stats,
                       maxed: hero.level >= GameSession.levelCap,
                       mastery: hero.level >= GameSession.levelCap ? hero.masteryPoints ?? 0 : nil)
        }
    }

    /// Skill points, what you know and can learn (SkillChoices), and what your class unlocks later:
    /// the next two, the rest a tap away.
    private func skills(hero: Hero) -> some View {
        let upcoming = session.heroClass.skills.filter { $0.level > hero.level }
        return VStack(alignment: .leading, spacing: 10) {
            if session.canSpendSkillPoint {
                // In a gold pill, as it's something to do: tap a skill you know, then raise it.
                Text(session.unspentSkillPoints == 1 ? L("1 skill point to spend") : L("{count} skill points to spend", ["count": session.unspentSkillPoints]))
                    .font(HUDStyle.font(11))
                    .monospacedDigit()
                    .foregroundStyle(HUDStyle.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(HUDStyle.gold))
            } else if session.unspentSkillPoints > 0 {
                // Everything known is mastered: points wait for the next skill the class unlocks.
                Text(L("{count} saved for your next skill", ["count": session.unspentSkillPoints]))
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.dim)
            }
            if session.heroSkills.isEmpty && session.learnableSkills.isEmpty {
                EmptyNote(session.skillHint, size: 11)
            }
            // What you know and what's still to learn at your guild, each a group of its own.
            SkillChoices(session: session, grouped: true)
            if !upcoming.isEmpty {
                SectionTitle(text: L("Coming up"), detail: "\(upcoming.count)")
                // Still locked: one group (`GroupedRows`), each a faded tile with the level it unlocks at.
                GroupedRows(showsAllUpcoming ? upcoming : Array(upcoming.prefix(2)), id: \.skill) { unlock in
                    if let skill = session.content.skill(unlock.skill) {
                        HStack(spacing: 10) {
                            SkillIcon(skill: skill, size: 28)
                                .saturation(0.2)
                                .opacity(0.55)
                            Text(skill.name)
                                .foregroundStyle(HUDStyle.dim)
                            Spacer()
                            Text(L("Lv {level}", ["level": unlock.level]))
                                .font(HUDStyle.font(10))
                                .foregroundStyle(HUDStyle.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(HUDStyle.dim))
                        }
                        .font(HUDStyle.font(11))
                        .groupRow()
                    }
                }
            }
            if upcoming.count > 2 {
                Button(showsAllUpcoming ? L("Show fewer") : L("Show {count} more", ["count": upcoming.count - 2])) {
                    withAnimation(.easeOut(duration: 0.2)) { showsAllUpcoming.toggle() }
                }
                .font(HUDStyle.font(11))
                .foregroundStyle(HUDStyle.gold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Stats section of the Character screen, and of the companion you bring along: the level,
/// HP, MP and EXP bars and the four stats with their icons, every number in one size. Big and easy
/// to read: the screen has the room. Another adventurer's (`ProfileWindow`) has no EXP to show.
struct StatsPanel: View {
    let level: String
    let exp: Int?
    let expToNext: Int
    let hp: Int
    let mp: Int
    let stats: Stats
    /// At the level cap (`GameSession.levelCap`): the EXP bar full (the user, 2026-11-16, with ∞ over it;
    /// 2026-11-18, the percentage alone: "Remove the infinite icon, just show the percentage").
    var maxed = false
    /// The hero's skill points from mastery at the cap: the EXP bar fills toward the next one
    /// (`GameSession.masteryBar`), how full over it and a `NoticeBar` under it saying what it's for.
    /// Nil for a companion's, which stands full.
    var mastery: Int? = nil

    private static let digits: CGFloat = 13
    private static let attackTint = Color(red: 1, green: 0.5, blue: 0.35)
    private static let magicTint = Color(red: 0.78, green: 0.58, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                // Its gold rule runs on to the level.
                SectionTitle(text: L("Stats"))
                Text(level).font(HUDStyle.title(15))
            }
            bar(L("HP"), hp, stats.hp, HUDStyle.hp)
            // Companions without magic have no MP to show.
            if stats.mp > 0 { bar(L("MP"), mp, stats.mp, HUDStyle.mp) }
            // EXP last, under HP and MP, as the HUD's own block has it (playtesting 2026-11-01).
            if maxed, let mastery, let exp {
                let percent = exp * 100 / max(1, GameSession.masteryBar)
                VStack(alignment: .leading, spacing: 8) {
                    // Only how full the bar is: ∞ beside it read as a glitch (the user, 2026-11-18).
                    StatBar(label: L("EXP"), value: exp, maximum: GameSession.masteryBar, color: HUDStyle.exp, labelWidth: 36, height: 20,
                            labelSize: 15, numberSize: Self.digits, caption: "\(percent)%")
                        .accessibilityValue(L("Highest level, mastery {percent}%", ["percent": percent]))
                    // What the bar's for, in a notice of its own rather than a small grey line (the user, 2026-11-18).
                    NoticeBar(text: L("Mastery: every full bar is a skill point ({count} so far).", ["count": mastery]))
                }
            } else if maxed {
                StatBar(label: L("EXP"), value: 1, maximum: 1, color: HUDStyle.exp, labelWidth: 36, height: 20,
                        labelSize: 15, numberSize: Self.digits, caption: "100%")
                    .accessibilityValue(L("Highest level"))
            } else if let exp {
                bar(L("EXP"), exp, expToNext, HUDStyle.exp)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                StatCell(name: L("Attack"), value: stats.attack, size: 13, icon: .sword, tint: Self.attackTint, digits: Self.digits)
                StatCell(name: L("Defense"), value: stats.defense, size: 13, icon: .shield, tint: HUDStyle.mp, digits: Self.digits)
                StatCell(name: L("Magic"), value: stats.magic, size: 13, icon: .sparkles, tint: Self.magicTint, digits: Self.digits)
                StatCell(name: L("Speed"), value: stats.speed, size: 13, icon: .wind, tint: HUDStyle.green, digits: Self.digits)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bar(_ label: String, _ value: Int, _ maximum: Int, _ color: Color) -> some View {
        StatBar(label: label, value: value, maximum: maximum, color: color,
                labelWidth: 36, height: 20, labelSize: 15, numberSize: Self.digits)
    }
}

struct StatCell: View {
    let name: String
    let value: Int
    /// The text size; the padding grows with it (bigger on the Character screen).
    var size: CGFloat = 12
    /// The stat's icon before its name, in its colour (the Character screen).
    var icon: GameIcon?
    var tint: Color = HUDStyle.dim
    /// The number in the HUD's digits at this size, to match the bars beside it.
    var digits: CGFloat?

    var body: some View {
        HStack(spacing: size * 0.45) {
            if let icon {
                IconImage(icon, size: (size * 1.15).rounded()).foregroundStyle(tint)
            }
            Text(name).foregroundStyle(HUDStyle.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text("\(value)").foregroundStyle(.white)
                .monospacedDigit()
                .font(digits.map { HUDStyle.mono($0) } ?? HUDStyle.font(size))
        }
        .font(HUDStyle.font(size))
        .padding(.horizontal, size * 0.7)
        .padding(.vertical, size * 0.45)
        .background(GlassCard(radius: size * 0.45))
    }
}

/// The hero in the middle with what they wear in a ring around them, like a paper doll: the hat and
/// cape over their head, the body's slots round the left (necklace, armour, boots, top to bottom),
/// the hands' round the right (weapon, gloves, accessory). A tap on a slot opens everything you
/// have for it (EquipmentPicker).
private struct PaperDoll: View {
    let session: GameSession
    let change: (ItemType) -> Void

    /// Each slot and where it sits on the ring, in degrees clockwise from the right: an eighth of
    /// the way round apart (playtesting 2026-10-18: no wider gap under the hero's feet), the hat
    /// and cape either side of the top, the boots and accessory either side of the bottom.
    static let ring: [(slot: ItemType, angle: Double)] = [
        (.head, 247.5), (.cape, 292.5), (.weapon, 337.5), (.gloves, 22.5), (.accessory, 67.5),
        (.boots, 112.5), (.armor, 157.5), (.necklace, 202.5),
    ]
    /// The ring's radius (to each slot's middle), and the room a slot takes.
    static let radius: CGFloat = 112
    static let slot = CGSize(width: 62, height: 66)
    /// From the hat and cape at the top of the ring down to the boots and the accessory.
    static let high = radius * CGFloat(ring.map { -sin($0.angle * Double.pi / 180) }.max() ?? 1)
    static let low = radius * CGFloat(ring.map { sin($0.angle * Double.pi / 180) }.max() ?? 1)

    var body: some View {
        let width = Self.radius * 2 + Self.slot.width
        let high = Self.high, low = Self.low
        let height = high + low + Self.slot.height
        ZStack {
            // A faint ring through the slots, and the hero on a soft disc in the middle.
            Circle()
                .strokeBorder(.white.opacity(0.08), lineWidth: 2)
                .frame(width: Self.radius * 2, height: Self.radius * 2)
            WalkingSprite(art: GameSession.heroArt, size: 128, weapon: session.equipped(.weapon))
                .background(Circle().fill(.white.opacity(0.06)))
            ForEach(Self.ring, id: \.slot) { place in
                let angle = place.angle * Double.pi / 180
                DollSlot(session: session, slot: place.slot) { change(place.slot) }
                    .frame(width: Self.slot.width, height: Self.slot.height)
                    .offset(x: Self.radius * CGFloat(cos(angle)), y: Self.radius * CGFloat(sin(angle)))
            }
        }
        // The ring's middle sits lower than the frame's, as much as the hat reaches higher than the boots.
        .offset(y: (high - low) / 2)
        .frame(width: width, height: height)
        .padding(.vertical, 4)
    }
}

/// One slot on the paper doll: what's worn there, or the slot's shape faded when it's empty, with
/// the slot's name under it. When the bag holds something better for it that you can wear (or
/// anything you can wear for an empty slot), the gold upgrade arrow says so.
private struct DollSlot: View {
    let session: GameSession
    let slot: ItemType
    let change: () -> Void

    private static let size: CGFloat = 44

    /// What an empty slot shows, faded: the plainest piece for it (on someone else's doll too, `WornDoll`).
    static let silhouettes: [ItemType: String] = [
        .weapon: "wooden_sword", .armor: "cloth_tunic", .gloves: "leather_gloves",
        .necklace: "shell_pendant", .boots: "straw_sandals", .accessory: "novice_ring", .cape: "wayfarer_cape",
        .head: "white_party_hat",
    ]

    var body: some View {
        let worn = session.equipped(slot)
        let better = session.upgrade(for: slot)
        Button(action: change) {
            VStack(spacing: 3) {
                Group {
                    if let worn {
                        ItemIcon(item: worn, size: Self.size)
                    } else if let shape = Self.silhouettes[slot].flatMap(session.content.item) {
                        ItemIcon(item: shape, size: Self.size)
                            .saturation(0)
                            .opacity(0.3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if better != nil { UpgradeBadge().offset(x: 6, y: -6) }
                }
                Text(slot.displayName)
                    .font(HUDStyle.font(9))
                    .foregroundStyle(HUDStyle.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: Self.size + 14)
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(slot.displayName)
        .accessibilityValue([worn.map { [$0.name, $0.stats?.bonusSummary ?? ""].filter { !$0.isEmpty }.joined(separator: ", ") } ?? L("Empty"),
                             better.map { L("{item} in your bag is better", ["item": $0.name]) } ?? ""]
                            .filter { !$0.isEmpty }.joined(separator: ". "))
        .accessibilityHint(L("Change"))
    }
}

/// Another adventurer in the middle of the same ring as your paper doll (`ProfileWindow`): what they
/// hold and wear in its slot, an empty slot a dashed outline, each slot's name under it. A tap on a piece
/// opens its card (`inspect`).
struct WornDoll: View {
    let session: GameSession
    let art: String
    let weapon: ItemDef?
    let worn: [ItemDef]
    let inspect: (ItemDef) -> Void

    private static let size: CGFloat = 44

    var body: some View {
        let radius = PaperDoll.radius, slot = PaperDoll.slot
        let high = PaperDoll.high, low = PaperDoll.low
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.08), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            WalkingSprite(art: art, size: 128, weapon: weapon)
                .background(Circle().fill(.white.opacity(0.06)))
            ForEach(PaperDoll.ring, id: \.slot) { place in
                let angle = place.angle * Double.pi / 180
                piece(place.slot)
                    .frame(width: slot.width, height: slot.height)
                    .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            }
        }
        .offset(y: (high - low) / 2)
        .frame(width: radius * 2 + slot.width, height: high + low + slot.height)
        .padding(.vertical, 4)
    }

    private func piece(_ type: ItemType) -> some View {
        let item = worn.first { $0.type == type }
        return Button {
            if let item { inspect(item) }
        } label: {
            VStack(spacing: 3) {
                Group {
                    if let item {
                        ItemIcon(item: item, size: Self.size)
                    } else {
                        // Plainly empty: a dashed outline of a tile, not a faded piece (playtesting
                        // 2026-10-30: a bot's faded cape read as a cape they wore).
                        RoundedRectangle(cornerRadius: Self.size * 0.26)
                            .strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: Self.size, height: Self.size)
                    }
                }
                Text(type.displayName)
                    .font(HUDStyle.font(9))
                    .foregroundStyle(HUDStyle.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: Self.size + 14)
            }
        }
        .buttonStyle(PressScaleStyle())
        .allowsHitTesting(item != nil)
        .accessibilityLabel(type.displayName)
        .accessibilityValue(item.map { [$0.name, $0.stats?.bonusSummary ?? ""].filter { !$0.isEmpty }.joined(separator: ", ") } ?? L("Empty"))
    }
}

/// The companion you bring along laid out as the hero is (playtesting 2026-10-25: the Hero and Companion
/// pages "should become similar"): big on the same soft disc in the same faint ring, its skills in the
/// ring's slots where the hero has their gear, the first pair either side of its head, the next under them.
/// Another adventurer's companion too (`ProfileWindow`).
struct CompanionDoll: View {
    let art: String
    let skills: [SkillDef]

    /// Where each skill sits on the ring, in the order the companion learnt them: on the hero's own
    /// slots, in pairs either side.
    private static let angles: [Double] = [202.5, 337.5, 157.5, 22.5, 247.5, 292.5, 112.5, 67.5]

    var body: some View {
        let radius = PaperDoll.radius, slot = PaperDoll.slot
        let high = PaperDoll.high, low = PaperDoll.low
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.08), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            SpriteImage(art: art, size: 128)
                .background(Circle().fill(.white.opacity(0.06)))
            ForEach(Array(skills.prefix(Self.angles.count).enumerated()), id: \.offset) { index, skill in
                let angle = Self.angles[index] * Double.pi / 180
                VStack(spacing: 3) {
                    SkillIcon(skill: skill, size: 44)
                    Text(skill.name)
                        .font(HUDStyle.font(9))
                        .foregroundStyle(HUDStyle.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 58)
                }
                .frame(width: slot.width, height: slot.height)
                .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
                .accessibilityElement(children: .combine)
            }
        }
        .offset(y: (high - low) / 2)
        .frame(width: radius * 2 + slot.width, height: high + low + slot.height)
        .padding(.vertical, 4)
    }
}

/// An element's shape and name on a glossy pill of its gem.
struct ElementBadge: View {
    let element: Element

    var body: some View {
        HStack(spacing: 3) {
            IconImage(element.icon, size: 10)
            Text(element.displayName)
        }
        .font(HUDStyle.font(9))
        // As wide as its name, on one line: a crowded row squeezes the skill's name instead.
        .lineLimit(1)
        .fixedSize()
        .onElementGem(element, horizontal: 7, vertical: 2.5)
    }
}

/// An element's shape on a round gem, where there's no room for its name.
struct ElementIcon: View {
    let element: Element
    var size: CGFloat = 16

    var body: some View {
        let gem = ElementGem(element)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [gem.light, gem.base, gem.shade], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            Ellipse()
                .fill(ElementGem.gloss)
                .frame(width: size * 0.68, height: size * 0.46)
                .offset(y: -size * 0.2)
            Circle().strokeBorder(gem.deep, lineWidth: 1)
            Circle().inset(by: 1).strokeBorder(ElementGem.bevel, lineWidth: 0.75)
            IconImage(element.icon, size: (size * 0.6).rounded())
                .foregroundStyle(gem.ink)
                .shadow(color: gem.inkShadow, radius: 0, x: 0, y: gem.inkDrop)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(element.displayName)
    }
}

extension View {
    /// Sets this shape and name on `element`'s gem, cut as a glossy pill.
    func onElementGem(_ element: Element, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let gem = ElementGem(element)
        return foregroundStyle(gem.ink)
            .shadow(color: gem.inkShadow, radius: 0, x: 0, y: gem.inkDrop)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [gem.light, gem.base, gem.shade], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        // The shine across its top half.
                        VStack(spacing: 0) {
                            Capsule().fill(ElementGem.gloss)
                            Color.clear
                        }
                        .padding(.horizontal, 3)
                        .padding(.top, 1.5)
                    }
                    .overlay(Capsule().strokeBorder(gem.deep, lineWidth: 1))
                    .overlay(Capsule().inset(by: 1).strokeBorder(ElementGem.bevel, lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            )
    }
}

/// The gem an element's badges are cut from, lit from the top: a light top, its colour, a shaded
/// lower edge and a deep rim. Its shape sits on it in white with a deep drop, or engraved in a dark
/// tone on the pale gems (gold light, silver metal, pearl neutral), where white wouldn't show.
private struct ElementGem {
    let light: Color
    let base: Color
    let shade: Color
    let deep: Color
    let ink: Color
    let inkShadow: Color
    let inkDrop: CGFloat

    static let gloss = LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
    /// A thin light edge just inside the rim, along the top.
    static let bevel = LinearGradient(colors: [.white.opacity(0.65), .clear], startPoint: .top, endPoint: .center)

    init(_ element: Element) {
        switch element {
        case .fire: self.init(light: (1, 0.78, 0.42), base: (0.92, 0.36, 0.1), deep: (0.55, 0.12, 0.02))
        case .water: self.init(light: (0.6, 0.86, 1), base: (0.18, 0.48, 0.9), deep: (0.05, 0.2, 0.52))
        case .wood: self.init(light: (0.7, 0.95, 0.45), base: (0.22, 0.56, 0.15), deep: (0.07, 0.3, 0.06))
        case .earth: self.init(light: (0.92, 0.76, 0.5), base: (0.66, 0.43, 0.2), deep: (0.36, 0.2, 0.06))
        case .metal: self.init(light: (1, 1, 1), base: (0.72, 0.76, 0.84), deep: (0.38, 0.42, 0.52), engraved: (0.25, 0.29, 0.4))
        case .light: self.init(light: (1, 0.99, 0.8), base: (1, 0.82, 0.25), deep: (0.68, 0.45, 0), engraved: (0.52, 0.32, 0))
        case .dark: self.init(light: (0.8, 0.64, 1), base: (0.48, 0.28, 0.76), deep: (0.2, 0.07, 0.4))
        case .neutral: self.init(light: (1, 1, 1), base: (0.82, 0.84, 0.88), deep: (0.46, 0.49, 0.57), engraved: (0.3, 0.33, 0.4))
        }
    }

    private typealias RGB = (Double, Double, Double)

    private init(light: RGB, base: RGB, deep: RGB, engraved: RGB? = nil) {
        self.light = Self.color(light)
        self.base = Self.color(base)
        self.deep = Self.color(deep)
        // The lower edge leans 40% of the way to the deep tone.
        shade = Self.color((base.0 + (deep.0 - base.0) * 0.4, base.1 + (deep.1 - base.1) * 0.4, base.2 + (deep.2 - base.2) * 0.4))
        ink = engraved.map { Self.color($0) } ?? .white
        inkShadow = engraved == nil ? Self.color(deep) : .white.opacity(0.55)
        inkDrop = engraved == nil ? 1 : 0.75
    }

    private static func color(_ rgb: RGB) -> Color {
        Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

// MARK: - Companions

/// The Companions tab's pages.
private nonisolated enum CompanionsPage: String, CaseIterable {
    /// The monsters you've befriended.
    case companions
    /// Every monster you've met.
    case book

    var title: String {
        switch self {
        case .companions: L("Companions")
        case .book: L("Monster Book")
        }
    }
}

private struct CompanionsTab: View {
    let session: GameSession
    @Binding var page: CompanionsPage
    /// How it works, in a window over the menu (`ExplainWindow`).
    var onExplain: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch page {
            case .companions: companions
            case .book: MonsterBook(session: session)
            }
        }
    }

    private var companions: some View {
        let howItWorks = HowItWorks(L("Companions fight beside you and earn a share of battle EXP. Throw a Seal Stone at a wild monster with Capture to befriend it (up to {count}): any monster, at any HP, but the weaker it is, the better the odds. Each throw uses a stone up, and stronger stones hold more often. Trader Bo in Meadowbrook sells Seal Stones.", ["count": GameSession.maxPets]),
                                    open: session.data.pets.isEmpty, onOpen: onExplain)
        return VStack(alignment: .leading, spacing: 10) {
            if session.data.pets.isEmpty {
                howItWorks
                EmptyNote(L("No companions yet.\nElder Oak in Meadowbrook gives you an egg with the first quest: hatch it from your Bag."))
            }
            // The one you bring along first, laid out like your hero; the rest in cards below.
            let active = session.data.pets.first { $0.id == session.data.activePetID }
            let others = session.data.pets.filter { $0.id != active?.id }
            if let active {
                CompanionCard(session: session, pet: active, featured: true)
                if !others.isEmpty {
                    SectionTitle(text: L("Other companions"), detail: "\(others.count)").padding(.top, 6)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                ForEach(others) { pet in
                    CompanionCard(session: session, pet: pet)
                }
            }
            // The page opens on your companion, as the Hero page opens on your hero; how it works after.
            if !session.data.pets.isEmpty {
                howItWorks.padding(.top, 6)
            }
        }
    }
}

// MARK: - Friends

/// The adventurers you've befriended, and who of them travels with you; the guests in your party
/// (asked along without befriending them) first. The rest found by name, sorted and filtered (the
/// user, 2026-11-11: "add search, sort and filter options at the top. For example filter by
/// online/offline, sort by last seen"); a tap on one shows where they are (`FriendMapWindow`).
private struct FriendsTab: View {
    let session: GameSession
    /// A tap on a friend: where they are, in a window over the menu.
    var onOpen: (Adventurer) -> Void = { _ in }
    /// How it works, in a window over the menu (`ExplainWindow`).
    var onExplain: (String) -> Void = { _ in }
    @State private var search = ""
    @AppStorage("friendSort") private var sort: FriendSort = .online
    @State private var shelf: FriendShelf = .all

    /// Your party: its guests, then your friends in it, in the order you met them.
    private var party: [Adventurer] {
        (session.partyGuests + session.friends).filter { session.isInParty($0) }
    }

    /// Your other friends, as you've narrowed and sorted them. Online first: whoever's near enough
    /// to ask along, then those online elsewhere, then those away; each in the order you met them.
    private var others: [Adventurer] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = session.content
        let found = session.friends.filter { friend in
            guard !session.isInParty(friend) else { return false }
            let online = session.status(of: friend) != .offline
            switch shelf {
            case .all: break
            case .online: if !online { return false }
            case .offline: if online { return false }
            case .nearby: if !online || !session.adventurersAround.contains(friend.id) { return false }
            }
            guard !query.isEmpty else { return true }
            var words = [friend.name, content.race(friend.raceID).name, content.classDef(friend.classID).name]
            if case let .online(mapID) = session.status(of: friend) { words.append(content.map(mapID)?.name ?? "") }
            return words.contains { $0.localizedStandardContains(query) }
        }
        let ordered = Array(found.enumerated())
        switch sort {
        case .met:
            return found
        case .online:
            func rank(_ friend: Adventurer) -> Int {
                if session.adventurersAround.contains(friend.id) { return 0 }
                return session.status(of: friend) == .offline ? 2 : 1
            }
            return ordered.sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
        case .lastSeen:
            // The most recently seen first; those not seen lately last, in the order you met them.
            let seen = Dictionary(uniqueKeysWithValues: found.map { ($0.id, session.lastSeen($0)?.date ?? .distantPast) })
            return ordered.sorted { (seen[$0.element.id] ?? .distantPast, -$0.offset) > (seen[$1.element.id] ?? .distantPast, -$1.offset) }
                .map(\.element)
        case .name:
            return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .level:
            return ordered.sorted { ($0.element.level, -$0.offset) > ($1.element.level, -$1.offset) }.map(\.element)
        }
    }

    var body: some View {
        let howItWorks = HowItWorks(L("Befriend adventurers you meet (walk up to one). Up to {count} friends can travel and fight with you, and they bring their companions. They fight on if you faint, and wait where you fell; a friend who faints wakes up at their own checkpoint. Walk up to them to set off together again.", ["count": GameSession.maxAllies])
                                    + "\n" + L("They don't always say yes, and after a while they head off on their own. You can also ask whoever leads a group of adventurers to let you join them, and follow them about.")
                                    + "\n" + L("You don't have to be friends to party up: invite anyone you meet from their card."),
                                    open: session.friends.isEmpty, onOpen: onExplain)
        let party = self.party
        let others = self.others
        let anyone = !session.friends.isEmpty || !session.partyGuests.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            if !anyone {
                howItWorks
                EmptyNote(L("No friends yet.\nSay hi to the adventurers you meet!"))
            }
            // Grouped (the user, 2026-11-11, on a mock-up: "I like this grouping of content to make
            // everything more scannable"): who travels with you, how many of how many, then the rest.
            if !party.isEmpty {
                SectionTitle(text: L("Party"), detail: "\(party.count)/\(GameSession.maxAllies)")
                GroupedRows(party) { FriendRow(session: session, friend: $0, onOpen: onOpen) }
            }
            // Only with friends not in your party: with all of them in it, a search over none read "No
            // friends match." under the Party group (0.9.78).
            if session.friends.contains(where: { !session.isInParty($0) }) {
                // Named only under a Party to tell them apart; how many is the window title's badge.
                if !party.isEmpty { SectionTitle(text: L("Friends")) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ItemSearchField(text: $search)
                        SortMenu(sort: $sort, options: FriendSort.allCases, title: { $0.title })
                    }
                    // The sort's panel over the chips.
                    .zIndex(1)
                    SideScroll {
                        HStack(spacing: 6) {
                            ForEach(FriendShelf.allCases, id: \.self) { kind in
                                FilterChip(title: kind.title, on: shelf == kind) { shelf = kind }
                            }
                        }
                    }
                }
                // The sort's panel over the friends under it.
                .zIndex(1)
                if others.isEmpty {
                    Text(L("No friends match.")).font(HUDStyle.font(11)).foregroundStyle(HUDStyle.dim)
                } else {
                    GroupedRows(others) { FriendRow(session: session, friend: $0, onOpen: onOpen) }
                }
            }
            // The page opens on your friends; how it works after.
            if anyone {
                howItWorks.padding(.top, 6)
            }
        }
    }
}

/// The Friends window's orders (`FriendsTab`).
private nonisolated enum FriendSort: String, CaseIterable {
    /// Near enough to ask along first, then online elsewhere, then away.
    case online
    /// The most recently online first (`GameSession.lastSeen`).
    case lastSeen
    case name
    /// The highest first.
    case level
    /// The order you met them.
    case met

    var title: String {
        switch self {
        case .online: L("Online first")
        case .lastSeen: L("Last seen")
        case .name: L("Name")
        case .level: L("Level")
        case .met: L("First met")
        }
    }
}

/// Which friends the Friends window shows (`FriendsTab`).
private nonisolated enum FriendShelf: String, CaseIterable {
    /// `nearby`: near enough to ask along (the user, 2026-11-18: a pill of its own, in place of a
    /// Nearby badge on each).
    case all, online, offline, nearby

    var title: String {
        switch self {
        case .all: L("All")
        case .online: L("Online")
        case .offline: L("Offline")
        case .nearby: L("Nearby")
        }
    }
}

/// A friend's row: them and their companion in a column of their own, who they are and where, their
/// status in a badge at the top right (the user, 2026-11-11: "They should have a status badge at the
/// top right of their cards ... more of a gap between the hero + companion on the left and the
/// content"), and what you can do with them under it. A tap shows where they are (`FriendMapWindow`).
private struct FriendRow: View {
    let session: GameSession
    let friend: Adventurer
    let onOpen: (Adventurer) -> Void

    var body: some View {
        let inParty = session.isInParty(friend)
        let pet = friend.petSpecies.flatMap(session.content.monster)
        HStack(alignment: .top, spacing: 16) {
            // Their companion at their feet, in a column as wide for everyone.
            SpriteImage(art: session.artID(for: friend), size: 44)
                .overlay(alignment: .bottomTrailing) {
                    if let pet {
                        SpriteImage(art: pet.art, size: 24).offset(x: 12, y: 4)
                    }
                }
                .frame(width: 56, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.name)
                    NameBadge(badge: .bot)
                }
                Text(L("Lv {level} {race} {class}", ["level": friend.level, "race": session.content.race(friend.raceID).name, "class": session.content.classDef(friend.classID).name]))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.dim)
                // Their companion shows beside them; no line naming it too (the user, 2026-11-19).
                place
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                FriendStatusBadge(session: session, friend: friend)
                action(inParty: inParty)
            }
        }
        .font(HUDStyle.font(12))
        .groupRow()
        .contentShape(Rectangle())
        .onTapGesture {
            SoundEffects.shared.play(.tap, volume: 0.7)
            onOpen(friend)
        }
        .accessibilityAction(named: L("Where they are")) { onOpen(friend) }
    }

    @ViewBuilder
    private func action(inParty: Bool) -> some View {
        if inParty {
            // Theirs to leave, not yours: "Leave" read as you leaving (playtesting 2026-11-01).
            Button(L("Remove")) { session.leaveParty(friend.id) }
                .buttonStyle(PixelButtonStyle(compact: true))
        } else if !session.adventurersAround.contains(friend.id) || session.status(of: friend) == .offline {
            // Friends have to be near you, and online, to join you: where they are says where to find them.
            EmptyView()
        } else if !session.partyIsFull {
            Button(L("Invite")) { session.askAlong(friend.id) }
                .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold, compact: true))
        } else {
            Text(L("Party full"))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
        }
    }

    /// Where they are (the badge says whether they're online): the land they're in, where they wait
    /// for you, or when you last saw them online and where.
    @ViewBuilder
    private var place: some View {
        if let spot = session.whereabouts(of: friend) {
            Text(L("Waiting for you at {map}", ["map": spot]))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.orange)
        } else if !session.isInParty(friend) {
            Text(FriendMapWindow.whereabouts(of: friend, session: session))
                .font(HUDStyle.font(10))
                // Dim whether they're on or not: the ONLINE badge says that already (the user, 2026-11-19).
                .foregroundStyle(HUDStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A friend's status, in a small badge: waiting for you, online or offline. None for one
/// at your side: the Party group says so (the user, 2026-11-11: "The with you labels are not
/// needed").
private struct FriendStatusBadge: View {
    let session: GameSession
    let friend: Adventurer

    private var status: (text: String, color: Color)? {
        if session.isInParty(friend) {
            return session.whereabouts(of: friend) != nil ? (L("Waiting"), HUDStyle.orange) : nil
        }
        // Online or offline only: who's near enough to ask along has the Nearby pill (the user, 2026-11-18).
        return session.status(of: friend) == .offline ? (L("Offline"), HUDStyle.dim) : (L("Online"), HUDStyle.green)
    }

    var body: some View {
        if let status {
            Text(status.text.uppercased())
                .font(HUDStyle.font(9))
                .foregroundStyle(HUDStyle.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(status.color))
                .fixedSize()
        }
    }
}

/// A friend tapped in the Friends window: where they are, on their land's own map, in a window over
/// the list (the user, 2026-11-11: "When you tap on the card it should open a little map preview (in
/// a new modal overlayed) of where they are"). A land's map shows where it lies, not who's where in
/// it, so the mark is at the land's heart; what's under the map says where and when.
struct FriendMapWindow: View {
    let session: GameSession
    let friend: Adventurer
    let onClose: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let overview = WorldOverview.shared

    /// Where they are, in words: in a land now, or last seen there and when.
    static func whereabouts(of friend: Adventurer, session: GameSession) -> String {
        if case let .online(mapID) = session.status(of: friend) {
            return mapID == session.data.mapID ? L("Online here")
                : L("Online in {map}", ["map": session.content.map(mapID)?.name ?? L("somewhere")])
        }
        guard let seen = session.lastSeen(friend) else { return L("Not seen lately") }
        return L("Last seen {time} in {map}", ["time": seen.date.formatted(.relative(presentation: .named).locale(Localizer.shared.locale)),
                                              "map": session.content.map(seen.mapID)?.name ?? L("somewhere")])
    }

    /// The land to show: where they wait, where they are, or where they were last.
    private var mapID: String? {
        if session.isInParty(friend) { return friend.waitingAt?.mapID ?? session.data.mapID }
        if case let .online(mapID) = session.status(of: friend) { return mapID }
        return session.lastSeen(friend)?.mapID
    }

    private var caption: String {
        if let spot = session.whereabouts(of: friend) { return L("Waiting for you at {map}", ["map": spot]) }
        if session.isInParty(friend) { return L("With you in {map}", ["map": session.mapName]) }
        return Self.whereabouts(of: friend, session: session)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                WindowTitle(friend.name, onClose: onClose)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SpriteImage(art: session.artID(for: friend), size: 44)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("Lv {level} {race} {class}", ["level": friend.level, "race": session.content.race(friend.raceID).name, "class": session.content.classDef(friend.classID).name]))
                                .font(HUDStyle.font(11))
                                .foregroundStyle(HUDStyle.dim)
                            Text(caption)
                                .font(HUDStyle.font(12))
                                .foregroundStyle(HUDStyle.cream)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        FriendStatusBadge(session: session, friend: friend)
                    }
                    if let mapID, let def = session.content.map(mapID) {
                        landMap(def)
                            .frame(height: 220)
                        Text(def.name)
                            .font(HUDStyle.font(12))
                            .foregroundStyle(HUDStyle.gold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(HUDStyle.windowInset)
            }
            .frame(maxWidth: 380)
            .gameWindow()
            .popIn()
            .padding(24)
        }
        .foregroundStyle(HUDStyle.cream)
        .accessibilityAction(.escape, onClose)
        .onAppear {
            if let mapID { overview.prepare(first: [mapID]) }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) { pulse = true }
            }
        }
    }

    /// The land's own map (`WorldOverview`, a pixel a cell, north up) fitted in, a dark one only as
    /// far as you've explored it, the mark pulsing at its heart.
    @ViewBuilder
    private func landMap(_ def: MapDef) -> some View {
        let sea = WorldMap.seaColor
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        GeometryReader { proxy in
            let width = CGFloat(max(1, def.width)), height = CGFloat(max(1, def.height))
            let scale = min(proxy.size.width / width, proxy.size.height / height)
            let middle = session.content.regions[def.id]?.middle ?? GridPoint(col: def.width / 2, row: def.height / 2)
            if let image = picture(of: def) {
                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: width * scale, height: height * scale)
                    mark
                        .position(x: (CGFloat(middle.col) + 0.5) * scale, y: (height - CGFloat(middle.row) - 0.5) * scale)
                }
                .frame(width: width * scale, height: height * scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                ProgressView()
                    .tint(HUDStyle.cream)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .background(Color(red: Double(sea.r) / 255, green: Double(sea.g) / 255, blue: Double(sea.b) / 255))
        .clipShape(shape)
        .overlay(shape.strokeBorder(HUDStyle.frameDark.opacity(0.8), lineWidth: 1.5))
        .accessibilityLabel(caption)
    }

    private func picture(of def: MapDef) -> CGImage? {
        guard let image = overview.images[def.id] else { return nil }
        if def.ambience?.darkness != nil,
           let fogged = WorldScene.fog(UIImage(cgImage: image), seen: session.explored(def.id), columns: def.width, rows: def.height).cgImage {
            return fogged
        }
        return image
    }

    private var mark: some View {
        ZStack {
            Circle()
                .stroke(HUDStyle.gold, lineWidth: 2)
                .frame(width: 18, height: 18)
                .scaleEffect(pulse ? 2.2 : 1)
                .opacity(pulse ? 0 : 0.9)
            Circle()
                .fill(HUDStyle.gold)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(HUDStyle.ink, lineWidth: 1.5))
        }
        .accessibilityHidden(true)
    }
}

private struct CompanionCard: View {
    let session: GameSession
    let pet: Pet
    /// The one you bring along, at the top: big, like the hero on the Character screen.
    var featured = false
    @State private var editing = false
    /// On one of the others' cards: its skills open to choose (`SkillChoices`).
    @State private var choosingSkills = false

    /// The gentlest potion in the bag that would wake a fainted companion.
    private var potion: ItemDef? {
        session.content.items
            .filter { $0.type == .consumable && ($0.heal ?? 0) > 0 && session.count(of: $0.id) > 0 }
            .min { ($0.heal ?? 0) < ($1.heal ?? 0) }
    }

    var body: some View {
        let species = session.species(of: pet)
        let stats = session.stats(of: pet)
        let isActive = session.data.activePetID == pet.id
        if editing {
            CompanionEditor(session: session, pet: pet) { editing = false }
        } else if featured {
            overview(species: species, stats: stats, isActive: isActive)
        } else {
            card(species: species, stats: stats, isActive: isActive)
        }
    }

    /// Laid out as the hero's overview is (2026-10-25): the companion in its ring with its skills round
    /// it (`CompanionDoll`, the hero's `PaperDoll`), its name with a pencil to rename it, what it is in
    /// gold where the hero's race and class go (once it has a name of its own), whether it follows you;
    /// its stats beside or under it.
    private func overview(species: MonsterDef?, stats: Stats, isActive: Bool) -> some View {
        AdaptiveStack(spacing: 18) {
            VStack(spacing: 6) {
                CompanionDoll(art: session.artID(for: pet), skills: session.skills(of: pet))
                nameLine(species: species, size: 18)
                if let kind = renamed(species) {
                    Text(kind)
                        .font(HUDStyle.font(12))
                        .foregroundStyle(HUDStyle.gold)
                }
                status(isActive: isActive)
                notes(stats: stats, isActive: isActive, hint: true)
                    .multilineTextAlignment(.center)
                    .frame(width: 220)
            }
            .frame(minWidth: 250)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                StatsPanel(level: L("Level {level}", ["level": pet.level]),
                           exp: pet.exp, expToNext: GameSession.expToNext(level: pet.level), hp: pet.hp, mp: pet.mp, stats: stats,
                           maxed: pet.level >= GameSession.levelCap)
                // Its skills, to learn and raise for its points as your hero's are, and drag about
                // into its battle row's order (playtesting 2026-11-01).
                skillPoints()
                SkillChoices(session: session, owner: pet.id)
            }
        }
    }

    /// Its species' name, when you've named it something else (else the name already says it).
    private func renamed(_ species: MonsterDef?) -> String? {
        guard let species, species.name != pet.name else { return nil }
        return species.name
    }

    /// Its name and element, and the pencil that renames it.
    private func nameLine(species: MonsterDef?, size: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(pet.name)
                .font(HUDStyle.font(size))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let element = species?.element { ElementBadge(element: element) }
            Button { editing = true } label: {
                IconImage(.edit, size: 12)
                    .foregroundStyle(HUDStyle.cream)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Rename"))
        }
    }

    /// Following you, or resting (still your choice: it comes along again once it's healed), in a
    /// pill; or Bring along.
    @ViewBuilder
    private func status(isActive: Bool) -> some View {
        if isActive {
            let resting = pet.hp <= 0
            let tint = resting ? HUDStyle.orange : HUDStyle.green
            Label(resting ? L("Chosen, resting") : L("Following you"), icon: resting ? GameIcon.heart : .checkCircle)
                .font(HUDStyle.font(11))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint.opacity(0.15)))
        } else {
            Button(L("Bring along")) { session.setActivePet(pet.id) }
                .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold, compact: true))
        }
    }

    /// Fainted (and how to heal it), and its toys. `hint`: say a toy from the Bag would do it good
    /// when it has none yet (only on the one you bring along, not on every card).
    @ViewBuilder
    private func notes(stats: Stats, isActive: Bool, hint: Bool) -> some View {
        if pet.hp <= 0 {
            // A fainted companion stays off the map and out of fights until it's healed.
            Text(isActive ? L("Fainted: it can't follow you or fight until it's healed.") : L("Fainted: heal it before it comes along."))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.orange)
                .fixedSize(horizontal: false, vertical: true)
            if let potion {
                Button(L("Give it a {item} ({count} left)", ["item": potion.name, "count": session.count(of: potion.id)])) { session.use(potion.id, onPet: pet.id) }
                    .buttonStyle(PixelButtonStyle(tint: HUDStyle.green, compact: true))
            } else {
                Text(L("No potions in your bag: a healer in town can help."))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.dim)
            }
        }
        // Toys it has played with, and what they've added for good.
        if let toys = pet.toys, toys > 0 {
            Text(L("Toys {count}/{max}: {bonus}", ["count": toys, "max": GameSession.toysPerCompanion, "bonus": (pet.toyStats ?? .zero).bonusSummary]))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
        } else if hint, !session.bagToys.isEmpty {
            Text(L("Give it a toy from your Bag."))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Its skill points to spend, in gold (none: nothing shown).
    @ViewBuilder
    private func skillPoints() -> some View {
        let points = session.unspentSkillPoints(of: pet)
        if points > 0 {
            Text(points == 1 ? L("1 skill point to spend") : L("{count} skill points to spend", ["count": points]))
                .font(HUDStyle.font(11))
                .foregroundStyle(HUDStyle.gold)
        }
    }

    /// What it can do in a fight, a chip each, in your order: held and dragged onto another, a chip
    /// takes its place (`GameSession.moveSkill(_:onto:of:)`).
    @ViewBuilder
    private func chips() -> some View {
        let skills = session.skills(of: pet)
        if !skills.isEmpty {
            WrapRows(spacing: 6) {
                ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                    HStack(spacing: 4) {
                        SkillIcon(skill: skill, size: 18)
                        Text(skill.name)
                            .font(HUDStyle.font(10))
                            .foregroundStyle(HUDStyle.cream)
                            .lineLimit(1)
                    }
                    .padding(.leading, 3)
                    .padding(.trailing, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.07)))
                    .contentShape(Capsule())
                    .draggable(skill.id) { SkillIcon(skill: skill, size: 28) }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let id = ids.first else { return false }
                        return moveSkill(id, onto: skill.id)
                    }
                    .accessibilityAction(named: L("Move earlier")) {
                        if index > 0 { moveSkill(skill.id, onto: skills[index - 1].id) }
                    }
                    .accessibilityAction(named: L("Move later")) {
                        if index + 1 < skills.count { moveSkill(skill.id, onto: skills[index + 1].id) }
                    }
                }
            }
        }
    }

    @discardableResult
    private func moveSkill(_ id: String, onto target: String) -> Bool {
        let moved = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { session.moveSkill(id, onto: target, of: pet.id) }
        if moved { session.save() }
        return moved
    }

    /// One of the others: its face, its name (and pencil) over what it is and its level, its HP
    /// and EXP, its stats in a line, its skills, and Bring along.
    @ViewBuilder
    private func card(species: MonsterDef?, stats: Stats, isActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SpriteImage(art: session.artID(for: pet), size: 64)
                .background(Circle().fill(.white.opacity(0.06)))
            VStack(alignment: .leading, spacing: 5) {
                nameLine(species: species, size: 14)
                Text(renamed(species).map { L("{species} · Lv {level}", ["species": $0, "level": pet.level]) } ?? L("Lv {level}", ["level": pet.level]))
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.gold)
                StatBar(label: L("HP"), value: pet.hp, maximum: stats.hp, color: HUDStyle.hp)
                StatBar(label: L("EXP"), value: pet.exp, maximum: GameSession.expToNext(level: pet.level), color: HUDStyle.exp)
                Text(L("ATK {attack} · DEF {defense} · MAG {magic} · SPD {speed}", ["attack": stats.attack, "defense": stats.defense, "magic": stats.magic, "speed": stats.speed]))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.dim)
                notes(stats: stats, isActive: isActive, hint: false)
                chips()
                skillPoints()
                // Its skills open here to choose, as the one you bring along has them.
                if !session.offeredSkills(of: pet).isEmpty {
                    Button(choosingSkills ? L("Done") : L("Choose skills")) {
                        withAnimation(.easeOut(duration: 0.2)) { choosingSkills.toggle() }
                    }
                    .buttonStyle(PixelButtonStyle(tint: session.unspentSkillPoints(of: pet) > 0 ? HUDStyle.gold : HUDStyle.cream, compact: true))
                }
                if choosingSkills {
                    SkillChoices(session: session, owner: pet.id)
                }
                status(isActive: isActive)
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // On a plate sunk into the glass, as every group is (`GlassCard`); green round the one with you.
        .background(
            GlassCard(lit: isActive)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? HUDStyle.green.opacity(0.7) : .clear, lineWidth: 2))
        )
    }
}

// MARK: - Bag

/// Everything you carry in one grid of slots, like an adventurer's pack: potions and other things to
/// use, spare gear, and materials, each with how many you have, in your order. A tap opens the item's
/// card, with Drop, Trade and the button to use, give, hatch or wear it; holding one lifts it to drop
/// it onto another, whose place it takes (`ItemSlotGrid`, your order of the bag). Search, sort and pick the
/// kinds to show at the top; gear better than what you wear has the gold upgrade arrow.
private struct BagTab: View {
    let session: GameSession
    @Binding var note: String?
    /// An egg chosen on its card: it hatches here.
    @Binding var hatchRequest: ItemDef?
    /// A tap on an item: MenuView shows its card.
    let onInspect: (ItemDef) -> Void
    /// A long press on an item: its main action, if it has one there and then (`MenuView.quickAction`).
    let quickAction: (ItemDef) -> ItemInfoCard.Action?
    @State private var hatched: Pet?
    @State private var hatching = false
    @State private var search = ""
    @AppStorage("bagSort") private var sort: ItemSort = .standard
    @State private var shelf: Shelf = .all
    /// Only the gear you can put on now (your class's, at your level).
    @AppStorage("bagWearableOnly") private var wearableOnly = false

    /// Which kinds of thing the Bag shows.
    private typealias Shelf = ItemShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // How full the bag is shows by the window's title (`MenuView.tabs`); here, when it's full,
            // what's up for trade (the coin on its slot), and what the last thing used did. Not the coins
            // you carry: the HUD shows them (the user, 2026-11-16: "We don't need to show the money here").
            let full = session.bagSlotsFree == 0
            if full || !session.forTrade.isEmpty || note != nil {
                HStack {
                    if full {
                        Text(L("Full: bank something")).foregroundStyle(HUDStyle.orange)
                    }
                    if !session.forTrade.isEmpty {
                        Label(L("{count} for trade", ["count": session.forTrade.count]), icon: .coins)
                            .foregroundStyle(HUDStyle.gold)
                    }
                    Spacer()
                    if let note { Text(note).foregroundStyle(HUDStyle.green) }
                }
                .font(HUDStyle.font(12))
            }

            if hatching, let pet = hatched {
                HatchView(session: session, pet: pet) { hatching = false }
            }

            finder
                .zIndex(1)
            // One grid for every kind of thing, in your order (playtesting 2026-10-26: "The Items,
            // Equipment and Materials sections should not exist, it's all the same"); the chips narrow it.
            let searching = !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || wearableOnly
            let kinds = session.bagItems.filter { item in
                shelf.holds(item) && (!wearableOnly || (ItemType.equipmentSlots.contains(item.type) && session.equipIssue(item) == nil))
            }
            let shown = ItemFinder.arrange(kinds, search: search, sort: sort, session: session)
            // Unfiltered, the room left after them too, a faint empty slot for each free one (the user's UI
            // review, 2026-11-19: "17/59" over 17 tiles and a sheet of empty glass).
            let room = !searching && shelf == .all ? session.bagSlotsFree : 0
            if shown.isEmpty {
                EmptyNote(searching || shelf != .all ? L("Nothing in your bag matches.") : L("Your bag is empty."), size: 11)
                    .padding(.vertical, 12)
            }
            if !shown.isEmpty || room > 0 {
                grid(shown, room: room)
            }
        }
        .onChange(of: hatchRequest?.id) { _, id in
            guard let id else { return }
            hatchRequest = nil
            hatching = true
            hatched = session.hatch(id)
            if hatched == nil, session.data.pets.count >= GameSession.maxPets {
                note = L("No room: you have {count} companions.", ["count": GameSession.maxPets])
            }
            session.save()
        }
    }

    /// Search, sort, and the kinds to show (and only gear you can wear).
    private var finder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ItemSearchField(text: $search)
                ItemSortMenu(sort: $sort, options: ItemSort.allCases)
            }
            // The sort's panel over the chips.
            .zIndex(1)
            SideScroll {
                HStack(spacing: 6) {
                    ForEach(Shelf.allCases, id: \.self) { kind in
                        FilterChip(title: kind.title, on: shelf == kind) { shelf = kind }
                    }
                    FilterChip(title: L("Can wear"), on: wearableOnly) { wearableOnly.toggle() }
                }
            }
        }
    }

    /// Puts what was dragged where `target` is; sorted another way, the order you see is yours from
    /// then on, so the sort goes back to your order.
    private func move(_ id: String, onto target: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            guard session.moveItem(id, onto: target, on: .bag, sortedBy: sort) else { return }
            sort = .standard
        }
        session.save()
    }

    /// One slot per kind of item, its count in the corner from two up, the upgrade arrow on gear
    /// better than what you wear, gear you can't wear yet (too low a level, another class's) faded,
    /// and a coin on what's up for trade; then `room` empty slots, one for each free slot. Held,
    /// gear you can wear goes on and a potion is drunk (`quickAction`), as their card's button does.
    private func grid(_ items: [ItemDef], room: Int) -> some View {
        ItemSlotGrid(items: items,
                     label: { item in
                         let count = session.count(of: item.id)
                         let name = count > 1 ? L("{item}, {count}", ["item": item.name, "count": count]) : item.name
                         return session.isForTrade(item.id) ? name + ", " + L("For trade") : name
                     },
                     hint: L("Shows what it does and who can use it"),
                     emptySlots: room,
                     onTap: onInspect,
                     onMove: { move($0, onto: $1) },
                     onHold: { item in quickAction(item)?.run() },
                     holdLabel: { quickAction($0)?.title },
                     tile: { item, size in
                         let wearable = !ItemType.equipmentSlots.contains(item.type) || session.equipIssue(item) == nil
                         ItemIcon(item: item, size: size - 5, count: session.count(of: item.id), upgrade: session.isUpgrade(item))
                             .opacity(wearable ? 1 : 0.45)
                             .overlay(alignment: .bottomLeading) {
                                 if session.isForTrade(item.id) {
                                     IconImage(.coins, size: 11)
                                         .padding(2)
                                         .background(Circle().fill(HUDStyle.ink.opacity(0.75)))
                                 }
                             }
                             .padding(.top, 5)
                             .padding(.trailing, 5)
                     })
    }
}

/// The egg wobbles, cracks, and your first companion pops out.
private struct HatchView: View {
    let session: GameSession
    let pet: Pet
    let onDone: () -> Void
    @State private var stage = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if stage < 2 {
                    SpriteImage(art: "pet_egg", size: 90)
                        .rotationEffect(.degrees(stage == 1 ? 12 : -12))
                        .animation(.easeInOut(duration: 0.12).repeatCount(8, autoreverses: true), value: stage)
                } else {
                    SpriteImage(art: session.artID(for: pet), size: 110)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                    IconImage(.sparkles, size: 40)
                        .foregroundStyle(HUDStyle.gold)
                        .offset(x: 44, y: -40)
                }
            }
            .frame(height: 120)
            Text(stage < 2 ? L("Something is hatching…") : L("{name} hatched! Your first companion.", ["name": pet.name]))
                .font(HUDStyle.font(14))
                .foregroundStyle(HUDStyle.gold)
            if stage >= 2 {
                Button(L("Hello, {name}!", ["name": pet.name]), action: onDone)
                    .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(GlassCard(radius: 12))
        .task {
            stage = 1
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { stage = 2 }
        }
    }
}

// MARK: - Quests

/// The Quests tab's two pages. Nonisolated like the other enums shown with `ForEach(id: \.self)`.
private nonisolated enum QuestsPage: String, CaseIterable {
    /// The quests people have given you, active and finished.
    case quests
    /// The day's bounties, their bonus and the daily gift.
    case daily

    var title: String {
        switch self {
        case .quests: L("Quests")
        case .daily: L("Daily challenges")
        }
    }
}

/// How the Quests list is ordered. Nonisolated like the other enums shown with `ForEach(id: \.self)`.
private nonisolated enum QuestSort: String, CaseIterable {
    /// The one you took (or finished) last first.
    case newest
    /// By number: the order they come in, land by land.
    case number
    /// Ready to hand in first, then the nearest to done.
    case progress
    /// By where whoever gave it lives, then by number.
    case place
    /// The most EXP first.
    case exp
    /// The hardest first (`GameSession.difficulty(of:)`).
    case difficulty

    var title: String {
        switch self {
        case .newest: L("Newest")
        case .number: L("Number")
        case .progress: L("Nearest done")
        case .place: L("Place")
        case .exp: L("Most EXP")
        case .difficulty: L("Hardest")
        }
    }
}

/// Which quests the list shows.
private nonisolated enum QuestShelf: String, CaseIterable {
    case all, ready, going, done

    var title: String {
        switch self {
        case .all: L("All")
        case .ready: L("Ready")
        case .going: L("In progress")
        case .done: L("Completed")
        }
    }
}

private struct QuestsTab: View {
    let session: GameSession
    @Binding var page: QuestsPage
    /// A tap on a quest: its window, over the menu (`QuestWindow`).
    var onOpen: (QuestDef) -> Void = { _ in }
    /// Finding a quest (playtesting 2026-10-18): what you typed, the order, which ones, and only
    /// those given in the land you're in.
    @State private var search = ""
    @AppStorage("questSort") private var sort: QuestSort = .newest
    @State private var shelf: QuestShelf = .all
    @State private var hereOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch page {
            case .quests:
                questList
            case .daily:
                BountiesSection(session: session)
            }
        }
    }

    /// The search, the order and the chips, then the active quests and the finished ones as they
    /// narrow them down.
    @ViewBuilder
    private var questList: some View {
        let numbers = Dictionary(session.content.quests.enumerated().map { ($0.element.id, $0.offset + 1) }) { first, _ in first }
        let active: [QuestDef] = shelf == .done ? [] : arrange(session.activeQuests, numbers: numbers).filter { quest in
            let ready = session.status(of: quest) == .ready
            return shelf == .ready ? ready : shelf == .going ? !ready : true
        }
        let completed: [QuestDef] = shelf == .all || shelf == .done ? arrange(session.completedQuests, numbers: numbers) : []
        VStack(alignment: .leading, spacing: 8) {
            // How far through the game's quests you are, as the Monster Book counts its monsters.
            Text(L("Completed {count} of {total} quests", ["count": session.completedQuests.count, "total": session.content.quests.count]))
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.gold)
            // Sort as the Bag's is: the panel in the HUD menu's look, no system menu.
            HStack(spacing: 8) {
                ItemSearchField(text: $search)
                SortMenu(sort: $sort, options: QuestSort.allCases, title: { $0.title })
            }
            // The sort's panel over the chips.
            .zIndex(1)
            SideScroll {
                HStack(spacing: 6) {
                    ForEach(QuestShelf.allCases, id: \.self) { kind in
                        FilterChip(title: kind.title, on: shelf == kind) { shelf = kind }
                    }
                    FilterChip(title: L("This land"), on: hereOnly) { hereOnly.toggle() }
                }
            }
        }
        // The sort's panel over the quests under it.
        .zIndex(1)
        if shelf != .done {
            SectionTitle(text: L("Active"), detail: active.isEmpty ? nil : "\(active.count)")
            if session.activeQuests.isEmpty {
                EmptyNote(L("No active quests. Elder Oak in Meadowbrook always needs help."))
            } else if active.isEmpty {
                Text(L("No quests match.")).font(HUDStyle.font(11)).foregroundStyle(HUDStyle.dim)
            } else {
                GroupedRows(active) { QuestListRow(session: session, quest: $0, onOpen: onOpen) }
            }
        }
        if !completed.isEmpty || shelf == .done {
            SectionTitle(text: L("Completed"), detail: completed.isEmpty ? nil : "\(completed.count)")
            if completed.isEmpty {
                Text(L("No quests match.")).font(HUDStyle.font(11)).foregroundStyle(HUDStyle.dim)
            } else {
                GroupedRows(completed) { QuestListRow(session: session, quest: $0, onOpen: onOpen) }
            }
        }
    }

    /// `quests` narrowed to those that hold what you typed (in the title, the story, who gave it or
    /// where they live, or its number), and to this land's if you asked, in the order chosen. Ties
    /// keep the order they came in (the newest first).
    private func arrange(_ quests: [QuestDef], numbers: [String: Int]) -> [QuestDef] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = query.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let found = quests.filter { quest in
            let home = session.content.home(ofNPC: quest.giver)
            if hereOnly, home?.id != session.data.mapID { return false }
            guard !query.isEmpty else { return true }
            if let number = numbers[quest.id], String(number) == digits { return true }
            let giver = session.content.npc(quest.giver)?.name ?? ""
            return [quest.title, quest.description, giver, home?.name ?? ""].contains { $0.localizedStandardContains(query) }
        }
        let number = { (quest: QuestDef) in numbers[quest.id] ?? 0 }
        switch sort {
        case .newest:
            return found
        case .number:
            return found.sorted { number($0) < number($1) }
        case .place:
            let place = { (quest: QuestDef) in session.content.home(ofNPC: quest.giver)?.name ?? "" }
            return found.sorted {
                let order = place($0).localizedStandardCompare(place($1))
                return order == .orderedSame ? number($0) < number($1) : order == .orderedAscending
            }
        case .progress, .exp, .difficulty:
            let value: (QuestDef) -> Double
            if sort == .exp {
                value = { Double(session.questPay($0).exp) }
            } else if sort == .difficulty {
                value = { Double(session.difficulty(of: $0).rawValue) }
            } else {
                value = { quest in
                    switch session.status(of: quest) {
                    case .ready: return 2
                    case .active(let progress, let goal): return Double(progress) / Double(max(goal, 1))
                    default: return 0
                    }
                }
            }
            return found.enumerated()
                .map { (quest: $0.element, place: $0.offset, value: value($0.element)) }
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.place < $1.place }
                .map { $0.quest }
        }
    }
}

struct QuestRow: View {
    let session: GameSession
    let quest: QuestDef
    /// Who asked and where they live (the Quests list; not while you're talking to them).
    /// In the list a tap also shows the reward in full.
    var showsGiver = false
    /// Its story (not on the last page of a conversation with its giver, who's just told it).
    var showsDescription = true
    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsGiver {
                GiverFace(npcID: quest.giver, size: 44)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    QuestNumber(number: session.questNumber(quest))
                    Text(quest.title).font(HUDStyle.font(13))
                    // How hard it is, in the Quests list only (playtesting 2026-10-25), not as its giver offers it.
                    if showsGiver {
                        DifficultyBadge(difficulty: session.difficulty(of: quest))
                    }
                    Spacer(minLength: 0)
                    // Only a count beside its name; anything in words goes under it, on a line of
                    // its own: side by side a long name and "Done! Report back" each broke in two
                    // (the user, 2026-11-17: "These quest cards look a mess").
                    if case .active(let progress, let goal) = session.status(of: quest), quest.objective.type != .deliver {
                        Text("\(progress)/\(goal)").foregroundStyle(HUDStyle.gold).monospacedDigit().fixedSize()
                    }
                }
                .font(HUDStyle.font(12))
                switch session.status(of: quest) {
                case .active where quest.objective.type == .deliver:
                    // A favour: who it's for, as there's nothing to count.
                    Text(L("Take it to {name}", ["name": quest.objective.target.flatMap(session.content.npc)?.name ?? ""]))
                        .font(HUDStyle.font(11))
                        .foregroundStyle(HUDStyle.gold)
                case .ready:
                    Text(L("Done! Report back")).font(HUDStyle.font(11)).foregroundStyle(HUDStyle.green)
                default: EmptyView()
                }
                if showsGiver, let giver = session.content.npc(quest.giver) {
                    let home = session.content.home(ofNPC: quest.giver)?.name
                    Text(home.map { L("From {name} · {place}", ["name": giver.name, "place": $0]) } ?? L("From {name}", ["name": giver.name]))
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.gold.opacity(0.85))
                }
                if showsDescription {
                    Text(quest.description).font(HUDStyle.body(11)).foregroundStyle(HUDStyle.dim)
                }
                if showsGiver && expanded {
                    QuestRewardsView(session: session, quest: quest, earned: false)
                        .padding(.top, 4)
                        .transition(.reveal)
                } else {
                    QuestRewardLine(session: session, quest: quest, more: showsGiver)
                        .padding(.top, 2)
                        .transition(.opacity)
                }
            }
        }
        // Gold when it's done, waiting for you to report back.
        .rowCard(lit: expanded, gold: isReady)
        .contentShape(Rectangle())
        .onTapGesture {
            guard showsGiver else { return }
            withAnimation(Reveal.animation) { expanded.toggle() }
        }
        .accessibilityAddTraits(showsGiver ? .isButton : [])
        .accessibilityHint(showsGiver ? (expanded ? L("Hides the reward") : L("Shows the reward")) : "")
    }

    private var isReady: Bool {
        if case .ready = session.status(of: quest) { return true }
        return false
    }
}

/// How hard a quest is (`QuestDifficulty`): its name in a little pill, from green for easy to red
/// for elite, with as many pips as its rank.
struct DifficultyBadge: View {
    let difficulty: QuestDifficulty

    var body: some View {
        HStack(spacing: 3) {
            HStack(spacing: 1.5) {
                ForEach(1...4, id: \.self) { rank in
                    Circle()
                        .fill(rank <= difficulty.rawValue ? color : color.opacity(0.25))
                        .frame(width: 4, height: 4)
                }
            }
            Text(difficulty.title)
        }
        .font(HUDStyle.font(9))
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.16)))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Difficulty: {level}", ["level": difficulty.title]))
    }

    private var color: Color {
        switch difficulty {
        case .easy: HUDStyle.green
        case .normal: HUDStyle.gold
        case .hard: HUDStyle.orange
        case .elite: Color(red: 0.95, green: 0.36, blue: 0.4)
        }
    }
}

/// A quest's number (`GameSession.questNumber`), small and gold before its title.
private struct QuestNumber: View {
    let number: Int

    var body: some View {
        Text(L("#{number}", ["number": number]))
            .font(HUDStyle.mono(10))
            .foregroundStyle(HUDStyle.gold.opacity(0.85))
            .accessibilityLabel(L("Quest {number}", ["number": number]))
    }
}

/// A quest in the Quests list: its number, small, over its name, and nothing else (the user,
/// 2026-11-11: "The quest items show too much information. It should just show the name of the
/// quest, with the number as a small label above it. Then when you tap on it, it shows a new modal
/// with a back button that shows more of the story and the rewards"), beside the round face of who
/// asked. Gold when it's done and waiting
/// for you to report back; dim once it's finished. A tap opens it (`QuestWindow`).
private struct QuestListRow: View {
    let session: GameSession
    let quest: QuestDef
    let onOpen: (QuestDef) -> Void

    var body: some View {
        let status = session.status(of: quest)
        let finished = status == .completed
        Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            onOpen(quest)
        } label: {
            HStack(spacing: 10) {
                // Who asked, in their round portrait (the user, 2026-11-11: "The quest list should
                // still show the circle avatar of the character, so it's nicer to look at"), faded
                // with the rest of the row once it's done.
                GiverFace(npcID: quest.giver, size: 40)
                    .opacity(finished ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    QuestNumber(number: session.questNumber(quest))
                    Text(quest.title)
                        .font(HUDStyle.font(13))
                        .foregroundStyle(finished ? HUDStyle.dim : HUDStyle.cream)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    progress(status)
                }
                Spacer(minLength: 6)
                if finished {
                    IconImage(.badgeCheck, size: 14).foregroundStyle(HUDStyle.green)
                } else if session.isTracked(quest) {
                    // Followed on the HUD (Track, in its window).
                    IconImage(.map, size: 14).foregroundStyle(HUDStyle.gold)
                        .accessibilityLabel(L("Tracked"))
                }
                IconImage(.chevronDown, size: 14)
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(HUDStyle.dim)
            }
            .groupRow(gold: status == .ready)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(status == .ready ? L("Done! Report back") : finished ? L("Completed") : "")
        .accessibilityHint(L("Shows its story and rewards"))
    }

    /// How far along an active quest is, under its name, so you needn't open each (the user's UI
    /// review, 2026-11-19): a thin bar and its count, who to take it to, or that it's done.
    @ViewBuilder
    private func progress(_ status: GameSession.QuestStatus) -> some View {
        switch status {
        case .active where quest.objective.type == .deliver:
            Text(L("Take it to {name}", ["name": quest.objective.target.flatMap(session.content.npc)?.name ?? ""]))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.gold)
                .fixedSize(horizontal: false, vertical: true)
        case .active(let done, let goal):
            HStack(spacing: 6) {
                GlossyBar(fraction: CGFloat(done) / CGFloat(max(goal, 1)), color: HUDStyle.gold, height: GlossyBar.progress)
                    .frame(maxWidth: 140)
                Text(verbatim: "\(done)/\(goal)")
                    .font(HUDStyle.font(10))
                    .monospacedDigit()
                    .foregroundStyle(HUDStyle.gold)
                    .fixedSize()
            }
            .padding(.top, 2)
        case .ready:
            Text(L("Done! Report back"))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.green)
        default:
            EmptyView()
        }
    }
}

/// A quest from the Quests list, in a window of its own over the menu, its name on the title bar and
/// the close button over the corner: its number and how hard it is, who asked and where they live, how far along you are, all of
/// its story, and its rewards (what you earned, once it's done). A tap outside it goes back too.
struct QuestWindow: View {
    let session: GameSession
    let quest: QuestDef
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onBack)
            VStack(alignment: .leading, spacing: 0) {
                // Its name on the bar and the close button over the corner, as every window has (the
                // user, 2026-11-19: a close button at the top right, not a Back button).
                WindowTitle(quest.title)
                // Scrolls only when it can't all fit (a phone on its side, a long story).
                FitOrScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        progress
                        follow
                        Text(quest.description)
                            .font(HUDStyle.body(12))
                            .foregroundStyle(HUDStyle.cream)
                            .fixedSize(horizontal: false, vertical: true)
                        // The section's title says which: what it pays, or what you earned.
                        let earned = session.status(of: quest) == .completed
                        SectionTitle(text: earned ? L("You earned") : L("Rewards"))
                        QuestRewardsView(session: session, quest: quest, earned: earned, heading: false)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            .gameWindow()
            .windowCloseButton(onBack)
            .padding(24)
            .popIn()
        }
        .foregroundStyle(HUDStyle.cream)
        .accessibilityAction(.escape, onBack)
    }

    /// Its number and how hard it is, its name, and who asked and where they live.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                QuestNumber(number: session.questNumber(quest))
                DifficultyBadge(difficulty: session.difficulty(of: quest))
            }
            if let giver = session.content.npc(quest.giver) {
                let home = session.content.home(ofNPC: quest.giver)?.name
                HStack(spacing: 8) {
                    GiverFace(npcID: quest.giver, size: 32)
                    Text(home.map { L("From {name} · {place}", ["name": giver.name, "place": $0]) } ?? L("From {name}", ["name": giver.name]))
                        .font(HUDStyle.font(11))
                        .foregroundStyle(HUDStyle.gold.opacity(0.85))
                }
            }
        }
    }

    /// While you're on it, Track (one quest followed on the HUD, under the minimap, at a time); and Show
    /// on map, the world map opening on where it's done (`GameSession.questPlace`): where its monsters
    /// live, who to take it to, else and once it's ready, where its giver lives. Side by side, or one
    /// over the other where they don't fit (a narrow phone, a long language).
    @ViewBuilder
    private var follow: some View {
        let onIt = session.data.quests[quest.id]?.state == .active
        let mappable = session.onShowMap != nil && session.questPlace(of: quest) != nil
        if onIt || mappable {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    if mappable { mapButton }
                    if onIt { trackSwitch.fixedSize() }
                }
                VStack(alignment: .leading, spacing: 10) {
                    if onIt { trackSwitch }
                    if mappable { mapButton }
                }
            }
        }
    }

    /// Track: this quest's next step on the HUD, in place of the one followed before.
    private var trackSwitch: some View {
        Toggle(isOn: Binding(get: { session.isTracked(quest) }, set: { on in
            SoundEffects.shared.play(.tap, volume: 0.7)
            session.track(quest, on)
            session.save()
        })) {
            Text(L("Track"))
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.cream)
                .lineLimit(1)
                .fixedSize()
        }
        .toggleStyle(PixelSwitchStyle())
        .accessibilityHint(L("Shows its next step under the minimap"))
    }

    private var mapButton: some View {
        Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            session.mapFocus = session.questPlace(of: quest)
            session.onShowMap?()
        } label: {
            Label(L("Show on map"), icon: .map, size: 12)
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(PixelButtonStyle(compact: true))
        .accessibilityHint(L("Opens the world map where it's done"))
    }

    /// How far along it is: a count and a bar, who to take it to, ready to report, or done.
    @ViewBuilder
    private var progress: some View {
        switch session.status(of: quest) {
        case .active where quest.objective.type == .deliver:
            Text(L("Take it to {name}", ["name": quest.objective.target.flatMap(session.content.npc)?.name ?? ""]))
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.gold)
        case .active(let done, let goal):
            HStack(spacing: 8) {
                GlossyBar(fraction: CGFloat(done) / CGFloat(max(goal, 1)), color: HUDStyle.gold, height: GlossyBar.progress)
                Text("\(done)/\(goal)")
                    .font(HUDStyle.font(12))
                    .monospacedDigit()
                    .foregroundStyle(HUDStyle.gold)
            }
        case .ready:
            Text(L("Done! Report back"))
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.green)
        case .completed:
            Label(L("Completed"), icon: .badgeCheck, size: 12)
                .font(HUDStyle.font(12))
                .foregroundStyle(HUDStyle.green)
        default:
            EmptyView()
        }
    }
}

/// What a quest pays at your level, on one line like a bounty's: gold, EXP and the items' icons,
/// onto a second line when there are more than fit (playtesting 2026-10-16: the Hundred-Toy Shelf's
/// six toys squeezed its gold and EXP into a column of single letters). `more`: a chevron says a
/// tap shows it all (item names, roads it opens).
struct QuestRewardLine: View {
    let session: GameSession
    let quest: QuestDef
    var more = false

    var body: some View {
        let pay = session.questPay(quest)
        let items = RewardList.group(quest.reward.items ?? [], in: session)
        HStack(alignment: .top, spacing: 4) {
            // What it pays in numbers on one row, the things it gives on a row of their own under
            // it: run together, six icons broke after the fourth beside "+1 skill point".
            VStack(alignment: .leading, spacing: 6) {
                WrapRows(spacing: 10) {
                    if pay.gold > 0 {
                        GoldPill(amount: pay.gold, size: 11)
                            .frame(height: 22)
                    }
                    if pay.exp > 0 {
                        // Its thousands set off as the gold's are.
                        Label(L("{exp} EXP", ["exp": pay.exp.formatted()]), icon: .star, size: 12)
                            .frame(height: 22)
                    }
                    // A Hard or Elite quest gives a skill point (`GameSession.givesSkillPoint`).
                    if session.givesSkillPoint(quest) {
                        Label(L("+1 skill point"), icon: .sparkles, size: 12)
                            .frame(height: 22)
                    }
                }
                if !items.isEmpty {
                    WrapRows(spacing: 6) {
                        ForEach(items, id: \.item.id) { entry in
                            ItemIcon(item: entry.item, size: 20, count: entry.count)
                                .frame(height: 22)
                                .accessibilityLabel(entry.item.name)
                        }
                    }
                }
            }
            if more {
                Spacer(minLength: 4)
                IconImage(.chevronDown, size: 14)
            }
        }
        .font(HUDStyle.font(10))
        .foregroundStyle(HUDStyle.dim)
    }
}

/// What a quest pays: gold, EXP, items (with their icons) and roads it opens.
/// `earned` words it for a quest you've finished, with what it really paid.
struct QuestRewardsView: View {
    let session: GameSession
    let quest: QuestDef
    let earned: Bool
    /// Its own small heading (Reward, You earned); off under a `SectionTitle` that already says it
    /// (`QuestWindow`).
    var heading = true

    private struct RewardItem: Identifiable {
        let item: ItemDef
        var count: Int
        var id: String { item.id }
    }

    /// Items in reward order, repeats counted ("Potion ×2").
    private var items: [RewardItem] {
        var result: [RewardItem] = []
        for id in quest.reward.items ?? [] {
            guard let item = session.content.item(id) else { continue }
            if let index = result.firstIndex(where: { $0.id == id }) {
                result[index].count += 1
            } else {
                result.append(RewardItem(item: item, count: 1))
            }
        }
        return result
    }

    /// The caves it gives you the whole map of (`MapDef.chart`), each by its own name, not its
    /// levels'.
    private var charts: [String] {
        session.content.maps.filter { $0.chart == quest.id && $0.depth == nil }.map(\.name)
    }

    private var roads: [String] {
        let content = session.content
        return content.maps.flatMap { map in
            map.exits.filter { $0.requires == quest.id }.map { "\(map.name) → \(content.map($0.to)?.name ?? $0.to)" }
        }
    }

    var body: some View {
        let pay = earned ? session.paid(for: quest) : session.questPay(quest)
        VStack(alignment: .leading, spacing: 6) {
            if heading {
                Text(earned ? L("You earned") : L("Reward"))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.gold)
            }
            // A label that doesn't fit moves whole onto the next row, never breaking inside itself (the
            // user, 2026-11-11: "+1 skill point" wrapped onto two lines beside the EXP).
            WrapRows(spacing: 12) {
                if pay.gold > 0 {
                    GoldPill(amount: pay.gold, size: 13)
                        .frame(height: 28)
                }
                if pay.exp > 0 {
                    Label(L("{exp} EXP", ["exp": pay.exp]), icon: .star, size: 14)
                        .frame(height: 28)
                }
                if session.givesSkillPoint(quest) {
                    Label(L("+1 skill point"), icon: .sparkles, size: 14)
                        .frame(height: 28)
                }
            }
            .font(HUDStyle.font(12))
            .foregroundStyle(HUDStyle.cream)
            ForEach(items) { entry in
                HStack(spacing: 6) {
                    ItemIcon(item: entry.item, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.count > 1 ? "\(entry.item.name) ×\(entry.count)" : entry.item.name)
                            .font(HUDStyle.font(11))
                            .foregroundStyle(HUDStyle.cream)
                        // A quest treasure: what it is, since you can't see one anywhere else first.
                        if session.content.isQuestTreasure(entry.item.id) {
                            Text(L("Quest treasure") + " · " + ItemInfoCard.summary(of: entry.item))
                                .font(HUDStyle.font(9))
                                .foregroundStyle(HUDStyle.gold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            ForEach(charts, id: \.self) { place in
                Label(L("A map of the {place}: every level of it on your minimap"), icon: .map, size: 14)
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.cream)
            }
            ForEach(roads, id: \.self) { road in
                Label(earned ? L("Opened the road {road}", ["road": road]) : L("Opens the road {road}", ["road": road]), icon: .map, size: 14)
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.cream)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(HUDStyle.ink.opacity(0.35)))
    }
}

/// The quest giver's face in a little round frame, so you remember who asked.
struct GiverFace: View {
    let npcID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let npc = Content.shared.npc(npcID) {
                Image(uiImage: ArtLibrary.shared.face(npc.art))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(HUDStyle.portrait.opacity(0.9)))
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(HUDStyle.bevel, lineWidth: size > 30 ? 2 : 1.5))
    }
}
