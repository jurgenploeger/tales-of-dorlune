import SpriteKit

/// Footprints in the snow and the sand (the user's picks from `tools/snow_trail_preview.py`,
/// 2026-11-24: look C, and in the sand the same, its lip warm; after SpriteCook's trail render texture
/// article): where anyone with a walk sheet puts a foot down on a snow or sand land's own plain ground
/// (`Walker.footfall`), a print is pressed in, a dent lit from the top left in three depths: tinted
/// toward the land's palette shadow (in the sand mostly toward a warm brown: a beach's blue shadow on
/// its own turned them grey-green), its top edge darker (the wall facing away from the light), its
/// left edge a little darker, a bright lip along its bottom (the snow's white, the sand's highlight).
/// As it ages the ground fills it back in, the print shrinking, gone in about six seconds.
///
/// The article keeps one map of bytes round the walker, stamps a soft dot into it per footfall, keeps
/// the brighter of the two, and fades it all a whole level a frame. Every pixel of that map is the
/// brightest stamp over it less the fade since that stamp went down, so each print here is its own
/// sprite showing its stamp less its own age's fade (`frames`): the same picture wherever prints don't
/// overlap (they fall a stride apart), and nothing is worked out per pixel each frame.
final class Footprints {
    /// What takes prints, by a land's theme `ground`.
    enum Material {
        case snow, sand
    }
    static let grounds: [String: Material] = ["tile_snow": .snow, "tile_sand": .sand, "tile_desert": .sand]
    /// The stamp where a foot comes down: `min(1, peak * exp(-(dx/sx)² - (dy/sy)²))`, in points (a
    /// walker's art pixel is a point), flat white in its middle.
    static let peak = 1.3, spread = (x: 3.0, y: 1.8)
    /// The depths: a pixel is a level deeper over each cutoff (half a level off what a byte holds,
    /// as the article says, so no pixel flips back and forth).
    static let cutoffs = [70, 140, 210]
    /// How strongly each depth leans toward the shade colour, and the wall's and the left edge's
    /// darkening. As the preview has them.
    static let tints: [CGFloat] = [0.18, 0.32, 0.46]
    static let wall: CGFloat = 0.82, side: CGFloat = 0.92
    /// The snow's lip; the sand's is its palette's highlight half mixed with white (`sandLip`).
    static let snowLip = (r: CGFloat(0.97), g: CGFloat(0.98), b: CGFloat(1.0))
    static let sandLip: CGFloat = 0.55, lipAlpha: CGFloat = 0.65
    /// The warm brown the sand's dents lean toward, and how much of it beside the palette's shadow.
    static let sandShade = "#5A3018", sandShadeShare: CGFloat = 0.6
    /// The ground's own brightness the tint is laid at, so the dent reads as shade, not paint.
    static let light: [Material: CGFloat] = [.snow: 0.9, .sand: 0.7]
    /// Whole levels it fades a second (the preview's one a frame at 30 frames a second).
    static let fade = 30.0
    /// How far either side of the way you walk the feet fall, in points: across, and up or down
    /// when walking left or right (the ground is a squashed diamond).
    static let apart = (across: CGFloat(4), along: CGFloat(1.5))
    /// Under the ground's shade (`CanopyShade`, -99 300) and the walkers' shadows, over the ground's
    /// colour patches (`Lighting`, -99 400).
    static let depth: CGFloat = -99_350

    /// One land's prints: a picture for each whole level of fade, the same picture shared while no
    /// pixel crosses a cutoff.
    struct Look {
        let frames: [SKTexture]
    }

    private struct Print {
        let node: SKSpriteNode
        let look: Look
        var age: TimeInterval = 0
        var shown = 0
    }

    let node = SKNode()
    private var prints: [Print] = []
    /// Its looks, by what takes them and the palette colours they're drawn in.
    private static var looks: [String: Look] = [:]

    init() {
        node.zPosition = Self.depth
    }

    /// The look of a land's prints, made the first time it's wanted; nil if its ground takes none.
    static func look(for def: MapDef) -> Look? {
        guard let material = grounds[def.theme.ground] else { return nil }
        let shadowHex = def.theme.palette?.shadow ?? "#3050E0", highlightHex = def.theme.palette?.highlight ?? "#FFFFFF"
        let key = "\(material)|\(shadowHex)|\(highlightHex)"
        if let known = looks[key] { return known }
        func rgb(_ hex: String, _ fallback: (CGFloat, CGFloat, CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard let color = UIColor(hex: hex), color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return (fallback.0, fallback.1, fallback.2) }
            return (r, g, b)
        }
        let shadow = rgb(shadowHex, (0.19, 0.31, 0.88))
        var shade = shadow, lip = snowLip
        if material == .sand {
            let brown = rgb(sandShade, (0.35, 0.19, 0.09)), k = sandShadeShare
            shade = (shadow.r * (1 - k) + brown.r * k, shadow.g * (1 - k) + brown.g * k, shadow.b * (1 - k) + brown.b * k)
            let high = rgb(highlightHex, (1, 1, 1))
            lip = (sandLip + (1 - sandLip) * high.r, sandLip + (1 - sandLip) * high.g, sandLip + (1 - sandLip) * high.b)
        }
        let bright = light[material] ?? 0.9
        let look = Look(frames: frames(shade: (shade.r * bright, shade.g * bright, shade.b * bright), lip: lip))
        looks[key] = look
        return look
    }

    /// Presses a print in at each of `footfalls` (in its node's parent's points) where `ground` says
    /// the snow there takes one, ages the rest by `dt` and lets go of those filled back in.
    /// `ground` is asked at points on the ground's plane (the print's spot less the lift it's raised by)
    /// with the lift, and says no where the ground there isn't that high (a slope, a face, a stair). On a
    /// raised level (a terrace, a mountain's), the print is sorted at its own spot's depth, over the
    /// level's picture and under whoever stands in front (the user, 2026-11-25: "It should show the
    /// footsteps on elevated levels as well"); on the flat it's in the prints' own layer under it all.
    func update(dt: TimeInterval, footfalls: [(point: CGPoint, lift: CGFloat)], ground: (CGPoint, CGFloat) -> Look?) {
        for fall in footfalls {
            let point = fall.point, lift = fall.lift
            let spot = CGPoint(x: point.x.rounded(), y: point.y.rounded())
            let base = CGPoint(x: spot.x, y: spot.y - lift)
            // All it shows on the snow (a dent reaches 4 points across and 3 down from its middle,
            // its lip a row under that), so none lies over a path's edge.
            let rx: CGFloat = 4, ry: CGFloat = 4
            guard let found = ground(base, lift),
                  [CGPoint(x: -rx, y: -ry), CGPoint(x: rx, y: -ry), CGPoint(x: -rx, y: ry), CGPoint(x: rx, y: ry)]
                    .allSatisfy({ ground(CGPoint(x: base.x + $0.x, y: base.y + $0.y), lift) != nil }),
                  let first = found.frames.first else { continue }
            let sprite = SKSpriteNode(texture: first)
            sprite.size = first.size()
            sprite.position = spot
            if lift > 0.5 { sprite.zPosition = -base.y - 0.01 - Self.depth }
            node.addChild(sprite)
            prints.append(Print(node: sprite, look: found))
        }
        guard !prints.isEmpty else { return }
        for index in prints.indices.reversed() {
            prints[index].age += dt
            let level = Int(prints[index].age * Self.fade)
            let frames = prints[index].look.frames
            if level >= frames.count {
                prints[index].node.removeFromParent()
                prints.remove(at: index)
            } else if level != prints[index].shown {
                prints[index].shown = level
                if prints[index].node.texture !== frames[level] { prints[index].node.texture = frames[level] }
            }
        }
    }

    // MARK: The pictures

    /// How far the stamp reaches from its middle, in whole points.
    private static let reach = (x: Int((spread.x * 3).rounded(.up)), y: Int((spread.y * 3).rounded(.up)))

    /// The stamp's levels, 0 to 255, rows from the top; a row clear above and below for the lip.
    private static func stamp() -> (levels: [Int], width: Int, height: Int) {
        let width = reach.x * 2 + 1, height = reach.y * 2 + 3
        var levels = [Int](repeating: 0, count: width * height)
        for row in 1..<(height - 1) {
            for col in 0..<width {
                let dx = Double(col - reach.x) / spread.x, dy = Double(row - 1 - reach.y) / spread.y
                let value = min(1, peak * exp(-dx * dx - dy * dy))
                levels[row * width + col] = Int((value * 255).rounded())
            }
        }
        return (levels, width, height)
    }

    /// A picture for each whole level of fade till the stamp's middle is under the first cutoff,
    /// pictures that come out the same shared.
    private static func frames(shade: (r: CGFloat, g: CGFloat, b: CGFloat), lip: (r: CGFloat, g: CGFloat, b: CGFloat)) -> [SKTexture] {
        let (levels, width, height) = stamp()
        // A pixel's colour, premultiplied: tinted `tint` toward the shadow, then darkened by `dark`.
        func dent(_ tint: CGFloat, _ dark: CGFloat) -> [UInt8] {
            let alpha = 1 - (1 - tint) * dark
            return [shade.r * tint * dark, shade.g * tint * dark, shade.b * tint * dark, alpha].map { UInt8(min(255, max(0, ($0 * 255).rounded()))) }
        }
        let rim: [UInt8] = [lip.r * lipAlpha, lip.g * lipAlpha, lip.b * lipAlpha, lipAlpha].map { UInt8(($0 * 255).rounded()) }
        let most = levels.max() ?? 0
        var out: [SKTexture] = []
        var last: (bytes: [UInt8], texture: SKTexture)?
        for fade in 0...max(0, most - cutoffs[0]) {
            var depth = [Int](repeating: 0, count: levels.count)
            for i in levels.indices {
                let value = levels[i] - fade
                depth[i] = cutoffs.filter { value > $0 }.count
            }
            var bytes = [UInt8](repeating: 0, count: levels.count * 4)
            for row in 0..<height {
                for col in 0..<width {
                    let i = row * width + col, level = depth[i]
                    let above = row > 0 ? depth[i - width] : 0
                    let left = col > 0 ? depth[i - 1] : 0
                    var pixel: [UInt8]?
                    if level > 0 {
                        let tint = tints[min(level, tints.count) - 1]
                        pixel = dent(tint, above < level ? wall : left < level ? side : 1)
                    } else if above > 0 {
                        pixel = rim
                    }
                    if let pixel { for k in 0..<4 { bytes[i * 4 + k] = pixel[k] } }
                }
            }
            if let last, last.bytes == bytes {
                out.append(last.texture)
                continue
            }
            let texture = picture(bytes, width: width, height: height)
            last = (bytes, texture)
            out.append(texture)
        }
        return out
    }

    /// RGBA bytes, premultiplied, rows from the top, as a texture drawn pixel for pixel.
    private static func picture(_ bytes: [UInt8], width: Int, height: Int) -> SKTexture {
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return SKTexture()
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
