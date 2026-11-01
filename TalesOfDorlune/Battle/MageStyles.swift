import SpriteKit
import UIKit

/// The palette of the Mage's metal spell (MageStyles below); water and fire use their elements'.
extension SkillEffects.ElementLight {
    /// Spiritual Lance's silver-gold, Metal's light with a white-hot edge.
    static let spirit = Self(deep: UIColor(red: 0.55, green: 0.45, blue: 0.15, alpha: 1), main: UIColor(red: 0.92, green: 0.82, blue: 0.45, alpha: 1),
                             bright: UIColor(red: 1, green: 0.96, blue: 0.75, alpha: 1), core: .white)
}

/// The Mage's later spells (playtesting 2026-11-01, Phase 3 of more skills: its last new one came
/// at 70, and it had no water or metal attack), after Fairyland Online's Mage list: Dancing Fountain,
/// Spiritual Lance and Meteor Blast. Each its own look in light, as every skill's is; BattleScene
/// plays them and shows the hits once they land (each returns how long that takes).
extension SkillEffects {
    /// Dancing Fountain: jets of water light leap up from the ground under each foe in turn, sway
    /// and fall back in a rain of droplets, a ring splashing out at their feet.
    @discardableResult
    static func fountainJets(on targets: [BattleActor], level: Int, in parent: SKNode) -> TimeInterval {
        let light = ElementLight.water
        for (order, target) in targets.enumerated() {
            let delay = Double(order) * 0.05
            for jet in 0..<(3 + level / 3) {
                let offset = CGFloat(jet - 1) * 14 + .random(in: -4...4)
                let height = CGFloat.random(in: 60...86) + CGFloat(level) * 2
                let column = streak(light, size: CGSize(width: 12, height: height), tint: 0.4)
                column.position = target.position + CGVector(dx: offset, dy: 0)
                column.yScale = 0.05
                column.alpha = 0
                parent.addChild(column)
                // Up from the ground, swaying a little, and down again.
                let rise = SKAction.group([.scaleY(to: 1, duration: 0.18), .moveBy(x: 0, y: height / 2, duration: 0.18)])
                rise.timingMode = .easeOut
                let sway = SKAction.sequence([.rotate(byAngle: 0.12, duration: 0.1), .rotate(byAngle: -0.24, duration: 0.18)])
                column.run(.sequence([.wait(forDuration: delay + Double(jet) * 0.05), .fadeIn(withDuration: 0.03),
                                      .group([rise, sway]), .group([.scaleY(to: 0.1, duration: 0.2), .moveBy(x: 0, y: -height / 2, duration: 0.2),
                                                                     .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
                // Droplets thrown off the top, falling back.
                for _ in 0..<3 {
                    let drop = glowSprite(jet % 2 == 0 ? light.bright : light.core, size: CGSize(width: 6, height: 8))
                    drop.position = target.position + CGVector(dx: offset, dy: height)
                    drop.alpha = 0
                    parent.addChild(drop)
                    let fall = SKAction.moveBy(x: .random(in: -26...26), y: -height + .random(in: -4...8), duration: 0.4)
                    fall.timingMode = .easeIn
                    drop.run(.sequence([.wait(forDuration: delay + 0.2 + Double(jet) * 0.05), .fadeIn(withDuration: 0.02),
                                        .group([fall, .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.1)])]), .removeFromParent()]))
                }
            }
            ring(at: target.position, color: light.bright, size: CGSize(width: 44, height: 16), grow: 2.2, delay: delay + 0.1, in: parent)
        }
        return 0.3 + Double(max(0, targets.count - 1)) * 0.05
    }

    /// Spiritual Lance: a long spear of silver-gold spirit light forms beside the mage and drives
    /// through the foe, flaring at the tip and leaving a thin trail. Returns how long until it strikes.
    @discardableResult
    static func spiritLance(from caster: BattleActor?, to target: BattleActor?, level: Int, in parent: SKNode) -> TimeInterval {
        let light = ElementLight.spirit
        guard let target else { return 0 }
        let start = caster?.center ?? target.center + CGVector(dx: 140, dy: 40)
        let way = (target.center - start).normalized
        let length: CGFloat = 90 + CGFloat(level) * 6
        let lance = streak(light, color: light.core, size: CGSize(width: length, height: 7), tint: 0.45)
        lance.position = start
        lance.zRotation = atan2(way.dy, way.dx)
        lance.xScale = 0.1
        lance.alpha = 0
        parent.addChild(lance)
        let tip = lightBall(light, size: 22, tint: 0.3)
        tip.position = CGPoint(x: length / 2, y: 0)
        lance.addChild(tip)
        let distance = (target.center - start).length
        let drive = SKAction.move(to: target.center + way * (length * 0.2), duration: 0.16)
        drive.timingMode = .easeIn
        lance.run(.sequence([.fadeIn(withDuration: 0.04), .scaleX(to: 1, duration: 0.1), drive,
                             .group([.scaleY(to: 0.2, duration: 0.15), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        // The thin trail it leaves on its way.
        let trailLine = glowSprite(light.main, size: CGSize(width: distance, height: 3))
        trailLine.position = start + way * (distance / 2)
        trailLine.zRotation = atan2(way.dy, way.dx)
        trailLine.alpha = 0
        parent.addChild(trailLine)
        trailLine.run(.sequence([.wait(forDuration: 0.16), .fadeAlpha(to: 0.7, duration: 0.05), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        let flare = lightBall(light, size: 50 + CGFloat(level) * 4)
        flare.position = target.center
        flare.setScale(0.2)
        flare.alpha = 0
        parent.addChild(flare)
        flare.run(.sequence([.wait(forDuration: 0.3), .fadeIn(withDuration: 0.02),
                             .group([.scale(to: 1.25, duration: 0.18), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        sparks(from: target.center, light: light, count: 10 + level, reach: 60, delay: 0.3, in: parent)
        return 0.3
    }

    /// Meteor Blast: burning meteors dive steeply out of the sky, one at every foe and smaller ones
    /// after, each bursting in fire and a ring. Returns how long until the big ones land.
    @discardableResult
    static func meteorShower(on targets: [BattleActor], level: Int, top: CGFloat, in parent: SKNode) -> TimeInterval {
        let light = ElementLight.fire
        let fall: TimeInterval = 0.32
        for (order, target) in targets.enumerated() {
            let delay = Double(order) * 0.07
            for small in 0..<3 {
                let big = small == 0
                let size = big ? 34 + CGFloat(level) * 3 : 16
                let landing = target.center + (big ? CGVector.zero : CGVector(dx: .random(in: -30...30), dy: .random(in: -12...12)))
                let rock = lightBall(light, size: size)
                rock.position = CGPoint(x: landing.x - 120, y: max(top, landing.y + 260))
                rock.zPosition = 18_700
                rock.alpha = 0
                let tail = trail(light, level: level, parent: parent)
                rock.addChild(tail)
                parent.addChild(rock)
                let dive = SKAction.move(to: landing, duration: fall)
                dive.timingMode = .easeIn
                let wait = delay + (big ? 0 : 0.12 + Double(small) * 0.08)
                rock.run(.sequence([.wait(forDuration: wait), .fadeIn(withDuration: 0.03), dive, .run {
                    SkillEffects.settle(tail, in: parent)
                    let burst = SkillEffects.lightBall(light, size: size * 1.8)
                    burst.position = landing
                    burst.setScale(0.3)
                    parent.addChild(burst)
                    burst.run(.sequence([.group([.scale(to: 1.2, duration: 0.2), .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
                    if big {
                        SkillEffects.sparks(from: landing, light: light, count: 8 + level, reach: 56, in: parent)
                        SkillEffects.ring(at: target.position, color: light.main, size: CGSize(width: 48, height: 17), grow: 2.4, in: parent)
                    }
                }, .removeFromParent()]))
            }
        }
        return fall + 0.04 + Double(max(0, targets.count - 1)) * 0.07
    }
}
