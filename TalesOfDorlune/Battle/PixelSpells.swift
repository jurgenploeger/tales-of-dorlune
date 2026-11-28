import SpriteKit

/// A skill drawn as pixel art in battle (ChatGPT's effect sheets, tools/spell_effect_art.py): the cast
/// round the caster, the bolt flying to the target when it has one, and the impact on the target, each a
/// strip of 64-pixel frames (`art/sprites/spell_<skill>_cast.png`, `_fly`, `_flyup`, `_impact`). In place of
/// the glows (`SkillEffects`) for every skill that has one; `BattleScene.castPixel` plays it.
struct PixelSpell {
    let cast: [SKTexture]
    let fly: [SKTexture]?
    let flyUp: [SKTexture]?
    let impact: [SKTexture]

    /// How long each frame shows.
    static let frameTime: TimeInterval = 0.06

    private static var known: [String: PixelSpell?] = [:]

    /// The skill's effect, or nil when it has none drawn (it keeps its glows).
    static func of(_ skillID: String) -> PixelSpell? {
        if let found = known[skillID] { return found }
        var made: PixelSpell?
        if let cast = frames("spell_\(skillID)_cast"), let impact = frames("spell_\(skillID)_impact") {
            made = PixelSpell(cast: cast, fly: frames("spell_\(skillID)_fly"), flyUp: frames("spell_\(skillID)_flyup"), impact: impact)
        }
        known[skillID] = made
        return made
    }

    /// A strip's square frames, left to right.
    private static func frames(_ id: String) -> [SKTexture]? {
        guard let image = ArtLibrary.shared.artImage(id)?.cgImage, image.height > 0 else { return nil }
        let count = image.width / image.height
        guard count > 0 else { return nil }
        let sheet = SKTexture(cgImage: image)
        sheet.filteringMode = .nearest
        return (0..<count).map { index in
            let texture = SKTexture(rect: CGRect(x: CGFloat(index) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1), in: sheet)
            texture.filteringMode = .nearest
            return texture
        }
    }

    /// Plays `frames` once at `point`, `scale` points to its pixel, then takes it away; how long it plays.
    @discardableResult
    static func play(_ frames: [SKTexture], at point: CGPoint, scale: CGFloat, in stage: SKNode) -> TimeInterval {
        guard let first = frames.first else { return 0 }
        let node = SKSpriteNode(texture: first, size: CGSize(width: 64 * scale, height: 64 * scale))
        node.position = point
        node.zPosition = 20_000
        stage.addChild(node)
        node.run(.sequence([.animate(with: frames, timePerFrame: frameTime), .removeFromParent()]))
        return Double(frames.count) * frameTime
    }

    /// The bolt flying from `from` to `to`, its frames looping on the way, turned to its course (mirrored,
    /// not turned upside down, going left or down); how long it flies. Nil-free: 0 without a bolt.
    func fly(from: CGPoint, to: CGPoint, scale: CGFloat, in stage: SKNode) -> TimeInterval {
        let dx = to.x - from.x, dy = to.y - from.y
        let upward = abs(dy) > abs(dx)
        guard let frames = (upward ? flyUp ?? fly : fly ?? flyUp), let first = frames.first else { return 0 }
        let vertical = frames.first === flyUp?.first
        let node = SKSpriteNode(texture: first, size: CGSize(width: 64 * scale, height: 64 * scale))
        let course = atan2(dy, dx)
        if vertical {
            if dy < 0 { node.yScale = -1 }
            node.zRotation = dy < 0 ? course + .pi / 2 : course - .pi / 2
        } else {
            if dx < 0 { node.xScale = -1 }
            node.zRotation = dx < 0 ? course - (course > 0 ? .pi : -.pi) : course
        }
        node.position = from
        node.zPosition = 20_000
        stage.addChild(node)
        let duration = max(0.25, min(0.5, Double(hypot(dx, dy)) / 700))
        node.run(.repeatForever(.animate(with: frames, timePerFrame: Self.frameTime)))
        node.run(.sequence([.move(to: to, duration: duration), .removeFromParent()]))
        return duration
    }
}
