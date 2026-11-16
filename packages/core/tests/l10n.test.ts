import {describe, expect, it} from 'vitest';
import {createI18n, negotiateLocale} from '../src/l10n';

declare module 'i18next' {
  interface ResourceNamespaceMap {
    test: {greeting: 'Hello {{name}}'; farewell: 'Goodbye'};
  }
}

describe('negotiateLocale', () => {
  it('picks the Locale of the language the user prefers', () => {
    expect(negotiateLocale(['fr-CA', 'en-US'])).toBe('fr-FR');
    expect(negotiateLocale(['en-GB'])).toBe('en-US');
    expect(negotiateLocale(['fr'])).toBe('fr-FR');
  });

  it('falls back to English for other languages', () => {
    expect(negotiateLocale(['de-DE'])).toBe('en-US');
    expect(negotiateLocale([])).toBe('en-US');
  });
});

describe('createI18n', () => {
  const i18n = createI18n('fr-FR', 'test', {
    'en-US': {greeting: 'Hello {{name}}', farewell: 'Goodbye'},
    'fr-FR': {greeting: 'Bonjour {{name}}'},
  });

  it("translates the shared messages and the app's own", () => {
    expect(i18n.t($ => $.core.home.title)).toBe('Accueil');
    expect(i18n.t($ => $.test.greeting, {name: 'Ada'})).toBe('Bonjour Ada');
  });

  it('falls back to English', () => {
    expect(i18n.t($ => $.test.farewell)).toBe('Goodbye');
  });
});
