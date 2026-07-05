// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/domain/winner.dart';
import 'package:scythe_companion/models/players.dart';

ScoreEntry _entry(String name, int result) =>
    ScoreEntry(name, 0, 0, 0, 0, 0, 0, result);

void main() {
  group('rankScores', () {
    test('empty list returns empty', () {
      expect(rankScores([]), isEmpty);
    });

    test('single entry — rank 1, isWinner', () {
      final ranked = rankScores([_entry('Alice', 100)]);

      expect(ranked.length, 1);
      expect(ranked[0].rank, 1);
      expect(ranked[0].isWinner, true);
    });

    test('two distinct scores — ranks 1, 2', () {
      final ranked = rankScores([
        _entry('Alice', 100),
        _entry('Bob', 80),
      ]);

      expect(ranked.length, 2);
      expect(ranked[0].entry.name, 'Alice');
      expect(ranked[0].rank, 1);
      expect(ranked[0].isWinner, true);
      expect(ranked[1].entry.name, 'Bob');
      expect(ranked[1].rank, 2);
      expect(ranked[1].isWinner, false);
    });

    test('two-way tie — both rank 1', () {
      final ranked = rankScores([
        _entry('Alice', 100),
        _entry('Bob', 100),
      ]);

      expect(ranked.length, 2);
      expect(ranked[0].rank, 1);
      expect(ranked[0].isWinner, true);
      expect(ranked[1].rank, 1);
      expect(ranked[1].isWinner, true);
    });

    test('three-way tie — all rank 1', () {
      final ranked = rankScores([
        _entry('Alice', 50),
        _entry('Bob', 50),
        _entry('Carol', 50),
      ]);

      expect(ranked.length, 3);
      for (final r in ranked) {
        expect(r.rank, 1);
        expect(r.isWinner, true);
      }
    });

    test('tie + lower score — ranks 1, 1, 3 (standard competition)', () {
      final ranked = rankScores([
        _entry('Alice', 100),
        _entry('Bob', 100),
        _entry('Carol', 80),
      ]);

      expect(ranked[0].rank, 1);
      expect(ranked[0].isWinner, true);
      expect(ranked[1].rank, 1);
      expect(ranked[1].isWinner, true);
      expect(ranked[2].rank, 3);
      expect(ranked[2].isWinner, false);
    });

    test('all distinct — ranks 1, 2, 3, 4', () {
      final ranked = rankScores([
        _entry('D', 40),
        _entry('A', 100),
        _entry('C', 60),
        _entry('B', 80),
      ]);

      expect(ranked[0].entry.name, 'A');
      expect(ranked[0].rank, 1);
      expect(ranked[1].entry.name, 'B');
      expect(ranked[1].rank, 2);
      expect(ranked[2].entry.name, 'C');
      expect(ranked[2].rank, 3);
      expect(ranked[3].entry.name, 'D');
      expect(ranked[3].rank, 4);
    });

    test('unsorted input — output is sorted descending', () {
      final ranked = rankScores([
        _entry('Low', 10),
        _entry('High', 100),
        _entry('Mid', 50),
      ]);

      expect(ranked[0].entry.name, 'High');
      expect(ranked[1].entry.name, 'Mid');
      expect(ranked[2].entry.name, 'Low');
    });
  });

  group('findWinners', () {
    test('empty list returns empty', () {
      expect(findWinners([]), isEmpty);
    });

    test('single entry — that entry is the winner', () {
      final winners = findWinners([_entry('Alice', 100)]);

      expect(winners.length, 1);
      expect(winners.first.name, 'Alice');
    });

    test('two-way tie — both returned', () {
      final winners = findWinners([
        _entry('Alice', 100),
        _entry('Bob', 100),
      ]);

      expect(winners.length, 2);
      final names = winners.map((w) => w.name).toSet();
      expect(names, containsAll(['Alice', 'Bob']));
    });

    test('no tie — only top score returned', () {
      final winners = findWinners([
        _entry('Alice', 100),
        _entry('Bob', 99),
      ]);

      expect(winners.length, 1);
      expect(winners.first.name, 'Alice');
    });
  });
}
