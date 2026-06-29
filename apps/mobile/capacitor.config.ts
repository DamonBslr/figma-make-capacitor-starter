import type { CapacitorConfig } from '@capacitor/cli';

// Valid defaults so the blank starter runs a dummy app out of the box
// (pnpm dummy:ios / pnpm dummy:android). /init-from-figma rewrites appId + appName
// with the real values before running cap add — don't hand-edit for a real app.
const config: CapacitorConfig = {
  appId: 'com.example.dummy',
  appName: 'Dummy App',
  webDir: 'dist',
  plugins: {
    CapacitorUpdater: {
      autoUpdate: false,
    },
  },
};

export default config;
