// SPDX-License-Identifier: MIT

import 'package:scythe_companion/domain/score_calculator.dart';
import 'package:scythe_companion/domain/models/score_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coinsFor — tier boundaries', () {
    /// Helper: score with fixed inputs, only popularity varies.
    int scoreWithPopularity(int pop) => coinsFor(ScoreInput(
          name: 'Test',
          popularity: pop,
          stars: 6,
          lands: 10,
          resources: 8,
          buildings: 4,
          coins: 5,
        ));

    test('pop 0 → tier 1 (×3/×2/×1)', () {
      // stars 6×3=18, lands 10×2=20, res 4×1=4, bld 4, coins 5 → 51
      expect(scoreWithPopularity(0), 51);
    });

    test('pop 6 → still tier 1 (upper boundary inclusive)', () {
      expect(scoreWithPopularity(6), 51);
    });

    test('pop 7 → tier 2 (×4/×3/×2)', () {
      // stars 6×4=24, lands 10×3=30, res 4×2=8, bld 4, coins 5 → 71
      expect(scoreWithPopularity(7), 71);
    });

    test('pop 12 → still tier 2 (upper boundary inclusive)', () {
      expect(scoreWithPopularity(12), 71);
    });

    test('pop 13 → tier 3 (×5/×4/×3)', () {
      // stars 6×5=30, lands 10×4=40, res 4×3=12, bld 4, coins 5 → 91
      expect(scoreWithPopularity(13), 91);
    });

    test('pop 18 → still tier 3 (max popularity)', () {
      expect(scoreWithPopularity(18), 91);
    });
  });

  group('coinsFor — resources floor (÷2, truncated)', () {
    int scoreWithResources(int res) => coinsFor(ScoreInput(
          popularity: 1, // tier 1: res ×1
          resources: res,
        ));

    test('even resources: exact half', () {
      // 8 resources → 4 coin-pairs × 1 = 4
      expect(scoreWithResources(8), 4);
    });

    test('odd resources: floored (9 → 4)', () {
      // 9 resources → floor(9/2) = 4 coin-pairs × 1 = 4
      expect(scoreWithResources(9), 4);
    });

    test('1 resource → 0 coins', () {
      // floor(1/2) = 0
      expect(scoreWithResources(1), 0);
    });

    test('0 resources → 0 coins', () {
      expect(scoreWithResources(0), 0);
    });

    test('odd resources at tier 2 (×2)', () {
      // 9 → 4 pairs × 2 = 8
      expect(
        coinsFor(ScoreInput(popularity: 7, resources: 9)),
        8,
      );
    });

    test('odd resources at tier 3 (×3)', () {
      // 9 → 4 pairs × 3 = 12
      expect(
        coinsFor(ScoreInput(popularity: 13, resources: 9)),
        12,
      );
    });
  });

  group('coinsFor — zeros and edge cases', () {
    test('all-zero input → 0', () {
      expect(coinsFor(const ScoreInput()), 0);
    });

    test('only coins (no tier bonus) → coins face value', () {
      expect(coinsFor(const ScoreInput(coins: 10)), 10);
    });

    test('only buildings → buildings face value', () {
      expect(coinsFor(const ScoreInput(buildings: 7)), 7);
    });

    test('only stars at tier 1 → stars × 3', () {
      expect(coinsFor(const ScoreInput(popularity: 0, stars: 6)), 18);
    });

    test('only lands at tier 3 → lands × 4', () {
      expect(coinsFor(const ScoreInput(popularity: 18, lands: 10)), 40);
    });

    test('negative popularity treated as tier 1 (< 7)', () {
      // Defensive: the UI clamps to 0, but verify the formula doesn't break.
      expect(coinsFor(const ScoreInput(popularity: -1, stars: 2)), 6);
    });
  });

  group('coinsFor — 7-player batch', () {
    /// Simulates a full 7-player game where each player has different
    /// stats. Verifies the calculator handles a realistic batch without
    /// state leakage (it's a pure function, so each call is independent).
    test('7 players, mixed tiers, each score is independent', () {
      final inputs = <ScoreInput>[
        ScoreInput(
            name: 'P1',
            popularity: 18,
            stars: 6,
            lands: 12,
            resources: 10,
            buildings: 5,
            coins: 3),
        ScoreInput(
            name: 'P2',
            popularity: 13,
            stars: 4,
            lands: 8,
            resources: 6,
            buildings: 2,
            coins: 7),
        ScoreInput(
            name: 'P3',
            popularity: 7,
            stars: 3,
            lands: 6,
            resources: 5,
            buildings: 1,
            coins: 0),
        ScoreInput(
            name: 'P4',
            popularity: 6,
            stars: 2,
            lands: 4,
            resources: 3,
            buildings: 0,
            coins: 2),
        ScoreInput(
            name: 'P5',
            popularity: 0,
            stars: 1,
            lands: 2,
            resources: 2,
            buildings: 1,
            coins: 1),
        ScoreInput(
            name: 'P6',
            popularity: 12,
            stars: 5,
            lands: 10,
            resources: 8,
            buildings: 3,
            coins: 4),
        ScoreInput(
            name: 'P7',
            popularity: 1,
            stars: 0,
            lands: 0,
            resources: 0,
            buildings: 0,
            coins: 0),
      ];

      final scores = inputs.map(coinsFor).toList();

      // P1: tier3: 6×5=30 + 12×4=48 + 5×3=15 + 5 + 3 = 101
      expect(scores[0], 101);
      // P2: tier3: 4×5=20 + 8×4=32 + 3×3=9 + 2 + 7 = 70
      expect(scores[1], 70);
      // P3: tier2: 3×4=12 + 6×3=18 + 2×2=4 + 1 + 0 = 35
      expect(scores[2], 35);
      // P4: tier1: 2×3=6 + 4×2=8 + 1×1=1 + 0 + 2 = 17
      expect(scores[3], 17);
      // P5: tier1: 1×3=3 + 2×2=4 + 1×1=1 + 1 + 1 = 10
      expect(scores[4], 10);
      // P6: tier2: 5×4=20 + 10×3=30 + 4×2=8 + 3 + 4 = 65
      expect(scores[5], 65);
      // P7: all zeros → 0
      expect(scores[6], 0);
    });
  });
}
