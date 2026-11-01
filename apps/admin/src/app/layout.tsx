import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

import { Shell } from '@/components/Shell';
import { MODE_SCRIPT } from '@/lib/mode';

import './globals.css';

export const metadata: Metadata = {
  title: 'FITOS Admin',
  description: 'Mess corrections, food and exercise library, provider health, flags, support and the audit log.',
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: dark)', color: '#000000' },
    { media: '(prefers-color-scheme: light)', color: '#f6f8fc' },
  ],
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" data-mode="dark" suppressHydrationWarning>
      <head>
        {/* Beta 5.3: the dark or light mode before the first paint (lib/mode.ts). */}
        <script dangerouslySetInnerHTML={{ __html: MODE_SCRIPT }} />
      </head>
      <body>
        <Shell>{children}</Shell>
      </body>
    </html>
  );
}
