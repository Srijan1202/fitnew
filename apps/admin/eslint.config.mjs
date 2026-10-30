// ESLint for the admin panel (audit 2026-10-20): the non-interactive
// equivalent of `next lint`'s "Strict" choice. Beta 4.8: Next 16 ships
// flat configs, so no compatibility layer.
import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';

export default [
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      // New in Next 16's React rules. The panel loads each page's data in an
      // effect (loading, data, error) and closes the phone drawer when the
      // page changes; both are deliberate and cheap here.
      'react-hooks/set-state-in-effect': 'off',
    },
  },
];
