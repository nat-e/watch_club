/**
 * Translates the web app into the signed-in User's Locale, or else the browser's. Its own
 * messages are in the `web` namespace, beside the `core` one it shares with the mobile app.
 */
import {useQuery} from '@tanstack/react-query';
import {currentUserQuery} from '@watchclub/core/accounts/session';
import {createI18n, type Messages, negotiateLocale} from '@watchclub/core/l10n';
import {type ReactNode, useEffect, useMemo} from 'react';
import {I18nextProvider} from 'react-i18next';
import enUs from '@/l10n/en-us';
import frFr from '@/l10n/fr-fr';

declare module 'i18next' {
  interface ResourceNamespaceMap {
    web: typeof enUs;
  }
}

const MESSAGES: Messages = {'en-US': enUs, 'fr-FR': frFr};

/** Gives the pages inside it the translations into the User's Locale. */
export function Localization({children}: {children: ReactNode}) {
  const {data: user} = useQuery(currentUserQuery);
  const locale = user?.locale ?? negotiateLocale(navigator.languages);
  const i18n = useMemo(() => createI18n(locale, 'web', MESSAGES), [locale]);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  return <I18nextProvider i18n={i18n}>{children}</I18nextProvider>;
}
