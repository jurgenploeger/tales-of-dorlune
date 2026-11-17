import SpriteKit

/// How a tree or bush moves in the wind (art/wind.json, written by tools/wind_art.py): its leaf
/// clumps, as runs of pixels (y, x, length, back to front), and each frame's whole-pixel move for
/// each (dx, dy, y down), a calm loop and then a gust. Everything else of the sprite stays put.
nonisolated struct WindRig: Decodable, Sendable {
    let size: [Int]
    let clumps: [[Int]]
    let frames: [[Int]]
}

/// art/wind.json: every rig, and the timing the game shares out among them (`WindField`).
nonisolated struct WindBook: Decodable, Sendable {
    /// Frames a second.
    let fps: Double
    /// Frames in the calm loop, and in a gust (two loops long).
    let loop: Int
    let gust: Int
    /// Points between the crests of the ripple that runs across the trees.
    let wavelength: Double
    /// Loops between one round of gusts and the next, and how tall a patch of gust is.
    let cycle: Int
    let band: Double
    /// The crown drawn again under its clumps, this much darker (red, green, blue): the shade
    /// inside the tree a gap between two shows.
    let inside: [Double]
    let rigs: [String: WindRig]

    static let shared: WindBook? = {
        guard let url = Bundle.main.url(forResource: "wind", withExtension: "json", subdirectory: "art"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(WindBook.self, from: data)
        } catch {
            print("⚠️ Couldn't read art/wind.json: \(error)")
            return nil
        }
    }()

    /// A sprite's frames in one strip, side by side: what stays, the crown's shade under the
    /// clumps, then each clump moved as that frame says. Pixels are only moved, never drawn, so
    /// it's the sprite as it's graded for the land it stands in.
    func strip(_ image: CGImage, rig: WindRig) -> CGImage? {
        let width = image.width, height = image.height
        let count = rig.frames.count
        guard rig.size == [width, height], count == loop + gust, inside.count == 3,
              let source = PixelImage.pixels(of: image, width: width, height: height) else { return nil }
        var label = [Int](repeating: 0, count: width * height)
        for (k, runs) in rig.clumps.enumerated() {
            for start in stride(from: 0, to: runs.count - 2, by: 3) {
                let y = runs[start], x = runs[start + 1], length = runs[start + 2]
                guard y >= 0, y < height, x >= 0, length > 0, x + length <= width else { return nil }
                for column in x..<(x + length) { label[y * width + column] = k + 1 }
            }
        }
        let rowWidth = width * count
        var out = [UInt8](repeating: 0, count: rowWidth * height * 4)
        for f in 0..<count {
            let moves = rig.frames[f]
            guard moves.count == rig.clumps.count * 2 else { return nil }
            let left = f * width
            for y in 0..<height {
                for x in 0..<width {
                    let from = (y * width + x) * 4, to = (y * rowWidth + left + x) * 4
                    if label[y * width + x] == 0 {
                        for c in 0..<4 { out[to + c] = source[from + c] }
                    } else {
                        for c in 0..<3 { out[to + c] = UInt8(Double(source[from + c]) * inside[c]) }
                        out[to + 3] = source[from + 3]
                    }
                }
            }
            for (k, runs) in rig.clumps.enumerated() {
                let dx = moves[2 * k], dy = moves[2 * k + 1]
                for start in stride(from: 0, to: runs.count - 2, by: 3) {
                    let y = runs[start], x = runs[start + 1], length = runs[start + 2]
                    let ty = y + dy
                    guard ty >= 0, ty < height else { continue }
                    for column in x..<(x + length) {
                        let tx = column + dx
                        guard tx >= 0, tx < width else { continue }
                        let from = (y * width + column) * 4, to = (ty * rowWidth + left + tx) * 4
                        for c in 0..<4 { out[to + c] = source[from + c] }
                    }
                }
            }
        }
        return PixelImage.make(out, width: rowWidth, height: height)
    }

    /// Which frame a tree standing at `x`, `y` (the continent's points) shows `seconds` into the
    /// wind while a gust is passing over it, timed by where it stands so the gust runs from tree
    /// to tree; nil in still air, where it stands as it's drawn (tools/wind_art.py `frame_at`).
    /// Every tree used to turn through a calm loop all the time between gusts: it drew the eye
    /// from everything else and cost the most (the user, 2026-11-17: "it makes the game very slow
    /// and it kinda distracts"). Now the land is still, and a gust crosses a patch of it every
    /// quarter minute or so.
    func gustFrame(at seconds: Double, x: Double, y: Double) -> Int? {
        let slant = x + 0.35 * y
        let u = seconds * fps / Double(loop) - slant / wavelength
        let n = u.rounded(.down)
        guard let slot = gustSlot(Int(n), y: y) else { return nil }
        let f = min(loop - 1, max(0, Int((u - n) * Double(loop))))
        return loop + slot * loop + f
    }

    /// Which of a gust's two loops a tree's loop `n` falls in, or nil in still air: gusts come
    /// round every `cycle` loops, in patches of one to three `band`s, some patches none, some
    /// two in a row (tools/wind_art.py `gust_slot`).
    private func gustSlot(_ n: Int, y: Double) -> Int? {
        let cycle = Self.floorDiv(n, self.cycle), at = n - cycle * self.cycle
        let size = 1 + Int(Self.mix([cycle, 7]) % 3)
        let patch = Self.floorDiv(Int((y / self.band).rounded(.down)) + Int(Self.mix([cycle, 11]) % 3), size)
        let roll = Self.mix([cycle, patch, 3])
        if roll % 4 == 0 { return nil }
        let start = 1 + Int((roll >> 4) % UInt32(self.cycle - 4))
        if at >= start, at < start + 2 { return at - start }
        if (roll >> 9) % 3 == 0, at >= start + 2, at < start + 4 { return at - start - 2 }
        return nil
    }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    /// A small hash of whole numbers (FNV-1a, then mixed), the same as tools/wind_art.py `mix`.
    private static func mix(_ values: [Int]) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for value in values {
            h = (h ^ UInt32(truncatingIfNeeded: value)) &* 16_777_619
        }
        h ^= h >> 15
        h = h &* 2_246_822_519
        h ^= h >> 13
        return h
    }
}

/// The wind over the land you're in: one clock for every tree and bush that moves in it, so the
/// ripple and the gusts run on from one to the next. Each shows the frame of its strip
/// (`ArtLibrary.windFrames`) the wind says for where it stands (`WindBook.frame`), ten times a
/// second, while it's in the scene. Its clock stops while the scene does (a battle, a menu).
final class WindField {
    static let shared = WindField()

    /// One tree or bush in the wind. A class, so going through them each tick copies none: as a
    /// struct with weak references every copy went through the weak table, thousands ten times a
    /// second, and a run from Xcode stopped in one being destroyed (`weak_entry_for_referent`,
    /// 2026-11-17).
    private final class Tree {
        weak var node: SKSpriteNode?
        /// Its picture as drawn: what it shows in still air.
        let rest: SKTexture?
        /// The land it's in (`LandStage.world`), by its identity: hidden, far from you, its trees
        /// keep still (`hide`).
        let land: ObjectIdentifier?
        let frames: [SKTexture]
        let x: Double
        let y: Double

        init(node: SKSpriteNode, land: ObjectIdentifier?, frames: [SKTexture], x: Double, y: Double) {
            self.node = node
            rest = node.texture
            self.land = land
            self.frames = frames
            self.x = x
            self.y = y
        }
    }

    private var trees: [Tree] = []
    /// The lands hidden far off (`hide`).
    private var hidden: Set<ObjectIdentifier> = []
    private var clock: TimeInterval = 0
    private var shownTick = -1
    /// How many there may be before those gone (a land let go) are dropped.
    private var prunedAt = 4096

    /// `node` moves in the wind from now on, by `frames`, standing at `point` (the continent's
    /// points, or a cave's own).
    func add(_ node: SKSpriteNode, frames: [SKTexture], at point: CGPoint, land: SKNode? = nil) {
        guard let book = WindBook.shared, frames.count == book.loop + book.gust else { return }
        let tree = Tree(node: node, land: land.map { ObjectIdentifier($0) }, frames: frames, x: Double(point.x), y: Double(point.y))
        if let frame = book.gustFrame(at: clock, x: tree.x, y: tree.y) { node.texture = frames[frame] }
        trees.append(tree)
        if trees.count > prunedAt {
            trees.removeAll { $0.node == nil }
            prunedAt = max(4096, trees.count * 2)
        }
    }

    /// A land's trees keep still while it's hidden far off, and move again once it's shown
    /// (`ContinentScene.lookAround`; the speed audit, 2026-11-17: they kept swapping pictures).
    func hide(_ land: SKNode, _ isHidden: Bool) {
        if isHidden {
            hidden.insert(ObjectIdentifier(land))
        } else {
            hidden.remove(ObjectIdentifier(land))
        }
    }

    /// Moves the wind on by `dt` (the scene's `update`).
    func tick(_ dt: TimeInterval) {
        guard let book = WindBook.shared else { return }
        clock += dt
        let tick = Int(clock * book.fps)
        guard tick != shownTick else { return }
        shownTick = tick
        for tree in trees {
            if let land = tree.land, hidden.contains(land) { continue }
            // Only what's on stage: a chunk out of sight waits.
            guard let node = tree.node, node.scene != nil else { continue }
            let texture = book.gustFrame(at: clock, x: tree.x, y: tree.y).map { tree.frames[$0] } ?? tree.rest
            if node.texture !== texture { node.texture = texture }
        }
    }
}
