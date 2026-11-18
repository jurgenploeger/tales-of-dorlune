import SpriteKit
import UIKit

/// The water moving on a land's own lakes and rivers (after SpriteCook's "Pixel art pond water: reflections
/// and ripples", its moving layers; the user, 2026-11-17: "Start on the moving water parts"): light dashes
/// lapping in and out along the near and side shores, the far shore's waterline creeping, glints flickering
/// on the open water and drops rippling out from where they fall. Each a little picture in whole pixels the
/// size of the water's own (`pixel`), in the pond's light and dark tones, shown in steps, never faded
/// (`LandStage.placePondMotion` sets them down). Mirrored in `tools/pond_preview.py` (`layers`, 4 to 6).
enum PondMotion {
    /// One of the water's pixels on screen, in points: its tile's 32 a cell, turned and squashed as the
    /// ground is (about half again a walker's).
    static let pixel: CGFloat = 1.4

    static let light = UIColor(red: 0.86, green: 0.97, blue: 0.95, alpha: 1)
    static let mid = UIColor(red: 0.6, green: 0.86, blue: 0.88, alpha: 1)
    static let dark = UIColor(red: 0.1, green: 0.24, blue: 0.28, alpha: 1)

    /// A glint's five shapes as it lives (a 0.6-second life): a pixel, three, five, four with a gap in the
    /// middle, then two at the ends; light in the middle, the paler mid tone at the ends.
    static let glint: [(texture: SKTexture, time: TimeInterval)] = [
        (picture(5, 1, [(2, 0, light)]), 0.09),
        (picture(5, 1, [(1, 0, mid), (2, 0, light), (3, 0, mid)]), 0.09),
        (picture(5, 1, [(0, 0, mid), (1, 0, light), (2, 0, light), (3, 0, light), (4, 0, mid)]), 0.21),
        (picture(5, 1, [(0, 0, mid), (1, 0, light), (3, 0, light), (4, 0, mid)]), 0.12),
        (picture(5, 1, [(0, 0, mid), (4, 0, mid)]), 0.09),
    ]

    /// A drop's rings, spreading in five steps of 0.2 seconds: ellipses (1, 0) to (8, 4) pixels, only
    /// their edge; the last two broken, only their tops and bottoms, as they fade.
    static let ripple: [SKTexture] = [(1, 0), (2, 1), (4, 2), (6, 3), (8, 4)].enumerated().map { step, radius in
        var cells: [(Int, Int, UIColor)] = []
        let (rx, ry) = (radius.0, radius.1)
        for y in -4...4 {
            for x in -8...8 where ring(x, y, rx, ry) {
                if step >= 3, abs(Double(y)) < Double(ry) / 2 { continue }
                cells.append((x + 8, y + 4, step < 3 ? light : mid))
            }
        }
        return picture(17, 9, cells)
    }

    /// Whether it's raining where you are (`ContinentScene.updateAir`): drops ring the open water many
    /// times a second (`LandStage.placePondMotion`; the user, 2026-11-18: "Add the rain rings").
    static var raining = false

    /// A raindrop's rings: the drop's first four, quicker (`LandStage.placePondMotion`).
    static var rainRipple: [SKTexture] { Array(ripple.prefix(4)) }

    /// The bright rim along a near shore, one cell's edge of it (the user, 2026-11-18: "the bright shore
    /// rim"): a line of light pixels stepping two across and one up, as the edge runs on screen,
    /// broken here and there, a paler pixel at each end. `rising`: up to the right (an edge along the
    /// grid's x, the water's south shore), else up to the left (its west shore). A few of each,
    /// picked by where the edge lies, so a long shore doesn't repeat.
    static let rims: [Bool: [SKTexture]] = [true: (0..<4).map { rim(rising: true, variant: $0) },
                                            false: (0..<4).map { rim(rising: false, variant: $0) }]

    private static func rim(rising: Bool, variant: Int) -> SKTexture {
        let width = 22, height = 11
        var random = SeededRandom(text: "pond rim \(rising) \(variant)")
        var cells: [(Int, Int, UIColor)] = []
        var gap = 0
        for step in 0..<width {
            // A short gap now and then (a pixel or two), never at the ends, so the cells' rims join.
            if gap > 0 { gap -= 1; continue }
            if step > 2, step < width - 3, Double.random(in: 0..<1, using: &random) < 0.08 {
                gap = Int.random(in: 0...1, using: &random)
                continue
            }
            let x = rising ? step : width - 1 - step
            let y = height - 1 - step / 2
            cells.append((x, y, step == 0 || step == width - 1 ? mid : light))
        }
        return picture(width, height, cells)
    }

    /// A dash lapping at the shore: three pixels, light in the middle.
    static let lap = picture(3, 1, [(0, 0, mid), (1, 0, light), (2, 0, mid)])
    /// The far shore's waterline creeping up a pixel: two of its dark pixels.
    static let creep = picture(2, 1, [(0, 0, dark), (1, 0, dark)])

    /// Whether pixel (x, y) from an ellipse's middle lies on its edge.
    private static func ring(_ x: Int, _ y: Int, _ rx: Int, _ ry: Int) -> Bool {
        func inside(_ a: Int, _ b: Int) -> Bool {
            guard a > 0 else { return x == 0 && y == 0 }
            let fx = Double(x) / Double(a), fy = Double(y) / max(0.5, Double(b))
            return fx * fx + fy * fy <= 1
        }
        return inside(rx, ry) && !inside(rx - 1, ry - 1)
    }

    /// A picture `width` × `height` pixels with `cells` filled (x, y from the top left, a colour each),
    /// shown with its pixels hard.
    static func picture(_ width: Int, _ height: Int, _ cells: [(Int, Int, UIColor)]) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            for (x, y, colour) in cells {
                colour.setFill()
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// A node showing `texture` at the water's pixel size.
    static func sprite(_ texture: SKTexture) -> SKSpriteNode {
        let size = texture.size()
        return SKSpriteNode(texture: texture, size: CGSize(width: size.width * pixel, height: size.height * pixel))
    }
}
