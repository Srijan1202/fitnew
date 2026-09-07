// Extends the shared flat config in packages/config (spec §29).
import shared from '@fitos/config/eslint';

export default [
  ...shared,
  {
    // dist/ is build output; .test.ts files may use loose typing for stubs.
    ignores: ['dist/**'],
  },
];
