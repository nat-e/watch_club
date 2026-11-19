import {Radio} from '@base-ui/react/radio';
import {RadioGroup} from '@base-ui/react/radio-group';
import type {Content, Media} from '@watchclub/api';
import {useEpisodeFacts, useEpisodes} from '@watchclub/core/contents/media';
import {cn} from 'cn';
import {CircleIcon, ImageIcon, ListVideoIcon, TriangleAlertIcon} from 'lucide-react';
import {useTranslation} from 'react-i18next';
import {RoundAction} from '@/components/contents/round-action';
import {SizedImage} from '@/components/contents/sized-image';
import {ScrollRow} from '@/components/scroll-row';
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
      {/* Padded with the page's margins, which the seasons' row runs into. Over the whole screen on
          phones, where `!` beats the dialog's own width */}
      <DialogContent className="flex max-h-[calc(100dvh-4rem)] flex-col gap-0 p-0 md:max-w-2xl max-md:h-dvh max-md:max-h-dvh max-md:max-w-none! max-md:rounded-none max-md:border-0">
        <DialogHeader className="py-6 pr-14 pl-page">
          <DialogTitle className="text-lg">{content.title}</DialogTitle>
        </DialogHeader>
        {/* Only the Episodes scroll, under the title. A container for the rows' breakpoints */}
        <div className="@container flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-page pb-6">
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
          >
            <ScrollRow variant="chips">
              {seasons.map(each => (
                <Radio.Root
                  key={each.number}
                  value={each.number}
                  // `cn` lets the pill's classes replace the toggle's defaults
                  className={cn(toggleVariants({variant: 'pill', size: 'sm'}))}
                >
                  {seasonName(each.number)}
                </Radio.Root>
              ))}
            </ScrollRow>
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
 * A TV Show Episode: its still, its number, title, runtime and when it comes out, and the watched
 * check once it's out. The still is grey before it comes out. Its overview would crowd the list.
 */
function EpisodeRow({episode}: {episode: Media}) {
  const {t} = useTranslation('core');
  const facts = useEpisodeFacts(episode);
  return (
    <li className="flex items-start gap-4 py-2">
      <div
        className={cn(
          'relative flex aspect-video w-28 shrink-0 items-center justify-center overflow-hidden rounded-md bg-background text-muted-foreground @md:w-40',
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
      </div>
      {/* Waits for Watch Progress. Its place stays, so the rows' texts line up */}
      {facts.isOut ? (
        <Button
          variant="ghost"
          size="icon"
          disabled
          aria-pressed={false}
          aria-label={t($ => $.core.episodes.watchedEpisode, {number: facts.code})}
        >
          <CircleIcon />
        </Button>
      ) : (
        <span className="size-9 shrink-0" />
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
