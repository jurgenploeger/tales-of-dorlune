import SpriteKit

/// Draws the bridges where roads cross a map's river, and the footbridges and jetties out into its
/// lakes (`WorldMap.Bridge`): a deck of planks lying on the water in the ground's own layer
/// (`deck`), and posts and rails standing along its sides (`rails`), the near side sorted in front
/// of whoever walks the deck and the far side behind, so you walk between them. Wood, drawn in
/// code a pixel at a time like the tiles, in the map's palette.
enum BridgeArt {
    /// How far a deck reaches on over the land at an end that meets it, in cells: well onto the bank
    /// (`WorldMap.bank`), its end posts standing on land. A third of a cell only touched the shore.
    static let overlap: CGFloat = 0.6

    private typealias Tone = (r: Double, g: Double, b: Double)

    /// What a bridge is built of, as 0...255 channels (`WorldMap.Bridge.Material`): its deck's
    /// boards (or slabs), the gaps between them, the beam along each side and its dark edge, the
    /// nails; its posts' caps and its rails, light over dark.
    private struct Look {
        let plank: Tone, gap: Tone, beam: Tone, edge: Tone, nail: Tone
        let cap: Tone, railLight: Tone, railDark: Tone
        /// Stone slabs, twice as deep as planks, their joints staggered, and no nails.
        var slabs = false
        /// A sill of rough stones on the bank past each end, and the deck whole to its end; without,
        /// the deck's last boards break off on the bank (`deckPicture`).
        var sill = false
    }

    private static func look(_ material: WorldMap.Bridge.Material) -> Look {
        switch material {
        case .wood:
            Look(plank: (164, 116, 70), gap: (78, 52, 34), beam: (112, 76, 46), edge: (84, 56, 34), nail: (60, 52, 48),
                 cap: (164, 116, 70), railLight: (164, 116, 70), railDark: (112, 76, 46))
        case .stone:
            Look(plank: (156, 152, 144), gap: (92, 90, 90), beam: (124, 120, 114), edge: (78, 76, 78), nail: (92, 90, 90),
                 cap: (184, 180, 170), railLight: (164, 160, 152), railDark: (108, 104, 102), slabs: true, sill: true)
        case .lacquer:
            Look(plank: (136, 92, 60), gap: (66, 42, 30), beam: (176, 50, 44), edge: (104, 28, 30), nail: (60, 44, 40),
                 cap: (238, 190, 80), railLight: (206, 66, 54), railDark: (136, 36, 36), sill: true)
        case .rope:
            Look(plank: (188, 150, 100), gap: (70, 52, 38), beam: (150, 118, 76), edge: (96, 72, 46), nail: (70, 52, 38),
                 cap: (188, 150, 100), railLight: (206, 184, 136), railDark: (150, 126, 86))
        }
    }

    /// A bridge's deck for the ground's own (unprojected) layer, where it lies over its cells
    /// (`deckPicture`). Nil if it can't be drawn.
    static func deck(for bridge: WorldMap.Bridge, pixels: Int, palette: MapPalette?) -> SKSpriteNode? {
        guard let picture = deckPicture(for: bridge, pixels: pixels, palette: palette) else { return nil }
        let texture = SKTexture(cgImage: picture.image)
        texture.filteringMode = .nearest
        let tile = WorldMap.tileSize
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: picture.frame.width * tile, height: picture.frame.height * tile))
        sprite.anchorPoint = .zero
        sprite.position = CGPoint(x: picture.frame.minX * tile, y: picture.frame.minY * tile)
        return sprite
    }

    /// A bridge's deck as a picture, north up, and where it lies, in cells: planks across it, a beam
    /// along each side and a strip of shadow on the water past them, `pixels` to a cell like the
    /// tiles. Nil if it can't be drawn.
    static func deckPicture(for bridge: WorldMap.Bridge, pixels: Int, palette: MapPalette?) -> (image: CGImage, frame: CGRect)? {
        guard pixels > 0 else { return nil }
        let before = bridge.landsAtStart ? overlap : 0, after = bridge.landsAtEnd ? overlap : 0
        let style = look(bridge.material)
        // How its ends meet the land (the user's picks from tools/bridge_preview.py --ends,
        // 2026-11-17: "the overlap with the land and bridge, it's a straight line now"). Wood and
        // rope: the deck's last boards break off raggedly on the bank, the road showing between
        // them. Stone and red lacquer, which are built, not worn: the deck whole, and past each
        // end a sill of rough stones on the bank, wider than the deck.
        // (The sill went the same day: in the game it read as flaps on a flat slab, and stone and
        // red lacquer became bow bridges, `bowSprite`. One of them out over a sunk lake keeps a
        // plain whole end.)
        let worn = !style.sill
        let sillDeep = 0
        let lead = bridge.landsAtStart ? sillDeep : 0, tail = bridge.landsAtEnd ? sillDeep : 0
        let shadow = max(2, pixels / 8), beamWidth = max(2, pixels / 10)
        // The picture's margin either side of the deck: its shadow's, or a sill's reach past it.
        let margin = shadow
        let deckWide = bridge.lanes * pixels
        let across = deckWide + 2 * margin
        let deckAlong = Int(((CGFloat(bridge.end - bridge.start + 1) + before + after) * CGFloat(pixels)).rounded())
        let along = deckAlong + lead + tail
        let plank = style.plank, gap = style.gap, beam = style.beam, edge = style.edge, nail = style.nail
        let plankDeep = style.slabs ? max(4, pixels / 2) : max(3, pixels / 4)
        // Grid-space orientation: x east, y north (image rows top down).
        let width = bridge.northward ? across : along, height = bridge.northward ? along : across
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        func put(_ x: Int, _ y: Int, _ color: (r: Double, g: Double, b: Double), alpha: Double = 1) {
            let index = ((height - 1 - y) * width + x) * 4
            bytes[index] = UInt8(min(255, max(0, color.r * alpha)))
            bytes[index + 1] = UInt8(min(255, max(0, color.g * alpha)))
            bytes[index + 2] = UInt8(min(255, max(0, color.b * alpha)))
            bytes[index + 3] = UInt8(alpha * 255)
        }
        let sillStone: Tone = (150, 146, 138), sillDark: Tone = (86, 84, 86)
        let stoneWide = max(5, pixels * 7 / 16)
        for row in 0..<along {
            // The row within the deck itself; outside it, a sill's rows.
            let v = row - lead
            if v < 0 || v >= deckAlong {
                // How far out from the deck's end this row is, and the sill across it: stones side
                // by side, each its own shade, dark joints between them and a dark rim round it.
                let out = v < 0 ? -v - 1 : v - deckAlong
                for u in 0..<across {
                    let x = bridge.northward ? u : row, y = bridge.northward ? row : u
                    let stone = (u + (v < 0 ? 0 : stoneWide / 2)) / stoneWide
                    let rim = out == 0 || out == sillDeep - 1 || u == 0 || u == across - 1
                    if rim || (u + (v < 0 ? 0 : stoneWide / 2)) % stoneWide == 0 {
                        put(x, y, sillDark)
                    } else {
                        var shade = 0.84 + 0.28 * noise(stone, bridge.lane &* 13 &+ (v < 0 ? 1 : 2))
                        if out == 1 { shade *= 1.1 }
                        if noise(u, out &* 5 &+ bridge.start) < 0.07 { shade *= 0.86 }
                        put(x, y, (sillStone.r * shade, sillStone.g * shade, sillStone.b * shade))
                    }
                }
                continue
            }
            let board = v / plankDeep, inBoard = v % plankDeep
            // Each plank a little lighter or darker than the next.
            let tone = 0.92 + 0.16 * noise(board, bridge.lane &* 31 &+ bridge.start)
            // How far onto a bank this row lies, in cells (0 over the water): there a worn deck's
            // boards break off, more of them gone the further on.
            let onto = max(before > 0 ? before - CGFloat(v) / CGFloat(pixels) : 0,
                           after > 0 ? after - CGFloat(deckAlong - 1 - v) / CGFloat(pixels) : 0)
            let gone = worn ? Double(max(0, (onto - 0.2) / 0.4)) : 0
            for u in 0..<across {
                let x = bridge.northward ? u : row, y = bridge.northward ? row : u
                let inside = u - margin
                guard inside >= -shadow, inside < deckWide + shadow else { continue }
                if gone > 0, noise(u / 2 &+ 3, v / 2 &+ 91 &+ bridge.lane) < gone * 1.15 { continue }
                if inside < 0 || inside >= deckWide {
                    put(x, y, (0, 0, 0), alpha: 0.28)
                    continue
                }
                if inside == 0 || inside == deckWide - 1 {
                    put(x, y, edge)
                } else if inside < beamWidth || inside >= deckWide - beamWidth {
                    put(x, y, beam)
                } else if inBoard == plankDeep - 1 {
                    put(x, y, gap)
                } else if style.slabs, (inside + (board % 2) * plankDeep / 2) % plankDeep == 0 {
                    // A slab's joint with the one beside it, staggered from course to course.
                    put(x, y, gap)
                } else if !style.slabs, inBoard == plankDeep / 2, inside == beamWidth + 1 || inside == deckWide - beamWidth - 2 {
                    put(x, y, nail)
                } else {
                    var shade = tone * (inBoard == 0 ? 1.12 : 1)
                    // A darker fleck of grain here and there.
                    if noise(inside, v &* 7 &+ bridge.lane) < 0.06 { shade *= 0.85 }
                    put(x, y, (plank.r * shade, plank.g * shade, plank.b * shade))
                }
            }
        }
        guard var image = Self.image(bytes, width: width, height: height) else { return nil }
        if let palette, let graded = Recolor.grade(palette, image: image) { image = graded }
        let low = CGFloat(bridge.start) - before - CGFloat(lead) / CGFloat(pixels)
        let side = CGFloat(bridge.lane) - CGFloat(margin) / CGFloat(pixels)
        let size = CGSize(width: CGFloat(width) / CGFloat(pixels), height: CGFloat(height) / CGFloat(pixels))
        return (image, CGRect(origin: bridge.northward ? CGPoint(x: side, y: low) : CGPoint(x: low, y: side), size: size))
    }

    /// A bridge's posts and rails, standing in `world`: a post at each corner and about every cell
    /// and a quarter along both sides, two rails between each pair, and across a jetty's far end.
    /// `pixels`: the tiles' pixels to a cell, so the wood's pixels are the same size as theirs.
    /// `ground`: how high the deck lies under a spot on screen (sunk with a lake, `WorldMap.shore`).
    /// `railed`: false for posts alone, as along a harbor's pier, where you step off it aboard.
    static func rails(for bridge: WorldMap.Bridge, pixels: Int, palette: MapPalette?, in world: SKNode,
                      railed: Bool = true, ground: (CGPoint) -> CGFloat = { _ in 0 }) {
        let tile = WorldMap.tileSize
        let scale = tile / CGFloat(max(1, pixels))
        let style = look(bridge.material)
        guard let post = texture(post: true, style, palette: palette), let rail = texture(post: false, style, palette: palette) else { return }
        let before = bridge.landsAtStart ? overlap : 0, after = bridge.landsAtEnd ? overlap : 0
        let first = CGFloat(bridge.start) - before + 0.1, last = CGFloat(bridge.end + 1) + after - 0.1
        let count = max(2, Int(((last - first) / 1.25).rounded()) + 1)
        /// Where a spot on the deck (lanes across, cells along) stands on screen.
        func spot(_ across: CGFloat, _ along: CGFloat) -> CGPoint {
            WorldMap.project(bridge.northward ? CGPoint(x: across * tile, y: along * tile) : CGPoint(x: along * tile, y: across * tile))
        }
        let near = CGFloat(bridge.lane) + 0.12, far = CGFloat(bridge.lane + bridge.lanes) - 0.12
        let middle = spot((near + far) / 2, (first + last) / 2)
        /// A post at each spot, and two rails from each to the next, sorted in front of the deck
        /// if the line runs along its near side, behind if along its far side.
        func line(_ spots: [CGPoint], inFront: Bool) {
            // Sorted by where they stand on the ground, drawn as high as it lies there.
            let raised = spots.map { CGPoint(x: $0.x, y: $0.y + ground($0)) }
            for (base, top) in zip(spots, raised) {
                let node = SKSpriteNode(texture: post, size: CGSize(width: 3 * scale, height: 10 * scale))
                node.anchorPoint = CGPoint(x: 0.5, y: 0.05)
                node.position = top
                node.zPosition = -base.y
                world.addChild(node)
            }
            for ((a, b), (from, to)) in zip(zip(spots, spots.dropFirst()), zip(raised, raised.dropFirst())) where railed {
                let z = inFront ? -min(a.y, b.y) + 0.01 : -max(a.y, b.y) - 0.01
                // Ropes hang between their posts, in four short stretches; rails run straight.
                let parts = bridge.material == .rope ? 4 : 1
                let sag = bridge.material == .rope ? 2.5 * scale : 0
                for (lift, thick) in [(8.5 * scale, 2 * scale), (4.5 * scale, scale)] {
                    for part in 0..<parts {
                        let t0 = CGFloat(part) / CGFloat(parts), t1 = CGFloat(part + 1) / CGFloat(parts)
                        let p0 = CGPoint(x: from.x + (to.x - from.x) * t0, y: from.y + (to.y - from.y) * t0 + lift - sag * sin(.pi * t0))
                        let p1 = CGPoint(x: from.x + (to.x - from.x) * t1, y: from.y + (to.y - from.y) * t1 + lift - sag * sin(.pi * t1))
                        let node = SKSpriteNode(texture: rail, size: CGSize(width: p0.distance(to: p1) + scale, height: thick))
                        node.anchorPoint = CGPoint(x: 0, y: 0.5)
                        node.position = p0
                        node.zRotation = atan2(p1.y - p0.y, p1.x - p0.x)
                        node.zPosition = z
                        world.addChild(node)
                    }
                }
            }
        }
        let steps = (0..<count).map { first + (last - first) * CGFloat($0) / CGFloat(count - 1) }
        // Standing over the water, not lying on it (the user, 2026-11-17: "They look a bit too flat,
        // and shouldn't there be a shadow underneath as well and a reflection in the water?"; their
        // pick from tools/bridge_preview.py): along the side nearer you, the deck's thickness, piles
        // under it into the water, its shadow on the water, and its side, posts and rails mirrored
        // in the water, darker than it, swaying a point like ripples. A road's bridge and a
        // footbridge, not a jetty or a pier (those stand on posts of their own).
        // A bow bridge: its deck, the wall under it and its reflection, one picture (`bowSprite`).
        if bridge.bowed, let bow = bowSprite(for: bridge, pixels: pixels, palette: palette) { world.addChild(bow) }
        if bridge.kind != .jetty, !bridge.bowed, let side = fill(style.beam, shade: 0.5, palette: palette),
           let pile = fill(style.beam, shade: 0.4, palette: palette) {
            let thick = 5 * scale
            let edge = CGFloat(bridge.lane)
            // Only over the water (its cells from `start` to `end`), a little in from each bank:
            // run the deck's whole length, its shadow and reflection lay across the banks too (the
            // user, 2026-11-17: "the shadow over the water and land is a bit strange").
            let wetFrom = CGFloat(bridge.start) + 0.2, wetTo = CGFloat(bridge.end + 1) - 0.2
            let over = [wetFrom] + steps.filter { $0 > wetFrom + 0.3 && $0 < wetTo - 0.3 } + [wetTo]
            let rim = over.map { spot(edge, $0) }
            let lifted = rim.map { CGPoint(x: $0.x, y: $0.y + ground($0)) }
            let mirror = SKNode()
            mirror.zPosition = -(rim.map(\.y).min() ?? 0) + 0.002
            let dark = UIColor(red: 0.04, green: 0.16, blue: 0.28, alpha: 1)
            for ((a, b), (from, to)) in zip(zip(rim, rim.dropFirst()), zip(lifted, lifted.dropFirst())) {
                let z = -min(a.y, b.y)
                let turn = atan2(to.y - from.y, to.x - from.x), length = from.distance(to: to) + scale
                // Its shadow on the water, away from the sun: down the screen and a little right.
                let shade = SKSpriteNode(color: .black, size: CGSize(width: length, height: 1.6 * thick))
                shade.alpha = 0.2
                shade.anchorPoint = CGPoint(x: 0, y: 1)
                shade.position = CGPoint(x: from.x, y: from.y - thick * 0.8)
                shade.zRotation = turn
                shade.zPosition = z + 0.001
                world.addChild(shade)
                // Its thickness.
                let face = SKSpriteNode(texture: side, size: CGSize(width: length, height: thick))
                face.anchorPoint = CGPoint(x: 0, y: 1)
                face.position = from
                face.zRotation = turn
                face.zPosition = z + 0.005
                world.addChild(face)
                // Its side and rails in the water, as far under the water's level as they stand over it.
                for (drop, tall) in [(thick + 1.5 * scale, 3 * scale), (thick + 5.5 * scale, scale), (thick + 9.5 * scale, 2 * scale)] where railed {
                    let streak = SKSpriteNode(color: dark, size: CGSize(width: length, height: tall))
                    streak.alpha = 0.5
                    streak.anchorPoint = CGPoint(x: 0, y: 1)
                    streak.position = CGPoint(x: from.x, y: from.y - drop)
                    streak.zRotation = turn
                    mirror.addChild(streak)
                }
            }
            for (index, top) in lifted.enumerated() {
                // A post's reflection under each post.
                let post = SKSpriteNode(color: dark, size: CGSize(width: 3 * scale, height: 9 * scale))
                post.alpha = 0.5
                post.anchorPoint = CGPoint(x: 0.5, y: 1)
                post.position = CGPoint(x: top.x, y: top.y - thick - 1.5 * scale)
                mirror.addChild(post)
                // Piles under it, not at the water's edge by the banks, each with a pale line where
                // it stands in the water.
                guard index > 0, index < lifted.count - 1 else { continue }
                let leg = SKSpriteNode(texture: pile, size: CGSize(width: 3 * scale, height: thick + 3 * scale))
                leg.anchorPoint = CGPoint(x: 0.5, y: 1)
                leg.position = top
                leg.zPosition = -rim[index].y + 0.004
                world.addChild(leg)
                let foam = SKSpriteNode(color: UIColor(red: 0.82, green: 0.92, blue: 0.96, alpha: 1), size: CGSize(width: 5 * scale, height: scale))
                foam.alpha = 0.8
                foam.anchorPoint = CGPoint(x: 0.5, y: 1)
                foam.position = CGPoint(x: top.x, y: top.y - thick - 3 * scale)
                foam.zPosition = -rim[index].y + 0.0045
                world.addChild(foam)
            }
            let sway = SKAction.sequence([.moveBy(x: scale, y: 0, duration: 0), .wait(forDuration: 0.7),
                                          .moveBy(x: -scale, y: 0, duration: 0), .wait(forDuration: 0.7)])
            mirror.run(.repeatForever(sway))
            world.addChild(mirror)
        }
        // The lane nearer you is the one lower on the screen, across (west or south) of the deck.
        line(steps.map { spot(near, $0) }, inFront: true)
        line(steps.map { spot(far, $0) }, inFront: false)
        // A jetty's far end, out in the water.
        if !bridge.landsAtStart || !bridge.landsAtEnd {
            let end = bridge.landsAtStart ? last : first
            let across = [spot(near, end), spot(far, end)]
            line(across, inFront: (across[0].y + across[1].y) / 2 < middle.y)
        }
    }

    /// A post (a few pixels wide, lit down one side, a lighter cap) or a rail's colour (light over
    /// dark, stretched), as a texture in the map's palette.
    private static func texture(post: Bool, _ style: Look, palette: MapPalette?) -> SKTexture? {
        let width = post ? 3 : 1, height = post ? 10 : 2
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                // Lit from the upper left, as the art is: the cap and left side light, the right dark.
                var color: Tone = style.railDark
                if post, y == 0 {
                    color = style.cap
                } else if y == 0 || (post && x == 0) {
                    color = style.railLight
                } else if post, x == width - 1 {
                    color = style.edge
                } else if post {
                    color = (r: style.railLight.r * 0.9, g: style.railLight.g * 0.9, b: style.railLight.b * 0.9)
                }
                let index = (y * width + x) * 4
                bytes[index] = UInt8(color.r)
                bytes[index + 1] = UInt8(color.g)
                bytes[index + 2] = UInt8(color.b)
                bytes[index + 3] = 255
            }
        }
        guard var image = Self.image(bytes, width: width, height: height) else { return nil }
        if let palette, let graded = Recolor.grade(palette, image: image) { image = graded }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// A bow bridge (`WorldMap.Bridge.bowed`) as one picture, as it stands on the screen (mirrored in
    /// tools/bridge_preview.py `bow`): its deck's boards or slabs laid up the curve, each pixel
    /// where the view puts it and as high as the deck stands there (`Bridge.bow`), a little lighter
    /// where it climbs toward the sun and darker where it falls away; down its near side a wall
    /// with an arch through it over the water, in courses of stone (or the lacquer's dark red), a
    /// pale coping along its top; and the wall mirrored in the water under it. Sorted just behind
    /// its far corner, under everyone who walks it, as a harbor's pier is.
    static func bowSprite(for bridge: WorldMap.Bridge, pixels: Int, palette: MapPalette?) -> SKSpriteNode? {
        guard bridge.bowed, pixels > 0, let deck = deckPicture(for: bridge, pixels: pixels, palette: nil),
              let source = PixelImage.pixels(of: deck.image, width: deck.image.width, height: deck.image.height) else { return nil }
        let style = look(bridge.material)
        let unit = WorldMap.tileSize / CGFloat(pixels)                 // points to one of the art's pixels
        let per = Double(pixels)
        let rise = Double(WorldMap.Bridge.rise / unit)
        let reach = Double(WorldMap.Bridge.reach)
        let low = Double(bridge.start) - reach, high = Double(bridge.end + 1) + reach
        let lane = Double(bridge.lane)
        let wet = (from: Double(bridge.start), to: Double(bridge.end + 1))
        func lift(_ along: Double) -> Double { rise * sin(Double.pi * min(1, max(0, (along - low) / (high - low)))) }
        /// Where a spot on it (lanes across, cells along, `z` pixels up) shows, in the art's pixels.
        func spot(_ across: Double, _ along: Double, _ z: Double) -> (x: Double, y: Double) {
            let gx = (bridge.northward ? across : along) * per, gy = (bridge.northward ? along : across) * per
            return ((gx - gy) * 0.70710678, (gx + gy) * 0.35355339 + z)
        }
        let corners = [spot(lane, low, 0), spot(lane + Double(bridge.lanes), low, 0), spot(lane, high, 0), spot(lane + Double(bridge.lanes), high, 0)]
        let xs = corners.map { $0.x }, ys = corners.map { $0.y }
        let minX = (xs.min() ?? 0).rounded(.down) - 2, maxX = (xs.max() ?? 0).rounded(.up) + 2
        let minY = (ys.min() ?? 0).rounded(.down) - rise - 6, maxY = (ys.max() ?? 0).rounded(.up) + rise + 3
        let width = Int(maxX - minX), height = Int(maxY - minY)
        guard width > 0, height > 0, width < 2048, height < 2048 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        func plot(_ at: (x: Double, y: Double), _ color: Tone, alpha: Double = 1) {
            let x = Int((at.x - minX).rounded(.down)), y = Int((at.y - minY).rounded(.down))
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = ((height - 1 - y) * width + x) * 4
            bytes[index] = UInt8(min(255, max(0, color.r * alpha)))
            bytes[index + 1] = UInt8(min(255, max(0, color.g * alpha)))
            bytes[index + 2] = UInt8(min(255, max(0, color.b * alpha)))
            bytes[index + 3] = UInt8(alpha * 255)
        }
        /// How high the arch through its wall stands over the water at a spot along it: none over
        /// the banks, a ring of the wall left under the deck at its crown.
        func arch(_ along: Double) -> Double {
            let t = (along - wet.from) / max(1, wet.to - wet.from)
            guard t > 0, t < 1 else { return 0 }
            let across = (t - 0.5) / 0.42
            return max(0, rise - 5) * max(0, 1 - across * across).squareRoot()
        }
        let step = 1 / (per * 1.5)
        // The wall mirrored in the water, as far under the water's level as it stands over it.
        let dark: Tone = (30, 92, 128)
        for along in stride(from: wet.from, to: wet.to, by: step) {
            let top = Int(lift(along).rounded()), open = Int(arch(along))
            guard top >= open else { continue }
            for z in open...top { plot(spot(lane, along, -Double(z) - 1), dark, alpha: 0.45) }
        }
        // The deck, up the curve.
        let imageWide = deck.image.width, imageHigh = deck.image.height
        let margin = max(2, pixels / 8)
        let deckWide = bridge.lanes * pixels
        let deckAlong = (bridge.northward ? imageHigh : imageWide)
        for v in 0..<deckAlong {
            let along = low + (Double(v) + 0.5) / per
            let z = lift(along)
            let slope = cos(Double.pi * min(1, max(0, (along - low) / (high - low))))
            let lit = 1 + 0.1 * slope
            for u in 0..<deckWide {
                let x = bridge.northward ? margin + u : v, y = bridge.northward ? v : margin + u
                guard x < imageWide, y < imageHigh else { continue }
                let index = ((imageHigh - 1 - y) * imageWide + x) * 4
                guard source[index + 3] == 255 else { continue }
                plot(spot(lane + (Double(u) + 0.5) / per, along, z),
                     (Double(source[index]) * lit, Double(source[index + 1]) * lit, Double(source[index + 2]) * lit))
            }
        }
        // The wall down its near side, the arch through it.
        var stone: Tone = (128, 126, 120), coping: Tone = (170, 167, 160)
        if !style.slabs {
            stone = (style.edge.r * 1.15, style.edge.g * 1.15, style.edge.b * 1.15)
            coping = style.beam
        }
        for along in stride(from: low, to: high, by: step) {
            let top = Int(lift(along).rounded()), open = Int(arch(along))
            guard top >= open else { continue }
            for z in open...top {
                var tone = stone
                var shade = 1.0
                if z >= top - 1 {
                    tone = coping
                } else if open > 0, z < open + 3 {
                    shade = 0.8                                   // the ring of the arch
                } else if style.slabs {
                    // Courses four pixels deep, their joints staggered.
                    let course = z / 4
                    let block = Int((along * 9 + Double(course % 2) * 0.5).rounded(.down))
                    let before = Int((along * 9 + Double(course % 2) * 0.5 - 0.12).rounded(.down))
                    shade = z % 4 == 0 || block != before ? 0.72 : 0.9 + 0.2 * noise(block, course)
                }
                plot(spot(lane, along, Double(z)), (tone.r * shade, tone.g * shade, tone.b * shade))
            }
        }
        guard var image = Self.image(bytes, width: width, height: height) else { return nil }
        if let palette, let graded = Recolor.grade(palette, image: image) { image = graded }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: CGFloat(width) * unit, height: CGFloat(height) * unit))
        sprite.anchorPoint = .zero
        sprite.position = CGPoint(x: CGFloat(minX) * unit, y: CGFloat(minY) * unit)
        sprite.zPosition = -CGFloat(ys.max() ?? 0) * unit - 1
        return sprite
    }

    /// One colour as a texture, in the map's palette: a tone at `shade` of itself (the deck's side,
    /// its piles).
    private static func fill(_ tone: Tone, shade: Double, palette: MapPalette?) -> SKTexture? {
        let bytes = [UInt8(tone.r * shade), UInt8(tone.g * shade), UInt8(tone.b * shade), 255]
        guard var image = Self.image(bytes, width: 1, height: 1) else { return nil }
        if let palette, let graded = Recolor.grade(palette, image: image) { image = graded }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// A steady scatter from 0 to 1 for a pair of numbers.
    private static func noise(_ a: Int, _ b: Int) -> Double {
        var value = UInt32(truncatingIfNeeded: (a &* 73_856_093) ^ (b &* 19_349_663))
        value = (value ^ (value >> 13)) &* 0x5bd1_e995
        value ^= value >> 15
        return Double(value & 0xffff) / 65535
    }

    /// Premultiplied RGBA bytes, top row first, as an image.
    private static func image(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
