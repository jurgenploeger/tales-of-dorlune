import SwiftUI

/// The day's gift, the first time you're in the game that day: what it held, and where the round is,
/// as a card for each day of it (`GiftDays`). On Thanks, what it held flies off toward the Bag's
/// button at the bottom right before the card closes (`flight`), unless Reduce Motion is on.
struct DailyGiftCard: View {
    let session: GameSession
    let gift: GameSession.DailyGift
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where each of the gift's items stands on screen, for its flight to the Bag.
    @State private var spots: [String: CGRect] = [:]
    /// Thanks tapped: the items' copies are up over the card, the card fading.
    @State private var flying = false
    /// The copies on their way.
    @State private var flown = false

    var body: some View {
        let entries = RewardList.group(gift.items, in: session)
        ZStack {
            Color.black.opacity(flying ? 0 : 0.45)
                .animation(.easeOut(duration: 0.25), value: flying)
                .ignoresSafeArea()
                .onTapGesture(perform: thanks)
            VStack(spacing: 0) {
                WindowTitle(L("Daily gift"), onClose: thanks)
                VStack(spacing: 12) {
                    Text(L("Day {day} of {days}", ["day": gift.day, "days": gift.days]))
                        .font(HUDStyle.font(14))
                        .foregroundStyle(HUDStyle.gold)
                    GiftDays(session: session, current: gift.day)
                    if let greeting = gift.greeting {
                        // The first gift of a festive season brings its hat.
                        Text(greeting)
                            .font(HUDStyle.font(12))
                            .foregroundStyle(HUDStyle.gold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 14) {
                        if gift.gold > 0 {
                            GoldPill(amount: gift.gold, size: 15)
                        }
                        ForEach(entries, id: \.item.id) { entry in
                            ItemIcon(item: entry.item, size: 38, count: entry.count)
                                .accessibilityLabel(entry.count > 1 ? "\(entry.item.name) ×\(entry.count)" : entry.item.name)
                                // Its copy flies from here (`flight`); it stays behind, hidden.
                                .opacity(flying ? 0 : 1)
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { spots[entry.item.id] = $0 }
                        }
                    }
                    Text(L("A gift waits each day you play. Come back tomorrow for the next one!"))
                        .font(HUDStyle.font(11))
                        .foregroundStyle(HUDStyle.dim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Thanks!"), action: thanks)
                        .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold, compact: true))
                }
                .padding(HUDStyle.windowInset)
            }
            .frame(maxWidth: 360)
            .gameWindow()
            .popIn()
            .padding(16)
            // Fading as the copies leave it; they're there at once, where the icons were.
            .opacity(flying ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: flying)
            .allowsHitTesting(!flying)

            if flying {
                flight(entries)
            }
        }
        .foregroundStyle(HUDStyle.cream)
    }

    /// Closes the card: the gift's items first fly off to the Bag, the card fading under them (the
    /// user, 2026-11-19), straight away with Reduce Motion or nothing to fly.
    private func thanks() {
        guard !flying else { return }
        let items = RewardList.group(gift.items, in: session).filter { spots[$0.item.id] != nil }
        guard !reduceMotion, !items.isEmpty else {
            onClose()
            return
        }
        flying = true
        Task {
            // A frame for the copies to stand where the icons were, then off they go.
            try? await Task.sleep(for: .milliseconds(30))
            flown = true
            try? await Task.sleep(for: .milliseconds(Self.flightMilliseconds + 70 * items.count))
            onClose()
        }
    }

    private static let flightMilliseconds = 600

    /// The items' copies, each from where it stood on the card to the Bag's button at the bottom
    /// right (beside the menu's, `WorldHUD`), shrinking and fading as it goes, one after another.
    private func flight(_ entries: [RewardList.Entry]) -> some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            // About where the Bag's button stands: in from the corner past the menu's button, inside
            // the safe area as the HUD is.
            let insets = proxy.safeAreaInsets
            let target = CGPoint(x: proxy.size.width - insets.trailing - HUDMargins.side - 84,
                                 y: proxy.size.height - max(insets.bottom, HUDMargins.side) - 36)
            ForEach(Array(entries.enumerated()), id: \.element.item.id) { index, entry in
                if let spot = spots[entry.item.id] {
                    ItemIcon(item: entry.item, size: 38, count: entry.count)
                        .scaleEffect(flown ? 0.45 : 1)
                        .opacity(flown ? 0 : 1)
                        .position(flown ? target : CGPoint(x: spot.midX - origin.x, y: spot.midY - origin.y))
                        .animation(.easeIn(duration: Double(Self.flightMilliseconds) / 1000).delay(0.07 * Double(index)), value: flown)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The daily gift's round as a card for each day (the user, 2026-11-19): each with its own gift's
/// picture (rewards.json `dailyGifts`), the days given ticked, today's lit in gold, the last (the
/// best) bigger. In a row, scrolling sideways when a narrow phone can't fit it (`SideScroll`).
struct GiftDays: View {
    let session: GameSession
    /// Today's place in the round, from 1; the days before it given.
    let current: Int

    var body: some View {
        let gifts = session.content.rewards.dailyGifts
        ViewThatFits(in: .horizontal) {
            row(gifts)
            SideScroll { row(gifts) }
        }
    }

    private func row(_ gifts: [RewardsDef.Gift]) -> some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(gifts.enumerated()), id: \.offset) { index, gift in
                GiftDayCard(session: session, gift: gift, day: index + 1, current: current, best: index == gifts.count - 1)
            }
        }
    }
}

/// One day of the daily gift's round (`GiftDays`): its gift's best item (or its coins), and its number.
private struct GiftDayCard: View {
    let session: GameSession
    let gift: RewardsDef.Gift
    let day: Int
    let current: Int
    /// The round's last day, the best gift: drawn bigger.
    let best: Bool

    var body: some View {
        let today = day == current
        let given = day < current
        let picture: CGFloat = best ? 40 : 28
        let gold = (gift.goldPerLevel ?? 0) * session.data.hero.level
        let entries = RewardList.group(gift.items ?? [], in: session)
        // The rarest thing in it stands for it; the first of the rarest.
        let headline = entries.max { Content.shared.rarity(of: $0.item.id) < Content.shared.rarity(of: $1.item.id) }
        VStack(spacing: 3) {
            Group {
                if let headline {
                    ItemIcon(item: headline.item, size: picture, count: headline.count)
                        // Coins as well as things: a coin in its corner.
                        .overlay(alignment: .bottomLeading) {
                            if gold > 0 { coin(size: picture * 0.45).offset(x: -4, y: 4) }
                        }
                } else {
                    coin(size: picture)
                }
            }
            .opacity(given ? 0.5 : 1)
            // Given already: ticked.
            .overlay {
                if given {
                    IconImage(.check, size: 12)
                        .foregroundStyle(HUDStyle.ink)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(HUDStyle.green))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                }
            }
            Text("\(day)")
                .font(HUDStyle.font(10))
                .monospacedDigit()
                .foregroundStyle(today ? HUDStyle.gold : HUDStyle.dim)
        }
        .padding(.top, 6)
        .padding(.bottom, 3)
        .frame(width: best ? 52 : 38)
        .background(GlassCard(radius: 8, lit: today, gold: today))
        .shadow(color: today ? HUDStyle.gold.opacity(0.45) : .clear, radius: today ? 5 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Day {day}: {gift}", ["day": day, "gift": describe(gold: gold, entries: entries)]))
        .accessibilityValue(today ? L("Today") : given ? L("Claimed") : "")
    }

    private func coin(size: CGFloat) -> some View {
        IconTile(icon: .coins, tint: Color(red: 0.62, green: 0.48, blue: 0.24), size: size,
                 picture: ArtLibrary.shared.artImage(CoinsTile.art(for: max(1, (gift.goldPerLevel ?? 0) * session.data.hero.level))))
    }

    /// What the day's gift holds, for VoiceOver: "1,500 gold, Potion ×3".
    private func describe(gold: Int, entries: [RewardList.Entry]) -> String {
        var parts = entries.map { $0.count > 1 ? "\($0.item.name) ×\($0.count)" : $0.item.name }
        if gold > 0 { parts.insert(L("{gold} gold", ["gold": gold]), at: 0) }
        return parts.joined(separator: ", ")
    }
}

/// The daily gift's round: the days given ticked, `current` lit, the last (the best) ringed.
struct GiftRound: View {
    let current: Int
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(1, days), id: \.self) { day in
                Text("\(day)")
                    .font(HUDStyle.font(11))
                    .foregroundStyle(day <= current ? HUDStyle.ink : HUDStyle.cream.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(day == current ? HUDStyle.gold : day < current ? HUDStyle.gold.opacity(0.5) : .white.opacity(0.1)))
                    .overlay(Circle().strokeBorder(day == days ? HUDStyle.gold : .clear, lineWidth: 1.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Day {day} of {days}", ["day": current, "days": days]))
    }
}

/// Items counted for showing ("Potion ×3").
enum RewardList {
    struct Entry {
        let item: ItemDef
        var count: Int
    }

    static func group(_ ids: [String], in session: GameSession) -> [Entry] {
        var entries: [Entry] = []
        for id in ids {
            guard let item = session.content.item(id) else { continue }
            if let index = entries.firstIndex(where: { $0.item.id == id }) {
                entries[index].count += 1
            } else {
                entries.append(Entry(item: item, count: 1))
            }
        }
        return entries
    }
}

// MARK: - Bounties

/// Today's bounties, the Quests tab's Daily challenges: what each asks and how far along it is, Claim
/// once it's done, the bonus for claiming them all, and the daily gift's round.
struct BountiesSection: View {
    let session: GameSession

    var body: some View {
        let board = session.data.bounties
        VStack(alignment: .leading, spacing: 8) {
            let bounties = board?.bounties ?? []
            HStack {
                SectionTitle(text: L("Today's bounties"),
                             detail: bounties.isEmpty ? nil : "\(bounties.filter(\.isDone).count)/\(bounties.count)")
                Text(L("New ones each day"))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.dim)
                    .fixedSize()
            }
            // One group (`GroupedRows`), as every list is (the user, 2026-11-11).
            GroupedRows(Array(bounties.enumerated()), id: \.offset) { entry in
                BountyRow(session: session, bounty: entry.element, index: entry.offset)
            }
            if let board, !board.bounties.isEmpty {
                bonus(claimed: board.bonusClaimed)
            }
            giftLine
        }
        .onAppear { session.refreshBounties() }
    }

    /// The bonus for all of them: what it pays, and Claim once they're all claimed.
    private func bonus(claimed: Bool) -> some View {
        let rules = session.content.rewards.bounties.bonus
        let exp = max(1, Int((Double(GameSession.expToNext(level: session.data.hero.level)) * rules.exp).rounded()))
        return HStack(spacing: 10) {
            IconImage(.gift, size: 18)
                .foregroundStyle(HUDStyle.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Claim them all for a bonus"))
                    .font(HUDStyle.font(12))
                WrapRows(spacing: 8) {
                    Label(L("{exp} EXP", ["exp": exp]), icon: .star, size: 12).frame(height: 22)
                    ForEach(RewardList.group(rules.items ?? [], in: session), id: \.item.id) { entry in
                        ItemIcon(item: entry.item, size: 20, count: entry.count)
                            .accessibilityLabel(entry.item.name)
                    }
                }
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
            }
            Spacer(minLength: 6)
            if claimed {
                IconImage(.check, size: 16)
                    .foregroundStyle(HUDStyle.green)
                    .accessibilityLabel(L("Claimed"))
            } else if session.canClaimBountyBonus {
                Button(L("Claim")) { session.claimBountyBonus() }
                    .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold, compact: true))
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(HUDStyle.gold.opacity(session.canClaimBountyBonus ? 0.16 : 0.06)))
    }

    /// The daily gift: given when you first play each day; where its round is.
    private var giftLine: some View {
        let days = session.content.rewards.dailyGifts.count
        let given = session.data.giftDays ?? 0
        let today = session.hasCollectedGift() && given > 0 ? (given - 1) % max(1, days) + 1 : 0
        return HStack(spacing: 10) {
            IconImage(.gift, size: 18)
                .foregroundStyle(HUDStyle.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(today > 0 ? L("Daily gift: day {day} of {days}. The next one comes tomorrow.", ["day": today, "days": days])
                               : L("Daily gift: a new one each day you play."))
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.dim)
                    .fixedSize(horizontal: false, vertical: true)
                GiftRound(current: today, days: days)
            }
        }
        .padding(.top, 2)
    }
}

private struct BountyRow: View {
    let session: GameSession
    let bounty: Bounty
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconImage(icon, size: 18)
                .foregroundStyle(HUDStyle.gold)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                // Claimed or Claim on the line with what it asks, so the bar under it runs the row's
                // whole width whatever its state (the user, 2026-11-11: "Can we have the progress bars
                // here stay the same width, so it doesn't change when there is a button or when it's
                // completed").
                HStack(alignment: .center, spacing: 8) {
                    Text(session.describe(bounty))
                        .font(HUDStyle.font(12))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    if bounty.claimed {
                        IconImage(.check, size: 16)
                            .foregroundStyle(HUDStyle.green)
                            .accessibilityLabel(L("Claimed"))
                    } else if bounty.isDone {
                        Button(L("Claim")) { session.claimBounty(index) }
                            .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold, compact: true))
                    }
                }
                .frame(minHeight: 24)
                GlossyBar(fraction: CGFloat(bounty.progress) / CGFloat(max(1, bounty.count)),
                          color: bounty.isDone ? HUDStyle.green : HUDStyle.gold, height: GlossyBar.progress)
                // A label that doesn't fit moves whole onto the next row (`WrapRows`).
                WrapRows(spacing: 10) {
                    Text("\(bounty.progress)/\(bounty.count)").frame(height: 20)
                    GoldPill(amount: bounty.gold, size: 10).frame(height: 20)
                    Label(L("{exp} EXP", ["exp": bounty.exp]), icon: .star, size: 12).frame(height: 20)
                }
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
            }
        }
        // Gold while it's done and waiting to be claimed.
        .groupRow(gold: bounty.isDone && !bounty.claimed)
    }

    private var icon: GameIcon {
        switch bounty.type {
        case .defeatOnMap?: .map
        case .defeatElement?: .sparkles
        case .wins?: .sword
        case .rare?: .star
        case .seal?: .paw
        case nil: .book
        }
    }
}

// MARK: - Titles

/// The Character tab's titles: those earned, to wear over your name (tap one; tap it again to take
/// it off), and the next few to earn with how far along each is.
struct TitlesSection: View {
    let session: GameSession
    @State private var showsAll = false

    var body: some View {
        let titles = session.content.titles
        let earned = titles.filter { session.hasEarned($0) }
        let ahead = titles.filter { !session.hasEarned($0) }.sorted { fraction($0) > fraction($1) }
        VStack(alignment: .leading, spacing: 8) {
            // Earned: the badges, to wear one over your name, on a plate of their own under how
            // many of all there are (the user, 2026-11-11: "Make improvements to the skills and titles").
            SectionTitle(text: L("Earned"), detail: L("{count} of {total}", ["count": earned.count, "total": titles.count]))
            VStack(alignment: .leading, spacing: 8) {
                GlossyBar(fraction: CGFloat(earned.count) / CGFloat(max(1, titles.count)), color: HUDStyle.gold, height: GlossyBar.progress)
                if earned.isEmpty {
                    Text(L("Earn titles as you go: levels, lands, monsters, bosses and more. Wear one over your name."))
                        .font(HUDStyle.font(11))
                        .foregroundStyle(HUDStyle.dim)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    WrapRows(spacing: 6) {
                        ForEach(earned) { title in
                            let worn = session.data.title == title.id
                            Button {
                                session.wear(worn ? nil : title)
                            } label: {
                                // Each in its badge; the one you wear ringed in cream, with a tick.
                                TitleBadge(title: title, size: 11)
                                    .padding(4)
                                    .overlay(Capsule().strokeBorder(HUDStyle.cream.opacity(worn ? 0.9 : 0), lineWidth: 2))
                                    .overlay(alignment: .topTrailing) {
                                        if worn {
                                            IconImage(.check, size: 9)
                                                .foregroundStyle(HUDStyle.ink)
                                                .padding(3)
                                                .background(Circle().fill(HUDStyle.cream))
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityAddTraits(worn ? .isSelected : [])
                            .accessibilityHint(worn ? L("Takes it off") : L("Wears it over your name"))
                        }
                    }
                    Text(L("Tap a title to wear it over your name."))
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.dim)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassCard())
            if !ahead.isEmpty {
                // Still to earn, the closest first: one group (`GroupedRows`), as every list is.
                SectionTitle(text: L("To earn"), detail: "\(ahead.count)")
                GroupedRows(showsAll ? ahead : Array(ahead.prefix(4))) { title in
                    TitleGoalRow(session: session, title: title)
                }
            }
            if ahead.count > 4 {
                Button(showsAll ? L("Show fewer") : L("Show all {count} to earn", ["count": ahead.count])) {
                    withAnimation(.easeOut(duration: 0.2)) { showsAll.toggle() }
                }
                .font(HUDStyle.font(11))
                .foregroundStyle(HUDStyle.gold)
            }
        }
    }

    private func fraction(_ title: TitleDef) -> Double {
        let progress = session.titleProgress(title)
        return Double(progress.have) / Double(max(1, progress.need))
    }
}

/// A title still to earn: its name, what it takes, and how far along you are.
private struct TitleGoalRow: View {
    let session: GameSession
    let title: TitleDef

    var body: some View {
        let progress = session.titleProgress(title)
        HStack(spacing: 10) {
            IconImage(.lock, size: 14)
                .foregroundStyle(HUDStyle.dim)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title.name)
                        .font(HUDStyle.font(12))
                    Spacer()
                    Text("\(min(progress.have, progress.need))/\(progress.need)")
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.gold)
                }
                Text(session.titleRequirement(title))
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.dim)
                GlossyBar(fraction: CGFloat(min(progress.have, progress.need)) / CGFloat(max(1, progress.need)), color: HUDStyle.gold, height: GlossyBar.progress)
            }
        }
        .groupRow()
        .accessibilityElement(children: .combine)
    }
}
