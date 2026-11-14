import SpriteKit

/// The lamps' light on what stands round them at night, after SpriteCook's "Normal maps for pixel art
/// from the sprite's outline": which way each pixel of a sprite faces is worked out from its outline
/// (`OutlineNormals`), so the side of a house, a rock or a crate toward a street lamp or a glowing
/// prop catches its light, in a few hard steps as pixel art is lit, and the far side stays in the
/// night. Drawn as a copy of the sprite added over it (`lit`), faded in as it grows dark and gone by
/// day, so by day nothing's changed. Mirrored in `tools/normal_art.py`.
final class LampLight {
    static let shared = LampLight()

    /// A light: where it shines from (the continent's points, or a land's own) and its colour.
    struct Lamp {
        let point: CGPoint
        let color: (r: Double, g: Double, b: Double)
    }

    /// How far a lamp's light reaches, in points, and how bright it is on what stands beside it.
    static let reach: CGFloat = 150
    static let brightest: CGFloat = 1
    /// How much the light adds to a pixel that faces it fully: half again its colour (in the lamp's).
    static let boost = 1.5

    private struct Lit {
        weak var node: SKSpriteNode?
        let strength: CGFloat
    }
    private var lit: [Lit] = []
    private var night: CGFloat = 0
    private var prunedAt = 1024
    /// The light's copies by sprite picture, the way it comes from (one of eight) and its colour.
    private var copies: [String: SKTexture?] = [:]

    /// Lights `node` (showing `picture`, standing at `node.position`) from the nearest of `lamps`
    /// within reach, if any: a copy of it, lit from that way, over it.
    func light(_ node: SKSpriteNode, picture: CGImage, key: String, from lamps: [Lamp]) {
        // Where the light falls on it: halfway up what it shows.
        let middle = CGPoint(x: node.position.x, y: node.position.y + node.size.height * (0.5 - node.anchorPoint.y))
        guard let nearest = lamps.map({ (lamp: $0, distance: hypot($0.point.x - middle.x, $0.point.y - middle.y)) })
                .min(by: { $0.distance < $1.distance }),
              nearest.distance < Self.reach, nearest.distance > 4 else { return }
        let lamp = nearest.lamp, distance = nearest.distance
        // Eight ways round, as a lamp's light reaches it on screen.
        let angle = atan2(lamp.point.y - middle.y, lamp.point.x - middle.x)
        let way = (Int((angle / (.pi / 4)).rounded()) % 8 + 8) % 8
        guard let texture = copy(of: picture, key: key, way: way, color: lamp.color) else { return }
        let copy = SKSpriteNode(texture: texture, size: node.size)
        copy.anchorPoint = node.anchorPoint
        copy.blendMode = .add
        copy.zPosition = 0.01
        // Nearer, brighter, in steps.
        let near = 1 - distance / Self.reach
        let strength = Self.brightest * (near * 3).rounded(.up) / 3
        copy.alpha = night * strength
        copy.isHidden = night <= 0.01
        // Its child, so it fades with it as someone walks behind it (`SeeThrough`) and goes with it.
        node.addChild(copy)
        lit.append(Lit(node: copy, strength: strength))
        if lit.count > prunedAt {
            lit.removeAll { $0.node == nil }
            prunedAt = max(1024, lit.count * 2)
        }
    }

    /// `picture` (known by `key`) lit from `way` (0 the right, counting round toward the top) in
    /// `color`, kept for the next ask: the lamps' and the cave lantern's (`LanternLight`). Nil where
    /// nothing of it faces that way.
    func copy(of picture: CGImage, key: String, way: Int, color: (r: Double, g: Double, b: Double)) -> SKTexture? {
        let colorKey = String(format: "%.2f,%.2f,%.2f", color.r, color.g, color.b)
        let copyKey = "\(key)#\(way)#\(colorKey)"
        if let known = copies[copyKey] { return known }
        let made = makeCopy(of: picture, way: way, color: color)
        copies[copyKey] = .some(made)
        return made
    }

    /// How dark it's grown, 0 by day to 1 at night (`Sky.darkness`): the lamps' light fades in with it.
    func setNight(_ amount: CGFloat) {
        let amount = max(0, min(1, amount))
        guard abs(amount - night) > 0.01 || (amount == 0) != (night == 0) else { return }
        night = amount
        for entry in lit {
            guard let node = entry.node else { continue }
            node.alpha = amount * entry.strength
            node.isHidden = amount <= 0.01
        }
    }

    /// `picture` lit from `way` (0 the right, counting round toward the top) in `color`: each pixel's
    /// colour times the light it catches, in three steps (none where it faces away).
    private func makeCopy(of picture: CGImage, way: Int, color: (r: Double, g: Double, b: Double)) -> SKTexture? {
        let width = picture.width, height = picture.height
        guard let pixels = PixelImage.pixels(of: picture, width: width, height: height) else { return nil }
        let normals = OutlineNormals.normals(pixels, width: width, height: height)
        let angle = Double(way) * .pi / 4
        // Image rows run down: the light's up is their minus.
        var lx = cos(angle), ly = -sin(angle), lz = 0.55
        let length = (lx * lx + ly * ly + lz * lz).squareRoot()
        lx /= length; ly /= length; lz /= length
        var out = [UInt8](repeating: 0, count: width * height * 4)
        var any = false
        for index in 0..<(width * height) {
            let alpha = Double(pixels[index * 4 + 3])
            guard alpha > 0 else { continue }
            let n = index * 3
            let facing = Double(normals[n]) * lx + Double(normals[n + 1]) * ly + Double(normals[n + 2]) * lz
            // A face toward the viewer catches a third; one turned to the lamp, all of it.
            let caught = min(1, max(0, (facing - 0.15) / 0.75))
            let step = (caught * 3).rounded(.down) / 3
            guard step > 0 else { continue }
            any = true
            // Premultiplied as they are: the colour under the light, times the light.
            out[index * 4] = UInt8(min(255, Double(pixels[index * 4]) * color.r * step * Self.boost))
            out[index * 4 + 1] = UInt8(min(255, Double(pixels[index * 4 + 1]) * color.g * step * Self.boost))
            out[index * 4 + 2] = UInt8(min(255, Double(pixels[index * 4 + 2]) * color.b * step * Self.boost))
            out[index * 4 + 3] = UInt8(alpha)
        }
        guard any, let image = PixelImage.make(out, width: width, height: height) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}

/// Which way each pixel of a sprite faces, from its outline alone: how far it lies in from the
/// nearest clear pixel is its height (a rounded bevel `bevel` pixels wide, flat beyond), with a
/// little of its brightness for the surface's detail; its slope, the way it faces (x right, y down,
/// z toward you). Nothing needs drawing: the outline says where the edges curve away.
nonisolated enum OutlineNormals {
    static let bevel = 5.0
    static let detail = 1.2

    /// x, y, z for each pixel of `pixels` (premultiplied RGBA, rows top down).
    static func normals(_ pixels: [UInt8], width: Int, height: Int) -> [Float] {
        let count = width * height
        // How far in from the edge (two passes, a step across counting 1 and aslant 1.414).
        var distance = [Double](repeating: 0, count: count)
        for index in 0..<count where pixels[index * 4 + 3] >= 128 { distance[index] = .greatestFiniteMagnitude }
        func at(_ x: Int, _ y: Int) -> Double {
            // Past the edge of the picture is clear.
            x < 0 || y < 0 || x >= width || y >= height ? 0 : distance[y * width + x]
        }
        for y in 0..<height {
            for x in 0..<width where distance[y * width + x] > 0 {
                distance[y * width + x] = min(distance[y * width + x], at(x - 1, y) + 1, at(x, y - 1) + 1,
                                              at(x - 1, y - 1) + 1.414, at(x + 1, y - 1) + 1.414)
            }
        }
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) where distance[y * width + x] > 0 {
                distance[y * width + x] = min(distance[y * width + x], at(x + 1, y) + 1, at(x, y + 1) + 1,
                                              at(x + 1, y + 1) + 1.414, at(x - 1, y + 1) + 1.414)
            }
        }
        var heights = [Double](repeating: 0, count: count)
        for index in 0..<count where distance[index] > 0 {
            let t = min(distance[index], bevel) / bevel
            let dome = bevel * (1 - (1 - t) * (1 - t)).squareRoot()
            let alpha = Double(pixels[index * 4 + 3])
            let luma = alpha > 0 ? (0.299 * Double(pixels[index * 4]) + 0.587 * Double(pixels[index * 4 + 1])
                                    + 0.114 * Double(pixels[index * 4 + 2])) / alpha : 0
            heights[index] = dome + detail * luma
        }
        func lift(_ x: Int, _ y: Int) -> Double {
            x < 0 || y < 0 || x >= width || y >= height ? 0 : heights[y * width + x]
        }
        var out = [Float](repeating: 0, count: count * 3)
        for y in 0..<height {
            for x in 0..<width {
                // Sobel: the slope across and down.
                let gx = (lift(x + 1, y - 1) + 2 * lift(x + 1, y) + lift(x + 1, y + 1))
                    - (lift(x - 1, y - 1) + 2 * lift(x - 1, y) + lift(x - 1, y + 1))
                let gy = (lift(x - 1, y + 1) + 2 * lift(x, y + 1) + lift(x + 1, y + 1))
                    - (lift(x - 1, y - 1) + 2 * lift(x, y - 1) + lift(x + 1, y - 1))
                var nx = -gx / 8, ny = -gy / 8, nz = 1.0
                let length = (nx * nx + ny * ny + nz * nz).squareRoot()
                nx /= length; ny /= length; nz /= length
                let i = (y * width + x) * 3
                out[i] = Float(nx); out[i + 1] = Float(ny); out[i + 2] = Float(nz)
            }
        }
        return out
    }
}
