import {defineConfig} from 'vitest/config';

export default defineConfig({
  // The tests import the app's code through `@/`, as the app does
  resolve: {tsconfigPaths: true},
});
