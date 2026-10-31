import SpriteKit

/// A waystone carrying you off and setting you down (playtesting 2026-10-31: "The waystone teleports
/// need a different animation, more magical"), in the waystone's own cyan and a violet:
///
/// - away: a ring of runes opens on the ground under you, the stone flares and sends motes of light
///   to you, more rise spiralling round you as a pillar of light comes up, and you turn to light,
///   stretch up into the pillar and are gone in a flash and a burst of sparks;
/// - arriving: the same backward, in the ring at the other stone: a flash, the pillar, sparks
///   gathering in, and you coming out of the light, the ring closing behind you.
///
/// Shared by the continent (`ContinentScene`) and a cave or a land's own scene (`WorldScene`), drawn
/// in whatever node the hero walks in.
@MainActor
enum WaystoneMagic {
    /// The waystone's cyan (its role's colour on the HUD) and the violet its light turns at the edges.
    static let light = UIColor(red: 0.4, green: 0.95, blue: 1, alpha: 1)
    static let violet = UIColor(red: 0.62, green: 0.5, blue: 1, alpha: 1)
    /// Away: the gathering, then you're gone; arriving takes about as long.
    static let gather = 1.15, vanish = 0.45
    static var length: Double { gather + vanish }
    static let arrival = 1.3
    /// How high you stretch up into the pillar as you go.
    private static let rise: CGFloat = 26
    private static let z: CGFloat = 30_000

    // MARK: Away

    /// Takes `player` away from `stone` (the waystone's place, if it's known), drawn in `parent`, then `done`.
    static func away(_ player: Walker, from stone: CGPoint?, in parent: SKNode, then done: @escaping () -> Void) {
        let feet = player.position
        let ring = runeRing(at: feet, in: parent)
        ring.setScale(0.2)
        ring.alpha = 0
        ring.run(.group([.fadeIn(withDuration: 0.35), .scale(to: 1, duration: 0.45)]))
        ring.run(.sequence([.wait(forDuration: length), .group([.fadeOut(withDuration: 0.5), .scale(to: 1.25, duration: 0.5)]), .removeFromParent()]))
        if let stone { flare(stone, toward: feet, in: parent) }
        motes(around: feet, in: parent, rising: true, count: 16, over: gather)
        let pillar = pillar(at: feet, in: parent)
        pillar.alpha = 0
        pillar.xScale = 0.4
        pillar.run(.sequence([
            .wait(forDuration: gather * 0.45),
            .group([.fadeAlpha(to: 0.85, duration: gather * 0.55), .scaleX(to: 1, duration: gather * 0.55)]),
            .group([.fadeOut(withDuration: vanish + 0.3), .scaleX(to: 0.15, duration: vanish + 0.3)]),
            .removeFromParent(),
        ]))
        // You glow, then turn to light and stretch up into the pillar, and you're gone.
        let sprite = player.sprite
        sprite.color = light
        sprite.run(.sequence([
            .wait(forDuration: gather * 0.4),
            .colorize(with: light, colorBlendFactor: 0.85, duration: gather * 0.6),
            .group([.scaleX(to: 0.25, duration: vanish), .scaleY(to: 1.5, duration: vanish),
                    .moveBy(x: 0, y: rise, duration: vanish)]),
        ]), withKey: "waystone")
        player.run(.sequence([.wait(forDuration: gather + vanish * 0.4), .fadeOut(withDuration: vanish * 0.6)]))
        parent.run(.sequence([.wait(forDuration: gather), .run { flash(at: feet, in: parent); burst(at: feet, in: parent, outward: true) }]))
        parent.run(.sequence([.wait(forDuration: length), .run(done)]))
    }

    // MARK: Arriving

    /// Before the land shows: you aren't there yet (`arrive` brings you out of the light).
    static func hold(_ player: Walker) {
        player.alpha = 0
        player.sprite.removeAction(forKey: "waystone")
        player.sprite.position = CGPoint(x: 0, y: rise)
        player.sprite.xScale = 0.25
        player.sprite.yScale = 1.5
        player.sprite.color = light
        player.sprite.colorBlendFactor = 0.85
    }

    /// You come out of the light in a ring of runes at the waystone you chose, then `done`.
    static func arrive(_ player: Walker, in parent: SKNode, then done: @escaping () -> Void) {
        let feet = player.position
        let ring = runeRing(at: feet, in: parent)
        ring.setScale(1.25)
        ring.alpha = 0
        ring.run(.sequence([
            .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.3)]),
            .wait(forDuration: arrival - 0.3),
            .group([.fadeOut(withDuration: 0.5), .scale(to: 0.2, duration: 0.5)]),
            .removeFromParent(),
        ]))
        flash(at: feet, in: parent)
        burst(at: feet, in: parent, outward: false)
        motes(around: feet, in: parent, rising: false, count: 12, over: arrival)
        let pillar = pillar(at: feet, in: parent)
        pillar.alpha = 0.9
        pillar.run(.sequence([.wait(forDuration: 0.25), .group([.fadeOut(withDuration: 0.7), .scaleX(to: 0.2, duration: 0.7)]), .removeFromParent()]))
        let settle = SKAction.group([
            .scaleX(to: 1, duration: 0.45), .scaleY(to: 1, duration: 0.45),
            .move(to: .zero, duration: 0.45),
            .colorize(withColorBlendFactor: 0, duration: 0.9),
        ])
        settle.timingMode = .easeOut
        player.sprite.run(.sequence([.wait(forDuration: 0.15), settle]), withKey: "waystone")
        player.run(.sequence([.wait(forDuration: 0.1), .fadeIn(withDuration: 0.35)]))
        parent.run(.sequence([.wait(forDuration: arrival), .run(done)]))
    }

    // MARK: The pieces

    /// The ring of runes on the ground: two rings of light, eight runes going round between them, and
    /// a glow under it all, flat on the ground as the map is seen.
    private static func runeRing(at point: CGPoint, in parent: SKNode) -> SKNode {
        let node = SKNode()
        node.position = point
        node.zPosition = z - 2
        let glow = SkillEffects.glowSprite(light, size: CGSize(width: 110, height: 48))
        glow.alpha = 0.55
        glow.zPosition = 0
        node.addChild(glow)
        for (index, radius) in [CGFloat(34), 25].enumerated() {
            let ring = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.9))
            ring.strokeColor = index == 0 ? light : violet
            ring.fillColor = .clear
            ring.lineWidth = index == 0 ? 2 : 1.2
            ring.glowWidth = 2.5
            ring.blendMode = .add
            ring.zPosition = 1
            node.addChild(ring)
            ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])))
        }
        // The runes go round between the rings (round the ellipse, so the ring stays flat on the ground).
        let runes = SKNode()
        runes.zPosition = 2
        node.addChild(runes)
        let count = 8
        for index in 0..<count {
            let rune = SKSpriteNode(texture: SoftTextures.star, size: CGSize(width: 6, height: 6))
            rune.color = index.isMultiple(of: 2) ? light : violet
            rune.colorBlendFactor = 1
            rune.blendMode = .add
            runes.addChild(rune)
        }
        runes.run(.repeatForever(.customAction(withDuration: 4) { holder, elapsed in
            let turn = elapsed / 4 * 2 * .pi
            for (index, rune) in holder.children.enumerated() {
                let angle = turn + CGFloat(index) / CGFloat(count) * 2 * .pi
                rune.position = CGPoint(x: cos(angle) * 29.5, y: sin(angle) * 29.5 * 0.45)
            }
        }))
        parent.addChild(node)
        return node
    }

    /// A tall soft pillar of light standing on `point`.
    private static func pillar(at point: CGPoint, in parent: SKNode) -> SKSpriteNode {
        let pillar = SkillEffects.glowSprite(light, size: CGSize(width: 54, height: 210))
        pillar.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        pillar.position = point
        pillar.zPosition = z
        parent.addChild(pillar)
        return pillar
    }

    /// The waystone lighting up, and motes of its light streaming over to `target`.
    private static func flare(_ stone: CGPoint, toward target: CGPoint, in parent: SKNode) {
        let glow = SkillEffects.glowSprite(light, size: CGSize(width: 46, height: 64))
        glow.position = stone + CGVector(dx: 0, dy: 22)
        glow.zPosition = z
        glow.alpha = 0
        parent.addChild(glow)
        glow.run(.sequence([
            .fadeAlpha(to: 0.9, duration: 0.3),
            .repeat(.sequence([.scale(to: 1.25, duration: 0.18), .scale(to: 1, duration: 0.18)]), count: 3),
            .fadeOut(withDuration: 0.5),
            .removeFromParent(),
        ]))
        let from = stone + CGVector(dx: 0, dy: 26)
        let to = target + CGVector(dx: 0, dy: 18)
        for index in 0..<7 {
            let mote = SkillEffects.glowSprite(index.isMultiple(of: 2) ? light : violet, size: CGSize(width: 9, height: 9))
            mote.zPosition = z + 1
            mote.alpha = 0
            parent.addChild(mote)
            let bend = CGFloat(index.isMultiple(of: 2) ? 1 : -1) * CGFloat(10 + index * 3)
            let flight: CGFloat = 0.55
            let arc = SKAction.customAction(withDuration: TimeInterval(flight)) { node, elapsed in
                let t = min(1, elapsed / flight)
                let ease = t * t * (3 - 2 * t)
                node.position = CGPoint(x: from.x + (to.x - from.x) * ease, y: from.y + (to.y - from.y) * ease + sin(t * .pi) * bend)
                node.alpha = min(1, t * 6, (1 - t) * 4 + 0.2)
            }
            mote.run(.sequence([.wait(forDuration: 0.25 + Double(index) * 0.08), arc, .removeFromParent()]))
        }
    }

    /// Motes round `center`: spiralling up and in as you go (`rising`), or down and in as you arrive.
    private static func motes(around center: CGPoint, in parent: SKNode, rising: Bool, count: Int, over duration: Double) {
        for index in 0..<count {
            let mote = SkillEffects.glowSprite(index.isMultiple(of: 3) ? violet : light, size: CGSize(width: 8, height: 8))
            mote.zPosition = z + 1
            mote.alpha = 0
            parent.addChild(mote)
            let phase = CGFloat(index) / CGFloat(count) * 2 * .pi
            let flight = CGFloat(duration * 0.7)
            let spin = SKAction.customAction(withDuration: TimeInterval(flight)) { node, elapsed in
                let t = min(1, elapsed / flight)
                // How far up the spiral it is (0 on the ring, 1 high in the pillar).
                let up = rising ? t : 1 - t
                let angle = phase + up * 3.2 * .pi
                let radius = 32 * (1 - up * 0.75)
                node.position = CGPoint(x: center.x + cos(angle) * radius, y: center.y + 4 + up * 70 + sin(angle) * radius * 0.45)
                node.alpha = min(1, t * 5, (1 - t) * 4)
                node.setScale(1 - up * 0.4)
            }
            mote.run(.sequence([.wait(forDuration: duration * 0.3 * Double(index) / Double(count)), spin, .removeFromParent()]))
        }
    }

    /// A bright flash where you stand.
    private static func flash(at point: CGPoint, in parent: SKNode) {
        let flash = SkillEffects.glowSprite(.white, size: CGSize(width: 40, height: 40))
        flash.position = point + CGVector(dx: 0, dy: 20)
        flash.zPosition = z + 2
        flash.alpha = 0.95
        parent.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 3.2, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    /// Sparks flying out from where you stand (`outward`), or gathering in to it.
    private static func burst(at point: CGPoint, in parent: SKNode, outward: Bool) {
        let middle = point + CGVector(dx: 0, dy: 20)
        let count = 14
        for index in 0..<count {
            let spark = SKSpriteNode(texture: SoftTextures.star, size: CGSize(width: 7, height: 7))
            spark.color = index.isMultiple(of: 2) ? light : violet
            spark.colorBlendFactor = 1
            spark.blendMode = .add
            spark.zPosition = z + 2
            parent.addChild(spark)
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
            let reach = CGFloat(38 + (index * 7) % 18)
            let far = CGPoint(x: middle.x + cos(angle) * reach, y: middle.y + sin(angle) * reach * 0.7 + (outward ? 12 : 0))
            spark.position = outward ? middle : far
            spark.alpha = outward ? 1 : 0
            let move = SKAction.move(to: outward ? far : middle, duration: 0.5)
            move.timingMode = outward ? .easeOut : .easeIn
            let fade: SKAction = outward ? .fadeOut(withDuration: 0.5) : .sequence([.fadeIn(withDuration: 0.25), .fadeOut(withDuration: 0.25)])
            spark.run(.sequence([.group([move, fade, .rotate(byAngle: .pi, duration: 0.5)]), .removeFromParent()]))
        }
    }
}
