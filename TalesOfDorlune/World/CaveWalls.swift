import SpriteKit

/// A cave's rock (and the crags outside where a road leads into one, `WorldMap.Crag`), drawn as
/// raised walls you pass in front of and disappear behind. Each cell
/// near the floor gets a depth-sorted block: a shaded stone top and lit faces where the rock
/// drops to the floor. The outline runs through the middles of the cells (marching squares),
/// so corners are cut across instead of stepping in sharp right angles, each cut broken into a
/// few angled facets that differ from cell to cell, as rock splits: real caves aren't carved
/// round (playtesting 2026-11-02: "The caves now have a bit too much rounded walls, that's not
/// how real caves are carved"; every corner had been a quarter circle). Rock deeper in is one
/// flat raised layer underneath. Walls stay solid: whoever walks behind one is hidden, and their
/// name tag shows where they are.
final class CaveWalls {
    /// Every block of rock drawn and the cell it stands for, so the lantern can light the faces
    /// turned toward you (`LanternLight`).
    private(set) var blocks: [(node: SKSpriteNode, cell: GridPoint)] = []
    /// Faces, edges and soft shadows (in points) around each block's texture.
    private static let pad: CGFloat = 10
    /// The tops of the walls are in shadow, so they stand apart from the lit floor.
    private static let topShade: CGFloat = 0.45
    /// How many ways each corner can break (`facets`), picked by the cell, so neighbouring corners
    /// of the same shape don't repeat.
    private static let variants = 3

    /// A cave's walls: its rock, and beyond the map rock too but for the tunnels the roads leave by.
    convenience init(map: WorldMap, cave: MapDef.Cave, world: SKNode, art: ArtLibrary, margin: Int) {
        var mouths: Set<GridPoint> = []
        for exit in map.def.exits {
            for i in 0..<margin {
                switch exit.edge {
                case .north, .south:
                    let edgeRow = exit.edge == .north ? map.rows - 1 : 0
                    for col in 0..<map.columns where !map.rock.contains(GridPoint(col: col, row: edgeRow)) {
                        mouths.insert(GridPoint(col: col, row: exit.edge == .north ? map.rows + i : -1 - i))
                    }
                case .east, .west:
                    let edgeCol = exit.edge == .east ? map.columns - 1 : 0
                    for row in 0..<map.rows where !map.rock.contains(GridPoint(col: edgeCol, row: row)) {
                        mouths.insert(GridPoint(col: exit.edge == .east ? map.columns + i : -1 - i, row: row))
                    }
                }
            }
        }
        func isRock(_ cell: GridPoint) -> Bool {
            map.contains(cell) ? map.rock.contains(cell) : !mouths.contains(cell)
        }
        self.init(map: map, rock: cave.rock, height: CGFloat(cave.height ?? 40), topShade: CaveWalls.topShade,
                  world: world, art: art, margin: margin, isRock: isRock)
    }

    /// Walls of `rock` (a tile) `height` points tall wherever `isRock` says, in the map and out past
    /// its edge to `margin` cells, their tops `topShade` darker than the rock. `rows` and `columns`
    /// narrow where to look, if the rock is all in one part of that.
    init(map: WorldMap, rock: String, height: CGFloat, topShade: CGFloat, world: SKNode, art: ArtLibrary, margin: Int,
         rows: Range<Int>? = nil, columns: Range<Int>? = nil, isRock: (GridPoint) -> Bool) {
        let tile = WorldMap.tileSize
        // Every top uses the same tile, lined up with the flat layer, so they meet seamlessly.
        let top = art.picture(of: art.tileVariant(rock, 0))
        let side = art.picture(of: art.tileVariant(rock, 1))

        let topTexture = SKTexture(cgImage: top)
        topTexture.filteringMode = .nearest
        let group = SKTileGroup(tileDefinition: SKTileDefinition(texture: topTexture, size: CGSize(width: tile, height: tile)))
        let deep = SKTileMapNode(tileSet: SKTileSet(tileGroups: [group]), columns: map.columns + margin * 2, rows: map.rows + margin * 2,
                                 tileSize: CGSize(width: tile, height: tile))
        deep.anchorPoint = .zero
        deep.color = .black
        deep.colorBlendFactor = topShade
        deep.position = CGPoint(x: -CGFloat(margin) * tile, y: -CGFloat(margin) * tile)
        // Rock this far from the floor is hidden behind the blocks in front of it, so it can be the
        // flat layer: about as many cells as the walls are tall, up the screen.
        let depthStep = WorldMap.project(CGPoint(x: tile, y: 0)).y
        let near = max(2, Int((height / depthStep).rounded(.up)) - 1)

        // Which blocks go where. A rock cell's block shows all of its rock; a floor cell in a
        // corner between walls gets a sliver of rock in that corner, sorted by where it sits.
        var pending: [(cell: GridPoint, key: Int, z: CGFloat)] = []
        for row in rows ?? (-margin..<(map.rows + margin)) {
            for col in columns ?? (-margin..<(map.columns + margin)) {
                let cell = GridPoint(col: col, row: row)
                var mask = 0
                for dr in -1...1 {
                    for dc in -1...1 where isRock(GridPoint(col: col + dc, row: row + dr)) { mask |= 1 << ((dr + 1) * 3 + dc + 1) }
                }
                let center = WorldMap.project(CGPoint(x: (CGFloat(col) + 0.5) * tile, y: (CGFloat(row) + 0.5) * tile))
                // Which way its corners break (only blocks with a corner have more than one).
                let variant = (((col &* 73_856_093) ^ (row &* 19_349_663)) & 0x7fff_ffff) % Self.variants
                if isRock(cell) {
                    // Only rock near the floor needs its own block; the rest is the flat layer.
                    let nearFloor = (-near...near).contains { dr in (-near...near).contains { dc in !isRock(GridPoint(col: col + dc, row: row + dr)) } }
                    if nearFloor {
                        pending.append((cell, Self.hasCorner(mask) ? mask | variant << 12 : mask, -center.y))
                    } else {
                        deep.setTileGroup(group, forColumn: col + margin, row: row + margin)
                    }
                } else {
                    for corner in 0..<4 where Self.fills(mask: mask, corner: corner) {
                        let quarter = WorldMap.project(CGPoint(x: (CGFloat(col) + 0.25 + 0.5 * CGFloat(corner & 1)) * tile,
                                                               y: (CGFloat(row) + 0.25 + 0.5 * CGFloat(corner >> 1)) * tile))
                        pending.append((cell, mask | (corner + 1) << 9 | variant << 12, -quarter.y))
                    }
                }
            }
        }

        let keys = Array(Set(pending.map(\.key))).sorted()
        let (textures, blockSize) = Self.atlas(keys: keys, top: top, side: side, height: height, topShade: topShade)
        guard textures.count == keys.count else { return }
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let half = WorldMap.project(CGPoint(x: tile, y: tile)).y / 2
        for block in pending {
            guard let i = index[block.key] else { continue }
            let node = SKSpriteNode(texture: textures[i], size: blockSize)
            let center = WorldMap.project(CGPoint(x: (CGFloat(block.cell.col) + 0.5) * tile, y: (CGFloat(block.cell.row) + 0.5) * tile))
            node.anchorPoint = CGPoint(x: 0.5, y: Self.pad / blockSize.height)
            node.position = center + CGVector(dx: 0, dy: -half)
            node.zPosition = block.z
            world.addChild(node)
            blocks.append((node, block.cell))
        }

        let squash = SKNode()
        squash.yScale = 0.5
        let turn = SKNode()
        turn.zRotation = .pi / 4
        squash.addChild(turn)
        turn.addChild(deep)
        squash.position.y = height
        squash.zPosition = -99_000
        world.addChild(squash)
    }

    // MARK: Shapes

    /// The rock in one block, in the cell's own grid units (0...1, x east, y north): the tops,
    /// and the outline pieces with their normals pointing from the rock out to the floor.
    private struct Shape {
        var tops: [[CGPoint]] = []
        /// `along`: how far along the wall (grid units) the piece starts, so the face texture runs on.
        var edges: [(a: CGPoint, b: CGPoint, normal: CGVector, along: CGFloat)] = []
    }

    /// Whether `mask` (bit `(dy + 1) * 3 + dx + 1` set for each rock cell around this one) is
    /// rock at that offset.
    private static func rock(_ mask: Int, _ dx: Int, _ dy: Int) -> Bool {
        mask & (1 << ((dy + 1) * 3 + dx + 1)) != 0
    }

    /// The corner of a floor cell (bit 0: east, bit 1: north) between three rock cells.
    private static func fills(mask: Int, corner: Int) -> Bool {
        let x = corner & 1 == 1 ? 1 : -1, y = corner >> 1 == 1 ? 1 : -1
        return !rock(mask, 0, 0) && rock(mask, x, 0) && rock(mask, 0, y) && rock(mask, x, y)
    }

    /// Whether a rock cell's block has a corner sticking out (one its `facets` break).
    private static func hasCorner(_ mask: Int) -> Bool {
        rock(mask, 0, 0) && (0..<4).contains { corner in
            !rock(mask, corner & 1 == 1 ? 1 : -1, 0) && !rock(mask, 0, corner >> 1 == 1 ? 1 : -1)
        }
    }

    /// A number in 0..<1 from `seed` and `index`, the same every time (splitmix64).
    private static func noise(_ seed: Int, _ index: Int) -> CGFloat {
        var z = UInt64(bitPattern: Int64(seed &* 1_000_003 &+ index)) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return CGFloat(z % 10_000) / 10_000
    }

    /// A corner's cut across its quarter, from the middle of one side, (0.5, 0) in the quarter's
    /// (p, q), to the middle of the other, (0, 0.5): two or three straight facets. Each break lies
    /// a step further round from the cell's middle (so the facets never fold back over each other)
    /// and is pushed out toward the cell's corner or back toward its middle by a different amount
    /// from the straight cut, so some corners come out nearly square, some chipped deep, none round.
    private static func facets(_ seed: Int) -> [(p: CGFloat, q: CGFloat)] {
        let breaks = noise(seed, 0) < 0.45 ? 1 : 2
        var points: [(p: CGFloat, q: CGFloat)] = [(p: 0.5, q: 0)]
        for index in 1...breaks {
            // How far round, a little off even spacing.
            let even = CGFloat(index) / CGFloat(breaks + 1)
            let angle = (even + (noise(seed, index * 2) - 0.5) * 0.3) * .pi / 2
            // The straight cut's distance from the middle that way, pushed out (more rock) or in.
            let straight = 0.5 / (cos(angle) + sin(angle))
            let reach = straight * (0.72 + noise(seed, index * 2 + 1) * 0.6)
            // Inside the quarter, so the rock never pokes out past the cell's sides.
            points.append((p: min(0.47, reach * cos(angle)), q: min(0.47, reach * sin(angle))))
        }
        points.append((p: 0, q: 0.5))
        return points
    }

    /// Marching squares over the cell middles, one quarter of the cell at a time, every corner cut
    /// across in angled facets (`facets`) where the rock sticks out and where it goes in. They
    /// start and end at the middles of the cell's sides, so they meet the straight walls and the
    /// next cell's corners there. Key: the 3×3 rock mask, plus (for a floor cell's corner sliver)
    /// `(corner + 1) << 9`, plus which way its corners break, `variant << 12`.
    private static func shape(for key: Int) -> Shape {
        let mask = key & 511
        let only = ((key >> 9) & 7) - 1
        var result = Shape()
        for corner in 0..<4 where only < 0 || corner == only {
            let x = corner & 1 == 1 ? 1 : -1, y = corner >> 1 == 1 ? 1 : -1
            let sx = CGFloat(x), sy = CGFloat(y)
            // (p, q) runs from the cell's middle (0, 0) out to its corner (0.5, 0.5).
            func at(_ p: CGFloat, _ q: CGFloat) -> CGPoint { CGPoint(x: 0.5 + sx * p, y: 0.5 + sy * q) }
            let here = rock(mask, 0, 0), across = rock(mask, x, 0), above = rock(mask, 0, y), diagonal = rock(mask, x, y)
            let cut = facets(key &* 4 &+ corner).map { at($0.p, $0.q) }
            /// The cut's pieces, each with its normal from the rock out to the floor: toward the
            /// cell's corner where the rock sticks out (`outward`), toward its middle where it goes in.
            func pieces(outward: Bool) {
                var along: CGFloat = 0
                for (a, b) in zip(cut, cut.dropFirst()) {
                    var normal = CGVector(dx: b.y - a.y, dy: a.x - b.x)
                    if (normal.dx * sx + normal.dy * sy > 0) != outward { normal = CGVector(dx: -normal.dx, dy: -normal.dy) }
                    result.edges.append((a, b, normal, along))
                    along += a.distance(to: b)
                }
            }
            if here {
                if !across && !above {
                    // A corner sticking out: broken off in facets.
                    result.tops.append([at(0, 0)] + cut)
                    pieces(outward: true)
                } else {
                    result.tops.append([at(0, 0), at(0.5, 0), at(0.5, 0.5), at(0, 0.5)])
                    if !across && !diagonal { result.edges.append((at(0.5, 0), at(0.5, 0.5), CGVector(dx: sx, dy: 0), 0)) }
                    if !above && !diagonal { result.edges.append((at(0, 0.5), at(0.5, 0.5), CGVector(dx: 0, dy: sy), 0)) }
                }
            } else if across && above && diagonal {
                // A corner going in: a hollow chipped out in facets.
                result.tops.append(cut + [at(0.5, 0.5)])
                pieces(outward: false)
            }
        }
        return result
    }

    // MARK: Drawing

    /// Every block that's needed, in one texture so they draw together, in the order of `keys`.
    /// Also returns a block's size in points.
    private static func atlas(keys: [Int], top: CGImage, side: CGImage, height: CGFloat, topShade: CGFloat) -> ([SKTexture], CGSize) {
        let tile = WorldMap.tileSize
        let c = CGFloat(0.5).squareRoot()
        let width = 2 * tile * c
        let cell = CGSize(width: width + pad * 2, height: tile * c + height + pad * 2)
        let columns = 16
        let rows = max(1, (keys.count + columns - 1) / columns)
        // Two pixels per point, unless that would make the sheet too big.
        let scale: CGFloat = CGFloat(rows) * (cell.height * 2 + 2) > 8000 ? 1 : 2
        let cellPixels = (w: Int((cell.width * scale).rounded(.up)) + 2, h: Int((cell.height * scale).rounded(.up)) + 2)
        let size = (w: cellPixels.w * columns, h: cellPixels.h * rows)
        guard let context = CGContext(data: nil, width: size.w, height: size.h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return ([], cell) }
        context.interpolationQuality = .none
        let lift = CGVector(dx: 0, dy: height)
        let space = CGColorSpaceCreateDeviceRGB()
        func gradient(_ from: UIColor, _ to: UIColor) -> CGGradient {
            CGGradient(colorsSpace: space, colors: [from.cgColor, to.cgColor] as CFArray, locations: [0, 1])!
        }
        let darkToFloor = gradient(UIColor(white: 0, alpha: 0.45), UIColor(white: 0, alpha: 0))
        let lipShine = gradient(UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 0.22))
        let shadow = gradient(UIColor(white: 0, alpha: 0.4), UIColor(white: 0, alpha: 0))

        /// A point in the cell's grid units, on the floor, in block points.
        func floor(_ p: CGPoint) -> CGPoint {
            CGPoint(x: width / 2 + (p.x - p.y) * c * tile, y: (p.x + p.y) * c * tile / 2)
        }
        func line(_ a: CGPoint, _ b: CGPoint, _ color: UIColor, _ lineWidth: CGFloat) {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.move(to: a)
            context.addLine(to: b)
            context.strokePath()
        }
        /// A wall face from `a` to `b` along the floor (`length` in grid points), up to the top:
        /// the rock texture sheared onto it, shaded darker toward the floor, with light rounding
        /// over the lip.
        func face(_ a: CGPoint, _ b: CGPoint, length: CGFloat, start: CGFloat, shade: CGFloat) {
            guard length > 0 else { return }
            context.saveGState()
            context.concatenate(CGAffineTransform(a: (b.x - a.x) / length, b: (b.y - a.y) / length, c: 0, d: 1, tx: a.x, ty: a.y))
            let rect = CGRect(x: 0, y: 0, width: length, height: height)
            context.clip(to: rect)
            var y: CGFloat = 0
            while y < height {
                var x = -start.truncatingRemainder(dividingBy: tile)
                while x < length {
                    context.draw(side, in: CGRect(x: x, y: y, width: tile, height: tile))
                    x += tile
                }
                y += tile
            }
            context.setFillColor(UIColor(white: 0, alpha: shade).cgColor)
            context.fill(rect)
            context.drawLinearGradient(darkToFloor, start: .zero, end: CGPoint(x: 0, y: height * 0.7), options: [])
            context.drawLinearGradient(lipShine, start: CGPoint(x: 0, y: height - 7), end: CGPoint(x: 0, y: height), options: [])
            context.restoreGState()
        }
        /// A soft shadow on the floor in front of a face (`out` points away from the wall).
        func floorShadow(_ a: CGPoint, _ b: CGPoint, out: CGVector) {
            let path = CGMutablePath()
            path.addLines(between: [a, b, b + out, a + out])
            path.closeSubpath()
            context.saveGState()
            context.addPath(path)
            context.clip()
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            context.drawLinearGradient(shadow, start: mid, end: mid + out, options: [])
            context.restoreGState()
        }

        var textures: [SKTexture] = []
        for (index, key) in keys.enumerated() {
            let piece = Self.shape(for: key)
            let origin = CGPoint(x: CGFloat((index % columns) * cellPixels.w + 1), y: CGFloat((index / columns) * cellPixels.h + 1))
            context.saveGState()
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: pad, y: pad)

            // Faces you can see point toward the camera (down the screen); the far ones first.
            let front = piece.edges.filter { $0.normal.dx + $0.normal.dy < 0 }
                .sorted { $0.a.x + $0.a.y + $0.b.x + $0.b.y > $1.a.x + $1.a.y + $1.b.x + $1.b.y }
            for edge in front {
                let n = edge.normal, length = (n.dx * n.dx + n.dy * n.dy).squareRoot()
                let out = CGVector(dx: (n.dx - n.dy) * c / length * pad * 0.9, dy: (n.dx + n.dy) * c / 2 / length * pad * 0.9)
                floorShadow(floor(edge.a), floor(edge.b), out: out)
            }
            for edge in front {
                let n = edge.normal, length = (n.dx * n.dx + n.dy * n.dy).squareRoot()
                // Lit from the left: faces turned west are brightest, faces turned south darkest.
                let shade = 0.22 + 0.1 * (n.dx - n.dy) / length
                face(floor(edge.a), floor(edge.b), length: edge.a.distance(to: edge.b) * tile, start: edge.along * tile, shade: shade)
            }

            // The top: the rock tile laid over the lifted outline, a hair bigger than the cell so
            // neighbouring tops overlap instead of leaving seams.
            if !piece.tops.isEmpty {
                let outline = CGMutablePath()
                for polygon in piece.tops {
                    outline.addLines(between: polygon.map { p in
                        floor(CGPoint(x: 0.5 + (p.x - 0.5) * 1.03, y: 0.5 + (p.y - 0.5) * 1.03)) + lift
                    })
                    outline.closeSubpath()
                }
                context.saveGState()
                context.addPath(outline)
                context.clip()
                context.concatenate(CGAffineTransform(a: c, b: c / 2, c: -c, d: c / 2, tx: width / 2, ty: height))
                let cover = CGRect(x: -2, y: -2, width: tile + 4, height: tile + 4)
                context.draw(top, in: cover)
                context.setFillColor(UIColor(white: 0, alpha: topShade).cgColor)
                context.fill(cover)
                context.restoreGState()
            }

            // Light catches the lips above the faces; where the rock drops away out of sight
            // there's a dark rim.
            for edge in piece.edges {
                let facing = edge.normal.dx + edge.normal.dy
                let color = facing < 0 ? UIColor(white: 1, alpha: 0.4) : UIColor(white: 0, alpha: 0.5)
                line(floor(edge.a) + lift, floor(edge.b) + lift, color, 1.5)
            }
            context.restoreGState()
        }

        guard let image = context.makeImage() else { return ([], cell) }
        let sheet = SKTexture(cgImage: image)
        sheet.filteringMode = .nearest
        for index in keys.indices {
            let origin = CGPoint(x: CGFloat((index % columns) * cellPixels.w + 1), y: CGFloat((index / columns) * cellPixels.h + 1))
            let rect = CGRect(x: origin.x / CGFloat(size.w), y: origin.y / CGFloat(size.h),
                              width: cell.width * scale / CGFloat(size.w), height: cell.height * scale / CGFloat(size.h))
            let texture = SKTexture(rect: rect, in: sheet)
            texture.filteringMode = .nearest
            textures.append(texture)
        }
        return (textures, cell)
    }
}
