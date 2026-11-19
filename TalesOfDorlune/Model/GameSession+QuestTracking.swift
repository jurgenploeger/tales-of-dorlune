import Foundation

/// One quest followed on the HUD (the user's UI review, 2026-11-19): a plate under the minimap with
/// its name and what's next (`WorldHUD`'s `TrackedQuestPlate`), chosen with Track in its window
/// (`QuestWindow`), one at a time; and where a quest is done, for its Show on map.
extension GameSession {
    /// The quest followed on the HUD, while you're still on it: one handed in is followed no more.
    var trackedQuest: QuestDef? {
        guard let id = data.trackedQuest, data.quests[id]?.state == .active else { return nil }
        return content.quest(id)
    }

    func isTracked(_ quest: QuestDef) -> Bool { trackedQuest?.id == quest.id }

    /// Follows `quest` on the HUD, in place of the one followed before, or stops following it.
    func track(_ quest: QuestDef, _ on: Bool) {
        if on {
            data.trackedQuest = quest.id
        } else if data.trackedQuest == quest.id {
            data.trackedQuest = nil
        }
    }

    /// What's next on a quest, short, for the HUD: how far along ("3/10"), who to take it to, or who
    /// to report back to. Nil for one you're not on.
    func nextStep(of quest: QuestDef) -> String? {
        switch status(of: quest) {
        case .ready:
            return L("Report to {name}", ["name": content.npc(quest.giver)?.name ?? ""])
        case .active(let progress, let goal):
            if quest.objective.type == .deliver {
                return L("Take it to {name}", ["name": quest.objective.target.flatMap(content.npc)?.name ?? ""])
            }
            return "\(progress)/\(goal)"
        default:
            return nil
        }
    }

    /// Where a quest is done, a land's or a cave's id for the world map (`mapFocus`): who to take it to
    /// for a favour, where the monsters it wants live (or the ones that drop what it wants), else, and
    /// once it's ready to hand in, where its giver lives.
    func questPlace(of quest: QuestDef) -> String? {
        let giverHome = content.home(ofNPC: quest.giver)?.id
        guard case .active = status(of: quest) else { return giverHome }
        switch quest.objective.type {
        case .deliver:
            return quest.objective.target.flatMap { content.home(ofNPC: $0)?.id } ?? giverHome
        case .defeat, .capture:
            return quest.objective.target.flatMap { habitat(of: $0) } ?? giverHome
        case .bring:
            let monsters = (quest.drops ?? []).flatMap(\.from)
            return monsters.lazy.compactMap { self.habitat(of: $0) }.first ?? giverHome
        case .reachLevel, .chooseClass, .collect, .hatch, .cards:
            return giverHome
        }
    }

    /// The land (or cave) a monster lives in: the one you're in when it lives there too, else where
    /// it turns up at the lowest levels, or waits as a boss.
    func habitat(of monsterID: String) -> String? {
        var best: (id: String, level: Int)?
        for map in content.maps {
            var level: Int?
            if let encounters = map.encounters, encounters.monsters[monsterID] != nil {
                level = encounters.levels.first ?? 1
            }
            for npc in map.npcs ?? [] where npc.role == .boss && npc.monster == monsterID {
                level = min(level ?? Int.max, npc.level ?? 1)
            }
            guard let level else { continue }
            if map.id == data.mapID { return map.id }
            if level < (best?.level ?? Int.max) { best = (map.id, level) }
        }
        return best?.id
    }
}
