import Foundation

/// How a chest out in the world looks (the user, 2026-11-26): closed, in its land's own style, till it's
/// opened (maps.json theme `chest`, ChatGPT's drawings, `tools/chest_art.py`), then open (its NPC art,
/// RD's `treasure_chest`). Found by stumbling on it: no "!" and nothing on the maps (`GameSession.notice`,
/// `minimapKind`).
enum ChestLook {
    /// The land's closed chest, if it has one drawn.
    @MainActor static func closed(in def: MapDef, art: ArtLibrary) -> String? {
        guard let id = def.theme.chest, art.asset(id) != nil else { return nil }
        return id
    }

    /// The land's chest opened: its style's open drawing (`<closed>_open`) where there is one, else `fallback`
    /// (the chest's NPC art, RD's open `treasure_chest`).
    @MainActor static func open(in def: MapDef, art: ArtLibrary, fallback: String) -> String {
        guard let closed = closed(in: def, art: art), art.asset(closed + "_open") != nil else { return fallback }
        return closed + "_open"
    }
}
