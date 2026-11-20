import type {Source} from '@watchclub/api';
import type {SourceType} from '@watchclub/core/sources/sources';
import * as icons from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {SourceCard} from '@/components/sources/source-card';
import {SourceDialog} from '@/components/sources/source-dialog';
import {useSourceTypeTexts} from '@/components/sources/texts';
import {Button} from '@/components/ui/button';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';
import {Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle} from '@/components/ui/empty';

/** The icon of each Source Type. */
const ICONS: Record<SourceType, icons.LucideIcon> = {
  filesystem: icons.HardDriveIcon,
  radarr: icons.FilmIcon,
  sonarr: icons.TvIcon,
  sportarr: icons.TrophyIcon,
};

/** The Sources of a type, with what they do and a button to add one. */
export function SourceTypeSection({type, sources}: {type: SourceType; sources: Source[]}) {
  const {t} = useTranslation('web');
  const texts = useSourceTypeTexts()[type];
  const [isAdding, setIsAdding] = useState(false);
  const Icon = ICONS[type];

  return (
    <section>
      <Card>
        <CardHeader className="flex flex-col items-start gap-4 sm:flex-row sm:justify-between">
          <div className="flex min-w-0 items-start gap-3">
            <Icon className="mt-1 size-6 shrink-0 text-muted-foreground" />
            <div className="flex min-w-0 flex-col gap-1">
              <h2 className="font-heading text-xl font-semibold tracking-tight">{texts.name}</h2>
              <CardDescription className="max-w-readable leading-6">
                {texts.description}
              </CardDescription>
            </div>
          </div>
          <Button
            onClick={() => {
              setIsAdding(true);
            }}
          >
            <icons.PlusIcon />
            {t($ => $.web.sources.add, {type: texts.name})}
          </Button>
        </CardHeader>
        <CardContent>
          {sources.length === 0 ? (
            <Empty className="p-6">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <Icon />
                </EmptyMedia>
                <EmptyTitle>{t($ => $.web.sources.none, {type: texts.name})}</EmptyTitle>
                <EmptyDescription>{texts.empty}</EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <ul className="flex flex-col gap-3">
              {sources.map(source => (
                <SourceCard key={source.id} source={source} />
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
      <SourceDialog type={type} open={isAdding} onOpenChange={setIsAdding} />
    </section>
  );
}
