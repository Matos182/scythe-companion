// SPDX-License-Identifier: MIT

/**
 * Faction wheel — turn-order logic for Scythe (audit A8).
 *
 * Extracted verbatim from the old `server/index.js` (lines 16–75) so the
 * behavior is preserved exactly and pinned by unit tests.  The faction
 * array defines the circular turn order; `reorderPlayers` sorts players
 * by their player-mat (ascending string sort), then rotates the result
 * so the first player in faction-wheel order leads.
 *
 * Player mats are '1','2','2A','3','3A','4','5' — string sort works
 * because the numeric prefixes are single-digit and letter suffixes sort
 * correctly.  If Invaders from Afar mats are added (mind C5), verify the
 * sort still holds.
 */

/** Faction names in wheel order (clockwise on the game board). */
export const playerFactions = [
  'Crimea',
  'Saxony',
  'Polania',
  'Albion',
  'Nordic',
  'Rusviet',
  'Togawa',
];

/**
 * Reorders players by mat (ascending), then rotates so the faction-wheel-
 * order leader starts.  Does NOT mutate the input array.
 *
 * @param {Array<{playerfaction: string, playermat: string}>} players
 * @returns {Array<typeof players>} new array in turn order
 */
export function reorderPlayers(players) {
  const sorted = [...players].sort((a, b) => {
    if (a.playermat < b.playermat) return -1;
    if (a.playermat > b.playermat) return 1;
    return 0;
  });

  const firstPlayer = sorted[0];
  let currentIndex = playerFactions.indexOf(firstPlayer.playerfaction);

  const reordered = [];
  for (let i = 0; i < playerFactions.length; i++) {
    const currentFaction = playerFactions[currentIndex];
    const currentPlayer = sorted.find(
      (p) => p.playerfaction === currentFaction,
    );
    if (currentPlayer) {
      reordered.push(currentPlayer);
    }
    currentIndex++;
    if (currentIndex >= playerFactions.length) {
      currentIndex = 0;
    }
  }
  return reordered;
}
