// SPDX-License-Identifier: MIT

/// T3.5: human-friendly text for the structured error envelope emitted
/// by the server (T2.4) and the client-side fallback codes (T3.1).
///
/// Lives in `lib/data/` because it depends on nothing but [SocketError]
/// (also in lib/data) — no Flutter imports, so it's trivially
/// unit-testable and the strings stay in one place when Phase 3 adds
/// PT localisation (per AGENTS.md C6: user-facing strings centralised).
///
/// Why a mapping here, not in the server: the server's `message` field
/// is English-only and aimed at developers; the client owns the
/// translation to the player's voice, plus the choice of which codes
/// are worth showing at all (e.g. PROTOCOL_MISMATCH is a client-only
/// code — the server never sends it).
library;

import 'socket_service.dart';

/// Convert a structured [SocketError] into text the user can act on.
///
/// Falls back to the server-supplied `message` when we have no
/// user-friendly copy for the code (covers legacy servers that emit
/// errors we haven't catalogued yet, or future codes that beat us to
/// the client). The fallback is intentional — silently dropping an
/// error is worse than a slightly developer-y sentence.
String humanizeError(SocketError error) {
  final message = _messages[error.code];
  if (message != null) return message;
  // Fall through to the server's text. Some legacy errors arrive as
  // code: 'UNKNOWN' with a developer message — better than nothing.
  final raw = error.message;
  return raw.isEmpty ? 'Something went wrong. Please try again.' : raw;
}

/// All codes we recognise. Keep this list in sync with:
///  - server/src/errors.js (the wire catalogue — T2.4 hand-off)
///  - lib/data/socket_service.dart (client-side PROTOCOL_MISMATCH,
///    CLIENT_BAD_PAYLOAD, UNKNOWN)
const Map<String, String> _messages = {
  // ── Validation (VAL_*) — user typed something wrong ─────────────
  'VAL_MISSING_NICKNAME': "Please enter a nickname before joining the game.",
  'VAL_MISSING_ROOM_ID': "Please enter a room code (or scan the creator's QR).",
  'VAL_MISSING_FIELDS':
      "Some required fields are missing. Please check the form.",
  'VAL_INVALID_TIMER': "That turn time isn't valid. Pick one of the options.",
  'VAL_INVALID_FACTION':
      "That faction isn't recognised. Pick one from the list.",
  'VAL_INVALID_MAT': "That player mat isn't valid. Pick one from the list.",
  'VAL_BAD_PAYLOAD':
      "The server didn't understand the request. Please try again.",

  // ── State (STATE_*) — the game is in the wrong shape ─────────────
  'STATE_ROOM_NOT_FOUND':
      "Room not found. Double-check the code, or ask the creator for a new one.",
  'STATE_GAME_IN_PROGRESS':
      "That game has already started — ask the creator for the new room code.",
  'STATE_FACTION_OR_MAT_TAKEN':
      "Someone in the room already picked that faction or mat. Choose another.",
  'STATE_SINGLE_PLAYER':
      "You need at least two players before the game can start.",
  'STATE_NOT_YOUR_TURN':
      "It's not your turn yet — only the current player can pass.",
  'STATE_PASS_FAILED': "The turn couldn't be passed. Please try again.",

  // ── Rejoin (REJOIN_*) — the stored session is dead ───────────────
  'REJOIN_NOT_FOUND':
      "Your previous game has ended. Head back to the home menu to start a new one.",

  // ── Rate limiting (RATE_*) — too many connections ───────────────
  'RATE_LIMITED':
      "Too many requests in a short time. Wait a moment and try again.",
  'RATE_MAX_CONNECTIONS':
      "This server already has the maximum number of players connected.",

  // ── Server-side capacity (SERVER_*) ──────────────────────────────
  'SERVER_MAX_ROOMS':
      "The server is hosting the maximum number of rooms. Try again later.",

  // ── Client-side codes (T3.1, T3.2) — never sent by the server ──
  'PROTOCOL_MISMATCH':
      "This app version doesn't match the server. Please update the app.",
  'CLIENT_BAD_PAYLOAD':
      "The server sent an unexpected response. Please try again.",
  'UNKNOWN': "Something went wrong. Please try again.",
};
