import SpriteKit

/// A land's tall grass you wade through (the user, 2026-11-19, after SpriteCook's interactive tall
/// grass article; the look picked from `tools/grass_preview.py`): its patches (`WorldMap.tallGrass`)
/// filled with small tufts, each its own sprite standing on its base and sorted with the walkers.
/// As you come through, the tufts beside you lean away on a spring, those in front of your legs only
/// a little so they still hide them, those you push into rustle, and those just behind your feet are
/// pressed flat and a shade darker, standing up again in under a second. Visual only: nothing hides
/// in it.
///
/// Every pose is a frame of the tuft's sheet (`tools/grass_art.py`: leaning −8 to 8 pixels across,
/// pressed by steps down), so a tuft's rows move in whole pixels and only its texture changes. Only
/// the tufts round you and those still settling are worked out each frame.
final class GrassField {
    static let frame = CGSize(width: 18, height: 20)
    static let leans = 8
    static let stages = 5
    /// The spring a tuft leans on: how fast it swings, how soon it settles, how far it goes.
    static let springHz: CGFloat = 2.6, damping: CGFloat = 0.22, maxLean: CGFloat = 8, frontLean: CGFloat = 2
    /// How fast it's pressed down behind your feet and stands up again, in seconds.
    static let pressIn: CGFloat = 0.12, pressOut: CGFloat = 0.7
    /// Its rustle as you push in: how long, how far, how fast, and how long before it rustles again.
    static let shakeFor: CGFloat = 0.35, shakePx: CGFloat = 1, shakeSpeed: CGFloat = 40, cooldown: CGFloat = 0.7

    final class Tuft {
        let node: SKSpriteNode
        let frames: [[SKTexture]]
        let base: CGPoint
        let flipped: Bool
        /// At its patch's rim: never pressed, so the patch keeps its edge.
        let edge: Bool
        let phase: CGFloat
        var lean: CGFloat = 0, velocity: CGFloat = 0, press: CGFloat = 0
        /// Which way it leans while you're beside it, kept till you've gone (picked again every
        /// frame, a tuft snapped from side to side as you walked through it).
        var side: CGFloat = 0
        var age: CGFloat = 99, cool: CGFloat = 0
        var shown = (lean: 0, stage: 0)

        init(node: SKSpriteNode, frames: [[SKTexture]], base: CGPoint, flipped: Bool, edge: Bool, phase: CGFloat) {
            self.node = node
            self.frames = frames
            self.base = base
            self.flipped = flipped
            self.edge = edge
            self.phase = phase
        }

        var isStill: Bool { abs(lean) < 0.05 && abs(velocity) < 0.05 && press < 0.01 && age >= GrassField.shakeFor && side == 0 }
    }

    private var byCell: [GridPoint: [Tuft]] = [:]
    /// Tufts still swinging or standing up after you've passed.
    private var settling: [ObjectIdentifier: Tuft] = [:]
    private var last: CGPoint?

    /// Each design's frames, cut from its sheet: `[stage][lean + leans]`.
    static func frames(of sheet: SKTexture) -> [[SKTexture]] {
        let size = sheet.size()
        guard size.width >= frame.width, size.height >= frame.height else { return [[sheet]] }
        let across = CGFloat(2 * leans + 1), down = CGFloat(stages)
        return (0..<stages).map { stage in
            (0...(2 * leans)).map { lean in
                // A texture's rect runs from its bottom left; the sheet's first stage is its top row.
                let rect = CGRect(x: CGFloat(lean) / across, y: 1 - CGFloat(stage + 1) / down, width: 1 / across, height: 1 / down)
                let texture = SKTexture(rect: rect, in: sheet)
                texture.filteringMode = .nearest
                return texture
            }
        }
    }

    /// Sets the tufts down over the land's patches: about nine a cell on a jittered grid, each one
    /// of the four designs (`designs`, each a sheet's frames), half of them flipped. `parent` gives
    /// the node to hang each on (the stage's chunk at its spot).
    init(cells: Set<GridPoint>, designs: [[[SKTexture]]], seed: String, parent: (CGPoint) -> SKNode) {
        guard !designs.isEmpty else { return }
        var draw = SeededRandom(text: seed + "/tufts")
        let tile = WorldMap.tileSize
        let across = 3
        for cell in cells.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            let rim = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { !cells.contains(GridPoint(col: cell.col + $0.0, row: cell.row + $0.1)) }
            var tufts: [Tuft] = []
            for a in 0..<across {
                for b in 0..<across {
                    let u = (CGFloat(a) + CGFloat.random(in: 0.2...0.8, using: &draw)) / CGFloat(across)
                    let v = (CGFloat(b) + CGFloat.random(in: 0.2...0.8, using: &draw)) / CGFloat(across)
                    let spot = WorldMap.project(CGPoint(x: (CGFloat(cell.col) + u) * tile, y: (CGFloat(cell.row) + v) * tile))
                    // On a whole point, so its pixels sit on the screen's.
                    let base = CGPoint(x: spot.x.rounded(), y: spot.y.rounded())
                    let frames = designs[Int.random(in: 0..<designs.count, using: &draw)]
                    let flipped = Bool.random(using: &draw)
                    let phase = CGFloat.random(in: 0..<1, using: &draw)
                    // Only the tufts on the rim's outer side count as its edge.
                    let edge = rim && (u < 0.34 || u > 0.66 || v < 0.34 || v > 0.66)
                    let texture = frames[0][Self.leans]
                    let node = SKSpriteNode(texture: texture, size: Self.frame)
                    node.anchorPoint = CGPoint(x: 0.5, y: 0)
                    node.position = base
                    if flipped { node.xScale = -1 }
                    // Sorted by its base as the walkers are by their feet, a hair in front of one
                    // whose feet are level with it, so a tuft level with your feet hides them.
                    node.zPosition = -base.y + 0.5
                    parent(base).addChild(node)
                    tufts.append(Tuft(node: node, frames: frames, base: base, flipped: flipped, edge: edge, phase: phase))
                }
            }
            byCell[cell] = tufts
        }
    }

    var isEmpty: Bool { byCell.isEmpty }

    /// A frame of the grass round your feet (`feet` in the land's own points, on `cell`).
    func update(dt: TimeInterval, feet: CGPoint, cell: GridPoint) {
        guard !byCell.isEmpty, dt > 0 else { return }
        let moving = last.map { $0.distance(to: feet) > 0.01 } ?? false
        last = feet
        var near: [Tuft] = []
        for dr in -1...1 {
            for dc in -1...1 {
                if let tufts = byCell[GridPoint(col: cell.col + dc, row: cell.row + dr)] { near.append(contentsOf: tufts) }
            }
        }
        for tuft in near { settling[ObjectIdentifier(tuft)] = tuft }
        guard !settling.isEmpty else { return }
        // In steps of a quarter of the frame, so the spring keeps steady however long a frame took.
        let steps = 4
        let step = CGFloat(dt) / CGFloat(steps)
        for tuft in settling.values {
            for _ in 0..<steps { Self.move(tuft, feet: feet, moving: moving, dt: step) }
            show(tuft)
        }
        settling = settling.filter { !$0.value.isStill || Self.isNear($0.value, feet) }
    }

    /// Whether you're beside it, close enough to bend it.
    private static func isNear(_ tuft: Tuft, _ feet: CGPoint) -> Bool {
        let dx = tuft.base.x - feet.x, down = feet.y - tuft.base.y
        return abs(dx) < 13 && down > -11 && down < 9
    }

    /// Its spring, its press and its rustle, a step on.
    private static func move(_ tuft: Tuft, feet: CGPoint, moving: Bool, dt: CGFloat) {
        // Across, and how far below your feet it stands (in front of you, on screen).
        let dx = tuft.base.x - feet.x, down = feet.y - tuft.base.y
        let near = isNear(tuft, feet)
        if near, tuft.side == 0 { tuft.side = dx >= 0 ? 1 : -1 }
        if !near { tuft.side = 0 }
        let front = down >= 0 && down < 9 && abs(dx) < 9
        let most = front ? frontLean : maxLean
        let target = near ? tuft.side * most * max(0, 1 - abs(dx) / 13) : 0
        if abs(target) > 1.5, tuft.cool <= 0, moving {
            tuft.age = 0
            tuft.cool = cooldown
        }
        let w = 2 * CGFloat.pi * springHz
        tuft.velocity += (-w * w * (tuft.lean - target) - 2 * damping * w * tuft.velocity) * dt
        tuft.lean = min(maxLean, max(-maxLean, tuft.lean + tuft.velocity * dt))
        // Just behind your feet: pressed down, never at the patch's rim.
        let behind = down >= -7 && down < 0 && abs(dx) < 7 && !tuft.edge
        if behind {
            tuft.press = min(1, tuft.press + dt / pressIn)
        } else {
            tuft.press = max(0, tuft.press - dt / pressOut)
        }
        tuft.age += dt
        tuft.cool -= dt
    }

    /// Its frame for how far it leans (rustle and all) and how pressed it is, set only on a change.
    private func show(_ tuft: Tuft) {
        let shake = tuft.age < Self.shakeFor ? Self.shakePx * sin(tuft.age * Self.shakeSpeed + tuft.phase * 6) : 0
        // A flipped tuft is drawn mirrored, so it leans the other way in its own frames.
        let lean = (tuft.lean + shake) * (tuft.flipped ? -1 : 1)
        let index = min(Self.leans, max(-Self.leans, Int(lean.rounded())))
        let stage: Int = switch tuft.press {
        case ..<0.15: 0
        case ..<0.4: 1
        case ..<0.62: 2
        case ..<0.87: 3
        default: 4
        }
        guard tuft.shown.lean != index || tuft.shown.stage != stage else { return }
        tuft.shown = (index, stage)
        let row = tuft.frames[min(stage, tuft.frames.count - 1)]
        tuft.node.texture = row[min(index + Self.leans, row.count - 1)]
    }
}
