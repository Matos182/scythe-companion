/**
 * Centralised environment configuration.
 *
 * Reads from process.env (populated by dotenv in the entry point) and
 * exposes typed constants.  Everything that depends on the environment
 * imports from here — never reads process.env directly in business logic.
 *
 * Why a module?  See audit A4: the old server hard-coded the port, had no
 * CORS config, and reached into the Flutter tree for credentials.  This
 * keeps all knobs in one testable place.
 */

/** @type {number} HTTP/WS listen port (default 3000). */
export const port = Number(process.env.PORT ?? 3000);

/**
 * Allowed CORS origins.
 * '*' is fine for dev/LAN; in production set the exact reverse-proxy URL.
 * @type {string}
 */
export const corsOrigin = process.env.CORS_ORIGIN ?? '*';

/** @type {number} Idle-room TTL in hours (D2 — in-memory store sweeper). */
export const roomTtlHours = Number(process.env.ROOM_TTL_HOURS ?? 3);

/**
 * Minimum seconds remaining when a turn starts (audit A6 — the old server
 * silently reset timers to 10 if below 10; now this is an explicit config
 * knob).  Ensures every player gets at least this much time even if the
 * allowance was partially consumed by an auto-pass.
 * @type {number}
 */
export const minTurnSec = Number(process.env.MIN_TURN_SEC ?? 10);
