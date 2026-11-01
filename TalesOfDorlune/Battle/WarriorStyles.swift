import SpriteKit
import UIKit

/// The palettes of the Fighter's and Beast Tamer's later skills (WarriorStyles below).
extension SkillEffects.ElementLight {
    /// Charge's white-hot orange.
    static let charge = Self(deep: lit(0.85, 0.3, 0.05), main: lit(1, 0.6, 0.2), bright: lit(1, 0.86, 0.55), core: lit(1, 1, 0.9))
    /// Rush's cool white-blue.
    static let rush = Self(deep: lit(0.25, 0.4, 0.75), main: lit(0.7, 0.82, 1), bright: lit(0.9, 0.95, 1), core: lit(1, 1, 1))
    /// Impact's amber and earth.
    static let quake = Self(deep: lit(0.5, 0.28, 0.06), main: lit(0.85, 0.55, 0.2), bright: lit(1, 0.78, 0.42), core: lit(1, 0.95, 0.8))
    /// Double Combo's crimson.
    static let combo = Self(deep: lit(0.62, 0.04, 0.12), main: lit(0.9, 0.2, 0.25), bright: lit(1, 0.5, 0.45), core: lit(1, 0.9, 0.85))
    /// Dodge Whip's tan lash.
    static let lash = Self(deep: lit(0.45, 0.3, 0.12), main: lit(0.82, 0.62, 0.32), bright: lit(0.96, 0.84, 0.58), core: lit(1, 0.97, 0.88))
    /// Beast Lore's teal.
    static let lore = Self(deep: lit(0.04, 0.45, 0.48), main: lit(0.18, 0.78, 0.78), bright: lit(0.6, 0.95, 0.93), core: lit(0.92, 1, 1))
    /// Super Boost's red to gold.
    static let surge = Self(deep: lit(0.75, 0.12, 0.04), main: lit(1, 0.42, 0.12), bright: lit(1, 0.78, 0.3), core: lit(1, 0.97, 0.75))
    /// Full Heal's green and white.
    static let bloom = Self(deep: lit(0.08, 0.55, 0.28), main: lit(0.35, 0.9, 0.5), bright: lit(0.8, 1, 0.85), core: lit(1, 1, 1))
    /// God of Beast Impact's gold.
    static let beast = Self(deep: lit(0.65, 0.4, 0.05), main: lit(1, 0.76, 0.22), bright: lit(1, 0.92, 0.6), core: lit(1, 1, 0.92))

    fileprivate static func lit(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

/// The Fighter's and Beast Tamer's later skills (playtesting 2026-11-01, Phase 1 of more skills for
/// both, named after Fairyland Online's Warrior and Beast Master skills): each its own look, drawn in
/// light in its own colours, as every skill's is (SkillStyles.swift). BattleScene.castSkill plays
/// them; the ones that travel or build up return how long until the hits should show.
extension SkillEffects {
    // MARK: - Fighter

    /// Charge: a comet of white-hot light drives in from the fighter's side and bursts through the
    /// foe, a ring rolling out at its feet.
    static func chargeBurst(from caster: BattleActor?, on target: BattleActor, level: Int, in parent: SKNode) {
        let light = ElementLight.charge
        let from = caster?.center ?? target.center + CGVector(dx: 90, dy: 0)
        let way = (target.center - from).normalized
        let length: CGFloat = 110 + CGFloat(level) * 8
        let comet = streak(light, size: CGSize(width: length, height: 16 + CGFloat(level)))
        comet.position = target.center + way * (-length / 2)
        comet.zRotation = atan2(way.dy, way.dx)
        comet.xScale = 0.1
        parent.addChild(comet)
        let drive = SKAction.group([.scaleX(to: 1, duration: 0.07), .move(to: target.center + way * 20, duration: 0.1)])
        drive.timingMode = .easeIn
        comet.run(.sequence([drive, .group([.scaleY(to: 0.3, duration: 0.15), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        let bloom = lightBall(light, size: 46 + CGFloat(level) * 5)
        bloom.position = target.center
        bloom.setScale(0.3)
        bloom.alpha = 0
        parent.addChild(bloom)
        bloom.run(.sequence([.wait(forDuration: 0.08), .fadeIn(withDuration: 0.02),
                             .group([.scale(to: 1.3, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        sparks(from: target.center, light: light, count: 8 + level, reach: 60, delay: 0.08, in: parent)
        ring(at: target.position, color: light.main, size: CGSize(width: 44, height: 16), grow: 2.2, delay: 0.08, in: parent)
    }

    /// One of Rush's three blows: a quick stroke of cool light across the foe, each at its own slant.
    static func rushStroke(on target: BattleActor, index: Int, level: Int, in parent: SKNode) {
        let light = ElementLight.rush
        let slants: [CGFloat] = [0.35, -0.5, 0.05]
        let stroke = streak(light, color: index == 2 ? light.core : light.bright, size: CGSize(width: 80 + CGFloat(level) * 6, height: 8))
        stroke.position = target.center + CGVector(dx: 0, dy: CGFloat(index - 1) * 8)
        stroke.zRotation = slants[index % slants.count]
        stroke.xScale = 0.05
        parent.addChild(stroke)
        stroke.run(.sequence([.scaleX(to: 1, duration: 0.05), .fadeOut(withDuration: 0.18), .removeFromParent()]))
        sparks(from: target.center, light: light, count: 5, reach: 34, in: parent)
    }

    /// Impact: a shaft of amber light slams down, the ground cracks open in jagged lines round the
    /// foe, a heavy ring rolls out and dust kicks up.
    static func impactQuake(on target: BattleActor, level: Int, in parent: SKNode) {
        let light = ElementLight.quake
        let shaft = glowSprite(light.bright, size: CGSize(width: 24 + CGFloat(level) * 2, height: 100))
        shaft.anchorPoint = CGPoint(x: 0.5, y: 0)
        shaft.position = target.top + CGVector(dx: 0, dy: 70)
        shaft.alpha = 0
        parent.addChild(shaft)
        let slam = SKAction.move(to: target.position, duration: 0.08)
        slam.timingMode = .easeIn
        shaft.run(.sequence([.fadeIn(withDuration: 0.02), slam, .group([.scaleY(to: 0.15, duration: 0.12), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        // Cracks running out over the ground, a few points jagged.
        for index in 0..<(5 + level / 2) {
            let angle = CGFloat(index) / CGFloat(5 + level / 2) * 2 * .pi + .random(in: -0.25...0.25)
            let path = CGMutablePath()
            var point = CGPoint.zero
            path.move(to: point)
            let reach = CGFloat.random(in: 26...40) + CGFloat(level) * 2
            for step in 1...3 {
                let along = reach * CGFloat(step) / 3
                let wobble = CGFloat.random(in: -6...6)
                point = CGPoint(x: cos(angle) * along - sin(angle) * wobble, y: (sin(angle) * along + cos(angle) * wobble) * 0.45)
                path.addLine(to: point)
            }
            let crack = SKShapeNode(path: path)
            crack.strokeColor = index % 2 == 0 ? light.bright : light.main
            crack.lineWidth = 2.5
            crack.glowWidth = 3
            crack.lineCap = .round
            crack.lineJoin = .round
            crack.blendMode = .add
            crack.position = target.position
            crack.zPosition = 18_000
            crack.alpha = 0
            parent.addChild(crack)
            crack.run(.sequence([.wait(forDuration: 0.08), .fadeIn(withDuration: 0.03), .wait(forDuration: 0.3),
                                 .fadeOut(withDuration: 0.35), .removeFromParent()]))
        }
        ring(at: target.position, color: light.main, size: CGSize(width: 50, height: 18), grow: 2.6, delay: 0.08, in: parent)
        ring(at: target.position, color: light.bright, size: CGSize(width: 30, height: 11), grow: 3.2, delay: 0.16, in: parent)
        let dust = UIColor(red: 0.6, green: 0.5, blue: 0.38, alpha: 1)
        for _ in 0..<(5 + level) {
            let puff = shade(dust, size: CGSize(width: 24, height: 16), alpha: 0.6)
            puff.position = target.position + CGVector(dx: .random(in: -30...30), dy: .random(in: -4...6))
            puff.zPosition = 18_200
            puff.alpha = 0
            parent.addChild(puff)
            puff.run(.sequence([
                .wait(forDuration: 0.09), .fadeAlpha(to: 0.6, duration: 0.03),
                .group([.scale(to: 1.9, duration: 0.5), .moveBy(x: .random(in: -16...16), y: 14, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    /// One of Double Combo's two blows: a heavy crimson stroke, the second crossing the first into
    /// an X that flares as it lands.
    static func comboStroke(on target: BattleActor, index: Int, level: Int, in parent: SKNode) {
        let light = ElementLight.combo
        let stroke = streak(light, size: CGSize(width: 100 + CGFloat(level) * 8, height: 12 + CGFloat(level)))
        stroke.position = target.center
        stroke.zRotation = index == 0 ? -0.7 : 0.7
        stroke.xScale = 0.05
        parent.addChild(stroke)
        stroke.run(.sequence([.scaleX(to: 1, duration: 0.07), .wait(forDuration: index == 0 ? 0.2 : 0.05),
                              .fadeOut(withDuration: 0.25), .removeFromParent()]))
        if index > 0 {
            let flare = lightBall(light, size: 54 + CGFloat(level) * 4)
            flare.position = target.center
            flare.setScale(0.2)
            parent.addChild(flare)
            flare.run(.sequence([.group([.scale(to: 1.2, duration: 0.16), .fadeOut(withDuration: 0.24)]), .removeFromParent()]))
            sparks(from: target.center, light: light, count: 10 + level, reach: 58, in: parent)
        } else {
            sparks(from: target.center, light: light, count: 5, reach: 36, in: parent)
        }
    }

    // MARK: - Beast Tamer

    /// Dodge Whip: a tan lash curls out from the tamer and cracks across the foe, a flash at its
    /// tip; then streaks of speed rise off the tamer. Returns how long until it cracks.
    @discardableResult
    static func whipLash(from caster: BattleActor?, on targets: [BattleActor], level: Int, in parent: SKNode) -> TimeInterval {
        let light = ElementLight.lash
        guard let start = caster?.center else { return 0 }
        for target in targets {
            let path = arc(from: start, to: target.center, lift: 34)
            let lash = SKShapeNode(path: path)
            lash.strokeColor = light.bright
            lash.lineWidth = 3
            lash.glowWidth = 4
            lash.lineCap = .round
            lash.blendMode = .add
            lash.zPosition = 18_000
            lash.alpha = 0
            parent.addChild(lash)
            lash.run(.sequence([.fadeIn(withDuration: 0.06), .wait(forDuration: 0.12), .fadeOut(withDuration: 0.2), .removeFromParent()]))
            let crack = lightBall(light, size: 30 + CGFloat(level) * 3)
            crack.position = target.center
            crack.setScale(0.2)
            crack.alpha = 0
            parent.addChild(crack)
            crack.run(.sequence([.wait(forDuration: 0.14), .fadeIn(withDuration: 0.02),
                                 .group([.scale(to: 1.1, duration: 0.14), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
            sparks(from: target.center, light: light, count: 6, reach: 36, delay: 0.14, in: parent)
        }
        // Light on its feet: green streaks of speed rising off the tamer.
        if let caster {
            for index in 0..<5 {
                let line = glowSprite(ElementLight.wood.bright, size: CGSize(width: 4, height: 26))
                line.position = caster.position + CGVector(dx: CGFloat(index - 2) * 9, dy: .random(in: 0...10))
                line.alpha = 0
                parent.addChild(line)
                line.run(.sequence([.wait(forDuration: 0.2 + Double(index) * 0.04), .fadeIn(withDuration: 0.04),
                                    .group([.moveBy(x: 0, y: 46, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
            }
        }
        return 0.16
    }

    /// Beast Lore: over every foe a ring of teal light closes in like a sight onto its weak spot,
    /// cross hairs flash on it and a mark glints. Returns how long it takes.
    @discardableResult
    static func loreSight(on targets: [BattleActor], in parent: SKNode) -> TimeInterval {
        let light = ElementLight.lore
        for (index, target) in targets.enumerated() {
            let delay = Double(index) * 0.06
            let sight = SKShapeNode(circleOfRadius: 22)
            sight.strokeColor = light.bright
            sight.lineWidth = 2.5
            sight.glowWidth = 3
            sight.blendMode = .add
            sight.position = target.center
            sight.zPosition = 18_600
            sight.setScale(2.4)
            sight.alpha = 0
            parent.addChild(sight)
            let close = SKAction.scale(to: 1, duration: 0.3)
            close.timingMode = .easeOut
            sight.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.06), close, .wait(forDuration: 0.12),
                                 .fadeOut(withDuration: 0.2), .removeFromParent()]))
            for turn in 0..<4 {
                let hair = glowSprite(light.main, size: CGSize(width: 14, height: 3))
                let angle = CGFloat(turn) * .pi / 2
                hair.position = target.center + CGVector(dx: cos(angle) * 30, dy: sin(angle) * 30)
                hair.zRotation = angle
                hair.zPosition = 18_600
                hair.alpha = 0
                parent.addChild(hair)
                hair.run(.sequence([.wait(forDuration: delay + 0.3), .fadeIn(withDuration: 0.03),
                                    .group([.move(to: target.center + CGVector(dx: cos(angle) * 16, dy: sin(angle) * 16), duration: 0.12),
                                            .sequence([.wait(forDuration: 0.1), .fadeOut(withDuration: 0.18)])]),
                                    .removeFromParent()]))
            }
            let glint = lightBall(light, size: 24, tint: 0.3)
            glint.position = target.center
            glint.setScale(0.2)
            glint.alpha = 0
            parent.addChild(glint)
            glint.run(.sequence([.wait(forDuration: delay + 0.38), .fadeIn(withDuration: 0.02),
                                 .group([.scale(to: 1, duration: 0.12), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        }
        return 0.55
    }

    /// Super Boost: two columns of red-gold chevrons blaze up round the ally, a flaring aura and a
    /// ring under them, hotter and higher than Boost's.
    static func superBoost(on target: BattleActor, in parent: SKNode) {
        let light = ElementLight.surge
        let aura = lightBall(light, size: 76, tint: 0.4, core: false)
        aura.position = target.center
        aura.alpha = 0
        parent.addChild(aura)
        aura.run(.sequence([.fadeIn(withDuration: 0.1), .wait(forDuration: 0.3), .group([.scale(to: 1.5, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        ring(at: target.position, color: light.main, size: CGSize(width: 44, height: 16), grow: 2.4, in: parent)
        for column in [-1, 1] {
            for index in 0..<4 {
                let chevron = SKShapeNode(path: superChevron(width: 18, height: 9))
                chevron.strokeColor = index % 2 == 0 ? light.bright : light.core
                chevron.lineWidth = 3
                chevron.glowWidth = 4
                chevron.lineCap = .round
                chevron.lineJoin = .round
                chevron.blendMode = .add
                chevron.position = target.position + CGVector(dx: CGFloat(column) * 14, dy: 2)
                chevron.zPosition = 18_600
                chevron.alpha = 0
                parent.addChild(chevron)
                let rise = SKAction.moveBy(x: 0, y: 76 + CGFloat(index) * 6, duration: 0.45)
                rise.timingMode = .easeOut
                chevron.run(.sequence([
                    .wait(forDuration: Double(index) * 0.06 + (column > 0 ? 0.03 : 0)), .fadeIn(withDuration: 0.04),
                    .group([rise, .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.2)])]),
                    .removeFromParent(),
                ]))
            }
        }
    }

    /// An upward chevron, `width` × `height`.
    private static func superChevron(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        return path
    }

    /// Full Heal: a great bloom of green and white light opens round the ally, petals of light
    /// spread from it and motes stream up as it closes into them. Returns how long it takes.
    @discardableResult
    static func fullBloom(on target: BattleActor, in parent: SKNode) -> TimeInterval {
        let light = ElementLight.bloom
        let heart = lightBall(light, size: 70, tint: 0.35)
        heart.position = target.center
        heart.setScale(0.3)
        heart.alpha = 0
        parent.addChild(heart)
        heart.run(.sequence([.fadeIn(withDuration: 0.08), .scale(to: 1.2, duration: 0.3), .wait(forDuration: 0.12),
                             .group([.scale(to: 0.4, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        for index in 0..<8 {
            let angle = CGFloat(index) / 8 * 2 * .pi
            let petal = glowSprite(index % 2 == 0 ? light.bright : light.main, size: CGSize(width: 22, height: 10))
            petal.position = target.center
            petal.zRotation = angle
            petal.alpha = 0
            parent.addChild(petal)
            let open = SKAction.move(to: target.center + CGVector(dx: cos(angle) * 34, dy: sin(angle) * 26), duration: 0.3)
            open.timingMode = .easeOut
            petal.run(.sequence([.wait(forDuration: 0.05), .fadeIn(withDuration: 0.05), open, .wait(forDuration: 0.1),
                                 .group([.move(to: target.center, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
        }
        rising(from: target, light: light, count: 12, height: 80, in: parent)
        return 0.55
    }

    /// God of Beast Impact: a giant paw of gold light swings down out of the sky onto the foe,
    /// slams in a burst, and a great ring rolls out.
    static func beastPaw(on target: BattleActor, level: Int, in parent: SKNode) {
        let light = ElementLight.beast
        let paw = SKNode()
        paw.zPosition = 18_600
        let pad = lightBall(light, size: 44 + CGFloat(level) * 3, tint: 0.35)
        paw.addChild(pad)
        for (x, y) in [(-22.0, 26.0), (-8.0, 36.0), (8.0, 36.0), (22.0, 26.0)] {
            let toe = lightBall(light, size: 18 + CGFloat(level), tint: 0.3)
            toe.position = CGPoint(x: x, y: y)
            paw.addChild(toe)
        }
        paw.position = target.center + CGVector(dx: 0, dy: 120)
        paw.setScale(1.4)
        paw.alpha = 0
        parent.addChild(paw)
        let fall = SKAction.group([.move(to: target.center + CGVector(dx: 0, dy: 6), duration: 0.12), .scale(to: 1, duration: 0.12)])
        fall.timingMode = .easeIn
        paw.run(.sequence([.fadeIn(withDuration: 0.04), fall, .wait(forDuration: 0.08),
                           .group([.scale(to: 1.3, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        sparks(from: target.center, light: light, count: 12 + level, reach: 70, delay: 0.14, in: parent)
        ring(at: target.position, color: light.main, size: CGSize(width: 56, height: 20), grow: 2.8, delay: 0.14, in: parent)
        ring(at: target.position, color: light.bright, size: CGSize(width: 34, height: 12), grow: 3.6, delay: 0.22, in: parent)
    }
}
