import SpriteKit
import UIKit

/// An emote: a little speech bubble with a picture in it, popped over someone's head for a few seconds
/// (the user, 2026-11-17: "Can we add these emote/reactions features to the game?"). You pick one by the
/// chat's box (`ChatView`); the adventurers round you use them too, and answer yours (`Crowd.answer`).
/// Drawn by `tools/emote_art.py` (`art/sprites/emote_<name>.png`), shown as drawn, not graded by a land.
enum Emote: String, CaseIterable, Identifiable {
    case heart, wave, happy, laugh, exclaim, question, dots, idea, music, check, sweat, sleep, gloom, sun, anger

    var id: String { rawValue }

    /// What it says, for VoiceOver and the picker.
    var label: String {
        switch self {
        case .heart: L("Love")
        case .wave: L("Wave")
        case .happy: L("Happy")
        case .laugh: L("Laugh")
        case .exclaim: L("Surprised")
        case .question: L("Puzzled")
        case .dots: L("Thinking")
        case .idea: L("Idea")
        case .music: L("Singing")
        case .check: L("Agreed")
        case .sweat: L("Nervous")
        case .sleep: L("Sleepy")
        case .gloom: L("Gloomy")
        case .sun: L("Sunny")
        case .anger: L("Angry")
        }
    }

    /// Its picture, as drawn.
    var image: UIImage? { ArtLibrary.shared.artImage("emote_" + rawValue) }

    /// Its picture for the map, hard-edged; nil if it isn't drawn.
    var texture: SKTexture? {
        if let known = Self.textures[self] { return known }
        guard let picture = image?.cgImage else { return nil }
        let texture = SKTexture(cgImage: picture)
        texture.filteringMode = .nearest
        Self.textures[self] = texture
        return texture
    }
    private static var textures: [Emote: SKTexture] = [:]

    /// The emote someone answers this one with: a heart for a heart, a wave for a wave, a laugh at a
    /// laugh, a question met with thinking.
    var answer: Emote {
        switch self {
        case .heart: .heart
        case .wave: .wave
        case .happy, .laugh, .music: [.laugh, .happy, .music].randomElement() ?? .happy
        case .exclaim: .question
        case .question: .dots
        case .dots, .idea: .idea
        case .check: .check
        case .sweat, .gloom: .sweat
        case .sleep: .sleep
        case .sun: .sun
        case .anger: .sweat
        }
    }
}
