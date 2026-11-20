import {describe, expect, it} from 'vitest';
import {createI18n, formatRelativeTime, negotiateLocale} from '../src/l10n';

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

describe('formatRelativeTime', () => {
  const now = Date.parse('2026-11-20T12:00:00Z');

  it('counts in the largest unit the time spans', () => {
    expect(formatRelativeTime('2026-11-27T11:59:00Z', 'en-US', now)).toBe('in 7 days');
    expect(formatRelativeTime('2026-08-20T12:00:00Z', 'en-US', now)).toBe('3 months ago');
    expect(formatRelativeTime('2026-11-20T09:00:00Z', 'fr-FR', now)).toBe('il y a 3 heures');
  });

  it('names the nearest days', () => {
    expect(formatRelativeTime('2026-11-19T12:00:00Z', 'en-US', now)).toBe('yesterday');
    expect(formatRelativeTime('2026-11-20T12:00:00Z', 'en-US', now)).toBe('now');
  });
});
