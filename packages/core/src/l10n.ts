/**
 * Translates WatchClub with i18next. The `core` namespace holds the messages the web and mobile
 * apps share, and each app adds its own namespace: `t($ => $.core.signIn.title)`. `i18next-cli`
 * checks the translations against the code, with the settings in `i18next.config.ts`.
 */
import type {Locale} from '@watchclub/api';
import {createInstance, type i18n, type ResourceLanguage} from 'i18next';
import {useTranslation} from 'react-i18next';
import enUs from './l10n/en-us';
import frFr from './l10n/fr-fr';

declare module 'i18next' {
  interface CustomTypeOptions {
    // Every message starts with its namespace, as `$.core.signIn.title`
    enableSelector: 'strict';
  }

  interface ResourceNamespaceMap {
    core: typeof enUs;
  }
}

/** The messages of a namespace in each Locale. */
export type Messages = Record<Locale, Record<string, unknown>>;

const SHARED_MESSAGES: Messages = {'en-US': enUs, 'fr-FR': frFr};

/** The Locale every translation is checked against, and the one users get by default. */
const SOURCE_LOCALE: Locale = 'en-US';

/** The Locales WatchClub is translated into. */
// biome-ignore lint/nursery/noUnsafeTypeAssertion: the keys of a Record<Locale, …> are Locales
export const LOCALES = Object.keys(SHARED_MESSAGES) as Locale[];

/**
 * Returns the Locale closest to the languages the user prefers, such as `navigator.languages`:
 * the first one that has a Locale for its language, if not for its region.
 */
export function negotiateLocale(languages: readonly string[]): Locale {
  const language = (tag: string) => tag.split(/[-_]/)[0]?.toLowerCase();
  for (const tag of languages) {
    const locale =
      LOCALES.find(candidate => candidate.toLowerCase() === tag.toLowerCase()) ??
      LOCALES.find(candidate => language(candidate) === language(tag));
    if (locale) {
      return locale;
    }
  }
  return SOURCE_LOCALE;
}

/**
 * Returns i18next translating an app into the Locale, from the shared messages and the app's own
 * namespace.
 */
export function createI18n(locale: Locale, namespace: string, messages: Messages): i18n {
  const instance = createInstance();
  instance.init({
    lng: locale,
    fallbackLng: SOURCE_LOCALE,
    resources: Object.fromEntries(
      LOCALES.map(each => {
        const namespaces: ResourceLanguage = {core: SHARED_MESSAGES[each]};
        namespaces[namespace] = messages[each];
        return [each, namespaces];
      }),
    ),
    ns: ['core', namespace],
    enableSelector: 'strict',
    // React escapes the text it shows
    interpolation: {escapeValue: false},
    // The messages are bundled, so it translates as soon as it's created
    initAsync: false,
  });
  return instance;
}

/** The units of a relative time, from the largest, with their length in seconds. */
const RELATIVE_TIME_UNITS: ReadonlyArray<[Intl.RelativeTimeFormatUnit, number]> = [
  ['year', 365 * 24 * 60 * 60],
  ['month', 30 * 24 * 60 * 60],
  ['day', 24 * 60 * 60],
  ['hour', 60 * 60],
  ['minute', 60],
  ['second', 1],
];

/**
 * Returns how long ago a time was, or how soon it comes, in the language, in the largest unit it
 * spans: "3 months ago", "in 7 days".
 */
export function formatRelativeTime(time: string, language: string, now = Date.now()): string {
  const seconds = (Date.parse(time) - now) / 1000;
  const [unit, length] = RELATIVE_TIME_UNITS.find(([, each]) => Math.abs(seconds) >= each) ?? [
    'second',
    1,
  ];
  const format = new Intl.RelativeTimeFormat(language, {numeric: 'auto'});
  return format.format(Math.round(seconds / length), unit);
}

/** Returns the name of each Locale in the app's language, for Users to pick theirs. */
export function useLocaleNames(): Record<Locale, string> {
  const {t} = useTranslation('core');
  return {'en-US': t($ => $.core.settings.englishUs), 'fr-FR': t($ => $.core.settings.french)};
}
