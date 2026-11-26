import SpriteKit

/// What a land's things on the continent are kept in (`LandStage.world`): whoever walks in it stands
/// on that land's ground (`Walker.settle`).
final class StageNode: SKNode {
    weak var stage: LandStage?
}

/// A land's own things on the continent (`ContinentScene`), set down in its own points where its
/// plan put them (`LandPlanner`), as its own scene sets them down (`WorldScene.build`): its scenery
/// and buildings, its town's fence and terraces, lamps and fountains, the crags round a cave's mouth,
/// lily pads, fairy rings, its bridges' rails, its people, signposts, and the fences along the
/// borders a quest keeps closed; and its passers-by and animals, going about as you come near. Its
/// ground, hills and shore are the continent's (`ContinentScene.draw`).
///
/// Kept in pieces of the screen (`chunk(at:)`), only those near the camera in the scene (`show`),
/// as its own scene keeps them: a wooded land's thousands of trees cost nothing out of sight.
final class LandStage {
    let def: MapDef
    let map: WorldMap
    /// Everything of it, at its shift on the continent: its points are the land's own, and its depth
    /// too (`-y` in its own points, less its shift's), so it sorts among everything else there.
    let world = StageNode()
    /// The people who stand about it (`placeNPCs`), with their quest marks.
    private(set) var npcs: [(def: NPCDef, node: Walker, marker: NameTag)] = []
    /// Its passers-by, traders and locals (`Crowd`), and its animals (`Critters`).
    private(set) var crowd: Crowd?
    private var critters: Critters?
    /// Its tall grass you wade through (`GrassField`), if it grows any.
    private var grass: GrassField?
    /// Whether it's the land you're in: only then do its passers-by's chats reach yours.
    var isHere = false
    /// Where its own points lie in the continent's.
    let shift: CGVector
    private let art: ArtLibrary
    private let session: GameSession
    private let plan: LandPlan
    private let tiles: GroundTiles
    private var chunks: [GridPoint: SKNode] = [:]
    /// Each chunk's layers that keep a depth of the continent's own (`layer(at:lift:)`).
    private var layers: [GridPoint: [CGFloat: SKNode]] = [:]
    private var shownChunks: (low: GridPoint, high: GridPoint)?
    private var feet: [ObjectIdentifier: CGFloat] = [:]
    /// Shadows cast by its scenery on a hill or the sunk shore (`Lighting.Shadow`).
    private var shadows: [Lighting.Shadow] = []
    /// Debug flag `off=crags+shade+lighting+ambience+sky+ground+variation+sea`: those layers left
    /// out, to see which one draws something on screen (it found the Valley of Fear's pale patch,
    /// 2026-11-19: the sea's shallows over the ground, `ContinentScene.shallows`).
    static var offForDebug: Set<String> = []
    static func isOffForDebug(_ name: String) -> Bool {
        if GameSettings.devOff.contains(name) { return true }
        #if DEBUG
        return offForDebug.contains(name)
        #else
        return false
        #endif
    }

    /// The shade cast by everything it sets down on flat ground (`CanopyShade`), away from the sun
    /// (`follow`), stopping at its town's wall or fence (`WorldMap.fenceCells`).
    private lazy var canopy = CanopyShade(size: Self.chunkSize, walls: Set(map.fenceCells), map: map) { [unowned self] point in
        self.layer(at: point)
    }
    /// The walls along its borders that come down once you can cross (`placeBorders`): the border,
    /// and what's taken away (a gate's bar, or the whole fence).
    private var gates: [(neighbour: Continent.Neighbour, bar: [SKNode])] = []
    /// Its scenery tall enough to hide someone: nobody's set down behind it (`SeeThrough`).
    private let see = SeeThrough()
    private static let chunkSize: CGFloat = 400
    /// How far past the screen's edges a chunk is kept (`WorldScene.chunkMargin`).
    private static let chunkMargin: CGFloat = 360
    /// How far over everything that stands on the continent its layers above everything are lifted:
    /// past the deepest anything stands there (`ContinentScene`, about ±25,000).
    private static let above: CGFloat = 40_000
    /// How far its air is lifted (`air`, and the sparkles over a fairy ring or a fountain): with
    /// their own depths (20,000 to 30,000) past the deepest anything stands, and still under the
    /// night's shade over the screen (`Sky`, 43,000), as on a land's own map. Lifted `above`, the
    /// butterflies and sparkles stayed as bright at night as by day (playtesting 2026-10-16).
    private static let airLift: CGFloat = 10_000

    init(def: MapDef, map: WorldMap, plan: LandPlan, tiles: GroundTiles, art: ArtLibrary, session: GameSession, shift: CGVector) {
        self.def = def
        self.map = map
        self.plan = plan
        self.tiles = tiles
        self.art = art
        self.session = session
        self.shift = shift
        world.position = CGPoint(x: shift.dx, y: shift.dy)
        world.zPosition = -shift.dy
        world.stage = self
    }

    /// A layer of its own over everything that stands on the continent, for its air's parts that a
    /// land's scene puts over everything (`Ambience`'s butterflies and clouds' shadows, `Lighting`'s
    /// pools of light and sunbeams, and the particles drifting about): their depths, lifted
    /// `airLift`, keep their order there.
    private(set) lazy var air: SKNode = {
        let node = SKNode()
        node.zPosition = self.shift.dy + Self.airLift
        self.world.addChild(node)
        return node
    }()

    /// A point of its box brought onto the land itself, as `WorldScene.onLand` does: one past an
    /// edge mirrored back in, one off its shape moved in toward its middle.
    func onLand(_ point: CGPoint) -> CGPoint {
        let tile = WorldMap.tileSize
        let grid = WorldMap.unproject(point)
        func fold(_ value: CGFloat, _ length: CGFloat) -> CGFloat {
            value < 0 ? min(length, -value) : value > length ? max(0, 2 * length - value) : value
        }
        var spot = WorldMap.project(CGPoint(x: fold(grid.x, CGFloat(map.columns) * tile), y: fold(grid.y, CGFloat(map.rows) * tile)))
        let middle = map.center(of: map.center)
        for _ in 0..<6 where !map.owns(map.rawCell(at: spot)) {
            spot = CGPoint(x: (spot.x + middle.x) / 2, y: (spot.y + middle.y) / 2)
        }
        return spot
    }

    /// How high its ground stands under a point of its own (a hilltop, a terrace, down the shore).
    func groundHeight(at point: CGPoint) -> CGFloat { map.height(at: point) }

    /// A point of the continent's in its own points.
    func local(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x - shift.dx, y: point.y - shift.dy) }

    /// Sets it all down, a piece at a time (`pause` between them: grading with its own palette).
    /// `step`: says which step it's at (Settings → Developer's frame timing, `ContinentScene.breathe`). The
    /// frame's given back after every step (`pause`): between a dozen of them at once, one frame took 720 ms
    /// (the user's gauges, 2026-11-26).
    func build(pause: @escaping () async -> Void, step: @escaping (String) -> Void = { _ in }) async {
        func next(_ name: String) async {
            await pause()
            step(name)
        }
        step("water")
        placeLilyPads(plan.lilyPads)
        if !Self.isOffForDebug("water") { placeFloaters(plan.floaters) }
        await next("bridges")
        placeBridges()
        placeHarbors()
        await next("reeds")
        for (index, reed) in plan.reeds.enumerated() {
            if index % 40 == 39 { await pause() }
            let node = addScenery(reed)
            // The rocks cast one where the shade can't fall (the user, 2026-11-16: "The rocks in the water
            // should also have the shadows"): a lake and its shore lie sunk.
            if reed.art.hasPrefix("water_rock") || reed.art == "shore_stones" { roundShadow(under: node, at: reed.cell) }
            // The water's pale line round a rock's foot, lapping: brighter and fainter by turns.
            if reed.art.hasPrefix("water_rock") {
                if let line = waterline(for: reed.art, size: node.size, anchor: node.anchorPoint) {
                    line.zPosition = -0.01
                    node.addChild(line)
                    // With a key: in this async function a bare `run` is SKNode's async one, awaiting the
                    // action's end, which a forever action never reaches.
                    line.run(.sequence([.wait(forDuration: .random(in: 0...2)), .repeatForever(.sequence([
                        .fadeAlpha(to: 0.55, duration: 0), .wait(forDuration: 1.1), .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 1.6),
                    ]))]), withKey: "lap")
                }
            }
        }
        await next("falls")
        placeWaterfalls(plan.waterfalls)
        placeCliffFalls(plan.cliffFalls)
        await next("pond motion")
        placePondMotion()
        await next("fence")
        placeFence()
        await next("buildings")
        placeBuildings()
        await next("decor")
        placeDecor(plan.decor)
        await next("npcs")
        placeNPCs(plan.npcs)
        await next("local props")
        for (index, prop) in plan.localProps.enumerated() {
            if index % 40 == 39 { await pause() }
            addScenery(prop)
        }
        await next("fairy rings")
        placeFairyRings(plan.fairyRings)
        await next("outcrops")
        for (index, rock) in plan.outcrops.enumerated() {
            if index % 40 == 39 { await pause() }
            addScenery(rock)
        }
        await next("props")
        await placeProps(plan.props, seams: plan.seamProps, pause: pause)
        await next("tall grass")
        placeTallGrass()
        await next("roadsides")
        placeRoadsides()
        await next("signposts")
        placeSignposts(plan.signposts)
        await next("crags")
        placeCrags()
        await next("plateaus")
        placePlateaus()
        await next("borders")
        placeBorders()
        await next("panes")
        hidePanesBehindScenery()
        await next("into view")
        bringIntoView()
        for npc in npcs { npc.node.settle() }
        await next("crowd")
        // A town's market traders sell what they have today, around your level.
        let market = Crowd.Market(sign: { [weak session] in session?.marketSign(for: $0) },
                                  shout: { [weak session] in session?.marketShout(for: $0) },
                                  level: session.data.hero.level)
        // Your friends who are here now come along among its adventurers (`GameSession.friendsIn`).
        let crowd = Crowd(def: def, map: map, world: world, heroLevel: session.data.hero.level, friends: session.friendsIn(def.id),
                          market: market, locals: plan.locals, hides: { [see, map] in see.hides($0, on: map) })
        // Its locals stand where the plan put them: off to a spot nothing hides, if something does.
        crowd.moveOutOfHiding()
        crowd.onChat = { [weak self, weak session] speaker, text, kind, art, adventurer in
            guard self?.isHere == true else { return }
            session?.postChat(text, from: speaker, kind: kind, art: art, adventurer: adventurer)
        }
        crowd.dares = { [weak session] rival in session?.dares(rival) ?? false }
        self.crowd = crowd
        await next("critters")
        critters = Critters(def.ambience, world: world, map: map, seed: def.id)
        step("done")
    }

    /// What each chest shows now, opened or not (`showChest`).
    private var chestShown: [String: Bool] = [:]

    /// A chest closed in its land's style till it's opened, then open (`ChestLook`); with no closed
    /// drawing for the land, faded while it's empty.
    private func showChest(_ chest: NPCDef, _ node: Walker) {
        let opened = session.isOpened(chest.id)
        guard let closed = ChestLook.closed(in: def, art: art) else {
            if opened == (node.alpha > 0.5) { node.run(.fadeAlpha(to: opened ? 0.35 : 1, duration: 0.3)) }
            return
        }
        guard chestShown[chest.id] != opened else { return }
        chestShown[chest.id] = opened
        node.setCycle(art.walkCycle(opened ? ChestLook.open(in: def, art: art, fallback: chest.art) : closed))
        node.alpha = 1
    }

    /// Whether any of its chunks is in the scene, near the camera (`show`).
    private(set) var onScreen = false

    /// A frame of its life (`player` and `camera` in the continent's points, the screen at
    /// `scale`): its people stroll and its animals mind you as you come near, and its pieces near the
    /// camera are in the scene. Its birds cross the sky only while you're in it (`isHere`). Its people
    /// wait while none of it is near the screen (the speed audit, 2026-11-17: every land round you,
    /// most of them out of sight, walked and found its ways every frame).
    func update(dt: TimeInterval, player: CGPoint, camera: CGPoint, scale: CGFloat, screen: CGSize, isHere: Bool = true) {
        let you = local(player), eye = local(camera)
        if onScreen || isHere { crowd?.update(dt: dt, player: you) }
        FrameTiming.shared.lap("crowd")
        let visible = CGRect(x: eye.x - screen.width / 2 * scale, y: eye.y - screen.height / 2 * scale,
                             width: screen.width * scale, height: screen.height * scale)
        critters?.update(dt: dt, player: you, visible: visible, flocks: isHere) { [map] in map.isWalkable(map.rawCell(at: $0)) }
        FrameTiming.shared.lap("critters")
        show(around: camera, scale: scale, screen: screen)
        FrameTiming.shared.lap("chunks")
        if let grass, isHere || onScreen { wade(through: grass, dt: dt, you: you) }
        FrameTiming.shared.lap("grass")
        let shadeOff = Self.isOffForDebug("shade")
        canopy.setOff(shadeOff)
        if !shadeOff { canopy.draw() }
        FrameTiming.shared.lap("shade")
        coverPanes(dt)
        FrameTiming.shared.lap("panes")
    }

    /// Lays the shade under its scenery away from `sun` (`CanopyShade.follow`).
    func follow(_ sun: Sun) {
        guard !Self.isOffForDebug("shade") else { return }
        canopy.follow(sun)
    }

    /// Its people's quest marks (`!` news, `?` done), opened chests and beaten bosses, and its
    /// townsfolk turning to watch you pass (`player` in the continent's points), as
    /// `WorldScene.updateNotices` has them. The one nearest you within `reach`, if any, and how near.
    func updateNotices(player: CGPoint, reach: CGFloat) -> (npc: NPCDef, distance: CGFloat)? {
        let you = local(player)
        var nearest: (npc: NPCDef, distance: CGFloat)?
        for npc in npcs {
            npc.node.isNear = npc.node.position.distance(to: you) < Walker.nameRange
            // A chest stands closed in its land's style (`ChestLook`) till it's opened, then open; with no
            // closed drawing for its land, faded while it's empty, and back as something new turns up in it.
            if npc.def.role == .chest { showChest(npc.def, npc.node) }
            // A waystone stands faded while it sleeps, and comes back once its quest wakes it.
            if npc.def.role == .waystone, session.isAwake(npc.def) == (npc.node.alpha < 0.9) {
                npc.node.run(.fadeAlpha(to: session.isAwake(npc.def) ? 1 : 0.55, duration: 0.3))
            }
            if npc.def.role == .boss, session.isBeatenHere(npc.def) {
                if !npc.node.isHidden {
                    SkillEffects.smoke(at: npc.node.position, in: world)
                    npc.node.isHidden = true
                }
                continue
            }
            let notice = session.notice(for: npc.def.id)
            npc.marker.isHidden = notice == nil
            if let notice { npc.marker.setText(notice == .ready ? "?" : "!") }
            let distance = you.distance(to: npc.node.position)
            if distance <= reach, distance < (nearest?.distance ?? .infinity) { nearest = (npc.def, distance) }
            // Townsfolk at their posts turn to watch you pass, and glance around otherwise.
            if !npc.def.role.isObject, npc.def.role != .boss {
                if distance < 130 {
                    npc.node.face(Direction(you - npc.node.position, current: npc.node.facing))
                } else if Int.random(in: 0..<12) == 0 {
                    npc.node.face(Direction.allCases.randomElement() ?? .down)
                }
            }
        }
        return nearest
    }

    /// Everyone else about it, for the minimap (in its cells): the adventurers walking about (friends
    /// and those spoiling for a fight marked so) and the folk who live here (`WorldScene.minimapDots`).
    func minimapDots(friends: Set<UUID>, party: Set<UUID> = []) -> [GameSession.MinimapDot] {
        let walkers = (crowd?.adventurerPositions ?? []).map { profile, position in
            GameSession.MinimapDot(cell: map.cell(at: position), kind: GameSession.MinimapDot.kind(of: profile, friends: friends, party: party))
        }
        let folk = (crowd?.folkPositions ?? []).map { GameSession.MinimapDot(cell: map.cell(at: $0), kind: .folk) }
        return folk + walkers
    }

    /// Who does what about it, for the minimap's icons (`WorldScene.minimapMarks`): quest givers as
    /// their marks say, the healer, the shop, the smith, the guilds, a chest still to open, a boss
    /// still to beat.
    func minimapMarks() -> [GameSession.MinimapMark] {
        npcs.compactMap { npc -> GameSession.MinimapMark? in
            guard !npc.node.isHidden else { return nil }
            guard let kind = session.minimapKind(for: npc.def) else { return nil }
            return GameSession.MinimapMark(cell: map.cell(at: npc.node.position), kind: kind)
        }
    }

    /// Whoever of its people was tapped at `point` (the continent's): one of its own, by where they
    /// stand (and how high), unless they've gone.
    func npc(tappedAt point: CGPoint) -> (def: NPCDef, node: Walker)? {
        let spot = local(point)
        return npcs.first { !$0.node.isHidden && ($0.node.position + CGVector(dx: 0, dy: 24 + $0.node.lift)).distance(to: spot) < 34 }
            .map { ($0.def, $0.node) }
    }

    // MARK: Seeing through

    /// Moves anyone it set down where a building or tall scenery in front of them hides them (put by
    /// hand behind a shop, or a tree planted before them) to the nearest cell nothing hides
    /// (playtesting 2026-10-31: Spectacle-Maker Fennimore stood behind the shop on Emerald Road,
    /// only his name showing).
    private func bringIntoView() {
        var taken = Set(npcs.map { map.cell(at: $0.node.position) })
        for npc in npcs {
            guard let spot = see.clearSpot(near: npc.node.position, size: npc.node.sprite.size, map: map, taken: taken) else { continue }
            taken.remove(map.cell(at: npc.node.position))
            taken.insert(spot)
            npc.node.position = map.center(of: spot)
            npc.node.zPosition = map.depth(at: npc.node.position)
        }
    }

    // MARK: Chunks

    /// The piece of the land holding what's drawn at `position` (its own points).
    private func chunk(at position: CGPoint) -> SKNode {
        let key = Self.key(position.x, position.y)
        if let known = chunks[key] { return known }
        let node = SKNode()
        chunks[key] = node
        shownChunks = nil
        return node
    }

    /// A layer of the chunk at `position` for things with a depth of the continent's own, not the
    /// land's: the ground's shadows and lily pads (`lift` 0, just over the ground at -100,000), or,
    /// lifted `airLift` or `above`, the sparkles, mist and signs over everything that stands.
    private func layer(at position: CGPoint, lift: CGFloat = 0) -> SKNode {
        let key = Self.key(position.x, position.y)
        if let known = layers[key]?[lift] { return known }
        let node = SKNode()
        // Undoes the land's own depth (`world`'s).
        node.zPosition = shift.dy + lift
        chunk(at: position).addChild(node)
        layers[key, default: [:]][lift] = node
        return node
    }

    private static func key(_ x: CGFloat, _ y: CGFloat) -> GridPoint {
        GridPoint(col: Int((x / chunkSize).rounded(.down)), row: Int((y / chunkSize).rounded(.down)))
    }

    /// Puts its chunks near the camera (`camera` in the continent's points, showing `screen` at
    /// `scale`) in the scene, and takes the rest out (their actions wait).
    func show(around camera: CGPoint, scale: CGFloat, screen: CGSize) {
        let local = CGPoint(x: camera.x - shift.dx, y: camera.y - shift.dy)
        let reach = CGSize(width: screen.width / 2 * scale + Self.chunkMargin, height: screen.height / 2 * scale + Self.chunkMargin)
        let low = Self.key(local.x - reach.width, local.y - reach.height)
        let high = Self.key(local.x + reach.width, local.y + reach.height)
        if let shown = shownChunks, shown.low == low, shown.high == high { return }
        shownChunks = (low, high)
        defer { onScreen = chunks.values.contains { $0.parent != nil } }
        canopy.show(low: low, high: high)
        for (spot, node) in chunks {
            let near = spot.col >= low.col && spot.col <= high.col && spot.row >= low.row && spot.row <= high.row
            if near, node.parent == nil {
                world.addChild(node)
            } else if !near, node.parent != nil {
                node.removeFromParent()
            }
        }
    }

    // MARK: Scenery

    /// A piece of scenery as the plan set it down: its own sprite, or `sprite` (a land next door's,
    /// graded as it is there).
    @discardableResult
    private func addScenery(_ placement: Placement, sprite: SpriteArt? = nil) -> SKSpriteNode {
        var drawn = sprite ?? art.sprite(placement.art)
        // Snow on its top near a snowy land's border, as the ground there is snowed over
        // (`GroundTiles.snowCover`, `ArtLibrary.capped`; the user, 2026-11-25), unless it's a snowy land's
        // own (already drawn in snow) or a building.
        let snowyOwn = (placement.land ?? def).theme.ground.contains("snow")
        if !snowyOwn, art.asset(placement.art)?.kind != "building", drawn.size.height >= 12 {
            let cover = tiles.snowCover(placement.cell)
            let stage = cover > 0.75 ? 3 : cover > 0.45 ? 2 : cover > 0.15 ? 1 : 0
            if stage > 0, let tones = tiles.snowTones(placement.cell) {
                drawn = SpriteArt(texture: art.capped(drawn.texture, stage: stage, tones: tones), size: drawn.size)
            }
        }
        let node = addScenery(drawn, at: placement.cell, nudge: placement.nudge, sway: placement.sway, scale: placement.scale,
                              wind: placement.art)
        reflect(node, picture: drawn.texture, art: placement.art, cell: placement.cell)
        addFire(to: node, art: placement.art)
        addWindows(to: node, art: placement.art, colour: placement.prop?.glow.flatMap { UIColor(hex: $0) })
        if placement.art == "lighthouse" { addBeam(to: node) }
        if placement.art == "brazier" {
            addSmoke(to: node)
        } else if let hole = Self.smokeHoles[placement.art] {
            addSmoke(to: node, from: hole, colour: Self.smokeColours[placement.art])
        }
        // Lit by a lamp nearby at night (`LampLight`): not a light itself, nor what moves in the wind
        // (its picture changes, the light's copy wouldn't).
        if !lamps.isEmpty, node.texture === drawn.texture, !lights.contains(placement.art), placement.prop?.glow == nil {
            LampLight.shared.light(node, picture: art.picture(of: drawn.texture), key: "\(placement.art)@\(placement.land?.id ?? def.id)",
                                   from: lamps)
        }
        return node
    }

    /// Where smoke rises from a building whose picture has a smoke hole or chimney, as a fraction of
    /// its picture from the top left: the yurt's smoke hole at the tip of its cone, the teapot's
    /// spout, the smokehouse's stack, the genie lamp's spout (ChatGPT's drawings, their drawn smoke
    /// cut out so it moves; the user, 2026-11-21: "the smoke needs to be animated", 2026-11-22: "Any
    /// house that has something with smoke needs to be animated"), and the top of every chimney.
    private static let smokeHoles: [String: CGPoint] = [
        "yurt": CGPoint(x: 47.0 / 96, y: 25.0 / 96),
        "teapot_house": CGPoint(x: 80.0 / 96, y: 43.0 / 96),
        "smokehouse": CGPoint(x: 68.0 / 96, y: 20.0 / 96),
        "lamp_house": CGPoint(x: 84.5 / 96, y: 53.0 / 96),
        // Chimneys with nothing coming out (the user, 2026-11-22: "make everything feel more alive").
        "inn": CGPoint(x: 61.5 / 96, y: 9.0 / 96),
        "inn_red": CGPoint(x: 61.5 / 96, y: 9.0 / 96),
        "inn_teal": CGPoint(x: 61.5 / 96, y: 9.0 / 96),
        "thatched_cottage": CGPoint(x: 61.0 / 96, y: 27.0 / 96),
        "painter_studio": CGPoint(x: 67.0 / 96, y: 19.0 / 96),
        "woodcutter_cabin": CGPoint(x: 68.0 / 96, y: 18.0 / 96),
        "stump_house": CGPoint(x: 70.0 / 96, y: 16.0 / 96),
        "ice_fishing_hut": CGPoint(x: 63.5 / 96, y: 21.0 / 96),
        "brick_house": CGPoint(x: 66.0 / 96, y: 16.0 / 96),
        "toymaker_workshop": CGPoint(x: 69.0 / 96, y: 22.0 / 96),
        "stone_townhouse": CGPoint(x: 72.5 / 96, y: 15.0 / 96),
        "coral_house": CGPoint(x: 34.5 / 96, y: 19.0 / 96),
        "snow_cabin": CGPoint(x: 25.5 / 96, y: 19.0 / 96),
        "post_office": CGPoint(x: 27.5 / 96, y: 22.0 / 96),
        "timber_house": CGPoint(x: 73.5 / 96, y: 19.0 / 96),
        "apothecary": CGPoint(x: 68.0 / 96, y: 12.0 / 96),
        "emerald_shop": CGPoint(x: 32.5 / 96, y: 17.0 / 96),
        "glass_lantern_shop": CGPoint(x: 59.0 / 96, y: 11.0 / 96),
        // Shiverdell's cauldron, its brew steaming.
        "bubbling_cauldron": CGPoint(x: 16.0 / 32, y: 9.0 / 32),
    ]

    /// A smoke hole's own colour where it isn't grey smoke: the teapot's white steam, the genie
    /// lamp's purple wisp, as drawn.
    private static let smokeColours: [String: UIColor] = [
        "teapot_house": UIColor(white: 0.95, alpha: 1),
        "lamp_house": UIColor(red: 0.66, green: 0.52, blue: 0.8, alpha: 1),
        "bubbling_cauldron": UIColor(red: 0.62, green: 0.85, blue: 0.55, alpha: 1),
    ]

    /// Smoke rising from a fire (a camp's or a lair's brazier, from the top of its picture) or a
    /// building's smoke hole (`hole`, `smokeHoles`): a soft grey puff every half second or so that
    /// drifts up, swells and fades; only while its chunk is in the scene.
    private func addSmoke(to node: SKSpriteNode, from hole: CGPoint? = nil, colour: UIColor? = nil) {
        let top: CGPoint
        if let hole {
            top = CGPoint(x: (hole.x - node.anchorPoint.x) * node.size.width,
                          y: (1 - hole.y - node.anchorPoint.y) * node.size.height)
        } else {
            top = CGPoint(x: 0, y: node.size.height * (1 - node.anchorPoint.y) - 4)
        }
        let puff = SKAction.run { [weak node] in
            guard let node else { return }
            let smoke = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: 12, height: 12))
            smoke.color = colour ?? UIColor(white: 0.55, alpha: 1)
            smoke.colorBlendFactor = 1
            smoke.alpha = 0.5
            smoke.position = CGPoint(x: top.x + .random(in: -3...3), y: top.y)
            smoke.zPosition = 0.02
            node.addChild(smoke)
            smoke.run(.sequence([
                .group([.scale(to: .random(in: 2...2.8), duration: 2.4), .moveBy(x: .random(in: 4...12), y: 34, duration: 2.4),
                        .fadeOut(withDuration: 2.4)]),
                .removeFromParent(),
            ]))
        }
        node.run(.repeatForever(.sequence([puff, .wait(forDuration: 0.55, withRange: 0.3)])))
    }

    /// A building's windows lit at night (`tools/window_art.py`, the user, 2026-11-18: "during the
    /// night the lights in houses should be brighter"): its windows' own picture laid over it above
    /// the night's shade (`Sky`, 43 000 up), so they glow as drawn while the house dims; in as it
    /// grows dark and out by day with the lamps' light (`LampLight.follow`).
    /// Each window is a sprite of its own (`windowBoxes`), put out while someone stands in front of
    /// it (`coverPanes`): drawn above the shade, a pane would show over their head (the user,
    /// 2026-11-18: "the lit panes shouldn't be over the hero's head").
    /// A light's own bright parts are cut the same way (a lamp's, a lantern's, a torch's or a
    /// crystal's: `windows_<id>` too), and every one shines a soft glow round it, as real light does
    /// (the user, 2026-11-22: "anything else that could have light in the evening/night should be lit
    /// up. There should also be a soft glow around it"), in the light's own colour (`colour`, its
    /// prop's `glow`) or a lamp's warm one.
    private func addWindows(to node: SKSpriteNode, art id: String, colour: UIColor? = nil) {
        let name = "windows_\(id)"
        guard art.asset(name) != nil else { return }
        let texture = art.sprite(name).texture
        let picture = art.picture(of: texture)
        let width = CGFloat(picture.width), height = CGFloat(picture.height)
        guard width > 0, height > 0 else { return }
        let lit = SKSpriteNode(color: .clear, size: .zero)
        lit.zPosition = 43_100 - node.zPosition
        node.addChild(lit)
        LampLight.shared.follow(lit)
        let sx = node.size.width / width, sy = node.size.height / height
        let left = -node.anchorPoint.x * node.size.width, bottom = -node.anchorPoint.y * node.size.height
        // Crystals glow softer than a window or a flame (the user, 2026-11-25: "a bit too bright and
        // obvious at night"): their lit copy a little dimmer, their glow fainter and closer.
        let mineral = Self.minerals.contains { id.contains($0) }
        for box in windowBoxes(of: name, picture: picture) {
            let part = SKTexture(rect: CGRect(x: box.minX / width, y: 1 - box.maxY / height, width: box.width / width,
                                              height: box.height / height), in: texture)
            part.filteringMode = .nearest
            let pane = SKSpriteNode(texture: part, size: CGSize(width: box.width * sx, height: box.height * sy))
            pane.position = CGPoint(x: left + box.midX * sx, y: bottom + (height - box.midY) * sy)
            if mineral {
                pane.color = .black
                pane.colorBlendFactor = 0.3
            }
            lit.addChild(pane)
            // Its glow: soft light spilling round it, behind it, added to what's under it.
            let reach = max(pane.size.width, pane.size.height) * (mineral ? 0.7 : 1)
            let halo = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: pane.size.width * 1.6 + reach * 1.4 + 14,
                                                                             height: pane.size.height * 1.6 + reach * 1.4 + 14))
            halo.color = colour ?? UIColor(red: 1, green: 0.78, blue: 0.45, alpha: 1)
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.alpha = mineral ? 0.2 : 0.42
            halo.position = pane.position
            halo.zPosition = -0.01
            // Steady: a land can hold hundreds of lights (Twilight Woods' glowing mushrooms), each
            // pulsing would cost the frame. Beside its pane, not on it: it stays while the pane fades
            // for someone standing in front (`coverPanes`; the user, 2026-11-25: the glow went too).
            lit.addChild(halo)
            litPanes.append(LitPane(pane: pane, halo: halo, building: node, box: box, picture: picture,
                                    left: left, bottom: bottom, sx: sx, sy: sy, height: height))
            // Where it shows in the land's points, and how far down the screen its building stands.
            let middle = CGPoint(x: node.position.x + pane.position.x * node.xScale, y: node.position.y + pane.position.y)
            panes.append(Pane(node: pane, box: CGRect(x: middle.x - pane.size.width / 2, y: middle.y - pane.size.height / 2,
                                                      width: pane.size.width, height: pane.size.height), foot: node.position.y))
        }
    }

    /// A building's lit window: its sprite, where it shows in the land's points, and its building's foot.
    private struct Pane {
        let node: SKSpriteNode
        let box: CGRect
        let foot: CGFloat
    }
    private var panes: [Pane] = []
    private var paneTimer: TimeInterval = 0
    private static let coverKey = "cover"
    /// What's a crystal by its art's name (`addWindows`): lit softer than windows and flames.
    private static let minerals = ["crystal", "spire", "geode", "shard", "ice_cluster", "amethyst"]

    /// Something set down that can stand in front of a lit window (`hidePanesBehindScenery`): its
    /// node and the picture it was set down with.
    private struct Occluder {
        let node: SKSpriteNode
        let picture: CGImage
    }
    private var occluders: [Occluder] = []

    /// A lit window as `addWindows` cut it: its sprite and glow, its building, its box in the windows
    /// picture's pixels (from the top left) and how that picture lies on the building.
    private struct LitPane {
        let pane: SKSpriteNode
        let halo: SKSpriteNode
        let building: SKSpriteNode
        let box: CGRect
        let picture: CGImage
        let left: CGFloat
        let bottom: CGFloat
        let sx: CGFloat
        let sy: CGFloat
        let height: CGFloat
    }
    private var litPanes: [LitPane] = []

    /// Cuts out of each lit window whatever stands in front of it (the user, 2026-11-25: "whenever
    /// another building sits in front of it, it doesn't block the window"): drawn above the night's
    /// shade, a pane showed through a house, a tree or a wall nearer you. Once, after everything is
    /// set down: each pane pixel under an opaque pixel of something sorted in front of its building
    /// is cleared; a pane hidden whole is taken away, and a glow dimmed by how much of its pane is left.
    private func hidePanesBehindScenery() {
        defer {
            litPanes = []
            occluders = []
        }
        guard !litPanes.isEmpty else { return }
        var cache: [ObjectIdentifier: (w: Int, h: Int, bytes: [UInt8])] = [:]
        func pixels(_ image: CGImage) -> (w: Int, h: Int, bytes: [UInt8])? {
            let key = ObjectIdentifier(image)
            if let known = cache[key] { return known }
            guard image.width > 0, image.height > 0,
                  let bytes = PixelImage.pixels(of: image, width: image.width, height: image.height) else { return nil }
            let made = (w: image.width, h: image.height, bytes: bytes)
            cache[key] = made
            return made
        }
        // Whether `o` has an opaque pixel at `point` (in the land's points). Only upright, unscaled ones.
        func covers(_ o: Occluder, _ point: CGPoint) -> Bool {
            let n = o.node
            guard n.xScale == 1, n.yScale == 1, n.size.width > 0, n.size.height > 0 else { return false }
            let u = (point.x - n.position.x) / n.size.width + n.anchorPoint.x
            let v = (point.y - n.position.y) / n.size.height + n.anchorPoint.y
            guard u >= 0, u < 1, v >= 0, v < 1, let px = pixels(o.picture) else { return false }
            let x = Int(u * CGFloat(px.w)), y = Int((1 - v) * CGFloat(px.h))
            guard x >= 0, x < px.w, y >= 0, y < px.h else { return false }
            return px.bytes[(y * px.w + x) * 4 + 3] > 127
        }
        var gone: Set<ObjectIdentifier> = []
        for lit in litPanes {
            let building = lit.building
            guard building.xScale == 1, building.yScale == 1 else { continue }
            func land(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
                CGPoint(x: building.position.x + lit.left + px * lit.sx, y: building.position.y + lit.bottom + (lit.height - py) * lit.sy)
            }
            let a = land(lit.box.minX, lit.box.minY), b = land(lit.box.maxX, lit.box.maxY)
            let area = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
            let front = occluders.filter {
                $0.node !== building && $0.node.zPosition > building.zPosition && $0.node.frame.intersects(area)
            }
            guard !front.isEmpty, let own = pixels(lit.picture) else { continue }
            let x0 = Int(lit.box.minX), y0 = Int(lit.box.minY)
            let cols = Int(lit.box.width), rows = Int(lit.box.height)
            guard cols > 0, rows > 0 else { continue }
            var out = [UInt8](repeating: 0, count: cols * rows * 4)
            var shown = 0, total = 0
            for j in 0..<rows {
                for i in 0..<cols {
                    let sx = x0 + i, sy = y0 + j
                    guard sx >= 0, sx < own.w, sy >= 0, sy < own.h else { continue }
                    let source = (sy * own.w + sx) * 4
                    guard own.bytes[source + 3] > 0 else { continue }
                    total += 1
                    let at = land(CGFloat(sx) + 0.5, CGFloat(sy) + 0.5)
                    if front.contains(where: { covers($0, at) }) { continue }
                    shown += 1
                    for c in 0..<4 { out[(j * cols + i) * 4 + c] = own.bytes[source + c] }
                }
            }
            guard shown < total else { continue }
            if shown == 0 {
                lit.pane.removeFromParent()
                lit.halo.removeFromParent()
                gone.insert(ObjectIdentifier(lit.pane))
                continue
            }
            guard let image = PixelImage.make(out, width: cols, height: rows) else { continue }
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = .nearest
            lit.pane.texture = texture
            lit.halo.alpha *= CGFloat(shown) / CGFloat(total)
        }
        if !gone.isEmpty { panes.removeAll { gone.contains(ObjectIdentifier($0.node)) } }
    }
    /// The windows of each windows picture, in its pixels from its top left: panes within two pixels
    /// of each other are one window.
    private var windowBoxCache: [String: [CGRect]] = [:]

    private func windowBoxes(of name: String, picture: CGImage) -> [CGRect] {
        if let known = windowBoxCache[name] { return known }
        let w = picture.width, h = picture.height
        var boxes: [CGRect] = []
        if let pixels = PixelImage.pixels(of: picture, width: w, height: h) {
            var seen = [Bool](repeating: false, count: w * h)
            for y0 in 0..<h {
                for x0 in 0..<w where pixels[(y0 * w + x0) * 4 + 3] > 0 && !seen[y0 * w + x0] {
                    var stack = [(x: x0, y: y0)]
                    seen[y0 * w + x0] = true
                    var minX = x0, maxX = x0, minY = y0, maxY = y0
                    while let spot = stack.popLast() {
                        minX = min(minX, spot.x); maxX = max(maxX, spot.x)
                        minY = min(minY, spot.y); maxY = max(maxY, spot.y)
                        for dy in -2...2 {
                            for dx in -2...2 {
                                let nx = spot.x + dx, ny = spot.y + dy
                                guard nx >= 0, ny >= 0, nx < w, ny < h, !seen[ny * w + nx], pixels[(ny * w + nx) * 4 + 3] > 0 else { continue }
                                seen[ny * w + nx] = true
                                stack.append((x: nx, y: ny))
                            }
                        }
                    }
                    boxes.append(CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
                }
            }
        }
        windowBoxCache[name] = boxes
        return boxes
    }

    /// Puts out the lit windows someone stands in front of (lower on the screen than the building's
    /// foot, their body over the pane), and lights them again once they've moved on. A few times a
    /// second, and only by night.
    private func coverPanes(_ dt: TimeInterval) {
        guard !panes.isEmpty, LampLight.shared.isNight else { return }
        paneTimer -= dt
        guard paneTimer <= 0 else { return }
        paneTimer = 0.12
        let people = Walker.standing(in: world)
        for pane in panes where pane.node.scene != nil {
            let covered = people.contains { at in
                at.y < pane.foot + 2 && CGRect(x: at.x - 13, y: at.y, width: 26, height: 54).intersects(pane.box)
            }
            // Faded, not put out at once (the user, 2026-11-25: it "turns off immediately, which looks
            // weird"), its glow left shining round it.
            let alpha: CGFloat = covered ? 0 : 1
            if pane.node.action(forKey: Self.coverKey) == nil, pane.node.alpha != alpha {
                pane.node.run(.fadeAlpha(to: alpha, duration: 0.3), withKey: Self.coverKey)
            }
        }
    }

    /// A building's fire moving (`tools/fire_art.py`, the user, 2026-11-17: a forge's fire stood
    /// still): its flame's frames, cut from its own picture at its own size, laid over it and played on
    /// a loop, each building from a moment of its own so they don't flicker in step.
    private func addFire(to node: SKSpriteNode, art id: String) {
        let names = (0..<4).map { "fire_\(id)_\($0)" }
        guard names.allSatisfy({ art.asset($0) != nil }) else { return }
        let frames = names.map { art.sprite($0).texture }
        let flame = SKSpriteNode(texture: frames[0], size: node.size)
        flame.anchorPoint = node.anchorPoint
        flame.zPosition = 0.01
        node.addChild(flame)
        let start = TimeInterval.random(in: 0...0.33)
        flame.run(.sequence([.wait(forDuration: start), .repeatForever(.animate(with: frames, timePerFrame: 0.11))]))
        // By night it burns as bright as by day, and glows: the same flame again above the night's
        // shade, as lit windows are (`addWindows`), put out while someone stands in front of it.
        let lit = SKSpriteNode(color: .clear, size: .zero)
        lit.zPosition = 43_100 - node.zPosition
        node.addChild(lit)
        LampLight.shared.follow(lit)
        let bright = SKSpriteNode(texture: frames[0], size: node.size)
        bright.anchorPoint = node.anchorPoint
        lit.addChild(bright)
        bright.run(.sequence([.wait(forDuration: start), .repeatForever(.animate(with: frames, timePerFrame: 0.11))]))
        let halo = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: node.size.width * 0.9, height: node.size.height * 0.7))
        halo.position = CGPoint(x: (0.5 - node.anchorPoint.x) * node.size.width, y: (0.3 - node.anchorPoint.y) * node.size.height)
        halo.color = UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.4
        halo.zPosition = -0.01
        lit.addChild(halo)
        halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.5), .fadeAlpha(to: 0.45, duration: 0.4)])))
        // Put out for someone in front only where its flame is (the user, 2026-11-25: the whole
        // building's frame put the forge's fire out while its healer stood anywhere before it).
        var frame = CGRect(x: node.position.x - node.anchorPoint.x * node.size.width, y: node.position.y - node.anchorPoint.y * node.size.height,
                           width: node.size.width, height: node.size.height)
        if let flame = Self.opaqueBounds(art.picture(of: frames[0])) {
            frame = CGRect(x: frame.minX + flame.minX * node.size.width, y: frame.maxY - flame.maxY * node.size.height,
                           width: flame.width * node.size.width, height: flame.height * node.size.height)
        }
        panes.append(Pane(node: bright, box: frame, foot: node.position.y))
    }

    /// Where a picture's opaque pixels lie, as fractions of it from its top left; nil if it has none.
    private static func opaqueBounds(_ image: CGImage) -> CGRect? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let pixels = PixelImage.pixels(of: image, width: w, height: h) else { return nil }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: CGFloat(minX) / CGFloat(w), y: CGFloat(minY) / CGFloat(h),
                      width: CGFloat(maxX - minX + 1) / CGFloat(w), height: CGFloat(maxY - minY + 1) / CGFloat(h))
    }

    /// The lighthouse's light turning at night (the user, 2026-11-22: "make everything feel more
    /// alive"): a glow in its lamp room and a long soft beam swinging round from it, out to the
    /// right, gone as it turns toward you or away, out to the left and back, a turn every six
    /// seconds; above the night's shade and faded in with the dark, as lit windows are.
    private func addBeam(to node: SKSpriteNode) {
        // The lamp room's middle, in the picture's pixels from its top left (96 across).
        let lamp = CGPoint(x: 49.0 / 96, y: 33.5 / 96)
        let light = SKSpriteNode(color: .clear, size: .zero)
        light.position = CGPoint(x: (lamp.x - node.anchorPoint.x) * node.size.width,
                                 y: (1 - lamp.y - node.anchorPoint.y) * node.size.height)
        light.zPosition = 43_100 - node.zPosition
        node.addChild(light)
        LampLight.shared.follow(light)
        let warm = UIColor(red: 1, green: 0.93, blue: 0.72, alpha: 1)
        let halo = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: 56, height: 30))
        halo.color = warm
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.7
        light.addChild(halo)
        // A soft glow stretched long, brightest a little out from the lamp.
        let beam = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: 320, height: 26))
        beam.anchorPoint = CGPoint(x: 0.18, y: 0.5)
        beam.color = warm
        beam.colorBlendFactor = 1
        beam.blendMode = .add
        light.addChild(beam)
        let turn: TimeInterval = 6
        let start = Double.random(in: 0..<1)
        beam.run(.repeatForever(.customAction(withDuration: turn) { beam, elapsed in
            let angle = 2 * Double.pi * (start + Double(elapsed) / turn)
            // Seen from the side: as long as it reaches out across the screen, brighter swinging
            // toward you than away.
            beam.xScale = CGFloat(cos(angle))
            beam.alpha = CGFloat(0.32 + 0.16 * sin(angle))
        }))
        halo.run(.repeatForever(.customAction(withDuration: turn) { halo, elapsed in
            let angle = 2 * Double.pi * (start + Double(elapsed) / turn)
            halo.alpha = CGFloat(0.55 + 0.35 * max(0, sin(angle)))
        }))
    }

    /// What's a light itself, wherever the plan set it down: the street lamp, and every art some land's
    /// props give a glow to. A rest's lamp, a lair's lanterns, a roadside row or a story's decor carry
    /// no glow of their own (`Placement.prop`), and lit by the lamps round them (`LampLight`) a lantern
    /// turned into a pale copy of itself (playtesting 2026-11-21, Starfall Isle's moon lanterns).
    private lazy var lights: Set<String> = {
        var lights: Set<String> = ["street_lamp"]
        for land in Content.shared.maps {
            for prop in land.theme.props where prop.glow != nil { lights.insert(prop.art) }
        }
        return lights
    }()

    /// Its lights at night (`LampLight`): its town's street lamps, where their glow is, and its props
    /// that glow (lanterns, crystals, glowing mushrooms), in their glow's colour.
    private lazy var lamps: [LampLight.Lamp] = {
        var lamps: [LampLight.Lamp] = []
        for decor in plan.streetDecor where decor.art == "street_lamp" {
            lamps.append(LampLight.Lamp(point: map.center(of: decor.cell) + CGVector(dx: 0, dy: 34), color: (r: 1, g: 0.85, b: 0.5)))
        }
        for prop in plan.props + plan.decor + plan.localProps {
            guard let hex = prop.prop?.glow, let color = Lighting.rgb(hex) else { continue }
            lamps.append(LampLight.Lamp(point: map.center(of: prop.cell) + CGVector(dx: 0, dy: 16), color: color))
        }
        return lamps
    }()

    /// As `WorldScene.addScenery`: on its cell, nudged, up on the ground there, shaded on a hill's
    /// shaded side (by the midday sun, for now), moving in the wind if it's a tree or bush with a rig
    /// (`wind`, its art: `WindField`), else swaying if asked.
    @discardableResult
    private func addScenery(_ sprite: SpriteArt, at cell: GridPoint, nudge: CGVector? = nil, sway: Placement.Sway? = nil, scale: CGFloat = 1,
                            wind: String? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(texture: sprite.texture, size: CGSize(width: sprite.size.width * scale, height: sprite.size.height * scale))
        node.anchorPoint = CGPoint(x: 0.5, y: min(0.5, 0.05 + foot(of: sprite.texture)))
        var position = map.base(of: cell)
        if let nudge {
            position.x += nudge.dx
            position.y += nudge.dy
        }
        let ground = position.y
        position.y += map.height(at: map.center(of: cell))
        node.position = position
        node.zPosition = -ground
        shade(node, standingOn: cell)
        if let wind, let frames = art.windFrames(wind, texture: sprite.texture) {
            // Timed by where it stands on the continent, so the wind runs on across the border.
            WindField.shared.add(node, frames: frames, at: CGPoint(x: position.x + shift.dx, y: position.y + shift.dy), land: world)
        } else if let sway {
            let left = SKAction.rotate(toAngle: sway.lean, duration: sway.duration, shortestUnitArc: true)
            let right = SKAction.rotate(toAngle: -sway.lean, duration: sway.duration, shortestUnitArc: true)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            node.zRotation = sway.start
            node.run(.repeatForever(.sequence([left, right])))
        }
        chunk(at: node.position).addChild(node)
        see.note(node)
        occluders.append(Occluder(node: node, picture: art.picture(of: sprite.texture)))
        // Everything set down on flat ground casts shade, merged and cast away from the sun (on a hill
        // or the sunk shore, a prop with `shadow` keeps its round one: `plant`).
        if map.hillIndex(at: cell) == nil, !map.isSunken(cell) {
            // A building's walls cast it, not a crown's rounds (`CanopyPainter.Caster.walls`).
            canopy.add(node, picture: art.picture(of: sprite.texture),
                       walls: wind.flatMap { art.asset($0)?.kind } == "building" || wind.map(CanopyShade.isRock) == true,
                       flatBase: wind.map { CanopyShade.flatBases.contains($0) } ?? false)
        }
        return node
    }

    /// Darkens scenery on a hill's shaded side with the ground there, as `WorldScene.shade` does, by
    /// the midday sun.
    private func shade(_ node: SKSpriteNode, standingOn cell: GridPoint) {
        guard let index = map.hillIndex(at: cell) else { return }
        let hill = map.hills[index]
        let x = Double(cell.col) + 0.5, y = Double(cell.row) + 0.5, e = 0.25
        let gx = Double(hill.height(atCells: x + e, y) - hill.height(atCells: x - e, y)) / (2 * e)
        let gy = Double(hill.height(atCells: x, y + e) - hill.height(atCells: x, y - e)) / (2 * e)
        let tile = Double(WorldMap.tileSize)
        let ambient = hill.isCrag || hill.hasMountain ? HillLooks.cragShade : HillArt.ambient(rocky: map.rockiness)
        let light = HillArt.sunlight(hx: gx / tile / 0.866, hy: gy / tile / 0.866, ambient: ambient, sun: .noon)
        guard light.shade < 1 else { return }
        let shadowed = min(1, max(0, (0.15 - light.lambert) / 0.15))
        node.color = .black
        node.colorBlendFactor = CGFloat((1 - light.shade) * (0.6 + 0.4 * shadowed))
    }

    /// How far up its picture a sprite's lowest opaque pixel sits (0...1), so scenery drawn with
    /// empty rows under it stands on its cell (`WorldScene.foot(of:)`).
    private func foot(of texture: SKTexture) -> CGFloat {
        let key = ObjectIdentifier(texture)
        if let known = feet[key] { return known }
        let image = art.picture(of: texture)
        let width = image.width, height = image.height
        var foot: CGFloat = 0
        if width > 0, height > 0,
           let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let data = context.data {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
            // The bitmap's rows run top to bottom, so search up from the last one.
            search: for row in stride(from: height - 1, through: 0, by: -1) {
                for col in 0..<width where pixels[(row * width + col) * 4 + 3] > 127 {
                    foot = CGFloat(height - 1 - row) / CGFloat(height)
                    break search
                }
            }
        }
        feet[key] = foot
        return foot
    }

    /// How deep something lying flat on the ground at `point` sorts, in the land's own depth: on a
    /// hill just over the strip of raised ground it lies on, on the shore over the sunk ground
    /// (`WorldScene.flatZ`); nil elsewhere, where it lies on the ground under everything.
    private func flatZ(at point: CGPoint) -> CGFloat? {
        let cell = map.cell(at: point)
        if map.hillIndex(at: cell) != nil { return HillArt.strip(at: point.y).z + 0.2 }
        if map.isSunken(cell) { return HillArt.strip(at: point.y, depth: HillArt.sunkenDepth).z + 0.2 }
        return nil
    }


    // MARK: What it sets down

    /// The water's pale line where it meets something sitting in it (`rim_<art>`, `tools/float_art.py`): a
    /// sprite the same size and anchor as it, nil if the art has none.
    private func waterline(for id: String, size: CGSize, anchor: CGPoint) -> SKSpriteNode? {
        guard art.asset("rim_" + id) != nil else { return nil }
        let line = SKSpriteNode(texture: art.sprite("rim_" + id).texture, size: size)
        line.anchorPoint = anchor
        return line
    }

    /// Petals, blossoms and leaves floating on the water (`LandPlan.planFloaters`; the user, 2026-11-25,
    /// after ZeFrost's pond): each bobbing a whole pixel down and up again, slowly and in its own time,
    /// over the water's pale line round it, which stays put, so it rides on the water.
    private func placeFloaters(_ floaters: [(cell: GridPoint, drift: CGVector, art: String)]) {
        for floater in floaters {
            let sprite = art.sprite(floater.art)
            let spot = map.center(of: floater.cell) + floater.drift
            let at = CGPoint(x: spot.x.rounded(), y: (spot.y + map.height(at: spot)).rounded())
            let holder = SKNode()
            holder.position = at
            if let line = waterline(for: floater.art, size: sprite.size, anchor: CGPoint(x: 0.5, y: 0.5)) { holder.addChild(line) }
            let node = SKSpriteNode(texture: sprite.texture, size: sprite.size)
            node.zPosition = 0.01
            holder.addChild(node)
            let rise = TimeInterval.random(in: 2.2...3.2), fall = TimeInterval.random(in: 1.8...2.6)
            node.run(.sequence([.wait(forDuration: .random(in: 0...5)), .repeatForever(.sequence([
                .moveBy(x: 0, y: -PondMotion.pixel, duration: 0), .wait(forDuration: fall),
                .moveBy(x: 0, y: PondMotion.pixel, duration: 0), .wait(forDuration: rise),
            ]))]))
            if map.isSunken(floater.cell), let z = flatZ(at: spot) {
                holder.zPosition = z
                chunk(at: holder.position).addChild(holder)
            } else {
                holder.zPosition = -99_000
                layer(at: holder.position).addChild(holder)
            }
        }
    }

    private func placeLilyPads(_ pads: [(cell: GridPoint, drift: CGVector)]) {
        guard !pads.isEmpty else { return }
        let sprite = art.sprite("lily_pad")
        for (cell, drift) in pads {
            let node = SKSpriteNode(texture: sprite.texture, size: sprite.size)
            let spot = map.center(of: cell) + drift
            // On a lake sunk with the shore, down on its water.
            node.position = CGPoint(x: spot.x, y: spot.y + map.height(at: spot))
            // The water's pale line round it, staying put as it bobs and turns (the user, 2026-11-25).
            let line = waterline(for: "lily_pad", size: sprite.size, anchor: node.anchorPoint)
            line?.position = node.position
            node.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.08, duration: 2.2, shortestUnitArc: true),
                .rotate(toAngle: -0.08, duration: 2.2, shortestUnitArc: true),
            ])))
            // Bobbing a whole pixel down and up again, each in its own time (the pond water article's:
            // down while sin(t + 1.7k) > 0.4, about three eighths of a 5-second turn).
            node.run(.sequence([.wait(forDuration: .random(in: 0...5)), .repeatForever(.sequence([
                .moveBy(x: 0, y: -PondMotion.pixel, duration: 0), .wait(forDuration: 1.85),
                .moveBy(x: 0, y: PondMotion.pixel, duration: 0), .wait(forDuration: 3.15),
            ]))]))
            if map.isSunken(cell), let z = flatZ(at: spot) {
                node.zPosition = z
                chunk(at: node.position).addChild(node)
            } else {
                node.zPosition = -99_000
                layer(at: node.position).addChild(node)
            }
            if let line {
                line.zPosition = node.zPosition - 0.01
                node.parent?.addChild(line)
            }
        }
    }

    /// The water moving on the land's own lakes and rivers (`PondMotion`; not ice or chocolate): along the
    /// near and side shores (down the screen, south and west of the water) a light dash lapping a pixel in
    /// and out every 1.25 seconds, showing a while and gone a while; along the far shore (north and east)
    /// the waterline creeping a pixel up the bank now and then; and out on the open water, a chunk at a
    /// time, glints flickering (one every half second or so) and a drop rippling out every few seconds.
    /// Unseeded: the land's layout stays what it was.
    private func placePondMotion() {
        guard !Self.isOffForDebug("water") else { return }
        let water = def.theme.water ?? "tile_water"
        // Nothing laps, glints or rings on ice.
        guard ArtLibrary.isPondWater(water), def.theme.frozen != true else { return }
        // Chocolate's glints and rings in a creamy sheen, not the water's pale blue.
        let tint: UIColor? = water == "tile_water" ? nil : UIColor(red: 1, green: 0.86, blue: 0.7, alpha: 1)
        func make(_ texture: SKTexture) -> SKSpriteNode {
            let node = PondMotion.sprite(texture)
            if let tint {
                node.color = tint
                node.colorBlendFactor = 0.6
            }
            return node
        }
        var cells = map.river
        for lake in map.lakes { cells.formUnion(lake.water) }
        // The small ponds too (the user, 2026-11-25: "Lakes and ponds are too lifeless"): they had none.
        for pond in map.ponds { cells.formUnion(pond) }
        guard !cells.isEmpty else { return }
        let tile = WorldMap.tileSize
        var open: [GridPoint: [(point: CGPoint, cell: GridPoint, shore: Bool)]] = [:]
        for cell in cells.sorted(by: WorldMap.inOrder) where !map.bridgeCells.contains(cell) {
            var shore = false
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let next = GridPoint(col: cell.col + dc, row: cell.row + dr)
                guard map.contains(next), !cells.contains(next) else { continue }
                let ground = map.ground[next.row][next.col]
                guard ground != .water, ground != .sea, ground != .away else { continue }
                shore = true
                // Up the screen is north and east at once: a shore that way is the far bank.
                let far = dc + dr > 0
                guard Double.random(in: 0..<1) < (far ? 0.4 : 0.6) else { continue }
                // Along the edge, toward the land: the near shore's dashes two or three pixels out on
                // the water, the far shore's creep at the waterline.
                let along = Double.random(in: -0.3...0.3), inset = far ? 0.47 : 0.36
                let offset = CGPoint(x: (Double(dc) * inset - Double(dr) * along) * tile, y: (Double(dr) * inset + Double(dc) * along) * tile)
                let point = map.center(of: cell) + CGVector(dx: WorldMap.project(offset).x, dy: WorldMap.project(offset).y)
                if far {
                    let node = make(PondMotion.creep)
                    node.alpha = 0
                    node.run(.sequence([.wait(forDuration: .random(in: 0...6)), .repeatForever(.sequence([
                        .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 2.5, withRange: 2),
                        .fadeAlpha(to: 0, duration: 0), .wait(forDuration: 4, withRange: 4),
                    ]))]))
                    onWater(node, at: point, cell: cell)
                } else {
                    // A pixel out toward the open water and back, as the ring of dashes steps out and in.
                    let toward = WorldMap.project(CGPoint(x: -Double(dc), y: -Double(dr)))
                    let length = max(0.001, (toward.x * toward.x + toward.y * toward.y).squareRoot())
                    let step = CGVector(dx: (toward.x / length * PondMotion.pixel).rounded(), dy: (toward.y / length * PondMotion.pixel).rounded())
                    let node = make(PondMotion.lap)
                    node.alpha = 0
                    node.run(.repeatForever(.sequence([
                        .wait(forDuration: 1.25), .moveBy(x: step.dx, y: step.dy, duration: 0),
                        .wait(forDuration: 1.25), .moveBy(x: -step.dx, y: -step.dy, duration: 0),
                    ])))
                    node.run(.sequence([.wait(forDuration: .random(in: 0...5)), .repeatForever(.sequence([
                        .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 1.5, withRange: 1.5),
                        .fadeAlpha(to: 0, duration: 0), .wait(forDuration: 2, withRange: 2),
                    ]))]))
                    onWater(node, at: point, cell: cell)
                }
            }
            // Down on the water, with its height, for the glints, drops and rings set round it: every
            // cell of it, a shore's kept nearer its middle (only open water's, a pond or a narrow river
            // had none, and no rain fell on it).
            let point = map.center(of: cell)
            open[Self.key(point.x, point.y), default: []].append((CGPoint(x: point.x, y: point.y + map.height(at: point)), cell, shore))
        }
        // Glints and drops, a spawner for each chunk of open water.
        for spots in open.values {
            guard let first = spots.first else { continue }
            let spawner = SKNode()
            onWater(spawner, at: map.center(of: first.cell), cell: first.cell)
            let base = spawner.position
            let places = spots.map { (point: $0.point, reach: $0.shore ? 0.22 : 0.4) }
            let spot: () -> CGPoint = {
                let pick = places[Int.random(in: 0..<places.count)]
                let jitter = WorldMap.project(CGPoint(x: Double.random(in: -pick.reach...pick.reach) * tile,
                                                      y: Double.random(in: -pick.reach...pick.reach) * tile))
                return CGPoint(x: (pick.point.x + jitter.x - base.x).rounded(), y: (pick.point.y + jitter.y - base.y).rounded())
            }
            let glint = SKAction.run { [weak spawner] in
                guard let spawner else { return }
                let node = make(PondMotion.glint[0].texture)
                node.position = spot()
                spawner.addChild(node)
                var steps: [SKAction] = []
                for frame in PondMotion.glint {
                    steps.append(.setTexture(frame.texture))
                    steps.append(.wait(forDuration: frame.time))
                }
                steps.append(.removeFromParent())
                node.run(.sequence(steps))
            }
            let drop = SKAction.run { [weak spawner] in
                guard let spawner, let first = PondMotion.ripple.first else { return }
                let node = make(first)
                node.position = spot()
                spawner.addChild(node)
                node.run(.sequence([.animate(with: PondMotion.ripple, timePerFrame: 0.2), .removeFromParent()]))
            }
            // As lively over a big lake as a small pond: as often for every ten cells of it.
            let busy = max(1, Double(spots.count) / 10)
            // A wavelet drifting across: a light dash, two pixels downwind in steps, then gone.
            let drift = SKAction.run { [weak spawner] in
                guard let spawner else { return }
                let node = make(PondMotion.lap)
                node.position = spot()
                node.alpha = 0.8
                spawner.addChild(node)
                let step = PondMotion.pixel.rounded()
                node.run(.sequence([.wait(forDuration: 0.6), .moveBy(x: step, y: 0, duration: 0), .wait(forDuration: 0.6),
                                    .moveBy(x: step, y: 0, duration: 0), .fadeAlpha(to: 0.45, duration: 0), .wait(forDuration: 0.5),
                                    .removeFromParent()]))
            }
            spawner.run(.repeatForever(.sequence([.wait(forDuration: 0.55 / busy, withRange: 0.6 / busy), glint])))
            spawner.run(.repeatForever(.sequence([.wait(forDuration: 3.5 / busy, withRange: 3 / busy), drop])))
            spawner.run(.repeatForever(.sequence([.wait(forDuration: 0.9 / busy, withRange: 0.8 / busy), drift])))
            // In the rain, drops ring the water many times a second (the user, 2026-11-18).
            let rain = SKAction.run { [weak spawner] in
                guard let spawner, PondMotion.raining, let first = PondMotion.rainRipple.first else { return }
                let node = make(first)
                node.position = spot()
                spawner.addChild(node)
                node.run(.sequence([.animate(with: PondMotion.rainRipple, timePerFrame: 0.12), .removeFromParent()]))
            }
            spawner.run(.repeatForever(.sequence([.wait(forDuration: max(0.03, 0.22 / busy), withRange: max(0.03, 0.25 / busy)), rain])))
        }
    }

    /// How many reflections a land lays (`reflect`): a lake's banks are lined with trees, and each one
    /// has a shader and a mask of its own.
    private static let reflectionsAtMost = 160
    private var reflections = 0

    /// What stands just above the water on screen mirrored in it (after SpriteCook's pond water article,
    /// its reflections; the user, 2026-11-17: "Start on the reflections"): its picture flipped about its
    /// foot and squashed to 0.55, in three of the pond's darkest tones by how bright each pixel is (the
    /// darkest 15% tone 0, below 110 tone 1, the rest 2), always a step darker than the water it lies on,
    /// only where it lies on the land's own water (`GroundTiles.pondTone`, baked in a mask), its rows
    /// shifted a whole pixel by a slow wave in four steps over 2.5 seconds (none in the first 3 rows over
    /// the foot, then one, two past 16), a third of the thing's own colour kept (the user, 2026-11-17: "a
    /// bit of the water color"). Painted into four pictures here: a shader did it, and on a phone it
    /// didn't take and the reflections lay over the land. Not what stands in the water.
    private func reflect(_ node: SKSpriteNode, picture texture: SKTexture, art id: String, cell: GridPoint) {
        guard !Self.isOffForDebug("water"), reflections < Self.reflectionsAtMost, !id.hasPrefix("waterfall"), id != "water_rock", id != "lily_pad",
              map.contains(cell), map.ground[cell.row][cell.col] != .water else { return }
        // Water down the screen from it (south and west) within reach of its reflection.
        var nearWater = false
        for dc in 0...3 where !nearWater {
            for dr in 0...3 where dc + dr > 0 {
                let below = GridPoint(col: cell.col - dc, row: cell.row - dr)
                if map.contains(below), map.ground[below.row][below.col] == .water { nearWater = true; break }
            }
        }
        guard nearWater, tiles.pondColours.count >= 3 else { return }
        let image = art.picture(of: texture)
        let width = image.width, height = image.height
        guard width > 0, height > 0, let pixels = PixelImage.pixels(of: image, width: width, height: height) else { return }
        // Its lowest opaque row, from the top.
        var footRow = -1
        search: for row in stride(from: height - 1, through: 0, by: -1) {
            for col in 0..<width where pixels[(row * width + col) * 4 + 3] > 127 {
                footRow = row
                break search
            }
        }
        guard footRow > 0 else { return }
        let pixelWidth = node.size.width / CGFloat(width), pixelHeight = node.size.height / CGFloat(height)
        let footY = node.position.y - node.anchorPoint.y * node.size.height + CGFloat(height - 1 - footRow) * pixelHeight
        let left = node.position.x - node.anchorPoint.x * node.size.width
        // Where each of its pixels falls in the water, mirrored: the water's tone there (as 32 a step in
        // red), or clear where it isn't water. The water lies down the screen by its depth on a sunk
        // lake: found again from where the ground there lies.
        var mask = [UInt8](repeating: 0, count: width * height * 4)
        var lowest: CGPoint?
        let tile = Double(WorldMap.tileSize)
        for row in 0...footRow {
            let y = footY - (CGFloat(footRow - row) + 0.5) * pixelHeight * Self.squash
            for col in 0..<width {
                let x = left + (CGFloat(col) + 0.5) * pixelWidth
                var grid = WorldMap.unproject(CGPoint(x: x, y: y))
                for _ in 0..<2 {
                    let depth = map.height(at: WorldMap.project(grid))
                    grid = WorldMap.unproject(CGPoint(x: x, y: y - depth))
                }
                guard let tone = tiles.pondTone(atCells: Double(grid.x) / tile, Double(grid.y) / tile) else { continue }
                let o = (row * width + col) * 4
                mask[o] = UInt8(min(7, tone) * 32)
                mask[o + 3] = 255
                if lowest == nil || y < (lowest?.y ?? 0) { lowest = CGPoint(x: x, y: y) }
            }
        }
        guard let lowest else { return }
        // Its brightness's darkest 15%, the cut to its darkest tone.
        var bright: [Double] = []
        for i in stride(from: 0, to: width * height * 4, by: 4) where pixels[i + 3] > 127 {
            bright.append(0.3 * Double(pixels[i]) + 0.59 * Double(pixels[i + 1]) + 0.11 * Double(pixels[i + 2]))
        }
        bright.sort()
        let darkCut = bright.isEmpty ? 0 : bright[bright.count * 15 / 100]
        // Painted here, a picture for each of the wave's four steps, not by a shader on the device:
        // the shader didn't take on a phone, and every reflection showed whole, over the land as
        // well as the water (the user, 2026-11-17: "There are tree reflections that go on on the
        // land"). Each pixel the mask clears stays clear, whatever the GPU does.
        let colours = tiles.pondColours
        let tones = (0..<3).map { k in (r: colours[k].r * 255, g: colours[k].g * 255, b: colours[k].b * 255) }
        var steps: [SKTexture] = []
        for step in 0..<4 {
            let turn = Double(step) * Double.pi / 2
            var out = [UInt8](repeating: 0, count: width * height * 4)
            for row in 0...footRow {
                // How far above its foot this row of the picture is, and how far the wave moves it.
                let down = Double(footRow - row) + 0.5
                let reach = (down >= 3 ? 1.0 : 0) + (down >= 16 ? 1.0 : 0)
                let aside = Int((reach * sin(down * 1.36 - turn) + 0.5).rounded(.down))
                for col in 0..<width {
                    let o = (row * width + col) * 4
                    guard mask[o + 3] > 127 else { continue }
                    let from = min(width - 1, max(0, col - aside))
                    let p = (row * width + from) * 4
                    let alpha = Double(pixels[p + 3])
                    guard alpha > 127 else { continue }
                    let red = Double(pixels[p]) * 255 / alpha, green = Double(pixels[p + 1]) * 255 / alpha
                    let blue = Double(pixels[p + 2]) * 255 / alpha
                    let lum = 0.3 * red + 0.59 * green + 0.11 * blue
                    let band = (lum >= darkCut ? 1 : 0) + (lum >= 110 ? 1 : 0)
                    let shade = max(0, min(Int(mask[o]) / 32 - 1, band))
                    let tone = tones[shade]
                    out[o] = UInt8(min(255, max(0, red * 0.32 + tone.r * 0.68)))
                    out[o + 1] = UInt8(min(255, max(0, green * 0.32 + tone.g * 0.68)))
                    out[o + 2] = UInt8(min(255, max(0, blue * 0.32 + tone.b * 0.68)))
                    out[o + 3] = 255
                }
            }
            guard let picture = PixelImage.make(out, width: width, height: height) else { return }
            let texture = SKTexture(cgImage: picture)
            texture.filteringMode = .nearest
            steps.append(texture)
        }
        reflections += 1
        // Its picture turned over about its foot and squashed, still as the tree stands (not moving
        // in the wind with it: a picture for every frame of the wind was too many), its rows rippling.
        let mirror = SKSpriteNode(texture: steps[0], size: node.size)
        mirror.anchorPoint = CGPoint(x: node.anchorPoint.x, y: CGFloat(height - 1 - footRow) / CGFloat(height))
        mirror.position = CGPoint(x: node.position.x, y: footY)
        mirror.yScale = -Self.squash
        mirror.run(.repeatForever(.animate(with: steps, timePerFrame: 0.625)))
        // Over the water it lies on: on a sunk lake, over its lowest strip of it.
        if let z = flatZ(at: lowest), map.isSunken(map.cell(at: lowest)) {
            mirror.zPosition = z - 0.1
            chunk(at: lowest).addChild(mirror)
        } else {
            mirror.zPosition = -99_020
            layer(at: mirror.position).addChild(mirror)
        }
    }

    /// How much shorter a reflection is than what it mirrors (the article's 0.55).
    private static let squash: CGFloat = 0.55

    /// Sets `node` down on the water at `point` (`cell`'s), as the lily pads are: down on a lake sunk with
    /// the shore, just under the pads.
    private func onWater(_ node: SKNode, at point: CGPoint, cell: GridPoint) {
        node.position = CGPoint(x: point.x.rounded(), y: (point.y + map.height(at: point)).rounded())
        if map.isSunken(cell), let z = flatZ(at: point) {
            node.zPosition = z - 0.05
            chunk(at: node.position).addChild(node)
        } else {
            node.zPosition = -99_010
            layer(at: node.position).addChild(node)
        }
    }

    /// The bridges' posts and rails (`BridgeArt`; their decks lie with the ground).
    private func placeBridges() {
        guard !map.bridges.isEmpty else { return }
        let pixels = art.picture(of: art.tileTexture(def.theme.ground)).width
        for bridge in map.bridges {
            BridgeArt.rails(for: bridge, pixels: pixels, palette: def.theme.palette, in: world) { [map] in map.height(at: $0) }
        }
    }

    /// How far across from its harbor's road its ship lies, up the screen from the pier (cells, its
    /// middle: past the pier's far side and a little water), and how far out along it.
    static let shipAcross: CGFloat = 2.9
    static let shipAlong: CGFloat = 4

    /// Its harbors (`WorldMap.harbors`): a pier of planks out over the sea, a little over the water
    /// (`WorldMap.pierHeight`) on posts, and a ship moored alongside, up the screen from it, rocking
    /// gently, its gangplank down to the pier. You walk aboard at the pier's end
    /// (`Region.Road.boarding`, `ContinentScene.checkCell`).
    private func placeHarbors() {
        let harbors = map.harbors
        guard !harbors.isEmpty else { return }
        let pixels = art.picture(of: art.tileTexture(def.theme.ground)).width
        let tile = WorldMap.tileSize
        for harbor in harbors {
            let road = harbor.road
            guard let pier = road.pier, let first = road.pierCell(along: 1, across: -1),
                  let last = road.pierCell(along: Region.Road.pierLength, across: -1) else { continue }
            let northward = pier == .north || pier == .south, outward = pier == .north || pier == .east
            let a = northward ? first.row : first.col, b = northward ? last.row : last.col
            let bridge = WorldMap.Bridge(kind: .jetty, northward: northward, lane: northward ? first.col : first.row, lanes: 3,
                                         start: min(a, b), end: max(a, b), landsAtStart: outward, landsAtEnd: !outward)
            // Its deck, under whoever walks it: under the lowest of them on the screen.
            var top: CGFloat = 0
            if let picture = BridgeArt.deckPicture(for: bridge, pixels: pixels, palette: def.theme.palette) {
                let texture = SKTexture(cgImage: picture.image)
                texture.filteringMode = .nearest
                let deck = SKSpriteNode(texture: texture, size: CGSize(width: picture.frame.width * tile, height: picture.frame.height * tile))
                deck.anchorPoint = .zero
                deck.position = CGPoint(x: picture.frame.minX * tile, y: picture.frame.minY * tile)
                let flat = ContinentScene.projected(deck)
                flat.position.y = WorldMap.pierHeight
                let frame = picture.frame
                top = [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                       CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY)]
                    .map { WorldMap.project(CGPoint(x: $0.x * tile, y: $0.y * tile)).y }.max() ?? 0
                flat.zPosition = -top - 1
                world.addChild(flat)
            }
            BridgeArt.rails(for: bridge, pixels: pixels, palette: def.theme.palette, in: world, railed: false) { _ in WorldMap.pierHeight }
            // The ship, behind the pier and all on it.
            let side = northward ? CGVector(dx: 1, dy: 0) : CGVector(dx: 0, dy: 1)
            let out = Self.step(pier)
            let middle = CGPoint(x: CGFloat(road.at.col) + 0.5 + out.dx * Self.shipAlong + side.dx * Self.shipAcross,
                                 y: CGFloat(road.at.row) + 0.5 + out.dy * Self.shipAlong + side.dy * Self.shipAcross)
            let sprite = art.sprite("ship")
            let ship = SKSpriteNode(texture: sprite.texture, size: sprite.size)
            // Drawn lying along the east; its mirror image lies along the north.
            if northward { ship.xScale = -1 }
            ship.position = WorldMap.project(CGPoint(x: middle.x * tile, y: middle.y * tile)) + CGVector(dx: 0, dy: -WorldMap.seaDrop)
            ship.zPosition = -top - 2
            let rise = SKAction.moveBy(x: 0, y: 1.5, duration: 1.9)
            rise.timingMode = .easeInEaseOut
            let lean = SKAction.rotate(byAngle: 0.012, duration: 2.6)
            lean.timingMode = .easeInEaseOut
            ship.run(.repeatForever(.sequence([rise, rise.reversed()])))
            ship.run(.repeatForever(.sequence([lean, lean.reversed(), lean.reversed(), lean])))
            world.addChild(ship)
            placeShipInWater(ship, picture: art.picture(of: sprite.texture), rise: rise)
        }
    }

    /// The ship's shadow on the sea and its reflection in it (the user, 2026-11-20: it sat on the
    /// water with neither): the reflection the ship flipped about its keel, squashed and in the
    /// sea's dark tones, bobbing against it; the shadow a soft dark oval along its hull, away from
    /// the sun. Both only over the sea's cells, so neither lies over the shore by its stern.
    private func placeShipInWater(_ ship: SKSpriteNode, picture: CGImage, rise: SKAction) {
        let width = picture.width, height = picture.height
        guard width > 0, height > 0, let pixels = PixelImage.pixels(of: picture, width: width, height: height) else { return }
        // Its keel: its lowest opaque row, from the top.
        var footRow = height - 1
        search: for row in stride(from: height - 1, through: 0, by: -1) {
            for col in 0..<width where pixels[(row * width + col) * 4 + 3] > 127 {
                footRow = row
                break search
            }
        }
        let tile = WorldMap.tileSize
        let up = CGFloat(height - 1 - footRow) / CGFloat(height)
        let foot = CGPoint(x: ship.position.x, y: ship.position.y + (up - ship.anchorPoint.y) * ship.size.height)
        // The sea's cells round it, as the ground shows them.
        let path = CGMutablePath()
        let middle = map.rawCell(at: CGPoint(x: ship.position.x, y: ship.position.y + WorldMap.seaDrop))
        for dr in -12...12 {
            for dc in -12...12 {
                let cell = GridPoint(col: middle.col + dc, row: middle.row + dr)
                guard !map.contains(cell) || map.ground[cell.row][cell.col] == .sea else { continue }
                let corners = [(0, 0), (1, 0), (1, 1), (0, 1)].map {
                    WorldMap.project(CGPoint(x: CGFloat(cell.col + $0.0) * tile, y: CGFloat(cell.row + $0.1) * tile))
                }
                path.addLines(between: corners)
                path.closeSubpath()
            }
        }
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white
        mask.strokeColor = .white
        mask.lineWidth = 1
        mask.position = CGPoint(x: 0, y: -WorldMap.seaDrop)
        let water = SKCropNode()
        water.maskNode = mask
        water.zPosition = ship.zPosition - 0.5
        // Its shadow, down the screen and a little right of its hull.
        let shadow = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: ship.size.width * 0.85, height: 26))
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.35
        shadow.position = CGPoint(x: foot.x + 8, y: foot.y + 2)
        water.addChild(shadow)
        // Its reflection, flipped about its keel.
        let mirror = SKSpriteNode(texture: ship.texture, size: ship.size)
        mirror.anchorPoint = CGPoint(x: 0.5, y: up)
        mirror.position = foot
        mirror.xScale = ship.xScale
        mirror.yScale = -0.55
        mirror.color = UIColor(red: 0.04, green: 0.16, blue: 0.28, alpha: 1)
        mirror.colorBlendFactor = 0.8
        mirror.alpha = 0.45
        mirror.run(.repeatForever(.sequence([rise.reversed(), rise])))
        water.addChild(mirror)
        world.addChild(water)
    }

    /// A step the way `edge` faces, in cells.
    private static func step(_ edge: Edge) -> CGVector {
        switch edge {
        case .east: CGVector(dx: 1, dy: 0)
        case .west: CGVector(dx: -1, dy: 0)
        case .north: CGVector(dx: 0, dy: 1)
        case .south: CGVector(dx: 0, dy: -1)
        }
    }

    private func placeFence() {
        guard !map.fenceCells.isEmpty else { return }
        let before = Set(world.children.map { ObjectIdentifier($0) })
        let stone = def.town?.walls == "stone"
        let placed = TownFence.place(cells: map.fenceCells, map: map, world: world, art: art, stone: stone)
        // A city's stone walls and towers stand tall enough to hide someone too.
        for case let node as SKSpriteNode in world.children where !before.contains(ObjectIdentifier(node)) { see.note(node) }
        // Their shade on the ground away from the sun, as everything's is (the user, 2026-11-18: "The
        // walls also need shadows cast in the floor depending on the light. Same with the gates"): a
        // stone wall as rounds a few points apart all along its line, from each cell's middle to the
        // next one's, its height up; its towers by their outline; every gate (a village's too) by its
        // arch's, laid as bands as a building's are.
        if stone {
            let fence = Set(map.fenceCells)
            var feet: [CGPoint] = []
            for cell in map.fenceCells {
                let middle = map.center(of: cell)
                feet.append(middle)
                for next in [GridPoint(col: cell.col + 1, row: cell.row), GridPoint(col: cell.col, row: cell.row + 1)] where fence.contains(next) {
                    let far = map.center(of: next)
                    for k in 1..<4 {
                        let t = CGFloat(k) / 4
                        feet.append(CGPoint(x: middle.x + (far.x - middle.x) * t, y: middle.y + (far.y - middle.y) * t))
                    }
                }
            }
            canopy.addBlock(feet: feet, height: BorderArt.wallHeight - 6, half: 5, throughWalls: true)
            for tower in placed.towers {
                guard let texture = tower.texture else { continue }
                canopy.add(tower, picture: art.picture(of: texture), throughWalls: true)
            }
        }
        for gate in placed.gates {
            guard let texture = gate.texture else { continue }
            canopy.add(gate, picture: texture.cgImage(), walls: true, throughWalls: true, thin: true)
        }
    }

    /// The picket fences and low walls along stretches of its roads (`LandPlanner.planRoadsides`),
    /// joined from cell to cell as a town's fence is, each piece in the chunk it stands in.
    private func placeRoadsides() {
        TownFence.placeRoadsides(plan.roadsides, map: map, art: art) { node in
            self.chunk(at: node.position).addChild(node)
            if let sprite = node as? SKSpriteNode { self.see.note(sprite) }
        }
    }

    /// Houses, the street's lamps (glowing) and decor, the terraces' railings, and the land's own
    /// buildings.
    private func placeBuildings() {
        for lot in plan.lots { addScenery(lot) }
        for decor in plan.streetDecor {
            let lamp = addScenery(decor)
            guard decor.art == "street_lamp" else { continue }
            let glow = SKSpriteNode(texture: SoftTextures.glow, size: CGSize(width: 70, height: 50))
            glow.color = UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.35
            glow.position = map.center(of: decor.cell) + CGVector(dx: 0, dy: 34)
            // Just behind the lamp: whoever stands in front hides the glow, whoever is behind is lit.
            glow.zPosition = lamp.zPosition - 0.5
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 1.4), .fadeAlpha(to: 0.3, duration: 1.4)])))
            chunk(at: glow.position).addChild(glow)
        }
        placeTerraces()
        for building in plan.buildings { addScenery(building) }
    }

    /// A terrace's stairs: how many steps, and their sandstone where the walls' own can't be read
    /// (`meanColour` of the land's graded walls and paving is used).
    static let stairSteps = 6
    static let stairTread = UIColor(red: 0.9, green: 0.79, blue: 0.6, alpha: 1)
    static let stairTreadAlt = UIColor(red: 0.94, green: 0.83, blue: 0.64, alpha: 1)
    static let stairLitRiser = UIColor(red: 0.8, green: 0.66, blue: 0.47, alpha: 1)
    static let stairShadedRiser = UIColor(red: 0.64, green: 0.51, blue: 0.38, alpha: 1)
    static let stairEdge = UIColor(red: 0.45, green: 0.32, blue: 0.24, alpha: 1)

    /// The mean colour of a picture's opaque pixels (a terrace's stone, as graded in its land).
    static func meanColour(_ image: CGImage) -> UIColor? {
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
        for index in 0..<(width * height) where pixels[index * 4 + 3] > 200 {
            let alpha = Double(pixels[index * 4 + 3]) / 255
            red += Double(pixels[index * 4]) / 255 / alpha
            green += Double(pixels[index * 4 + 1]) / 255 / alpha
            blue += Double(pixels[index * 4 + 2]) / 255 / alpha
            count += 1
        }
        guard count > 0 else { return nil }
        return UIColor(red: red / count, green: green / count, blue: blue / count, alpha: 1)
    }

    /// How tall a terrace's balustrade stands (`tools/terrace_art.py` `RAIL`).
    static let railHeight: CGFloat = 14

    /// Stone terraces' balustrades, up on their tops round every edge but the stairs, and a post at
    /// each corner and either side of each stair (`tools/terrace_art.py`; the land's caves keep
    /// `WorldScene.placeTerraces`). Each stretch is one cell's edge, its picture sheared along it as
    /// the walls' are. Those along the front stand in front of whoever is on the edge's cell, those
    /// along the back behind them.
    private func placeTerraces() {
        guard !map.terraces.isEmpty else { return }
        let tile = WorldMap.tileSize
        let southRail = art.sprite("terrace_rail_s").texture, westRail = art.sprite("terrace_rail_w").texture
        let post = art.sprite("terrace_post")
        let up = CGVector(dx: 0, dy: WorldMap.terraceHeight)
        func corner(_ col: Int, _ row: Int) -> CGPoint { WorldMap.project(CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)) }
        func place(_ texture: SKTexture, from a: CGPoint, to b: CGPoint, front: Bool) {
            let node = SKSpriteNode(texture: texture, size: CGSize(width: abs(b.x - a.x), height: abs(b.y - a.y) + Self.railHeight))
            node.anchorPoint = .zero
            node.position = CGPoint(x: min(a.x, b.x), y: min(a.y, b.y)) + up
            node.zPosition = front ? -min(a.y, b.y) : -max(a.y, b.y)
            chunk(at: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)).addChild(node)
        }
        func standPost(at point: CGPoint) {
            let node = SKSpriteNode(texture: post.texture, size: post.size)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = point + up + CGVector(dx: 0, dy: -2)
            node.zPosition = -point.y + 0.5
            chunk(at: point).addChild(node)
        }
        for terrace in map.terraces {
            let o = terrace.origin
            let last = GridPoint(col: o.col + terrace.width - 1, row: o.row + terrace.height - 1)
            var posts: Set<GridPoint> = [GridPoint(col: o.col, row: o.row), GridPoint(col: last.col + 1, row: o.row),
                                          GridPoint(col: o.col, row: last.row + 1), GridPoint(col: last.col + 1, row: last.row + 1)]
            for col in o.col...last.col {
                // Along the front (south) and the back (north).
                if terrace.heads.contains(GridPoint(col: col, row: o.row)) {
                    posts.insert(GridPoint(col: col, row: o.row))
                    posts.insert(GridPoint(col: col + 1, row: o.row))
                } else {
                    place(southRail, from: corner(col, o.row), to: corner(col + 1, o.row), front: true)
                }
                place(southRail, from: corner(col, last.row + 1), to: corner(col + 1, last.row + 1), front: false)
            }
            for row in o.row...last.row {
                // Along the left (west) and the right (east).
                if terrace.heads.contains(GridPoint(col: o.col, row: row)) {
                    posts.insert(GridPoint(col: o.col, row: row))
                    posts.insert(GridPoint(col: o.col, row: row + 1))
                } else {
                    place(westRail, from: corner(o.col, row), to: corner(o.col, row + 1), front: true)
                }
                place(westRail, from: corner(last.col + 1, row), to: corner(last.col + 1, row + 1), front: false)
            }
            for spot in posts { standPost(at: corner(spot.col, spot.row)) }
        }
    }

    /// A round shadow (`Lighting.Shadow`) under what stands on a hill or on the sunk shore and lakes, where
    /// the shade cast away from the sun isn't laid (`addScenery`), as `plant` gives a prop with `shadow`.
    /// Hides its scenery's shadows on slopes, or shows them again (`Lighting.Shadow.hideForPicture`).
    func hideSlopeShadows(_ hidden: Bool) {
        for shadow in shadows { shadow.hideForPicture(hidden) }
    }

    private func roundShadow(under node: SKSpriteNode, at cell: GridPoint) {
        if map.hillIndex(at: cell) != nil {
            let strip = HillArt.strip(at: -node.zPosition)
            let layers: [(from: CGFloat, z: CGFloat)] = (0..<3).map { step in
                let start = strip.start - CGFloat(step) * HillArt.stripHeight
                return (from: start + map.height(at: CGPoint(x: node.position.x, y: start)),
                        z: strip.z + CGFloat(step) * HillArt.stripHeight)
            }
            shadows.append(Lighting.Shadow(under: node, in: chunk(at: node.position), layers: layers))
        } else if map.isSunken(cell) {
            let strip = HillArt.strip(at: -node.zPosition, depth: HillArt.sunkenDepth)
            shadows.append(Lighting.Shadow(under: node, in: chunk(at: node.position), layers: [(from: strip.start, z: strip.z)]))
        }
    }

    /// The waterfalls where the rivers spring (`LandPlan.planWaterfalls`): their four frames in turn, the
    /// water running down, and a little spray sparkling over the pool at their foot.
    private func placeWaterfalls(_ planned: [Placement]) {
        guard !planned.isEmpty else { return }
        let frames = ["waterfall", "waterfall_2", "waterfall_3", "waterfall_4"].map { art.sprite($0).texture }
        for fall in planned {
            let node = addScenery(art.sprite(fall.art), at: fall.cell, nudge: fall.nudge, scale: fall.scale)
            node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.11)))
            let spray = node.position + CGVector(dx: 0, dy: 10)
            Ambience.twinkle(around: spray, radius: 20, count: 4, in: layer(at: spray, lift: Self.airLift))
        }
    }

    /// The waterfalls over the terraces' faces (`LandPlan.planCliffFalls`), in three pieces fitted to
    /// each (`tools/waterfall_art.py`): the stream on the level above with its lip, the sheet of water
    /// down the face as tall as the face stands, and the pool at its foot, each in four frames.
    /// Sorted at the foot, in front of the face's own strip and over the level above's.
    private func placeCliffFalls(_ falls: [(foot: CGPoint, lip: CGPoint)]) {
        guard !falls.isEmpty else { return }
        func frames(_ name: String) -> [SKTexture] { ["", "_2", "_3", "_4"].map { art.sprite(name + $0).texture } }
        let tops = frames("cliff_fall_top"), sheets = frames("cliff_fall_sheet"), pools = frames("cliff_fall_pool")
        // The spring pond on the level above that its stream runs out of (the user, 2026-11-25: "there
        // is no water it comes from"), its mouth overlapping the stream's head by a few of its pixels.
        let springs = frames("cliff_fall_spring")
        let topSize = art.sprite("cliff_fall_top").size, springSize = art.sprite("cliff_fall_spring").size
        let overlap = topSize.height * 3 / 12
        let tile = WorldMap.tileSize
        /// A point in cells on the ground (its place on the map) and shown up at its height.
        func spot(_ point: CGPoint) -> (ground: CGPoint, shown: CGPoint) {
            let ground = WorldMap.project(CGPoint(x: point.x * tile, y: point.y * tile))
            return (ground, CGPoint(x: ground.x, y: ground.y + map.height(at: ground)))
        }
        for fall in falls {
            let foot = spot(fall.foot), lip = spot(fall.lip)
            let x = ((foot.shown.x + lip.shown.x) / 2).rounded()
            let z = -foot.ground.y
            let drop = max(8, (lip.shown.y - foot.shown.y).rounded())
            let pieces: [(frames: [SKTexture], size: CGSize, anchor: CGPoint, at: CGPoint, lift: CGFloat)] = [
                (tops, art.sprite("cliff_fall_top").size, CGPoint(x: 0.5, y: 0), CGPoint(x: x, y: foot.shown.y.rounded() + drop - 2), 0.1),
                (sheets, CGSize(width: art.sprite("cliff_fall_sheet").size.width, height: drop), CGPoint(x: 0.5, y: 0),
                 CGPoint(x: x, y: foot.shown.y.rounded()), 0.2),
                (pools, art.sprite("cliff_fall_pool").size, CGPoint(x: 0.5, y: 0.5), CGPoint(x: x, y: foot.shown.y.rounded()), 0.3),
                (springs, springSize, CGPoint(x: 0.5, y: 0), CGPoint(x: x, y: (foot.shown.y.rounded() + drop - 2 + topSize.height - overlap).rounded()), 0.05),
            ]
            for piece in pieces {
                let node = SKSpriteNode(texture: piece.frames[0], size: piece.size)
                node.anchorPoint = piece.anchor
                node.position = piece.at
                node.zPosition = z + piece.lift
                node.run(.repeatForever(.animate(with: piece.frames, timePerFrame: 0.11)))
                chunk(at: foot.shown).addChild(node)
            }
            let spray = foot.shown + CGVector(dx: 0, dy: 6)
            Ambience.twinkle(around: spray, radius: 14, count: 3, in: layer(at: spray, lift: Self.airLift))
        }
    }

    private func placeDecor(_ planned: [Placement]) {
        for decor in planned {
            addScenery(decor)
            if decor.art.contains("fountain") {
                let sparkle = map.center(of: decor.cell) + CGVector(dx: 0, dy: 30)
                Ambience.twinkle(around: sparkle, radius: 30, count: 4, in: layer(at: sparkle, lift: Self.airLift))
            }
        }
    }

    /// The land's people where the plan put them, each with a quest mark over them (hidden till
    /// there's news for you); they stand and idle for now.
    private func placeNPCs(_ planned: [(npc: NPCDef, cell: GridPoint)]) {
        for (npc, cell) in planned {
            let node = Walker(cycle: art.walkCycle(npc.art), label: npc.name)
            node.idles = !npc.role.isObject
            node.tagMode = .onDemand
            if npc.role == .boss { node.motion = IdleMotion.of(art: npc.art) }
            node.position = map.center(of: cell)
            node.zPosition = map.depth(at: node.position)
            let marker = NameTag("!", size: 28)
            marker.position = CGPoint(x: 0, y: node.sprite.size.height + 18)
            marker.zPosition = 6_000
            marker.isHidden = true
            let bob = SKAction.sequence([.moveBy(x: 0, y: 5, duration: 0.4), .moveBy(x: 0, y: -5, duration: 0.4)])
            let pulse = SKAction.sequence([.scale(to: 1.15, duration: 0.4), .scale(to: 1, duration: 0.4)])
            marker.run(.repeatForever(.group([bob, pulse])))
            node.addChild(marker)
            world.addChild(node)
            npcs.append((npc, node, marker))
        }
    }

    /// Circles of mushrooms with a sparkle in the middle, like the ones fairies dance in.
    private func placeFairyRings(_ middles: [GridPoint]) {
        guard let rings = def.theme.fairyRings, !middles.isEmpty else { return }
        let sprite = art.sprite(rings.art)
        for middle in middles {
            let origin = map.center(of: middle)
            for index in 0..<9 {
                let angle = CGFloat(index) / 9 * 2 * .pi
                let node = SKSpriteNode(texture: sprite.texture, size: sprite.size * 0.75)
                node.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                node.position = origin + CGVector(dx: cos(angle) * 52, dy: sin(angle) * 36)
                node.zPosition = -node.position.y
                chunk(at: origin).addChild(node)
            }
            Ambience.twinkle(around: origin, radius: 26, count: 5, in: layer(at: origin, lift: Self.airLift))
        }
    }

    /// The theme's props, and past the lines the land meets the lands beside it along (`Seam`)
    /// theirs, graded as they are there.
    private func placeProps(_ props: [Placement], seams: [Placement], pause: @escaping () async -> Void) async {
        // Its trees' and bushes' wind frames on one texture, so they draw in batches (`packWindFrames`).
        if !Self.isOffForDebug("wind") { await art.packWindFrames(props.map { $0.art }, pause: pause) }
        for (number, prop) in props.enumerated() {
            if number % 32 == 31 { await pause() }
            plant(prop)
        }
        var sprites: [String: SpriteArt] = [:]
        for (number, prop) in seams.enumerated() {
            if number % 32 == 31 { await pause() }
            guard let land = prop.land else { continue }
            let key = land.id + "|" + prop.art
            let sprite: SpriteArt
            if let known = sprites[key] {
                sprite = known
            } else {
                let own = art.sprite(prop.art)
                let texture = art.gradedTile(prop.art, palette: land.theme.palette).map { image -> SKTexture in
                    let made = SKTexture(cgImage: image)
                    made.filteringMode = .nearest
                    return made
                } ?? own.texture
                sprite = SpriteArt(texture: texture, size: own.size)
                sprites[key] = sprite
            }
            plant(prop, sprite: sprite)
        }
    }

    /// A prop as its placement says (`WorldScene.plant`): swaying, bobbing, with its shadow and its
    /// glow.
    private func plant(_ planted: Placement, sprite: SpriteArt? = nil) {
        guard let placement = planted.prop else { return }
        let cell = planted.cell
        let node = addScenery(planted, sprite: sprite)
        if placement.bob == true {
            // Unseeded, so the land's layout stays what it was.
            let rise = SKAction.moveBy(x: 0, y: 3, duration: .random(in: 1.3...2))
            rise.timingMode = .easeInEaseOut
            node.run(.repeatForever(.sequence([rise, rise.reversed()])), withKey: "bob")
        }
        // On a hill, the strip it stands on and the two in front, where its shadow and glow reach
        // them (`HillArt.strip(at:)`).
        var layers: [(from: CGFloat, z: CGFloat)] = []
        if map.hillIndex(at: cell) != nil {
            let strip = HillArt.strip(at: -node.zPosition)
            layers = (0..<3).map { step in
                let start = strip.start - CGFloat(step) * HillArt.stripHeight
                return (from: start + map.height(at: CGPoint(x: node.position.x, y: start)),
                        z: strip.z + CGFloat(step) * HillArt.stripHeight)
            }
        }
        if placement.shadow == true {
            if !layers.isEmpty {
                shadows.append(Lighting.Shadow(under: node, in: chunk(at: node.position), layers: layers))
            } else if map.isSunken(cell) {
                // On the shore, over the sunk ground it stands on (`HillArt.sunkenDepth`).
                let strip = HillArt.strip(at: -node.zPosition, depth: HillArt.sunkenDepth)
                shadows.append(Lighting.Shadow(under: node, in: chunk(at: node.position), layers: [(from: strip.start, z: strip.z)]))
            }
            // On flat ground its shade is laid as everything's is (`addScenery`, `CanopyShade`).
        }
        if let hex = placement.glow, let color = UIColor(hex: hex), let glow = planted.glow {
            // A light isn't darkened on a hill's shaded side (`shade`).
            node.colorBlendFactor = 0
            Lighting.glow(behind: node, color: color, in: chunk(at: node.position), alpha: glow.alpha, duration: glow.duration,
                          layers: layers)
        }
    }

    /// A small sign where each road leaves the land, where the plan put it, its words over it
    /// (shown when you come to read it).
    /// Its tall grass bent by you and its people near you, and cut over their legs (`Walker.wade`).
    private func wade(through grass: GrassField, dt: TimeInterval, you: CGPoint) {
        var waders: [GrassField.Wader] = []
        if isHere { waders.append(GrassField.Wader(key: ObjectIdentifier(LandStage.self), feet: you)) }
        for walker in crowd?.walkers ?? [] where walker.position.distance(to: you) < 700 {
            guard grass.grows(near: map.rawCell(at: walker.position)) else {
                walker.wade(nil)
                continue
            }
            waders.append(GrassField.Wader(key: ObjectIdentifier(walker), feet: walker.position))
            walker.wade(grass.cover(feet: walker.position, width: walker.frameWidth))
        }
        grass.update(dt: dt, waders: waders) { map.rawCell(at: $0) }
    }

    /// How much of you the grass in front of you hides (`GrassField.cover`), `point` in the
    /// continent's points; nil out of it.
    func wading(at point: CGPoint, width: Int) -> [CGFloat]? {
        guard let grass else { return nil }
        let feet = local(point)
        guard grass.grows(near: map.rawCell(at: feet)) else { return nil }
        return grass.cover(feet: feet, width: width)
    }

    /// Its tall grass (`GrassField`, theme `tallGrass`) over the patches its layout kept for it
    /// (`WorldMap.tallGrass`), each tuft graded with the land's palette as its ground is.
    private func placeTallGrass() {
        guard let wanted = def.theme.tallGrass, !map.tallGrass.isEmpty, !Self.isOffForDebug("grass") else { return }
        let designs = (0..<4).map { GrassField.frames(of: art.sprite("\(wanted.art)_\($0)").texture) }
        grass = GrassField(cells: map.tallGrass, designs: designs, seed: def.id) { self.chunk(at: $0) }
    }

    private func placeSignposts(_ planned: [(exit: MapDef.Exit, cell: GridPoint)]) {
        for (exit, cell) in planned {
            guard let destination = Content.shared.map(exit.to) else { continue }
            let text = switch map.signWay(for: exit) {
            // Arrows follow the road on screen: north runs up-left, east up-right.
            case .north: "↖ \(destination.name)"
            case .south: "\(destination.name) ↘"
            case .east: "\(destination.name) ↗"
            case .west: "↙ \(destination.name)"
            }
            let post = addScenery(art.sprite("signpost"), at: cell, scale: 1.6)
            let top = map.base(of: cell) + CGVector(dx: 0, dy: post.size.height + 4)
            let label = NameTag(text, color: Nodes.gold, size: 12)
            label.position = top + CGVector(dx: 0, dy: 4)
            label.alpha = 0
            layer(at: top, lift: Self.above).addChild(label)
        }
    }

    /// The crags round a cave's mouth: boulders strewn on the range past the land's edge, and the
    /// mist thickening out past it (`WorldScene.placeCrags`).
    private func placeCrags() {
        guard !map.crags.isEmpty, !Self.isOffForDebug("crags") else { return }
        let tile = WorldMap.tileSize
        let colour = Self.fogColor(from: art.picture(of: art.tileTexture(def.theme.border ?? def.theme.ground)))
        for crag in map.crags {
            let hill = map.hills[crag.hill]
            strewStones(on: hill, inland: crag.inland)
            if let mouth = hill.mouth, mouth.pictured { placeMouth(mouth, on: hill, cave: crag.to) }
            // A hill inland stands in the land's own ground: no range past the edge to fade out.
            guard !crag.inland else { continue }
            let length = crag.edge == .north || crag.edge == .south ? map.columns : map.rows
            var span = 0...length
            if map.region != nil, let mouth = hill.mouth {
                let road = Int((crag.edge == .north || crag.edge == .south ? mouth.x : mouth.y).rounded(.down))
                let reach = Int(WorldMap.cragStretch) + 8
                span = max(0, road - reach)...min(length, road + reach)
            }
            let facesYou = crag.edge == .north || crag.edge == .east
            let from: CGFloat = facesYou ? 14 : 13
            let heights = stride(from: span.lowerBound, to: span.upperBound, by: 4).map { along -> CGFloat in
                let cell = map.cell(on: crag.edge, along: along, inward: -Int(from) - 4)
                return hill.height(atCells: Double(cell.col) + 0.5, Double(cell.row) + 0.5)
            }
            let lift = heights.reduce(0, +) / CGFloat(max(1, heights.count))
            func clear(_ alongs: StrideTo<Int>) -> Bool {
                alongs.allSatisfy { along in
                    stride(from: -4, through: -32, by: -7).allSatisfy { inward in
                        !Continent.isLand(map.cell(on: crag.edge, along: along, inward: inward), from: def)
                    }
                }
            }
            let low: CGFloat = clear(stride(from: span.lowerBound - 2, to: span.lowerBound - 22, by: -5)) ? 20 : 0
            let high: CGFloat = clear(stride(from: span.upperBound + 1, to: span.upperBound + 21, by: 5)) ? 20 : 0
            let wide = (CGFloat(span.upperBound - span.lowerBound) + low + high) * tile, deep = 8 * tile, beyond = 8 * tile
            let toward: CGFloat = crag.edge == .north || crag.edge == .west ? 1 : -1
            let off = (high - low) / 2 * tile * toward
            let fog = SKNode()
            let band = SKSpriteNode(texture: Self.fogTexture, color: colour, size: CGSize(width: wide, height: deep))
            band.colorBlendFactor = 1
            let mist = SKSpriteNode(color: colour, size: CGSize(width: wide, height: beyond))
            band.position = CGPoint(x: off, y: (from + 4) * tile)
            mist.position = CGPoint(x: off, y: (from + 8) * tile + beyond / 2)
            let turned = SKNode()
            turned.addChild(band)
            turned.addChild(mist)
            let middle = CGFloat(span.lowerBound + span.upperBound) / 2 * tile
            switch crag.edge {
            case .north: turned.position = CGPoint(x: middle, y: CGFloat(map.rows) * tile)
            case .south: turned.position = CGPoint(x: middle, y: 0); turned.zRotation = .pi
            case .east: turned.position = CGPoint(x: CGFloat(map.columns) * tile, y: middle); turned.zRotation = -.pi / 2
            case .west: turned.position = CGPoint(x: 0, y: middle); turned.zRotation = .pi / 2
            }
            fog.addChild(turned)
            let raised = ContinentScene.projected(fog)
            raised.position.y = lift
            // Over everything that stands, as in the land's own scene (15,000 there).
            raised.zPosition = shift.dy + Self.above + 15_000
            world.addChild(raised)
        }
    }

    /// A cave's mouth as its picture (`WorldMap.mouthArt`, ChatGPT's drawings, `tools/cave_mouth_art.py`):
    /// laid over its rock face, its bottom row on the mouth's foot where the road runs in, graded with the
    /// land's palette as everything is. The face runs along the map's diagonal on screen, so the picture,
    /// drawn face on, is sheared to lean with it: each column moved up or down in whole pixels by how far
    /// along the face it lies (as the town terraces' walls are). Sorted just behind whoever stands at its
    /// foot, in front of the rock behind it.
    private func placeMouth(_ mouth: WorldMap.Hill.Mouth, on hill: WorldMap.Hill, cave: String) {
        let id = WorldMap.mouthArt(for: cave)
        guard art.asset(id) != nil else { return }
        let picture = art.picture(of: art.sprite(id).texture)
        // How the face leans on screen: up this many points for each one across.
        let along = WorldMap.project(CGPoint(x: mouth.along.x, y: mouth.along.y))
        let slope = abs(along.x) > 0.001 ? along.y / along.x : 0
        // The opening's columns (`tools/cave_mouth_art.py`: x 20 to 107 of 128), its floor faded into the ground.
        let opening = Int(Double(picture.width) * 22 / 128)...Int(Double(picture.width) * 105 / 128)
        guard let made = Self.shear(picture, slope: slope, fade: opening) else { return }
        let sheared = made.0, footUp = made.1
        let texture = SKTexture(cgImage: sheared)
        texture.filteringMode = .nearest
        let size = CGSize(width: sheared.width, height: sheared.height)
        let node = SKSpriteNode(texture: texture, size: size)
        node.anchorPoint = CGPoint(x: 0.5, y: footUp / size.height)
        let tile = WorldMap.tileSize
        let foot = WorldMap.project(CGPoint(x: mouth.x * tile, y: mouth.y * tile))
        node.position = CGPoint(x: foot.x.rounded(), y: (foot.y + hill.height(atCells: mouth.x, mouth.y)).rounded() - Self.mouthSink)
        node.zPosition = -foot.y - 1
        // It stands off the face (the user, 2026-11-25: "add some depth to the cave entrance drawing,
        // because it shows flat now while they are rocks"): its rocks cast a hard shadow on the rock behind,
        // down and to the right, away from the light, in two steps, a near one darker, a far one fainter.
        for (offset, darkness) in [(CGFloat(4), CGFloat(0.16)), (CGFloat(2), CGFloat(0.32))] {
            let shadow = SKSpriteNode(texture: texture, size: size)
            shadow.anchorPoint = node.anchorPoint
            shadow.color = .black
            shadow.colorBlendFactor = 1
            shadow.alpha = darkness
            shadow.position = CGPoint(x: offset, y: -offset)
            shadow.zPosition = -0.001 * offset
            node.addChild(shadow)
        }
        chunk(at: node.position).addChild(node)
    }

    /// `picture` sheared to lean `slope` points up for each across, in whole pixels about its middle
    /// column, and how far its middle column's bottom stands over the new picture's bottom.
    /// How far a cave mouth's picture is sunk below its foot, onto the road in front, and how many rows up
    /// from its bottom its floor fades out into the land's ground there (`fadeFloor`).
    static let mouthSink: CGFloat = 6
    static let mouthFade = 8

    /// A cave mouth's floor faded out into the land's ground under it (the user, 2026-11-25: "The cave
    /// entrance ground should fade/merge better with the world ground"): the picture sunk `mouthSink` onto the
    /// road in front of the face, and across its opening's `columns` its bottom `mouthFade` rows cleared
    /// through an ordered dither, all of the bottom row, fewer and fewer up toward the dark, so the road and
    /// the cave's floor mix in whole pixels, with no edge between them.
    static func fadeFloor(_ pixels: inout [UInt8], width w: Int, height h: Int, columns: ClosedRange<Int>) {
        let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 + 0.5) / 16 }
        let rows = mouthFade
        for up in 0..<min(rows, h) {
            let y = h - 1 - up
            // The share cleared: all of the bottom row, none `rows` up.
            let clear = 1 - Double(up) / Double(rows)
            for x in max(0, columns.lowerBound)...min(w - 1, columns.upperBound) where bayer[(y % 4) * 4 + x % 4] < clear {
                let at = (y * w + x) * 4
                for k in 0..<4 { pixels[at + k] = 0 }
            }
        }
    }

    static func shear(_ picture: CGImage, slope: CGFloat, fade: ClosedRange<Int>? = nil) -> (CGImage, CGFloat)? {
        let w = picture.width, h = picture.height
        guard w > 0, h > 0 else { return nil }
        let middle = CGFloat(w) / 2
        let lifts = (0..<w).map { Int((slope * (CGFloat($0) + 0.5 - middle)).rounded()) }
        let low = lifts.min() ?? 0, high = lifts.max() ?? 0
        let tall = h + high - low
        var source = [UInt8](repeating: 0, count: w * h * 4)
        var out = [UInt8](repeating: 0, count: w * tall * 4)
        let space = CGColorSpaceCreateDeviceRGB(), info = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = source.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: space, bitmapInfo: info) else { return false }
            context.draw(picture, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        if let fade { fadeFloor(&source, width: w, height: h, columns: fade) }
        // Rows from the top in memory: a column lifted `lift` up starts `high - lift` rows down.
        for x in 0..<w {
            let down = high - lifts[x]
            for y in 0..<h {
                let from = (y * w + x) * 4, to = ((y + down) * w + x) * 4
                for k in 0..<4 { out[to + k] = source[from + k] }
            }
        }
        let made = out.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: w, height: tall, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: space, bitmapInfo: info)?.makeImage()
        }
        guard let made else { return nil }
        // The middle column's lift is about 0: its bottom stands `-low` over the picture's bottom.
        let middleLift = lifts[w / 2]
        return (made, CGFloat(middleLift - low))
    }

    /// Boulders and stones strewn over a range where a road leads into a cave, out past the land's
    /// edge, or over its rock where it's a hill inland (`WorldScene.strewStones`).
    private func strewStones(on hill: WorldMap.Hill, inland: Bool) {
        var random = SeededRandom(text: def.id + "/crag stones")
        for cell in hill.cells.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) where inland ? !map.isWalkable(cell) : !map.contains(cell) {
            if !inland, Continent.isLand(cell, from: def) { continue }
            let x = Double(cell.col) + 0.5, y = Double(cell.row) + 0.5
            if let mouth = hill.mouth {
                let dx = x - mouth.x, dy = y - mouth.y
                let across = dx * mouth.along.x + dy * mouth.along.y, inward = dx * mouth.into.x + dy * mouth.into.y
                if abs(across) < mouth.half + 2, inward < mouth.depth + 3 { continue }
            }
            guard hill.rise(x, y) > 0.15, Double.random(in: 0..<1, using: &random) < 0.06 else { continue }
            let big = Bool.random(using: &random)
            let size = CGFloat.random(in: 0.55...0.85, using: &random)
            let stone = addScenery(art.sprite(big ? "boulder" : "rock"), at: cell, scale: big ? size : size * 1.4)
            stone.position.y += hill.height(atCells: x, y)
        }
    }

    /// Raised terraces (`WorldMap.plateaus`), in stacked sandstone (the user's pick from
    /// `tools/terrace_preview.py`, 2026-11-17; drawn by `tools/terrace_art.py`): each top paved in
    /// flagstones its height up, a wall of sandstone blocks under the edges that face you, stone
    /// steps up from the ground in front, and its shade laid on the ground away from the sun as
    /// everything's is (`CanopyShade.addBlock`) (`WorldScene.placePlateaus`).
    private func placePlateaus() {
        guard !map.plateaus.isEmpty else { return }
        let tile = WorldMap.tileSize
        let flags = ["terrace_flag", "terrace_flag_2", "terrace_flag_3", "terrace_flag_4"].map { art.tileTexture($0) }
        for flag in flags { flag.filteringMode = .nearest }
        // A cell's stretch of wall under a south edge (rising to the right) and a west one, three of each.
        let southWalls = ["terrace_wall_s", "terrace_wall_s_2", "terrace_wall_s_3"].map { art.sprite($0).texture }
        let westWalls = ["terrace_wall_w", "terrace_wall_w_2", "terrace_wall_w_3"].map { art.sprite($0).texture }
        func pick(_ cell: GridPoint, _ count: Int) -> Int { (((cell.col &* 73_856_093) ^ (cell.row &* 19_349_663)) & 0x7fff_ffff) % count }
        func corner(_ col: Int, _ row: Int) -> CGPoint { WorldMap.project(CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)) }
        func stroke(_ path: CGPath, color: UIColor, width: CGFloat, z: CGFloat) {
            guard !path.isEmpty else { return }
            let node = SKShapeNode(path: path)
            node.strokeColor = color
            node.lineWidth = width
            node.lineCap = .round
            node.zPosition = z
            world.addChild(node)
        }
        for plateau in map.plateaus {
            let rise = plateau.height
            let topZ = Self.topZ(of: plateau.cells)
            let lips = CGMutablePath(), shadows = CGMutablePath()
            func line(_ path: CGMutablePath, _ from: CGPoint, _ to: CGPoint) {
                path.move(to: from)
                path.addLine(to: to)
            }
            // Its top: flagstones, its height up, a sprite a cell (a tile map here went undrawn on a
            // phone, Ingothold's ground showing through: the user, 2026-11-18). A hair over a cell
            // each, so no seam opens between them as they're turned. The stairs are drawn as steps.
            let grid = SKNode()
            for cell in plateau.cells where plateau.ramps[cell] == nil {
                let flag = SKSpriteNode(texture: flags[pick(cell, flags.count)], size: CGSize(width: tile + 0.5, height: tile + 0.5))
                flag.position = CGPoint(x: (CGFloat(cell.col) + 0.5) * tile, y: (CGFloat(cell.row) + 0.5) * tile)
                grid.addChild(flag)
            }
            let raised = ContinentScene.projected(grid)
            raised.position.y = rise
            raised.zPosition = topZ
            world.addChild(raised)
            // Walls: under each edge of the top facing you (front, left) where the ground beyond is
            // lower, down to it.
            for cell in plateau.cells.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) where plateau.ramps[cell] == nil {
                for front in [true, false] {
                    let beyond = front ? GridPoint(col: cell.col, row: cell.row - 1) : GridPoint(col: cell.col - 1, row: cell.row)
                    if plateau.cells.contains(beyond), plateau.ramps[beyond] == nil { continue }
                    let a = CGPoint(x: CGFloat(cell.col) * tile, y: CGFloat(cell.row) * tile)
                    let b = front ? CGPoint(x: a.x + tile, y: a.y) : CGPoint(x: a.x, y: a.y + tile)
                    let nudge: CGFloat = 0.5
                    let lowA = map.height(atGrid: front ? CGPoint(x: a.x + nudge, y: a.y - nudge) : CGPoint(x: a.x - nudge, y: a.y + nudge))
                    let lowB = map.height(atGrid: CGPoint(x: b.x - nudge, y: b.y - nudge))
                    guard min(lowA, lowB) < rise - 0.5 else { continue }
                    let pa = WorldMap.project(a), pb = WorldMap.project(b)
                    let wall = front ? southWalls[pick(cell, southWalls.count)] : westWalls[pick(cell, westWalls.count)]
                    defer {
                        line(lips, pa + CGVector(dx: 0, dy: rise), pb + CGVector(dx: 0, dy: rise))
                        line(shadows, pa + CGVector(dx: 0, dy: min(rise, lowA)), pb + CGVector(dx: 0, dy: min(rise, lowB)))
                    }
                    if abs(lowA) < 0.5, abs(lowB) < 0.5 {
                        // On level ground: the wall's picture, sheared along the edge as drawn.
                        let face = SKSpriteNode(texture: wall, size: CGSize(width: abs(pb.x - pa.x), height: abs(pb.y - pa.y) + rise))
                        face.anchorPoint = .zero
                        face.position = CGPoint(x: min(pa.x, pb.x), y: min(pa.y, pb.y))
                        face.zPosition = topZ - 0.5
                        world.addChild(face)
                        continue
                    }
                    // Down to a stair's slope beside it: the same picture, cut to the slope.
                    let path = CGMutablePath()
                    path.move(to: pa + CGVector(dx: 0, dy: rise))
                    path.addLine(to: pb + CGVector(dx: 0, dy: rise))
                    path.addLine(to: pb + CGVector(dx: 0, dy: min(rise, lowB)))
                    path.addLine(to: pa + CGVector(dx: 0, dy: min(rise, lowA)))
                    path.closeSubpath()
                    let face = SKShapeNode(path: path)
                    face.fillTexture = wall
                    face.fillColor = .white
                    face.strokeColor = .clear
                    face.lineWidth = 0
                    face.zPosition = topZ - 0.5
                    world.addChild(face)
                }
            }
            // Stairs: steps from the foot on the ground in front up to the head at the top, each a lit
            // tread and a riser in front of it, the nearest drawn last; and their side turned to you,
            // stepped (the user, 2026-11-17: one slope with lines on it read as flat).
            func at(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
                WorldMap.project(CGPoint(x: x * tile, y: y * tile)) + CGVector(dx: 0, dy: z)
            }
            // In the walls' own stone, as graded in this land (the user, 2026-11-18: "The stairs of the
            // terraces should have the same brick colors as the sides of the terraces"): the stairs'
            // side and risers the mean colour of the wall turned the same way, the treads the top's paving's.
            let litStone = Self.meanColour(art.picture(of: westWalls[0])) ?? Self.stairLitRiser
            let shadedStone = Self.meanColour(art.picture(of: southWalls[0])) ?? Self.stairShadedRiser
            let paving = Self.meanColour(art.picture(of: flags[0])) ?? Self.stairTread
            let pavingAlt = Self.meanColour(art.picture(of: flags[1])) ?? Self.stairTreadAlt
            func shape(_ points: [CGPoint], fill: UIColor, texture: SKTexture? = nil, z: CGFloat) {
                let path = CGMutablePath()
                path.addLines(between: points)
                path.closeSubpath()
                let node = SKShapeNode(path: path)
                node.fillColor = texture == nil ? fill : .white
                node.fillTexture = texture
                node.strokeColor = Self.stairEdge
                node.lineWidth = 1
                node.lineJoin = .miter
                node.zPosition = z
                world.addChild(node)
            }
            for (cell, ramp) in plateau.ramps {
                let c = CGFloat(cell.col), r = CGFloat(cell.row)
                let count = Self.stairSteps, step = rise / CGFloat(count)
                var side: [CGPoint] = [at(c, r, 0)]
                for k in stride(from: count - 1, through: 0, by: -1) {
                    let near = CGFloat(k) / CGFloat(count), far = CGFloat(k + 1) / CGFloat(count)
                    let low = CGFloat(k) * step, high = CGFloat(k + 1) * step
                    let z = topZ - 0.25 + 0.01 * CGFloat(count - k)
                    if ramp == .south {
                        shape([at(c, r + near, high), at(c + 1, r + near, high), at(c + 1, r + far, high), at(c, r + far, high)],
                              fill: k % 2 == 0 ? paving : pavingAlt, z: z)
                        shape([at(c, r + near, low), at(c + 1, r + near, low), at(c + 1, r + near, high), at(c, r + near, high)],
                              fill: shadedStone, z: z + 0.005)
                    } else {
                        shape([at(c + near, r, high), at(c + far, r, high), at(c + far, r + 1, high), at(c + near, r + 1, high)],
                              fill: k % 2 == 0 ? paving : pavingAlt, z: z)
                        shape([at(c + near, r, low), at(c + near, r + 1, low), at(c + near, r + 1, high), at(c + near, r, high)],
                              fill: litStone, z: z + 0.005)
                    }
                }
                for k in 0..<count {
                    let near = CGFloat(k) / CGFloat(count), far = CGFloat(k + 1) / CGFloat(count), high = CGFloat(k + 1) * step
                    side += ramp == .south ? [at(c, r + near, high), at(c, r + far, high)] : [at(c + near, r, high), at(c + far, r, high)]
                }
                side.append(ramp == .south ? at(c, r + 1, 0) : at(c + 1, r, 0))
                // The west side of the front stairs is turned to the light, the south side of the side ones away:
                // the wall's own stone turned that way (the user, 2026-11-18: "the sides of the stairs should
                // show the rocks"), its picture over the stepped side as it is over a wall's stretch, the same
                // edge from the ground to the top.
                shape(side, fill: ramp == .south ? litStone : shadedStone,
                      texture: ramp == .south ? westWalls[pick(cell, westWalls.count)] : southWalls[pick(cell, southWalls.count)],
                      z: topZ - 0.15)
            }
            stroke(lips, color: UIColor(white: 1, alpha: 0.2), width: 1, z: topZ + 0.1)
            stroke(shadows, color: UIColor(white: 0, alpha: 0.28), width: 2, z: topZ - 0.45)
            // Its shade on the ground away from the sun, a block its height (and its balustrade's).
            canopy.addBlock(feet: plateau.cells.filter { plateau.ramps[$0] == nil }.map { map.center(of: $0) },
                            height: rise + Self.railHeight * 0.5,
                            half: tile * 0.70710678)
        }
    }

    /// The fences and rocks along the borders you can't cross (`BorderArt.place`): where a quest
    /// keeps you out, and where no road you can take joins the two lands.
    private func placeBorders() {
        // Both lands would set the same wall down in the same places (`BorderArt.place`): on the
        // continent, the first of the two by id does.
        for neighbour in Continent.neighbours(of: def) where def.id < neighbour.def.id {
            let joined = Continent.joined(def.id, neighbour.def.id, done: session.hasCompleted)
            guard neighbour.isWalled(done: session.hasCompleted, joined: joined) else { continue }
            let open = neighbour.quest.map(session.hasCompleted) ?? false
            let bar = BorderArt.place(neighbour, of: def, open: open, art: art, ground: { [map] in map.height(at: $0) }) { [weak self] point in
                self?.chunk(at: point) ?? SKNode()
            }
            if !bar.isEmpty { gates.append((neighbour, bar)) }
        }
    }

    /// A quest done opened a border of its while you were away in a window: the bar across its gate,
    /// or the fence along it, poofs away (`WorldScene.openBarricades`).
    func openGates() {
        gates.removeAll { gate in
            let joined = Continent.joined(def.id, gate.neighbour.def.id, done: session.hasCompleted)
            guard !gate.neighbour.isWalled(done: session.hasCompleted, joined: joined) else { return false }
            for node in gate.bar {
                if let parent = node.parent { SkillEffects.smoke(at: node.position, in: parent) }
                node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
            }
            return true
        }
    }

    /// Where a terrace's top is sorted: just behind its back corner (`WorldScene.topZ`).
    private static func topZ(of cells: Set<GridPoint>) -> CGFloat { WorldMap.terraceTopZ(of: cells) }

    /// White, solid along the top row and fading smoothly to clear at the bottom (tinted per land).
    private static let fogTexture: SKTexture = {
        let height = 64
        var pixels = [UInt8](repeating: 0, count: height * 4)
        for row in 0..<height {
            let t = 1 - Double(row) / Double(height - 1)
            let alpha = UInt8((t * t * (3 - 2 * t) * 255).rounded())
            for channel in 0..<4 { pixels[row * 4 + channel] = alpha }
        }
        let texture = PixelImage.make(pixels, width: 1, height: height).map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .linear
        return texture
    }()

    /// The land's surrounding ground, averaged and hazed into a pale mist (`WorldScene.fogColor`).
    private static func fogColor(from image: CGImage) -> UIColor {
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let average = [CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255]
        let haze: [CGFloat] = [0.86, 0.9, 0.94]
        let channel = (0..<3).map { average[$0] + (haze[$0] - average[$0]) * 0.4 }
        return UIColor(red: channel[0], green: channel[1], blue: channel[2], alpha: 1)
    }
}
