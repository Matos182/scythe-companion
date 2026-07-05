// SPDX-License-Identifier: MIT

import js from '@eslint/js';
import globals from 'globals';

/**
 * ESLint 9 flat config for the server.
 *
 * ESM ("type": "module" in package.json), Node 22, Vitest globals in
 * test files.
 */
export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module',
      globals: { ...globals.node },
    },
  },
  {
    files: ['test/**/*.test.js'],
    languageOptions: {
      globals: { ...globals.node, ...globals.es2021 },
    },
  },
  {
    ignores: ['node_modules/'],
  },
];
