import SpriteKit

/// Anything that walks around a map: the hero, a companion, an NPC or a passer-by.
/// Walk sheets animate per direction; single-image sprites hop instead. Standing still,
/// everyone breathes gently and blinks now and then, so the world never looks frozen.
final class Walker: SKNode {
    let sprite: SKSpriteNode
    var walkSpeed: CGFloat = 88
    /// Waypoints still to walk, in world coordinates (tap-to-move).
    var path: [CGPoint] = []
    /// How fast its legs go: 1 walking, more running (`InputState.pace`).
    var pace: CGFloat = 1 {
        didSet { if pace != oldValue { sprite.action(forKey: "walk")?.speed = pace } }
    }

    private(set) var facing: Direction = .down
    private(set) var isWalking = false
    private var cycle: WalkCycle
    private var tag: NameTag?
    private var titleTag: NameTag?
    private var shownTitle: String?
    /// When the name tag shows: the party's while standing still, everyone else's up close or when tapped.
    /// `whenClear`, your companion's: while still, unless it would print over the name of whoever it
    /// follows (`follow`), as it does right behind you when the two names are long.
    enum TagMode { case always, whenStill, whenClear, onDemand }
    var tagMode: TagMode = .always {
        didSet { refreshTag() }
    }
    /// The hero is close by; `.onDemand` tags show then.
    var isNear = false {
        didSet { if isNear != oldValue { refreshTag() } }
    }
    /// Its name would sit on its leader's where it stands; a `.whenClear` tag hides then.
    private var crowded = false {
        didSet { if crowded != oldValue { refreshTag() } }
    }
    /// How close the hero gets before someone's name shows.
    static let nameRange: CGFloat = 120
    private var revealed = false
    private var tagShown: Bool?
    private var bubble: SKNode?
    /// Breathing while standing still; off for things that shouldn't, like gift boxes.
    var idles = true {
        didSet { if idles != oldValue { animate() } }
    }
    /// Monsters squish, hop or sway instead of breathing.
    var motion: IdleMotion = .breathe {
        didSet { if motion != oldValue { animate() } }
    }
    /// The hero fidgets when left standing: glances around, stretches.
    var fidgets = false {
        didSet { if fidgets, !isWalking { startFidgeting() } }
    }
    /// So a crowd doesn't breathe in unison.
    private let breathOffset = TimeInterval.random(in: 0..<1.6)
    /// Standing still: breathing out (a pixel lower) and blinking, shown by `showPose`.
    private var breathingOut = false
    private var eyesShut = false
    /// The current map's light, cast softly on everyone standing in it (`theme.palette.light`).
    static var light: (color: UIColor, strength: CGFloat)?

    /// Everything you see of it, raised with the ground it stands on (a hilltop, a terrace).
    /// Children added to the walker go in here.
    private let body = SKNode()
    /// Holds the sprite, mirrored for a single picture walking the other way (`WalkCycle.mirrors`).
    /// Apart from the sprite, so its idle squish and stretch don't undo it.
    private let turn = SKNode()
    /// Which way a single picture last went across the screen; kept while it walks up or down.
    private var goingRight = false
    /// How high the ground under it stands (`WorldScene.groundHeight(at:)`).
    private(set) var lift: CGFloat = 0
    /// A soft round of shade right under its feet, where it touches the ground.
    private let shadow = SKSpriteNode(texture: SoftTextures.glow)
    /// Its shadow: its own picture, frame by frame, laid on the ground away from the sun, as long for
    /// its height as the shade under the trees and buildings (`CanopyShade`; the user, 2026-11-14:
    /// "the hero and all other characters should have shadows as well"), mirrored as it is.
    private let figure = SKSpriteNode()
    /// The figure's colour and how dark it lies, by full sunlight (fainter by moonlight): the trees'
    /// shade's own, multiplied over the ground as theirs is (`CanopyPainter.lean`, `core`), so a
    /// walker's shadow is the same colour as a tree's in every land (playtesting 2026-11-16: black
    /// beside the trees' cool shade on snow).
    private static let figureColor = UIColor(red: CGFloat(CanopyPainter.lean.r), green: CGFloat(CanopyPainter.lean.g),
                                                blue: CGFloat(CanopyPainter.lean.b), alpha: 1)
    private static let figureDarkness = CGFloat(CanopyPainter.core)
    /// How much wider than its frame the figure lies: a profile is a few pixels wide, and its shadow
    /// read as a thin stick (playtesting 2026-11-16); a body's shadow is about as wide whichever way
    /// it faces.
    private static let figureWidth: (side: CGFloat, front: CGFloat) = (1.6, 1.15)
    /// Where the figure lies among everything in a map's scene: just over the ground and the shade
    /// under the trees (-99,300), under all that stands, so a long shadow at evening runs over the
    /// ground, not over a tree behind.
    private static let figureDepth: CGFloat = -99_250
    /// Where a speech bubble or emote lies in a map's scene: over the night's shade (`Sky`, 43,000)
    /// and the lit windows (`LandStage.addWindows`, 43,100), under a lightning flash (43,500).
    private static let bubbleDepth: CGFloat = 43_300
    /// Softens the figure (playtesting 2026-11-14: "a bit more softer and blurred gradient at the
    /// end, it's too stark"): each pixel's alpha taken from a few round it, so its edge is soft, and
    /// fading toward its head, the shadow's far end. `a_frame`: the frame's bottom and height in its
    /// texture, and a texel and a bit across and up (`showFrame`). Drawn in the figure's colour.
    private static let soften: SKShader = {
        let shader = SKShader(source: """
        void main() {
            vec2 d = a_frame.zw;
            float a = texture2D(u_texture, v_tex_coord).a * 0.36
                + (texture2D(u_texture, v_tex_coord + vec2(d.x, 0.0)).a + texture2D(u_texture, v_tex_coord - vec2(d.x, 0.0)).a
                 + texture2D(u_texture, v_tex_coord + vec2(0.0, d.y)).a + texture2D(u_texture, v_tex_coord - vec2(0.0, d.y)).a) * 0.16;
            float t = clamp((v_tex_coord.y - a_frame.x) / a_frame.y, 0.0, 1.0);
            a *= (1.0 - 0.75 * t) * v_color_mix.a;
            // Multiplied over the ground (`blendMode`): the ground times 1 - a * (1 - shade), white
            // (nothing) where it's clear. SpriteKit's multiply takes no account of alpha: a clear
            // pixel came out black, the figure's whole square black on the ground (0.9.96).
            gl_FragColor = vec4(vec3(1.0) - a * (vec3(1.0) - u_shade.rgb), 1.0);
        }
        """)
        shader.uniforms = [SKUniform(name: "u_shade", vectorFloat4: SIMD4<Float>(Float(CanopyPainter.lean.r), Float(CanopyPainter.lean.g),
                                                                         Float(CanopyPainter.lean.b), 1))]
        shader.attributes = [SKAttribute(name: "a_frame", type: .vectorFloat4)]
        return shader
    }()
    /// The soft round at its feet, multiplied over the ground as the figure is: white where it's clear.
    private static let round: SKShader = {
        let shader = SKShader(source: """
        void main() {
            float a = texture2D(u_texture, v_tex_coord).a * v_color_mix.a;
            gl_FragColor = vec4(vec3(1.0) - a * (vec3(1.0) - u_shade.rgb), 1.0);
        }
        """)
        shader.uniforms = [SKUniform(name: "u_shade", vectorFloat4: SIMD4<Float>(Float(CanopyPainter.lean.r), Float(CanopyPainter.lean.g),
                                                                         Float(CanopyPainter.lean.b), 1))]
        return shader
    }()
    /// Where the light over the map comes from now, for anyone set down after it last moved
    /// (`WorldScene.follow`).
    static var sun = Sun.noon
    /// Every walker there is, held weakly, so a new sun reaches them all (`shine`).
    private static let everyone = NSHashTable<Walker>.weakObjects()

    /// Where everyone in the scene stands now, in `space`'s points (`LandStage.coverPanes`).
    static func standing(in space: SKNode) -> [CGPoint] {
        everyone.allObjects.compactMap { walker -> CGPoint? in
            guard walker.scene != nil, !walker.isHidden, let parent = walker.parent else { return nil }
            return parent.convert(walker.position, to: space)
        }
    }

    /// Hides everyone's cast shadow, or shows it again: out of a picture of the map
    /// (`ContinentScene.battleBackdrop`).
    static func hideFigures(_ hidden: Bool) {
        for walker in everyone.allObjects { walker.figure.isHidden = hidden }
    }

    /// Casts everyone's shadow away from `sun` from now on, and anyone's set down later.
    static func shine(_ sun: Sun) {
        self.sun = sun
        for walker in everyone.allObjects { walker.cast(from: sun) }
    }

    override var position: CGPoint {
        didSet { settle() }
    }

    /// Up onto the ground under its spot: as it walks, and once it's on the map.
    func settle() {
        // Its own land's ground, even shown past the border of the land you're in.
        let land = (parent as? LandNode)?.land ?? (scene as? WorldScene)
        // Or on the continent as one place (`ContinentScene`): set down in a land's own points
        // there (`LandStage`), that land's.
        let height = (parent as? StageNode)?.stage?.groundHeight(at: position) ?? land?.groundHeight(at: position)
            ?? (scene as? ContinentScene)?.groundHeight(at: position) ?? 0
        guard height != lift else { return }
        lift = height
        body.position.y = height
    }

    override func addChild(_ node: SKNode) {
        if node === body { super.addChild(node) } else { body.addChild(node) }
    }

    /// Lays its shadow on the ground away from `sun`, as the scenery's: its figure along the way the
    /// shade falls (`CanopyShade.falling`), as long for its height, and a soft round under its feet
    /// (`Lighting.Shadow.shape`), fainter by moonlight.
    func cast(from sun: Sun) {
        let (middle, size, turn) = Lighting.Shadow.shape(wide: Double(cycle.size.width) * 0.75, sun: sun)
        // Under its feet, a little toward the way the shade falls: halfway along the shade, it lay
        // off from them and the walker seemed to hover (the user, 2026-11-18).
        shadow.position = CGPoint(x: middle.dx * 0.3, y: middle.dy * 0.3 + feet)
        shadow.size = size
        shadow.zRotation = turn
        shadow.alpha = 0.45 * CGFloat(sun.strength)
        let fall = CanopyShade.falling(from: sun)
        let length = (fall.fall.dx * fall.fall.dx + fall.fall.dy * fall.fall.dy).squareRoot()
        // Its up turned to the way the shade falls, and as long as the shade is for its height.
        figure.zRotation = atan2(fall.fall.dy, fall.fall.dx) - .pi / 2
        figure.yScale = max(0.25, length)
        figure.alpha = Self.figureDarkness * CGFloat(fall.strength)
    }

    /// The figure shows the sprite's frame, and the shader where that frame lies in its texture
    /// (`soften`).
    private func showFrame() {
        figure.texture = sprite.texture
        guard let texture = sprite.texture else {
            // Never without a value for its shader: SpriteKit reads one from every sprite it draws.
            figure.setValue(SKAttributeValue(vectorFloat4: SIMD4<Float>(0, 1, 0, 0)), forAttribute: "a_frame")
            return
        }
        let rect = texture.textureRect(), size = texture.size()
        let frame = SIMD4<Float>(Float(rect.minY), Float(max(rect.height, 0.0001)),
                                 Float(rect.width / max(1, size.width) * 1.3), Float(rect.height / max(1, size.height) * 1.3))
        figure.setValue(SKAttributeValue(vectorFloat4: frame), forAttribute: "a_frame")
    }

    /// How far over its position its feet stand, in points: the lowest row anything's drawn in its
    /// first frame, less the sprite's anchor. The figure turns about them, starting right under them,
    /// and the round lies under them (the user, 2026-11-18: hung off the frame's anchor, a few pixels
    /// under the feet, the shadows read as hovering).
    private var feet: CGFloat = 0
    /// Each frame's clear rows under its feet and its height, in its picture's pixels (`feetRows`), by texture.
    private static var feetCache: [ObjectIdentifier: (rows: Int, tall: Int)] = [:]

    /// How many rows at the bottom of `texture`'s picture are clear (under its feet), of how many.
    private static func feetRows(_ texture: SKTexture) -> (rows: Int, tall: Int) {
        if let known = feetCache[ObjectIdentifier(texture)] { return known }
        let image = ArtLibrary.shared.picture(of: texture)
        let w = image.width, h = image.height
        var rows = 0
        if w > 0, h > 0, let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let data = context.data {
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            let bytes = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            // Rows run down from the top in memory: up from the last.
            search: for row in stride(from: h - 1, through: 0, by: -1) {
                for x in 0..<w where bytes[(row * w + x) * 4 + 3] > 24 { break search }
                rows += 1
            }
            if rows >= h { rows = 0 }
        }
        feetCache[ObjectIdentifier(texture)] = (rows, h)
        return (rows, h)
    }

    /// Stands the figure on its feet (`feet`): turning about them, its own feet under them.
    private func standFigure() {
        guard let first = cycle.frames(.down).first else { return }
        let found = Self.feetRows(first)
        let rows = CGFloat(found.rows), tall = CGFloat(max(1, found.tall))
        // A pixel into the feet, so the shadow starts under them, not a hair below.
        let share = min(0.5, (rows + 1) / tall)
        feet = max(0, (rows / tall - sprite.anchorPoint.y) * cycle.size.height)
        figure.anchorPoint = CGPoint(x: sprite.anchorPoint.x, y: share)
        figure.position = CGPoint(x: 0, y: (share - sprite.anchorPoint.y) * cycle.size.height)
    }

    /// The figure shows the frame the sprite shows, and lies just over the ground (`figureDepth`)
    /// wherever the walker stands in the scene's depth. Every frame.
    private func followFigure() {
        if figure.texture !== sprite.texture { showFrame() }
        let wide = facing == .left || facing == .right ? Self.figureWidth.side : Self.figureWidth.front
        if figure.xScale != turn.xScale * wide { figure.xScale = turn.xScale * wide }
        guard scene is ContinentScene || scene is WorldScene else {
            figure.zPosition = -1
            bubble?.zPosition = 6_000
            return
        }
        var depth = zPosition + body.zPosition
        var node = parent
        while let above = node {
            depth += above.zPosition
            node = above.parent
        }
        figure.zPosition = Self.figureDepth - depth
        // The bubble over the night's shade and the lit windows: under them it was dimmed, and a
        // building's windows showed through it (the user, 2026-11-20). The nearer walker's on top.
        bubble?.zPosition = Self.bubbleDepth + min(50, max(-50, depth * 0.001)) - (depth - body.zPosition)
    }

    /// `badge`: BOT after the name.
    init(cycle: WalkCycle, label: String?, labelColor: UIColor = .white, badge: PlayerBadge? = nil) {
        self.cycle = cycle
        sprite = SKSpriteNode(texture: cycle.frames(.down).first, size: cycle.size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        super.init()
        super.addChild(body)
        // The trees' shade's colour, multiplied over the ground as the figure is.
        shadow.color = Self.figureColor
        shadow.colorBlendFactor = 1
        shadow.blendMode = .multiply
        shadow.shader = Self.round
        shadow.zPosition = -1
        addChild(shadow)
        figure.size = cycle.size
        figure.anchorPoint = sprite.anchorPoint
        figure.color = Self.figureColor
        figure.colorBlendFactor = 1
        figure.blendMode = .multiply
        figure.shader = Self.soften
        showFrame()
        figure.zPosition = -1
        standFigure()
        addChild(figure)
        figure.run(.repeatForever(.customAction(withDuration: 1) { [weak self] _, _ in self?.followFigure() }))
        cast(from: Self.sun)
        Self.everyone.add(self)
        addChild(turn)
        turn.addChild(sprite)
        // It starts out looking the way its picture does.
        goingRight = cycle.facesRight
        Self.lit(sprite)
        if let label {
            let tag = NameTag(label, color: labelColor, size: 11, badge: badge)
            tag.position = CGPoint(x: 0, y: cycle.size.height * 0.95)
            addChild(tag)
            self.tag = tag
        }
        animate()
        blink()
    }

    /// Swaps the look (after customising the hero or recolouring a companion).
    func setCycle(_ cycle: WalkCycle) {
        self.cycle = cycle
        sprite.size = cycle.size
        figure.size = cycle.size
        standFigure()
        cast(from: Self.sun)
        mirror()
        animate()
        blink()
    }

    /// Shuts its eyes a moment every few seconds while it stands still, if it has any to shut.
    private func blink() {
        removeAction(forKey: "blink")
        eyesShut = false
        guard cycle.poses.values.contains(where: { $0.shut != nil }) else { return }
        run(EyeBlink.blinking(shut: .run { [weak self] in self?.setEyes(shut: true) },
                              open: .run { [weak self] in self?.setEyes(shut: false) }), withKey: "blink")
    }

    private func setEyes(shut: Bool) {
        guard idles else { return }
        eyesShut = shut
        showPose()
    }

    /// Standing still, the pose it's in: its first frame, breathing out or not, its eyes open or shut.
    private func showPose() {
        guard !isWalking, let open = cycle.frames(facing).first else { return }
        let pose = cycle.poses[facing]
        let texture = switch (breathingOut, eyesShut) {
        case (false, false): open
        case (false, true): pose?.shut ?? open
        case (true, false): pose?.out ?? open
        case (true, true): pose?.outShut ?? pose?.out ?? open
        }
        if sprite.texture !== texture { sprite.texture = texture }
    }

    /// Turns a single picture to look the way it's going across the screen (`dx`, ignored when it
    /// goes mostly up or down), mirrored when that's not the way the picture looks.
    private func lean(_ dx: CGFloat, of length: CGFloat) {
        if abs(dx) > length * 0.3 { goingRight = dx > 0 }
        mirror()
    }

    private func mirror() {
        turn.xScale = cycle.mirrors && goingRight != cycle.facesRight ? -1 : 1
        figure.xScale = turn.xScale * (facing == .left || facing == .right ? Self.figureWidth.side : Self.figureWidth.front)
    }

    // MARK: Wading

    /// How wide its frame is, in whole points (for `wade`).
    var frameWidth: Int { Int(cycle.size.width.rounded()) }

    /// Holds the sprite once it's first waded through tall grass (`wade`), cutting off what the
    /// grass in front of it hides.
    private var wading: SKCropNode?
    /// The cut's columns, a point wide each, across the frame from its left.
    private var cutColumns: [SKSpriteNode] = []

    /// Hides its legs in tall grass (`GrassField.cover`; after SpriteCook's interactive tall grass
    /// article, the "wading cut"): `hidden[i]` is how many points over its feet are hidden in the
    /// frame's column `i` from the left as it shows on screen, nil or all 0 for none. With only the
    /// tufts sorted in front of it, its legs showed through the gaps between them.
    func wade(_ hidden: [CGFloat]?) {
        guard let hidden, hidden.contains(where: { $0 > 0 }) else {
            if let wading, wading.maskNode != nil { wading.maskNode = nil }
            return
        }
        let crop: SKCropNode
        if let wading {
            crop = wading
        } else {
            crop = SKCropNode()
            sprite.removeFromParent()
            crop.addChild(sprite)
            turn.addChild(crop)
            wading = crop
        }
        let width = Int(cycle.size.width.rounded())
        if cutColumns.count != width {
            let mask = SKNode()
            cutColumns = (0..<width).map { _ in
                let column = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
                column.anchorPoint = CGPoint(x: 0, y: 0)
                mask.addChild(column)
                return column
            }
            crop.maskNode = mask
        } else if crop.maskNode == nil, let mask = cutColumns.first?.parent {
            crop.maskNode = mask
        }
        // From its feet to well over its head; mirrored with the sprite when it's turned.
        let top = cycle.size.height * 2
        let mirrored = turn.xScale < 0
        for (index, column) in cutColumns.enumerated() {
            let onScreen = mirrored ? width - 1 - index : index
            let cut = onScreen < hidden.count ? max(0, hidden[onScreen]) : 0
            // `hidden` counts from its position, where its feet stand.
            let bottom = cut > 0 ? cut : -cycle.size.height
            column.position = CGPoint(x: CGFloat(index) - CGFloat(width) / 2, y: bottom)
            column.size = CGSize(width: 1, height: max(1, top - bottom))
        }
    }

    /// Shows the weapon in hand.
    func setWeapon(_ weapon: ItemDef?) {
        sprite.childNode(withName: "weapon")?.removeFromParent()
        if let weapon, let node = GearArt.weapon(weapon, height: cycle.size.height) {
            Self.lit(node)
            sprite.addChild(node)
        }
        // From the walk's first frame, the weapon in step with it.
        animate()
    }

    /// Takes on the light of the land it's in now (`Walker.light`), as if made there: the hero and
    /// the party walking over a border into a land next door.
    func relight() {
        sprite.colorBlendFactor = 0
        Self.lit(sprite)
        if let weapon = sprite.childNode(withName: "weapon") as? SKSpriteNode {
            weapon.colorBlendFactor = 0
            Self.lit(weapon)
        }
    }

    /// Tints a sprite with the map's light, so characters take on the colours around them.
    private static func lit(_ node: SKSpriteNode) {
        guard let light else { return }
        node.color = light.color
        node.colorBlendFactor = light.strength
    }

    private func poseGear() {
        guard let weapon = sprite.childNode(withName: "weapon") as? SKSpriteNode else { return }
        weapon.removeAction(forKey: "walk")
        GearArt.pose(weapon, facing: facing, height: cycle.size.height)
        guard isWalking else { return }
        // In hand as the walk goes, frame by frame in step with it (`animate`): it bobs as the body does.
        let frames = cycle.frames(facing)
        guard frames.count > 1 else { return }
        let steps = frames.flatMap { frame -> [SKAction] in
            [.move(to: GearArt.grip(on: sprite, frame: frame, facing: facing, height: cycle.size.height, drop: GearArt.drop(of: weapon)), duration: 0), .wait(forDuration: 0.16)]
        }
        weapon.run(.repeatForever(.sequence(steps)), withKey: "walk")
    }

    func setLabel(_ text: String) {
        tag?.setText(text)
    }

    func setBadge(_ badge: PlayerBadge?) {
        tag?.setBadge(badge)
    }

    func setLabelColor(_ color: UIColor) {
        tag?.setColor(color)
    }

    /// A title worn over the name (Character → Titles), in small gold letters; it shows and hides
    /// with the name.
    /// The title worn over the name, in its rank's colour (TitleBadge's, on the map).
    func setTitle(_ title: TitleDef?) {
        guard title?.name != shownTitle else { return }
        shownTitle = title?.name
        titleTag?.removeFromParent()
        titleTag = nil
        guard let title, let tag else { return }
        let node = NameTag(title.name, color: TitleBadge.mapColor(rank: title.tier), size: 9)
        node.position = CGPoint(x: 0, y: 15)
        tag.addChild(node)
        titleTag = node
    }

    /// Shows the name tag for a few seconds, whatever its mode (someone tapped them).
    func revealTag(for duration: TimeInterval = 4) {
        revealed = true
        refreshTag()
        run(.sequence([.wait(forDuration: duration), .run { [weak self] in
            self?.revealed = false
            self?.refreshTag()
        }]), withKey: "reveal")
    }

    private func refreshTag() {
        guard let tag else { return }
        let show = switch tagMode {
        case .always: true
        case .whenStill: !isWalking || revealed
        case .whenClear: (!isWalking && !crowded) || revealed
        case .onDemand: isNear || revealed
        }
        guard show != tagShown else { return }
        let first = tagShown == nil
        tagShown = show
        tag.removeAction(forKey: "fade")
        if first {
            tag.alpha = show ? 1 : 0
        } else if show {
            // A short pause first, so the party's names don't blink on every brief stop.
            let delay = (tagMode == .whenStill || tagMode == .whenClear) && !revealed ? 0.6 : 0
            tag.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.2)]), withKey: "fade")
        } else {
            tag.run(.fadeOut(withDuration: 0.2), withKey: "fade")
        }
    }

    /// A speech bubble above the name tag for a few seconds.
    func say(_ text: String, for duration: TimeInterval = 3.5) {
        bubble?.removeFromParent()
        let node = Nodes.speechBubble(text)
        node.position = CGPoint(x: 0, y: (tag?.position.y ?? sprite.size.height) + 20)
        node.zPosition = 6_000
        node.alpha = 0
        node.setScale(0.6)
        addChild(node)
        bubble = node
        let pop = SKAction.group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.15)])
        node.run(.sequence([pop, .wait(forDuration: duration), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    /// An emote over its head (`Emote`), where a speech bubble would be, for a few seconds: popped up
    /// a little past its size and settling, in whole steps, then gone.
    func emote(_ emote: Emote, for duration: TimeInterval = 2.8) {
        // In the bubble speech has, its picture in it; its own drawn bubble if that's missing.
        let node: SKSpriteNode
        if let icon = emote.icon {
            node = Nodes.emoteBubble(icon)
            node.position = CGPoint(x: 0, y: (tag?.position.y ?? sprite.size.height) + 20)
        } else if let texture = emote.texture {
            let size = texture.size()
            node = SKSpriteNode(texture: texture, size: CGSize(width: size.width * PondMotion.pixel, height: size.height * PondMotion.pixel))
            node.anchorPoint = CGPoint(x: 0.3, y: 0)
            node.position = CGPoint(x: 6, y: (tag?.position.y ?? sprite.size.height) + 14)
        } else {
            return
        }
        bubble?.removeFromParent()
        node.zPosition = 6_000
        node.setScale(0.5)
        addChild(node)
        bubble = node
        node.accessibilityLabel = emote.label
        node.run(.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1, duration: 0.06),
                            .wait(forDuration: duration), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    /// Where this walker has just been, newest first, a step apart: ground it stood on, so a
    /// follower can always walk there.
    private var footsteps: [CGPoint] = []
    /// How much longer a follower keeps to its leader's footsteps after its usual place was blocked.
    private var trailing: TimeInterval = 0

    /// Notes where it stands now. Call it every frame on anyone who's followed (the hero, an
    /// adventurer with a pet).
    func markFootstep() {
        if let last = footsteps.first {
            let gap = last.distance(to: position)
            if gap < 6 { return }
            // A jump (a new map, a road bounced back from): the old trail leads nowhere now.
            if gap > 200 { footsteps = [] }
        }
        footsteps.insert(position, at: 0)
        // Enough for a full party in single file (about 400 px).
        if footsteps.count > 64 { footsteps.removeLast() }
    }

    /// The stride frame its foot last came down on (`footfall`), and how many it's put down, so its
    /// prints fall left and right by turns.
    private var lastStride: SKTexture?
    private var strides = 0

    /// Where a foot of its has just come down, in its parent's points, or nil. A walk sheet's
    /// strides are frames 0 and 2 (one foot forward), its feet together 1 and 3: a foot comes down
    /// as a stride frame starts (`Footprints`, tools/snow_trail_preview.py). Only a four-frame walk
    /// sheet: a hopping monster leaves none.
    func footfall() -> CGPoint? {
        let frames = cycle.frames(facing)
        guard isWalking, frames.count == 4, let shown = sprite.texture else {
            lastStride = nil
            return nil
        }
        guard shown === frames[0] || shown === frames[2], shown !== lastStride else { return nil }
        lastStride = shown
        strides += 1
        let side: CGFloat = strides % 2 == 0 ? 1 : -1
        let offset = facing.isHorizontal ? CGVector(dx: 0, dy: Footprints.apart.along * side)
            : CGVector(dx: Footprints.apart.across * side, dy: 0)
        return CGPoint(x: position.x + offset.dx, y: position.y + lift + feet + offset.dy)
    }

    /// Every footfall in the scene `space` is in this frame (`footfall`), in `space`'s points.
    static func footfalls(in space: SKNode) -> [CGPoint] {
        everyone.allObjects.compactMap { walker -> CGPoint? in
            guard walker.scene === space.scene, !walker.isHidden, let parent = walker.parent,
                  let point = walker.footfall() else { return nil }
            return parent.convert(point, to: space)
        }
    }

    /// The point `distance` back along its footsteps. Where they don't go back that far (it's only
    /// just arrived), the rest is straight back from the way it faces.
    func footstep(behind distance: CGFloat) -> CGPoint {
        var previous = position
        var left = distance
        for point in footsteps {
            let gap = previous.distance(to: point)
            if gap > 0, gap >= left { return previous + (point - previous) * (left / gap) }
            left -= gap
            previous = point
        }
        return previous + facing.vector * -left
    }

    /// Trails behind `leader` like a companion: close enough to feel together, never on top. It keeps
    /// to ground it can stand on: when its place beside the leader is in water or a wall, or one is in
    /// the way, it walks to `footstep` instead (its place in single file on the trail of whoever leads
    /// the line), and it slides along whatever's in its way like the hero does. `beside`: at the
    /// leader's side instead (a friend's companion, with the next friend walking behind them).
    func follow(_ leader: Walker, dt: TimeInterval, footstep: CGPoint, canStand: (CGPoint) -> Bool, beside: Bool = false) {
        let behind = leader.facing.vector * -1
        var goal: CGPoint
        if beside {
            let side = CGVector(dx: -behind.dy, dy: behind.dx)
            goal = leader.position + side * 26 + behind * 8
        } else if leader.facing.isHorizontal {
            goal = leader.position + behind * 34 + CGVector(dx: 0, dy: 6)
        } else {
            goal = leader.position + behind * 14 + CGVector(dx: -30, dy: 0)
        }
        // Once blocked, it keeps to the footsteps a moment, so it doesn't dither along a ragged shore.
        if !Self.isClear(from: position, to: goal, canStand) { trailing = 0.6 }
        if trailing > 0 {
            trailing -= dt
            goal = footstep
        }
        let offset = goal - position
        let distance = offset.length
        // While the leader walks it walks too, right up to its place. Followers are quicker than
        // you, so they caught up, stopped within a few points of their place and stepped on again:
        // every stop and start began the walk from its first frame, so they seemed to slide.
        if distance > 300 {
            position = goal
        } else if distance > 6 || (leader.isWalking && distance > 0.5) {
            let step = min(distance, max(walkSpeed, distance * 2) * CGFloat(dt))
            let move = offset * (step / distance)
            var next = position + move
            // Stuck in a wall already (just arrived)? Then walk straight out; otherwise don't walk in.
            if canStand(position), !canStand(next) {
                let alongX = CGPoint(x: position.x + move.dx, y: position.y)
                let alongY = CGPoint(x: position.x, y: position.y + move.dy)
                next = canStand(alongX) ? alongX : canStand(alongY) ? alongY : position
            }
            position = next
            face(Direction(offset, current: facing))
            lean(offset.dx, of: distance)
            setWalking(true)
        } else {
            setWalking(false)
            face(leader.facing)
        }
        if tagMode == .whenClear { crowded = tagCrowds(leader) }
    }

    /// Walks on toward `goal` as a follower walks to its place (`follow`), on while `going` (whoever
    /// it's following is walking) or still a few points off, sliding along whatever's in its way: the
    /// hero in a party they've joined, at the back of its line (`Crowd.yourPlace`).
    func walk(toward goal: CGPoint, going: Bool, dt: TimeInterval, canStand: (CGPoint) -> Bool) {
        let offset = goal - position
        let distance = offset.length
        guard distance > 6 || (going && distance > 0.5) else {
            setWalking(false)
            return
        }
        let step = min(distance, max(walkSpeed, distance * 2) * CGFloat(dt))
        let move = offset * (step / distance)
        var next = position + move
        if !canStand(next) {
            let alongX = CGPoint(x: position.x + move.dx, y: position.y)
            let alongY = CGPoint(x: position.x, y: position.y + move.dy)
            next = canStand(alongX) ? alongX : canStand(alongY) ? alongY : position
        }
        let moved = next != position
        position = next
        face(Direction(offset, current: facing))
        setWalking(moved)
    }

    /// Whether its name tag, where it stands now, would print over `other`'s.
    func tagCrowds(_ other: Walker) -> Bool {
        guard let tag, let theirs = other.tag else { return false }
        let mine = tag.calculateAccumulatedFrame().offsetBy(dx: position.x, dy: position.y)
        let them = theirs.calculateAccumulatedFrame().offsetBy(dx: other.position.x, dy: other.position.y)
        return mine.insetBy(dx: -4, dy: -2).intersects(them)
    }

    /// Whether the way from `start` to `end`, and `end` itself, is all ground to stand on.
    private static func isClear(from start: CGPoint, to end: CGPoint, _ canStand: (CGPoint) -> Bool) -> Bool {
        let offset = end - start
        let steps = max(1, Int(offset.length / 8))
        for index in 1...steps where !canStand(start + offset * (CGFloat(index) / CGFloat(steps))) {
            return false
        }
        return true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var headTop: CGPoint { CGPoint(x: position.x, y: position.y + sprite.size.height + 14) }

    /// Walks along `path`; returns true while there's still somewhere to go.
    @discardableResult
    func followPath(dt: TimeInterval) -> Bool {
        guard let next = path.first else { return false }
        let offset = next - position
        let distance = offset.length
        let step = walkSpeed * CGFloat(dt)
        if distance <= step {
            position = next
            path.removeFirst()
        } else {
            position = position + offset * (step / distance)
            face(Direction(offset, current: facing))
            lean(offset.dx, of: distance)
        }
        return !path.isEmpty
    }

    func face(_ direction: Direction) {
        if direction == .left || direction == .right { lean(direction == .right ? 1 : -1, of: 1) }
        guard direction != facing else { return }
        facing = direction
        animate()
    }

    func setWalking(_ walking: Bool) {
        guard walking != isWalking else { return }
        isWalking = walking
        animate()
        refreshTag()
        if walking {
            removeAction(forKey: "fidget")
            removeAction(forKey: "glance")
        } else if fidgets {
            startFidgeting()
        }
    }

    private func startFidgeting() {
        let fidget = SKAction.sequence([.wait(forDuration: 5, withRange: 4), .run { [weak self] in self?.fidget() }])
        run(.repeatForever(fidget), withKey: "fidget")
    }

    /// Look left and right, or have a little stretch.
    private func fidget() {
        guard !isWalking else { return }
        if Bool.random() {
            let original = facing
            let sides: [Direction] = original.isHorizontal ? [.down, original == .left ? .right : .left] : [.left, .right].shuffled()
            run(.sequence([
                .run { [weak self] in self?.face(sides[0]) }, .wait(forDuration: 0.7),
                .run { [weak self] in self?.face(sides[1]) }, .wait(forDuration: 0.7),
                .run { [weak self] in self?.face(original) },
            ]), withKey: "glance")
        } else {
            let stretch = SKAction.sequence([.scaleY(to: 1.12, duration: 0.18), .scaleY(to: 0.94, duration: 0.12), .scaleY(to: 1, duration: 0.14)])
            stretch.timingMode = .easeInEaseOut
            sprite.run(stretch, withKey: "stretch")
        }
    }

    private func animate() {
        sprite.removeAction(forKey: "walk")
        sprite.removeAction(forKey: "idle")
        sprite.position = .zero
        sprite.xScale = 1
        sprite.yScale = 1
        sprite.zRotation = 0
        breathingOut = false
        let frames = cycle.frames(facing)
        sprite.texture = frames.first
        poseGear()
        guard isWalking else {
            breathe()
            return
        }
        if frames.count > 1 {
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.16)), withKey: "walk")
        } else {
            let up = SKAction.moveBy(x: 0, y: 5, duration: 0.13)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -5, duration: 0.13)
            down.timingMode = .easeIn
            sprite.run(.repeatForever(.sequence([up, down])), withKey: "walk")
        }
        sprite.action(forKey: "walk")?.speed = pace
    }

    /// Standing still: breathing for people, a squish, hop or sway for monsters. A walk sheet
    /// breathes in whole pixels (`IdlePose.out`), where stretching the sprite smeared them.
    private func breathe() {
        guard idles else { return }
        if eyesShut { showPose() }
        guard motion == .breathe, cycle.poses[facing]?.out != nil else {
            sprite.run(motion.action(height: sprite.size.height, delay: breathOffset), withKey: "idle")
            return
        }
        let breath = SKAction.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.setBreath(out: true) },
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.setBreath(out: false) },
        ])
        sprite.run(.sequence([.wait(forDuration: breathOffset), .repeatForever(breath)]), withKey: "idle")
    }

    private func setBreath(out: Bool) {
        breathingOut = out
        showPose()
    }
}
