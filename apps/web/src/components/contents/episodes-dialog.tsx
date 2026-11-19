import {Radio} from '@base-ui/react/radio';
import {RadioGroup} from '@base-ui/react/radio-group';
import type {Content, Media} from '@watchclub/api';
import {useEpisodeFacts, useEpisodes} from '@watchclub/core/contents/media';
import {cn} from 'cn';
import {CircleIcon, ImageIcon, ListVideoIcon, TriangleAlertIcon} from 'lucide-react';
import {useTranslation} from 'react-i18next';
import {RoundAction} from '@/components/contents/round-action';
import {SizedImage} from '@/components/contents/sized-image';
import {Button} from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {Empty, EmptyDescription, EmptyHeader, EmptyMedia} from '@/components/ui/empty';
import {Skeleton} from '@/components/ui/skeleton';
import {toggleVariants} from '@/components/ui/toggle';

/**
 * The Episodes action of a TV Show, which opens its TV Show Episodes by season, over the whole
 * screen on phones. They load when it opens.
 */
export function EpisodesDialog({content}: {content: Content}) {
  const {t} = useTranslation('core');
  return (
    <Dialog>
      <DialogTrigger
        render={<RoundAction label={t($ => $.core.contents.episodes)} icon={<ListVideoIcon />} />}
      />
      <DialogContent className="flex max-h-[calc(100dvh-4rem)] flex-col sm:max-w-3xl max-sm:h-dvh max-sm:max-h-dvh max-sm:max-w-full max-sm:rounded-none">
        <DialogHeader>
          <DialogTitle className="text-lg">{content.title}</DialogTitle>
        </DialogHeader>
        {/* A container for the rows' breakpoints */}
        <div className="@container -mx-6 flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-6">
          <Episodes contentId={content.id} />
        </div>
      </DialogContent>
    </Dialog>
  );
}

/** The TV Show's Episodes of the season the User picks, the first one at first. */
function Episodes({contentId}: {contentId: string}) {
  const {t} = useTranslation('core');
  const {status, seasons, season, pickSeason, retry} = useEpisodes(contentId);

  if (status === 'loading') {
    return <EpisodesSkeleton />;
  }
  if (status === 'failed') {
    return (
      <Empty className="p-6">
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <TriangleAlertIcon />
          </EmptyMedia>
          <EmptyDescription>{t($ => $.core.errors.somethingWentWrong)}</EmptyDescription>
        </EmptyHeader>
        <Button variant="secondary" size="sm" onClick={retry}>
          {t($ => $.core.controls.tryAgain)}
        </Button>
      </Empty>
    );
  }
  if (!season) {
    return null;
  }
  const seasonName = (number: number) => t($ => $.core.episodes.season, {number});
  return (
    <>
      <div className="flex flex-col gap-2">
        {seasons.length > 1 ? (
          <RadioGroup
            aria-label={t($ => $.core.contents.episodes)}
            value={season.number}
            onValueChange={number => {
              pickSeason(number);
            }}
            className="flex gap-2 overflow-x-auto pb-1"
          >
            {seasons.map(each => (
              <Radio.Root
                key={each.number}
                value={each.number}
                className={cn(toggleVariants({variant: 'chip', size: 'sm'}), 'shrink-0')}
              >
                {seasonName(each.number)}
              </Radio.Root>
            ))}
          </RadioGroup>
        ) : (
          <span className="text-sm font-semibold">{seasonName(season.number)}</span>
        )}
        {/* Waits for Watch Progress */}
        <Button
          variant="ghost"
          size="sm"
          disabled
          title={t($ => $.core.episodes.markSeasonAsWatched, {number: season.number})}
          className="self-end"
        >
          {t($ => $.core.contents.markAsWatched)}
          <CircleIcon data-icon="inline-end" />
        </Button>
      </div>
      <ol className="flex flex-col">
        {season.media.map(episode => (
          <EpisodeRow key={episode.id} episode={episode} />
        ))}
      </ol>
    </>
  );
}

/**
 * A TV Show Episode: its still, its number, title, runtime and when it comes out, its overview, and
 * the watched check once it's out. The still is grey before it comes out.
 */
function EpisodeRow({episode}: {episode: Media}) {
  const {t} = useTranslation('core');
  const facts = useEpisodeFacts(episode);
  return (
    <li className="flex items-start gap-4 py-2">
      <div
        className={cn(
          'relative flex aspect-video w-28 shrink-0 items-center justify-center overflow-hidden rounded-md bg-accent text-subtle-foreground @md:w-40',
          !facts.isOut && 'opacity-60 grayscale',
        )}
      >
        {episode.image ? (
          <SizedImage
            image={episode.image}
            width={160}
            className="absolute inset-0 size-full object-cover"
          />
        ) : (
          <ImageIcon className="size-1/4" />
        )}
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <span>
          <span className="font-semibold">{facts.code}</span>
          {/* i18next-instrument-ignore: a separator, the same in every language */}
          {episode.title && <span> · {episode.title}</span>}
        </span>
        {(facts.runtime || facts.releaseNote) && (
          <span className="flex flex-wrap gap-x-2 text-xs text-muted-foreground">
            {facts.runtime && <span>{facts.runtime}</span>}
            {facts.releaseNote && <span className="font-semibold">{facts.releaseNote}</span>}
          </span>
        )}
        {episode.overview && (
          <span className="line-clamp-2 max-w-readable text-sm text-muted-foreground">
            {episode.overview}
          </span>
        )}
      </div>
      {/* Waits for Watch Progress */}
      {facts.isOut && (
        <Button
          variant="ghost"
          size="icon"
          disabled
          aria-pressed={false}
          aria-label={t($ => $.core.episodes.watchedEpisode, {number: facts.code})}
        >
          <CircleIcon />
        </Button>
      )}
    </li>
  );
}

/** The rows that show while the Episodes load. */
function EpisodesSkeleton() {
  return (
    <div className="flex flex-col" aria-hidden="true">
      {[0, 1, 2, 3].map(row => (
        <div key={row} className="flex items-start gap-4 py-2">
          <Skeleton className="aspect-video w-28 rounded-md @md:w-40" />
          <span className="flex flex-1 flex-col gap-2">
            <Skeleton className="h-3 w-1/2 rounded-full" />
            <Skeleton className="h-3 w-1/4 rounded-full" />
          </span>
        </div>
      ))}
    </div>
  );
}
