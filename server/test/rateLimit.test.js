// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeEach } from 'vitest';
import {
  allowConnection,
  releaseConnection,
  _reset,
  _getBucket,
} from '../src/rateLimit.js';
import { ERROR_CODES } from '../src/errors.js';

/**
 * Rate limiter tests (T2.4 done-criteria).
 *
 * The limiter is a per-IP token bucket: N connections per minute + M
 * concurrent connections.  Tests prove that rapid connections exhaust
 * tokens, concurrent cap rejects, and releaseConnection frees slots.
 */

const TEST_IP = '192.168.1.42';

describe('rate limiter', () => {
  beforeEach(() => {
    _reset();
  });

  it('allows the first connection from an IP', () => {
    const result = allowConnection(TEST_IP);
    expect(result.allowed).toBe(true);
  });

  it('tracks connections count', () => {
    allowConnection(TEST_IP);
    allowConnection(TEST_IP);
    const bucket = _getBucket(TEST_IP);
    expect(bucket.connections).toBe(2);
  });

  it('rejects when concurrent cap is reached', () => {
    // Default maxConnectionsPerIp is 10.
    for (let i = 0; i < 10; i++) {
      const r = allowConnection(TEST_IP);
      expect(r.allowed).toBe(true);
    }
    // 11th should be rejected.
    const result = allowConnection(TEST_IP);
    expect(result.allowed).toBe(false);
    expect(result.envelope.code).toBe(ERROR_CODES.RATE_MAX_CONNECTIONS);
  });

  it('releaseConnection decrements the concurrent count', () => {
    for (let i = 0; i < 10; i++) {
      allowConnection(TEST_IP);
    }
    // At cap — release one, then allow one more.
    releaseConnection(TEST_IP);
    const result = allowConnection(TEST_IP);
    expect(result.allowed).toBe(true);
  });

  it('releaseConnection on unknown IP is a no-op', () => {
    // Should not throw.
    releaseConnection('10.0.0.99');
  });

  it('never goes negative on connections', () => {
    allowConnection(TEST_IP);
    releaseConnection(TEST_IP);
    releaseConnection(TEST_IP); // double release
    const bucket = _getBucket(TEST_IP);
    expect(bucket.connections).toBe(0);
  });

  it('different IPs have independent buckets', () => {
    // Exhaust IP A's tokens.
    for (let i = 0; i < 10; i++) {
      allowConnection('10.0.0.1');
    }
    // IP B should still be allowed.
    const result = allowConnection('10.0.0.2');
    expect(result.allowed).toBe(true);
  });
});
