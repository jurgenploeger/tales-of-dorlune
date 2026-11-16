import SwiftUI

/// The map's chat window: everything adventurers, villagers and NPCs have said here, the game's
/// announcements, and a box to say something yourself (someone might answer).
struct ChatView: View {
    let session: GameSession
    let onSay: (String) -> Void
    let onClose: () -> Void
    /// For an adventurer's profile, opened over the chat from their face or name.
    var coordinator: GameCoordinator? = nil
    /// The adventurer whose profile is open over the chat.
    @State private var profile: Adventurer?
    /// How far down the list's foot is in the scroll view, and how tall the scroll view is: whether
    /// the latest line is in sight (`atLatest`).
    @State private var footY: CGFloat = 0
    @State private var shownHeight: CGFloat = 0
    /// Lines said since you scrolled up from the latest, counted on the button back down.
    @State private var unseen = 0
    @State private var draft = ""
    @FocusState private var typing: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                WindowTitle(L("Chat · {map}", ["map": session.mapName]), onClose: onClose)
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(session.chat) { line in
                                ChatLineView(line: line) { person in
                                    withAnimation(.easeOut(duration: 0.2)) { profile = person }
                                }
                                .id(line.id)
                            }
                            // The list's foot, to tell whether you've scrolled up from the latest.
                            Color.clear
                                .frame(height: 1)
                                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.scroll)).minY } action: { footY = $0 }
                        }
                        .padding(HUDStyle.windowInset)
                    }
                    .coordinateSpace(name: Self.scroll)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                    // What you type stands over the bottom of the lines, which scroll on under it (`composer`).
                    .safeAreaInset(edge: .bottom, spacing: 0) { composer(reader) }
                    .animation(.easeOut(duration: 0.2), value: atLatest)
                    // Short, it starts at the top (anchored to the bottom, a few lines sat at the foot
                    // under empty glass); opened, and as lines come in, it shows the latest (the user,
                    // 2026-11-16: "The chat should start from the top here. Then when new messages come
                    // in, it stays pinned at the latest").
                    .onAppear {
                        if let last = session.chat.last?.id { reader.scrollTo(last, anchor: .bottom) }
                    }
                    .onChange(of: session.chat.last?.id) {
                        session.unreadChat = 0
                        // Only while you're at the latest: scrolled up to read, a new line doesn't pull
                        // you down, it's counted on the button back down (the user, 2026-11-16); what
                        // you say yourself does take you down.
                        let yours = session.chat.last?.kind == .you
                        guard atLatest || yours, let last = session.chat.last?.id else {
                            unseen += 1
                            return
                        }
                        withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(last, anchor: .bottom) }
                    }
                    .onChange(of: atLatest) { _, latest in if latest { unseen = 0 } }
                }
                .frame(maxHeight: .infinity)

            }
            // As big as the menu's windows (playtesting 2026-10-25: "Make the chat modal the same size as
            // the other modals"): out to the HUD's own margins (`HUDMargins`).
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gameWindow()
            .popIn()
            .padding(.horizontal, HUDMargins.side)
            .padding(.top, HUDMargins.side)
            .padding(.bottom, HUDMargins.bottom(onItsSide: verticalSizeClass == .compact))
            .ignoresSafeArea(.container, edges: HUDMargins.bottomEdge(onItsSide: verticalSizeClass == .compact))
        }
        // Their profile over the chat, which shows again as it closes (the user, 2026-11-16: "When
        // tapping on the name and avatar, it should open their profile above the chat").
        .overlay {
            if let person = profile, let coordinator {
                ProfileWindow(coordinator: coordinator, person: person) {
                    withAnimation(.easeOut(duration: 0.2)) { profile = nil }
                }
                .transition(.opacity)
            }
        }
        .onAppear { session.unreadChat = 0 }
    }

    /// What you type and Send, over the bottom of the lines on a blur that fades in from above (the
    /// user, 2026-11-16: "There should be a progressive gradient blur behind the chat composer"), and,
    /// scrolled up from the latest, a button back down over Send with how many lines came in since.
    private func composer(_ reader: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            TextField(L("Say something…"), text: $draft)
                .font(HUDStyle.font(13))
                .foregroundStyle(HUDStyle.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(HUDStyle.cream))
                .focused($typing)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                IconImage(.arrowRight, size: 18)
                    .foregroundStyle(HUDStyle.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(HUDStyle.gold).overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(L("Send"))
        }
        .padding(HUDStyle.windowInset)
        .background(alignment: .bottom) {
            // Blurred under the bar, fading out above it, and a little darker toward the foot.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(LinearGradient(colors: [HUDStyle.ink.opacity(0), HUDStyle.ink.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.4),
                                             .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
                .padding(.top, -28)
                .allowsHitTesting(false)
        }
        // Scrolled up, a button back down to the latest, over Send (the user, 2026-11-16: "When scrolling
        // up in the chat, there should be an arrow down button in the bottom right (aligned with the
        // send button)"), with how many lines came in since.
        .overlay(alignment: .topTrailing) {
            if !atLatest {
                Button {
                    guard let last = session.chat.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo(last, anchor: .bottom) }
                } label: {
                    IconImage(.arrowDown, size: 18)
                        .foregroundStyle(HUDStyle.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(HUDStyle.gold)
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)))
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                        .overlay(alignment: .topTrailing) {
                            if unseen > 0 { CountBadge(count: unseen).offset(x: 6, y: -6) }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .padding(.trailing, HUDStyle.windowInset)
                .offset(y: -46)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel(L("Latest messages"))
                .accessibilityValue(unseen > 0 ? "\(unseen)" : "")
            }
        }
    }

    /// The scroll view, for where the list's foot is in it.
    private static var scroll: String { "ChatView.scroll" }

    /// Whether the latest line is in sight: the list's foot no lower than the scroll view's own,
    /// give or take a line's worth.
    private var atLatest: Bool { shownHeight <= 0 || footY <= shownHeight + 60 }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSay(String(text.prefix(80)))
        draft = ""
    }
}

struct ChatLineView: View {
    let line: GameSession.ChatLine
    /// An adventurer's face or name tapped: their profile.
    var onProfile: (Adventurer) -> Void = { _ in }

    private var color: Color {
        switch line.kind {
        case .you: HUDStyle.gold
        case .adventurer: Color(uiColor: Crowd.adventurerColor)
        case .villager: HUDStyle.cream
        case .npc: HUDStyle.green
        case .system: HUDStyle.dim
        case .announcement: HUDStyle.gold
        case .notice: ChatLineView.color(of: line.tone ?? .system)
        }
    }

    /// A notice's colour, by its kind of news: as the HUD's toasts mark it (`WorldHUD`).
    static func color(of tone: GameSession.LogLine.Kind) -> Color {
        switch tone {
        case .system: HUDStyle.nameYellow
        case .quest: Color(red: 0.55, green: 0.95, blue: 1)
        case .battle: .white
        case .reward: HUDStyle.green
        case .announcement: HUDStyle.gold
        }
    }

    /// A notice's mark, by its kind of news.
    static func icon(of tone: GameSession.LogLine.Kind) -> GameIcon {
        switch tone {
        case .system: .sparkles
        case .quest: .star
        case .battle: .sword
        case .reward: .gift
        case .announcement: .sparkles
        }
    }

    var body: some View {
        switch line.kind {
        case .system:
            ruled {
                Text(line.text)
                    .font(HUDStyle.font(11))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
            }
        case .announcement:
            // The game's own notices: a gold banner, apart from what people say.
            // Centred on a soft gold plate, no rim, as round as the window's cards (the user, 2026-11-16).
            HStack(alignment: .top, spacing: 7) {
                IconImage(.sparkles, size: 14)
                    .foregroundStyle(HUDStyle.gold)
                Text(line.text)
                    .font(HUDStyle.font(12))
                    .foregroundStyle(HUDStyle.gold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HUDStyle.gold.opacity(0.15)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("Announcement: {text}", ["text": line.text]))
        case .notice:
            // What happened to you lately, toasted on the map first.
            ruled {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    IconImage(ChatLineView.icon(of: line.tone ?? .system), size: 11)
                        .foregroundStyle(color)
                    Text(line.text)
                        .font(HUDStyle.font(11))
                        .foregroundStyle(color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .you, .adventurer, .villager, .npc:
            // Their face, then their name, BOT after it and the time at the right, and what they said
            // under it (the user, 2026-11-16). An adventurer's face and name open their profile.
            HStack(alignment: .top, spacing: 8) {
                who { ChatFace(art: line.art, size: 30) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        who {
                            Text(line.speaker)
                                .font(HUDStyle.font(12))
                                .foregroundStyle(color)
                                .lineLimit(1)
                        }
                        if let badge = line.badge {
                            NameBadge(badge: badge)
                        }
                        Spacer(minLength: 6)
                        Text(line.time, format: .dateTime.hour().minute())
                            .font(HUDStyle.font(10))
                            .foregroundStyle(HUDStyle.dim)
                            .monospacedDigit()
                    }
                    Text(line.text)
                        .font(HUDStyle.font(12))
                        .foregroundStyle(HUDStyle.cream)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 3)
            .accessibilityElement(children: .combine)
        }
    }

    /// What happened, not said by anyone (`.system`, `.notice`): centred between two thin rules in its
    /// own colour, running out to the window's sides (the user, 2026-11-16: "add horizontal lines left
    /// and right of those labels").
    private func ruled<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        HStack(spacing: 8) {
            rule
            label().layoutPriority(1)
            rule
        }
        .frame(maxWidth: .infinity)
    }

    private var rule: some View {
        color.opacity(0.22).frame(minWidth: 12, maxWidth: .infinity).frame(height: 1)
    }

    /// Their face or name: a button to their profile, for an adventurer.
    @ViewBuilder
    private func who<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        if let person = line.adventurer {
            Button { onProfile(person) } label: { label() }
                .buttonStyle(.plain)
                .accessibilityLabel(L("{name}'s stats", ["name": person.name]))
        } else {
            label()
        }
    }
}

/// Someone's face by what they said in the chat: their picture's head in a small round, as a quest
/// giver's is (`GiverFace`); a plain round for someone with no picture.
private struct ChatFace: View {
    let art: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let art {
                Image(uiImage: ArtLibrary.shared.face(art))
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
        .overlay(Circle().strokeBorder(HUDStyle.bevel, lineWidth: 1.5))
    }
}
