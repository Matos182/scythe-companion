// SPDX-License-Identifier: MIT

/**
 * Per-IP rate limiting for socket connections.
 *
 * Two layers:
 *  1. Connection-rate: max N new connections per IP per minute (token
 *     bucket).  Prevents a misbehaving client from opening thousands of
 *     sockets.  Default 20/min (allows reconnect storms).
 *  2. Concurrent-connection cap: max M live sockets per IP at once.
 *     Default 10 (one player + reconnect churn + a few friends on NAT).
 *
 * Both are configurable via env (config.js).  The limiter is a plain
 * Map — it lives in memory and resets on server restart.  That's fine:
 * the goal is to stop accidental floods, not to survive a determined DDoS
 * (that's the reverse proxy's job, per D1).
 */

import { rateLimitPerMin, maxConnectionsPerIp } from './config.js';
import { ERROR_CODES, errorEnvelope } from './errors.js';
import logger from './logger.js';

const WINDOW_MS = 60_000; // 1 minute

/**
 * @typedef {Object} IpBucket
 * @property {number} tokens        — remaining connection tokens this window
 * @property {number} windowStart   — epoch ms when the window opened
 * @property {number} connections   — current live connections from this IP
 */

/** @type {Map<string, IpBucket>} */
const buckets = new Map();

/**
 * Get or create the bucket for an IP address.
 * @param {string} ip
 * @returns {IpBucket}
 */
function getBucket(ip) {
  let bucket = buckets.get(ip);
  if (!bucket) {
    bucket = { tokens: rateLimitPerMin, windowStart: Date.now(), connections: 0 };
    buckets.set(ip, bucket);
  }
  return bucket;
}

/**
 * Reset the token window if it has elapsed.
 * @param {IpBucket} bucket
 */
function maybeResetWindow(bucket) {
  const now = Date.now();
  if (now - bucket.windowStart >= WINDOW_MS) {
    bucket.tokens = rateLimitPerMin;
    bucket.windowStart = now;
  }
}

/**
 * Called on a new socket connection.  Returns true if the connection is
 * allowed, false if it should be rejected (rate limited).
 *
 * @param {string} ip — client IP address
 * @returns {{allowed: true} | {allowed: false, envelope: {code: string, message: string}}}
 */
export function allowConnection(ip) {
  const bucket = getBucket(ip);
  maybeResetWindow(bucket);

  // Concurrent connection cap.
  if (bucket.connections >= maxConnectionsPerIp) {
    logger.warn({ ip, connections: bucket.connections }, 'connection rejected: max concurrent');
    return {
      allowed: false,
      envelope: errorEnvelope(
        ERROR_CODES.RATE_MAX_CONNECTIONS,
        `Too many connections from your IP (max ${maxConnectionsPerIp}).`,
      ),
    };
  }

  // Token-bucket rate limit.
  if (bucket.tokens <= 0) {
    logger.warn({ ip, tokens: bucket.tokens }, 'connection rejected: rate limited');
    return {
      allowed: false,
      envelope: errorEnvelope(
        ERROR_CODES.RATE_LIMITED,
        'Too many connection attempts. Please wait a minute and try again.',
      ),
    };
  }

  bucket.tokens--;
  bucket.connections++;
  return { allowed: true };
}

/**
 * Called when a socket disconnects — decrements the concurrent-connection
 * counter for the IP.
 * @param {string} ip
 */
export function releaseConnection(ip) {
  const bucket = buckets.get(ip);
  if (!bucket) return;
  bucket.connections = Math.max(0, bucket.connections - 1);
}

/**
 * Clear all buckets (for tests).
 */
export function _reset() {
  buckets.clear();
}

/**
 * Get the current bucket state for an IP (for tests).
 * @param {string} ip
 * @returns {IpBucket | undefined}
 */
export function _getBucket(ip) {
  return buckets.get(ip);
}

export { rateLimitPerMin, maxConnectionsPerIp };
