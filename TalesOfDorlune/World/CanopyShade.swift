import SpriteKit
import UIKit

/// Shade under the trees (the user, 2026-11-14, after a clip of a pixel-art forest whose floor lies
/// in deep shade under the trees, light falling through between them, and its prototype in
/// `tools/canopy_preview.py`: "looks great so we can apply that"). Each piece of scenery's own
/// outline is laid on the ground away from the sun (`Sun`), the top of its crown falling farthest,
/// so it's short at midday and long in the evening; all of it is merged into one, so where two
/// trees' shade overlaps it doesn't darken twice, in hard steps (a core and a one-pixel paler rim),
/// with flecks of light where the leaves part. It multiplies the ground, as the night's shade does
/// (`Sky`): an opaque picture, white where there's no shade, so its texture still shows, leaning
/// toward the land's palette shadow colour. Walkers and scenery stand over it in their own colours.
///
/// Drawn one of `LandStage`'s chunks at a time, a pixel a point, only while the chunk is shown,
/// a couple of chunks a frame, and again once the sun has moved on far enough to show. Each chunk's
/// picture covers its own square and no more, from every caster near enough to reach it, so the
/// chunks meet without a seam. Only scenery on flat ground casts it: on a hill or the sunk shore
/// it keeps its round shadow (`Lighting.Shadow`), sorted with the strips it lies over.
/// `tools/canopy_preview.py` mirrors it; keep the two in step.
final class CanopyShade {
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
    /// A border round each chunk's picture worked out but not shown, so its rim and flecks meet the
    /// next chunk's.
    private static let margin = 5
    /// How many chunks round a caster its shade can reach: a tall tree's 2.2 heights.
    private static let reachChunks = 2

    /// A run of one row of an outline: how far right of the foot its middle is, how high above the
    /// foot, and half its width: in points, or in the texture's widths and heights in `outlines`.
    private struct Slice {
        let dx: CGFloat
        let up: CGFloat
        let half: CGFloat
    }

    private struct Caster {
        let foot: CGPoint
        let slices: [Slice]
    }

    /// A texture anchored at a height: its outline's slices are the same at any size, in its widths
    /// and heights.
    private struct Outline: Hashable {
        let texture: ObjectIdentifier
        let anchor: CGFloat
    }

    /// The chunks' size in points (`LandStage.chunkSize`), and in pixels.
    private let size: CGFloat
    private let side: Int
    /// What a shaded pixel multiplies the ground by, at full shade, per channel.
    private let lean: (r: Double, g: Double, b: Double)
    /// The layer of `LandStage`'s chunk at a point where the ground's shadows lie.
    private let layer: (CGPoint) -> SKNode
    private var casters: [GridPoint: [Caster]] = [:]
    private var outlines: [Outline: [Slice]] = [:]
    private var nodes: [GridPoint: SKSpriteNode] = [:]
    /// The chunks any caster's shade could reach, and those to draw again.
    private var reached: Set<GridPoint> = []
    private var stale: Set<GridPoint> = []
    /// The chunks in the scene now (`show(low:high:)`).
    private var shown: (low: GridPoint, high: GridPoint)?
    /// Where the shade falls per point of height (right and up on screen), and how strong it is,
    /// as drawn.
    private var fall: CGVector
    private var strength: Double

    init(size: CGFloat, palette: MapPalette?, layer: @escaping (CGPoint) -> SKNode) {
        self.size = size
        side = Int(size)
        let dark = Lighting.rgb(palette?.shadow) ?? (r: 0.165, g: 0.227, b: 0.333)
        let luma = max(0.001, 0.299 * dark.r + 0.587 * dark.g + 0.114 * dark.b)
        func toward(_ channel: Double) -> Double { min(1, max(0.25, channel / luma * 0.5)) }
        lean = (toward(dark.r), toward(dark.g), toward(dark.b))
        self.layer = layer
        let noon = CanopyShade.falling(from: .noon)
        fall = noon.fall
        strength = noon.strength
    }

    /// Where shade falls from `sun`, per point of height above the ground, on screen, and how strong.
    private static func falling(from sun: Sun) -> (fall: CGVector, strength: Double) {
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
        guard let texture = node.texture else { return }
        let outline = Outline(texture: ObjectIdentifier(texture), anchor: node.anchorPoint.y)
        let unit = outlines[outline] ?? Self.slices(of: picture, anchor: node.anchorPoint)
        outlines[outline] = unit
        guard !unit.isEmpty else { return }
        let w = node.size.width, h = node.size.height
        let slices = unit.map { Slice(dx: $0.dx * w, up: $0.up * h, half: $0.half * w) }
        let home = key(at: node.position)
        casters[home, default: []].append(Caster(foot: node.position, slices: slices))
        for dc in -Self.reachChunks...Self.reachChunks {
            for dr in -Self.reachChunks...Self.reachChunks {
                let spot = GridPoint(col: home.col + dc, row: home.row + dr)
                reached.insert(spot)
                stale.insert(spot)
            }
        }
    }

    /// Lays the shade away from `sun` from now on: drawn again once it has moved far enough to show
    /// (the tip of a tall tree's shade a couple of points).
    func follow(_ sun: Sun) {
        let next = Self.falling(from: sun)
        guard abs(next.fall.dx - fall.dx) + abs(next.fall.dy - fall.dy) > 0.015 || next.strength != strength else { return }
        fall = next.fall
        strength = next.strength
        stale.formUnion(reached)
    }

    /// The chunks from `low` to `high` are in the scene: the rest let their pictures go, to be drawn
    /// again when they're back.
    func show(low: GridPoint, high: GridPoint) {
        shown = (low, high)
        for (spot, node) in nodes where !isShown(spot) && node.texture != nil {
            node.texture = nil
            node.isHidden = true
            stale.insert(spot)
        }
    }

    /// Draws up to `budget` shown chunks whose shade is out of date. Call once a frame.
    func draw(budget: Int) {
        guard !stale.isEmpty, shown != nil else { return }
        let due = stale.filter { isShown($0) }.prefix(budget)
        for spot in due {
            stale.remove(spot)
            paint(spot)
        }
    }

    private func isShown(_ spot: GridPoint) -> Bool {
        guard let shown else { return false }
        return spot.col >= shown.low.col && spot.col <= shown.high.col && spot.row >= shown.low.row && spot.row <= shown.high.row
    }

    private func key(at point: CGPoint) -> GridPoint {
        GridPoint(col: Int((point.x / size).rounded(.down)), row: Int((point.y / size).rounded(.down)))
    }

    // MARK: Drawing

    /// The chunk at `spot`'s shade, from every caster near enough to reach it.
    private func paint(_ spot: GridPoint) {
        let m = Self.margin, full = side + 2 * m
        // The picture's top left corner, in the land's points (y up), and each pixel a point.
        let left = CGFloat(spot.col) * size - CGFloat(m)
        let top = CGFloat(spot.row + 1) * size + CGFloat(m)
        var mask = [Bool](repeating: false, count: full * full)
        var any = false
        for dc in -Self.reachChunks...Self.reachChunks {
            for dr in -Self.reachChunks...Self.reachChunks {
                guard let near = casters[GridPoint(col: spot.col + dc, row: spot.row + dr)] else { continue }
                for caster in near {
                    for slice in caster.slices {
                        // Each run of the outline is a slice of a round crown: its shade a round on the
                        // ground (an ellipse half as tall as it's wide, as `WorldMap.project` draws it),
                        // moved along the ground by the slice's height above the foot.
                        let cx = caster.foot.x + slice.dx + fall.dx * slice.up - left
                        let cy = top - (caster.foot.y + fall.dy * slice.up)
                        if Self.fill(&mask, side: full, cx: cx, cy: cy, rx: slice.half, ry: max(0.5, slice.half / 2)) { any = true }
                    }
                }
            }
        }
        guard any else {
            nodes[spot]?.removeFromParent()
            nodes[spot] = nil
            return
        }
        // Flecks of light where the leaves part: only well inside the shade, so a fleck never
        // opens onto its edge.
        var fleck = [Bool](repeating: false, count: full * full)
        for y in 3..<(full - 3) {
            for x in 4..<(full - 4) where mask[y * full + x] {
                guard mask[y * full + x - 4], mask[y * full + x + 4], mask[(y - 3) * full + x], mask[(y + 3) * full + x] else { continue }
                let noise = Self.noise(Double(left) + Double(x) + 0.5, Double(top) - Double(y) - 0.5)
                if noise > Self.fleckCut { fleck[y * full + x] = true }
            }
        }
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        let power = strength
        for y in 0..<side {
            for x in 0..<side {
                let i = (y + m) * full + x + m
                var shade = 0.0
                if mask[i] {
                    // A fleck is lit, with a rim of half shade round it, in steps as the shade's own edge.
                    if fleck[i] {
                        shade = 0
                    } else if fleck[i - 1] || fleck[i + 1] || fleck[i - full] || fleck[i + full] {
                        shade = Self.rim
                    } else {
                        shade = Self.core
                    }
                } else if mask[i - 1] || mask[i + 1] || mask[i - full] || mask[i + full] {
                    shade = Self.rim
                }
                guard shade > 0 else { continue }
                let a = shade * power, o = (y * side + x) * 4
                pixels[o] = UInt8((255 * (1 - a * (1 - lean.r))).rounded())
                pixels[o + 1] = UInt8((255 * (1 - a * (1 - lean.g))).rounded())
                pixels[o + 2] = UInt8((255 * (1 - a * (1 - lean.b))).rounded())
            }
        }
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

    // MARK: Outlines

    /// `picture`'s outline as runs of each row (alpha over half), from the foot of a node anchored at
    /// `anchor`, in its widths and heights: rows below the foot left out.
    private static func slices(of picture: CGImage, anchor: CGPoint) -> [Slice] {
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
