import SpriteKit

/// A town's fence as one continuous picket fence round its square: the picket art is slanted onto
/// each edge's diagonal so neighbouring pieces join up and turn at the corners, and a stone gate
/// arch stands over every road that runs through it. A city's is a wall of stone instead, round
/// towers at its corners, either side of each gate and along it between (`stone`).
enum TownFence {
    /// Pickets are drawn one picture per cell, this tall (points).
    private static let height: CGFloat = 21
    private static let gateHeight: CGFloat = 51
    /// A city wall's towers stand at most this many cells apart along a straight stretch.
    private static let towerEvery = 8

    /// What it set down that casts shade (`LandStage.placeFence`): a city's towers and every gate.
    struct Placed {
        var towers: [SKSpriteNode] = []
        var gates: [SKSpriteNode] = []
    }

    /// `stone`: a city's wall (art/sprites/city_wall.png and city_tower.png, `tools/city_wall_art.py`)
    /// rather than a village's pickets.
    @discardableResult
    static func place(cells: [GridPoint], map: WorldMap, world: SKNode, art: ArtLibrary, stone: Bool = false) -> Placed {
        var placed = Placed()
        let fence = Set(cells)
        let palette = map.def.theme.palette
        let source = stone ? art.gradedTile("city_wall", palette: palette) : art.sprite("fence").texture.cgImage()
        let height = stone ? BorderArt.wallHeight : Self.height
        guard !fence.isEmpty, let source else { return placed }
        func has(_ dc: Int, _ dr: Int, _ cell: GridPoint) -> Bool { fence.contains(GridPoint(col: cell.col + dc, row: cell.row + dr)) }
        // A wall's stretches along the grid's x axis show their south face, turned from the light (from
        // the upper left, as everything is): a step darker, as a terrace's south wall is.
        let top = stone ? art.gradedTile("city_wall_top", palette: palette) : nil
        for piece in pieces(cells: cells, picture: source, height: height, shaded: stone ? 0.8 : 1, top: top) {
            let node = SKSpriteNode(texture: piece.texture, size: piece.size)
            node.anchorPoint = piece.anchor
            node.position = map.center(of: piece.cell)
            node.zPosition = -node.position.y
            world.addChild(node)
        }

        // A city wall's towers: at its corners and either side of each gate, and along each straight
        // stretch between, no two closer than half the stretch they're spread along.
        if stone, let tower = art.gradedTile("city_tower", palette: palette) {
            let texture = SKTexture(cgImage: tower)
            texture.filteringMode = .nearest
            var spots: [GridPoint] = []
            for cell in cells.sorted(by: WorldMap.inOrder) {
                let east = has(1, 0, cell) || has(-1, 0, cell), north = has(0, 1, cell) || has(0, -1, cell)
                let ends = [(1, 0), (0, 1), (-1, 0), (0, -1)].filter { has($0.0, $0.1, cell) }.count < 2
                let along = east && !north ? cell.col : !east && north ? cell.row : 0
                guard (east && north) || ends || along % towerEvery == 0 else { continue }
                guard spots.allSatisfy({ max(abs($0.col - cell.col), abs($0.row - cell.row)) > 3 }) || east && north || ends else { continue }
                spots.append(cell)
            }
            for cell in spots {
                let node = SKSpriteNode(texture: texture, size: BorderArt.towerSize)
                node.anchorPoint = CGPoint(x: 0.5, y: 0.06)
                node.position = map.center(of: cell)
                node.zPosition = -node.position.y + 0.01
                world.addChild(node)
                placed.towers.append(node)
            }
        }

        // Gates: the two ends of each gap where a road runs through, joined by its arch (the town's own).
        guard let arch = cropped(art.sprite(map.def.town?.gate ?? "town_gate").texture.cgImage()) else { return placed }
        var done: Set<GridPoint> = []
        for cell in cells where !done.contains(cell) {
            let links = [(1, 0), (0, 1), (-1, 0), (0, -1)].filter { has($0.0, $0.1, cell) }
            guard links.count == 1 else { continue }
            // Look the other way along the fence for the end across the road.
            let step = (-links[0].0, -links[0].1)
            var other: GridPoint?
            for distance in 2...6 {
                let candidate = GridPoint(col: cell.col + step.0 * distance, row: cell.row + step.1 * distance)
                if fence.contains(candidate) { other = candidate; break }
            }
            guard let other else { continue }
            done.insert(cell)
            done.insert(other)
            // Draw from the west/north end to the east/south end.
            let (from, to) = step.0 + step.1 * -1 > 0 ? (cell, other) : (other, cell)
            let node = gate(arch, from: map.center(of: from), to: map.center(of: to))
            world.addChild(node)
            placed.gates.append(node)
        }
        return placed
    }

    /// How tall the pickets of a fence along a road stand (points): a little lower than a town's.
    private static let roadsideHeight: CGFloat = 18

    /// The picket fences and low walls along stretches of a land's roads
    /// (`LandPlanner.planRoadsides`; its rows of props are drawn as its other props are), joined from
    /// cell to cell as a town's fence is, each piece on its cell's middle, up on the ground there.
    /// `put` sets each down (in the piece of the land it stands in).
    static func placeRoadsides(_ lines: [RoadsideLine], map: WorldMap, art: ArtLibrary, put: (SKSpriteNode) -> Void) {
        guard lines.contains(where: { $0.kind != .row }) else { return }
        let pickets = art.picture(of: art.sprite("fence").texture)
        let stones = BorderArt.lowWallPicture(palette: map.def.theme.palette)
        for line in lines where line.kind != .row {
            let wall = line.kind == .wall
            guard let picture = wall ? stones : pickets else { continue }
            for piece in pieces(cells: line.cells, picture: picture, height: wall ? BorderArt.lowWallHeight : roadsideHeight) {
                let node = SKSpriteNode(texture: piece.texture, size: piece.size)
                node.anchorPoint = piece.anchor
                let foot = map.center(of: piece.cell)
                node.position = CGPoint(x: foot.x, y: foot.y + map.height(at: foot))
                node.zPosition = -foot.y
                put(node)
            }
        }
    }

    /// A fence's pieces, one a cell (`cells`), each `picture` (pickets, or a wall's stones) slanted
    /// from the cell's middle to each side it joins the next cell of the fence at, so the pieces
    /// join up and turn at the corners: what each cell shows, and the anchor to stand it on the
    /// cell's middle with. `height`: how tall the picture stands, in points.
    /// `top`: a city wall's walk (`BorderArt.wallTop`), drawn over each stretch at `wallTopLevel`,
    /// going back into the screen (north from a stretch along x, east from one along y).
    static func pieces(cells: [GridPoint], picture source: CGImage, height: CGFloat,
                       shaded: CGFloat = 1, top: CGImage? = nil) -> [(cell: GridPoint, texture: SKTexture, size: CGSize, anchor: CGPoint)] {
        let fence = Set(cells)
        guard !fence.isEmpty, let pickets = cropped(source) else { return [] }
        // `shaded`: how much darker the stretches along x are drawn (their south face, from the light).
        let southern = shaded < 1 ? dimmed(pickets, by: shaded) : pickets
        let southernTop = top.map { shaded < 1 ? dimmed($0, by: shaded) : $0 }
        let tile = WorldMap.tileSize
        let c = CGFloat(0.5).squareRoot()
        // Half a cell along the grid's x axis on screen; along y it's (-dx, dy).
        let east = CGVector(dx: c * tile / 2, dy: c * tile / 4)
        let north = CGVector(dx: -east.dx, dy: east.dy)
        let deep = top == nil ? 0 : BorderArt.wallThickness
        let lift = CGVector(dx: 0, dy: BorderArt.wallTopLevel)
        // A wall's parapet along the walk's outer edge too, merlons standing up from it (the user,
        // 2026-11-18: "The walls miss the ridge on the outer edge"): the face's own top, what of it
        // stands over the walk, from the top down to the walk's level.
        let crestHeight = top == nil ? 0 : max(0, height - BorderArt.wallTopLevel)
        let crestRows = Int((crestHeight / height * CGFloat(pickets.height)).rounded())
        let crest = crestRows > 0 ? pickets.cropping(to: CGRect(x: 0, y: 0, width: pickets.width, height: crestRows)) : nil
        let southernCrest = crest.map { shaded < 1 ? dimmed($0, by: shaded) : $0 }
        let pad: CGFloat = 2 + (east.dx * deep).rounded(.up)
        let size = CGSize(width: east.dx * 2 + pad * 2, height: east.dy * 2 + height + pad * 2 + (east.dy * deep).rounded(.up))
        let middle = CGPoint(x: size.width / 2, y: east.dy + pad)
        let anchor = CGPoint(x: 0.5, y: middle.y / size.height)

        func has(_ dc: Int, _ dr: Int, _ cell: GridPoint) -> Bool { fence.contains(GridPoint(col: cell.col + dc, row: cell.row + dr)) }
        var textures: [Int: SKTexture] = [:]
        var found: [(cell: GridPoint, texture: SKTexture, size: CGSize, anchor: CGPoint)] = []
        for cell in cells {
            var mask = 0
            if has(1, 0, cell) { mask |= 1 }
            if has(0, 1, cell) { mask |= 2 }
            if has(-1, 0, cell) { mask |= 4 }
            if has(0, -1, cell) { mask |= 8 }
            if mask == 0 { mask = 5 }
            if textures[mask] == nil {
                textures[mask] = render(size: size) { context in
                    // Along x the picture runs from the west end to the east end; along y from the
                    // north end to the south end, so it reads left to right on screen. Each half of
                    // the cell shows its half of the picture, so straight runs repeat seamlessly.
                    // The far halves (north, east) first.
                    // A wall's walk first, back from its top, and the parapet along its far edge
                    // standing on it; then its face over them.
                    func walk(_ image: CGImage?, from origin: CGPoint, along: CGVector, back: CGVector, part: Int) {
                        guard let image else { return }
                        drawTop(image, in: context, from: origin + lift, along: along, back: back, part: part)
                        let rim = image === top ? crest : southernCrest
                        if let rim { draw(rim, in: context, from: origin + lift + back, along: along, part: part, height: crestHeight) }
                    }
                    if mask & 2 != 0 {
                        walk(top, from: middle + north, along: north * -2, back: east * deep, part: 0)
                        draw(pickets, in: context, from: middle + north, along: north * -2, part: 0, height: height)
                    }
                    if mask & 1 != 0 {
                        walk(southernTop, from: middle + east * -1, along: east * 2, back: north * deep, part: 1)
                        draw(southern, in: context, from: middle + east * -1, along: east * 2, part: 1, height: height)
                    }
                    if mask & 4 != 0 {
                        walk(southernTop, from: middle + east * -1, along: east * 2, back: north * deep, part: 0)
                        draw(southern, in: context, from: middle + east * -1, along: east * 2, part: 0, height: height)
                    }
                    if mask & 8 != 0 {
                        walk(top, from: middle + north, along: north * -2, back: east * deep, part: 1)
                        draw(pickets, in: context, from: middle + north, along: north * -2, part: 1, height: height)
                    }
                }
            }
            guard let texture = textures[mask] else { continue }
            found.append((cell: cell, texture: texture, size: size, anchor: anchor))
        }
        return found
    }

    /// The stone arch over a road through a fence, from `a` to `b` on screen (the west or north
    /// end first), standing on the line between them. `picture`: the arch, cropped (`cropped`).
    static func gate(_ picture: CGImage, from a: CGPoint, to b: CGPoint) -> SKSpriteNode {
        let pad: CGFloat = 2
        let span = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let gateSize = CGSize(width: abs(span.dx) + pad * 2, height: abs(span.dy) + gateHeight + pad * 2)
        let start = CGPoint(x: span.dx >= 0 ? pad : gateSize.width - pad, y: span.dy >= 0 ? pad : gateSize.height - gateHeight - pad)
        // As wide as the gap, its pillars and banner as they are (`widened`).
        let arch = widened(picture, to: Int((abs(span.dx) / gateHeight * CGFloat(picture.height)).rounded()))
        let texture = render(size: gateSize) { context in
            draw(arch, in: context, from: start, along: span, part: nil, height: gateHeight)
        }
        let node = SKSpriteNode(texture: texture, size: gateSize)
        node.anchorPoint = CGPoint(x: start.x / gateSize.width, y: start.y / gateSize.height)
        node.position = a
        node.zPosition = -(a.y + b.y) / 2
        return node
    }

    /// The town gate's arch (`cropped`) widened to `width` pixels without stretching it: its pillars
    /// at either end and its banner in the middle as they are, a beam of the pillars' stones laid
    /// across their tops between them. Stretched across a wide road (a quest's gate across a border
    /// spans six cells) its pillars came out smeared sideways (playtesting 2026-10-16). Narrower
    /// than the picture, it's the picture. Its parts, as shares of the picture's size: each pillar
    /// `pillar` of its width (the banner between them, `hangs` of its height down from the top), and
    /// the beam the stones `stones` across the left pillar's top, `beam` down from the top.
    static func widened(_ picture: CGImage, to width: Int) -> CGImage {
        let w = picture.width, h = picture.height
        guard width > w else { return picture }
        let side = Int((Double(w) * pillar).rounded())
        let top = Int((Double(h) * beam.lowerBound).rounded()), bottom = Int((Double(h) * beam.upperBound).rounded())
        let from = Int((Double(w) * stones.lowerBound).rounded()), to = Int((Double(w) * stones.upperBound).rounded())
        guard side > 0, side * 2 < w, bottom > top, to > from,
              let left = picture.cropping(to: CGRect(x: 0, y: 0, width: side, height: h)),
              let right = picture.cropping(to: CGRect(x: w - side, y: 0, width: side, height: h)),
              let banner = picture.cropping(to: CGRect(x: side, y: 0, width: w - 2 * side, height: Int((Double(h) * hangs).rounded()))),
              let block = picture.cropping(to: CGRect(x: from, y: top, width: to - from, height: bottom - top)),
              let context = CGContext(data: nil, width: width, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return picture }
        context.interpolationQuality = .none
        // Rows run up from the bottom here: a part `y` rows down from the picture's top lies at
        // `h - y - its height`. The beam first, from just inside one pillar to just inside the other.
        context.saveGState()
        context.clip(to: CGRect(x: side - 2, y: 0, width: width - 2 * side + 4, height: h))
        var x = side - 2
        while x < width - side + 2 {
            context.draw(block, in: CGRect(x: x, y: h - bottom, width: block.width, height: block.height))
            x += block.width
        }
        context.restoreGState()
        context.draw(left, in: CGRect(x: 0, y: 0, width: side, height: h))
        context.draw(right, in: CGRect(x: width - side, y: 0, width: side, height: h))
        context.draw(banner, in: CGRect(x: (width - banner.width) / 2, y: h - banner.height, width: banner.width, height: banner.height))
        return context.makeImage() ?? picture
    }

    /// The town gate's parts (`widened`), as shares of its cropped picture (70 × 51 pixels).
    private static let pillar = 27.0 / 70
    private static let hangs = 32.0 / 51
    private static let beam = (2.0 / 51)...(12.0 / 51)
    private static let stones = (14.0 / 70)...(26.0 / 70)

    /// One cell's stretch of a railing picture that has a post at each end (`posts`: how far across
    /// the cropped picture their centres sit, 0...1), slanted along the edge it stands on: west to
    /// east (`alongColumns`) or north to south, left to right on screen either way. Its posts land
    /// on the cell's edges, where the next cell's posts land too, so a run reads as one railing.
    /// The anchor is the middle of its foot, to go on the cell's centre.
    static func railing(_ image: CGImage, posts: (CGFloat, CGFloat), height: CGFloat,
                        alongColumns: Bool) -> (texture: SKTexture, size: CGSize, anchor: CGPoint)? {
        guard let picture = cropped(image), posts.1 > posts.0 else { return nil }
        let c = CGFloat(0.5).squareRoot(), tile = WorldMap.tileSize
        // One cell along the edge: east climbs to the right, south drops to the right.
        let cell = CGVector(dx: c * tile, dy: alongColumns ? c * tile / 2 : -c * tile / 2)
        let full = cell * (1 / (posts.1 - posts.0))
        let pad: CGFloat = 2
        let size = CGSize(width: full.dx + pad * 2, height: abs(full.dy) + height + pad * 2)
        let origin = CGPoint(x: pad, y: pad + max(0, -full.dy))
        let texture = render(size: size) { context in
            draw(picture, in: context, from: origin, along: full, part: nil, height: height)
        }
        let middle = origin + full * ((posts.0 + posts.1) / 2)
        return (texture, size, CGPoint(x: middle.x / size.width, y: middle.y / size.height))
    }

    /// `image` slanted along `along` from `origin` (its bottom edge follows the line, its sides
    /// stay upright). `part` 0 or 1 draws only the first or second half of it.
    nonisolated private static func draw(_ image: CGImage, in context: CGContext, from origin: CGPoint, along: CGVector, part: Int?, height: CGFloat) {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        context.saveGState()
        context.concatenate(CGAffineTransform(a: along.dx / w, b: along.dy / w, c: 0, d: height / h, tx: origin.x, ty: origin.y))
        if let part { context.clip(to: CGRect(x: CGFloat(part) * w / 2, y: 0, width: w / 2, height: h)) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        context.restoreGState()
    }

    /// `image` laid flat from `origin`: its width along `along`, its height back along `back` (its top
    /// row the far edge), clipped to its half `part`, as `draw` does a face.
    nonisolated private static func drawTop(_ image: CGImage, in context: CGContext, from origin: CGPoint, along: CGVector, back: CGVector, part: Int?) {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        context.saveGState()
        context.concatenate(CGAffineTransform(a: along.dx / w, b: along.dy / w, c: back.dx / h, d: back.dy / h, tx: origin.x, ty: origin.y))
        if let part { context.clip(to: CGRect(x: CGFloat(part) * w / 2, y: 0, width: w / 2, height: h)) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        context.restoreGState()
    }

    /// A texture `size` points big, drawn at two pixels per point.
    private static func render(size: CGSize, _ body: (CGContext) -> Void) -> SKTexture {
        let scale: CGFloat = 2
        guard let context = CGContext(data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return SKTexture() }
        context.interpolationQuality = .none
        // Hard edges: smoothed, each piece's ends came out half clear and a seam a pixel wide showed
        // between every two (the user, 2026-11-18).
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        context.scaleBy(x: scale, y: scale)
        body(context)
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// The image with its colour multiplied by `factor` (its alpha as it is).
    static func dimmed(_ image: CGImage, by factor: CGFloat) -> CGImage {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for index in 0..<(width * height) {
            for channel in 0..<3 {
                let at = index * 4 + channel
                pixels[at] = UInt8((CGFloat(pixels[at]) * factor).rounded())
            }
        }
        return context.makeImage() ?? image
    }

    /// The image without its transparent margins.
    static func cropped(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        // The bitmap's rows run top to bottom, like the image's.
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }
}
