import {TMDB_LOGO_ASPECT_RATIO, TMDB_LOGO_SVG, TMDB_URL} from '@watchclub/core/contents/tmdb';
import {useTranslation} from 'react-i18next';
import {Linking, Pressable, ScrollView, Text} from 'react-native';
import {SvgXml} from 'react-native-svg';

/** The height of TMDB's logo, in points: smaller than the Instance's name, as TMDB's terms ask */
const TMDB_LOGO_HEIGHT = 16;

/**
 * About: TMDB's notice and logo, which its terms require, the logo unaltered. The logo opens TMDB's
 * website.
 */
export default function About() {
  const {t} = useTranslation('core');
  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerClassName="gap-4 p-6">
      <Text className="text-base text-muted-foreground">{t($ => $.core.settings.tmdbNotice)}</Text>
      <Pressable
        accessibilityRole="link"
        accessibilityLabel={t($ => $.core.settings.tmdbLogo)}
        onPress={() => {
          void Linking.openURL(TMDB_URL);
        }}
        className="min-h-11 justify-center self-start rounded-sm focus:bg-accent"
      >
        <SvgXml
          xml={TMDB_LOGO_SVG}
          height={TMDB_LOGO_HEIGHT}
          width={TMDB_LOGO_HEIGHT * TMDB_LOGO_ASPECT_RATIO}
        />
      </Pressable>
    </ScrollView>
  );
}
