import SpriteKit
import UIKit

/// Shade under the trees, buildings and everything else that stands (the user, 2026-11-14, after a
/// clip of a pixel-art forest whose floor lies in deep shade under the trees, light falling through
/// between them, and its prototype in `tools/canopy_preview.py`: "looks great so we can apply
/// that"; then "every building and other object in the game should also have the shadow"). Each
/// thing's own outline is laid on the ground away from the sun (`Sun`), its top falling farthest,
/// so it's short at midday and long in the evening; all of it is merged into one, so where two
/// shadows overlap it doesn't darken twice, in hard steps (a core and a one-pixel paler rim), with
/// flecks of light where the leaves part. It multiplies the ground, as the night's shade does
/// (`Sky`): an opaque picture, white where there's no shade, so its texture still shows, a little
/// cool (`CanopyPainter.lean`, the same in every land: leaning toward each palette's own shadow
/// colour turned a desert's sand red, playtesting 2026-11-14). It stops at a town's wall: it doesn't
/// fall on past it. Walkers and scenery stand over it in their own colours.
///
/// Drawn one of `LandStage`'s chunks at a time, a pixel a point, while the chunk is shown, and again
/// once the sun has moved on far enough to show. The pixels are worked out off the main thread
/// (`CanopyPainter.render`, from a copy of what reaches the chunk), so the game doesn't stall while
/// they're drawn (worked out on it, the game went slow, playtesting 2026-11-14); only the finished
/// picture is put in on the main thread. Each chunk's picture covers its own square and no more,
/// from every caster near enough to reach it, so the chunks meet without a seam. Only on flat
/// ground: on a hill or the sunk shore a prop keeps its round shadow (`Lighting.Shadow`), sorted
/// with the strips it lies over. `tools/canopy_preview.py` mirrors it; keep the two in step.
final class CanopyShade {
    /// The chunks' size in points (`LandStage.chunkSize`).
    private let size: CGFloat
    /// The layer of `LandStage`'s chunk at a point where the ground's shadows lie.
    private let layer: (CGPoint) -> SKNode
    /// Its town's wall cells, which the shade stops at, and the map they're in.
    private let walls: Set<GridPoint>
    private let map: WorldMap
    private var casters: [GridPoint: [CanopyPainter.Caster]] = [:]
    private var outlines: [Outline: [CanopyPainter.Slice]] = [:]
    private var nodes: [GridPoint: SKSpriteNode] = [:]
    /// The chunks any caster's shade could reach, those to draw again, and those being drawn now.
    private var reached: Set<GridPoint> = []
    private var stale: Set<GridPoint> = []
    private var drawing: Set<GridPoint> = []
    /// Counts each move of the sun: a picture drawn for an earlier one is drawn again.
    private var generation = 0
    /// The chunks in the scene now (`show(low:high:)`).
    private var shown: (low: GridPoint, high: GridPoint)?
    /// Where the shade falls per point of height (right and up on screen), and how strong it is,
    /// as drawn.
    private var fall: CGVector
    private var strength: Double
    /// How many chunks round a caster its shade can reach: a tall building's 2.2 heights.
    private static let reachChunks = 2
    /// Pictures being worked out at once, at most.
    private static let parallel = 2
    /// Things shorter than this (points) cast none: a flower's would be a speck.
    private static let shortest: CGFloat = 12

    /// A texture anchored at a height: its outline's slices are the same at any size, in its widths
    /// and heights.
    private struct Outline: Hashable {
        let texture: ObjectIdentifier
        let anchor: CGFloat
    }

    init(size: CGFloat, walls: Set<GridPoint>, map: WorldMap, layer: @escaping (CGPoint) -> SKNode) {
        self.size = size
        self.walls = walls
        self.map = map
        self.layer = layer
        let noon = CanopyShade.falling(from: .noon)
        fall = noon.fall
        strength = noon.strength
    }

    /// Where shade falls from `sun`, per point of height above the ground, on screen, and how strong.
    static func falling(from sun: Sun) -> (fall: CGVector, strength: Double) {
        let reach = CanopyPainter.reach, longest = CanopyPainter.longest
        let k = reach / 0.866 / max(sun.z, 0.05)
        var dx = 0.70710678 * (sun.y - sun.x) * k
        var dy = 0.35355339 * (-sun.x - sun.y) * k
        let length = (dx * dx + dy * dy).squareRoot()
        if length > longest {
            dx *= longest / length
            dy *= longest / length
        }
        return (CGVector(dx: CGFloat(dx), dy: CGFloat(dy)), sun.strength)
    }

    /// `node` casts shade from now on, its outline that of `picture` (its texture's).
    func add(_ node: SKSpriteNode, picture: CGImage) {
        guard let texture = node.texture, node.size.height >= Self.shortest else { return }
        let outline = Outline(texture: ObjectIdentifier(texture), anchor: node.anchorPoint.y)
        let unit = outlines[outline] ?? CanopyPainter.slices(of: picture, anchor: node.anchorPoint)
        outlines[outline] = unit
        guard !unit.isEmpty else { return }
        let w = node.size.width, h = node.size.height
        let slices = unit.map { CanopyPainter.Slice(dx: $0.dx * w, up: $0.up * h, half: $0.half * w) }
        let caster = CanopyPainter.Caster(foot: node.position, slices: slices)
        let home = key(at: node.position)
        casters[home, default: []].append(caster)
        for dc in -Self.reachChunks...Self.reachChunks {
            for dr in -Self.reachChunks...Self.reachChunks {
                let spot = GridPoint(col: home.col + dc, row: home.row + dr)
                reached.insert(spot)
                stale.insert(spot)
            }
        }
    }

    /// Lays the shade away from `sun` from now on: drawn again once it has moved far enough to show
    /// (the tip of a tall tree's shade a few points).
    func follow(_ sun: Sun) {
        let next = CanopyShade.falling(from: sun)
        guard abs(next.fall.dx - fall.dx) + abs(next.fall.dy - fall.dy) > 0.03 || next.strength != strength else { return }
        fall = next.fall
        strength = next.strength
        generation += 1
        stale.formUnion(reached)
    }

    /// The chunks from `low` to `high` are in the scene. Those more than a chunk outside let their
    /// pictures go, to be drawn again when they're back; those just past the edge keep theirs, so
    /// walking to and fro doesn't draw them over and over.
    func show(low: GridPoint, high: GridPoint) {
        shown = (low, high)
        for (spot, node) in nodes where node.texture != nil {
            let near = spot.col >= low.col - 1 && spot.col <= high.col + 1 && spot.row >= low.row - 1 && spot.row <= high.row + 1
            guard !near else { continue }
            node.texture = nil
            node.isHidden = true
            stale.insert(spot)
        }
    }

    /// Starts working out shown chunks whose shade is out of date, a couple at a time, off the main
    /// thread. Call once a frame.
    func draw() {
        guard !stale.isEmpty, shown != nil, drawing.count < Self.parallel else { return }
        let due = stale.filter { isShown($0) && !drawing.contains($0) }.prefix(Self.parallel - drawing.count)
        for spot in due {
            stale.remove(spot)
            drawing.insert(spot)
            let job = CanopyPainter.Job(left: CGFloat(spot.col) * size, bottom: CGFloat(spot.row) * size, side: Int(size),
                                        fall: fall, strength: strength, casters: reaching(spot),
                                        walls: walls, map: walls.isEmpty ? nil : map)
            let drawnFor = generation
            Task.detached(priority: .utility) { [weak self] in
                let pixels = CanopyPainter.render(job)
                await self?.finish(spot, pixels: pixels, generation: drawnFor)
            }
        }
    }

    /// Every caster whose shade could reach the chunk at `spot` (worked out on the main thread, as
    /// cheap as a box round each shade can make it).
    private func reaching(_ spot: GridPoint) -> [CanopyPainter.Caster] {
        let left = CGFloat(spot.col) * size, bottom = CGFloat(spot.row) * size
        let margin = CGFloat(CanopyPainter.margin) + 1
        var found: [CanopyPainter.Caster] = []
        for dc in -Self.reachChunks...Self.reachChunks {
            for dr in -Self.reachChunks...Self.reachChunks {
                guard let near = casters[GridPoint(col: spot.col + dc, row: spot.row + dr)] else { continue }
                for caster in near {
                    let tip = CGPoint(x: caster.foot.x + fall.dx * caster.tallest, y: caster.foot.y + fall.dy * caster.tallest)
                    let reach = caster.widest + margin
                    guard max(caster.foot.x, tip.x) + reach >= left, min(caster.foot.x, tip.x) - reach <= left + size,
                          max(caster.foot.y, tip.y) + reach >= bottom, min(caster.foot.y, tip.y) - reach <= bottom + size else { continue }
                    found.append(caster)
                }
            }
        }
        return found
    }

    /// A chunk's picture is worked out: put in, unless the sun has moved on since (then it's drawn again).
    private func finish(_ spot: GridPoint, pixels: [UInt8]?, generation drawnFor: Int) {
        drawing.remove(spot)
        guard drawnFor == generation else {
            stale.insert(spot)
            return
        }
        guard let pixels else {
            nodes[spot]?.removeFromParent()
            nodes[spot] = nil
            return
        }
        let side = Int(size)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        let node: SKSpriteNode
        if let known = nodes[spot] {
            node = known
        } else {
            node = SKSpriteNode(texture: nil, size: CGSize(width: size, height: size))
            // Multiplied over the ground, as the night's shade is (`Sky`): white leaves it as it is.
            node.blendMode = .multiply
            node.position = CGPoint(x: (CGFloat(spot.col) + 0.5) * size, y: (CGFloat(spot.row) + 0.5) * size)
            // Where the round shadows on flat ground lay: over the ground, under everything that stands.
            node.zPosition = -99_300
            layer(node.position).addChild(node)
            nodes[spot] = node
        }
        node.texture = texture
        node.size = CGSize(width: size, height: size)
        node.isHidden = false
    }

    private func isShown(_ spot: GridPoint) -> Bool {
        guard let shown else { return false }
        return spot.col >= shown.low.col && spot.col <= shown.high.col && spot.row >= shown.low.row && spot.row <= shown.high.row
    }

    private func key(at point: CGPoint) -> GridPoint {
        GridPoint(col: Int((point.x / size).rounded(.down)), row: Int((point.y / size).rounded(.down)))
    }
}

/// The shade's drawing (`CanopyShade`), on any thread: only values in and pixels out.
nonisolated enum CanopyPainter {
    /// How far the ground is pulled into shade, and the one-pixel rim round it.
    static let core = 0.72
    static let rim = 0.32
    /// How long the shade is next to real geometry (real shadows read far too long at midday), and
    /// the longest it gets, in heights of what casts it (the low evening sun).
    static let reach = 0.55
    static let longest = 2.2
    /// The flecks of light: blobs of value noise about this many points across, where it's over
    /// `fleckCut` (about 3.5% of it), only well inside the shade.
    static let fleckCell = 9.0
    static let fleckCut = 0.875
    /// What a shaded pixel multiplies the ground by, at full shade, per channel: darker, a little cool.
    static let lean = (r: 0.42, g: 0.5, b: 0.72)
    /// A border round each chunk's picture worked out but not shown, so its rim and flecks meet the
    /// next chunk's.
    static let margin = 5

    /// A run of one row of an outline: how far right of the foot its middle is, how high above the
    /// foot, and half its width: in points, or in the texture's widths and heights in an outline.
    struct Slice: Sendable {
        let dx: CGFloat
        let up: CGFloat
        let half: CGFloat
    }

    /// Something that casts shade: where its foot is, its outline's slices in points, and how tall
    /// and how far its outline reaches out from the foot.
    struct Caster: Sendable {
        let foot: CGPoint
        let slices: [Slice]
        let tallest: CGFloat
        let widest: CGFloat

        init(foot: CGPoint, slices: [Slice]) {
            self.foot = foot
            self.slices = slices
            tallest = slices.map(\.up).max() ?? 0
            widest = slices.map { abs($0.dx) + $0.half }.max() ?? 0
        }
    }

    /// One chunk's picture to work out: its bottom left corner in the land's points, its side in
    /// pixels, the sun's fall and strength, what reaches it, and the town's wall in `map`, if any.
    struct Job: Sendable {
        let left: CGFloat
        let bottom: CGFloat
        let side: Int
        let fall: CGVector
        let strength: Double
        let casters: [Caster]
        let walls: Set<GridPoint>
        let map: WorldMap?
    }

    /// The chunk's picture, RGBA a pixel a point from its top left, or nil where no shade falls on it.
    static func render(_ job: Job) -> [UInt8]? {
        let side = job.side, m = margin, full = side + 2 * m
        // The picture's top left corner, in the land's points (y up), and each pixel a point.
        let left = job.left - CGFloat(m)
        let top = job.bottom + CGFloat(side + m)
        var mask = [Bool](repeating: false, count: full * full)
        var any = false
        for caster in job.casters {
            let stop = reachBeforeWall(caster, job: job)
            for slice in caster.slices where slice.up <= stop {
                // Each run of the outline is a slice of a round crown: its shade a round on the
                // ground (an ellipse half as tall as it's wide, as `WorldMap.project` draws it),
                // moved along the ground by the slice's height above the foot.
                let cx = caster.foot.x + slice.dx + job.fall.dx * slice.up - left
                let cy = top - (caster.foot.y + job.fall.dy * slice.up)
                if fill(&mask, side: full, cx: cx, cy: cy, rx: slice.half, ry: max(0.5, slice.half / 2)) { any = true }
            }
        }
        guard any else { return nil }
        // Flecks of light where the leaves part: only well inside the shade, so a fleck never
        // opens onto its edge.
        var fleck = [Bool](repeating: false, count: full * full)
        for y in 3..<(full - 3) {
            for x in 4..<(full - 4) where mask[y * full + x] {
                guard mask[y * full + x - 4], mask[y * full + x + 4], mask[(y - 3) * full + x], mask[(y + 3) * full + x] else { continue }
                if noise(Double(left) + Double(x) + 0.5, Double(top) - Double(y) - 0.5) > fleckCut { fleck[y * full + x] = true }
            }
        }
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        let power = job.strength
        // Each step's colour, worked out once.
        func shaded(_ shade: Double) -> (UInt8, UInt8, UInt8) {
            let a = shade * power
            return (UInt8((255 * (1 - a * (1 - lean.r))).rounded()), UInt8((255 * (1 - a * (1 - lean.g))).rounded()),
                    UInt8((255 * (1 - a * (1 - lean.b))).rounded()))
        }
        let coreColour = shaded(core), rimColour = shaded(rim)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y + m) * full + x + m
                let colour: (UInt8, UInt8, UInt8)
                if mask[i] {
                    // A fleck is lit, with a rim of half shade round it, in steps as the shade's own edge.
                    if fleck[i] { continue }
                    colour = fleck[i - 1] || fleck[i + 1] || fleck[i - full] || fleck[i + full] ? rimColour : coreColour
                } else if mask[i - 1] || mask[i + 1] || mask[i - full] || mask[i + full] {
                    colour = rimColour
                } else {
                    continue
                }
                let o = (y * side + x) * 4
                pixels[o] = colour.0
                pixels[o + 1] = colour.1
                pixels[o + 2] = colour.2
            }
        }
        return pixels
    }

    /// How high up `caster` its shade can come from before it would fall past the town's wall: the
    /// shade is followed from its foot away from the sun, a few points at a time, to the first point
    /// in a wall. Unlimited where the land has no wall.
    private static func reachBeforeWall(_ caster: Caster, job: Job) -> CGFloat {
        guard let map = job.map else { return .greatestFiniteMagnitude }
        let length = (job.fall.dx * job.fall.dx + job.fall.dy * job.fall.dy).squareRoot()
        guard length > 0.01 else { return .greatestFiniteMagnitude }
        let reach = caster.tallest * length, step: CGFloat = 4
        var along: CGFloat = step
        while along <= reach {
            let point = CGPoint(x: caster.foot.x + job.fall.dx / length * along, y: caster.foot.y + job.fall.dy / length * along)
            if job.walls.contains(map.cell(at: point)) { return along / length }
            along += step
        }
        return .greatestFiniteMagnitude
    }

    /// Fills an ellipse into `mask` (`side` pixels square, row 0 at the top): its middle at (`cx`,
    /// `cy`) in pixels from the top left, `rx` and `ry` its half width and height. Whether it
    /// touched the mask at all.
    private static func fill(_ mask: inout [Bool], side: Int, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Bool {
        let extent = CGFloat(side)
        guard cx + rx >= 0, cx - rx <= extent, cy + ry >= 0, cy - ry <= extent else { return false }
        let first = max(0, Int((cy - ry - 0.5).rounded(.up))), last = min(side - 1, Int((cy + ry - 0.5).rounded(.down)))
        guard first <= last else { return false }
        var touched = false
        for row in first...last {
            let dy = (CGFloat(row) + 0.5 - cy) / ry
            let left = 1 - dy * dy
            guard left >= 0 else { continue }
            let half = rx * left.squareRoot()
            let from = max(0, Int((cx - half - 0.5).rounded(.up))), to = min(side - 1, Int((cx + half - 0.5).rounded(.down)))
            guard from <= to else { continue }
            for x in from...to { mask[row * side + x] = true }
            touched = true
        }
        return touched
    }

    /// Smooth value noise over the land's points, about `fleckCell` across, 0...1, the same on
    /// either side of a chunk's border.
    private static func noise(_ x: Double, _ y: Double) -> Double {
        let fx = x / fleckCell, fy = y / fleckCell
        let ix = fx.rounded(.down), iy = fy.rounded(.down)
        var tx = fx - ix, ty = fy - iy
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        let i = Int(ix), j = Int(iy)
        let a = lattice(i, j), b = lattice(i + 1, j), c = lattice(i, j + 1), d = lattice(i + 1, j + 1)
        let low = a + (b - a) * tx, high = c + (d - c) * tx
        return low + (high - low) * ty
    }

    /// A value 0..<1 for each corner of the noise's grid, from a hash of where it is.
    private static func lattice(_ i: Int, _ j: Int) -> Double {
        var h = (UInt64(bitPattern: Int64(i)) &* 0x9E37_79B9_7F4A_7C15) ^ (UInt64(bitPattern: Int64(j)) &* 0xC2B2_AE3D_27D4_EB4F)
        h ^= h >> 33
        h = h &* 0xFF51_AFD7_ED55_8CCD
        h ^= h >> 33
        return Double(h >> 11) / Double(UInt64(1) << 53)
    }

    /// `picture`'s outline as runs of each row (alpha over half), from the foot of a node anchored at
    /// `anchor`, in its widths and heights: rows below the foot left out.
    static func slices(of picture: CGImage, anchor: CGPoint) -> [Slice] {
        let w = picture.width, h = picture.height
        guard w > 0, h > 0 else { return [] }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(picture, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return [] }
        var slices: [Slice] = []
        // Row 0 is the picture's top.
        for row in 0..<h {
            let up = (CGFloat(h - row) - 0.5) / CGFloat(h) - anchor.y
            guard up >= 0 else { continue }
            var start: Int?
            for x in 0...w {
                let solid = x < w && pixels[(row * w + x) * 4 + 3] > 127
                if solid, start == nil { start = x }
                if !solid, let from = start {
                    let middle = CGFloat(from + x) / 2 / CGFloat(w) - anchor.x
                    slices.append(Slice(dx: middle, up: up, half: CGFloat(x - from) / 2 / CGFloat(w)))
                    start = nil
                }
            }
        }
        return slices
    }
}
