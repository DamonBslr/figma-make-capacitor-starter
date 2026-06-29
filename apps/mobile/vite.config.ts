import { fileURLToPath, URL } from 'node:url';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// Resolve the monorepo workspace aliases (mirror of tsconfig.base.json `paths`)
// so apps/mobile imports @app/ui and @app/core straight from source, with HMR.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@app/ui': fileURLToPath(new URL('../../packages/ui/src', import.meta.url)),
      '@app/core': fileURLToPath(new URL('../../packages/core/src', import.meta.url)),
    },
  },
  build: {
    // Must match `webDir` in capacitor.config.ts.
    outDir: 'dist',
  },
});
