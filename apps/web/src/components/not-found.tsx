import {Link} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {buttonVariants} from '@/components/ui/button';

/** The page in place of one that doesn't exist, as when a link is wrong, with a way back home. */
export function NotFound() {
  const {t} = useTranslation('core');
  return (
    <main className="flex min-h-svh items-center justify-center p-6">
      <div className="flex w-full max-w-xl flex-col items-center gap-4 text-center text-balance">
        {/* i18next-instrument-ignore: the status code is the same in every language */}
        <p className="text-sm font-semibold tracking-wide text-muted-foreground">404</p>
        <div className="flex flex-col gap-2">
          <h1 className="font-heading text-2xl font-semibold sm:text-3xl">
            {t($ => $.core.notFound.title)}
          </h1>
          <p className="text-sm/relaxed text-muted-foreground sm:text-base/relaxed">
            {t($ => $.core.notFound.description)}
          </p>
        </div>
        <Link to="/" className={buttonVariants({size: 'lg'})}>
          {t($ => $.core.notFound.goHome)}
        </Link>
      </div>
    </main>
  );
}
