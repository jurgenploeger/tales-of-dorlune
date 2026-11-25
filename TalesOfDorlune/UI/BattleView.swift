import SwiftUI
import UIKit

/// Battle HUD: what just happened in a slim line top centre, the time left to choose in a ring round
/// your face bottom left (on a phone on its side in a pill by the line), and the commands in a row
/// along the bottom, all one size, your skills among them. How fast the fight plays and Auto wait
/// behind More. Results at the end. Names, levels, HP and MP sit on the fighters themselves. No chat in a fight: it's back on the map once the fight is over.
struct BattleView: View {
    let controller: BattleController
    /// A phone on its side: the line of what just happened can run wider.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            topBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            if showsStrip {
                LockInStrip(controller: controller, ringed: ringed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 14)
                    // Upright, above the commands' row, which can reach across the bottom.
                    .padding(.bottom, verticalSizeClass == .compact ? 18 : 104)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            commands
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
                // While a round plays nothing here takes a tap, but Auto's button, to take over.
                .allowsHitTesting(controller.phase != .animating || controller.isAuto)

            if controller.phase == .finished, let result = controller.result {
                ResultPanel(result: result, session: controller.session,
                            foes: controller.combatants.filter { $0.side == .enemies }.map(\.name), onContinue: controller.leave)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: controller.phase)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: controller.choosingForCompanion)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: controller.isAuto)
    }

    /// Upright, with a turn clock: the time to choose runs as a ring round your own face in the
    /// party's row bottom left (`TurnRing`), not in a pill at the top (the user, 2026-11-25: the top
    /// of the screen is the monsters' room).
    private var ringed: Bool {
        verticalSizeClass != .compact && BattleController.turnSeconds != nil
    }

    /// The party's faces while you choose: with the commands, and upright with a turn clock in every
    /// phase of the turn the clock runs in (a list, picking a target), as the pill did.
    private var showsStrip: Bool {
        switch controller.phase {
        case .command: return true
        case .items, .stones, .target: return ringed
        case .animating, .finished: return false
        }
    }

    /// Along the top: what just happened in the middle, and under it, in a boss fight, how far
    /// through its waves you are. On its side, your party's HP and MP at the left (`PartyPlate`)
    /// and the time to choose's pill in a row with the line, as the fighters' heads come up close
    /// under the top row there (`BattleScene.layout`). Upright, no plate and no pill (the user,
    /// 2026-11-25, a boss fight's monsters covering each other: "In portrait mode, the hero and
    /// companion stats at the top can be removed"): your HP and MP are under your feet and the time
    /// runs round your face bottom left (`TurnRing`). No boss bar either: the boss's HP is on its
    /// own plate under its feet, as everyone's is (the user, the same day).
    private var topBar: some View {
        VStack(spacing: 6) {
            if verticalSizeClass == .compact {
                HStack(alignment: .top, spacing: 8) {
                    PartyPlate(controller: controller, beside: true)
                    HStack(spacing: 8) {
                        clockPill
                        // As tall as the top row at least, so the field below doesn't shift with the message.
                        logLine
                            .frame(minHeight: Self.topRowHeight)
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            } else {
                logLine
                    .frame(minHeight: Self.topRowHeight)
                    .frame(maxWidth: 360)
            }
            if controller.waveCount > 1 {
                WaveTracker(wave: controller.wave, total: controller.waveCount)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    /// The top row's height: the field below is laid out clear of it (`BattleScene.portraitTopInset`).
    private static let topRowHeight: CGFloat = 40

    /// One slim line of what just happened, or two when it's long: a toast, as on the map.
    private var logLine: some View {
        ToastLabel(text: controller.message)
    }

    /// The time left to choose, with a turn clock on (Settings' Time to choose). Its place is kept
    /// while a round plays, so the line beside it doesn't jump from turn to turn.
    @ViewBuilder
    private var clockPill: some View {
        if BattleController.turnSeconds != nil {
            TurnClockPill(deadline: controller.turnDeadline, window: BattleController.turnSeconds ?? 10)
        }
    }

    @ViewBuilder
    private var commands: some View {
        switch controller.phase {
        case .command:
            if controller.choosingForCompanion {
                CompanionPad(controller: controller, chip: !(ringed || controller.lockIns != nil))
                    .padding(.top, 64)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            } else {
                CommandPad(controller: controller)
                    .padding(.top, 64)   // clear of the log line
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        case .items:
            ChoiceCard(title: L("Items"), onBack: controller.back) {
                if controller.items.isEmpty {
                    EmptyNote(L("Your bag is empty.\nShops in town sell potions."))
                }
                ForEach(controller.items) { item in
                    // A Seal Stone is thrown like Capture, so it's dim when there's nothing to seal.
                    ChoiceRow(action: { controller.useItem(item) }, enabled: item.capture != true || controller.canCapture) {
                        ItemIcon(item: item, size: 26, count: controller.session.count(of: item.id))
                        Text(item.name)
                        Spacer()
                        // How much a stone helps: stronger ones are likelier to hold, a Wishing Seal always does.
                        if item.capture == true {
                            Text(item.sure == true ? L("Never fails") : L("Odds ×{power}", ["power": (item.sealPower ?? 1).formatted()]))
                                .font(HUDStyle.font(10))
                                .foregroundStyle(item.sure == true ? HUDStyle.gold : HUDStyle.frameDark)
                        }
                    }
                }
            }
            // Fades in, its window popping in as every window does (`popIn`).
            .transition(.opacity)
        case .stones:
            // Capture with more than one kind of Seal Stone: which to throw, with what each brings.
            ChoiceCard(title: L("Seal Stones"), onBack: controller.back) {
                ForEach(controller.stones) { stone in
                    ChoiceRow(action: { controller.capture(with: stone) }, enabled: controller.canCapture) {
                        ItemIcon(item: stone, size: 26, count: controller.session.count(of: stone.id))
                        Text(stone.name)
                        Spacer()
                        Text(stone.sure == true ? L("Never fails") : L("Odds ×{power}", ["power": (stone.sealPower ?? 1).formatted()]))
                            .font(HUDStyle.font(10))
                            .foregroundStyle(stone.sure == true ? HUDStyle.gold : HUDStyle.frameDark)
                    }
                }
            }
            // Fades in, its window popping in as every window does (`popIn`).
            .transition(.opacity)
        case .target:
            HStack(spacing: 10) {
                IconImage(.tap, size: 18).foregroundStyle(HUDStyle.gold)
                Text(controller.prompt).font(HUDStyle.font(13))
                Button(L("Cancel"), action: controller.back)
                    .buttonStyle(PixelButtonStyle(compact: true))
            }
            .foregroundStyle(HUDStyle.cream)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(Capsule().fill(HUDStyle.ink.opacity(0.9)).overlay(Capsule().strokeBorder(HUDStyle.gold.opacity(0.8), lineWidth: 2)))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        case .animating where controller.isAuto:
            AutoPlaying { controller.toggleAuto() }
                .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
        case .animating, .finished:
            EmptyView()
        }
    }
}

/// A boss fight's waves: a pip for each, the boss's a star, gold once you've reached it.
private struct WaveTracker: View {
    let wave: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            Text(wave == total ? L("Boss wave") : L("Wave {wave} of {total}", ["wave": wave, "total": total]))
                .font(HUDStyle.font(11))
                .padding(.trailing, 2)
            ForEach(1...total, id: \.self) { index in
                Group {
                    if index == total {
                        IconImage(.star, size: 11)
                    } else {
                        Circle().frame(width: 7, height: 7)
                    }
                }
                .foregroundStyle(index <= wave ? HUDStyle.gold : HUDStyle.cream.opacity(0.3))
            }
        }
        .foregroundStyle(HUDStyle.cream)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(HUDStyle.ink.opacity(0.8)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(wave == total ? L("Boss wave, the last of {total}", ["total": total]) : L("Wave {wave} of {total}", ["wave": wave, "total": total]))
    }
}

/// Your hero's HP and MP as numbers at the top left, as the map's hero panel shows them
/// (`WorldHUD`'s `StatusCluster`): your face and two bars with what's left of each over its whole
/// (the user, 2026-11-19: with only the thin bars under the feet you judged a heal by a bar's
/// length). Your companion, while one fights at your side, in a smaller row under yours (beside it
/// on a phone on its side, so the plate stays as low as the top row), greyed once it's fainted.
/// Friends keep the bars under their feet. It takes no taps.
private struct PartyPlate: View {
    let controller: BattleController
    /// On its side: your companion beside you, not under you.
    var beside = false

    /// Upright, clear of the time to choose's pill centred on the narrowest phone (375 points: the
    /// pill starts at about 151, the plate ends at 8 + 136).
    static let width: CGFloat = 136

    /// Your own companion on the field, standing or fainted (`BattleController.companion` is only
    /// one that's standing).
    private var companion: Combatant? {
        guard let id = controller.session.activePet?.id else { return nil }
        return controller.combatants.first { $0.petID == id }
    }

    var body: some View {
        let layout = beside ? AnyLayout(HStackLayout(alignment: .top, spacing: 6))
                            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        layout {
            if let hero = controller.hero {
                row(hero, face: 32, bar: 11)
                    .frame(width: Self.width)
            }
            if let pet = companion {
                row(pet, face: 22, bar: 9)
                    .frame(width: beside ? 122 : Self.width)
            }
        }
        .allowsHitTesting(false)
    }

    /// A face in its round frame, and HP over MP, each with its numbers.
    private func row(_ fighter: Combatant, face: CGFloat, bar: CGFloat) -> some View {
        let down = fighter.hp <= 0
        return HStack(spacing: 6) {
            Image(uiImage: ArtLibrary.shared.face(fighter.art))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(face * 0.08)
                .frame(width: face, height: face)
                .background(Circle().fill(RadialGradient(colors: [HUDStyle.portrait, HUDStyle.portraitRim],
                                                         center: UnitPoint(x: 0.4, y: 0.35), startRadius: 1, endRadius: face * 0.7)))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(HUDStyle.bevel, lineWidth: 2))
            VStack(spacing: 3) {
                tagged(L("HP"), value: fighter.hp, maximum: fighter.stats.hp, color: HUDStyle.hp, height: bar)
                tagged(L("MP"), value: fighter.mp, maximum: fighter.stats.mp, color: HUDStyle.mp, height: bar)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HUDStyle.panel(shape: HUDStyle.hudPanelShape))
        .saturation(down ? 0 : 1)
        .opacity(down ? 0.75 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("{name}: HP {hp} of {maxHP}, MP {mp} of {maxMP}",
                              ["name": fighter.name, "hp": max(0, fighter.hp), "maxHP": fighter.stats.hp,
                               "mp": fighter.mp, "maxMP": fighter.stats.mp]))
    }

    /// A bar with its numbers over it and its tag on a dark chip after it, as the map's are.
    private func tagged(_ tag: String, value: Int, maximum: Int, color: Color, height: CGFloat) -> some View {
        HStack(spacing: 3) {
            StatBar(label: "", value: max(0, value), maximum: maximum, color: color, height: height)
            Text(tag)
                .font(HUDStyle.font(9))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 1)
                .frame(width: 20, height: 11)
                .background(RoundedRectangle(cornerRadius: 3).fill(HUDStyle.frameDark))
        }
    }
}

/// While you choose, your party's faces bottom left, each ticked once that one has locked in their
/// move: your friends one by one as the time to choose runs (`BattleController.lockIns`), you when
/// you've chosen. Your side acts in the order it chose, as in Fairyland Online, so the ticks show who
/// you'd go before. Only with friends at your side, or upright with a turn clock (`ringed`), when
/// your own face wears the time left as a ring (`TurnRing`), alone without friends.
private struct LockInStrip: View {
    let controller: BattleController
    /// The time to choose as a ring round your face.
    var ringed = false

    var body: some View {
        let lockIns = controller.lockIns
        if lockIns != nil || ringed {
            TimelineView(.periodic(from: lockIns?.since ?? Date(), by: 0.25)) { context in
                HStack(spacing: 5) {
                    ForEach(lockIns == nil ? controller.choosers.filter(\.isHero) : controller.choosers) { fighter in
                        // Your place shows whoever you're choosing for, with the ring: you, then on its turn
                        // your companion in your place (the user, 2026-11-25: "it should show the companion's
                        // little avatar with the countdown"; "It shouldn't show my hero and companion avatar
                        // ... at the same time, only when it's the companion's turn, it swaps with the hero").
                        if fighter.isHero, controller.choosingForCompanion, let companion = controller.companion {
                            slot(companion, ready: false, active: true)
                        } else {
                            slot(fighter, ready: isReady(fighter, at: context.date), active: fighter.isHero)
                        }
                    }
                }
            }
        }
    }

    /// A face in the row: with a turn clock (`ringed`) every face keeps the ring's room round it, so
    /// the row stands still as the ring moves from one to the next, and the one being chosen for
    /// (`active`) wears it.
    @ViewBuilder
    private func slot(_ fighter: Combatant, ready: Bool, active: Bool) -> some View {
        if ringed && active {
            ringedFace(fighter, ready: ready)
        } else if ringed {
            face(fighter, ready: ready).padding(TurnRing.inset)
        } else {
            face(fighter, ready: ready)
        }
    }

    /// A face with the time to choose as a ring round it (`TurnRing`).
    private func ringedFace(_ fighter: Combatant, ready: Bool) -> some View {
        face(fighter, ready: ready)
            .padding(TurnRing.inset)
            .overlay {
                TurnRing(deadline: controller.turnDeadline, window: BattleController.turnSeconds ?? 10)
            }
    }

    /// You once you've chosen; a friend once the time to choose has run to their share of it.
    private func isReady(_ fighter: Combatant, at date: Date) -> Bool {
        if fighter.isHero { return controller.choosingForCompanion }
        guard let lockIns = controller.lockIns, let share = lockIns.friends[fighter.id] else { return false }
        return date >= lockIns.since.addingTimeInterval(share * lockIns.window)
    }

    private func face(_ fighter: Combatant, ready: Bool) -> some View {
        Image(uiImage: ArtLibrary.shared.face(fighter.art))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(3)
            .frame(width: 32, height: 32)
            .background(Circle().fill(RadialGradient(colors: [HUDStyle.portrait, HUDStyle.portraitRim],
                                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 1, endRadius: 22)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(ready ? AnyShapeStyle(HUDStyle.gold) : AnyShapeStyle(HUDStyle.bevel), lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if ready {
                    IconImage(.check, size: 9)
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(Color(red: 0.25, green: 0.7, blue: 0.35)).overlay(Circle().strokeBorder(.white, lineWidth: 1.2)))
                        .offset(x: 3, y: 3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .opacity(ready ? 1 : 0.75)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: ready)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready ? "\(fighter.name), \(L("Ready"))" : fighter.name)
    }
}

/// The time left to choose as a ring round your face in the party's row, upright (`LockInStrip`;
/// the user, 2026-11-25: "The timer at the top should be incorporated as a circle line around the
/// little hero avatar in the bottom left corner"): gold on a dark track, emptying from the top as
/// the time runs, red for the last three seconds, as the pill was. With Reduce Motion it steps a
/// whole second at a time instead of sweeping. Unseen while no clock ticks.
private struct TurnRing: View {
    let deadline: Date?
    /// The whole time a turn gives, in seconds: the ring is full at it.
    let window: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the ring stands out round the 32-point face (its stroke clear of the face's rim).
    static let inset: CGFloat = 6
    private static let lineWidth: CGFloat = 3.5

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : nil, paused: deadline == nil)) { context in
            let left = deadline.map { max(0, $0.timeIntervalSince(context.date)) } ?? 0
            let seconds = Int(left.rounded(.up))
            let shown = reduceMotion ? Double(seconds) : left
            let share = CGFloat(min(1, shown / max(window, 1)))
            let urgent = deadline != nil && left <= TurnClockPill.urgentSeconds
            ZStack {
                Circle()
                    .stroke(HUDStyle.ink.opacity(0.6), lineWidth: Self.lineWidth)
                Circle()
                    .trim(from: 0, to: share)
                    .stroke(urgent ? TurnClockPill.urgentRed : HUDStyle.gold,
                            style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(Self.lineWidth / 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Time left to choose before you attack"))
            .accessibilityValue(L("{seconds} s", ["seconds": seconds]))
        }
        .opacity(deadline == nil ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: deadline == nil)
        .allowsHitTesting(false)
        .accessibilityHidden(deadline == nil)
    }
}

/// The time left to choose on a phone on its side (upright it's a ring round your face, `TurnRing`),
/// top centre in a dark pill like the map's (`mapPill`): an hourglass and
/// the seconds over a yellow bar running down as the time does (playtesting 2026-10-26: "The timer
/// should show a yellow bar"), the same in every phase of a turn (the commands, a list, picking a
/// target). Red for the last three, with a beat as each goes. When it runs out the hero attacks. While no clock
/// ticks (a round playing, the buttons being rearranged) it keeps its place unseen.
private struct TurnClockPill: View {
    let deadline: Date?
    /// The whole time a turn gives, in seconds: the bar is full at it.
    let window: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let urgentSeconds: TimeInterval = 3
    /// Red that reads on the navy (`HUDStyle.hp` is too deep there).
    static let urgentRed = Color(red: 1, green: 0.45, blue: 0.4)

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: deadline == nil)) { context in
            let left = deadline.map { max(0, $0.timeIntervalSince(context.date)) } ?? 0
            let urgent = deadline != nil && left <= Self.urgentSeconds
            // How much of the second on show is left: 1 just as it shows, down to 0 as it goes.
            let into = CGFloat(left - left.rounded(.down))
            pill(seconds: Int(left.rounded(.up)), share: CGFloat(min(1, left / max(window, 1))), urgent: urgent)
                .scaleEffect(urgent && !reduceMotion ? 1 + 0.14 * into * into : 1)
        }
        .opacity(deadline == nil ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: deadline == nil)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Time left to choose before you attack"))
        .accessibilityHidden(deadline == nil)
    }

    private func pill(seconds: Int, share: CGFloat, urgent: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                IconImage(.hourglass, size: 13)
                    .foregroundStyle(urgent ? Self.urgentRed : HUDStyle.gold)
                Text(verbatim: String(seconds))
                    .font(HUDStyle.mono(13))
                    .foregroundStyle(urgent ? Self.urgentRed : HUDStyle.cream)
                    // Two digits' room, so the pill keeps its width as they count down.
                    .frame(minWidth: 16)
            }
            // The time left as a bar, emptying from the right; red with the numbers at the end.
            Capsule()
                .fill(HUDStyle.cream.opacity(0.18))
                .frame(width: 52, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(urgent ? Self.urgentRed : HUDStyle.gold)
                        .frame(width: 52 * share, height: 4)
                }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .mapPill()
        .overlay(Capsule().strokeBorder(Self.urgentRed, lineWidth: 1.5).opacity(urgent ? 1 : 0))
    }
}

// MARK: - Commands

/// The commands in one row along the bottom, all the same size (the user, 2026-10-26: "the buttons
/// to show as the same size at the bottom ... 'More' is all the way on the left"): More at the left
/// end, then a button for each of your skills (`SkillRow`), your first command (Attack unless you
/// change it) at the right end where the thumb rests, and before it, right to left, the rest of the
/// row. Nothing moves with the fight (playtesting 2026-10-30: "Don't change the order of the battle
/// buttons based on the state"): Capture stays in its place, faded while there's nothing to seal, and
/// Items glows green where it is when someone is low on HP. Less-used commands hide behind More, and with them Auto and the fight's pace. Holding a command
/// makes them all wiggle, like the iPhone home screen: drag them into any order (onto the first, or
/// into the "Behind More" tray), then tap Done. The skills keep their place by More.
private struct CommandPad: View {
    let controller: BattleController
    /// Debug `more`: open from the start, for screenshots.
    @State private var showMore = DebugLaunch.opensMore
    /// While rearranging: the whole order, `moreDivider` included (nil otherwise).
    @State private var editing: [String]?
    /// Where each button sits, for working out what a dragged button is over.
    @State private var frames: [String: CGRect] = [:]
    @State private var trayFrame: CGRect = .zero
    @State private var dragging: String?
    @State private var dragPoint: CGPoint = .zero
    /// The button last swapped with, so hovering over it doesn't swap back and forth.
    @State private var lastTarget: String?

    private let buttonSize = CommandRow.size
    private static let space = "commandPad"

    var body: some View {
        Group {
            if let editing {
                editPad(editing)
            } else {
                pad
            }
        }
        .coordinateSpace(name: Self.space)
        .onAppear { if DebugLaunch.arrangesButtons, editing == nil { arrange() } }
        // Moving the buttons around isn't choosing: the turn clock waits.
        .onChange(of: editing == nil) { _, settled in controller.holdTurnClock(!settled, for: "arrange") }
        // The pad can go mid-move (AUTO tapped while the buttons wiggle plays the round): its hold
        // goes with it, or the clock and Auto would wait for it forever.
        .onDisappear { controller.holdTurnClock(false, for: "arrange") }
    }

    /// Your order (`GameSession.battleButtons`), split into the first button (the row's right end),
    /// the rest of the row (right to left, before More) and the More menu, the same all fight long:
    /// what can't be used right now is faded in its place, not left out.
    private var sections: (main: String?, column: [String], more: [String]) {
        let order = controller.session.battleButtons
        let divider = order.firstIndex(of: GameSession.moreDivider) ?? order.endIndex
        var front = Array(order[..<divider])
        var more = Array(order[divider...].dropFirst())
        if front.isEmpty, !more.isEmpty { front.append(more.removeFirst()) }
        return (front.first, Array(front.dropFirst()), more)
    }

    /// Auto and the fight's pace: at the end of what More opens, after the commands behind it.
    private static let paceIDs = ["auto", "pace"]

    /// More at the left end, opening up and to the right; then the skills; the first button at the
    /// right end. More's panel reaches as far right as a row of three: a shorter one makes room for it.
    /// Skills the row has no room for wait behind More, at the top of its panel (playtesting
    /// 2026-10-30: "If it doesn't fit, the buttons will go in the more button").
    private var pad: some View {
        let (main, column, more) = sections
        return SkillRow(controller: controller, skills: controller.skills, others: column.count + (main == nil ? 0 : 1),
                        least: MoreMenu.width, overflowsToLead: true,
                        onSize: { controller.commandButtonSize = $0 }) { size, behind in
            MoreMenu(controller: controller, skills: behind, commands: more + Self.paceIDs, open: $showMore, size: size,
                     onPick: perform, onHold: arrange)
        } tail: { size in
            ForEach(Array(column.reversed()), id: \.self) { id in
                button(id, size: size)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
            if let main {
                button(main, size: size, isMain: true)
            }
        }
        .padding(.leading, 14)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: showMore)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: controller.canCapture)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: controller.needsHealing)
    }

    private func arrange() {
        showMore = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { editing = controller.session.battleButtons }
    }

    // MARK: Rearranging

    private func editPad(_ order: [String]) -> some View {
        let divider = order.firstIndex(of: GameSession.moreDivider) ?? order.endIndex
        let main = order.first
        let row = Array(order[..<divider].dropFirst())
        let tray = Array(order[divider...].dropFirst())
        return VStack(alignment: .trailing, spacing: 22) {
            HStack(spacing: 8) {
                Text(L("Drag to rearrange"))
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.cream)
                Button(L("Reset")) { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { editing = GameSession.defaultBattleButtons } }
                    .font(HUDStyle.font(12))
                    .foregroundStyle(HUDStyle.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.15)))
                Button {
                    controller.arrangeButtons(order)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { editing = nil }
                } label: {
                    Text(L("Done"))
                        .font(HUDStyle.font(13))
                        .foregroundStyle(HUDStyle.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(HUDStyle.gold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(HUDStyle.ink.opacity(0.85)))

            // What waits behind More.
            VStack(alignment: .trailing, spacing: 8) {
                Text(L("Behind More"))
                    .font(HUDStyle.font(11))
                    .foregroundStyle(HUDStyle.cream.opacity(0.8))
                RightToLeftRows {
                    ForEach(tray, id: \.self) { id in editTile(id, size: buttonSize) }
                }
                .frame(minWidth: buttonSize * 2, minHeight: buttonSize, alignment: .bottomTrailing)
                .padding(.bottom, 16)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(HUDStyle.ink.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(HUDStyle.cream.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            )
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { trayFrame = $0 }
            .zIndex(tray.contains { $0 == dragging } ? 1 : 0)

            // The row as it plays: More at the left end, the first button at the right, the rest
            // right to left between them (on up into a second row when they don't fit).
            HStack(alignment: .bottom, spacing: CommandRow.spacing) {
                RoundCommandButton(title: L("More"), icon: .more, size: buttonSize, tint: .quiet) {}
                    .allowsHitTesting(false)
                    .opacity(0.5)
                RightToLeftRows(spacing: CommandRow.spacing) {
                    ForEach(main.map { [$0] + row } ?? row, id: \.self) { id in editTile(id, size: buttonSize, isMain: id == main) }
                }
                .zIndex(order[..<divider].contains { $0 == dragging } ? 1 : 0)
            }
            .padding(.leading, 14)
        }
    }

    /// A wiggling button that can be dragged; taps do nothing while rearranging.
    private func editTile(_ id: String, size: CGFloat, isMain: Bool = false) -> some View {
        let isDragged = dragging == id
        let center = frames[id].map { CGPoint(x: $0.midX, y: $0.midY) } ?? dragPoint
        return button(id, size: size, isMain: isMain)
            .allowsHitTesting(false)
            .modifier(Wiggle(active: !isDragged))
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[id] = $0 }
            .scaleEffect(isDragged ? 1.15 : 1)
            .offset(isDragged ? CGSize(width: dragPoint.x - center.x, height: dragPoint.y - center.y) : .zero)
            .zIndex(isDragged ? 1 : 0)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        if dragging != id {
                            dragging = id
                            lastTarget = nil
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dragPoint = value.location
                        drag(id, over: value.location)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragging = nil
                            lastTarget = nil
                        }
                    }
            )
    }

    /// Moves the dragged button into the place of whatever it's over (iPhone home screen style), or to
    /// the end of the tray when it's dropped into the tray's empty space.
    private func drag(_ id: String, over point: CGPoint) {
        guard var order = editing, let from = order.firstIndex(of: id) else { return }
        if let target = frames.first(where: { $0.key != id && order.contains($0.key) && $0.value.contains(point) })?.key {
            guard target != lastTarget, let to = order.firstIndex(of: target) else { return }
            lastTarget = target
            order.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        } else if trayFrame.contains(point), let divider = order.firstIndex(of: GameSession.moreDivider), from < divider {
            lastTarget = nil
            order.remove(at: from)
            order.append(id)
        } else {
            lastTarget = nil
            return
        }
        // Something always has to be the first button.
        if order.first == GameSession.moreDivider, order.count > 1 { order.swapAt(0, 1) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { editing = order }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func button(_ id: String, size: CGFloat, isMain: Bool = false) -> some View {
        let info = BattleCommand(id)
        let faded = id == "capture" && !controller.canCapture
        return RoundCommandButton(title: info.title, icon: id == "items" && controller.needsHealing ? .heartPlus : info.icon,
                                  size: size, tint: tint(for: id, main: isMain), onHold: arrange) {
            perform(id)
        }
        .saturation(faded ? 0 : 1)
        .opacity(faded ? 0.5 : 1)
    }

    private func tint(for id: String, main: Bool) -> RoundCommandButton.Tint {
        if id == "capture" { return controller.canCapture ? .special : main ? .primary : .normal }
        if id == "items", controller.needsHealing { return .heal }
        return main ? .primary : .normal
    }

    private func perform(_ id: String) {
        switch id {
        case "attack": controller.attack()
        case "items": controller.openItems()
        case "guard": controller.defend()
        case "run": controller.escape()
        // Faded while there's nothing to seal: a tap does nothing.
        case "capture": if controller.canCapture { controller.capture() }
        default: break
        }
    }
}

/// More, at the left end of the row: a round button that, tapped, grows into a panel up and to the
/// right of it, over the row and the field, as the map's menu does (`GameMenu`), listing what waits
/// behind it (the skills the row had no room for, the commands put there, then Auto and the fight's
/// pace), the orange close button on its top right corner (playtesting 2026-10-24: it scattered more
/// round buttons over the arc). It takes only the button's room, and the row stays as it is under the
/// panel. Holding it rearranges the buttons.
private struct MoreMenu: View {
    let controller: BattleController
    /// Your skills the row had no room for.
    var skills: [SkillDef] = []
    let commands: [String]
    @Binding var open: Bool
    let size: CGFloat
    let onPick: (String) -> Void
    let onHold: () -> Void

    /// The panel's width (the row makes room for it to the right of More: `CommandPad.row`).
    static let width: CGFloat = 176
    private static let spring = Animation.spring(response: 0.34, dampingFraction: 0.78)

    private var entries: [MoreEntry] {
        skills.map { MoreEntry.skill($0) } + commands.enumerated().map { MoreEntry.command($0.element, $0.offset) }
    }

    var body: some View {
        // As the map's menu opens (`GameMenu`): the button grows into the panel from its corner,
        // up and to the right over the row, the close button on the panel's top right corner
        // (playtesting 2026-10-30: it opened downward, under the skills).
        ZStack(alignment: .bottomLeading) {
            if open {
                panel
                    .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                button
                    .transition(.opacity)
            }
        }
        .animation(Self.spring, value: open)
        .frame(width: size, height: size, alignment: .bottomLeading)
    }

    private var button: some View {
        PressButton(action: {
            SoundEffects.shared.play(.tap, volume: 0.7)
            open = true
        }, onHold: onHold) {
            IconImage(.more, size: size * 0.56)
                .shadow(color: HUDStyle.frameDark, radius: 0, x: 1, y: 1)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .accessibilityLabel(L("More"))
        .background(
            Circle()
                .fill(LinearGradient(colors: HUDStyle.tile, startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(HUDStyle.bevel, lineWidth: 2.5))
                .overlay(
                    // The button's gloss.
                    Ellipse().fill(.white.opacity(0.35))
                        .frame(width: size * 0.5, height: size * 0.2)
                        .offset(y: -size * 0.3)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            Text(L("More"))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.cream)
                .shadow(color: .black, radius: 0, x: 1, y: 1)
                .fixedSize()
                .offset(y: 15)
        }
    }

    /// What waits behind More, in a window of the button's blue.
    private var panel: some View {
        // One column, always (the user, 2026-11-19: two side by side were "terrible").
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries) { entry in
                cell(entry)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(width: Self.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: HUDStyle.tile, startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(HUDStyle.bevel, lineWidth: 2.5))
        )
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 4)
        .overlay(alignment: .topTrailing) {
            OrangeCloseButton {
                SoundEffects.shared.play(.tap, volume: 0.7)
                open = false
            }
            .accessibilityLabel(L("Close"))
            .offset(x: OrangeCloseButton.overhang, y: -OrangeCloseButton.overhang)
        }
    }

    @ViewBuilder
    private func cell(_ entry: MoreEntry) -> some View {
        switch entry {
        case .skill(let skill):
            skillRow(skill)
                .transition(.opacity)
        case .command(let id, let index):
            row(id)
                // One after another up from the button as it opens.
                .transition(.asymmetric(
                    insertion: .offset(y: 14).combined(with: .opacity)
                        .animation(Self.spring.delay(Double(commands.count - 1 - index) * 0.035)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))))
        }
    }

    /// A skill the row had no room for: its picture, name and MP, greyed when it can't be used (a
    /// tap then only says why, as the row's buttons do).
    private func skillRow(_ skill: SkillDef) -> some View {
        let usable = controller.canUse(skill)
        let cost = controller.cost(of: skill)
        return Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            open = false
            if !usable { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            controller.useSkill(skill)
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(Color(uiColor: skill.tileColor))
                    if let picture = skill.art.flatMap(ArtLibrary.shared.artImage) {
                        Image(uiImage: picture)
                            .interpolation(picture.size.width > 64 ? .high : .none)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        IconImage(skill.icon.flatMap(GameIcon.init) ?? .sparkles, size: 14)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)
                Text(skill.name)
                    .font(HUDStyle.font(13))
                    .foregroundStyle(.white)
                    .shadow(color: HUDStyle.frameDark, radius: 0, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if cost > 0 {
                    Text(L("{cost} MP", ["cost": cost]))
                        .font(HUDStyle.font(11))
                        .monospacedDigit()
                        .foregroundStyle(HUDStyle.cream)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .saturation(usable ? 1 : 0)
        .opacity(usable ? 1 : 0.5)
        .accessibilityLabel(skill.name)
        .accessibilityValue(L("{cost} MP", ["cost": cost]))
    }

    private func row(_ id: String) -> some View {
        let isAuto = id == "auto", isPace = id == "pace"
        let fast = controller.speed > 1
        let info = BattleCommand(id)
        let healing = id == "items" && controller.needsHealing
        return Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            if isPace {
                // The pace stays open to see it change.
                controller.toggleSpeed()
            } else {
                open = false
                if isAuto { controller.toggleAuto() } else { onPick(id) }
            }
        } label: {
            HStack(spacing: 9) {
                IconImage(isAuto ? .paw : isPace ? .wind : healing ? .heartPlus : info.icon, size: 24)
                Text(isAuto ? L("Auto") : isPace ? L("Pace") : info.title)
                    .font(HUDStyle.font(13))
                    .foregroundStyle(healing ? HUDStyle.green : id == "capture" ? HUDStyle.gold : .white)
                    .shadow(color: HUDStyle.frameDark, radius: 0, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if isPace {
                    Text(fast ? "2×" : "1×")
                        .font(HUDStyle.font(13))
                        .foregroundStyle(fast ? HUDStyle.gold : HUDStyle.cream)
                } else if isAuto, controller.isAuto {
                    IconImage(.check, size: 14).foregroundStyle(HUDStyle.gold)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        // Auto is faded where it can't play (a boss, a duel, monsters too strong for it) and says why
        // when tapped.
        .opacity(isAuto && !controller.isAuto && !controller.canAuto ? 0.5 : id == "capture" && !controller.canCapture ? 0.5 : 1)
        .accessibilityLabel(isAuto
                            ? (controller.isAuto ? L("Auto is on. Tap to choose yourself.") : L("Auto: fight on your own."))
                            : isPace ? (fast ? L("Battle speed: double. Tap for normal.") : L("Battle speed: normal. Tap for double."))
                            : info.title)
    }
}

/// One line in More's panel: a skill the row had no room for, or a command (`index`: its place
/// among the commands, for their one-after-another opening).
private nonisolated enum MoreEntry: Identifiable {
    case skill(SkillDef)
    case command(String, Int)

    var id: String {
        switch self {
        case .skill(let skill): "skill:" + skill.id
        case .command(let command, _): command
        }
    }
}

/// Auto at work: the commands' corner turns gold and says so, its ring turning, and a tap takes
/// the fight back from the next round. (The switch that starts it is behind More.)
private struct AutoPlaying: View {
    let onTakeOver: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        Button {
            SoundEffects.shared.play(.tap, volume: 0.7)
            onTakeOver()
        } label: {
            Text(L("AUTO"))
                .font(HUDStyle.font(16))
                .foregroundStyle(HUDStyle.ink)
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 1, green: 0.92, blue: 0.55), Color(red: 0.98, green: 0.68, blue: 0.2)],
                                             center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 66))
                        .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 2))
                )
                .overlay {
                    Circle()
                        .stroke(HUDStyle.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [9, 7]))
                        .frame(width: 104, height: 104)
                        .rotationEffect(.degrees(turning ? 360 : 0))
                }
                .overlay(alignment: .top) {
                    Text(L("Tap to take over"))
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.cream)
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .fixedSize()
                        .offset(y: -30)
                }
        }
        .buttonStyle(RoundPressStyle())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { turning = true }
        }
        .accessibilityLabel(L("Auto is on. Tap to choose yourself."))
    }
}

/// Your companion's turn, after the hero's choice: the same row as the hero's, Auto to let it
/// decide for itself where More is, then its skills, Guard, and Attack at the right end. The chip
/// on top shows whose turn it is. The hero's choice is made by then, so there's no going back to
/// it (that would start their clock over).
private struct CompanionPad: View {
    let controller: BattleController
    /// Whether the chip shows whose turn it is: only where the party's row bottom left doesn't, its face
    /// there taking your place in the ring (the user, 2026-11-25: "We don't need to show the pill ... their
    /// circle already lights up and it shows in the small avatar bottom left").
    var chip = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            if chip, let companion = controller.companion {
                HStack(spacing: 8) {
                    SpriteImage(art: companion.art, size: 30)
                    Text(L("{companion}'s turn", ["companion": companion.name]))
                        .font(HUDStyle.font(13))
                        .foregroundStyle(HUDStyle.cream)
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(HUDStyle.ink.opacity(0.88)).overlay(Capsule().strokeBorder(HUDStyle.gold.opacity(0.7), lineWidth: 1.5)))
            }

            // Its buttons the size of the hero's (`commandButtonSize`), closed up at the right.
            SkillRow(controller: controller, skills: controller.companionSkills, others: 2,
                     matching: controller.commandButtonSize) { size, _ in
                RoundCommandButton(title: L("Auto"), icon: .paw, size: size, tint: .quiet) { controller.letCompanionDecide() }
            } tail: { size in
                RoundCommandButton(title: L("Guard"), icon: .shield, size: size, tint: .normal) { controller.defend() }
                // The hero's Attack, sword and all (playtesting 2026-10-30: a tooth "should just be the same as
                // the hero").
                RoundCommandButton(title: L("Attack"), icon: BattleCommand("attack").icon, size: size, tint: .primary) {
                    controller.attack()
                }
            }
        }
        .padding(.leading, 14)
    }
}

/// The commands' row along the bottom (`CommandPad`, `CompanionPad`): every button the same size,
/// evenly spaced; the labels hang below the buttons, outside the layout.
nonisolated enum CommandRow {
    static let size: CGFloat = 56
    static let spacing: CGFloat = 14
    /// Closed up, for a row too long for a narrow phone upright.
    static let narrowSize: CGFloat = 42
    static let narrowSpacing: CGFloat = 8
}

/// A row of commands with your skills in it (the user, 2026-10-26: skills as buttons in the row,
/// not behind a menu): `lead` at the left end (More, or Auto on your companion's turn), then a
/// round button for each skill (`SkillCommandButton`), then `tail`, the other commands, Attack at
/// the right end. Upright it spans the screen, its buttons sized and spaced to fill it (`filling`);
/// on its side it sits at the right. Too long for the phone, the row closes up and its buttons
/// shrink a little, as it always did; longer still, the last skills go behind More (`overflowsToLead`: `lead` is told
/// which), as few as will do, or, where there's no More (your companion's turn), the skills slide
/// sideways between the two ends, which stay put.
/// Holding a skill shows its card over the row (`SkillCard`): its level, element, MP and what it
/// does, as the list of skills once did.
private struct SkillRow<Lead: View, Tail: View>: View {
    let controller: BattleController
    let skills: [SkillDef]
    /// How many buttons `tail` holds.
    let others: Int
    /// The least the row may measure across (More's panel reaches that far right of it).
    var least: CGFloat = 0
    /// Skills the row has no room for go to `lead` (More) rather than sliding.
    var overflowsToLead = false
    /// A button size to keep to where it fits (the hero's, on the companion's turn), the row closed up
    /// at the right with the usual gap between its buttons instead of spread out to the left edge
    /// (playtesting 2026-10-31: "The companion's buttons should be right aligned, without the gaps").
    var matching: CGFloat? = nil
    /// Told the button size the row settles on (the hero's row tells `BattleController.commandButtonSize`).
    var onSize: ((CGFloat) -> Void)? = nil
    /// The left end, at a button size, with the skills the row had no room for.
    @ViewBuilder let lead: (CGFloat, [SkillDef]) -> Lead
    @ViewBuilder let tail: (CGFloat) -> Tail
    /// The skill whose card shows.
    @State private var card: String?
    @State private var hideCard: Task<Void, Never>?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Upright, the row's room across, measured: its buttons are sized and spaced to fill it.
    @State private var width: CGFloat = 0

    /// Room under the sliding skills for their names, which hang below the buttons and would be cut
    /// off there, and above them for their MP badges. Computed: a generic type can't store a static.
    private static var nameRoom: CGFloat { 18 }
    private static var badgeRoom: CGFloat { 6 }
    /// The biggest a button grows to, filling a row of few.
    private static var largest: CGFloat { 64 }

    var body: some View {
        Group {
            // On its side the row stays at the right, clear of the lock-in strip at the bottom left.
            if verticalSizeClass == .compact { fitting } else { filling }
        }
        .overlay(alignment: .top) {
            if let id = card, let skill = skills.first(where: { $0.id == id }) {
                SkillCard(skill: skill, level: level(of: skill), cost: cost(of: skill), enoughMP: mp >= cost(of: skill))
                    // Its foot a little above the buttons, over the middle of the row.
                    .alignmentGuide(.top) { $0[.bottom] + 16 }
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: card)
        // Debug `skills`: the first skill's card, for screenshots.
        .onAppear { if DebugLaunch.showsSkillCard, card == nil { card = skills.first?.id } }
        .onDisappear { hideCard?.cancel() }
    }

    /// Upright: the whole width of the screen, edge to edge (playtesting 2026-10-30: "Make sure the
    /// button sizes always fill the full width of the screen"), the buttons as big as that allows
    /// (up to `largest`) and spaced to reach both ends; no smaller than the closed-up size, past
    /// which the last skills go behind More (or, with no More, slide).
    private var filling: some View {
        let layout = filled(in: width)
        return VStack(spacing: 0) {
            // The room across, measured apart from the row: measured on the row itself, a row wider
            // than the screen measured itself as the room it had, and stayed that wide, stretching
            // the whole battle past the screen's edges (playtesting 2026-10-30).
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            row(size: layout.size, spacing: layout.spacing, shown: layout.shown, slides: layout.slides, reach: layout.reach)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: width > 0 ? layout.size : nil, initial: true) { _, size in
            if let size { onSize?(size) }
        }
    }

    /// `reach`: how far across the row reaches, its lead at the left end and the rest at the right
    /// (0: as far as its buttons do).
    private func filled(in width: CGFloat) -> (size: CGFloat, spacing: CGFloat, shown: Int, slides: Bool, reach: CGFloat) {
        // Not measured yet: as small as the row goes, its skills behind More (or sliding), so it
        // never starts out wider than the screen.
        guard width > 0 else { return (CommandRow.narrowSize, CommandRow.narrowSpacing, overflowsToLead ? 0 : skills.count, !overflowsToLead, 0) }
        let gap = CommandRow.narrowSpacing
        // How big each of `count` buttons would be, the least gap between them.
        func fitted(_ count: Int) -> CGFloat { (width - CGFloat(count - 1) * gap) / CGFloat(count) }
        var shown = skills.count
        if overflowsToLead {
            while shown > 0, fitted(1 + shown + others) < CommandRow.narrowSize { shown -= 1 }
        }
        let count = 1 + shown + others
        guard fitted(count) >= CommandRow.narrowSize else { return (CommandRow.narrowSize, gap, shown, true, 0) }
        // The size asked for, if the row has room for it; spaced out to fill the rest.
        let size = matching.map { min($0, fitted(count)) } ?? min(Self.largest, fitted(count)).rounded(.down)
        let spread = count > 1 ? (width - CGFloat(count) * size) / CGFloat(count - 1) : 0
        // At the hero's size (the companion's turn) it closes up at the right. At a size of its own
        // it spans the screen; with room to spare even at the biggest size (few skills yet), More
        // stays at the left end and the rest close up at the right, not strung out across it
        // (playtesting 2026-11-01: "If not all skills are there yet, the attack buttons are right
        // aligned with the more button always left aligned").
        if matching != nil { return (size, min(spread, CommandRow.spacing), shown, false, 0) }
        if spread > CommandRow.spacing { return (size, CommandRow.spacing, shown, false, width) }
        return (size, spread, shown, false, 0)
    }

    /// On its side: the biggest of a few fixed sizes that fits, at the right.
    private var fitting: some View {
        ViewThatFits(in: .horizontal) {
            // The size asked for first (the hero's, on the companion's turn), if every button fits at it.
            if let matching {
                row(size: matching, spacing: matching < CommandRow.size ? CommandRow.narrowSpacing : CommandRow.spacing,
                    shown: skills.count, slides: false)
            }
            row(size: CommandRow.size, spacing: CommandRow.spacing, shown: skills.count, slides: false)
                .onAppear { onSize?(CommandRow.size) }
            row(size: CommandRow.narrowSize, spacing: CommandRow.narrowSpacing, shown: skills.count, slides: false)
                .onAppear { onSize?(CommandRow.narrowSize) }
            if overflowsToLead {
                // One skill fewer at a time, the rest behind More, till the row fits.
                ForEach(Array((0..<skills.count).reversed()), id: \.self) { shown in
                    row(size: CommandRow.narrowSize, spacing: CommandRow.narrowSpacing, shown: shown, slides: false)
                        .onAppear { onSize?(CommandRow.narrowSize) }
                }
            } else {
                row(size: CommandRow.narrowSize, spacing: CommandRow.narrowSpacing, shown: skills.count, slides: true)
            }
        }
    }

    /// The row with the first `shown` skills in it, the rest handed to `lead`; `reach` across, if
    /// that's wider than its buttons, `lead` at the left end and the rest at the right.
    @ViewBuilder
    private func row(size: CGFloat, spacing: CGFloat, shown: Int, slides: Bool, reach: CGFloat = 0) -> some View {
        let visible = Array(skills.prefix(shown))
        let count = 1 + visible.count + others
        // Room left over, between `lead` and the rest (`least`, or `reach` from `filling`).
        let short = max(least, reach) - (CGFloat(count) * size + CGFloat(count - 1) * spacing)
        HStack(alignment: .bottom, spacing: spacing) {
            lead(size, Array(skills.dropFirst(shown)))
                // Over the rest of the row: More's panel opens across it.
                .zIndex(1)
            if slides {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        buttons(visible, size: size)
                    }
                    .padding(.top, Self.badgeRoom)
                    .padding(.bottom, Self.nameRoom)
                    .padding(.horizontal, 4)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                // In the row only as tall as its buttons, level with the rest.
                .padding(.top, -Self.badgeRoom)
                .padding(.bottom, -Self.nameRoom)
            } else {
                if short > spacing { Color.clear.frame(width: short - spacing, height: size) }
                buttons(visible, size: size)
            }
            tail(size)
        }
    }

    private func buttons(_ skills: [SkillDef], size: CGFloat) -> some View {
        ForEach(skills) { skill in
            SkillCommandButton(skill: skill, cost: cost(of: skill), usable: controller.canUse(skill), size: size,
                               picked: card == skill.id) {
                use(skill)
            } onHold: {
                show(skill)
            }
            .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
    }

    /// Whoever is choosing: your companion on its turn, else your hero.
    private var mp: Int { (controller.choosingForCompanion ? controller.companion?.mp : controller.hero?.mp) ?? 0 }

    private func level(of skill: SkillDef) -> Int {
        controller.choosingForCompanion ? controller.companionLevel(of: skill) : controller.level(of: skill)
    }

    private func cost(of skill: SkillDef) -> Int {
        controller.choosingForCompanion ? controller.companionCost(of: skill) : controller.cost(of: skill)
    }

    /// A greyed skill does nothing but say why (`BattleController.useSkill`: not the MP for it,
    /// nobody fainted to revive).
    private func use(_ skill: SkillDef) {
        hideCard?.cancel()
        card = nil
        if !controller.canUse(skill) { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        controller.useSkill(skill)
    }

    /// Its card, for a few seconds or until a skill is tapped.
    private func show(_ skill: SkillDef) {
        card = skill.id
        hideCard?.cancel()
        hideCard = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            card = nil
        }
    }
}

/// A skill as a round button in the battle's row (`SkillRow`), as big as the commands beside it:
/// its icon (art/sprites/skill_<id>.png, drawn as light on its tile's colour) cut round in a rim
/// of that colour, its MP in a badge on the rim and its name under it. Faded and grey when it
/// can't be used now. Holding it calls `onHold` (its card) instead of `action`.
struct SkillCommandButton: View {
    let skill: SkillDef
    let cost: Int
    let usable: Bool
    let size: CGFloat
    /// Its card is showing: a gold rim.
    var picked = false
    let action: () -> Void
    var onHold: (() -> Void)? = nil

    @State private var pressed = false
    /// Set by a hold, so letting go afterwards doesn't also count as a tap.
    @State private var held = false

    var body: some View {
        face
            .saturation(usable ? 1 : 0)
            .opacity(usable ? 1 : 0.45)
            .contentShape(Circle())
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .onTapGesture {
                if held { held = false } else { action() }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                guard let onHold else { return }
                held = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onHold()
            } onPressingChanged: { pressing in
                pressed = pressing
                if pressing { held = false }
            }
            .overlay(alignment: .bottom) {
                // Its name, as the commands have theirs; a long one cut short (the card has it whole).
                Text(skill.name)
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.cream.opacity(usable ? 1 : 0.6))
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
                    .frame(width: size * 1.15)
                    .offset(y: 15)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(skill.name)
            .accessibilityValue(L("{cost} MP", ["cost": cost]))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityAction(named: L("Skill details")) { onHold?() }
    }

    private var face: some View {
        ZStack {
            Circle().fill(Color(uiColor: skill.tileColor))
            if let picture = skill.art.flatMap(ArtLibrary.shared.artImage) {
                Image(uiImage: picture)
                    .interpolation(picture.size.width > 64 ? .high : .none)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 6, height: size - 6)
                    .clipShape(Circle())
            } else {
                IconImage(skill.icon.flatMap(GameIcon.init) ?? .sparkles, size: size * 0.56)
                    .foregroundStyle(.white)
                    .shadow(color: HUDStyle.ink.opacity(0.7), radius: 0, x: 0, y: 1)
            }
            // The commands' gloss.
            Ellipse().fill(.white.opacity(0.28))
                .frame(width: size * 0.5, height: size * 0.18)
                .offset(y: -size * 0.3)
            Circle().strokeBorder(picked ? AnyShapeStyle(HUDStyle.gold) : AnyShapeStyle(Color.white.opacity(0.75)),
                                  lineWidth: picked ? 3 : 2)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 4)
        .overlay(alignment: .topTrailing) {
            if cost > 0 {
                Text(verbatim: String(cost))
                    .font(HUDStyle.mono(max(8, size * 0.17)))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .frame(minWidth: size * 0.32, minHeight: size * 0.28)
                    .background(Capsule().fill(HUDStyle.mp).overlay(Capsule().strokeBorder(.white.opacity(0.85), lineWidth: 1)))
                    .offset(x: 3, y: -3)
            }
        }
    }
}

/// A held skill's card, over the row: its name, element and level, its MP (red when there isn't
/// enough) and what it does.
private struct SkillCard: View {
    let skill: SkillDef
    let level: Int
    let cost: Int
    let enoughMP: Bool

    /// The MP's blue, lighter to read on the navy.
    private static let mpLight = Color(red: 0.55, green: 0.78, blue: 1)
    private static let shortRed = Color(red: 1, green: 0.45, blue: 0.4)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let element = skill.element {
                    ElementIcon(element: element, size: 16)
                }
                Text(skill.name)
                    .font(HUDStyle.font(13))
                    .foregroundStyle(HUDStyle.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(L("Lv{level}", ["level": level]))
                    .font(HUDStyle.font(10).monospacedDigit())
                    .foregroundStyle(HUDStyle.cream)
                    .fixedSize()
                Spacer(minLength: 6)
                Text(L("{cost} MP", ["cost": cost]))
                    .font(HUDStyle.font(11).monospacedDigit())
                    .foregroundStyle(enoughMP ? Self.mpLight : Self.shortRed)
                    .fixedSize()
            }
            if let description = skill.description, !description.isEmpty {
                Text(description)
                    .font(HUDStyle.body(11))
                    .foregroundStyle(HUDStyle.cream.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HUDStyle.ink.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HUDStyle.gold.opacity(0.6), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}

/// The name and icon of a battle button id (see `GameSession.battleButtons`).
private struct BattleCommand {
    let title: String
    let icon: GameIcon

    init(_ id: String) {
        switch id {
        case "attack": title = L("Attack"); icon = .sword
        case "items": title = L("Items"); icon = .backpack
        case "guard": title = L("Guard"); icon = .shield
        case "run": title = L("Run"); icon = .wind
        case "capture": title = L("Capture"); icon = .sealStone
        default: title = L("More"); icon = .more
        }
    }
}

/// The home-screen wiggle for buttons being rearranged, each a little out of step with the others.
private struct Wiggle: ViewModifier {
    let active: Bool
    @State private var speed = Double.random(in: 0.11...0.15)

    // `Self.Content`: plain `Content` is the game's data store.
    func body(content: Self.Content) -> some View {
        content.phaseAnimator([false, true]) { view, tilted in
            view.rotationEffect(.degrees(active ? (tilted ? 2.5 : -2.5) : 0))
        } animation: { _ in
            .easeInOut(duration: speed)
        }
    }
}

/// Lays its views out in rows from the bottom-right corner: right to left, and when a row is full,
/// on up into the next one. Labels hang below the buttons, so rows leave room for them.
private struct RightToLeftRows: Layout {
    var spacing: CGFloat = 12
    var rowSpacing: CGFloat = 26

    private func rows(_ sizes: [CGSize], maxWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var width: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            let row = rows[rows.count - 1]
            let needed = row.isEmpty ? size.width : width + spacing + size.width
            if !row.isEmpty, needed > maxWidth {
                rows.append([index])
                width = size.width
            } else {
                rows[rows.count - 1].append(index)
                width = needed
            }
        }
        return rows
    }

    private func measure(_ subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    /// Without a width on offer, four buttons to a row.
    private func maxWidth(_ proposal: ProposedViewSize, _ sizes: [CGSize]) -> CGFloat {
        if let width = proposal.width, width.isFinite { return width }
        return 4 * (sizes.first?.width ?? 56) + 3 * spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = measure(subviews)
        guard !sizes.isEmpty else { return .zero }
        let rows = rows(sizes, maxWidth: maxWidth(proposal, sizes))
        let widths = rows.map { row in row.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(max(0, row.count - 1)) }
        let heights = rows.map { row in row.map { sizes[$0].height }.max() ?? 0 }
        return CGSize(width: widths.max() ?? 0, height: heights.reduce(0, +) + rowSpacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = measure(subviews)
        var y = bounds.maxY
        for row in rows(sizes, maxWidth: bounds.width) {
            var x = bounds.maxX
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .bottomTrailing, proposal: ProposedViewSize(sizes[index]))
                x -= sizes[index].width + spacing
            }
            y -= (row.map { sizes[$0].height }.max() ?? 0) + rowSpacing
        }
    }
}

struct RoundCommandButton: View {
    enum Tint {
        /// special glows gold (Capture); heal glows green (Items when HP is low); lit is a switch
        /// that's on (Auto, double pace), gold without the glow.
        case primary, normal, special, heal, quiet, lit
    }

    let title: String
    let icon: GameIcon
    let size: CGFloat
    let tint: Tint
    var onHold: (() -> Void)? = nil
    /// A word in the middle instead of the icon ("AUTO", "2×").
    var text: String? = nil
    let action: () -> Void

    @State private var pulse = false

    private var colors: [Color] {
        switch tint {
        case .primary: [Color(red: 1, green: 0.62, blue: 0.45), Color(red: 0.9, green: 0.3, blue: 0.3)]
        case .special, .lit: [Color(red: 1, green: 0.92, blue: 0.55), Color(red: 0.98, green: 0.68, blue: 0.2)]
        case .heal: [Color(red: 0.8, green: 1, blue: 0.75), Color(red: 0.3, green: 0.78, blue: 0.4)]
        case .normal, .quiet: HUDStyle.tile
        }
    }

    /// The HUD's own glossy blue, top to bottom, in its bevel (`FLIconButton`): the everyday
    /// commands and More, not cream (playtesting 2026-10-24: "the light yellow doesn't work").
    private var isBlue: Bool { tint == .normal || tint == .quiet }

    /// Buttons that want attention pulse with a coloured glow.
    private var glow: Color? {
        switch tint {
        case .special: HUDStyle.gold
        case .heal: HUDStyle.green
        default: nil
        }
    }

    /// A light button (gold, green), its icon on a pale ground.
    private var isLight: Bool {
        switch tint {
        case .special, .heal, .lit: true
        case .primary, .normal, .quiet: false
        }
    }

    private var foreground: Color {
        switch tint {
        case .primary, .normal, .quiet: .white
        case .special, .heal, .lit: HUDStyle.ink
        }
    }

    /// Under an icon: on the blue, the HUD buttons' hard dark blue edge; on a light button a crisp
    /// warm shadow (a soft dark rim round it looked muddy there).
    private var iconShadow: (color: Color, radius: CGFloat) {
        if isBlue { return (HUDStyle.frameDark, 0) }
        if isLight { return (Color(red: 0.43, green: 0.28, blue: 0.16).opacity(0.4), 0.4) }
        return (.clear, 0)
    }

    var body: some View {
        PressButton(action: action, onHold: onHold) {
            VStack(spacing: 1) {
                if let text {
                    Text(text)
                        .font(HUDStyle.font(size * 0.27))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                } else {
                    // Big: drawn as light, the icons washed out on the cream buttons at two fifths
                    // of them (playtesting 2026-10-24).
                    IconImage(icon, size: size * 0.56)
                        .shadow(color: iconShadow.color, radius: iconShadow.radius, x: isBlue ? 1 : 0, y: 1)
                }
                if size >= 80 {
                    Text(title).font(HUDStyle.font(12))
                }
            }
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isBlue ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(RadialGradient(colors: colors, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.75)))
                    .overlay(Circle().strokeBorder(isBlue ? AnyShapeStyle(HUDStyle.bevel) : AnyShapeStyle(Color.white.opacity(0.75)),
                                                   lineWidth: isBlue ? 2.5 : 2))
                    .overlay(
                        Ellipse().fill(.white.opacity(0.35))
                            .frame(width: size * 0.5, height: size * 0.2)
                            .offset(y: -size * 0.3)
                    )
            )
            .shadow(color: glow?.opacity(pulse ? 0.9 : 0.3) ?? .black.opacity(0.4),
                    radius: glow == nil ? 4 : (pulse ? 12 : 5), x: 0, y: glow == nil ? 4 : 0)
        }
        .overlay(alignment: .bottom) {
            if size < 80 {
                Text(title)
                    .font(HUDStyle.font(10))
                    .foregroundStyle(HUDStyle.cream)
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                    .fixedSize()
                    .offset(y: 15)
            }
        }
        .onAppear {
            guard glow != nil else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel(title)
    }
}

/// A button that shrinks while pressed; holding it calls `onHold` instead of `action`.
private struct PressButton<Label: View>: View {
    let action: () -> Void
    let onHold: (() -> Void)?
    @ViewBuilder let label: () -> Label
    @State private var pressed = false
    /// Set by a hold, so letting go afterwards doesn't also count as a tap.
    @State private var held = false

    var body: some View {
        label()
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .onTapGesture {
                if held { held = false } else { action() }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                guard let onHold else { return }
                held = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onHold()
            } onPressingChanged: { pressing in
                pressed = pressing
                if pressing { held = false }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityAction(named: L("Arrange buttons")) { onHold?() }
    }
}

private struct RoundPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Lists

private struct ChoiceCard<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowTitle(title, onClose: onBack)
            // Hug the rows; long lists scroll instead of growing past the scene.
            ScrollView {
                VStack(spacing: 6, content: content)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(max(contentHeight, 1), 220))
            .padding(HUDStyle.windowInset)
        }
        .frame(width: 300)
        .gameWindow()
        .popIn()
    }
}

private struct ChoiceRow<Label: View>: View {
    let action: () -> Void
    let enabled: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6, content: label)
                .font(HUDStyle.font(13))
                .foregroundStyle(HUDStyle.ink)
                .padding(.leading, 6)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(enabled ? HUDStyle.cream : HUDStyle.dim))
        }
        .buttonStyle(RoundPressStyle())
    }
}

// MARK: - Status & results

/// A scrolling column as tall as its content, up to the room there is: when it all fits it's just
/// the content, no fade and nothing to scroll. When it doesn't, its bottom fades out while there's
/// more below (the end scrolls up clear of the fade), and its scroll bar runs down the window's
/// edge: it reaches `edge` out past the content on each side, the window's padding.
private struct FittedScroll<Content: View>: View {
    var edge: CGFloat = 0
    @ViewBuilder let content: () -> Content
    /// How tall the fade at the bottom is.
    private static var fade: CGFloat { 36 }
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    /// How far it's scrolled down.
    @State private var scrolled: CGFloat = 0

    private var overflows: Bool { contentHeight > viewHeight + 1 }
    private var moreBelow: Bool { overflows && scrolled < contentHeight + Self.fade - viewHeight - 2 }

    var body: some View {
        ScrollView {
            content()
                .background(GeometryReader { proxy in
                    let frame = proxy.frame(in: .named("fittedScroll"))
                    Color.clear
                        .onAppear { contentHeight = frame.height; scrolled = -frame.minY }
                        .onChange(of: frame) { _, frame in
                            contentHeight = frame.height
                            scrolled = -frame.minY
                        }
                })
                .padding(.bottom, overflows ? Self.fade : 0)
                .padding(.horizontal, edge)
        }
        .coordinateSpace(name: "fittedScroll")
        .scrollBounceBehavior(.basedOnSize)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { viewHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in viewHeight = height }
        })
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, moreBelow ? .clear : .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.fade)
            }
        )
        // No taller than the content: a short list leaves the window short.
        .frame(maxHeight: contentHeight > 0 ? contentHeight : nil)
        .padding(.horizontal, -edge)
    }
}

private struct ResultPanel: View {
    /// The window's padding, which the rewards' scroll bar reaches out across to the edge.
    private static let inset: CGFloat = HUDStyle.windowInset
    let result: BattleResult
    let session: GameSession
    /// The names of everyone you fought, to tell who dropped what (`drops`).
    var foes: [String] = []
    let onContinue: () -> Void

    /// A boss's story first (the first time you beat it), then the summary; then, if needed, who
    /// stays behind (full party) and skill choices.
    private enum Stage { case story, summary, release, levelUp, companionLevelUp }
    @State private var stage: Stage
    /// The companion that grew and has a point to spend, its card after yours.
    @State private var companion: LevelUp?

    init(result: BattleResult, session: GameSession, foes: [String] = [], onContinue: @escaping () -> Void) {
        self.result = result
        self.session = session
        self.foes = foes
        self.onContinue = onContinue
        _stage = State(initialValue: result.story == nil ? .summary : .story)
    }

    private var title: String {
        switch result.outcome {
        case .victory: L("Victory!")
        case .fled: L("It got away…")
        case .defeat: L("Defeated…")
        case .escaped: L("Escaped")
        case .ongoing: ""
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            switch stage {
            case .story:
                if let story = result.story {
                    BossStoryCard(story: story, onDone: advance)
                        .transition(.opacity)
                }
            case .summary:
                summary
            case .release:
                LeaveBehindCard(session: session, onDone: advance)
                    .transition(.opacity)
            case .levelUp:
                if let level = result.newLevel {
                    LevelUpCard(session: session, level: level, onDone: advance)
                        .transition(.opacity)
                } else if result.masteryPoints > 0 {
                    LevelUpCard(session: session, level: session.data.hero.level, onDone: advance, mastery: result.masteryPoints)
                        .transition(.opacity)
                }
            case .companionLevelUp:
                if let companion, let petID = companion.petID {
                    LevelUpCard(session: session, level: companion.level, onDone: onContinue, owner: petID, name: companion.name)
                        .transition(.opacity)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage)
    }

    private func advance() {
        if stage == .story {
            stage = .summary
        } else if stage == .summary, session.pendingPet != nil {
            stage = .release
        } else if stage != .levelUp, stage != .companionLevelUp, result.newLevel != nil || result.masteryPoints > 0,
                  session.canSpendSkillPoint {
            stage = .levelUp
        } else if stage != .companionLevelUp,
                  let grown = result.others.first(where: { up in up.petID.map { session.companionCanSpendSkillPoint($0) } ?? false }) {
            // Your companion's skills to choose too, as yours (it's levelled up with you, or alone).
            companion = grown
            stage = .companionLevelUp
        } else {
            onContinue()
        }
    }

    private var summary: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(HUDStyle.title(26))
                .foregroundStyle(result.outcome == .victory ? HUDStyle.gold : HUDStyle.cream)
                // Clear of the close button, and still centred.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 18)
            // As tall as the rewards, scrolling only when they can't all fit (a big win, or a
            // phone on its side), with its scroll bar along the window's right edge.
            FittedScroll(edge: Self.inset) { details }
            Button(L("Continue"), action: advance)
                .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold))
                .padding(.top, 6)
        }
        .padding(Self.inset)
        .frame(maxWidth: 420)
        .gameWindow()
        // Closing it is Continue: the pay is already in your bag.
        .windowCloseButton(advance)
        .popIn()
        .padding(20)
    }

    /// Who dropped each thing found (item id to the monster's name), from the lines that said so
    /// ("Golden Hamster dropped Green Bamboo Staff!", `BattleController.concludeVictory`), and those
    /// lines, which the card leaves out: the finds' slots say it, under each (the user, 2026-11-19:
    /// the card listed every drop twice).
    private var drops: (sources: [String: String], told: Set<String>) {
        var sources: [String: String] = [:]
        var told: Set<String> = []
        let names = Array(Set(foes)).sorted()
        for entry in result.loot {
            guard let item = Content.shared.item(entry.id) else { continue }
            for name in names {
                let line = L("{name} dropped {item}!", ["name": name, "item": item.name])
                guard result.lines.contains(line) else { continue }
                if sources[entry.id] == nil { sources[entry.id] = name }
                told.insert(line)
            }
        }
        return (sources, told)
    }

    /// The pay, the level-up, what was found, and what else happened.
    private var details: some View {
        let found = self.drops
        return VStack(spacing: 10) {
            if result.exp > 0 || result.gold > 0 {
                HStack(spacing: 18) {
                    // None when you were out cold at the end (your friends won it).
                    if result.exp > 0 {
                        Label { Text(L("+{exp} EXP", ["exp": result.exp])) } icon: {
                            RewardStar()
                        }
                        // Always one line (playtesting 2026-10-30: it broke before EXP beside the coins).
                        .lineLimit(1)
                        .fixedSize()
                    }
                    GoldReward(amount: result.gold)
                }
                .font(HUDStyle.font(16))
                .foregroundStyle(HUDStyle.cream)
            }
            if result.exp > 0 {
                ExpGainBar(session: session, exp: result.exp, levels: result.levelsGained, masteryPoints: result.masteryPoints)
            }
            if let level = result.newLevel {
                LevelUpBanner(level: level, gains: session.heroClass.growth * result.levelsGained, after: session.heroStats)
            }
            if !result.others.isEmpty {
                PartyLevelUps(others: result.others)
            }
            if !result.loot.isEmpty {
                LootGrid(loot: result.loot, sources: found.sources)
            }
            if !result.newCards.isEmpty {
                NewCards(session: session, ids: result.newCards)
            }
            ForEach(Array(result.lines.filter { !found.told.contains($0) }.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(HUDStyle.font(13))
                    .foregroundStyle(HUDStyle.cream)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// A boss beaten for the first time: what the win means, told as a short story before the pay.
/// The boss in a ring of light over the title; the paragraphs come in one after another, at about
/// reading pace. A tap shows the rest at once; Continue goes on to the rewards.
private struct BossStoryCard: View {
    let story: BossStory
    let onDone: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many paragraphs are showing.
    @State private var shown = 0

    private var told: Bool { shown >= story.paragraphs.count }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape: the boss beside the story, so it all fits.
                HStack(spacing: 18) {
                    portrait(size: 80)
                    VStack(spacing: 10) {
                        heading
                        ViewThatFits(in: .vertical) {
                            paragraphs
                            ScrollView { paragraphs }
                                .scrollBounceBehavior(.basedOnSize)
                        }
                        continueButton
                    }
                }
            } else {
                VStack(spacing: 12) {
                    portrait(size: 96)
                    heading
                    paragraphs
                    continueButton
                }
            }
        }
        .padding(HUDStyle.windowInset)
        .frame(maxWidth: verticalSizeClass == .compact ? 620 : 420)
        .gameWindow()
        .contentShape(HUDStyle.windowShape)
        .onTapGesture { revealAll() }
        // Closing it skips the rest of the story, on to the rewards.
        .windowCloseButton(onDone)
        .popIn()
        .padding(20)
        .task { await tell() }
    }

    private func portrait(size: CGFloat) -> some View {
        SpriteImage(art: story.art, size: size)
            .frame(width: size + 16, height: size + 16)
            .background(
                Circle()
                    .fill(RadialGradient(colors: [HUDStyle.gold.opacity(0.3), HUDStyle.gold.opacity(0.04)],
                                         center: .center, startRadius: 0, endRadius: size * 0.6))
                    .overlay(Circle().strokeBorder(HUDStyle.gold.opacity(0.5), lineWidth: 1.5))
            )
            .accessibilityHidden(true)
    }

    /// The title, with a little star rule under it like a storybook chapter.
    private var heading: some View {
        VStack(spacing: 6) {
            Text(story.title)
                .font(HUDStyle.title(22))
                .foregroundStyle(HUDStyle.gold)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Capsule().fill(HUDStyle.gold.opacity(0.45)).frame(width: 44, height: 1.5)
                Text("✦").font(HUDStyle.font(11)).foregroundStyle(HUDStyle.gold.opacity(0.8))
                Capsule().fill(HUDStyle.gold.opacity(0.45)).frame(width: 44, height: 1.5)
            }
            .accessibilityHidden(true)
        }
    }

    /// Every paragraph takes its place from the start (unshown ones invisible), so nothing jumps.
    private var paragraphs: some View {
        VStack(spacing: 10) {
            ForEach(Array(story.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                Text(paragraph)
                    .font(HUDStyle.body(14))
                    .foregroundStyle(HUDStyle.cream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(index < shown ? 1 : 0)
                    .offset(y: index < shown ? 0 : 8)
            }
        }
    }

    private var continueButton: some View {
        Button(L("Continue")) {
            if told { onDone() } else { revealAll() }
        }
        .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold))
        .opacity(told ? 1 : 0.5)
        .padding(.top, 4)
    }

    /// One paragraph after another, each given time to be read (all at once with Reduce Motion).
    private func tell() async {
        if reduceMotion {
            shown = story.paragraphs.count
            return
        }
        var pause = 0.5
        for (index, paragraph) in story.paragraphs.enumerated() {
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled else { return }
            if shown <= index {
                withAnimation(.easeOut(duration: 0.8)) { shown = index + 1 }
            }
            pause = min(3.5, max(1.5, Double(paragraph.count) * 0.022))
        }
    }

    private func revealAll() {
        guard !told else { return }
        withAnimation(.easeOut(duration: 0.3)) { shown = story.paragraphs.count }
    }
}

/// What a win (or a quest) turned up, as little item tiles with how many and the name underneath,
/// each slot filling in turn with a pop (after SpriteCook's inventory article; the user picked it from
/// a mock-up, 2026-11-13): a rare find flashes sparkles in its rarity's colour and chimes, a
/// legendary one lights a warm glow behind the card. All at once with Reduce Motion.
struct LootGrid: View {
    let loot: [(id: String, count: Int)]
    var title = L("Found")
    /// Who dropped each (item id to a monster's name), in small dim letters under its name ("from
    /// Golden Hamster"); none for what no one in particular left.
    var sources: [String: String] = [:]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many slots have filled so far, the one whose sparkles are flying, and the legendary glow.
    @State private var shown = 0
    @State private var burst: Int?
    @State private var glow = 0.0

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(HUDStyle.font(11)).foregroundStyle(HUDStyle.gold)
            CenteredRows(spacing: 8, rowSpacing: 8) {
                ForEach(Array(loot.enumerated()), id: \.offset) { index, entry in
                    if let item = Content.shared.item(entry.id) {
                        let rarity = Content.shared.rarity(of: entry.id)
                        VStack(spacing: 3) {
                            ZStack {
                                // The empty slot it fills.
                                RoundedRectangle(cornerRadius: 40 * 0.26)
                                    .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .frame(width: 40, height: 40)
                                    .opacity(index < shown ? 0 : 1)
                                if index < shown {
                                    ItemIcon(item: item, size: 40, count: entry.count)
                                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                                }
                                if burst == index, let color = rarity.color {
                                    SparkleBurst(color: color)
                                }
                            }
                            .frame(width: 40, height: 40)
                            Text(item.name)
                                .font(HUDStyle.font(10))
                                .foregroundStyle(HUDStyle.cream)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .opacity(index < shown ? 1 : 0)
                            if let source = sources[entry.id] {
                                Text(L("from {name}", ["name": source]))
                                    .font(HUDStyle.font(10))
                                    .foregroundStyle(HUDStyle.dim)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                                    .opacity(index < shown ? 1 : 0)
                            }
                        }
                        .frame(width: 78)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(rarity == .common ? "" : rarity.name)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(GlassCard(radius: 12))
        .background {
            // A legendary find's warm glow behind the card.
            RadialGradient(colors: [Rarity.legendaryGlow, .clear], center: .center, startRadius: 10, endRadius: 190)
                .padding(-40)
                .opacity(glow)
                .allowsHitTesting(false)
        }
        .task { await reveal() }
    }

    /// Fills the slots one after another, a pop each, longer over a rare find's chime.
    private func reveal() async {
        guard shown == 0 else { return }
        guard !reduceMotion else {
            shown = loot.count
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        for index in loot.indices {
            let rarity = Content.shared.rarity(of: loot[index].id)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { shown = index + 1 }
            SoundEffects.shared.play(rarity == .legendary ? .lootLegend : rarity >= .rare ? .lootRare : .lootPop)
            if rarity >= .rare { burst = index }
            if rarity == .legendary {
                withAnimation(.easeOut(duration: 0.3)) { glow = 1 }
                withAnimation(.easeIn(duration: 1.6).delay(0.6)) { glow = 0.3 }
            }
            try? await Task.sleep(for: .milliseconds(rarity >= .rare ? 320 : 120))
        }
    }
}

/// Sparkles flying out of a slot as a rare find fills it (`LootGrid`), in its rarity's colour and white.
private struct SparkleBurst: View {
    let color: Color
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { k in
                let angle = Double(k) / 6 * 2 * Double.pi - Double.pi / 2
                IconImage(.sparkles, size: k % 2 == 0 ? 12 : 9)
                    .foregroundStyle(k % 2 == 0 ? color : Color.white)
                    .offset(x: out ? CGFloat(cos(angle) * 30) : 0, y: out ? CGFloat(sin(angle) * 30) : 0)
                    .scaleEffect(out ? 1 : 0.4)
                    .opacity(out ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { out = true } }
    }
}

/// Monster cards new to the Book after a win, face up, each with what it gives for good.
private struct NewCards: View {
    let session: GameSession
    let ids: [String]

    var body: some View {
        VStack(spacing: 6) {
            Text(ids.count == 1 ? L("New card!") : L("New cards!"))
                .font(HUDStyle.title(14))
                .foregroundStyle(HUDStyle.gold)
            CenteredRows(spacing: 10, rowSpacing: 8) {
                ForEach(ids, id: \.self) { id in
                    if let monster = session.content.monster(id) {
                        VStack(spacing: 4) {
                            MonsterCardFace(monster: monster, width: 56)
                            Text(session.cardGain(of: monster).bonusSummary)
                                .font(HUDStyle.font(10))
                                .foregroundStyle(HUDStyle.green)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Text(L("Kept in your Monster Book, for good."))
                .font(HUDStyle.font(10))
                .foregroundStyle(HUDStyle.dim)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(HUDStyle.gold.opacity(0.1)))
    }
}

/// Friends and your companion who went up a level with the win, each with their new level, in a
/// gold box like the hero's banner.
private struct PartyLevelUps: View {
    let others: [LevelUp]

    var body: some View {
        VStack(spacing: 6) {
            Text(others.count == 1 ? L("Level up!") : L("Level ups!"))
                .font(HUDStyle.title(14))
                .foregroundStyle(HUDStyle.gold)
            CenteredRows(spacing: 6, rowSpacing: 6) {
                ForEach(Array(others.enumerated()), id: \.offset) { _, other in
                    HStack(spacing: 4) {
                        IconImage(.arrowUp, size: 11)
                            .foregroundStyle(HUDStyle.gold)
                        Text(other.name)
                            .foregroundStyle(HUDStyle.cream)
                        Text(L("Lv {level}", ["level": other.level]))
                            .foregroundStyle(HUDStyle.gold)
                    }
                    .font(HUDStyle.font(12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(HUDStyle.gold.opacity(0.14)))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(HUDStyle.gold.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HUDStyle.gold.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(others.map { L("{name} reached level {level}", ["name": $0.name, "level": $0.level]) }.joined(separator: ". "))
    }
}

/// The EXP a win brought, on the victory card under "+31 EXP" (the user, 2026-11-19): the bar to your
/// next level filling from where it stood before the fight to where it stands now, rolling over for
/// each level gained, the level beside it ticking up as it does, and how much is left to the next
/// under it. At the level cap it's the mastery bar (`GameSession.masteryBar`), as the map's XP bar
/// is there: each full one a skill point. All at once with Reduce Motion.
private struct ExpGainBar: View {
    let session: GameSession
    /// What the fight brought, the levels it was worth and the skill points from mastery.
    let exp: Int
    let levels: Int
    let masteryPoints: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How full the bar shows, and the level beside it (nil till it starts playing).
    @State private var fill: CGFloat?
    @State private var shownLevel: Int?
    /// The level's little hop as the bar rolls over.
    @State private var bump = false

    /// A whole bar at `level`: to the next level, or the mastery bar at the cap.
    private static func barLength(_ level: Int) -> Int {
        level >= GameSession.levelCap ? GameSession.masteryBar : GameSession.expToNext(level: level)
    }

    private var level: Int { session.data.hero.level }
    private var atCap: Bool { level >= GameSession.levelCap }
    /// The level the fight started at.
    private var startLevel: Int { max(1, level - levels) }
    /// The times the bar fills up and starts again: each level, and each skill point from mastery.
    private var rolls: Int { levels + masteryPoints }

    /// Where the bar stood before the fight: the EXP now, plus what the levels and the skill points
    /// gained took off it (`GameSession.gainHeroEXP`), less what the fight brought.
    private var before: Int {
        var total = session.data.hero.exp + masteryPoints * GameSession.masteryBar
        for passed in startLevel..<level {
            total += GameSession.expToNext(level: passed)
        }
        return max(0, total - exp)
    }

    private func fraction(_ value: Int, at level: Int) -> CGFloat {
        let whole = Self.barLength(level)
        return whole > 0 ? min(1, max(0, CGFloat(value) / CGFloat(whole))) : 0
    }

    /// How much is left to fill: to the next level, or at the cap to the next skill point.
    private var caption: String {
        let left = max(0, Self.barLength(level) - session.data.hero.exp).formatted()
        return atCap ? L("{exp} to the next skill point", ["exp": left])
            : L("{exp} to level {level}", ["exp": left, "level": level + 1])
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text(L("Lv{level}", ["level": shownLevel ?? startLevel]))
                    .font(HUDStyle.font(11).monospacedDigit())
                    .foregroundStyle(bump ? HUDStyle.gold : HUDStyle.cream)
                    .scaleEffect(bump ? 1.2 : 1)
                    .fixedSize()
                GlossyBar(fraction: fill ?? fraction(before, at: startLevel), color: HUDStyle.exp, height: GlossyBar.progress)
            }
            Text(caption)
                .font(HUDStyle.font(10).monospacedDigit())
                .foregroundStyle(HUDStyle.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: 260)
        .task { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Level {level}", ["level": level]))
        .accessibilityValue(caption)
    }

    /// From before the fight to now: up to full and over for each roll (three at most played; a
    /// bigger jump lands on its last), then on to where the bar stands now.
    private func play() async {
        guard fill == nil else { return }
        let target = fraction(session.data.hero.exp, at: level)
        guard !reduceMotion else {
            fill = target
            shownLevel = level
            return
        }
        fill = fraction(before, at: startLevel)
        shownLevel = startLevel
        // While the card pops in.
        try? await Task.sleep(for: .milliseconds(450))
        let played = min(rolls, 3)
        for step in 0..<played {
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.45)) { fill = 1 }
            try? await Task.sleep(for: .milliseconds(480))
            guard !Task.isCancelled else { return }
            // Empty again at once, the level ticking up.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                fill = 0
                shownLevel = step == played - 1 ? level : min(level, (shownLevel ?? startLevel) + 1)
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bump = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.25)) { bump = false }
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.6)) { fill = target }
    }
}

/// A level-up, made a fuss of on the victory and quest cards: the new level on a gold medal in a
/// slowly turning sunburst, stars flying off it, "LEVEL UP!", and what the new levels raised.
struct LevelUpBanner: View {
    let level: Int
    /// What the levels raised: the class's growth for each level gained.
    let gains: Stats
    /// The stats now, with the levels in them (`GameSession.heroStats`): given, each raised stat
    /// shows from what it was to what it is ("ATK 24 → 26", the user, 2026-11-19), else only what
    /// it gained ("ATK +2").
    var after: Stats? = nil
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var burst = false

    /// The stats that went up, in the Character tab's order, with what each is now (nil without `after`).
    private var raised: [(label: String, value: Int, now: Int?)] {
        let all: [(label: String, value: Int, now: Int?)] = [
            (L("HP"), gains.hp, after?.hp), (L("MP"), gains.mp, after?.mp), (L("ATK"), gains.attack, after?.attack),
            (L("DEF"), gains.defense, after?.defense), (L("MAG"), gains.magic, after?.magic), (L("SPD"), gains.speed, after?.speed),
        ]
        return all.filter { $0.value > 0 }
    }

    /// On its side, the gains in one line: "ATK 24 → 26  DEF 18 → 19", or "+2 ATK, +1 DEF" without `after`.
    private var summaryLine: String {
        guard after != nil else { return gains.bonusSummary }
        return raised.map { stat in
            stat.now.map { "\(stat.label) \($0 - stat.value) → \($0)" } ?? "\(stat.label) +\(stat.value)"
        }.joined(separator: "   ")
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape: the medal beside the words, so the card still fits the screen.
                HStack(spacing: 16) {
                    medal(size: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        title(size: 22)
                        Text(summaryLine)
                            .font(HUDStyle.font(11).monospacedDigit())
                            .foregroundStyle(HUDStyle.green)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    medal(size: 66)
                    title(size: 28)
                    CenteredRows(spacing: 5, rowSpacing: 5) {
                        ForEach(Array(raised.enumerated()), id: \.offset) { _, stat in
                            chip(stat.label, stat.value, now: stat.now)
                        }
                    }
                    Text(L("HP and MP fully restored"))
                        .font(HUDStyle.font(10))
                        .foregroundStyle(HUDStyle.dim)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(HUDStyle.gold.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HUDStyle.gold.opacity(0.55), lineWidth: 1.5))
        .scaleEffect(shown ? 1 : 0.6)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.15)) { shown = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.3)) { burst = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Level up! You're now level {level}. {bonuses}", ["level": level, "bonuses": gains.bonusSummary]))
    }

    private func medal(size: CGFloat) -> some View {
        ZStack {
            TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) / 20
                // A soft glow, not a stark one: faint where it leaves the medal, mostly gone halfway
                // out, its wedges' edges blurred into the window's blue.
                Sunburst(rays: 14)
                    .fill(RadialGradient(stops: [
                        .init(color: HUDStyle.gold.opacity(0.38), location: 0.4),
                        .init(color: HUDStyle.gold.opacity(0.14), location: 0.65),
                        .init(color: HUDStyle.gold.opacity(0.04), location: 0.85),
                        .init(color: HUDStyle.gold.opacity(0), location: 1),
                    ], center: .center, startRadius: 0, endRadius: size * 1.2))
                    .frame(width: size * 2.4, height: size * 2.4)
                    .blur(radius: size * 0.04)
                    .rotationEffect(.degrees(turn * 360))
            }
            // Stars fly off from behind the medal as it lands.
            ForEach(0..<8, id: \.self) { index in
                IconImage(.star, size: size * 0.18)
                    .foregroundStyle(index % 2 == 0 ? HUDStyle.cream : HUDStyle.gold)
                    .offset(burst ? Self.flight(of: index, radius: size) : .zero)
                    .opacity(burst ? 0 : 1)
            }
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.97, blue: 0.75), HUDStyle.gold, HUDStyle.orange],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.75))
                .overlay(Circle().strokeBorder(HUDStyle.cream, lineWidth: 2.5))
                .shadow(color: HUDStyle.gold.opacity(0.9), radius: 10)
                .frame(width: size, height: size)
            VStack(spacing: -4) {
                Text(L("LV")).font(HUDStyle.title(size * 0.19))
                Text("\(level)")
                    .font(HUDStyle.title(size * 0.42))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .foregroundStyle(HUDStyle.ink)
            .padding(.horizontal, size * 0.1)
        }
        .frame(width: size, height: size)
    }

    /// Where star `index` of eight ends up, all the way round the medal.
    private static func flight(of index: Int, radius: CGFloat) -> CGSize {
        let angle = CGFloat(index) / 8 * 2 * .pi
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius * 0.8)
    }

    private func title(size: CGFloat) -> some View {
        Text(L("LEVEL UP!"))
            .font(HUDStyle.title(size))
            .foregroundStyle(HUDStyle.gold)
            .shadow(color: HUDStyle.orange.opacity(0.9), radius: 0, x: 2, y: 2)
    }

    /// "ATK 24 → 26" (or "ATK +2" without what it is now): one raised stat, in a little dark pill,
    /// what it was dim and what it is green.
    private func chip(_ label: String, _ value: Int, now: Int?) -> some View {
        let change: Text = now.map { now in
            Text(verbatim: "\(now - value) → ").foregroundStyle(HUDStyle.dim) + Text(verbatim: "\(now)").foregroundStyle(HUDStyle.green)
        } ?? Text(verbatim: "+\(value)").foregroundStyle(HUDStyle.green)
        let text: Text = Text(label + " ").foregroundStyle(HUDStyle.cream) + change
        return text
            .font(HUDStyle.font(11).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(HUDStyle.ink.opacity(0.7)))
    }
}

/// Wedges of light round the middle, like a sunburst.
private nonisolated struct Sunburst: Shape {
    var rays = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) / 2
        let step = 2 * CGFloat.pi / CGFloat(rays)
        for index in 0..<rays {
            let angle = step * CGFloat(index)
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: Angle(radians: Double(angle - step / 4)),
                        endAngle: Angle(radians: Double(angle + step / 4)), clockwise: false)
            path.closeSubpath()
        }
        return path
    }
}

/// Wraps its views into rows like text, each row centred.
private struct CenteredRows: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    private func rows(_ sizes: [CGSize], maxWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var width: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            let row = rows[rows.count - 1]
            let needed = row.isEmpty ? size.width : width + spacing + size.width
            if !row.isEmpty, needed > maxWidth {
                rows.append([index])
                width = size.width
            } else {
                rows[rows.count - 1].append(index)
                width = needed
            }
        }
        return rows
    }

    private func rowWidth(_ row: [Int], _ sizes: [CGSize]) -> CGFloat {
        row.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(max(0, row.count - 1))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        guard !sizes.isEmpty else { return .zero }
        let maxWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .infinity
        let rows = rows(sizes, maxWidth: maxWidth)
        let heights = rows.map { row in row.map { sizes[$0].height }.max() ?? 0 }
        let widest = rows.map { rowWidth($0, sizes) }.max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest,
                      height: heights.reduce(0, +) + rowSpacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for row in rows(sizes, maxWidth: bounds.width) {
            let height = row.map { sizes[$0].height }.max() ?? 0
            var x = bounds.midX - rowWidth(row, sizes) / 2
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += height + rowSpacing
        }
    }
}

/// What a treasure chest held, as a battle's pay is shown (the user, 2026-11-18: "the same modal
/// window with the items/coins as the modal window after a fight"): its gold, and the item in a
/// slot that fills (`LootGrid`).
struct TreasureCard: View {
    let chest: String
    /// The chest's own picture, over its name (the user, 2026-11-18: "it should show the treasure
    /// visual as well").
    let art: String
    let item: String
    let gold: Int
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture {}
            VStack(spacing: 10) {
                SpriteImage(art: art, size: 72)
                    .padding(.top, 4)
                VStack(spacing: 2) {
                    Text(L("Treasure!"))
                        .font(HUDStyle.title(26))
                        .foregroundStyle(HUDStyle.gold)
                        // Clear of the close button, and still centred.
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 18)
                    Text(chest)
                        .font(HUDStyle.font(12))
                        .foregroundStyle(HUDStyle.cream)
                }
                if gold > 0 {
                    GoldReward(amount: gold)
                        .font(HUDStyle.font(16))
                        .foregroundStyle(HUDStyle.cream)
                }
                LootGrid(loot: [(id: item, count: 1)])
                Button(L("Continue"), action: onClose)
                    .buttonStyle(PixelButtonStyle(tint: HUDStyle.gold))
                    .padding(.top, 6)
            }
            .padding(HUDStyle.windowInset)
            .frame(maxWidth: 420)
            .gameWindow()
            .windowCloseButton(onClose)
            .popIn()
            .padding(20)
        }
    }
}
