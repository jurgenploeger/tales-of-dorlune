import SwiftUI

/// The carved-wood HUD's pieces (tools/hud_game_art.py, `Assets.xcassets/Wood`): ChatGPT's drawings at 3
/// pixels a point, each with its Dark Mode twin, which the catalog swaps as the look changes (the user's
/// pick, direction A "Birch & Leaf", 2026-11-27; docs/ai-sprite-test/hud/HANDOVER.md).
enum WoodArt {
    /// The round button with its enamel picture for `icon`, or nil where none is drawn (it keeps its
    /// pixel icon on the plain round, `WoodButtonRound`). In battle the Bag is Items' potion.
    static func button(for icon: GameIcon, inBattle: Bool = false) -> String? {
        switch icon {
        case .talk: "WoodButtonChat"
        case .backpack: inBattle ? "WoodButtonItems" : "WoodButtonInventory"
        case .user: "WoodButtonCharacter"
        case .paw: "WoodButtonCompanions"
        case .users: "WoodButtonFriends"
        case .star: inBattle ? nil : "WoodButtonQuests"
        case .settings: "WoodButtonSettings"
        case .map: "WoodButtonWorldMap"
        case .sword: "WoodButtonAttack"
        case .wind: "WoodButtonRunAway"
        case .sparkles: inBattle ? "WoodButtonSpells" : nil
        default: nil
        }
    }
}

/// A window's carved frame, over its pane: corners 21 points, each rail one carved motif tiled whole
/// (`WoodWindowFrame`, a nine-slice; its pane cut out).
struct WoodFrame: View {
    var body: some View {
        Image("WoodWindowFrame")
            .resizable(capInsets: EdgeInsets(top: 64.0 / 3, leading: 64.0 / 3, bottom: 64.0 / 3, trailing: 64.0 / 3),
                       resizingMode: .tile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A round carved button's face, `size` across: its picture (`WoodArt.button`), or the plain round
/// with `icon` over it; pressed, the pressed drawing.
struct WoodButtonFace: View {
    let icon: GameIcon
    let size: CGFloat
    var pressed = false
    var inBattle = false

    var body: some View {
        if let name = WoodArt.button(for: icon, inBattle: inBattle) {
            Image(pressed ? name + "Pressed" : name)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(pressed ? "WoodButtonRoundPressed" : "WoodButtonRound")
                .resizable()
                .frame(width: size, height: size)
                .overlay {
                    IconImage(icon, size: (size * 0.5).rounded())
                        .foregroundStyle(HUDStyle.ink)
                }
        }
    }
}

/// A carved button pressed: its pressed drawing over it, a touch smaller.
struct WoodPressStyle: ButtonStyle {
    let pressed: String
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Image(pressed).resizable().frame(width: size, height: size)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A round carved button that shows its own pressed drawing (`WoodButtonFace`).
struct WoodRoundButtonStyle: ButtonStyle {
    let icon: GameIcon
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(alignment: .top) {
                if configuration.isPressed { WoodButtonFace(icon: icon, size: size, pressed: true) }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
