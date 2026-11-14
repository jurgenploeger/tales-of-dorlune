#!/usr/bin/env python3
"""Mirror of TalesOfDorlune/World/Shadowcast.swift (recursive shadowcasting, a stack in place of
recursion, after SpriteCook's shadowcasting article), with the article's own tests. Keep the two in
step: a change to one goes into the other in the same commit.

  shadowcast.py            runs the tests (exit 1 on a failure)
"""
import sys

OCTANTS = [(1, 0, 0, 1), (0, 1, 1, 0), (0, -1, 1, 0), (-1, 0, 0, 1),
           (-1, 0, 0, -1), (0, -1, -1, 0), (0, 1, -1, 0), (1, 0, 0, -1)]


def visible(origin, radius, blocks):
    """Shadowcast.visible: the cells (col, row) the light at `origin` sees; `blocks(cell)` is a wall."""
    seen = {origin}
    if radius <= 0:
        return seen
    for xx, xy, yx, yy in OCTANTS:
        stack = [(1, 1.0, 0.0)]
        while stack:
            row, start, end = stack.pop()
            if start < end:
                continue
            new_start = 0.0
            for j in range(row, radius + 1):
                dy = -j
                blocked = False
                for dx in range(-j, 1):
                    left = (dx - 0.5) / (dy + 0.5)
                    right = (dx + 0.5) / (dy - 0.5)
                    if start < right:
                        continue
                    if end > left:
                        break
                    cell = (origin[0] + dx * xx + dy * xy, origin[1] + dx * yx + dy * yy)
                    if dx * dx + dy * dy < radius * radius:
                        seen.add(cell)
                    wall = blocks(cell)
                    if blocked:
                        if wall:
                            new_start = right
                        else:
                            blocked = False
                            start = new_start
                    elif wall and j < radius:
                        blocked = True
                        stack.append((j + 1, start, left))
                        new_start = right
                if blocked:
                    break
    return seen


def grid(w, h, walls=()):
    walls = set(walls)
    inside = lambda c: 0 <= c[0] < w and 0 <= c[1] < h
    # Off the grid counts as wall, as the article's does; only cells on it count as seen.
    return (lambda c: not inside(c) or c in walls), inside


def count(origin, radius, w, h, walls=()):
    blocks, inside = grid(w, h, walls)
    return {c for c in visible(origin, radius, blocks) if inside(c)}


def main():
    failures = []

    def expect(name, got, want):
        if got != want:
            failures.append(f"{name}: got {got}, want {want}")

    # The article's checks (x, y from 0 at the top left; the algorithm doesn't care which way is up).
    for r, n in ((3, 25), (4, 45), (5, 69)):
        expect(f"empty 11×11, radius {r}", len(count((5, 5), r, 11, 11)), n)
    s = count((5, 5), 4, 11, 11)
    expect("radius 4 sees (8, 5)", (8, 5) in s, True)
    expect("radius 4 doesn't see (9, 5)", (9, 5) in s, False)
    s = count((5, 5), 6, 11, 11, [(7, 5)])
    expect("one wall: 106 seen", len(s), 106)
    expect("the wall itself is seen", (7, 5) in s, True)
    expect("behind the wall isn't", any(c in s for c in ((8, 5), (9, 5), (10, 5))), False)
    every = [(x, y) for x in range(7) for y in range(7)]
    expect("all walls, radius 3", len(count((3, 3), 3, 7, 7, every)), 9)
    expect("corner of 6×6, radius 4", len(count((0, 0), 4, 6, 6)), 15)
    column = [(5, y) for y in range(11)]
    blocks, inside = grid(11, 11, column)
    expect("a wall between: unseen", (8, 5) in visible((2, 5), 10, blocks), False)
    blocks, inside = grid(11, 11, [c for c in column if c != (5, 5)])
    expect("a gap in it: seen", (8, 5) in visible((2, 5), 10, blocks), True)
    # Turned 90 degrees, the same.
    a = count((5, 5), 5, 11, 11, [(7, 4), (3, 6)])
    b = count((5, 5), 5, 11, 11, [(4, 3), (6, 7)])  # (x, y) → (10 - y, x)
    expect("turned a quarter, the same", {(10 - y, x) for x, y in a} == b, True)
    for f in failures:
        print("✗ " + f)
    print("✓ all shadowcasting tests pass" if not failures else f"✗ {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
