import type {Media} from '@watchclub/api';
import {useEpisodeFacts, useEpisodes} from '@watchclub/core/contents/media';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, FlatList, Text, View} from 'react-native';
import {ChoiceChips} from '@/components/choice-chips';
import {SizedImage} from '@/components/contents/sized-image';
import {StatusScreen} from '@/components/layouts/status-screen';

/** A TV Show's Episodes, of the season the User picks, the first one at first. */
export function Episodes({contentId}: {contentId: string}) {
  const {t} = useTranslation('core');
  const {status, seasons, season, pickSeason, retry} = useEpisodes(contentId);

  if (status === 'loading') {
    return (
      <View className="flex-1 items-center justify-center">
        <ActivityIndicator accessibilityLabel={t($ => $.core.contents.loading)} />
      </View>
    );
  }
  if (status === 'failed') {
    return (
      <StatusScreen
        description={t($ => $.core.errors.somethingWentWrong)}
        actions={[{label: t($ => $.core.controls.tryAgain), onPress: retry}]}
      />
    );
  }

  const seasonName = (number: number) => t($ => $.core.episodes.season, {number});
  return (
    <FlatList
      data={season?.media ?? []}
      keyExtractor={episode => episode.id}
      renderItem={({item}) => <EpisodeRow episode={item} />}
      ListHeaderComponent={
        season &&
        (seasons.length > 1 ? (
          <ChoiceChips
            label={t($ => $.core.contents.episodes)}
            options={seasons.map(each => ({
              value: String(each.number),
              label: seasonName(each.number),
            }))}
            value={String(season.number)}
            onChange={number => {
              pickSeason(Number(number));
            }}
          />
        ) : (
          <Text className="px-4 py-2 text-sm font-semibold text-foreground">
            {seasonName(season.number)}
          </Text>
        ))
      }
      contentContainerClassName="pb-8"
      contentInsetAdjustmentBehavior="automatic"
    />
  );
}

/**
 * A TV Show Episode: its still, its number, title, runtime and when it comes out, and its overview.
 * The still is grey before it comes out.
 */
function EpisodeRow({episode}: {episode: Media}) {
  const facts = useEpisodeFacts(episode);
  const notes = [facts.runtime, facts.releaseNote].filter(note => note !== null);
  return (
    // One stop for a TV's remote and for screen readers, which read it whole
    <View accessible focusable className="flex-row items-start gap-4 px-4 py-2 focus:bg-accent">
      <View
        className={`aspect-video w-28 overflow-hidden rounded-md bg-accent ${
          facts.isOut ? '' : 'opacity-60'
        }`}
      >
        {episode.image && <SizedImage image={episode.image} style={{flex: 1}} />}
      </View>
      <View className="flex-1 gap-1">
        <Text className="text-base text-foreground">
          <Text className="font-semibold">{facts.code}</Text>
          {/* i18next-instrument-ignore: a separator, the same in every language */}
          {episode.title && ` · ${episode.title}`}
        </Text>
        {notes.length > 0 && (
          <Text className="text-xs text-muted-foreground">{notes.join('  ')}</Text>
        )}
        {episode.overview && (
          <Text numberOfLines={2} className="text-sm text-muted-foreground">
            {episode.overview}
          </Text>
        )}
      </View>
    </View>
  );
}
