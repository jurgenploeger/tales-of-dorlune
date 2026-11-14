import Foundation

/// Which cells a light can see on a grid of walls: Björn Bergström's recursive shadowcasting, a stack
/// in place of recursion, after SpriteCook's shadowcasting article (docs/spritecook-notes.md). The
/// cave's light stops at its rock with it (`WorldScene.castLight`, `Lantern.shade`), and the cave's map
/// fills in only with what the light has reached. Mirrored, with the article's own tests, by
/// `tools/shadowcast.py`; keep the two in step.
nonisolated enum Shadowcast {
    /// The eight slices round the light, as (xx, xy, yx, yy): how a step along a row (dx) and a row
    /// further out (dy) map to columns and rows.
    private static let octants: [(xx: Int, xy: Int, yx: Int, yy: Int)] = [
        (1, 0, 0, 1), (0, 1, 1, 0), (0, -1, 1, 0), (-1, 0, 0, 1),
        (-1, 0, 0, -1), (0, -1, -1, 0), (0, 1, -1, 0), (1, 0, 0, -1),
    ]

    /// Every cell the light at `origin` sees within `radius` cells (one exactly `radius` away isn't),
    /// the walls it lights included. `blocks`: whether light can't pass a cell.
    static func visible(from origin: GridPoint, radius: Int, blocks: (GridPoint) -> Bool) -> Set<GridPoint> {
        var seen: Set<GridPoint> = [origin]
        guard radius > 0 else { return seen }
        for o in octants {
            var stack: [(row: Int, start: Double, end: Double)] = [(1, 1.0, 0.0)]
            while let item = stack.popLast() {
                var start = item.start
                let end = item.end
                if start < end { continue }
                var newStart = 0.0
                var j = item.row
                while j <= radius {
                    let dy = -j
                    var blocked = false
                    var dx = -j
                    while dx <= 0 {
                        let left = (Double(dx) - 0.5) / (Double(dy) + 0.5)
                        let right = (Double(dx) + 0.5) / (Double(dy) - 0.5)
                        if start < right {
                            dx += 1
                            continue
                        }
                        if end > left { break }
                        let cell = GridPoint(col: origin.col + dx * o.xx + dy * o.xy, row: origin.row + dx * o.yx + dy * o.yy)
                        if dx * dx + dy * dy < radius * radius { seen.insert(cell) }
                        let wall = blocks(cell)
                        if blocked {
                            if wall {
                                newStart = right
                            } else {
                                blocked = false
                                start = newStart
                            }
                        } else if wall, j < radius {
                            blocked = true
                            stack.append((j + 1, start, left))
                            newStart = right
                        }
                        dx += 1
                    }
                    if blocked { break }
                    j += 1
                }
            }
        }
        return seen
    }
}
