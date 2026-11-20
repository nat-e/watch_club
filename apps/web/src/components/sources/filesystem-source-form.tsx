import {useMutation} from '@tanstack/react-query';
import type {MediaType} from '@watchclub/api';
import {
  FILESYSTEM_MEDIA_TYPES,
  type FilesystemSource,
  InvalidFilesystemConfigurationError,
  saveSourceMutation,
} from '@watchclub/core/sources/sources';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {useAppForm} from '@/components/forms/form';
import {SelectField} from '@/components/forms/select-field';
import {useErrorMessages, useMediaTypeNames} from '@/components/sources/texts';
import {Button} from '@/components/ui/button';
import {
  DialogClose,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

/** An example of a folder's path */
const PATH_EXAMPLE = '/media/movies';

/**
 * The form of a Filesystem Source in a dialog, which creates one, or edits `source`. Its Media Type
 * can't change once created.
 */
export function FilesystemSourceForm({
  source,
  onSaved,
}: {
  source?: FilesystemSource;
  onSaved: () => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const save = useMutation(saveSourceMutation);
  const mediaTypeNames = useMediaTypeNames();
  const errorMessages = useErrorMessages();
  const defaultMediaType: MediaType = source?.media_type ?? 'movie';
  const form = useAppForm({
    defaultValues: {mediaType: defaultMediaType, path: source?.path ?? ''},
    validators: [
      {
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (value.path.trim() === '') {
            errors.fields.path = t($ => $.web.sources.filesystemForm.enterPath);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      try {
        await save.mutateAsync({
          // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
          configuration: {type: 'filesystem', media_type: value.mediaType, path: value.path},
          id: source?.id,
        });
      } catch (error) {
        if (error instanceof InvalidFilesystemConfigurationError) {
          return createValidationError({fields: {path: errorMessages.folder(error.cause)}});
        }
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      toast.success(
        source === undefined ? t($ => $.web.sources.configured) : t($ => $.web.sources.updated),
      );
      onSaved();
      return null;
    },
  });

  return (
    <>
      <DialogHeader>
        <DialogTitle>
          {source === undefined
            ? t($ => $.web.sources.filesystemForm.createTitle)
            : t($ => $.web.sources.filesystemForm.editTitle)}
        </DialogTitle>
        {source === undefined && (
          <DialogDescription>
            {t($ => $.web.sources.filesystemForm.createDescription)}
          </DialogDescription>
        )}
      </DialogHeader>
      <form.AppForm>
        <form.Form className="flex flex-col gap-6">
          <form.Field name="mediaType">
            {field => (
              <SelectField
                label={t($ => $.web.sources.filesystemForm.mediaType)}
                description={t($ => $.web.sources.filesystemForm.mediaTypeLocked)}
                disabled={source !== undefined}
                options={FILESYSTEM_MEDIA_TYPES.map(mediaType => ({
                  value: mediaType,
                  label: mediaTypeNames[mediaType],
                }))}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.Field name="path">
            {field => (
              <field.TextField
                label={t($ => $.web.sources.filesystemForm.directory)}
                hint={t($ => $.web.sources.filesystemForm.directoryHint)}
                placeholder={PATH_EXAMPLE}
                autoComplete="off"
                spellCheck={false}
                className="font-mono"
              />
            )}
          </form.Field>
          <form.FormError />
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t($ => $.core.controls.cancel)}
            </DialogClose>
            <form.SubmitButton>
              {source === undefined
                ? t($ => $.web.sources.filesystemForm.create)
                : t($ => $.web.sources.filesystemForm.save)}
            </form.SubmitButton>
          </DialogFooter>
        </form.Form>
      </form.AppForm>
    </>
  );
}
