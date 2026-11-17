import SpriteKit

/// Which tile each of a land's cells shows (`WorldScene.makeGround`, and the continent's chunks):
/// its ground, with soft roads, accent patches, ponds and shorelines drawn over it from the cells
/// round it (`ArtLibrary.organicTile`), and across the band where it gives way to the land next
/// door (`Seam`), that land's ground in patches. Each cell's pick depends only on the cells within
/// two of it, so any piece of the land can be tiled on its own; and across the band, only on what
/// they show, whichever land holds them (`Blend`), so a tile meets the one past the border as it
/// would one of its own.
final class GroundTiles {
    private let map: WorldMap
    private let art: ArtLibrary
    private let theme: MapDef.Theme
    private let tileSize = CGSize(width: WorldMap.tileSize, height: WorldMap.tileSize)
    private let waterID: String
    /// The water's tile (animated, for placeholder water).
    let water: SKTileGroup
    /// Every tile picked so far, by what's drawn on it.
    private var groups: [String: SKTileGroup]
    /// Each tile's picture, for drawing hills (`HillArt`).
    private(set) var pictures: [ObjectIdentifier: SKTexture]
    /// Accent patches (flower meadows, moss) blend in as soft blobs. Not in towns, where the accent
    /// is terrace paving and stays square.
    private let patchAccent: Bool
    /// Plain tiles come in four versions that fit together in any order, so big areas don't repeat.
    /// Animated placeholder water keeps its single animated tile.
    private let waterVaries: Bool
    /// The sea (on the continent), round the land and in over its box past its coast (`Region`).
    /// It lies lower than the land (`WorldMap.seaDrop`; `WorldScene.placeSea` draws it), so its cells
    /// have no ground, and the land's edge along it is cut clear, curving as a lake's shore does.
    private var sea: Set<GridPoint> = []
    /// The lands next door whose ground comes over the line in patches, by id, graded as it is there.
    private var others: [String: (land: MapDef, from: ArtLibrary.Foreign)?] = [:]
    private var lookPast: [GridPoint: String?] = [:]
    private static let full = 0b111_111_111, sides = 0b010_101_010
    /// Every cell of `poolMask`'s 5×5.
    private static let wholePool = (1 << 25) - 1

    /// The tiles picked so far, for a tile set.
    var allGroups: [SKTileGroup] { Array(groups.values) }

    init(map: WorldMap, art: ArtLibrary) {
        self.map = map
        self.art = art
        theme = map.def.theme
        waterID = theme.water ?? "tile_water"
        let frames = art.waterFrames(waterID)
        water = SKTileGroup(tileDefinition: SKTileDefinition(textures: frames, size: CGSize(width: WorldMap.tileSize, height: WorldMap.tileSize),
                                                             timePerFrame: 0.9))
        groups = ["water": water]
        pictures = [ObjectIdentifier(water): frames.first ?? SKTexture()]
        patchAccent = (theme.accentPatches ?? 0) > 0 && theme.accent != nil && theme.accent != theme.ground
        waterVaries = frames.count == 1
        if map.region != nil {
            for row in -2..<(map.rows + 2) {
                for col in -2..<(map.columns + 2) {
                    let cell = GridPoint(col: col, row: row)
                    let open = map.contains(cell) ? map.ground[row][col] == .sea : map.isOpenSea(cell)
                    if open { sea.insert(cell) }
                }
            }
        }
    }

    private func group(_ key: String, _ texture: () -> SKTexture) -> SKTileGroup {
        if let known = groups[key] { return known }
        // Graded with this land's palette, whatever land the library was grading for when asked.
        let picture = art.grading(palette: theme.palette, for: map.def.id, texture)
        let made = SKTileGroup(tileDefinition: SKTileDefinition(texture: picture, size: tileSize))
        groups[key] = made
        pictures[ObjectIdentifier(made)] = picture
        return made
    }

    private func plain(_ id: String, _ variant: Int) -> SKTileGroup {
        group("\(id)#\(variant)") { art.tileVariant(id, variant) }
    }

    /// Whether the ground past the land's edge at `cell` is water: where a river runs on into the
    /// land next door (`Region`).
    private func waterBeyond(_ cell: GridPoint) -> Bool {
        map.region?.isRiver(cell) ?? false
    }

    /// Which cells of the 3×3 around `cell` are `kind` (bit row * 3 + col, row 0 north).
    private func mask(_ cell: GridPoint, _ kind: Ground) -> Int {
        let own = map.ground[cell.row][cell.col] == kind
        var bits = 0
        for dy in -1...1 {
            for dx in -1...1 {
                let next = GridPoint(col: cell.col + dx, row: cell.row + dy)
                // Off the land (past its box, or a land next door's) a patch carries on; water only
                // where a river runs off it; a road on a land next door only where its own runs on
                // from this one's (`WorldMap.roadsPast`), as that land lays it out, so the two meet.
                let hit: Bool
                if map.contains(next), map.ground[next.row][next.col] != .away {
                    hit = map.ground[next.row][next.col] == kind
                } else if kind == .water {
                    hit = waterBeyond(next)
                } else if kind == .path, map.region != nil, !map.isOpenSea(next) {
                    hit = map.roadsPast.contains(next)
                } else {
                    hit = own
                }
                if hit { bits |= 1 << ((1 - dy) * 3 + dx + 1) }
            }
        }
        return bits
    }

    /// The water cells of the 5×5 around `cell` (bit row * 5 + col, row 0 north), for shorelines.
    private func poolMask(_ cell: GridPoint) -> Int {
        var bits = 0
        for dy in -2...2 {
            for dx in -2...2 {
                let next = GridPoint(col: cell.col + dx, row: cell.row + dy)
                let water = map.contains(next) && map.ground[next.row][next.col] != .away ? map.ground[next.row][next.col] == .water : waterBeyond(next)
                if water { bits |= 1 << ((2 - dy) * 5 + dx + 2) }
            }
        }
        return bits
    }

    /// The sea's cells of the 3×3 around `cell` (as `mask`), and of the 5×5 (as `poolMask`).
    private func shore(_ cell: GridPoint) -> Int {
        var bits = 0
        for dy in -1...1 {
            for dx in -1...1 where sea.contains(GridPoint(col: cell.col + dx, row: cell.row + dy)) { bits |= 1 << ((1 - dy) * 3 + dx + 1) }
        }
        return bits
    }

    private func seaPool(_ cell: GridPoint) -> Int {
        var bits = 0
        for dy in -2...2 {
            for dx in -2...2 where sea.contains(GridPoint(col: cell.col + dx, row: cell.row + dy)) { bits |= 1 << ((2 - dy) * 5 + dx + 2) }
        }
        return bits
    }

    /// A land next door, for its ground graded as it is there.
    private func foreignLand(_ id: String) -> (land: MapDef, from: ArtLibrary.Foreign)? {
        if let known = others[id] { return known }
        let found = Content.shared.map(id).map { (land: $0, from: ArtLibrary.Foreign(land: $0.id, palette: $0.theme.palette)) }
        others[id] = found
        return found
    }

    /// Which land's ground shows at a cell, by id: on this land as laid out (`WorldMap.foreign`),
    /// past its border as the land there lays it out (`Blend.shows`), a land next door's own or a
    /// third land's come over onto it. Nil on the sea, or past where the band could reach.
    private func look(_ cell: GridPoint) -> String? {
        if map.owns(cell) { return map.foreign[cell].map { map.seams[$0].neighbour } ?? map.def.id }
        if let known = lookPast[cell] { return known }
        let found = map.blend.flatMap { blend in blend.shows(cell).map { blend.around.lands[$0] } }
        lookPast[cell] = found
        return found
    }

    /// How a road cell takes on the road of the land next door across the band between them: its
    /// road tile, graded as it is there, mixed in by that land's share of the ground at the cell
    /// (`Seam.share`, half on the border), in eighths. The ground there comes in patches; a road
    /// changing in patches looked torn, and changing at the border it was cut straight across
    /// (playtesting 2026-10-15). Nil where no band reaches.
    private func roadFade(_ cell: GridPoint) -> ArtLibrary.Fade? {
        var best: (seam: Int, share: Double)?
        for index in map.seams.indices {
            guard let share = map.seams[index].share(cell), share > (best?.share ?? 0) else { continue }
            best = (index, share)
        }
        guard let best, let other = foreignLand(map.seams[best.seam].neighbour) else { return nil }
        let eighths = (best.share * 8).rounded()
        guard eighths > 0 else { return nil }
        return ArtLibrary.Fade(tile: other.land.theme.path, from: other.from, share: eighths / 8)
    }

    /// The grounds the 3×3 round `cell` shows across the band (`look`), this land's and the lands
    /// next door's, a layer each (`base` this land's) with the cells showing it (bit row * 3 + col,
    /// row 0 north), by land id: `ArtLibrary.organicTile` lays them in that order, the same whichever
    /// land draws the tile. Nil where they're all this land's. One land's alone left out the others'
    /// where three met, and patches stopped dead there (playtesting 2026-10-16).
    private func grounds(_ cell: GridPoint, base: String) -> [ArtLibrary.GroundLayer]? {
        var masks: [String: Int] = [:]
        var bit = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if let land = look(GridPoint(col: cell.col + dx, row: cell.row - dy)) { masks[land, default: 0] |= 1 << bit }
                bit += 1
            }
        }
        guard masks.keys.contains(where: { $0 != map.def.id }) else { return nil }
        return masks.keys.sorted().compactMap { land -> ArtLibrary.GroundLayer? in
            let mask = masks[land] ?? 0
            if land == map.def.id { return ArtLibrary.GroundLayer(tile: base, mask: mask, style: .ground) }
            guard let other = foreignLand(land) else { return nil }
            return ArtLibrary.GroundLayer(tile: other.land.theme.ground, mask: mask, style: .ground, from: other.from)
        }
    }

    /// What shows between the soft shapes at a cell: its own ground, or for a road, pond or patch
    /// cell the ground around it.
    private func baseTile(_ cell: GridPoint, _ kind: Ground) -> String {
        switch kind {
        case .ground: theme.ground
        case .border: theme.border ?? theme.ground
        case .accent where !patchAccent: theme.accent ?? theme.ground
        default: mask(cell, .border) & Self.sides != 0 ? (theme.border ?? theme.ground) : theme.ground
        }
    }

    /// Which cells are plain ground, by `plainBase`.
    private var plainCache: [GridPoint: String?] = [:]

    /// The tile a cell shows if it's only plain ground, as `pick` draws it with no layers (no road,
    /// pond, patch, shore or a land next door's ground in it), else nil; nil off the land's box too.
    private func plainBase(_ cell: GridPoint) -> String? {
        if let known = plainCache[cell] { return known }
        var found: String? = nil
        if map.contains(cell) {
            let kind = map.ground[cell.row][cell.col]
            if kind != .sea, kind != .away, mask(cell, .path) == 0, mask(cell, .water) == 0,
               !(patchAccent && theme.accent != nil && mask(cell, .accent) != 0) {
                let base = baseTile(cell, kind)
                let band = map.seams.isEmpty ? nil : grounds(cell, base: base)
                let near = sea.isEmpty ? 0 : seaPool(cell)
                if band?.isEmpty ?? true, near == 0 || shore(cell) == 0 { found = base }
            }
        }
        plainCache[cell] = .some(found)
        return found
    }

    /// The land's box's south-west cell on the continent (none in a cave), so an edge's colour is
    /// hashed from where it lies in the world and two lands agree on the edges between them.
    private lazy var origin: GridPoint = Continent.origin(of: map.def) ?? GridPoint(col: 0, row: 0)

    /// A plain ground cell's edge Wang tile (`ArtLibrary.wangTile`, after SpriteCook's Wang tiles
    /// article): each edge's colour hashed from its place in the world, and 0 (the tile's own pixels
    /// along it) unless the cell across it is plain ground of the same tile, as everything else
    /// (roads, ponds, patches, shores, the four versions) meets the tile's own edge. Mirrored by
    /// `tools/wang_art.py` (`wang_index`).
    private func wang(_ cell: GridPoint, base: String) -> SKTileGroup {
        func open(_ dx: Int, _ dy: Int) -> Bool { plainBase(GridPoint(col: cell.col + dx, row: cell.row + dy)) == base }
        let col = cell.col + origin.col, row = cell.row + origin.row
        let north = open(0, 1) ? Self.edge(col, row + 1, horizontal: true) : 0
        let east = open(1, 0) ? Self.edge(col + 1, row, horizontal: false) : 0
        let south = open(0, -1) ? Self.edge(col, row, horizontal: true) : 0
        let west = open(-1, 0) ? Self.edge(col, row, horizontal: false) : 0
        let index = north + 2 * east + 4 * south + 8 * west
        return group("wang|\(base)#\(index)") { art.wangTile(base, index) }
    }

    /// An edge's colour, 0 or 1: the edge on the south side of world cell (`col`, `row`) if
    /// `horizontal`, else on its west side. A hash, so it has no pattern (`wang_art.edge_colour`).
    static func edge(_ col: Int, _ row: Int, horizontal: Bool) -> Int {
        var hash = UInt64(bitPattern: Int64(col)) &* 0x9E37_79B9_7F4A_7C15
        hash ^= UInt64(bitPattern: Int64(row)) &* 0xC2B2_AE3D_27D4_EB4F
        if horizontal { hash ^= 0x94D0_49BB_1331_11EB }
        hash ^= hash >> 29
        hash = hash &* 0xBF58_476D_1CE4_E5B9
        hash ^= hash >> 32
        return Int(hash & 1)
    }

    /// The tile a cell of the land's box shows (none on the sea, or on a land next door's cell), and
    /// whether it's within two of the sea (its bank, `WorldScene.bank`).
    func pick(_ cell: GridPoint) -> (group: SKTileGroup?, nearSea: Bool) {
        let (col, row) = (cell.col, cell.row)
        let kind = map.ground[row][col]
        guard kind != .sea, kind != .away else { return (nil, false) }
        let full = Self.full
        let road = mask(cell, .path), pond = mask(cell, .water)
        let variant = WorldScene.variant(of: cell)
        let patch = patchAccent ? mask(cell, .accent) : 0
        let base = baseTile(cell, kind)
        var layers: [ArtLibrary.GroundLayer] = []
        // The grounds across the band first, under everything of this land's.
        let band = map.seams.isEmpty ? nil : grounds(cell, base: base)
        if let band { layers += band }
        if patch != 0, let accent = theme.accent { layers.append(.init(tile: accent, mask: patch, style: .patch)) }
        let fade = road == 0 || map.seams.isEmpty ? nil : roadFade(cell)
        if road != 0 { layers.append(.init(tile: theme.path, mask: road, style: .road, fade: fade)) }
        if pond != 0 { layers.append(.init(tile: waterID, mask: poolMask(cell), style: .water)) }
        let near = sea.isEmpty ? 0 : seaPool(cell)
        let coast = near == 0 ? 0 : shore(cell)
        if coast != 0 { layers.append(.init(tile: base, mask: near, style: .cut)) }
        let chosen: SKTileGroup
        // A land's own water deepens out from its shores (`ArtLibrary.organicTile`): two cells out it's
        // the deep tile, nearer it's drawn as a shore is, shaded by how far in it lies.
        let natural = waterID == "tile_water" && waterVaries
        if pond == full, coast == 0, natural, poolMask(cell) == Self.wholePool, let field = pondField {
            chosen = group("pond|\(waterID)@\(col),\(row)#\(variant)") { art.pondTile(waterID, variant, cell: cell) { field.tone($0, $1) } }
        } else if pond == full, coast == 0, natural, poolMask(cell) == Self.wholePool {
            chosen = group("deep|\(waterID)#\(variant)") { art.deepWaterTile(waterID, variant) }
        } else if pond == full, coast == 0, !natural {
            chosen = waterVaries ? plain(waterID, variant) : water
        } else if road == full, pond == 0, coast == 0 {
            if let fade {
                chosen = group("faded|\(theme.path)|\(fade.key)#\(variant)") { art.fadedTile(theme.path, fade: fade, variant: variant) }
            } else {
                chosen = plain(theme.path, variant)
            }
        } else if let band, band.count == 1, let only = band.first, only.mask == full, layers.count == 1, let from = only.from {
            // All the land next door's ground.
            chosen = group("foreign|\(from.land)#\(variant)") {
                art.foreignTile(only.tile, palette: from.palette, from: from.land, variant: variant, base: base)
            }
        } else if layers.isEmpty {
            chosen = wang(cell, base: base)
        } else if let accent = theme.accent, patch == full, road == 0, pond == 0, coast == 0 {
            chosen = plain(accent, variant)
        } else {
            // Shorelines depend on where they are (see organicTile), so each gets its own tile.
            let place = pond != 0 || coast != 0 ? "@\(col),\(row)" : ""
            let key = base + "|" + layers.map { "\($0.style)\($0.mask)\($0.from?.land ?? "")\($0.fade?.key ?? "")" }.joined(separator: "|") + place
            var tone: ((Double, Double) -> Int)? = nil
            if pond != 0, let field = pondField { tone = { field.tone($0, $1) } }
            chosen = group(key) { art.organicTile(base: base, layers: layers, cell: cell, variant: variant, pond: tone) }
        }
        return (chosen, near != 0)
    }

    // MARK: Pond water

    /// The land's own lakes and rivers worked out once (`PondField`), for their water in the pond's
    /// tones (`ArtLibrary.pondTones`); none where its water is ice, chocolate or animated.
    private lazy var pondField: PondField? = makePondField()

    /// The tone (`ArtLibrary.pondTones`) of the land's own water at (x, y) in its cells; nil off its water,
    /// or where its water is ice, chocolate or animated. What a reflection falls on (`LandStage.reflect`).
    func pondTone(atCells x: Double, _ y: Double) -> Int? {
        pondField?.toneIfWater(x, y)
    }

    /// The pond's tones' colours in this land's water, graded with its palette.
    lazy var pondColours: [(r: Double, g: Double, b: Double)] = art.grading(palette: theme.palette, for: map.def.id) {
        art.pondPalette(of: waterID).tones
    }

    private func makePondField() -> PondField? {
        guard waterID == "tile_water", waterVaries else { return nil }
        var cells: Set<GridPoint> = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                for dr in -1...1 {
                    for dc in -1...1 { cells.insert(GridPoint(col: col + dc, row: row + dr)) }
                }
            }
        }
        guard !cells.isEmpty else { return nil }
        // Each cell's water as `pick` draws it: none without water in its 3×3, all of it deep out in
        // the water, else the shoreline's soft blobs (`ArtLibrary.organicTile`).
        var shapes: [GridPoint: (deep: Bool, pools: [(x: Double, y: Double)])] = [:]
        for cell in cells where mask(cell, .water) != 0 {
            let pools = poolMask(cell)
            shapes[cell] = (mask(cell, .water) == Self.full && pools == Self.wholePool, ArtLibrary.pools(mask: pools))
        }
        return PondField(cells: cells) { cell, x, y in
            guard let shape = shapes[cell] else { return false }
            if shape.deep { return true }
            let wobble = ArtLibrary.wobble(x, y, style: .water, cell: cell)
            return ArtLibrary.waterDepth(x, y, pools: shape.pools, wobble: wobble) > 0
        }
    }
}

/// A land's lakes and rivers, `samples` spots a cell over each cell of them and the cells round them,
/// worked out once (after SpriteCook's "Pixel art pond water: reflections and ripples"): which spots are
/// water, how far each lies from the nearest land, and how far below the far shore (up the screen) and
/// above the near one, so each pixel of the water takes the tone it should (`tone`). Mirrored in
/// `tools/pond_preview.py` (`layers`, its first two).
struct PondField {
    static let samples = 16
    /// How far the distance from the land is looked for, in spots: past it, as far as it matters.
    private static let reach = 5
    private var start: [GridPoint: Int] = [:]
    private var water: [Bool] = []
    /// Spots of water up the screen to the far shore, and down it to the near one, this one counted.
    private var up: [Int32] = []
    private var down: [Int32] = []
    /// Cells to the nearest land, up to `reach` spots.
    private var near: [Float] = []

    /// `isWater(cell, x, y)`: whether the point (x, y) of `cell` (-0.5...0.5 from its middle, y north) is water.
    init(cells: Set<GridPoint>, isWater: (GridPoint, Double, Double) -> Bool) {
        let s = Self.samples, per = s * s
        let ordered = cells.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        for (number, cell) in ordered.enumerated() { start[cell] = number * per }
        let count = ordered.count * per
        water = [Bool](repeating: false, count: count)
        for cell in ordered {
            guard let base = start[cell] else { continue }
            for j in 0..<s {
                for i in 0..<s {
                    let x = (Double(i) + 0.5) / Double(s) - 0.5, y = (Double(j) + 0.5) / Double(s) - 0.5
                    water[base + j * s + i] = isWater(cell, x, y)
                }
            }
        }
        // Up the screen is up both of the grid's ways at once: from the north-east down, each spot one
        // more than the one up the screen from it (a cell's spots all before the next cell's).
        up = [Int32](repeating: 0, count: count)
        for cell in ordered.reversed() {
            guard let base = start[cell] else { continue }
            for j in stride(from: s - 1, through: 0, by: -1) {
                for i in stride(from: s - 1, through: 0, by: -1) where water[base + j * s + i] {
                    let next = spot(cell, i + 1, j + 1).map { up[$0] } ?? 0
                    up[base + j * s + i] = next + 1
                }
            }
        }
        down = [Int32](repeating: 0, count: count)
        for cell in ordered {
            guard let base = start[cell] else { continue }
            for j in 0..<s {
                for i in 0..<s where water[base + j * s + i] {
                    let next = spot(cell, i - 1, j - 1).map { down[$0] } ?? 0
                    down[base + j * s + i] = next + 1
                }
            }
        }
        // The nearest land among the spots round each, nearest first.
        var offsets: [(di: Int, dj: Int, d: Float)] = []
        for dj in -Self.reach...Self.reach {
            for di in -Self.reach...Self.reach where di != 0 || dj != 0 {
                let d = Float((Double(di * di + dj * dj)).squareRoot())
                if d <= Float(Self.reach) { offsets.append((di, dj, d)) }
            }
        }
        offsets.sort { $0.d < $1.d }
        near = [Float](repeating: Float(Self.reach), count: count)
        for cell in ordered {
            guard let base = start[cell] else { continue }
            for j in 0..<s {
                for i in 0..<s where water[base + j * s + i] {
                    for offset in offsets {
                        let other = spot(cell, i + offset.di, j + offset.dj)
                        let dry = other.map { !water[$0] } ?? true
                        if dry {
                            near[base + j * s + i] = offset.d
                            break
                        }
                    }
                }
            }
        }
    }

    /// The index of spot (i, j) counted from `cell`'s south-west spot (past its edge, in the cell
    /// there); nil off the cells worked out.
    private func spot(_ cell: GridPoint, _ i: Int, _ j: Int) -> Int? {
        let s = Self.samples
        let dc = i >= 0 ? i / s : -((-i + s - 1) / s), dr = j >= 0 ? j / s : -((-j + s - 1) / s)
        let other = GridPoint(col: cell.col + dc, row: cell.row + dr)
        guard let base = start[other] else { return nil }
        return base + (j - dr * s) * s + (i - dc * s)
    }

    /// `tone`, or nil where (x, y) isn't water.
    func toneIfWater(_ x: Double, _ y: Double) -> Int? {
        let s = Self.samples
        let col = Int(x.rounded(.down)), row = Int(y.rounded(.down))
        let i = min(s - 1, max(0, Int(((x - Double(col)) * Double(s)).rounded(.down))))
        let j = min(s - 1, max(0, Int(((y - Double(row)) * Double(s)).rounded(.down))))
        guard let k = spot(GridPoint(col: col, row: row), i, j), water[k] else { return nil }
        return tone(x, y)
    }

    /// The tone (`ArtLibrary.pondTones`) of the water at (x, y), in cells of the land: by how far it lies
    /// from the land, 3 at the shore (under 3 of a tile's 32 pixels), 2 a little out, 1 past 7 pixels;
    /// lighter on the near half where it mirrors the sky (3 from a quarter of the way down from the far
    /// shore, 4 from halfway); a dark line along the far shore where the bank meets it; the shallows'
    /// tone along the near and side shores; the far bank mirrored just under its line (9 its grass, 8
    /// its mud).
    func tone(_ x: Double, _ y: Double) -> Int {
        let s = Self.samples
        let col = Int(x.rounded(.down)), row = Int(y.rounded(.down))
        let i = min(s - 1, max(0, Int(((x - Double(col)) * Double(s)).rounded(.down))))
        let j = min(s - 1, max(0, Int(((y - Double(row)) * Double(s)).rounded(.down))))
        guard let k = spot(GridPoint(col: col, row: row), i, j), water[k] else { return 3 }
        let land = Double(near[k]) / Double(s)
        let below = Double(up[k]), above = Double(down[k])
        if below <= 1, land < 0.12 { return 0 }
        // The far bank mirrored a few pixels down from its waterline (the user, 2026-11-17: "do the
        // things that are not done yet"): its grass, then its mud, before the water's own tones.
        if below <= 3, land < 0.2 { return below <= 2 ? 9 : 8 }
        if land < 0.06, below > 3 { return 7 }
        var tone = land < 0.09 ? 3 : (land > 0.22 ? 1 : 2)
        if land >= 0.09 {
            let along = below / max(1, below + above)
            if along >= 0.47 {
                tone = 4
            } else if along >= 0.23 {
                tone = max(tone, 3)
            }
        }
        return tone
    }
}
