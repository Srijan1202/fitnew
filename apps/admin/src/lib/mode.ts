'use client';

/**
 * Beta 5.3 (owner): the panel follows the computer's dark or light setting
 * (Cobalt or Cobalt Light) unless an admin pins one. The choice is a
 * per-browser convenience, kept in localStorage.
 */
export type Mode = 'system' | 'light' | 'dark';

const KEY = 'fitos.admin.mode';

export function savedMode(): Mode {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'light' || v === 'dark' ? v : 'system';
  } catch {
    return 'system';
  }
}

/** Sets `data-mode` on <html> for the chosen or the computer's mode. */
export function applyMode(mode: Mode): void {
  const dark = mode === 'dark' || (mode === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.dataset['mode'] = dark ? 'dark' : 'light';
}

export function saveMode(mode: Mode): void {
  try {
    if (mode === 'system') localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, mode);
  } catch {
    // Still applies for this visit.
  }
  applyMode(mode);
}

/**
 * Runs in <head> before the first paint, so a light-mode computer never
 * flashes dark. Kept tiny and self-contained (it is inlined as a string).
 */
export const MODE_SCRIPT = `(function(){try{var m=localStorage.getItem('${KEY}');var d=m==='dark'||(m!=='light'&&matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.dataset.mode=d?'dark':'light';}catch(e){}})();`;
