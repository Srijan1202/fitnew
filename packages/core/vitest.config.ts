import { defineConfig } from 'vitest/config';

/**
 * Phase 18 (§26.1): every decision function in packages/core is covered on
 * every branch. `pnpm --filter @fitos/core test:coverage` fails below 100 %
 * branches. A branch that no input can reach carries a
 * `v8 ignore next -- @preserve` hint with the invariant that makes it so.
 */
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      include: ['src/**'],
      // Types only: v8 reports a phantom branch on an empty module.
      exclude: ['src/mess/types.ts'],
      reporter: ['text-summary', 'json'],
      thresholds: { branches: 100, functions: 95, lines: 95, statements: 95 },
    },
  },
});
