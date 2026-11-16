/**
 * Translates the app into the signed-in User's Locale, or else the device's. Its own messages are
 * in the `mobile` namespace, beside the `core` one it shares with the web app.
 */
// Hermes has no Intl.PluralRules, which i18next needs to choose plural forms. Each Locale needs its
// language's data
import '@formatjs/intl-pluralrules/polyfill.js';
import '@formatjs/intl-pluralrules/locale-data/en.js';
import '@formatjs/intl-pluralrules/locale-data/fr.js';
import {createI18n, type Messages, negotiateLocale} from '@watchclub/core/l10n';
import {getLocales} from 'expo-localization';
import {type ReactNode, useMemo} from 'react';
import {I18nextProvider} from 'react-i18next';
import enUs from '@/l10n/en-us';
import frFr from '@/l10n/fr-fr';
import {useSession} from '@/session';

declare module 'i18next' {
  interface ResourceNamespaceMap {
    mobile: typeof enUs;
  }
}

const MESSAGES: Messages = {'en-US': enUs, 'fr-FR': frFr};

/** The translations into the User's Locale, for the screens inside it. */
export function Localization({children}: {children: ReactNode}) {
  const {user} = useSession();
  const locale = user?.locale ?? negotiateLocale(getLocales().map(locale => locale.languageTag));
  const i18n = useMemo(() => createI18n(locale, 'mobile', MESSAGES), [locale]);
  return <I18nextProvider i18n={i18n}>{children}</I18nextProvider>;
}
