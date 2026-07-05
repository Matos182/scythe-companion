/**
 * Wire-protocol event-name constants (D5).
 *
 * Centralising these avoids typo-prone string literals scattered across
 * handlers and tests.  The names themselves match the existing server
 * vocabulary so the Flutter client keeps working until the formal
 * protocol versioning lands in T2.1.
 *
 * Convention:  CLIENT→SERVER events are "actions"; SERVER→CLIENT events
 * are "events".  Both are plain strings on the wire.
 */

// ── Client → Server (incoming actions) ─────────────────────────────
export const CREATE_ROOM = 'createRoom';
export const JOIN_ROOM = 'joinRoom';
export const START_GAME = 'startGame';
export const TURN = 'turn';
export const PAUSE = 'pause';
export const RESUME = 'toContinue'; // renamed in T1.4; wire name stays until T2.1
export const REJOIN_ROOM = 'rejoinRoom';

// ── Server → Client (outgoing events) ──────────────────────────────
export const CREATE_ROOM_SUCCESS = 'createRoomSuccess';
export const JOIN_ROOM_SUCCESS = 'joinRoomSuccess';
export const UPDATE_ROOM = 'updateRoom';
export const NEW_TURN = 'newTurn';
export const TICK = 'tick';
export const ERROR_OCCURRED = 'errorOccurred';

/** Protocol version — bumped when the wire format changes (D5). */
export const PROTOCOL_VERSION = 1;
