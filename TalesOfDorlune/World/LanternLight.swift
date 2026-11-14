import SpriteKit

/// Your lantern's light on what stands round you in a cave (`WorldScene`): the side of a rock, a
/// crystal, a crate or a block of the cave's wall turned toward you catches it, the far side stays in
/// the dark, as the street lamps light a town at night (`LampLight`, after SpriteCook's normal-map
/// article: which way each pixel faces, from the sprite's outline alone, lit in three hard steps).
/// The lamps stand still and are worked out once; your light moves, so each time you step into
/// another cell (`WorldScene.castLight`) everything near you is lit again from where you are, and
/// only what the light can see (`Shadowcast`): nothing behind the rock. The lit copies are cached
/// by picture, way and colour (`LampLight.copy`), so walking about only swaps textures.
final class LanternLight {
    private final class Thing {
        weak var node: SKSpriteNode?
        /// Made the first time the light reaches it, so a cave's thousands of rock blocks cost nothing
        /// till you come near.
        var copy: SKSpriteNode?
        let key: String
        let cell: GridPoint
        let picture: () -> CGImage
        init(node: SKSpriteNode, key: String, cell: GridPoint, picture: @escaping () -> CGImage) {
            self.node = node
            self.key = key
            self.cell = cell
            self.picture = picture
        }
    }
    private var things: [Thing] = []
    /// Each picture read once, by its key.
    private var pictures: [String: CGImage] = [:]
    private let color: (r: Double, g: Double, b: Double)
    /// How far the light catches a thing's side, in points: the lantern's own reach.
    private let reach: CGFloat

    init(color: (r: Double, g: Double, b: Double), reach: CGFloat) {
        self.color = color
        self.reach = reach
    }

    /// `node` (its picture known by `key`, read by `picture` when first needed; standing for `cell`)
    /// catches your light from now on.
    func add(_ node: SKSpriteNode, key: String, cell: GridPoint, picture: @escaping () -> CGImage) {
        things.append(Thing(node: node, key: key, cell: cell, picture: picture))
    }

    /// Lit from `point` (your light, in the same points as the things): each within reach that the
    /// light sees (`sees`) from your way (one of eight), brighter nearer in steps; the rest unlit.
    func shine(from point: CGPoint, sees: (GridPoint) -> Bool) {
        things.removeAll { $0.node == nil }
        for thing in things {
            guard let node = thing.node else { continue }
            let middle = CGPoint(x: node.position.x, y: node.position.y + node.size.height * (0.5 - node.anchorPoint.y))
            let distance = hypot(point.x - middle.x, point.y - middle.y)
            guard distance < reach, distance > 4, sees(thing.cell) else {
                thing.copy?.isHidden = true
                continue
            }
            let angle = atan2(point.y - middle.y, point.x - middle.x)
            let way = (Int((angle / (.pi / 4)).rounded()) % 8 + 8) % 8
            let picture: CGImage
            if let known = pictures[thing.key] {
                picture = known
            } else {
                picture = thing.picture()
                pictures[thing.key] = picture
            }
            guard let texture = LampLight.shared.copy(of: picture, key: thing.key, way: way, color: color) else {
                thing.copy?.isHidden = true
                continue
            }
            let copy: SKSpriteNode
            if let made = thing.copy {
                copy = made
            } else {
                copy = SKSpriteNode(texture: texture, size: node.size)
                copy.blendMode = .add
                copy.zPosition = 0.01
                // Its child, so it sways, hides and goes with it.
                node.addChild(copy)
                thing.copy = copy
            }
            copy.texture = texture
            copy.size = node.size
            copy.anchorPoint = node.anchorPoint
            let near = 1 - distance / reach
            copy.alpha = LampLight.brightest * (near * 3).rounded(.up) / 3
            copy.isHidden = false
        }
    }
}
