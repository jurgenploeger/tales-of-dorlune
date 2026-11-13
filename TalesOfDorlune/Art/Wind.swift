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
    /// wind: its place in the calm loop, timed by where it stands so a ripple runs from tree to
    /// tree, and in a gust when one is passing over it (tools/wind_art.py `frame_at`).
    func frame(at seconds: Double, x: Double, y: Double) -> Int {
        let slant = x + 0.35 * y
        let u = seconds * fps / Double(loop) - slant / wavelength
        let n = u.rounded(.down)
        let f = min(loop - 1, max(0, Int((u - n) * Double(loop))))
        guard let slot = gustSlot(Int(n), y: y) else { return f }
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

    private struct Tree {
        weak var node: SKSpriteNode?
        let frames: [SKTexture]
        let x: Double
        let y: Double
    }

    private var trees: [Tree] = []
    private var clock: TimeInterval = 0
    private var shownTick = -1
    /// How many there may be before those gone (a land let go) are dropped.
    private var prunedAt = 4096

    /// `node` moves in the wind from now on, by `frames`, standing at `point` (the continent's
    /// points, or a cave's own).
    func add(_ node: SKSpriteNode, frames: [SKTexture], at point: CGPoint) {
        guard let book = WindBook.shared, frames.count == book.loop + book.gust else { return }
        let tree = Tree(node: node, frames: frames, x: Double(point.x), y: Double(point.y))
        node.texture = frames[book.frame(at: clock, x: tree.x, y: tree.y)]
        trees.append(tree)
        if trees.count > prunedAt {
            trees.removeAll { $0.node == nil }
            prunedAt = max(4096, trees.count * 2)
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
            // Only what's on stage: a chunk out of sight waits.
            guard let node = tree.node, node.scene != nil else { continue }
            let texture = tree.frames[book.frame(at: clock, x: tree.x, y: tree.y)]
            if node.texture !== texture { node.texture = texture }
        }
    }
}
