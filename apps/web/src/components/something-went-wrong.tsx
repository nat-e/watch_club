import {useTranslation} from 'react-i18next';

/** The message in place of a page that failed to load, as when the server is down. */
export function SomethingWentWrong() {
  const {t} = useTranslation('core');
  return (
    <p role="alert" className="p-6 text-destructive">
      {t($ => $.core.errors.somethingWentWrong)}
    </p>
  );
}
