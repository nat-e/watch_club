import tailwindcss from '@tailwindcss/vite';
import {tanstackRouter} from '@tanstack/router-plugin/vite';
import react from '@vitejs/plugin-react';
import {defineConfig} from 'vite';

const WEB_PORT = Number(process.env.WEB_PORT ?? 5173);
if (Number.isNaN(WEB_PORT)) {
  throw new Error(`WEB_PORT must be a number, not ${process.env.WEB_PORT}`);
}

export default defineConfig({
  // The router plugin must come before the React plugin
  plugins: [tanstackRouter({target: 'react', autoCodeSplitting: true}), react(), tailwindcss()],
  resolve: {tsconfigPaths: true},
  // Sentry finds them next to the scripts, and shows the source of its stack traces
  build: {sourcemap: true},
  server: {
    port: WEB_PORT,
    strictPort: true,
    // Forwards API calls to the server that `pnpm dev` runs on PORT
    proxy: {'/api': `http://127.0.0.1:${process.env.PORT}`},
  },
});
