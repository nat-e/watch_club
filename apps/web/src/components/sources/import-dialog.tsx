import {useMutation} from '@tanstack/react-query';
import type {FilesToImport, Source} from '@watchclub/api';
import {FILES_TO_IMPORT, startMediaImportMutation} from '@watchclub/core/sources/media-imports';
import {PlayIcon} from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {useFilesToImportTexts, useSourceTypeTexts} from '@/components/sources/texts';
import {Button} from '@/components/ui/button';
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {Field, FieldContent, FieldDescription, FieldLabel, FieldTitle} from '@/components/ui/field';
import {RadioGroup, RadioGroupItem} from '@/components/ui/radio-group';

/**
 * The dialog where the Instance Administrator starts an import of a Source's files, and chooses
 * which: the new ones, also the Unmatched ones, or all of them.
 */
export function ImportDialog({
  source,
  place,
  open,
  onOpenChange,
}: {
  source: Source;
  /** The Source's folder or its app's address */
  place: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const typeTexts = useSourceTypeTexts();
  const choiceTexts = useFilesToImportTexts();
  const startImport = useMutation(startMediaImportMutation);
  const [filesToImport, setFilesToImport] = useState<FilesToImport>('new');

  function start() {
    startImport.mutate(
      {sourceId: source.id, filesToImport},
      {
        onSuccess: () => {
          onOpenChange(false);
          toast.success(t($ => $.web.mediaImports.started));
        },
        onError: () => {
          toast.error(t($ => $.core.errors.somethingWentWrong));
        },
      },
    );
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t($ => $.web.mediaImports.dialog.title)}</DialogTitle>
          <DialogDescription>
            {t($ => $.web.mediaImports.dialog.description, {source: typeTexts[source.type].name})}
          </DialogDescription>
        </DialogHeader>
        <p className="font-mono text-sm break-all">{place}</p>
        <RadioGroup
          value={filesToImport}
          onValueChange={value => {
            // biome-ignore lint/nursery/noUnsafeTypeAssertion: the group's items are choices of files
            setFilesToImport(value as FilesToImport);
          }}
          aria-label={t($ => $.web.mediaImports.dialog.filesToImport)}
        >
          {FILES_TO_IMPORT.map(choice => (
            <FieldLabel key={choice}>
              <Field orientation="horizontal">
                <FieldContent>
                  <FieldTitle>{choiceTexts[choice].name}</FieldTitle>
                  <FieldDescription>{choiceTexts[choice].description}</FieldDescription>
                </FieldContent>
                <RadioGroupItem value={choice} />
              </Field>
            </FieldLabel>
          ))}
        </RadioGroup>
        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>
            {t($ => $.core.controls.cancel)}
          </DialogClose>
          <Button disabled={startImport.isPending} onClick={start}>
            <PlayIcon />
            {t($ => $.web.mediaImports.dialog.run)}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
