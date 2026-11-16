/**
 * Checks the translations against the code, in `pnpm check`, and sorts them in `pnpm fix`. The
 * `core` namespace holds the messages both apps share, in `packages/core`, and each app's own
 * namespace is in the app.
 */
import {defineConfig, recommendedAcceptedAttributes} from 'i18next-cli';

export default defineConfig({
  locales: ['en-US', 'fr-FR'],
  extract: {
    input: ['apps/{web,mobile}/src/**/*.{ts,tsx}', 'packages/core/src/**/*.{ts,tsx}'],
    ignore: ['**/l10n/*.ts', '**/*.gen.ts', '**/*.d.ts'],
    // TypeScript files, whose types say which values each message takes. In lowercase, as Biome
    // wants file names
    output: (language, namespace) =>
      namespace === 'core'
        ? `packages/core/src/l10n/${language.toLowerCase()}.ts`
        : `apps/${namespace}/src/l10n/${language.toLowerCase()}.ts`,
    outputFormat: 'ts',
  },
  types: {enableSelector: 'strict'},
  lint: {
    // Every element, as React Native's are components, and the props that show React Native text
    acceptedTags: 'all',
    acceptedAttributes: [
      ...recommendedAcceptedAttributes,
      'accessibilityLabel',
      'accessibilityHint',
    ],
    checkTranslationPlaceholders: 'error',
  },
});
