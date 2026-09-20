import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    include: ['src/**/*.test.ts'],
    // Every *.integration.test.ts shares ONE Postgres, and the migration suite
    // rolls the whole schema back in its beforeAll. Files therefore run one at
    // a time; with three suites the parallel default happened to work, with
    // five it raced. Unit files are milliseconds, so the cost is nil.
    fileParallelism: false,
  },
});
