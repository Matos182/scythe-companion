// SPDX-License-Identifier: MIT

/**
 * Structured logger (pino).
 *
 * Replaces console.log across the server — audit A7 flagged the
 * `console.log(room)` spam.  Pino emits newline-delimited JSON so logs
 * are greppable and pipeable to any log aggregator.
 *
 * In test mode pino is silent to keep vitest output clean — tests that
 * need to assert on log output can import the logger and spy on it.
 */

import pino from 'pino';
import { logLevel } from './config.js';

/** @type {boolean} true when running inside vitest. */
const isTest = process.env.NODE_ENV === 'test' || process.env.VITEST === 'true';

/**
 * Shared logger instance.
 *
 * - Test: pretty-print to a null destination (no stdout noise).
 * - Dev: pretty-print to stdout (colourised, readable).
 * - Prod: raw JSON to stdout.
 */
const logger = pino({
  level: isTest ? 'silent' : logLevel,
  base: { service: 'scythe-server' },
  ...(isTest
    ? {}
    : process.stdout.isTTY
      ? { transport: { target: 'pino-pretty', options: { colorize: true } } }
      : {}),
});

export default logger;
