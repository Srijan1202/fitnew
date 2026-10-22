import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import { Shell } from '@/components/Shell';

import './globals.css';

export const metadata: Metadata = {
  title: 'FITOS Admin',
  description: 'Mess corrections, food and exercise library, provider health, flags, support and the audit log.',
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Shell>{children}</Shell>
      </body>
    </html>
  );
}
