import {type QueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {Link, linkOptions, notFound, useCanGoBack, useRouter} from '@tanstack/react-router';
import {type Content, type ContentType, type ExternalContentId, hasCode} from '@watchclub/api';
import {
  contentQuery,
  creditedPeople,
  initials,
  LONG_OVERVIEW_LENGTH,
  useContentFacts,
  useCreditedPeopleHeading,
  useCreditRole,
  useGenreNames,
  useMarkAsWatchedLabel,
} from '@watchclub/core/contents/content';
import {cn} from 'cn';
import {
  ArrowLeftIcon,
  CircleIcon,
  CirclePlayIcon,
  DownloadIcon,
  ExternalLinkIcon,
  LoaderCircleIcon,
  StarIcon,
} from 'lucide-react';
import {Fragment, type ReactNode, type RefObject, useEffect, useId, useRef, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {EpisodesDialog} from '@/components/contents/episodes-dialog';
import {Poster} from '@/components/contents/poster';
import {RoundAction} from '@/components/contents/round-action';
import {SizedImage} from '@/components/contents/sized-image';
import {Page} from '@/components/layouts/page';
import {ScrollRow} from '@/components/scroll-row';
import {Badge} from '@/components/ui/badge';
import {Button, buttonVariants} from '@/components/ui/button';
import {SidebarTrigger} from '@/components/ui/sidebar';

/** Returns the options of a link to the Content's page. */
export function contentLink({content_type, external_id}: ExternalContentId) {
  const params = {id: external_id};
  switch (content_type) {
    case 'movie':
      return linkOptions({to: '/movies/$id', params});
    case 'tv_show':
      return linkOptions({to: '/shows/$id', params});
    case 'sports_event':
      return linkOptions({to: '/sports/$id', params});
    case 'book':
      return linkOptions({to: '/books/$id', params});
  }
}

/**
 * Loads the Content of a page's URL, from its type and the External ID in the URL, or shows that
 * the page doesn't exist when there's no such Content.
 */
export async function loadContent(
  queryClient: QueryClient,
  contentType: ContentType,
  idParam: string,
): Promise<ExternalContentId> {
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const externalContentId: ExternalContentId = {content_type: contentType, external_id: idParam};
  try {
    await queryClient.ensureQueryData(contentQuery(externalContentId));
  } catch (error) {
    if (hasCode(error, 'not_found')) {
      throw notFound();
    }
    throw error;
  }
  return externalContentId;
}

/** The page that shows while a Content loads, which takes a moment the first time it opens. */
export function ContentPagePending() {
  const {t} = useTranslation('core');
  return (
    <Page title={t($ => $.core.contents.loading)}>
      <p role="status" className="flex items-center justify-center gap-2 p-6 text-muted-foreground">
        <LoaderCircleIcon className="size-5 animate-spin" />
        {t($ => $.core.contents.loading)}
      </p>
    </Page>
  );
}

/** A Content's page: its header on its backdrop, under the bar, then its cast or authors. */
export function ContentPage({externalContentId}: {externalContentId: ExternalContentId}) {
  const {data: content} = useSuspenseQuery(contentQuery(externalContentId));
  const titleRef = useRef<HTMLHeadingElement>(null);

  return (
    // A container, so that the header lays out by the page's width beside the sidebar
    <div className="@container flex flex-1 flex-col">
      <ContentBar title={content.title} titleRef={titleRef} />
      <ContentHeader content={content} titleRef={titleRef} />
      {/* One column, so a long line of text can't widen the page past the screen */}
      <div className="grid grid-cols-1 content-start gap-12 px-page pt-6 pb-page-y">
        <CreditedPeople content={content} />
      </div>
    </div>
  );
}

/**
 * The bar over the header: Back, and on phones the button that slides the sidebar in. The backdrop
 * shows through it until the page scrolls, and it shows the Content's title once the header's has
 * scrolled under it.
 */
function ContentBar({
  title,
  titleRef,
}: {
  title: string;
  titleRef: RefObject<HTMLHeadingElement | null>;
}) {
  const barRef = useRef<HTMLDivElement>(null);
  const [isScrolled, setIsScrolled] = useState(false);
  const [isPastTitle, setIsPastTitle] = useState(false);
  useEffect(() => {
    const update = () => {
      const titleBottom = titleRef.current?.getBoundingClientRect().bottom;
      const barBottom = barRef.current?.getBoundingClientRect().bottom;
      setIsScrolled(window.scrollY > 8);
      setIsPastTitle(
        titleBottom !== undefined && barBottom !== undefined && titleBottom < barBottom,
      );
    };
    update();
    window.addEventListener('scroll', update, {passive: true});
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, [titleRef]);

  return (
    <div
      ref={barRef}
      className={cn(
        'sticky top-0 z-10 flex h-16 shrink-0 items-center gap-2 border-b px-page transition-colors duration-200',
        isScrolled ? 'bg-background' : 'border-transparent',
      )}
    >
      <SidebarTrigger className="md:hidden" />
      <BackLink />
      {/* Screen readers read the header's title */}
      <p
        aria-hidden="true"
        className={cn(
          'truncate text-base font-semibold transition-opacity duration-200',
          !isPastTitle && 'opacity-0',
        )}
      >
        {title}
      </p>
    </div>
  );
}

/**
 * The link back to the previous page, or to Browse when the page opened first, such as from a
 * link. A new tab opens Browse.
 */
function BackLink() {
  const {t} = useTranslation('web');
  const router = useRouter();
  const canGoBack = useCanGoBack();
  const label = t($ => $.web.contents.back);
  return (
    <Link
      to="/browse"
      aria-label={label}
      title={label}
      className={buttonVariants({variant: 'ghost', size: 'icon-sm'})}
      onClick={event => {
        const opensNewTab = event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0;
        if (canGoBack && !opensNewTab) {
          event.preventDefault();
          router.history.back();
        }
      }}
    >
      <ArrowLeftIcon />
    </Link>
  );
}

/**
 * The poster, the title, its facts, its genres, the overview and the actions, on the dimmed
 * backdrop, which runs under the bar. Centered on phones, beside the poster on wide screens.
 */
function ContentHeader({
  content,
  titleRef,
}: {
  content: Content;
  titleRef: RefObject<HTMLHeadingElement | null>;
}) {
  const genreNames = useGenreNames();
  return (
    <header className="relative isolate -mt-16 pt-16">
      {content.backdrop && (
        <div aria-hidden="true" className="absolute inset-0 -z-10 overflow-hidden">
          <SizedImage image={content.backdrop} width="full" className="size-full object-cover" />
          <span className="absolute inset-0 bg-background/80" />
        </div>
      )}
      <div className="flex flex-col items-center gap-4 px-page py-6 text-center @3xl:flex-row @3xl:items-start @3xl:gap-6 @3xl:py-12 @3xl:text-left">
        <Poster image={content.poster} width={176} className="w-28 shadow-card @3xl:w-44" />
        <div className="flex w-full min-w-0 flex-1 flex-col gap-4">
          <div className="flex flex-col gap-1">
            <h1
              ref={titleRef}
              className="font-heading text-3xl font-semibold text-balance @3xl:text-4xl"
            >
              {content.title}
            </h1>
            <Facts content={content} />
          </div>
          {content.genres.length > 0 && (
            <ul className="flex flex-wrap justify-center gap-1 @3xl:justify-start">
              {content.genres.map(genre => (
                <li key={genre}>
                  <Badge variant="secondary" className="border-border">
                    {genreNames[genre]}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
          {content.overview && (
            <Overview
              text={content.overview}
              // sportarr.net writes in English only
              lang={content.content_type === 'sports_event' ? 'en' : undefined}
            />
          )}
          <Actions content={content} />
        </div>
      </div>
    </header>
  );
}

/**
 * "🇫🇷 2001 · Movie · 2 hr 2 min · ★ 7.9": the original language's flag next to the year, then the
 * rating, which opens the Content on TMDB. A Sports Event shows its day and league: "April 13,
 * 2024 · Sports event · UFC".
 */
function Facts({content}: {content: Content}) {
  const {t} = useTranslation('core');
  const facts = useContentFacts(content);
  const languageLabel = facts.originalLanguage
    ? t($ => $.core.contents.originalLanguage, {language: facts.originalLanguage.name})
    : '';

  const items: ReactNode[] = [];
  if (facts.originalLanguage || facts.date) {
    items.push(
      <span className="inline-flex items-center gap-1">
        {facts.originalLanguage && (
          <span
            role="img"
            aria-label={languageLabel}
            title={languageLabel}
            className="text-base leading-none"
          >
            {facts.originalLanguage.flag}
          </span>
        )}
        {facts.date}
      </span>,
    );
  }
  items.push(<span>{facts.contentType}</span>);
  if (facts.detail) {
    items.push(<span>{facts.detail}</span>);
  }
  if (facts.rating) {
    const rating = (
      <span className="inline-flex items-center gap-1 font-semibold">
        <StarIcon className="size-4 fill-current text-warning" />
        {facts.rating}
      </span>
    );
    items.push(
      facts.ratingUrl ? (
        <a
          href={facts.ratingUrl}
          target="_blank"
          rel="noopener noreferrer"
          title={t($ => $.core.contents.seeOnTmdb)}
          className="inline-flex items-center gap-1 text-foreground hover:underline"
        >
          {rating}
          <ExternalLinkIcon className="size-4 text-subtle-foreground" />
        </a>
      ) : (
        rating
      ),
    );
  }

  return (
    <p className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-sm text-muted-foreground @3xl:justify-start">
      {items.map((item, index) => (
        // The facts keep their order, and have no ID
        // biome-ignore lint/suspicious/noArrayIndexKey: see above
        <Fragment key={index}>
          {/* i18next-instrument-ignore: a separator, the same in every language */}
          {index > 0 && <span aria-hidden="true">·</span>}
          {item}
        </Fragment>
      ))}
    </p>
  );
}

/**
 * The overview, in paragraphs, such as a Book's: a long one shortened to a few lines, with More to
 * read it whole.
 */
function Overview({
  text,
  lang,
}: {
  text: string;
  /** Its language, when it may not be the User's */
  lang?: string;
}) {
  const {t} = useTranslation('core');
  const [isExpanded, setIsExpanded] = useState(false);
  const id = useId();
  const isLong = text.length > LONG_OVERVIEW_LENGTH;
  return (
    <div className="flex max-w-readable flex-col items-center gap-1 @3xl:items-start">
      <p
        id={id}
        lang={lang}
        className={cn(
          'whitespace-pre-line text-muted-foreground',
          isLong && !isExpanded && 'line-clamp-3 @3xl:line-clamp-5',
        )}
      >
        {text}
      </p>
      {isLong && (
        <Button
          variant="ghost"
          size="sm"
          aria-controls={id}
          aria-expanded={isExpanded}
          onClick={() => {
            setIsExpanded(!isExpanded);
          }}
        >
          {isExpanded ? t($ => $.core.contents.less) : t($ => $.core.contents.more)}
        </Button>
      )}
    </div>
  );
}

/**
 * Request first, then the quieter Episodes of a TV Show, Watch trailer, and Mark as watched, or
 * Mark as read for a Book. Request and Mark as watched wait for their features.
 */
function Actions({content}: {content: Content}) {
  const {t} = useTranslation('core');
  const markAsWatchedLabel = useMarkAsWatchedLabel(content.content_type);
  return (
    <div className="flex flex-col gap-4 @3xl:flex-row @3xl:flex-wrap @3xl:items-start @3xl:gap-x-6">
      {/* On a solid background, so the backdrop doesn't show through it while it's disabled. Its
          fill runs under its transparent border, which would show the background as a dark ring */}
      <span className="flex w-full rounded-md bg-background @max-3xl:mx-auto @max-3xl:max-w-sm @3xl:w-auto @3xl:min-w-64">
        <Button size="lg" disabled className="h-12 w-full gap-2 bg-clip-border px-6 text-base">
          <DownloadIcon className="size-5" />
          {t($ => $.core.contents.request)}
        </Button>
      </span>
      <div className="flex justify-center gap-4 @3xl:justify-start">
        {content.content_type === 'tv_show' && content.media_group_count > 0 && (
          <EpisodesDialog content={content} />
        )}
        {content.trailer_url && (
          <RoundAction
            label={t($ => $.core.contents.watchTrailer)}
            icon={<CirclePlayIcon />}
            render={<a href={content.trailer_url} target="_blank" rel="noopener noreferrer" />}
          />
        )}
        <RoundAction label={markAsWatchedLabel} icon={<CircleIcon />} disabled />
      </div>
    </div>
  );
}

/**
 * The people credited for the Content, as round photos in a row that scrolls sideways: a Movie's or
 * a TV Show's directors then actors, or a Book's authors, illustrators and narrators.
 */
function CreditedPeople({content}: {content: Content}) {
  const heading = useCreditedPeopleHeading(content.content_type);
  const creditRole = useCreditRole();
  const headingId = useId();
  const people = creditedPeople(content.credits);
  if (people.length === 0) {
    return null;
  }

  return (
    <section aria-labelledby={headingId} className="flex min-w-0 flex-col gap-4">
      <h2 id={headingId} className="font-heading text-xl font-semibold">
        {heading}
      </h2>
      <ScrollRow list>
        {people.map((credit, index) => {
          const role = creditRole(credit);
          return (
            // Credits keep their order, and have no ID
            // biome-ignore lint/suspicious/noArrayIndexKey: see above
            <li key={index} className="flex w-24 flex-col items-center gap-2">
              <span className="relative flex size-20 shrink-0 items-center justify-center overflow-hidden rounded-full bg-secondary text-sm font-semibold text-muted-foreground">
                {credit.photo ? (
                  <SizedImage
                    image={credit.photo}
                    width={80}
                    className="absolute inset-0 size-full object-cover"
                  />
                ) : (
                  <span aria-hidden="true">{initials(credit.name)}</span>
                )}
              </span>
              <span className="flex w-full flex-col text-center">
                <span className="line-clamp-2 text-sm font-semibold">{credit.name}</span>
                {role && <span className="truncate text-xs text-muted-foreground">{role}</span>}
              </span>
            </li>
          );
        })}
      </ScrollRow>
    </section>
  );
}
