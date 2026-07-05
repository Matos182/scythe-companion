// SPDX-License-Identifier: MIT

import { describe, it, expect } from 'vitest';
import { playerFactions, reorderPlayers } from '../src/factionWheel.js';

/** Helper: create a player object matching the old server shape. */
function p(nickname, faction, mat) {
  return { nickname, playerfaction: faction, playermat: mat };
}

describe('playerFactions', () => {
  it('has 7 factions in wheel order', () => {
    expect(playerFactions).toEqual([
      'Crimea',
      'Saxony',
      'Polania',
      'Albion',
      'Nordic',
      'Rusviet',
      'Togawa',
    ]);
  });
});

describe('reorderPlayers', () => {
  it('fixture 1 — 2 players, Crimea(mat 1) + Rusviet(mat 2)', () => {
    // Sorted by mat: Crimea(1), Rusviet(2).  First = Crimea (index 0 in
    // wheel).  Wheel order from Crimea: Crimea, Saxony, ..., Rusviet.
    // Only Crimea and Rusviet exist → [Crimea, Rusviet].
    const result = reorderPlayers([
      p('Alice', 'Rusviet', '2'),
      p('Bob', 'Crimea', '1'),
    ]);
    expect(result.map((pl) => pl.nickname)).toEqual(['Bob', 'Alice']);
  });

  it('fixture 2 — 3 players, Polania leads (mat 1)', () => {
    // Mats: Polania(1), Crimea(2), Nordic(3).  First = Polania (index 2
    // in wheel).  Wheel from Polania: Polania, Albion, Nordic, Rusviet,
    // Togawa, Crimea, Saxony.  Present: Polania, Nordic, Crimea.
    const result = reorderPlayers([
      p('A', 'Crimea', '2'),
      p('B', 'Polania', '1'),
      p('C', 'Nordic', '3'),
    ]);
    expect(result.map((pl) => pl.nickname)).toEqual(['B', 'C', 'A']);
  });

  it('fixture 3 — 4 players, Togawa leads (mat 1)', () => {
    // Mats: Togawa(1), Saxony(2), Albion(3), Rusviet(4).
    // First = Togawa (index 6).  Wheel from Togawa: Togawa, Crimea,
    // Saxony, Polania, Albion, Nordic, Rusviet.
    // Present: Togawa, Saxony, Albion, Rusviet.
    const result = reorderPlayers([
      p('W', 'Saxony', '2'),
      p('X', 'Togawa', '1'),
      p('Y', 'Albion', '3'),
      p('Z', 'Rusviet', '4'),
    ]);
    expect(result.map((pl) => pl.nickname)).toEqual(['X', 'W', 'Y', 'Z']);
  });

  it('fixture 4 — full 7-player game, mat order matches faction wheel', () => {
    // Each faction gets the mat matching its wheel position (Crimea=1,
    // Saxony=2, ...).  After sort, order = mat 1..7 = wheel order.
    // First = Crimea.  Wheel from Crimea = full wheel → same order.
    const players = playerFactions.map((f, i) =>
      p(`P${i}`, f, String(i + 1)),
    );
    // Shuffle input to prove sort works
    const shuffled = [...players].reverse();
    const result = reorderPlayers(shuffled);
    expect(result.map((pl) => pl.playerfaction)).toEqual(playerFactions);
  });

  it('fixture 5 — mat 2A and 3A sort correctly (A8 edge case)', () => {
    // Mats with letter suffixes: '1','2','2A','3','3A','4'.
    // String sort: '1' < '2' < '2A' < '3' < '3A' < '4'.  ✓
    // First = Crimea (mat 1).  Players:
    //   Crimea(1), Saxony(2), Polania(2A), Albion(3), Nordic(3A), Rusviet(4)
    // Wheel from Crimea: Crimea, Saxony, Polania, Albion, Nordic, Rusviet.
    // All present → same order as input sorted.
    const result = reorderPlayers([
      p('A', 'Rusviet', '4'),
      p('B', 'Nordic', '3A'),
      p('C', 'Albion', '3'),
      p('D', 'Polania', '2A'),
      p('E', 'Saxony', '2'),
      p('F', 'Crimea', '1'),
    ]);
    expect(result.map((pl) => pl.playermat)).toEqual([
      '1', '2', '2A', '3', '3A', '4',
    ]);
    expect(result.map((pl) => pl.playerfaction)).toEqual([
      'Crimea', 'Saxony', 'Polania', 'Albion', 'Nordic', 'Rusviet',
    ]);
  });

  it('does not mutate the input array', () => {
    const input = [p('A', 'Rusviet', '2'), p('B', 'Crimea', '1')];
    const inputCopy = [...input];
    reorderPlayers(input);
    expect(input.map((pl) => pl.nickname)).toEqual(inputCopy.map((pl) => pl.nickname));
  });
});
