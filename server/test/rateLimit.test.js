// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  allowConnection,
  releaseConnection,
  clientIp,
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

/**
 * clientIp() tests (T4.7b done-criteria).
 *
 * trustProxy is read from env at module load, so the flag-on cases set
 * process.env.TRUST_PROXY and re-import the module fresh via
 * vi.resetModules().  The flag-off case uses the top-level import
 * (default false).
 */

/** Build a minimal socket-shaped object for clientIp(). */
function fakeSocket({ address = '172.18.0.2', xff } = {}) {
  const headers = {};
  if (xff !== undefined) headers['x-forwarded-for'] = xff;
  return { handshake: { address, headers } };
}

describe('clientIp (proxy-aware rate-limit key)', () => {
  const savedTrustProxy = process.env.TRUST_PROXY;

  afterEach(() => {
    if (savedTrustProxy === undefined) {
      delete process.env.TRUST_PROXY;
    } else {
      process.env.TRUST_PROXY = savedTrustProxy;
    }
  });

  it('flag off: spoofed XFF header is ignored, handshake address is used', () => {
    // Top-level import has TRUST_PROXY unset → trustProxy=false.
    const ip = clientIp(fakeSocket({ xff: '203.0.113.99' }));
    expect(ip).toBe('172.18.0.2');
  });

  it('flag on: two different XFF IPs get separate buckets', async () => {
    process.env.TRUST_PROXY = 'true';
    vi.resetModules();
    const fresh = await import('../src/rateLimit.js');
    fresh._reset();

    // Exhaust the concurrent cap for client A via its XFF.
    for (let i = 0; i < 10; i++) {
      const r = fresh.allowConnection(
        fresh.clientIp(fakeSocket({ xff: '203.0.113.1' })),
      );
      expect(r.allowed).toBe(true);
    }
    expect(
      fresh.allowConnection(fresh.clientIp(fakeSocket({ xff: '203.0.113.1' })))
        .allowed,
    ).toBe(false);

    // Client B (different XFF, same proxy behind it) is unaffected.
    const b = fresh.allowConnection(
      fresh.clientIp(fakeSocket({ xff: '198.51.100.7' })),
    );
    expect(b.allowed).toBe(true);

    // First entry of a multi-hop XFF wins; later entries are untrusted.
    expect(
      fresh.clientIp(fakeSocket({ xff: '203.0.113.1, 10.0.0.1' })),
    ).toBe('203.0.113.1');
  });

  it('flag on + missing XFF: falls back to handshake address, no crash', async () => {
    process.env.TRUST_PROXY = 'true';
    vi.resetModules();
    const fresh = await import('../src/rateLimit.js');

    expect(fresh.clientIp(fakeSocket({}))).toBe('172.18.0.2');
    // Blank header falls back too.
    expect(fresh.clientIp(fakeSocket({ xff: '   ' }))).toBe('172.18.0.2');
  });
});
