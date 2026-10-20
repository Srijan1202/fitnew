// ESLint for the admin scaffold (audit 2026-10-20): `next lint` asked an
// interactive question and stopped the root `pnpm lint`; this is the
// non-interactive equivalent of its "Strict" choice.
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { FlatCompat } from '@eslint/eslintrc';

const compat = new FlatCompat({ baseDirectory: dirname(fileURLToPath(import.meta.url)) });

export default [...compat.extends('next/core-web-vitals', 'next/typescript')];
