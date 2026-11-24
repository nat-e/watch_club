import {useMutation} from '@tanstack/react-query';
import {Link} from '@tanstack/react-router';
import type {Source} from '@watchclub/api';
import {importsFiles} from '@watchclub/core/sources/media-imports';
import {isServarrSource, sourceDeletionMutation} from '@watchclub/core/sources/sources';
import * as icons from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {ImportDialog} from '@/components/sources/import-dialog';
import {SourceDialog} from '@/components/sources/source-dialog';
import {useMediaTypeNames} from '@/components/sources/texts';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import {Badge} from '@/components/ui/badge';
import {Button} from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

/**
 * A Source on the Sources page: its folder or its app's address, its Media Type, and the quality
 * profile and root folder of its requests, with a menu to edit or delete it. A Source that imports
 * its files has a button that starts an import, and a link to its import history in its menu.
 */
export function SourceCard({source}: {source: Source}) {
  const {t} = useTranslation('web');
  const mediaTypeNames = useMediaTypeNames();
  const [isEditing, setIsEditing] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const place = isServarrSource(source) ? source.url : source.path;
  const canImport = importsFiles(source);

  return (
    <li className="flex items-start gap-3 rounded-lg border bg-card p-4">
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        <p className="truncate font-mono text-sm font-medium">{place}</p>
        <div className="flex flex-wrap gap-2">
          <Badge variant="secondary">{mediaTypeNames[source.media_type]}</Badge>
          {isServarrSource(source) && (
            <>
              <Badge variant="outline">
                <icons.SparklesIcon />
                {source.quality_profile.name}
              </Badge>
              <Badge variant="outline" className="font-mono">
                <icons.FolderIcon />
                {source.root_folder_path}
              </Badge>
            </>
          )}
        </div>
      </div>
      {canImport && (
        <Button
          variant="outline"
          size="sm"
          onClick={() => {
            setIsImporting(true);
          }}
        >
          <icons.PlayIcon />
          {t($ => $.web.mediaImports.import)}
        </Button>
      )}
      <DropdownMenu>
        <DropdownMenuTrigger
          render={
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={t($ => $.web.sources.actions, {source: place})}
            />
          }
        >
          <icons.EllipsisVerticalIcon />
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onClick={() => {
              setIsEditing(true);
            }}
          >
            <icons.PencilIcon />
            {t($ => $.web.sources.edit)}
          </DropdownMenuItem>
          {canImport && (
            <DropdownMenuItem
              render={<Link to="/admin/sources/$id/imports" params={{id: source.id}} />}
            >
              <icons.HistoryIcon />
              {t($ => $.web.mediaImports.viewHistory)}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            variant="destructive"
            onClick={() => {
              setIsDeleting(true);
            }}
          >
            <icons.TrashIcon />
            {t($ => $.web.sources.delete)}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      <SourceDialog source={source} open={isEditing} onOpenChange={setIsEditing} />
      {canImport && (
        <ImportDialog
          source={source}
          place={place}
          open={isImporting}
          onOpenChange={setIsImporting}
        />
      )}
      <DeleteSourceDialog
        source={source}
        place={place}
        open={isDeleting}
        onOpenChange={setIsDeleting}
      />
    </li>
  );
}

/** The dialog that asks to confirm deleting a Source, and says what it deletes. */
function DeleteSourceDialog({
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
  const deleteSource = useMutation(sourceDeletionMutation);

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{t($ => $.web.sources.deleteDialog.title)}</AlertDialogTitle>
          <AlertDialogDescription>
            {t($ => $.web.sources.deleteDialog.intro)}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <p className="font-mono text-sm break-all">{place}</p>
        <p className="text-sm text-muted-foreground">
          {t($ => $.web.sources.deleteDialog.consequence)}
        </p>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={deleteSource.isPending}>
            {t($ => $.core.controls.cancel)}
          </AlertDialogCancel>
          <AlertDialogAction
            variant="destructive"
            disabled={deleteSource.isPending}
            onClick={() => {
              deleteSource.mutate(source.id, {
                onSuccess: () => {
                  onOpenChange(false);
                  toast.success(t($ => $.web.sources.deleted));
                },
                onError: () => {
                  toast.error(t($ => $.core.errors.somethingWentWrong));
                },
              });
            }}
          >
            {deleteSource.isPending
              ? t($ => $.web.sources.deleteDialog.deleting)
              : t($ => $.web.sources.deleteDialog.confirm)}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
