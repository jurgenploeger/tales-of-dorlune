import SpriteKit
import UIKit

nonisolated struct ArtManifest: Decodable {
    let assets: [ArtAsset]
}

/// One entry of art/assets.json. The `request` block is only used by tools/rd.py.
nonisolated struct ArtAsset: Decodable {
    let id: String
    /// walk_sheet | npc | monster | tile | prop | building
    let kind: String
    /// Frame size in pixels for walk sheets.
    let frame: Int?
    /// Which direction each sheet row faces, top to bottom.
    let directions: [String]?
    /// Optional draw-size multiplier. Stick to whole numbers to keep pixels square.
    let scale: Double?
    /// A free palette-swapped copy of another sprite (used until this one gets its own PNG).
    let derive: Derivation?
    /// Which way a single picture looks, "left" (when not given) or "right": it has no side views,
    /// so walking the other way it's mirrored (`WalkCycle.mirrors`). A copy looks the way its base does.
    let faces: String?
}

/// One paper-doll layer (an art/sprites PNG) and how it's recoloured before stacking: by its own
/// rules, or with nil by the sprite's (`ArtLibrary.register`'s `recolor`, or its `derive`'s).
nonisolated struct ArtLayer: Decodable, Sendable {
    let id: String
    var recolor: [RecolorRule]? = nil
}

/// A texture plus the size it should be drawn at.
struct SpriteArt {
    let texture: SKTexture
    let size: CGSize
}

/// A directional walk cycle. The first frame of each direction doubles as the idle pose.
struct WalkCycle {
    let frames: [Direction: [SKTexture]]
    let size: CGSize
    /// A single picture that looks right (`ArtAsset.faces`); most look left or straight at you.
    var facesRight = false
    /// Each direction's standing pose breathing out, and with its eyes shut for a blink: none for a
    /// sprite with no eyes (art/eyes.json) and no walk sheet.
    var poses: [Direction: IdlePose] = [:]

    func frames(_ direction: Direction) -> [SKTexture] {
        frames[direction] ?? frames[.down] ?? []
    }

    /// The same picture whichever way it goes (a single image, or a sheet with no side views): it's
    /// mirrored to walk the other way.
    var mirrors: Bool {
        frames(.left).first === frames(.right).first
    }
}

/// A standing pose (a walk cycle's first frame) as it breathes and blinks: a pixel lower breathing
/// out (`out`), its eyes shut (`shut`), or both.
struct IdlePose {
    var shut: SKTexture?
    var out: SKTexture?
    var outShut: SKTexture?
}

/// Loads Retro Diffusion sprites from the bundled `art/` folder, falling back to
/// placeholder pixel art for anything that hasn't been generated yet.
final class ArtLibrary {
    static let shared = ArtLibrary()

    private let manifest: ArtManifest
    private var textures: [String: SKTexture] = [:]
    private var cycles: [String: WalkCycle] = [:]
    private var images: [String: UIImage] = [:]
    /// Sprites made at runtime (the customised hero, recoloured companions), keyed by id.
    private var runtime: [String: (asset: ArtAsset, key: String)] = [:]
    /// Gear drawn onto runtime sprites after their recolour (the hero's armour and boots).
    private var gearLooks: [String: GearLook] = [:]
    /// Paper-doll layers stacked in place of a runtime sprite's base (body, locks, then hair or headgear).
    private var layerSets: [String: [ArtLayer]] = [:]

    init() {
        do {
            guard let url = Bundle.main.url(forResource: "assets", withExtension: "json", subdirectory: "art") else {
                throw CocoaError(.fileNoSuchFile)
            }
            manifest = try JSONDecoder().decode(ArtManifest.self, from: Data(contentsOf: url))
        } catch {
            print("⚠️ Couldn't read art/assets.json: \(error)")
            manifest = ArtManifest(assets: [])
        }
    }

    /// The current map's colour grade, and which map it belongs to.
    private var palette: MapPalette?
    private var paletteMap: String?
    /// Sprite kinds that take on a map's palette.
    private static let gradedKinds: Set<String> = ["tile", "prop", "building"]

    /// Ground, scenery and buildings graded for the map the library grades for now (`use`).
    private var gradedTextures: [String: SKTexture] = [:]
    /// Another map's graded art, kept while it may be wanted again: a land next door, on screen
    /// past the border or being built while you walk toward it, takes turns with the one you're in.
    private struct Graded {
        let palette: MapPalette?
        let textures: [String: SKTexture]
        let blended: [String: SKTexture]
        let tileImages: [String: CGImage]
        let variants: [String: [UInt8]]
    }
    private var stashed: [String: Graded] = [:]
    /// The stashed maps, the longest unused first. A few at most: the land you're in, those beside
    /// it and the one you came from.
    private var stashOrder: [String] = []
    private static let stashLimit = 4

    /// The palette and map the library grades for now, to go back to (`use`).
    var grading: (palette: MapPalette?, map: String?) { (palette, paletteMap) }

    /// Grades ground, scenery and buildings with `map`'s palette from now on. Sprites already
    /// on screen keep their textures. The art graded for the map before is put aside, and taken
    /// up again if it comes back soon, so lands can take turns cheaply.
    func use(palette: MapPalette?, for map: String) {
        guard map != paletteMap else { return }
        if let current = paletteMap {
            stashed[current] = Graded(palette: self.palette, textures: gradedTextures, blended: blended, tileImages: tileImages, variants: variantCache)
            stashOrder.removeAll { $0 == current }
            stashOrder.append(current)
        }
        let kept = stashed.removeValue(forKey: map)
        stashOrder.removeAll { $0 == map }
        while stashOrder.count > Self.stashLimit { stashed[stashOrder.removeFirst()] = nil }
        paletteMap = map
        self.palette = palette
        gradedTextures = kept?.textures ?? [:]
        blended = kept?.blended ?? [:]
        tileImages = kept?.tileImages ?? [:]
        variantCache = kept?.variants ?? [:]
    }

    /// `make` run grading for `map` with `palette`, then back to whichever map it was grading for:
    /// for art graded lazily, whoever asks for it, so it never takes the palette of whatever land's
    /// work happened to run last (`GroundTiles`; playtesting 2026-11-14 saw a block of Emerald
    /// Road's ground pale, as if graded with another land's palette).
    func grading<T>(palette: MapPalette?, for map: String, _ make: () -> T) -> T {
        guard map != paletteMap else { return make() }
        let previous = paletteMap, previousPalette = self.palette
        use(palette: palette, for: map)
        defer { if let previous { use(palette: previousPalette, for: previous) } }
        return make()
    }

    /// Lets go of a map's graded art: nothing of it is on screen any more.
    func release(map: String) {
        guard map != paletteMap else { return }
        stashed[map] = nil
        stashOrder.removeAll { $0 == map }
    }

    /// Lets go of what it kept for textures that are gone (their images, `sources`, and wind
    /// strips): after a land's let go (`ContinentScene.letGoFarLands`), not only once thousands
    /// have piled up.
    func letGoOfSources() {
        guard sources.count > 512 || windStrips.count > 64 else { return }
        sources = sources.filter { $0.value.texture != nil }
        windStrips = windStrips.filter { $0.value.texture != nil }
    }

    /// A tile's image graded with `palette`, whatever map the library is grading for right now: the
    /// HUD draws a new map's minimap as soon as the scene exists, before its `build` takes the
    /// library over from the map you came from.
    func gradedTile(_ id: String, palette: MapPalette?) -> CGImage? {
        guard let image = sourceImage(id) else { return nil }
        guard let palette else { return image }
        return Recolor.grade(palette, image: image) ?? image
    }

    /// The sprite's image with the current map's palette, for ground, scenery and buildings.
    private func gradedImage(_ id: String) -> CGImage? {
        guard let image = sourceImage(id) else { return nil }
        guard let palette, Self.gradedKinds.contains(kind(of: id)) else { return image }
        return Recolor.grade(palette, image: image) ?? image
    }

    /// Registers (or updates) a recoloured copy of `base` under `id`, e.g. the customised hero.
    /// `key` identifies the look, so re-registering the same look is free.
    /// `layers` (art/sprites PNGs, bottom first) replace the base's own picture when they all exist;
    /// the base still supplies the frame size and directions.
    func register(_ id: String, from base: String, recolor rules: [RecolorRule], key: String, gear: GearLook? = nil,
                  layers: [ArtLayer]? = nil) {
        guard runtime[id]?.key != key else { return }
        let kind = asset(base)?.kind ?? "monster"
        runtime[id] = (ArtAsset(id: id, kind: kind, frame: nil, directions: nil, scale: nil, derive: Derivation(from: base, recolor: rules), faces: nil), key)
        gearLooks[id] = gear
        layerSets[id] = layers
        textures[id] = nil
        gradedTextures[id] = nil
        cycles[id] = nil
        images = images.filter { $0.key != id && !$0.key.hasPrefix(id + "#") }
    }

    /// The sprite's own art as an image, or nil when it has none yet (no placeholder).
    func artImage(_ id: String) -> UIImage? {
        let cacheKey = "art:" + id
        if let cached = images[cacheKey] { return cached }
        guard let cgImage = sourceImage(id) else { return nil }
        let image = UIImage(cgImage: cgImage)
        images[cacheKey] = image
        return image
    }

    /// A one-off recoloured portrait for pickers and previews (cached by `key`).
    func preview(from base: String, recolor rules: [RecolorRule], key: String, facing direction: Direction = .down,
                 layers: [ArtLayer]? = nil) -> UIImage {
        let id = "preview:" + base + ":" + key + ":" + (layers ?? []).map(\.id).joined(separator: "+")
        register(id, from: base, recolor: rules, key: key, layers: layers)
        return image(id, facing: direction)
    }

    func asset(_ id: String) -> ArtAsset? {
        guard let own = manifest.assets.first(where: { $0.id == id }) ?? runtime[id]?.asset ?? dyedAsset(id) else { return nil }
        // The base can itself be derived (hero → human_female_walk → player_walk): resolve it fully, or
        // the frame size and direction order are lost and the wrong row shows (her back for "down").
        guard let derive = own.derive, derive.from != id, let base = asset(derive.from) else { return own }
        return ArtAsset(id: own.id, kind: own.kind, frame: own.frame ?? base.frame, directions: own.directions ?? base.directions,
                        scale: own.scale ?? base.scale, derive: derive, faces: own.faces ?? base.faces)
    }

    /// A dyed piece's icon (`ItemDef.dyed`): "<its piece's art>~<dye id>~<trim dye id>", that art
    /// recoloured toward the dyes (`Recolor.dyeRules`, from the picture's own main colour and trim), made
    /// the first time it's asked for and kept like the hero's. A weapon's held sprites ("held_<id>_side",
    /// "_front": PNGs with no entry in the manifest) take their colours from its icon, so its blade and
    /// hilt are dyed alike in the hand and in the bag.
    private func dyedAsset(_ id: String) -> ArtAsset? {
        guard id.contains(ItemDef.dyeMark) else { return nil }
        let base = ItemDef.baseID(of: id)
        let main = ItemDef.dyeID(of: id).flatMap { Content.shared.item($0)?.dye }
        let trim = ItemDef.trimDyeID(of: id).flatMap { Content.shared.item($0)?.dye }
        guard main != nil || trim != nil,
              let kind = manifest.assets.first(where: { $0.id == base })?.kind ?? (pngURL(base) != nil ? "item" : nil) else { return nil }
        let item = Self.heldWeapon(base).flatMap { Content.shared.item($0) } ?? Content.shared.items.first { $0.art == base }
        guard let own = sourceImage(base) else { return nil }
        let icon = item?.art.flatMap { $0 == base ? nil : sourceImage($0) }
        let weapon = item?.type == .weapon
        let rules = Recolor.dyeRules(for: icon ?? own, main: main, trim: trim, weapon: weapon, on: icon == nil ? nil : own)
        // An axe's handle is a layer of its own ("<art>_haft", tools/dye_art.py hafts), laid over the
        // picture dyed and recoloured by its trim dye alone: a dye takes the head, never the handle
        // (playtesting 2026-10-31: "Make sure that the handles of all axes items won't be changed with the dye").
        let haft = base + "_haft"
        var derivation = Derivation(from: base, recolor: rules)
        if pngURL(haft) != nil {
            let haftRules = trim == nil ? [] : Recolor.dyeRules(for: icon ?? own, main: nil, trim: trim, weapon: weapon, on: icon == nil ? nil : own)
            derivation.layers = [ArtLayer(id: base), ArtLayer(id: haft, recolor: haftRules)]
        }
        let made = ArtAsset(id: id, kind: kind, frame: nil, directions: nil, scale: nil,
                            derive: derivation, faces: nil)
        runtime[id] = (made, id)
        return made
    }

    /// The weapon a held sprite is of: "held_<id>_side" or "held_<id>_front".
    private static func heldWeapon(_ art: String) -> String? {
        guard art.hasPrefix("held_") else { return nil }
        for suffix in ["_side", "_front"] where art.hasSuffix(suffix) {
            return String(art.dropFirst("held_".count).dropLast(suffix.count))
        }
        return nil
    }

    private func kind(of id: String) -> String {
        asset(id)?.kind ?? "monster"
    }

    private func pngURL(_ id: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: "png", subdirectory: "art/sprites")
    }

    /// The generated PNG for `id` (art/sprites/<id>.png), or nil if it doesn't exist yet.
    func generatedTexture(_ id: String) -> SKTexture? {
        if let cached = gradedTextures[id] ?? textures[id] { return cached }
        guard let image = gradedImage(id) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        remember(image, for: texture)
        if Self.gradedKinds.contains(kind(of: id)) {
            gradedTextures[id] = texture
        } else {
            textures[id] = texture
        }
        return texture
    }

    /// The sprite's own PNG, or — for derived sprites — its base's PNG with the palette swap applied.
    /// `shut`: its eyes shut for a blink (art/eyes.json), on its own PNG or on its paper-doll layers
    /// before they're recoloured and dressed, so whatever is drawn over the face still is.
    private func sourceImage(_ id: String, depth: Int = 0, shut: Bool = false) -> CGImage? {
        // "raw:<id>": the art as it's drawn, graded for no map (the sea, the same blue round every land).
        if id.hasPrefix("raw:") { return sourceImage(String(id.dropFirst(4)), depth: depth, shut: shut) }
        if let url = pngURL(id), let image = UIImage(contentsOfFile: url.path)?.cgImage {
            return shut ? eyesShut(in: image, as: id, frames: sheetFrames(id, width: image.width, height: image.height)) : image
        }
        guard depth < 3, let derive = asset(id)?.derive else { return nil }
        let base: CGImage
        let recolored: CGImage?
        // Paper-doll layers are recoloured one by one (a layer's own rules, like the hair's, touch
        // only that layer), then stacked.
        let layers = layerSets[id] ?? derive.layers
        // The layers' frames lie as the sprite's do.
        let frames = shut ? layers?.first.flatMap { pngSize($0.id) }.flatMap { sheetFrames(id, width: $0.width, height: $0.height) } : nil
        if let layers, let original = stacked(layers, shut: frames),
           let dressed = stacked(layers, recolor: derive.recolor, shut: frames) {
            base = original
            recolored = dressed
        } else if let sheet = sourceImage(derive.from, depth: depth + 1, shut: shut) {
            base = sheet
            recolored = Recolor.apply(derive.recolor, to: sheet)
        } else {
            return nil
        }
        if let gear = gearLooks[id], let recolored, let from = asset(derive.from) {
            let directions = from.directions ?? ["up", "right", "down", "left"]
            // The plain body the hands, chin and boots are found on (GearLook.body).
            let skeleton = gear.body.flatMap { pngURL($0) }.flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            // Where gloves and boots go on that body, marked frame by frame (tools/worn_marks.py).
            let marks = gear.body.flatMap { $0.hasPrefix("body_") ? pngURL("marks_" + String($0.dropFirst("body_".count))) : nil }
                .flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            // A festive hat's piece, cut out by tools/wear_art.py (art/sprites/wear_<hat>.png).
            let piece = gear.hat.flatMap { pngURL("wear_\($0)") }.flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            let cape = gear.cape == nil && gear.cloak == nil ? nil : pngURL("wear_cape").flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            let scarf = gear.scarf == nil ? nil : pngURL("wear_scarf").flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            return GearOverlay.apply(gear, original: base, dressed: recolored, skeleton: skeleton, marks: marks, piece: piece,
                                     capePiece: cape, scarfPiece: scarf, frame: from.frame ?? 48, directions: directions)
        }
        return recolored
    }

    /// art/sprites PNGs drawn on top of each other, bottom first; nil unless every one exists.
    /// With `rules`, each layer is recoloured first: by its own rules if it has them, else by these.
    /// With `shut` (where the frames lie), the eyes of the body or head layers are shut first
    /// (`EyeBlink.key(forLayer:)`); an armour sheet's or a helmet's face is left as it is
    /// (`cleanFaces` says where that shows).
    private func stacked(_ layers: [ArtLayer], recolor rules: [RecolorRule]? = nil, shut frames: SheetFrames? = nil) -> CGImage? {
        let images = layers.compactMap { layer -> CGImage? in
            guard var image = pngImage(layer.id) else { return nil }
            if frames != nil, let eyes = EyeBlink.key(forLayer: layer.id) {
                image = eyesShut(in: image, as: eyes, frames: frames)
            }
            guard let rules else { return image }
            return Recolor.apply(layer.recolor ?? rules, to: image)
        }
        guard let first = images.first, images.count == layers.count else { return nil }
        let width = first.width, height = first.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        for image in images {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return context.makeImage()
    }

    func tileTexture(_ id: String) -> SKTexture {
        generatedTexture(id) ?? Placeholder.canvas(for: id, kind: "tile").texture()
    }

    /// Graded tile images and their variants' pixels for the current map (cleared by `use(palette:for:)`).
    private var tileImages: [String: CGImage] = [:]
    private var variantCache: [String: [UInt8]] = [:]

    private func tileImage(_ id: String) -> CGImage {
        if let cached = tileImages[id] { return cached }
        let image = gradedImage(id) ?? Placeholder.canvas(for: id, kind: "tile").cgImage()
        tileImages[id] = image
        return image
    }

    private var blended: [String: SKTexture] = [:]

    /// One layer of an organic ground tile (see `organicTile`).
    nonisolated struct GroundLayer: Sendable {
        /// `cut`: the land's edge over the sea, which lies lower: the pixels past the shore left clear.
        /// `ground`: a land's ground across a band, this one's or (`from`) a land next door's, under
        /// the rest (see `organicTile`).
        nonisolated enum Style: Sendable { case road, patch, water, cut, ground }
        let tile: String
        /// Roads and patches: bit `row * 3 + col` is set where that cell of the 3×3 around this one
        /// holds the layer (row 0 north, col 0 west; bit 4 is the cell itself). Water: the same for
        /// the 5×5 around it (bit `row * 5 + col`, bit 12 is the cell itself).
        let mask: Int
        let style: Style
        /// A land next door's tile, graded with its palette as it is there, not this land's: its
        /// ground in patches across the band between the two (`Seam`).
        var from: Foreign? = nil
        /// A road taking on the land next door's road across the band (`Fade`).
        var fade: Fade? = nil
        /// A road in a town's square: cobbles down its middle, sand and pebbles either side, grass
        /// growing over its edges (`townRoad`, the user's pick from `tools/road_preview.py`, 2026-11-17).
        var cobbled = false
    }

    /// A land next door, for its tiles (`GroundLayer.from`).
    nonisolated struct Foreign: Sendable {
        let land: String
        let palette: MapPalette?
    }

    /// A road across the band between two lands (`Seam`): the land next door's road tile, graded as
    /// it is there, mixed into this land's by `share` (0...1), so the road changes look a little at
    /// a time instead of all at once at the border.
    nonisolated struct Fade: Sendable {
        let tile: String
        let from: Foreign
        let share: Double

        /// What tells one fade from another in a texture's key.
        var key: String { "\(from.land)~\(tile)~\(share)" }
    }

    /// One of four versions of a tile (0 is the tile itself). The others show the texture shifted
    /// and mirrored inside a soft frame of the original, so they share its edges: any mix of them
    /// tiles seamlessly, and big areas stop repeating the same square.
    func tileVariant(_ id: String, _ index: Int) -> SKTexture {
        let key = "variant|\(id)|\(index % 4)"
        if let cached = blended[key] { return cached }
        let image = tileImage(id)
        let size = max(image.width, 16)
        let texture = makeTexture(variantPixels(id, index, size: size), size: size)
        blended[key] = texture
        return texture
    }

    /// A cell of a land's water, out from its shores, in the pond's tones (`pondTones`): each pixel the
    /// tone `tone` gives for where it lies in the world (`GroundTiles.PondField.tone`), with the tile's own
    /// ripples over it. One for each cell, as the tones change across a lake.
    /// `seaward`: how much of the sea's colour the water at a point takes (`seaTones`), near a river's mouth.
    func pondTile(_ id: String, _ index: Int, cell: GridPoint, seaward: ((Double, Double) -> Double)? = nil,
                  across: ((Double, Double) -> (tones: [(r: Double, g: Double, b: Double)], share: Double)?)? = nil,
                  tone: (Double, Double) -> Int) -> SKTexture {
        let key = "pond|\(id)|\(cell.col),\(cell.row)|\(index % 4)"
        if let cached = blended[key] { return cached }
        let size = max(tileImage(id).width, 16)
        let texels = variantPixels(id, index, size: size)
        var out = texels
        let palette = Self.pondPalette(texels)
        for py in 0..<size {
            for px in 0..<size {
                let x = Double(cell.col) + (Double(px) + 0.5) / Double(size)
                let y = Double(cell.row) + 1 - (Double(py) + 0.5) / Double(size)
                let sea = seaward.map { (tones: seaTones, share: $0(x, y)) }
                Self.paintPond(&out, (py * size + px) * 4, texels: texels, tone: tone(x, y), palette: palette, shade: 1, sea: sea,
                               other: across?(x, y))
            }
        }
        let texture = makeTexture(out, size: size)
        blended[key] = texture
        return texture
    }

    /// The tones of a pond (after SpriteCook's "Pixel art pond water: reflections and ripples"; the user,
    /// 2026-11-16: "Yes I want it in the game"): every water pixel one of a few, never a blend. 0 to 6
    /// water from dark to light, each as bright against tone 3 as the article's, in a land's own water
    /// colour (`water`, its tile's average: darker toward a deep blue-green, lighter toward a pale sky),
    /// 7 the shallows over the mud, and 8 and 9 the far bank's mud and grass mirrored under it (the article's,
    /// a little of the water in them). Mirrored in `tools/pond_preview.py` (`toned`).
    /// A warm liquid (chocolate: red well over blue) is darker toward a deep cocoa and lighter toward a
    /// creamy sheen instead, its shallows a little lighter and the bank's mirrored mud and grass taking
    /// more of it: the blue-green pulls turned it grey (the user, 2026-11-25: chocolate lakes had none
    /// of the other water's depth).
    nonisolated static func pondTones(water: (r: Double, g: Double, b: Double)) -> [(r: Double, g: Double, b: Double)] {
        let article: [(Double, Double, Double)] = [(0x1d, 0x3a, 0x44), (0x24, 0x50, 0x5a), (0x2c, 0x66, 0x70), (0x3a, 0x7f, 0x84),
                                                   (0x5a, 0x9f, 0xa0), (0x8c, 0xc8, 0xc0), (0xc4, 0xec, 0xe2), (0x5a, 0x93, 0x84)]
        func bright(_ c: (Double, Double, Double)) -> Double { 0.3 * c.0 + 0.59 * c.1 + 0.11 * c.2 }
        let ref = bright(article[3]), low = bright(article[0]) / ref, top = bright(article[6]) / ref
        let w = (water.r * 0.88, water.g * 0.88, water.b * 0.88)
        let warm = water.r > water.b + 0.08
        let deep: (Double, Double, Double)
        let pale: (Double, Double, Double)
        if warm {
            deep = (w.0 * 0.45, w.1 * 0.4, w.2 * 0.38)
            pale = (w.0 + (1 - w.0) * 0.55, w.1 + (0.86 - w.1) * 0.55, w.2 + (0.72 - w.2) * 0.55)
        } else {
            deep = (w.0 * 0.45 + 0.02, w.1 * 0.45 + 0.05, w.2 * 0.45 + 0.08)
            pale = (w.0 + (0.86 - w.0) * 0.75, w.1 + (0.96 - w.1) * 0.75, w.2 + (0.95 - w.2) * 0.75)
        }
        func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
        var tones: [(r: Double, g: Double, b: Double)] = []
        for k in 0..<7 {
            let f = bright(article[k]) / ref
            if f <= 1 {
                let t = (f - low) / (1 - low)
                tones.append((clamp(deep.0 + (w.0 - deep.0) * t), clamp(deep.1 + (w.1 - deep.1) * t), clamp(deep.2 + (w.2 - deep.2) * t)))
            } else {
                let t = (f - 1) / (top - 1)
                tones.append((clamp(w.0 + (pale.0 - w.0) * t), clamp(w.1 + (pale.1 - w.1) * t), clamp(w.2 + (pale.2 - w.2) * t)))
            }
        }
        let mud = article[7]
        if warm {
            tones.append((clamp(w.0 * 1.08), clamp(w.1 * 1.08), clamp(w.2 * 1.08)))
        } else {
            tones.append((clamp((mud.0 / 255 + w.0) / 2), clamp((mud.1 / 255 + w.1) / 2), clamp((mud.2 / 255 + w.2) / 2)))
        }
        let own = warm ? 0.45 : 0.25
        for bank in [(0x2c, 0x3b, 0x36), (0x2d, 0x52, 0x46)] as [(Double, Double, Double)] {
            tones.append((clamp(bank.0 / 255 * (1 - own) + w.0 * own), clamp(bank.1 / 255 * (1 - own) + w.1 * own),
                          clamp(bank.2 / 255 * (1 - own) + w.2 * own)))
        }
        return tones
    }

    /// Whether a land's water tile is drawn as a pond (`pondTones`, depth, a bank, reflections): its
    /// lakes and rivers, and chocolate's (the user, 2026-11-25); not ice.
    nonisolated static func isPondWater(_ id: String) -> Bool { id == "tile_water" || id == "tile_chocolate" }

    /// The pond tones of a land next door's water (`id`, graded as it is there: `Foreign`), for its
    /// river's colour carried over the border (`paintPond`'s `other`).
    func foreignPondTones(_ id: String, from: Foreign) -> [(r: Double, g: Double, b: Double)] {
        let size = max(tileImage(id).width, 16)
        return Self.pondPalette(foreignPixels(id, palette: from.palette, from: from.land, variant: 0, size: size)).tones
    }

    /// The sea's own pond tones (`pondTones` of its average colour): the sea as it's drawn, graded for
    /// no land, the same blue round every land. What a river turns to as it runs into it (`paintPond`).
    private(set) lazy var seaTones: [(r: Double, g: Double, b: Double)] = {
        let image = picture(of: tileTexture("raw:sea"))
        guard image.width > 0, let texels = PixelImage.pixels(of: image, width: image.width, height: image.height) else { return [] }
        return Self.pondPalette(texels).tones
    }()

    /// Tile `id`'s pond tones and average brightness (`pondPalette`), as graded now.
    func pondPalette(of id: String) -> (tones: [(r: Double, g: Double, b: Double)], mean: Double) {
        Self.pondPalette(variantPixels(id, 0, size: max(tileImage(id).width, 16)))
    }

    /// A water tile's tones (`pondTones`, from its average colour) and its average brightness.
    nonisolated static func pondPalette(_ texels: [UInt8]) -> (tones: [(r: Double, g: Double, b: Double)], mean: Double) {
        var r = 0.0, g = 0.0, b = 0.0
        let count = max(1, texels.count / 4)
        for i in stride(from: 0, to: count * 4, by: 4) {
            r += Double(texels[i])
            g += Double(texels[i + 1])
            b += Double(texels[i + 2])
        }
        r /= Double(count) * 255
        g /= Double(count) * 255
        b /= Double(count) * 255
        return (pondTones(water: (r, g, b)), 0.3 * r + 0.59 * g + 0.11 * b)
    }

    /// Pixel `index` of `out` in tone `tone`, the tile's own ripples (`texels` above or below its average)
    /// kept over it, darkened by `shade`.
    /// `sea`: the sea's own tones and how much of them to take (near a river's mouth, so the river
    /// turns to the sea's colour as it runs into it instead of meeting it in a hard edge).
    /// `other`: a land next door's water's tones and how much of them to take, by the border, so a
    /// river runs from one land's colour into the next's (the user, 2026-11-25: it changed at the line).
    nonisolated static func paintPond(_ out: inout [UInt8], _ index: Int, texels: [UInt8],
                                      tone: Int, palette: (tones: [(r: Double, g: Double, b: Double)], mean: Double), shade: Double,
                                      sea: (tones: [(r: Double, g: Double, b: Double)], share: Double)? = nil,
                                      other: (tones: [(r: Double, g: Double, b: Double)], share: Double)? = nil) {
        guard index + 2 < texels.count, index + 2 < out.count, !palette.tones.isEmpty else { return }
        let lum = (0.3 * Double(texels[index]) + 0.59 * Double(texels[index + 1]) + 0.11 * Double(texels[index + 2])) / 255
        let ripple = (lum - palette.mean) * 1.1
        var colour = palette.tones[max(0, min(palette.tones.count - 1, tone))]
        if let other, other.share > 0, other.tones.count == palette.tones.count {
            let theirs = other.tones[max(0, min(other.tones.count - 1, tone))], t = min(1, other.share)
            colour = (colour.r + (theirs.r - colour.r) * t, colour.g + (theirs.g - colour.g) * t, colour.b + (theirs.b - colour.b) * t)
        }
        if let sea, sea.share > 0, sea.tones.count == palette.tones.count {
            let other = sea.tones[max(0, min(sea.tones.count - 1, tone))], t = min(1, sea.share)
            colour = (colour.r + (other.r - colour.r) * t, colour.g + (other.g - colour.g) * t, colour.b + (other.b - colour.b) * t)
        }
        out[index] = UInt8(max(0, min(255, ((colour.r + ripple) * shade * 255).rounded())))
        out[index + 1] = UInt8(max(0, min(255, ((colour.g + ripple) * shade * 255).rounded())))
        out[index + 2] = UInt8(max(0, min(255, ((colour.b + ripple) * shade * 255).rounded())))
    }

    /// A land's water two cells or more from any shore, out in a lake or a wide river: version `index`
    /// of its tile a shade deeper (`deepShade`), as `organicTile` darkens the water toward it from
    /// the shallows, so a lake has a middle instead of one flat blue.
    func deepWaterTile(_ id: String, _ index: Int) -> SKTexture {
        let key = "deep|\(id)|\(index % 4)"
        if let cached = blended[key] { return cached }
        let size = max(tileImage(id).width, 16)
        var out = variantPixels(id, index, size: size)
        let deep = Self.deepShade(1)
        for i in stride(from: 0, to: out.count, by: 4) {
            for c in 0..<3 { out[i + c] = UInt8(Double(out[i + c]) * (1 - deep)) }
        }
        let texture = makeTexture(out, size: size)
        blended[key] = texture
        return texture
    }

    /// Edge Wang tile `index` (0 to 15) of a ground tile, for a cell of plain ground (`GroundTiles.wang`),
    /// after SpriteCook's Wang tiles article: each edge is colour 0 or 1 (`index` is north + 2·east +
    /// 4·south + 8·west), colour 0 the tile's own pixels along it and colour 1 the tile shifted, the same
    /// shift on both sides of the edge, so two cells continue one patch of it. The four versions all kept
    /// the original's frame, so it repeated along every cell edge and a field showed its grid.
    /// Mirrored by `tools/wang_art.py` (its `check` holds every edge of a field to the tile's own seams).
    func wangTile(_ id: String, _ index: Int) -> SKTexture {
        let key = "wang|\(id)|\(index & 15)"
        if let cached = blended[key] { return cached }
        let size = max(tileImage(id).width, 16)
        let pixelKey = "wang|\(id)|\(index & 15)|\(size)"
        let made: [UInt8]
        if let cached = variantCache[pixelKey] {
            made = cached
        } else {
            made = Self.wangPixels(of: Self.pixels(tileImage(id), size: size), index & 15, size: size)
            variantCache[pixelKey] = made
        }
        let texture = makeTexture(made, size: size)
        blended[key] = texture
        return texture
    }

    /// The pixels of `wangTile` (rows from the north edge): a middle of its own (the tile shifted), each
    /// edge's strip (the tile itself for colour 0, shifted for colour 1) over it out to a cut along the
    /// least-difference path, 2 to a quarter of the tile deep (image quilting's minimum error boundary
    /// cut), each pixel to the strip of the edge nearest it; and each corner, where four cells meet, the
    /// tile itself. No pixel is mixed: every one is one of the tile's own.
    nonisolated private static func wangPixels(of source: [UInt8], _ index: Int, size n: Int) -> [UInt8] {
        guard source.count == n * n * 4 else { return source }
        // Pixel (x, y) of the tile moved by (dx, dy), as it wraps.
        func at(_ x: Int, _ y: Int, _ shift: (dx: Int, dy: Int)) -> Int {
            (((y + shift.dy) % n) * n + (x + shift.dx) % n) * 4
        }
        let q = max(1, n / 8)
        let middle: (dx: Int, dy: Int) = index == 0 ? (n / 8 * 3, n / 8 * 5) : ((3 + 5 * index) * q % n, (1 + 3 * index) * q % n)
        var out = [UInt8](repeating: 0, count: source.count)
        for y in 0..<n {
            for x in 0..<n {
                let from = at(x, y, middle), to = (y * n + x) * 4
                for c in 0..<4 { out[to + c] = source[from + c] }
            }
        }
        // Each pixel's nearest edge: north, east, south, west, the first on a tie.
        func nearest(_ x: Int, _ y: Int) -> Int {
            let distances = [y, n - 1 - x, n - 1 - y, x]
            var best = 0
            for side in 1..<4 where distances[side] < distances[best] { best = side }
            return best
        }
        // Side `side`'s pixel `depth` in from its edge, `along` it.
        func place(_ side: Int, depth d: Int, along p: Int) -> (x: Int, y: Int) {
            switch side {
            case 0: return (p, d)
            case 1: return (n - 1 - d, p)
            case 2: return (n - 1 - p, n - 1 - d)
            default: return (d, n - 1 - p)
            }
        }
        let band = max(3, n / 4)
        let depths = Array(2...band)
        for side in 0..<4 {
            let colour = (index >> side) & 1
            let strip: (dx: Int, dy: Int) = colour == 0 ? (0, 0) : (side % 2 == 0 ? (n / 2, n / 2) : (n / 4, n * 3 / 4))
            // How different strip and middle are at each depth along the edge.
            func error(_ d: Int, _ p: Int) -> Int {
                let spot = place(side, depth: d, along: p)
                let a = at(spot.x, spot.y, strip), b = at(spot.x, spot.y, middle)
                var sum = 0
                for c in 0..<3 { sum += abs(Int(source[a + c]) - Int(source[b + c])) }
                return sum
            }
            // The cut: a depth for each pixel along the edge, moving at most one from one to the next,
            // with the least difference summed along it.
            var total = [[Int]](repeating: [Int](repeating: 0, count: depths.count), count: n)
            var back = [[Int]](repeating: [Int](repeating: 0, count: depths.count), count: n)
            for k in depths.indices { total[0][k] = error(depths[k], 0) }
            if n > 1 {
                for p in 1..<n {
                    for k in depths.indices {
                        var best = Int.max, pick = k
                        for j in [k - 1, k, k + 1] where depths.indices.contains(j) && total[p - 1][j] < best {
                            best = total[p - 1][j]
                            pick = j
                        }
                        total[p][k] = best + error(depths[k], p)
                        back[p][k] = pick
                    }
                }
            }
            var k = 0
            for j in depths.indices where total[n - 1][j] < total[n - 1][k] { k = j }
            var cut = [Int](repeating: 0, count: n)
            for p in stride(from: n - 1, through: 0, by: -1) {
                cut[p] = depths[k]
                k = back[p][k]
            }
            for p in 0..<n {
                for d in 0..<cut[p] {
                    let spot = place(side, depth: d, along: p)
                    guard nearest(spot.x, spot.y) == side else { continue }
                    let from = at(spot.x, spot.y, strip), to = (spot.y * n + spot.x) * 4
                    for c in 0..<4 { out[to + c] = source[from + c] }
                }
            }
        }
        // The corners: the tile itself, in all four cells that meet there, so they agree.
        let corner = max(2, n / 10)
        for y0 in [0, n - corner] {
            for x0 in [0, n - corner] {
                for y in y0..<(y0 + corner) {
                    for x in x0..<(x0 + corner) {
                        let i = (y * n + x) * 4
                        for c in 0..<4 { out[i + c] = source[i + c] }
                    }
                }
            }
        }
        return out
    }

    private func variantPixels(_ id: String, _ index: Int, size: Int) -> [UInt8] {
        let key = "\(id)|\(index % 4)|\(size)"
        if let cached = variantCache[key] { return cached }
        let made = makeVariantPixels(id, index, size: size)
        variantCache[key] = made
        return made
    }

    private func makeVariantPixels(_ id: String, _ index: Int, size: Int) -> [UInt8] {
        Self.variantPixels(of: Self.pixels(tileImage(id), size: size), index, size: size)
    }

    /// Version `index` of a tile from its pixels (`tileVariant`).
    nonisolated private static func variantPixels(of source: [UInt8], _ index: Int, size: Int) -> [UInt8] {
        let shifts: [(dx: Int, dy: Int, mirrorX: Bool, mirrorY: Bool)] = [
            (0, 0, false, false), (size / 2, size / 2, false, false), (size / 4, size * 5 / 8, true, false), (size * 5 / 8, size / 4, false, true),
        ]
        let shift = shifts[index % 4]
        guard index % 4 != 0 else { return source }
        var out = source
        let band = Double(size) / 5
        for y in 0..<size {
            for x in 0..<size {
                var sx = (x + shift.dx) % size, sy = (y + shift.dy) % size
                if shift.mirrorX { sx = size - 1 - sx }
                if shift.mirrorY { sy = size - 1 - sy }
                let edge = Double(min(min(x, y), min(size - 1 - x, size - 1 - y)))
                let t = max(0, min(1, (edge - 1) / band))
                let inside: Double = t * t * (3 - 2 * t)
                let i = (y * size + x) * 4, j = (sy * size + sx) * 4
                for c in 0..<4 {
                    let mixed: Double = Double(source[i + c]) * (1 - inside) + Double(source[j + c]) * inside
                    out[i + c] = UInt8(min(255, mixed))
                }
            }
        }
        return out
    }

    /// Another land's tiles, graded with its palette, by land, tile, version and size: kept whatever
    /// map the library grades for, a few lands' ground at most.
    private var foreignVariants: [String: [UInt8]] = [:]

    private func foreignPixels(_ id: String, palette: MapPalette?, from land: String, variant: Int, size: Int) -> [UInt8] {
        let key = "\(land)|\(id)|\(variant % 4)|\(size)"
        if let cached = foreignVariants[key] { return cached }
        let image = gradedTile(id, palette: palette) ?? Placeholder.canvas(for: id, kind: "tile").cgImage()
        let made = Self.variantPixels(of: Self.pixels(image, size: size), variant, size: size)
        foreignVariants[key] = made
        return made
    }

    /// Version `variant` of a land next door's tile, graded as it is there (`Foreign`), for a cell
    /// all its ground, the size of this land's `base` tile.
    func foreignTile(_ id: String, palette: MapPalette?, from land: String, variant: Int, base: String) -> SKTexture {
        let key = "foreign|\(land)|\(id)|\(variant % 4)"
        if let cached = blended[key] { return cached }
        let size = max(tileImage(base).width, 16)
        let texture = makeTexture(foreignPixels(id, palette: palette, from: land, variant: variant, size: size), size: size)
        blended[key] = texture
        return texture
    }

    /// Version `variant` of this land's tile `id` with a land next door's mixed in (`Fade`), for a
    /// road cell all road across the band between them.
    func fadedTile(_ id: String, fade: Fade, variant: Int) -> SKTexture {
        let key = "faded|\(id)|\(fade.key)|\(variant % 4)"
        if let cached = blended[key] { return cached }
        let size = max(tileImage(id).width, 16)
        let texture = makeTexture(fadedPixels(id, fade: fade, variant: variant, size: size), size: size)
        blended[key] = texture
        return texture
    }

    /// This land's tile `id` and the land next door's (`fade`) mixed, pixel by pixel.
    private func fadedPixels(_ id: String, fade: Fade, variant: Int, size: Int) -> [UInt8] {
        let own = variantPixels(id, variant, size: size)
        let theirs = foreignPixels(fade.tile, palette: fade.from.palette, from: fade.from.land, variant: variant, size: size)
        guard own.count == theirs.count else { return own }
        let share = min(1, max(0, fade.share))
        var out = own
        for index in out.indices {
            let mixed: Double = Double(own[index]) * (1 - share) + Double(theirs[index]) * share
            out[index] = UInt8(min(255, mixed.rounded()))
        }
        return out
    }

    /// A ground tile with soft, rounded roads, patches and water drawn over `base`. Roads and
    /// patches are rounded strokes joining the cells around this one that hold them, so corners
    /// curve and diagonal steps become smooth bends; their edges wobble in a pattern that repeats
    /// every tile. Water is a smooth field over the 5×5 cells around, so shores curve freely instead
    /// of following cell edges, and wobbles with its place on the map (`cell`). Either way
    /// neighbouring tiles meet seamlessly. Roads get a darker rim, water a foamy edge and a damp bank.
    /// Shoreline tiles are unique anyway, so they also use tile variant `variant`. A patch layer
    /// `from` a land next door is its ground, graded as it is there.
    ///
    /// Across the band between two lands (`Seam`), the grounds each cell round shows (`ground`
    /// layers, in the same order whichever land draws the tile) go down first, over `base`: at each
    /// pixel the last of them whose soft shape reaches it, else the first with a cell within `verge`
    /// of it. So what shows between the shapes, along an edge, is the same from both tiles either
    /// side of it, though a land next door draws the one past its border: with the land's own
    /// ground there, its patches stopped dead along the border (playtesting 2026-10-16).
    /// `pond`: the tone of a land's own water at a point of the world (`GroundTiles.PondField.tone`), its
    /// lakes and rivers drawn in the pond's tones (`pondTones`) instead of shaded from the shore.
    /// `seaward`: how much of the sea's colour its pond water takes at a point (`paintPond`).
    func organicTile(base: String, layers: [GroundLayer], cell: GridPoint, variant: Int, pond: ((Double, Double) -> Int)? = nil,
                     seaward: ((Double, Double) -> Double)? = nil,
                     across: ((Double, Double) -> (tones: [(r: Double, g: Double, b: Double)], share: Double)?)? = nil) -> SKTexture {
        let hasWater = layers.contains { $0.style == .water || $0.style == .cut }
        let place = (hasWater ? "@\(cell.col),\(cell.row)#\(variant)" : "") + (pond == nil ? "" : "|pond")
        let key = "organic|\(base)|" + layers.map { "\($0.tile):\($0.mask):\($0.style):\($0.from?.land ?? ""):\($0.fade?.key ?? "")" }.joined(separator: "|") + place
            + (layers.contains { $0.cobbled } ? "|cob\(Self.cobblePhase(cell))" : "")
        if let cached = blended[key] { return cached }
        let size = max(tileImage(base).width, 16)
        let pick = hasWater ? variant : 0
        var out = variantPixels(base, pick, size: size)
        let rim = 1.2 / Double(size)
        let grounds = layers.filter { $0.style == .ground }
        if !grounds.isEmpty {
            var texels: [[UInt8]] = []
            var segments: [[(x0: Double, y0: Double, x1: Double, y1: Double)]] = []
            // Each ground's cells of the 3×3, in this cell's coordinates.
            var cells: [[(x: Double, y: Double)]] = []
            for layer in grounds {
                if let from = layer.from {
                    texels.append(foreignPixels(layer.tile, palette: from.palette, from: from.land, variant: pick, size: size))
                } else {
                    texels.append(variantPixels(layer.tile, pick, size: size))
                }
                segments.append(Self.strokes(mask: layer.mask))
                var near: [(x: Double, y: Double)] = []
                for bit in 0..<9 where layer.mask & (1 << bit) != 0 {
                    let x: Double = Double(bit % 3 - 1)
                    let y: Double = Double(1 - bit / 3)
                    near.append((x: x, y: y))
                }
                cells.append(near)
            }
            for py in 0..<size {
                for px in 0..<size {
                    let x: Double = (Double(px) + 0.5) / Double(size) - 0.5
                    let y: Double = 0.5 - (Double(py) + 0.5) / Double(size)
                    let reach: Double = 0.42 + Self.wobble(x, y, style: .patch, cell: cell)
                    var shown: Int? = nil
                    // The last whose shape reaches here.
                    for index in grounds.indices.reversed() where shown == nil {
                        for segment in segments[index] where Self.distance(x, y, to: segment) < reach {
                            shown = index
                            break
                        }
                    }
                    // Else the first with a cell within `verge`.
                    for index in grounds.indices where shown == nil {
                        for spot in cells[index] where Self.gap(x, y, to: spot) < Self.verge {
                            shown = index
                            break
                        }
                    }
                    let index = (py * size + px) * 4
                    guard let ground = shown, texels[ground].count == out.count else { continue }
                    for c in 0..<3 { out[index + c] = texels[ground][index + c] }
                    out[index + 3] = 255
                }
            }
        }
        for layer in layers where layer.style != .ground {
            let shore = layer.style == .water || layer.style == .cut
            let texels: [UInt8]
            if layer.style == .cut {
                texels = []
            } else if let fade = layer.fade {
                texels = fadedPixels(layer.tile, fade: fade, variant: pick, size: size)
            } else if let from = layer.from {
                texels = foreignPixels(layer.tile, palette: from.palette, from: from.land, variant: pick, size: size)
            } else {
                texels = variantPixels(layer.tile, pick, size: size)
            }
            let segments: [(x0: Double, y0: Double, x1: Double, y1: Double)] = shore ? [] : Self.strokes(mask: layer.mask)
            let palette = pond != nil && layer.style == .water && Self.isPondWater(layer.tile) ? Self.pondPalette(texels) : nil
            // A town's road: the sand either side of its cobbles and the stones' colour, from the land's
            // own path and cobble tiles as graded here.
            let sand = layer.cobbled ? variantPixels("tile_path", pick, size: size) : []
            let sandMean = layer.cobbled ? Self.meanColour(sand) : (0, 0, 0)
            let stone = layer.cobbled ? Self.stoneColour(Self.meanColour(variantPixels("tile_town", 0, size: size))) : (0, 0, 0)
            let pools: [(x: Double, y: Double)] = shore ? Self.pools(mask: layer.mask) : []
            let radius: Double = switch layer.style {
            case .road: 0.36
            case .patch, .ground: 0.42
            case .water, .cut: 0
            }
            for py in 0..<size {
                for px in 0..<size {
                    // Cell coordinates: this cell spans -0.5...0.5, x east, y north.
                    let x = (Double(px) + 0.5) / Double(size) - 0.5, y = 0.5 - (Double(py) + 0.5) / Double(size)
                    let wobble = Self.wobble(x, y, style: layer.style, cell: cell)
                    let depth: Double
                    if shore {
                        depth = Self.waterDepth(x, y, pools: pools, wobble: wobble)
                    } else if layer.cobbled {
                        // A town street's edge is where its cells end: how far the point is from the nearest
                        // cell round it that isn't street. Measured from the rounded strokes between its cells,
                        // the edge dipped in near their corners inside a wide street too, and grass and sand
                        // showed through the cobbles there (the user, 2026-11-17: "holes").
                        var nearest = 1.0
                        for bit in 0..<9 where layer.mask & (1 << bit) == 0 {
                            nearest = min(nearest, Self.gap(x, y, to: (x: Double(bit % 3 - 1), y: Double(1 - bit / 3))))
                        }
                        depth = nearest + wobble
                    } else {
                        var distance = Double.infinity
                        for segment in segments { distance = min(distance, Self.distance(x, y, to: segment)) }
                        depth = radius + wobble - distance
                    }
                    let index = (py * size + px) * 4
                    switch layer.style {
                    case .road, .patch, .ground:
                        guard depth > 0 else { continue }
                        if layer.cobbled, sand.count == out.count {
                            Self.townRoad(&out, index, x: x, y: y, depth: depth, rim: rim, cell: cell,
                                          speck: Self.speck(px, py, cell), sand: sand, sandMean: sandMean, stone: stone,
                                          inside: layer.mask == (1 << 9) - 1)
                            continue
                        }
                        let shade = layer.style == .road && depth < rim ? 0.72 : 1
                        for c in 0..<3 { out[index + c] = UInt8(Double(texels[index + c]) * shade) }
                        out[index + 3] = 255
                    case .water:
                        // A land's own water (not ice) gets depth and a bank: paler in the shallows,
                        // deeper out from the shore, and a strip of damp earth and pebbles along it,
                        // where the land had stopped dead at a flat blue (playtesting 2026-10-23).
                        // Chocolate too (the user, 2026-11-25), but not the blue shallows.
                        let natural = Self.isPondWater(layer.tile)
                        let speck = Self.speck(px, py, cell)
                        // Grass in the outline (the user, 2026-11-16): the land's own grass grows out over
                        // the waterline in blades, each its own height (`bladeReach`, along the screen's
                        // width across the world, so they meet from tile to tile), its tip a little lighter,
                        // the bank's earth only in the gaps between them. Only where the ground is green.
                        let reach = natural ? Self.bladeReach(Double(cell.col) + x - Double(cell.row) - y) : -1
                        let grassy = Int(out[index + 1]) > Int(out[index]) + 8 && Int(out[index + 1]) > Int(out[index + 2]) + 8
                        if natural, grassy, depth > -0.3, depth < reach {
                            let shade: Double = depth > reach - 0.035 ? 1.12 : 0.9
                            for c in 0..<3 { out[index + c] = UInt8(max(0, min(255, Double(out[index + c]) * shade))) }
                            out[index + 3] = 255
                            continue
                        }
                        // The blade's shadow on the water, just past its tip.
                        let shadowed = natural && grassy && reach > 0 && depth >= reach && depth < reach + 0.04
                        if depth > 0, let pond, let palette {
                            // In the pond's tones, by where it lies in the lake or river.
                            var tone = pond(Double(cell.col) + 0.5 + x, Double(cell.row) + 0.5 + y)
                            // The bright rim along a near shore (land down the screen, south and west of
                            // the water), a pixel or two wide just past the grass's blades and their
                            // shadow, along the waterline as it curves (the user, 2026-11-19: drawn a
                            // cell's edge at a time, it ran in straight steps: "it should follow the curves").
                            let pixel = 1 / Double(size)
                            let start = natural && grassy && reach > 0 ? reach + 0.04 : 0
                            if !shadowed, depth >= start, depth < start + 1.6 * pixel {
                                let probe = (x: x - 2.5 * pixel, y: y - 2.5 * pixel)
                                let below = Self.waterDepth(probe.x, probe.y, pools: pools,
                                                            wobble: Self.wobble(probe.x, probe.y, style: layer.style, cell: cell))
                                if below <= start { tone = 6 }
                            }
                            let sea = seaward.map { (tones: seaTones, share: $0(Double(cell.col) + 0.5 + x, Double(cell.row) + 0.5 + y)) }
                            Self.paintPond(&out, index, texels: texels, tone: tone, palette: palette, shade: shadowed ? 0.7 : 1, sea: sea,
                                           other: across?(Double(cell.col) + 0.5 + x, Double(cell.row) + 0.5 + y))
                            out[index + 3] = 255
                        } else if depth > 0 {
                            // Foam along the edge, broken here and there, with a few flecks out past it.
                            let foam = depth < 0.05 ? (speck < 0.75 ? 0.35 : 0.12) : (depth < 0.1 && speck < 0.12 ? 0.22 : 0)
                            let shallow = layer.tile == "tile_water" ? 0.3 * pow(max(0, 1 - depth / 0.4), 1.5) : 0
                            let deep = natural ? Self.deepShade(depth) : 0
                            for c in 0..<3 {
                                var value: Double = Double(texels[index + c]) * (1 - deep)
                                value += (Self.shallows[c] - value) * shallow
                                value = value * (1 - foam) + 255 * foam
                                if shadowed { value *= 0.7 }
                                out[index + c] = UInt8(max(0, min(255, value)))
                            }
                            out[index + 3] = 255
                        } else if depth > -0.06 {
                            // The lip of the bank, in the shadow it throws on the water's edge.
                            for c in 0..<3 {
                                let value: Double = natural ? Double(out[index + c]) * 0.55 + Self.bank[c] * 0.2 : Double(out[index + c]) * 0.8
                                out[index + c] = UInt8(max(0, min(255, value)))
                            }
                        } else if natural, depth > -0.3 {
                            // The bank: damp earth, more of it toward the water, and pebbles in it.
                            let near: Double = pow((depth + 0.3) / 0.24, 1.2)
                            for c in 0..<3 {
                                let ground: Double = Double(out[index + c])
                                let earth: Double = speck < 0.035 && near > 0.2 ? Self.pebble[c] : Self.bank[c]
                                let mix: Double = speck < 0.035 && near > 0.2 ? 0.85 : 0.72 * near
                                out[index + c] = UInt8(max(0, min(255, ground + (earth - ground) * mix)))
                            }
                        }
                    case .cut:
                        // Clear past the shore; the lip of the land along it a shade darker.
                        if depth > 0 {
                            for c in 0..<4 { out[index + c] = 0 }
                        } else if depth > -0.05 {
                            for c in 0..<3 { out[index + c] = UInt8(Double(out[index + c]) * 0.82) }
                        }
                    }
                }
            }
        }
        let texture = makeTexture(out, size: size)
        blended[key] = texture
        return texture
    }

    private func makeTexture(_ bytes: [UInt8], size: Int) -> SKTexture {
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        remember(image, for: texture)
        return texture
    }

    /// The image each texture the library made was drawn from (`picture(of:)`), while the texture
    /// lives.
    private struct Source {
        weak var texture: SKTexture?
        let image: CGImage
    }
    private var sources: [ObjectIdentifier: Source] = [:]
    /// How many `sources` there may be before those of textures gone are let go.
    private var sourcesPrunedAt = 4096

    /// The image `texture` shows: for a texture the library made, the image it was made from.
    /// `SKTexture.cgImage()` sets up a Core Image context every time it's called, and once for
    /// each tile along a coast that slopes to the sea (each its own, `organicTile`) that held a
    /// land's build up for many seconds on a phone, long enough for the watchdog to kill the game
    /// when the phone turned meanwhile.
    func picture(of texture: SKTexture) -> CGImage {
        if let known = sources[ObjectIdentifier(texture)], known.texture === texture { return known.image }
        return texture.cgImage()
    }

    /// Each texture's wind frames (`windFrames`), cut from one strip so a grove still draws together.
    private struct WindStrip {
        weak var texture: SKTexture?
        let frames: [SKTexture]?
    }
    private var windStrips: [ObjectIdentifier: WindStrip] = [:]

    /// The rig `id` moves in the wind by (art/wind.json): its own, or, for a palette swap with no
    /// PNG of its own (`big_tree`, `frost_pine`), its base's. Nil for anything that doesn't.
    private func windRig(_ id: String, depth: Int = 0) -> WindRig? {
        if pngURL(id) != nil { return WindBook.shared?.rigs[id] }
        guard depth < 3, let derive = asset(id)?.derive, derive.layers == nil else { return nil }
        return windRig(derive.from, depth: depth + 1)
    }

    /// The frames sprite `id` moves in the wind by, cut from `texture` as it's drawn (graded for
    /// its land, or a land next door's): nil for anything that doesn't (tools/wind_art.py).
    func windFrames(_ id: String, texture: SKTexture) -> [SKTexture]? {
        let key = ObjectIdentifier(texture)
        if let known = windStrips[key], known.texture === texture { return known.frames }
        var frames: [SKTexture]?
        if let book = WindBook.shared, let rig = windRig(id), let strip = book.strip(picture(of: texture), rig: rig) {
            let sheet = SKTexture(cgImage: strip)
            sheet.filteringMode = .nearest
            let count = rig.frames.count
            frames = (0..<count).map { f in
                let frame = SKTexture(rect: CGRect(x: CGFloat(f) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1), in: sheet)
                frame.filteringMode = .nearest
                return frame
            }
        }
        if windStrips.count > 256 { windStrips = windStrips.filter { $0.value.texture != nil } }
        windStrips[key] = WindStrip(texture: texture, frames: frames)
        return frames
    }

    /// The wind frames of every sprite in `ids` that moves in the wind, as `sprite(_:)` draws it now
    /// (graded for the land being set down), cut from strips packed side by side on one texture, so a
    /// mixed wood's trees and bushes share it and SpriteKit draws them in batches, not one by one
    /// (the user, 2026-11-25, after a post on pixel-art trees in the wind: the clumps aren't what's
    /// slow, drawing each tree off a picture of its own is). `windFrames` then finds them made; what
    /// it doesn't find (a land next door's recolour, or past `atlasSide`) it cuts on its own, as before.
    func packWindFrames(_ ids: [String]) {
        guard let book = WindBook.shared else { return }
        var items: [(texture: SKTexture, strip: CGImage, count: Int)] = []
        var seen: Set<ObjectIdentifier> = []
        for id in Set(ids).sorted() {
            guard let rig = windRig(id) else { continue }
            let texture = sprite(id).texture
            let key = ObjectIdentifier(texture)
            guard seen.insert(key).inserted else { continue }
            if let known = windStrips[key], known.texture === texture { continue }
            guard let strip = book.strip(picture(of: texture), rig: rig) else { continue }
            items.append((texture, strip, rig.frames.count))
        }
        guard items.count > 1 else { return }
        // Shelves, tallest first, a clear pixel round each so no neighbour's edge creeps in.
        let side = Self.atlasSide, gap = 1
        let order = items.indices.sorted { items[$0].strip.height > items[$1].strip.height }
        var spots: [Int: (x: Int, y: Int)] = [:]
        var x = gap, y = gap, shelf = 0
        for index in order {
            let w = items[index].strip.width, h = items[index].strip.height
            guard w + 2 * gap <= side else { continue }
            if x + w + gap > side {
                x = gap
                y += shelf + gap
                shelf = 0
            }
            guard y + h + gap <= side else { break }
            spots[index] = (x, y)
            x += w + gap
            shelf = max(shelf, h)
        }
        let height = y + shelf + gap
        guard spots.count > 1, height > 0,
              let context = CGContext(data: nil, width: side, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        context.interpolationQuality = .none
        for (index, spot) in spots {
            let strip = items[index].strip
            // The context's rows run up from the bottom.
            context.draw(strip, in: CGRect(x: spot.x, y: height - spot.y - strip.height, width: strip.width, height: strip.height))
        }
        guard let image = context.makeImage() else { return }
        let page = SKTexture(cgImage: image)
        page.filteringMode = .nearest
        let pageWidth = CGFloat(side), pageHeight = CGFloat(height)
        for (index, spot) in spots {
            let item = items[index]
            let frameWidth = CGFloat(item.strip.width / item.count), frameHeight = CGFloat(item.strip.height)
            let bottom = pageHeight - CGFloat(spot.y) - frameHeight
            let frames = (0..<item.count).map { f -> SKTexture in
                let rect = CGRect(x: (CGFloat(spot.x) + CGFloat(f) * frameWidth) / pageWidth, y: bottom / pageHeight,
                                  width: frameWidth / pageWidth, height: frameHeight / pageHeight)
                let frame = SKTexture(rect: rect, in: page)
                frame.filteringMode = .nearest
                return frame
            }
            windStrips[ObjectIdentifier(item.texture)] = WindStrip(texture: item.texture, frames: frames)
        }
    }

    /// How wide (and at most how tall) a land's packed wind texture is, in pixels: well inside what
    /// every iPhone's GPU takes (8192 since the A9).
    private static let atlasSide = 4096

    private func remember(_ image: CGImage, for texture: SKTexture) {
        sources[ObjectIdentifier(texture)] = Source(texture: texture, image: image)
        if sources.count > sourcesPrunedAt {
            sources = sources.filter { $0.value.texture != nil }
            sourcesPrunedAt = max(4096, sources.count * 2)
        }
    }

    /// How much darker a land's water is `depth` cells in from its shore: none in the shallows, the
    /// most two cells out (`deepWaterTile`).
    nonisolated static func deepShade(_ depth: Double) -> Double {
        let t = max(0, min(1, (depth - 0.25) / 0.55))
        return 0.2 * t * t * (3 - 2 * t)
    }

    /// The shallows' pale turquoise, a bank's damp earth and its pebbles (premultiplied, opaque).
    nonisolated private static let shallows: [Double] = [128, 214, 222]
    nonisolated private static let bank: [Double] = [104, 86, 60]
    nonisolated private static let pebble: [Double] = [186, 180, 168]

    /// A pixel's own fixed chance, 0 to 1, for the foam's breaks and the bank's pebbles.
    /// How far the blade of grass at `across` (world cells along the screen's width, x - y) reaches out
    /// past the waterline, in cells: a blade every 1/13 of a cell (2 or 3 of a tile's pixels), most of
    /// them 1 to 6 pixels over the water, a few in between short of it, where the bank's earth shows.
    nonisolated static func bladeReach(_ across: Double) -> Double {
        let blade = Int((across * 13).rounded(.down))
        var h = UInt32(truncatingIfNeeded: blade &* 668_265_263) ^ 0x9E37_79B9
        h = (h ^ (h >> 15)) &* 2_246_822_519
        h ^= h >> 13
        h = h &* 3_266_489_917
        h ^= h >> 16
        let gap = Double(h & 0xFFFF) / 65_535, height = Double(h >> 16) / 65_535
        guard gap < 0.7 else { return -0.16 }
        return 0.02 + 0.17 * height * height
    }

    nonisolated private static func speck(_ px: Int, _ py: Int, _ cell: GridPoint) -> Double {
        var h = UInt32(truncatingIfNeeded: px &* 73_856_093) ^ UInt32(truncatingIfNeeded: py &* 19_349_663)
        h ^= UInt32(truncatingIfNeeded: cell.col &* 83_492_791) ^ UInt32(truncatingIfNeeded: cell.row &* 2_654_435_761)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return Double((h ^ (h >> 16)) & 0xFFFF) / 65_535
    }

    /// Centres of the water cells in a 5×5 mask, relative to the middle cell (x east, y north).
    nonisolated static func pools(mask: Int) -> [(x: Double, y: Double)] {
        var points: [(x: Double, y: Double)] = []
        for bit in 0..<25 where mask & (1 << bit) != 0 {
            points.append((Double(bit % 5 - 2), Double(2 - bit / 5)))
        }
        return points
    }

    /// How far inside the water a point is (in cells, negative on land): each water cell adds a
    /// soft round blob, and the shore is where they add up to a threshold.
    nonisolated static func waterDepth(_ x: Double, _ y: Double, pools: [(x: Double, y: Double)], wobble: Double) -> Double {
        var field = 0.0
        for pool in pools {
            let dx = x - pool.x, dy = y - pool.y
            field += exp(-(dx * dx + dy * dy) / 0.49)
        }
        return (field + wobble * 1.8 - 0.55) / 1.2
    }

    /// An image's pixels (premultiplied RGBA), scaled to `size` × `size`.
    nonisolated private static func pixels(_ image: CGImage, size: Int) -> [UInt8] {
        PixelImage.pixels(of: image, width: size, height: size) ?? [UInt8](repeating: 0, count: size * size * 4)
    }

    /// The strokes a layer is drawn with: a dot on every cell that holds it, and a line to each
    /// neighbouring cell (diagonals too) that also holds it.
    nonisolated private static func strokes(mask: Int) -> [(x0: Double, y0: Double, x1: Double, y1: Double)] {
        var points: [(x: Double, y: Double)] = []
        for bit in 0..<9 where mask & (1 << bit) != 0 {
            points.append((Double(bit % 3 - 1), Double(1 - bit / 3)))
        }
        var segments: [(x0: Double, y0: Double, x1: Double, y1: Double)] = []
        for i in points.indices {
            segments.append((points[i].x, points[i].y, points[i].x, points[i].y))
            for j in points.indices where j > i && abs(points[i].x - points[j].x) <= 1 && abs(points[i].y - points[j].y) <= 1 {
                segments.append((points[i].x, points[i].y, points[j].x, points[j].y))
            }
        }
        return segments
    }

    /// How far an edge bulges out (+) or in (-) at a point. Roads and patches repeat every tile;
    /// shorelines follow the point's place on the map, so lakes meander.
    nonisolated static func wobble(_ x: Double, _ y: Double, style: GroundLayer.Style, cell: GridPoint) -> Double {
        let turn: Double = 2 * Double.pi
        if style == .water || style == .cut {
            let gx: Double = Double(cell.col) + x
            let gy: Double = Double(cell.row) + y
            let a: Double = sin(1.7 * gx + 0.9 * gy)
            let b: Double = sin(2.3 * gy - 1.1 * gx + 1.7)
            let c: Double = sin(3.1 * gx + 2.9 * gy + 0.4)
            return 0.08 * a + 0.05 * b + 0.03 * c
        }
        let a: Double = sin(turn * (2 * x + y))
        let b: Double = sin(turn * (3 * y - x) + 1.3)
        return 0.045 * a + 0.03 * b
    }

    // MARK: Town roads

    /// Which of 4 × 4 places a cell is in the cobbles' pattern, which repeats every four cells, so a
    /// town's road tiles are made once each for 16 places rather than once a cell.
    nonisolated static func cobblePhase(_ cell: GridPoint) -> Int {
        ((cell.col % 4 + 4) % 4) * 4 + (cell.row % 4 + 4) % 4
    }

    /// The mean colour of a tile's pixels, leaving out green ones (a path tile's flecks of grass).
    nonisolated private static func meanColour(_ pixels: [UInt8]) -> (Double, Double, Double) {
        var sum = (0.0, 0.0, 0.0), count = 0.0
        for index in stride(from: 0, to: pixels.count - 3, by: 4) where !isGreen(pixels, index) {
            sum.0 += Double(pixels[index]); sum.1 += Double(pixels[index + 1]); sum.2 += Double(pixels[index + 2])
            count += 1
        }
        guard count > 0 else { return (150, 145, 140) }
        return (sum.0 / count, sum.1 / count, sum.2 / count)
    }

    nonisolated private static func isGreen(_ pixels: [UInt8], _ index: Int) -> Bool {
        Int(pixels[index + 1]) > Int(pixels[index]) + 8 && Int(pixels[index + 1]) > Int(pixels[index + 2]) + 8
    }

    /// A cobble's colour from a cobble tile's mean: less saturated and a little darker, so it reads as
    /// stone beside the sand rather than as more sand (the tile's mean was tan in the green towns).
    nonisolated private static func stoneColour(_ mean: (Double, Double, Double)) -> (Double, Double, Double) {
        let grey = 0.3 * mean.0 + 0.59 * mean.1 + 0.11 * mean.2
        func mix(_ c: Double) -> Double { (grey + (c - grey) * 0.45) * 0.92 }
        return (mix(mean.0), mix(mean.1), mix(mean.2) + 4)
    }

    nonisolated private static func hash(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: a &* 73_856_093) ^ UInt32(truncatingIfNeeded: b &* 19_349_663) ^ UInt32(truncatingIfNeeded: c &* 83_492_791)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFF) / 65_535
    }

    /// How far the grass reaches out over a town road's edge (in cells), along the edge: rounded
    /// clumps, each its own width and reach, repeating every four cells (`cobblePhase`).
    nonisolated private static func clumpReach(_ along: Double) -> Double {
        let k = Int(along.rounded(.down))
        let t = along - Double(k)
        let clump = (k % 4 + 4) % 4
        let width = 0.7 + 0.3 * hash(clump, 3, 11)
        guard t < width else { return 0.04 }
        let u = t / width * 2 - 1
        return 0.05 + (0.12 + 0.12 * hash(clump, 4, 11)) * (1 - u * u).squareRoot()
    }

    /// A town road's pixel (`GroundLayer.cobbled`): rounded cobbles about half a cell across down its
    /// middle (their edge ragged, stone by stone), each its own tone, lit on its north side (up and to
    /// the left on screen, as everything is) and in shade on its south, dark gaps of sand between them;
    /// sand with pebbles in it either side; and where the ground beside it is green, the grass growing
    /// out over its edge in clumps, lit at their tips, with a shadow on the sand past them.
    nonisolated private static func townRoad(_ out: inout [UInt8], _ index: Int, x: Double, y: Double, depth: Double, rim: Double,
                                             cell: GridPoint, speck: Double, sand: [UInt8], sandMean: (Double, Double, Double),
                                             stone: (Double, Double, Double), inside: Bool) {
        let phase = cobblePhase(cell)
        let wx = Double(phase / 4) + x + 0.5, wy = Double(phase % 4) + y + 0.5
        let grassy = Int(out[index + 1]) > Int(out[index]) + 8 && Int(out[index + 1]) > Int(out[index + 2]) + 8
        // Grass grows over the street's edges, never in a cell in the middle of it, where it showed as holes.
        let reach = grassy && !inside ? clumpReach(wx - wy) : -1
        // Where the ground beside isn't green (a desert town's), the sand gives way to it raggedly, the
        // ground's own pixels left as they are: cut straight at the cell's edge it read as clipped (the
        // user, 2026-11-18, of Ingothold's streets).
        let ragged = !grassy && !inside ? 0.02 + 0.6 * clumpReach(wx - wy + 0.5) * hash(Int((wx - wy) * 6), 7, 13) : -1
        if depth < ragged { return }
        if depth < reach {
            // The grass over the edge: lit along its tips, a dark line where it ends.
            let shade = depth > reach - 0.03 ? 0.5 : depth > reach - 0.08 ? 1.2 : 1
            for c in 0..<3 { out[index + c] = UInt8(max(0, min(255, Double(out[index + c]) * shade))) }
            out[index + 3] = 255
            return
        }
        // The sand: the path tile's own light and dark, in its own colour without its flecks of grass.
        let meanLight = max(1, sandMean.0 + sandMean.1 + sandMean.2)
        // Kept close to its mean: the tile's light grains, graded gold in a desert town, read as yellow
        // blobs in a grid along every street (the user, 2026-11-18).
        let light = min(1.05, max(0.95, (Double(sand[index]) + Double(sand[index + 1]) + Double(sand[index + 2])) / meanLight))
        let tint = isGreen(sand, index) ? 1 : light
        var colour = (sandMean.0 * tint, sandMean.1 * tint, sandMean.2 * tint)
        var shade = 1.0
        if grassy, depth < reach + 0.08 { shade = 0.68 }            // the clumps' shadow on the road
        else if !grassy, !inside, depth < ragged + 0.035 { shade = 0.86 }   // its ragged edge a little darker
        // The cobbles: a stone's cell on a jittered grid, two to a cell, repeating every eight.
        let gx = wx * 2, gy = wy * 2
        let cx = Int(gx.rounded(.down)), cy = Int(gy.rounded(.down))
        var best = 9.0, second = 9.0, at = (0, 0, 0.0, 0.0)
        for dy in -1...1 {
            for dx in -1...1 {
                let sx = cx + dx, sy = cy + dy
                let kx = (sx % 8 + 8) % 8, ky = (sy % 8 + 8) % 8
                let jx = Double(sx) + 0.2 + 0.6 * hash(kx, ky, 1), jy = Double(sy) + 0.2 + 0.6 * hash(kx, ky, 2)
                let d = ((gx - jx) * (gx - jx) + (gy - jy) * (gy - jy)).squareRoot()
                if d < best {
                    second = best
                    best = d
                    at = (kx, ky, gx - jx, gy - jy)
                } else if d < second {
                    second = d
                }
            }
        }
        let edge = second - best
        // Down the middle, past its sand; a stone at the edge in or out by a roll of its own.
        let core = depth + 0.1 * (hash(at.0, at.1, 21) - 0.5) > 0.2
        if core, edge >= 0.05 {
            if edge < 0.1 {
                colour = (stone.0 * 0.5, stone.1 * 0.46, stone.2 * 0.44)   // the stone's dark outline
            } else {
                var tone = 0.86 + 0.24 * hash(at.0, at.1, 3)
                if edge < 0.2 { tone *= at.3 > 0 ? 1.13 : 0.8 }         // lit on its north side
                if speck < 0.08 { tone *= 0.92 }
                colour = (stone.0 * tone, stone.1 * tone, stone.2 * tone)
            }
        } else if core {
            // The joints between the stones, thin and in the stone's own shade: as packed earth, dark and
            // wide, they read as holes (the user, 2026-11-17).
            colour = (stone.0 * 0.62, stone.1 * 0.6, stone.2 * 0.6)
        } else if speck < 0.05, depth > 0.05 {
            // A pebble in the sand.
            let tone = speck < 0.025 ? 1.08 : 0.8
            colour = (stone.0 * tone, stone.1 * tone, stone.2 * tone)
        }
        out[index] = UInt8(max(0, min(255, colour.0 * shade)))
        out[index + 1] = UInt8(max(0, min(255, colour.1 * shade)))
        out[index + 2] = UInt8(max(0, min(255, colour.2 * shade)))
        out[index + 3] = 255
    }

    /// How far round a cell of the 3×3 a ground across a band shows where no shape reaches
    /// (`organicTile`): far enough that it fills the gap between this cell's own shape and that
    /// cell's side of it all along.
    nonisolated private static let verge = 0.27

    /// How far a point (in this cell's coordinates) is from the cell `offset` of the 3×3 round it.
    nonisolated private static func gap(_ x: Double, _ y: Double, to offset: (x: Double, y: Double)) -> Double {
        let dx: Double = max(0, abs(x - offset.x) - 0.5)
        let dy: Double = max(0, abs(y - offset.y) - 0.5)
        return (dx * dx + dy * dy).squareRoot()
    }

    nonisolated private static func distance(_ x: Double, _ y: Double, to s: (x0: Double, y0: Double, x1: Double, y1: Double)) -> Double {
        let dx = s.x1 - s.x0, dy = s.y1 - s.y0
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : max(0, min(1, ((x - s.x0) * dx + (y - s.y0) * dy) / length))
        let ex = s.x0 + t * dx - x, ey = s.y0 + t * dy - y
        return (ex * ex + ey * ey).squareRoot()
    }

    /// Animation frames for a water tile (a generated tile is a single frame).
    func waterFrames(_ id: String) -> [SKTexture] {
        if let texture = generatedTexture(id) { return [texture] }
        return [Placeholder.water(frame: 0).texture(), Placeholder.water(frame: 1).texture()]
    }

    /// A single image: the whole PNG, or the front-facing frame of a walk sheet.
    func sprite(_ id: String) -> SpriteArt {
        let kind = kind(of: id)
        if kind == "walk_sheet" {
            let cycle = walkCycle(id)
            return SpriteArt(texture: cycle.frames(.down).first ?? SKTexture(), size: cycle.size)
        }
        let scale = CGFloat(asset(id)?.scale ?? 1)
        if let texture = generatedTexture(id) {
            return SpriteArt(texture: texture, size: texture.size() * scale)
        }
        let texture = Placeholder.canvas(for: id, kind: kind).texture()
        return SpriteArt(texture: texture, size: texture.size() * (Placeholder.scale(for: kind) * scale))
    }

    /// Frames per direction. Single images become a one-frame cycle (they hop instead of walking).
    func walkCycle(_ id: String) -> WalkCycle {
        if let cached = cycles[id] { return cached }
        let cycle = makeWalkCycle(id)
        cycles[id] = cycle
        return cycle
    }

    private func makeWalkCycle(_ id: String) -> WalkCycle {
        let asset = asset(id)
        let kind = kind(of: id)
        let scale = CGFloat(asset?.scale ?? 1)

        guard kind == "walk_sheet" else {
            let art = sprite(id)
            var cycle = WalkCycle(frames: Dictionary(uniqueKeysWithValues: Direction.allCases.map { ($0, [art.texture]) }), size: art.size,
                                  facesRight: asset?.faces == "right")
            // A single picture blinks, both eyes or none; it breathes by its `motion` (IdleMotion).
            if let eyes = eyeKey(id).flatMap({ EyeBlink.shared.pictures[$0] }), let shut = sourceImage(id, shut: true),
               EyeBlink.shutsEvenly(open: picture(of: art.texture), shut: shut, eyes: eyes) {
                let pose = IdlePose(shut: poseTexture(shut))
                cycle.poses = Dictionary(uniqueKeysWithValues: Direction.allCases.map { ($0, pose) })
            }
            return cycle
        }

        guard let sheet = generatedTexture(id) else {
            var frames: [Direction: [SKTexture]] = [:]
            for direction in Direction.allCases {
                frames[direction] = (0..<4).map { Placeholder.canvas(for: id, kind: kind, direction: direction, frame: $0).texture() }
            }
            return WalkCycle(frames: frames, size: CGSize(width: 48, height: 48) * scale)
        }

        let frameSize = CGFloat(asset?.frame ?? 48)
        let pixels = sheet.size()
        let layout = SheetLayout(asset: asset, width: pixels.width, height: pixels.height)
        var frames: [Direction: [SKTexture]] = [:]
        for direction in layout.directions {
            frames[direction] = layout.cells(for: direction).map { cell in
                // SpriteKit texture rects are normalised with the origin at the bottom-left.
                let rect = CGRect(
                    x: CGFloat(cell.column) * frameSize / pixels.width,
                    y: 1 - CGFloat(cell.row + 1) * frameSize / pixels.height,
                    width: frameSize / pixels.width,
                    height: frameSize / pixels.height
                )
                let texture = SKTexture(rect: rect, in: sheet)
                texture.filteringMode = .nearest
                return texture
            }
        }
        var cycle = WalkCycle(frames: frames, size: CGSize(width: frameSize, height: frameSize) * scale)
        cycle.poses = idlePoses(id, sheet: picture(of: sheet), layout: layout, frame: Int(frameSize))
        return cycle
    }

    /// Where a sheet's frames lie, to find each direction's first.
    private struct SheetFrames {
        let layout: SheetLayout
        let frame: Int
    }

    private func sheetFrames(_ id: String, width: Int, height: Int) -> SheetFrames? {
        let asset = asset(id)
        guard asset?.kind == "walk_sheet" else { return nil }
        return SheetFrames(layout: SheetLayout(asset: asset, width: CGFloat(width), height: CGFloat(height)), frame: asset?.frame ?? 48)
    }

    private func pngImage(_ id: String) -> CGImage? {
        pngURL(id).flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
    }

    private func pngSize(_ id: String) -> (width: Int, height: Int)? {
        pngImage(id).map { ($0.width, $0.height) }
    }

    /// Whose eyes `id` has in art/eyes.json: its own, its base's, or its layers' (the face on top's);
    /// nil when it has none.
    private func eyeKey(_ id: String, depth: Int = 0) -> String? {
        let blink = EyeBlink.shared
        if blink.pictures[id] != nil || blink.sheets[id] != nil { return id }
        guard pngURL(id) == nil, depth < 3, let derive = asset(id)?.derive else { return nil }
        if let layers = layerSets[id] ?? derive.layers,
           let key = layers.reversed().lazy.compactMap({ EyeBlink.key(forLayer: $0.id) }).first(where: { blink.sheets[$0] != nil }) {
            return key
        }
        return eyeKey(derive.from, depth: depth + 1)
    }

    /// `image`, a sprite's own PNG or one of its paper-doll layers, with the eyes `key` has in
    /// art/eyes.json shut: a single picture's on it, a walk sheet's in each direction's first frame.
    private func eyesShut(in image: CGImage, as key: String, frames: SheetFrames?) -> CGImage {
        let blink = EyeBlink.shared
        if let eyes = blink.pictures[key] { return EyeBlink.shut(image, eyes: eyes, lash: true) ?? image }
        guard let frames, let directions = blink.sheets[key] else { return image }
        let eyes = directions.flatMap { direction, eyes -> [Eye] in
            guard let cell = frames.layout.cells(for: direction).first else { return [] }
            return eyes.map { $0.moved(to: (cell.column * frames.frame, cell.row * frames.frame)) }
        }
        return EyeBlink.shut(image, eyes: eyes, lash: false) ?? image
    }

    /// Each direction's standing pose (its first frame) breathing out, and with its eyes shut where
    /// every eye it has that way shut (`EyeBlink.shutsEvenly`) and no other face shows an open one
    /// (`cleanFaces`): drawn from the sprite again with them shut, as it's dressed and recoloured.
    /// Never one eye: a wink.
    private func idlePoses(_ id: String, sheet: CGImage, layout: SheetLayout, frame: Int) -> [Direction: IdlePose] {
        let key = eyeKey(id)
        let eyes = key.flatMap { EyeBlink.shared.sheets[$0] }
        let layers = layerSets[id] ?? asset(id)?.derive?.layers
        let clean = key.flatMap { key in layers.map { cleanFaces($0, key: key, frames: SheetFrames(layout: layout, frame: frame)) } }
        let shutSheet = eyes == nil ? nil : sourceImage(id, shut: true)
        var poses: [Direction: IdlePose] = [:]
        for direction in layout.directions {
            guard let cell = layout.cells(for: direction).first else { continue }
            let rect = CGRect(x: cell.column * frame, y: cell.row * frame, width: frame, height: frame)
            guard let open = sheet.cropping(to: rect) else { continue }
            let shut = shutSheet?.cropping(to: rect).flatMap { closed in
                let even = EyeBlink.shutsEvenly(open: open, shut: closed, eyes: eyes?[direction] ?? [])
                return (clean?.contains(direction) ?? true) && even ? closed : nil
            }
            poses[direction] = IdlePose(shut: shut.map(poseTexture), out: EyeBlink.exhaled(open).map(poseTexture),
                                        outShut: shut.flatMap(EyeBlink.exhaled).map(poseTexture))
        }
        return poses
    }

    /// The ways a sprite stacked from `layers` can blink without an open eye left beside the shut
    /// ones: none with a helmet's or an armour sheet's own face over its head (`hat_`, `armor_`:
    /// their eyes lie elsewhere), and only where its head hides an armour sheet's face under it
    /// round its eyes, two pixels out.
    private func cleanFaces(_ layers: [ArtLayer], key: String, frames: SheetFrames) -> Set<Direction> {
        let isFace = { (id: String) in id.hasPrefix("hat_") || id.hasPrefix("armor_") }
        guard let top = layers.lastIndex(where: { EyeBlink.key(forLayer: $0.id) != nil }),
              !layers[(top + 1)...].contains(where: { isFace($0.id) }),
              let head = pngImage(layers[top].id) else { return [] }
        let under = layers[..<top].filter { isFace($0.id) }.compactMap { pngImage($0.id) }
        var clean = Set<Direction>()
        for (direction, eyes) in EyeBlink.shared.sheets[key] ?? [:] {
            guard let cell = frames.layout.cells(for: direction).first else { continue }
            let placed = eyes.map { $0.moved(to: (cell.column * frames.frame, cell.row * frames.frame)) }
            if under.allSatisfy({ EyeBlink.hides(head, over: $0, round: placed, margin: 2) }) {
                clean.insert(direction)
            }
        }
        return clean
    }

    private func poseTexture(_ image: CGImage) -> SKTexture {
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        remember(image, for: texture)
        return texture
    }

    /// A portrait for SwiftUI screens (unscaled pixels — draw with `.interpolation(.none)`).
    /// Walk sheets can be shown facing any direction.
    func image(_ id: String, facing direction: Direction = .down) -> UIImage {
        let cacheKey = direction == .down ? id : id + "#" + direction.rawValue
        if let cached = images[cacheKey] { return cached }
        let asset = asset(id)
        let kind = kind(of: id)
        var cgImage: CGImage?
        if let full = sourceImage(id) {
            if kind == "walk_sheet" {
                let frame = CGFloat(asset?.frame ?? 48)
                let layout = SheetLayout(asset: asset, width: CGFloat(full.width), height: CGFloat(full.height))
                if let cell = layout.cells(for: direction).first {
                    cgImage = full.cropping(to: CGRect(x: CGFloat(cell.column) * frame, y: CGFloat(cell.row) * frame, width: frame, height: frame))
                }
            } else {
                cgImage = full
            }
        }
        let image = UIImage(cgImage: cgImage ?? Placeholder.canvas(for: id, kind: kind, direction: direction).cgImage())
        images[cacheKey] = image
        return image
    }

    /// A round-portrait crop, like Fairyland Online's HUD faces: a square about one head high from the top
    /// of the sprite's visible pixels, centred on it. A hero's (or another adventurer's) is centred on
    /// their head as their plain body has it (`GearLook.body`, same poses, no hat), sized by that body:
    /// a tall hat or a hood measured from the top pushed the face to the bottom of the circle.
    /// Cleared with the sprite when it's re-registered.
    func face(_ id: String) -> UIImage {
        let cacheKey = id + "#face"
        if let cached = images[cacheKey] { return cached }
        let whole = image(id)
        guard let cgImage = whole.cgImage, let box = Self.visibleBounds(of: cgImage) else { return whole }
        var side = max(8, min(box.width, box.height * 0.62).rounded())
        // Centred on the head, not on the whole picture: a sparkle or a tail beside it would pull the
        // crop off it (playtesting 2026-10-31: "The head of the companion is not perfectly center in
        // the companion avatar", a Poison Skeleton's green spark).
        let middle = Self.headMiddle(of: cgImage, top: Int(box.minY), rows: Int(side)) ?? box.midX
        var rect = CGRect(x: min(max(0, (middle - side / 2).rounded()), max(0, CGFloat(cgImage.width) - side)),
                          y: max(0, box.minY - 1), width: side, height: side)
        if let plain = plainFrame(id), let body = Self.visibleBounds(of: plain), let head = Self.skinBounds(of: plain) {
            side = max(8, min(body.width, body.height * 0.62).rounded())
            let x = min(max(0, (head.midX - side / 2).rounded()), CGFloat(cgImage.width) - side)
            let y = min(max(0, (head.midY - side / 2).rounded()), CGFloat(cgImage.height) - side)
            rect = CGRect(x: x, y: y, width: side, height: side)
        }
        let face = cgImage.cropping(to: rect).map { UIImage(cgImage: $0) } ?? whole
        images[cacheKey] = face
        return face
    }

    /// The plain body (`GearLook.body`) a hero's sprite `id` is drawn on, facing you, cut from its
    /// sheet as `image(id)` cuts the sprite's frame; nil for anyone else.
    private func plainFrame(_ id: String) -> CGImage? {
        guard let body = gearLooks[id]?.body, let sheet = pngURL(body).flatMap({ UIImage(contentsOfFile: $0.path)?.cgImage }) else { return nil }
        let asset = asset(id)
        let frame = CGFloat(asset?.frame ?? 48)
        let layout = SheetLayout(asset: asset, width: CGFloat(sheet.width), height: CGFloat(sheet.height))
        guard let cell = layout.cells(for: .down).first else { return nil }
        return sheet.cropping(to: CGRect(x: CGFloat(cell.column) * frame, y: CGFloat(cell.row) * frame, width: frame, height: frame))
    }

    /// The box around a plain body's head: its skin's biggest patch (the bald scalp is skin too), as
    /// GearOverlay finds it, in pixels from the top left.
    private static func skinBounds(of image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var skin = [Bool](repeating: false, count: width * height)
        for i in 0..<(width * height) where pixels[i * 4 + 3] > 128 {
            let a = Double(pixels[i * 4 + 3])
            let r = Double(pixels[i * 4]) / a, g = Double(pixels[i * 4 + 1]) / a, b = Double(pixels[i * 4 + 2]) / a
            let high = max(r, g, b), low = min(r, g, b), delta = high - low
            var hue = 0.0
            if delta > 0 {
                if high == r { hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
                else if high == g { hue = 60 * ((b - r) / delta + 2) }
                else { hue = 60 * ((r - g) / delta + 4) }
            }
            if hue < 0 { hue += 360 }
            let saturation = high == 0 ? 0 : delta / high
            skin[i] = (hue <= 40 || hue >= 342) && saturation > 0.12 && saturation < 0.65 && high > 0.55
        }
        var seen = [Bool](repeating: false, count: width * height)
        var best: [Int] = []
        for start in 0..<(width * height) where skin[start] && !seen[start] {
            var stack = [start], patch: [Int] = []
            seen[start] = true
            while let i = stack.popLast() {
                patch.append(i)
                let x = i % width, y = i / width
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                where nx >= 0 && ny >= 0 && nx < width && ny < height && skin[ny * width + nx] && !seen[ny * width + nx] {
                    seen[ny * width + nx] = true
                    stack.append(ny * width + nx)
                }
            }
            if patch.count > best.count { best = patch }
        }
        guard let left = best.map({ $0 % width }).min(), let right = best.map({ $0 % width }).max(),
              let top = best.map({ $0 / width }).min(), let bottom = best.map({ $0 / width }).max() else { return nil }
        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }

    /// The box around a picture's opaque pixels, in pixels from its top left.
    /// The middle of a picture's head: down its top `rows` rows from `top`, the middle of each row's
    /// drawn pixels (its leftmost to its rightmost), and the median of those, so the few rows a
    /// sparkle or an ear sticks out on don't move it.
    private static func headMiddle(of image: CGImage, top: Int, rows: Int) -> CGFloat? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, top >= 0, top < height else { return nil }
        var middles: [CGFloat] = []
        for y in top..<min(height, top + max(1, rows)) {
            var left = -1, right = -1
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 128 {
                if left < 0 { left = x }
                right = x
            }
            if left >= 0 { middles.append(CGFloat(left + right + 1) / 2) }
        }
        guard !middles.isEmpty else { return nil }
        middles.sort()
        return middles.count % 2 == 1 ? middles[middles.count / 2]
            : (middles[middles.count / 2 - 1] + middles[middles.count / 2]) / 2
    }

    private static func visibleBounds(of image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

/// Where each direction's frames sit in a walk sheet: one row per direction (the usual
/// layout), or all frames on one row split evenly. Row order comes from `directions`.
private struct SheetLayout {
    let directions: [Direction]
    let columns: Int
    let rows: Int

    init(asset: ArtAsset?, width: CGFloat, height: CGFloat) {
        let frame = CGFloat(asset?.frame ?? 48)
        directions = (asset?.directions ?? Direction.allCases.map(\.rawValue)).compactMap(Direction.init(rawValue:))
        columns = max(1, Int(width / frame))
        rows = max(1, Int(height / frame))
    }

    func cells(for direction: Direction) -> [(column: Int, row: Int)] {
        guard let index = directions.firstIndex(of: direction) else { return [] }
        if rows >= directions.count {
            return (0..<columns).map { ($0, index) }
        }
        let perDirection = max(1, columns / max(1, directions.count))
        return (0..<perDirection).map { (index * perDirection + $0, 0) }
    }
}
