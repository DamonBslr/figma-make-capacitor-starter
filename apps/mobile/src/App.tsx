import { Capacitor } from '@capacitor/core';
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { useEffect } from 'react';

// init-from-figma mounts the Figma-derived router + providers in place of the
// placeholder screen below. The notifyAppReady call must stay in this top-level component.

export default function App() {
  useEffect(() => {
    // Only meaningful inside the native OTA shell; skip on web so `pnpm dev` stays quiet.
    if (Capacitor.isNativePlatform()) {
      CapacitorUpdater.notifyAppReady();
    }
  }, []);

  // TODO(init-from-figma): replace this placeholder with the Figma app's router + providers
  return (
    <main
      style={{
        minHeight: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '0.75rem',
        padding: '2rem',
        textAlign: 'center',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}
    >
      <h1 style={{ margin: 0, fontSize: '1.5rem' }}>It works 🎉</h1>
      <p style={{ margin: 0, maxWidth: '24rem', opacity: 0.7 }}>
        Blank Capacitor starter. Run <code>/init-from-figma</code> to replace this placeholder with
        your Figma design.
      </p>
    </main>
  );
}
