import { CapacitorConfig } from '@capacitor/cli';

// init-from-figma fills these three tokens before running cap add.
// Do not edit manually — run /init-from-figma <url> <AppName> <com.bundle.id>
const config: CapacitorConfig = {
  appId:   '{{APP_ID}}',
  appName: '{{APP_NAME}}',
  webDir:  '{{WEB_DIR}}',
  plugins: {
    CapacitorUpdater: {
      autoUpdate: false,
    },
  },
};

export default config;
