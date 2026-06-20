import { useEffect } from 'react';
import { CapacitorUpdater } from '@capgo/capacitor-updater';

// init-from-figma mounts the Figma-derived router + providers in place of the null below.
// The notifyAppReady call must stay in this top-level component.

export default function App() {
  useEffect(() => {
    CapacitorUpdater.notifyAppReady();
  }, []);

  // TODO(init-from-figma): replace null with the Figma app's router + providers
  return null;
}
