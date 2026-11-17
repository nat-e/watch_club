import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** Playlists, where Users find their Playlists and the ones shared with them. Empty for now. */
export const Route = createFileRoute('/_shell/playlists')({component: Playlists});

function Playlists() {
  const {t} = useTranslation('core');
  return <Page title={t($ => $.core.playlists.title)} />;
}
