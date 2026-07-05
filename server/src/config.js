// SPDX-License-Identifier: MIT

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

/**
 * Max concurrent rooms per server instance.  Prevents a single host from
 * being overwhelmed by room-spam.  Default 100 is plenty for a friends'
 * game server; raise for a bigger deployment.
 * @type {number}
 */
export const maxRooms = Number(process.env.MAX_ROOMS ?? 100);

/**
 * Per-IP rate limit for socket connection attempts (per minute).
 * Default 20 — allows reconnect storms without throttling legitimate play.
 * @type {number}
 */
export const rateLimitPerMin = Number(process.env.RATE_LIMIT_PER_MIN ?? 20);

/**
 * Max concurrent socket connections per IP.  Default 10 — one player on
 * a phone, plus reconnect churn, plus a couple of friends on the same NAT.
 * @type {number}
 */
export const maxConnectionsPerIp = Number(process.env.MAX_CONNECTIONS_PER_IP ?? 10);

/**
 * Pino log level.  'info' for production, 'debug' for dev.
 * @type {string}
 */
export const logLevel = process.env.LOG_LEVEL ?? 'info';
