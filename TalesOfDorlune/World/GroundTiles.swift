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
        // Past the land's box no ground is laid: asked about a river cell out there (`makePondField`
        // follows rivers past the border), it read past the end of `ground` and the game crashed
        // building Ingothold's countryside (the user, 2026-11-25).
        let own = map.contains(cell) && map.ground[cell.row][cell.col] == kind
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

    /// How far a carved road's drawn edge lies past the half width it painted its cells to (`carve`):
    /// as wide as its cells drew it before, when each was rounded off a third of a cell past its middle.
    private static let roadVerge = 0.2

    /// The spots along the land's carved roads (`WorldMap.roadSpots`) whose drawn edge reaches into
    /// each cell, worked out once.
    private lazy var roadSpots: [GridPoint: [(x: Double, y: Double, half: Double, road: Int)]] = {
        var near: [GridPoint: [(x: Double, y: Double, half: Double, road: Int)]] = [:]
        // Every other spot, half a cell apart at most: closer, a tile's every pixel measured to twice
        // as many for an edge no smoother.
        for (index, spot) in map.roadSpots.enumerated() where index % 2 == 0 {
            // As far again as where two roads' edges round into each other (`ArtLibrary.roadFillet`):
            // every cell near a junction knows both, or the rounding stopped at a cell's edge.
            let reach = spot.half + Self.roadVerge + 0.1 + ArtLibrary.roadFillet / 4
            for col in Int((spot.x - reach - 1).rounded(.down))...Int((spot.x + reach + 1).rounded(.down)) {
                for row in Int((spot.y - reach - 1).rounded(.down))...Int((spot.y + reach + 1).rounded(.down)) {
                    // Its nearest point to the cell's square within reach (with the edge's sway).
                    let dx = max(0, abs(Double(col) + 0.5 - spot.x) - 0.5), dy = max(0, abs(Double(row) + 0.5 - spot.y) - 0.5)
                    guard (dx * dx + dy * dy).squareRoot() < reach else { continue }
                    near[GridPoint(col: col, row: row), default: []].append(spot)
                }
            }
        }
        return near
    }()

    /// Which cells of the 3×3 around `cell` a carved road painted and are road still (as `mask`).
    private func curvedMask(_ cell: GridPoint) -> Int {
        var bits = 0
        for dy in -1...1 {
            for dx in -1...1 {
                let next = GridPoint(col: cell.col + dx, row: cell.row + dy)
                if map.curvedRoad.contains(next), map.contains(next), map.ground[next.row][next.col] == .path {
                    bits |= 1 << ((1 - dy) * 3 + dx + 1)
                }
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

    // MARK: Snow over a border

    /// Whether a land's ground is snow (Briarmere, Snow White Forest).
    private static func snowy(_ land: MapDef) -> Bool { land.theme.ground.contains("snow") }

    /// The snowy land on the far side of each of this land's borders with one, where this land isn't
    /// snowy, or this land itself (snowy) toward each that isn't: its band (`Seam`) and the snow's tones.
    private lazy var snowSeams: [(seam: Seam, tones: [(Double, Double, Double)], here: Bool)] = map.seams.compactMap {
        (seam: Seam) -> (seam: Seam, tones: [(Double, Double, Double)], here: Bool)? in
        guard let other = foreignLand(seam.neighbour), Self.snowy(other.land) != Self.snowy(map.def) else { return nil }
        let snowyLand = Self.snowy(other.land) ? other.land : map.def
        let from = Self.snowy(other.land) ? other.from : ArtLibrary.Foreign(land: map.def.id, palette: theme.palette)
        return (seam, art.snowTones(snowyLand.theme.ground, from: from), Self.snowy(map.def))
    }

    /// How snowed over a cell of this land's is, 0 to 1 (after SpriteCook's snow and ice article; the user,
    /// 2026-11-25: "nice for areas that go from one map to another"): on a land that isn't snowy, all of
    /// it on the border and none `reach` cells in from it, by the band of a snowy land next door; on a
    /// snowy land, all of it (what its band brought over of the land next door, `snowOver`).
    func snowCover(_ cell: GridPoint) -> Double {
        var cover = 0.0
        for entry in snowSeams {
            guard let side = entry.seam.side(cell) else { continue }
            let amount = entry.here ? 1 : min(1, max(0, 1 - (side - 0.5) / max(1, entry.seam.reach)))
            cover = max(cover, amount)
        }
        return cover
    }

    /// The snow's tones where a cell is snowed over: the snowy land's own, by the nearest band.
    func snowTones(_ cell: GridPoint) -> [(Double, Double, Double)]? {
        var best: (side: Double, tones: [(Double, Double, Double)])?
        for entry in snowSeams {
            guard let side = entry.seam.side(cell), abs(side) < best?.side ?? .infinity else { continue }
            best = (abs(side), entry.tones)
        }
        return best?.tones
    }

    /// A cell's tile with snow laid over it pixel by pixel as far as `snowCover` says (`ArtLibrary.snowed`),
    /// its cover blended between the cells' middles so the snow comes on smoothly across them. Not on
    /// water or the coast; on a snowy land, only where its band brought the land next door's ground.
    /// On a snowy land, a cell with its grass patches in it (`patched`) is snowed over too, by
    /// `meltCover` in the land's own snow (the user, 2026-11-25: "This partly melted spots should have
    /// the new treatment as well").
    private func snowOver(_ group: SKTileGroup, cell: GridPoint, band: Bool, wet: Bool, patched: Bool = false) -> SKTileGroup {
        guard !wet else { return group }
        let melting = Self.snowy(map.def) && !band && patched
        guard melting || (!snowSeams.isEmpty && !(Self.snowy(map.def) && !band)) else { return group }
        var corners: [GridPoint: Double] = [:]
        var any = false
        for dr in -1...1 {
            for dc in -1...1 {
                let near = GridPoint(col: cell.col + dc, row: cell.row + dr)
                let cover = melting ? meltCover(near) : snowCover(near)
                corners[near] = cover
                if cover > 0.01 { any = true }
            }
        }
        guard any, let tones = melting ? ownSnowTones : snowTones(cell), let picture = pictures[ObjectIdentifier(group)] else { return group }
        let covers = corners
        let front: (Double, Double) -> Double = { x, y in
            let fx = x - 0.5, fy = y - 0.5
            let col = Int(fx.rounded(.down)), row = Int(fy.rounded(.down))
            let tx = fx - Double(col), ty = fy - Double(row)
            func at(_ dc: Int, _ dr: Int) -> Double { covers[GridPoint(col: col + dc, row: row + dr)] ?? 0 }
            return (at(0, 0) * (1 - tx) + at(1, 0) * tx) * (1 - ty) + (at(0, 1) * (1 - tx) + at(1, 1) * tx) * ty
        }
        let place = origin
        return self.group("snow@\(cell.col),\(cell.row)") { art.snowed(picture, cell: cell, origin: place, front: front, tones: tones) }
    }

    /// How snowed over a cell of a snowy land's grass patches (theme `accent`, the spots where it's
    /// melted) is, 0 to 1: the snow all round them, three quarters of it on a patch's edge, thinning a
    /// third a cell further in, none from four cells in, so a patch's middle stays green and its edge
    /// is snow giving way to grass pixel by pixel.
    private func meltCover(_ cell: GridPoint) -> Double {
        guard map.owns(cell), map.ground[cell.row][cell.col] == .accent else { return 1 }
        for reach in 1...3 {
            for dr in -reach...reach {
                for dc in -reach...reach where max(abs(dr), abs(dc)) == reach {
                    let near = GridPoint(col: cell.col + dc, row: cell.row + dr)
                    guard map.owns(near), map.ground[near.row][near.col] != .accent else { continue }
                    return max(0, 0.75 - 0.33 * Double(reach - 1))
                }
            }
        }
        return 0
    }

    /// A snowy land's own snow's tones (`meltCover`).
    private lazy var ownSnowTones: [(Double, Double, Double)]? = art.snowTones(theme.ground, from: ArtLibrary.Foreign(land: map.def.id, palette: theme.palette))

    /// A plain ground cell in the band where this land meets one that isn't snow (or both are): its own
    /// ground with the land next door's laid over it pixel by pixel (`ArtLibrary.blendedIn`), as much as
    /// that land's share of the ground there (`Seam.share`, half on the border), blended between the
    /// cells' middles so it comes on smoothly. Nil where no such band reaches, or across a snow border,
    /// which has its own (`snowOver`).
    private func seamBlend(_ cell: GridPoint, base: String, variant: Int) -> SKTileGroup? {
        var best: (seam: Int, share: Double)?
        for index in map.seams.indices {
            guard let share = pixelShare(map.seams[index], cell), share > (best?.share ?? 0.005) else { continue }
            best = (index, share)
        }
        guard let best, let other = foreignLand(map.seams[best.seam].neighbour),
              Self.snowy(other.land) == Self.snowy(map.def) else { return nil }
        let seam = map.seams[best.seam]
        var corners: [GridPoint: Double] = [:]
        for dr in -1...1 {
            for dc in -1...1 {
                let near = GridPoint(col: cell.col + dc, row: cell.row + dr)
                corners[near] = pixelShare(seam, near) ?? best.share
            }
        }
        let own = wang(cell, base: base)
        guard let picture = pictures[ObjectIdentifier(own)] else { return nil }
        let theirs = art.foreignTile(other.land.theme.ground, palette: other.from.palette, from: other.from.land,
                                     variant: variant, base: base)
        let covers = corners
        let front: (Double, Double) -> Double = { x, y in
            let fx = x - 0.5, fy = y - 0.5
            let col = Int(fx.rounded(.down)), row = Int(fy.rounded(.down))
            let tx = fx - Double(col), ty = fy - Double(row)
            func at(_ dc: Int, _ dr: Int) -> Double { covers[GridPoint(col: col + dc, row: row + dr)] ?? 0 }
            return (at(0, 0) * (1 - tx) + at(1, 0) * tx) * (1 - ty) + (at(0, 1) * (1 - tx) + at(1, 1) * tx) * ty
        }
        let place = origin, first = seam.sign > 0
        return group("seam@\(cell.col),\(cell.row)") {
            art.blendedIn(picture, other: theirs, cell: cell, origin: place, first: first, front: front)
        }
    }

    /// How much of a cell's ground is the land next door's in the pixel blend (`seamBlend`): `Seam.share`
    /// over `pixelBand` cells either side of the border, not the seam's own width (the patches spread over
    /// 14; pixel by pixel, 5 reads as one soft edge, as the snow's does, and keeps the cells it makes few).
    private func pixelShare(_ seam: Seam, _ cell: GridPoint) -> Double? {
        seam.side(cell).map { Seam.share(at: $0, over: min(seam.reach, Self.pixelBand)) }
    }
    private static let pixelBand = 5.0

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
        if map.owns(cell) {
            // The land next door's patches show only across a snow border; elsewhere its ground comes in
            // pixel by pixel instead (`seamBlend`).
            guard let index = map.foreign[cell] else { return map.def.id }
            let neighbour = map.seams[index].neighbour
            guard let other = foreignLand(neighbour), Self.snowy(other.land) != Self.snowy(map.def) else { return map.def.id }
            return neighbour
        }
        if let known = lookPast[cell] { return known }
        let found = map.blend.flatMap { blend in blend.shows(cell).map { blend.around.lands[$0] } }
        lookPast[cell] = found
        return found
    }

    /// How a road cell takes on the road of the land next door across the band between them: its
    /// road tile, graded as it is there, laid over this land's pixel by pixel as the plain ground's is
    /// (`seamBlend`, `pixelShare`, half on the border), coming in smoothly between the cells' middles
    /// (`ArtLibrary.Fade`); with that land's ground under its edges, but across a snow border, which
    /// keeps its patches. A road changing in patches looked torn, at the border it was cut straight
    /// across (playtesting 2026-10-15), and mixed a cell at a time in eighths it showed in bands (the
    /// user, 2026-11-26). Nil where no band reaches.
    private func roadFade(_ cell: GridPoint) -> ArtLibrary.Fade? {
        var best: (seam: Int, share: Double)?
        for index in map.seams.indices {
            guard let share = pixelShare(map.seams[index], cell), share > (best?.share ?? 0.005) else { continue }
            best = (index, share)
        }
        guard let best, let other = foreignLand(map.seams[best.seam].neighbour) else { return nil }
        let seam = map.seams[best.seam]
        var corners: [Double] = []
        for row in 0..<3 {
            for col in 0..<3 {
                corners.append(pixelShare(seam, GridPoint(col: cell.col + col - 1, row: cell.row + 1 - row)) ?? best.share)
            }
        }
        var fade = ArtLibrary.Fade(tile: other.land.theme.path, from: other.from, corners: corners, first: seam.sign > 0,
                                   origin: origin, cell: cell)
        if Self.snowy(other.land) == Self.snowy(map.def) { fade.ground = other.land.theme.ground }
        return fade
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

    /// The cells of the 3×3 round `cell` that show the land's richer ground (`WorldMap.lush`), as `mask`
    /// counts them (bit row * 3 + col, row 0 north); none where the theme has no `lush`.
    private func lushMask(_ cell: GridPoint) -> Int {
        guard theme.lush != nil, !map.lush.isEmpty else { return 0 }
        var bits = 0
        for dy in -1...1 {
            for dx in -1...1 where map.lush.contains(GridPoint(col: cell.col + dx, row: cell.row + dy)) {
                bits |= 1 << ((1 - dy) * 3 + dx + 1)
            }
        }
        return bits
    }

    /// The tile a cell shows if it's only plain ground, as `pick` draws it with no layers (no road,
    /// pond, patch, shore or a land next door's ground in it), else nil; nil off the land's box too.
    private func plainBase(_ cell: GridPoint) -> String? {
        if let known = plainCache[cell] { return known }
        var found: String? = nil
        if map.contains(cell) {
            let kind = map.ground[cell.row][cell.col]
            if kind != .sea, kind != .away, mask(cell, .path) == 0, mask(cell, .water) == 0,
               !(patchAccent && theme.accent != nil && mask(cell, .accent) != 0), lushMask(cell) == 0 {
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

    /// Whether a cell is in the land's town square (`WorldMap.townSquare`), where its roads are cobbled.
    private func inTown(_ cell: GridPoint) -> Bool {
        guard map.def.town != nil else { return false }
        let square = map.townSquare
        return cell.col >= square.origin.col && cell.col < square.origin.col + square.width
            && cell.row >= square.origin.row && cell.row < square.origin.row + square.height
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
        let fade = road == 0 || map.seams.isEmpty ? nil : roadFade(cell)
        // Under a road whose ground comes in pixel by pixel (`Fade.ground`), not the band's patches too.
        let band = map.seams.isEmpty || fade?.ground != nil ? nil : grounds(cell, base: base)
        if let band { layers += band }
        // The land's richer ground in its broad patches, under its accent's.
        let lush = lushMask(cell)
        if lush != 0, let rich = theme.lush { layers.append(.init(tile: rich, mask: lush, style: .patch)) }
        if patch != 0, let accent = theme.accent { layers.append(.init(tile: accent, mask: patch, style: .patch)) }
        // In a town's square its roads are cobbled (`ArtLibrary.GroundLayer.cobbled`); out in the wild, sand.
        let cobbled = road != 0 && fade == nil && inTown(cell)
        if road != 0 {
            var layer = ArtLibrary.GroundLayer(tile: theme.path, mask: road, style: .road, fade: fade, cobbled: cobbled)
            if !cobbled, let spots = roadSpots[cell] {
                layer.curves = spots.map {
                    ArtLibrary.RoadSpot(x: $0.x - Double(col) - 0.5, y: $0.y - Double(row) - 0.5, half: $0.half + Self.roadVerge, road: $0.road)
                }
                layer.curved = curvedMask(cell)
            }
            layers.append(layer)
        }
        if pond != 0 { layers.append(.init(tile: waterID, mask: poolMask(cell), style: .water)) }
        let near = sea.isEmpty ? 0 : seaPool(cell)
        let coast = near == 0 ? 0 : shore(cell)
        if coast != 0 { layers.append(.init(tile: base, mask: near, style: .cut)) }
        let chosen: SKTileGroup
        // A land's own water deepens out from its shores (`ArtLibrary.organicTile`): two cells out it's
        // the deep tile, nearer it's drawn as a shore is, shaded by how far in it lies.
        let natural = ArtLibrary.isPondWater(waterID) && waterVaries
        if pond == full, coast == 0, natural, poolMask(cell) == Self.wholePool, let field = pondField {
            let toSea = seaward, across = acrossBorder, frozen = ice
            chosen = group("pond|\(waterID)@\(col),\(row)#\(variant)") {
                art.pondTile(waterID, variant, cell: cell, seaward: toSea, across: across, ice: frozen) { field.tone($0, $1) }
            }
        } else if pond == full, coast == 0, natural, poolMask(cell) == Self.wholePool {
            chosen = group("deep|\(waterID)#\(variant)") { art.deepWaterTile(waterID, variant) }
        } else if pond == full, coast == 0, !natural {
            chosen = waterVaries ? plain(waterID, variant) : water
        } else if road == full, pond == 0, coast == 0, !cobbled {
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
        } else if let rich = theme.lush, lush == full, layers.count == 1 {
            chosen = plain(rich, variant)
        } else if let accent = theme.accent, patch == full, road == 0, pond == 0, coast == 0 {
            chosen = plain(accent, variant)
        } else {
            // Shorelines depend on where they are (see organicTile), so each gets its own tile.
            let curving = layers.contains { !$0.curves.isEmpty }
            let place = (pond != 0 || coast != 0 || curving ? "@\(col),\(row)" : "") + (cobbled ? "|cob\(ArtLibrary.cobblePhase(cell))" : "")
            let key = base + "|" + layers.map { "\($0.style)\($0.mask)\($0.tile)\($0.from?.land ?? "")\($0.fade?.key ?? "")" }.joined(separator: "|") + place
            var tone: ((Double, Double) -> Int)? = nil
            if pond != 0, let field = pondField { tone = { field.tone($0, $1) } }
            let toSea = tone == nil ? nil : seaward, across = tone == nil ? nil : acrossBorder, frozen = tone == nil ? nil : ice
            chosen = group(key) {
                art.organicTile(base: base, layers: layers, cell: cell, variant: variant, pond: tone, seaward: toSea, across: across,
                                ice: frozen)
            }
        }
        // Across a border with a land that isn't snow, its plain ground comes in pixel by pixel, not in
        // patches (`seamBlend`); a road, pond, shore or patch there keeps the patches it had. A town's
        // countryside round its wall is `.border`, not `.ground`: left out, its side of every border
        // stayed a hard line while the land next door blended its own (the user, 2026-11-26, Ingothold).
        let plainKind = map.ground[row][col] == .ground || (map.ground[row][col] == .border && map.isCountryside(cell))
        if !map.seams.isEmpty, road == 0, pond == 0, coast == 0, lush == 0, patch == 0, plainKind,
           let blended = seamBlend(cell, base: base, variant: variant) {
            return (blended, near != 0)
        }
        return (snowOver(chosen, cell: cell, band: band != nil, wet: pond != 0 || coast != 0, patched: patch != 0), near != 0)
    }

    // MARK: Pond water

    /// The land's own lakes and rivers worked out once (`PondField`), for their water in the pond's
    /// tones (`ArtLibrary.pondTones`); none where its water is ice or animated.
    private lazy var pondField: PondField? = makePondField()

    /// A frozen land's ice (theme `frozen`, `ArtLibrary.freeze`): where its box lies, its cracks, and how
    /// far its water lies from the shore. Nil where its water isn't frozen.
    private lazy var ice: ArtLibrary.Ice? = {
        guard theme.frozen == true, let field = pondField else { return nil }
        return ArtLibrary.Ice(origin: origin, cracks: makeCracks(), shore: { field.shore($0, $1) })
    }()

    /// The ice's cracks (after the article): a few to a lake, by how much water the land has, each a
    /// wandering line from somewhere out in the water, a pixel a step, now and then a short branch off it,
    /// stopping at the shore. The same every time (seeded by the land), in art pixels on the continent.
    private func makeCracks() -> Set<Int> {
        var random = SeededRandom(text: map.def.id + "/ice cracks")
        var open: [GridPoint] = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                let all = (-1...1).allSatisfy { dr in
                    (-1...1).allSatisfy { dc in
                        let next = GridPoint(col: col + dc, row: row + dr)
                        return map.contains(next) && map.ground[next.row][next.col] == .water
                    }
                }
                if all { open.append(GridPoint(col: col, row: row)) }
            }
        }
        guard !open.isEmpty else { return [] }
        let size = Double(art.tilePixels(waterID))
        var cracks: Set<Int> = []
        for _ in 0..<min(40, max(1, open.count / 30)) {
            let start = open[Int.random(in: 0..<open.count, using: &random)]
            var walks: [(x: Double, y: Double, a: Double, steps: Int)] = [(
                Double(start.col) + Double.random(in: 0..<1, using: &random), Double(start.row) + Double.random(in: 0..<1, using: &random),
                Double.random(in: 0..<(2 * Double.pi), using: &random), Int.random(in: 14...30, using: &random))]
            while let walk = walks.popLast() {
                var x = walk.x, y = walk.y, a = walk.a
                for _ in 0..<walk.steps {
                    a += Double.random(in: -0.6...0.6, using: &random)
                    x += cos(a) / size
                    y += 0.5 * sin(a) / size
                    let cell = GridPoint(col: Int(x.rounded(.down)), row: Int(y.rounded(.down)))
                    guard map.contains(cell), map.ground[cell.row][cell.col] == .water else { break }
                    let u = Int(((Double(origin.col) + x) * size).rounded(.down))
                    let v = Int(((Double(origin.row) + y) * size).rounded(.down))
                    cracks.insert(ArtLibrary.iceKey(u, v))
                    if Double.random(in: 0..<1, using: &random) < 0.12 {
                        let turn = Bool.random(using: &random) ? 1.1 : -1.1
                        walks.append((x, y, a + turn, Int.random(in: 3...6, using: &random)))
                    }
                }
            }
        }
        return cracks
    }

    /// The tone (`ArtLibrary.pondTones`) of the land's own water at (x, y) in its cells; nil off its water,
    /// or where its water is ice or animated. What a reflection falls on (`LandStage.reflect`).
    func pondTone(atCells x: Double, _ y: Double) -> Int? {
        pondField?.toneIfWater(x, y)
    }

    /// How near the sea each of the land's own water cells lies along its water, 1 at the sea to 0
    /// `seaReach` cells up a river or more (`seaward`); empty where none of its water meets the sea.
    private lazy var seaShare: [GridPoint: Double] = {
        var distance: [GridPoint: Int] = [:]
        var frontier: [GridPoint] = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                let cell = GridPoint(col: col, row: row)
                let touches = (-1...1).contains { dr in (-1...1).contains { dc in sea.contains(GridPoint(col: col + dc, row: row + dr)) } }
                if touches {
                    distance[cell] = 1
                    frontier.append(cell)
                }
            }
        }
        while !frontier.isEmpty {
            var next: [GridPoint] = []
            for cell in frontier {
                guard let d = distance[cell], d < Self.seaReach else { continue }
                for dr in -1...1 {
                    for dc in -1...1 {
                        let other = GridPoint(col: cell.col + dc, row: cell.row + dr)
                        guard map.contains(other), map.ground[other.row][other.col] == .water, distance[other] == nil else { continue }
                        distance[other] = d + 1
                        next.append(other)
                    }
                }
            }
            frontier = next
        }
        var share = distance.mapValues { max(0, 1 - Double($0 - 1) / Double(Self.seaReach)) }
        for cell in sea where !share.isEmpty { share[cell] = 1 }
        return share.count > sea.count ? share : [:]
    }()
    /// How far up a river its water turns from the sea's colour to the land's own, in cells.
    private static let seaReach = 7

    /// How far past the land's border its pond field follows a river into the land next door, in cells.
    private static let pastBorder = 8

    /// Whether a cell is the land's own (in its box and not a land next door's).
    private func isOwn(_ cell: GridPoint) -> Bool {
        map.contains(cell) && map.ground[cell.row][cell.col] != .away
    }

    /// How far either side of a border a river's colour turns from one land's to the next's, in cells.
    private static let acrossReach = 6

    /// The land's own water cells within `acrossReach` of a land next door's river, with that land and
    /// how many steps off its river lies (8 ways a step, as `seaShare`), and that land's river cells
    /// beside the land's own water, at 0.
    private lazy var borderWater: [GridPoint: (land: String, steps: Double)] = {
        guard map.region != nil else { return [:] }
        // Each cell's nearest cell of the river past the border, found ring by ring (8 ways a step), and
        // how far it lies from it in a straight line: counted in steps, the colour's contours were squares,
        // straight edges across a lake by the border (the user, 2026-11-25: "corners around water create a
        // strange reflection in the water").
        var source: [GridPoint: (land: String, from: GridPoint)] = [:]
        var frontier: [GridPoint] = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                for dr in -1...1 {
                    for dc in -1...1 {
                        let next = GridPoint(col: col + dc, row: row + dr)
                        guard source[next] == nil, !isOwn(next), waterBeyond(next),
                              let land = Continent.owner(of: next, from: map.def), land.id != map.def.id else { continue }
                        source[next] = (land.id, next)
                        frontier.append(next)
                    }
                }
            }
        }
        var rings = 0
        while !frontier.isEmpty, rings <= Self.acrossReach + 1 {
            rings += 1
            var next: [GridPoint] = []
            for cell in frontier {
                guard let from = source[cell] else { continue }
                for dr in -1...1 {
                    for dc in -1...1 {
                        let other = GridPoint(col: cell.col + dc, row: cell.row + dr)
                        guard isOwn(other), map.ground[other.row][other.col] == .water else { continue }
                        let far = Double((other.col - from.from.col) * (other.col - from.from.col) + (other.row - from.from.row) * (other.row - from.from.row))
                        if let known = source[other] {
                            let had = Double((other.col - known.from.col) * (other.col - known.from.col) + (other.row - known.from.row) * (other.row - known.from.row))
                            if far < had { source[other] = from }
                            continue
                        }
                        source[other] = from
                        next.append(other)
                    }
                }
            }
            frontier = next
        }
        var found: [GridPoint: (land: String, steps: Double)] = [:]
        for (cell, from) in source {
            let dc = Double(cell.col - from.from.col), dr = Double(cell.row - from.from.row)
            let distance = (dc * dc + dr * dr).squareRoot()
            if distance <= Double(Self.acrossReach) + 1 { found[cell] = (from.land, distance) }
        }
        return found
    }()

    /// A land next door's water's tones and how much of them the land's own water takes at (x, y) in
    /// its cells, by the border where a river runs from one into the other (the user, 2026-11-25:
    /// "it should have a smoother color change"): half on the border, none `acrossReach` cells in,
    /// blended between the cells' middles as `seaward` is. The land next door does the same from its
    /// side, so the two meet at half each. Nil where no land next door's river is near, or its water
    /// isn't a pond's (ice).
    private lazy var acrossBorder: ((Double, Double) -> (tones: [(r: Double, g: Double, b: Double)], share: Double)?)? = {
        let near = borderWater
        guard !near.isEmpty else { return nil }
        var tones: [String: [(r: Double, g: Double, b: Double)]] = [:]
        for land in Set(near.values.map { $0.land }) {
            guard let other = foreignLand(land) else { continue }
            let water = other.land.theme.water ?? "tile_water"
            guard ArtLibrary.isPondWater(water) else { continue }
            tones[land] = art.foreignPondTones(water, from: other.from)
        }
        guard !tones.isEmpty else { return nil }
        let reach = Double(Self.acrossReach)
        let grid = map
        let ownWater: (GridPoint) -> Bool = { cell in
            grid.contains(cell) && grid.ground[cell.row][cell.col] == .water
        }
        return { x, y in
            let fx = x - 0.5, fy = y - 0.5
            let col = Int(fx.rounded(.down)), row = Int(fy.rounded(.down))
            let tx = fx - Double(col), ty = fy - Double(row)
            var sum = 0.0, weight = 0.0
            var next: String?
            for (dc, dr, w) in [(0, 0, (1 - tx) * (1 - ty)), (1, 0, tx * (1 - ty)), (0, 1, (1 - tx) * ty), (1, 1, tx * ty)] {
                let cell = GridPoint(col: col + dc, row: row + dr)
                if let found = near[cell] {
                    // How far into the land from the border: its river's cells half a cell out past it.
                    let t = found.steps - 0.5
                    sum += max(0, min(1, 0.5 - t / (2 * reach))) * w
                    weight += w
                    if next == nil { next = found.land }
                } else if ownWater(cell) {
                    weight += w
                }
            }
            guard let next, let theirs = tones[next], weight > 0 else { return nil }
            let share = sum / weight
            return share > 0 ? (tones: theirs, share: share) : nil
        }
    }()

    /// How much of the sea's colour the land's water at (x, y) in its cells takes (`seaShare`, blended
    /// between the cells' middles so it fades smoothly); nil if none of its water meets the sea.
    private var seaward: ((Double, Double) -> Double)? {
        let share = seaShare
        guard !share.isEmpty else { return nil }
        return { x, y in
            let fx = x - 0.5, fy = y - 0.5
            let col = Int(fx.rounded(.down)), row = Int(fy.rounded(.down))
            let tx = fx - Double(col), ty = fy - Double(row)
            var sum = 0.0, weight = 0.0
            for (dc, dr, w) in [(0, 0, (1 - tx) * (1 - ty)), (1, 0, tx * (1 - ty)), (0, 1, (1 - tx) * ty), (1, 1, tx * ty)] {
                guard let value = share[GridPoint(col: col + dc, row: row + dr)] else { continue }
                sum += value * w
                weight += w
            }
            return weight > 0 ? sum / weight : 0
        }
    }

    /// The pond's tones' colours in this land's water, graded with its palette.
    lazy var pondColours: [(r: Double, g: Double, b: Double)] = art.grading(palette: theme.palette, for: map.def.id) {
        art.pondPalette(of: waterID).tones
    }

    private func makePondField() -> PondField? {
        guard ArtLibrary.isPondWater(waterID), waterVaries else { return nil }
        var cells: Set<GridPoint> = []
        // A river running on into a land next door counts on past the border, `pastBorder` cells of it:
        // cut at the line, the water there was taken for a shore (a pale band along it) and the far
        // shore for near, the mirrored sky stopping dead (the user, 2026-11-25: "suddenly gets chopped").
        var beyond: Set<GridPoint> = []
        var frontier: [GridPoint] = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                for dr in -1...1 {
                    for dc in -1...1 {
                        let next = GridPoint(col: col + dc, row: row + dr)
                        guard map.contains(next), !isOwn(next), waterBeyond(next), beyond.insert(next).inserted else { continue }
                        frontier.append(next)
                    }
                }
            }
        }
        for _ in 0..<Self.pastBorder where !frontier.isEmpty {
            var next: [GridPoint] = []
            for cell in frontier {
                for dr in -1...1 {
                    for dc in -1...1 {
                        let other = GridPoint(col: cell.col + dc, row: cell.row + dr)
                        guard map.contains(other), !isOwn(other), waterBeyond(other), beyond.insert(other).inserted else { continue }
                        next.append(other)
                    }
                }
            }
            frontier = next
        }
        for cell in beyond {
            for dr in -1...1 {
                for dc in -1...1 { cells.insert(GridPoint(col: cell.col + dc, row: cell.row + dr)) }
            }
        }
        // The sea just past a river's mouth counts as more of its water, so the river has no shore
        // where it runs into the sea: no dark far bank, no shallows (the user, 2026-11-20).
        var mouth: Set<GridPoint> = []
        for row in 0..<map.rows {
            for col in 0..<map.columns where map.ground[row][col] == .water {
                for dr in -1...1 {
                    for dc in -1...1 { cells.insert(GridPoint(col: col + dc, row: row + dr)) }
                }
                for dr in -2...2 {
                    for dc in -2...2 {
                        let cell = GridPoint(col: col + dc, row: row + dr)
                        if sea.contains(cell) { mouth.insert(cell) }
                    }
                }
            }
        }
        guard !cells.isEmpty else { return nil }
        cells.formUnion(mouth)
        // Each cell's water as `pick` draws it: none without water in its 3×3, all of it deep out in
        // the water, else the shoreline's soft blobs (`ArtLibrary.organicTile`).
        var shapes: [GridPoint: (deep: Bool, pools: [(x: Double, y: Double)])] = [:]
        for cell in cells where mask(cell, .water) != 0 {
            let pools = poolMask(cell)
            shapes[cell] = (mask(cell, .water) == Self.full && pools == Self.wholePool, ArtLibrary.pools(mask: pools))
        }
        return PondField(cells: cells, sea: mouth) { cell, x, y in
            if mouth.contains(cell) { return true }
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
    /// How far down from the far shore each spot lies, 0 at it to 1 at the near one (`up` against
    /// `up + down`), averaged with the water spots beside it across the screen and a little up and
    /// down it: from one spot's count alone, wherever the far shore jumped (a bay, a point) the
    /// mirrored sky's edge dropped straight down the screen in a sheer line (the user, 2026-11-19:
    /// "the straight line in the lake water").
    private var along: [Float] = []
    /// Spots either way across the screen, and up and down it, `along` is averaged over.
    private static let acrossReach = 24
    private static let upReach = 3
    /// Spots either way, across and up, `along` is evened out over after (a cell's worth).
    private static let evenReach = 16
    /// How far up or down the screen the far and near shores are counted, in spots (4 cells): past it,
    /// a long river running up the screen took its far shore from wherever its next bend lay, and its
    /// mirrored sky jumped where the shore did (the user, 2026-11-25: "a corner in the river shows
    /// the reflection very choppy and suddenly gets chopped").
    private static let shoreCap: Int32 = 64

    /// The sea's cells past a river's mouth, worked out as its water but not the land's: nothing's
    /// mirrored on them (`toneIfWater`).
    private var sea: Set<GridPoint> = []

    /// `isWater(cell, x, y)`: whether the point (x, y) of `cell` (-0.5...0.5 from its middle, y north) is water.
    /// `sea`: the sea's cells among them (`sea`).
    init(cells: Set<GridPoint>, sea: Set<GridPoint> = [], isWater: (GridPoint, Double, Double) -> Bool) {
        self.sea = sea
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
        // How far down from the far shore, smoothed (`along`). Across the screen is one way along the
        // grid and back the other (i + 1, j - 1); up it, both ways at once (i + 1, j + 1).
        var raw = [Float](repeating: 0, count: count)
        for index in 0..<count where water[index] {
            let below = Float(min(up[index], Self.shoreCap)), above = Float(min(down[index], Self.shoreCap))
            raw[index] = below / max(1, below + above)
        }
        // In two passes, across and then up and down, each cell's neighbours (two cells each way)
        // looked up once: spot by spot through `spot(_:_:_:)`, a big lake took too long.
        let starts = start, wet = water
        func smooth(_ field: [Float], _ step: (Int) -> (di: Int, dj: Int), reach: Int) -> [Float] {
            var out = field
            for cell in ordered {
                guard let base = starts[cell] else { continue }
                var around = [Int?](repeating: nil, count: 25)
                for dr in -2...2 {
                    for dc in -2...2 { around[(dr + 2) * 5 + dc + 2] = starts[GridPoint(col: cell.col + dc, row: cell.row + dr)] }
                }
                for j in 0..<s {
                    for i in 0..<s where wet[base + j * s + i] {
                        var sum: Float = 0, weight: Float = 0
                        for k in -reach...reach {
                            let (di, dj) = step(k)
                            let ii = i + di, jj = j + dj
                            let dc = ii >= 0 ? ii / s : -((-ii + s - 1) / s), dr = jj >= 0 ? jj / s : -((-jj + s - 1) / s)
                            guard abs(dc) <= 2, abs(dr) <= 2, let other = around[(dr + 2) * 5 + dc + 2] else { continue }
                            let index = other + (jj - dr * s) * s + (ii - dc * s)
                            guard wet[index] else { continue }
                            sum += field[index]
                            weight += 1
                        }
                        if weight > 0 { out[base + j * s + i] = sum / weight }
                    }
                }
            }
            return out
        }
        let across = smooth(raw, { (di: $0, dj: -$0) }, reach: Self.acrossReach)
        var blended = smooth(across, { (di: $0, dj: $0) }, reach: Self.upReach)
        // Then evenly both ways, twice: smoothed across the screen alone, where the far shore turned a
        // corner the mirrored sky ended in a straight edge running on down the lake (the user,
        // 2026-11-25: "corners around water create a strange reflection in the water").
        for _ in 0..<2 {
            blended = smooth(blended, { (di: $0, dj: -$0) }, reach: Self.evenReach)
            blended = smooth(blended, { (di: $0, dj: $0) }, reach: Self.evenReach)
        }
        along = blended
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

    /// How far the water at (x, y) in the land's cells lies from the land, in cells (as far as the field
    /// looks, about a third of a cell); 0 off its water.
    func shore(_ x: Double, _ y: Double) -> Double {
        let s = Self.samples
        let col = Int(x.rounded(.down)), row = Int(y.rounded(.down))
        let i = min(s - 1, max(0, Int(((x - Double(col)) * Double(s)).rounded(.down))))
        let j = min(s - 1, max(0, Int(((y - Double(row)) * Double(s)).rounded(.down))))
        guard let k = spot(GridPoint(col: col, row: row), i, j), water[k] else { return 0 }
        return Double(near[k]) / Double(s)
    }

    /// `tone`, or nil where (x, y) isn't water.
    func toneIfWater(_ x: Double, _ y: Double) -> Int? {
        let s = Self.samples
        let col = Int(x.rounded(.down)), row = Int(y.rounded(.down))
        guard !sea.contains(GridPoint(col: col, row: row)) else { return nil }
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
        let below = Double(up[k])
        if below <= 1, land < 0.12 { return 0 }
        // The far bank mirrored a few pixels down from its waterline (the user, 2026-11-17: "do the
        // things that are not done yet"): its grass, then its mud, before the water's own tones.
        if below <= 3, land < 0.2 { return below <= 2 ? 9 : 8 }
        if land < 0.06, below > 3 { return 7 }
        var tone = land < 0.09 ? 3 : (land > 0.22 ? 1 : 2)
        if land >= 0.09 {
            let along = Double(self.along[k])
            if along >= 0.47 {
                tone = 4
            } else if along >= 0.23 {
                tone = max(tone, 3)
            }
        }
        return tone
    }
}
