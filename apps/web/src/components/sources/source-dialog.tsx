import type {Source} from '@watchclub/api';
import type {SourceType} from '@watchclub/core/sources/sources';
import {FilesystemSourceForm} from '@/components/sources/filesystem-source-form';
import {ServarrSourceForm} from '@/components/sources/servarr-source-form';
import {Dialog, DialogContent} from '@/components/ui/dialog';

/** The type of the Source to create, or the Source to edit. */
type Target = {type: SourceType; source?: never} | {source: Source; type?: never};

/**
 * The dialog where the Instance Administrator adds a Source of the type, or edits `source`. Its form
 * starts over each time it opens.
 */
export function SourceDialog({
  open,
  onOpenChange,
  ...target
}: Target & {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const close = () => {
    onOpenChange(false);
  };
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <SourceForm target={target} onSaved={close} />
      </DialogContent>
    </Dialog>
  );
}

/** The form of the Source's type, which creates a Source of the type, or edits `source`. */
function SourceForm({target, onSaved}: {target: Target; onSaved: () => void}) {
  const {source} = target;
  if (source !== undefined) {
    return source.type === 'filesystem' ? (
      <FilesystemSourceForm source={source} onSaved={onSaved} />
    ) : (
      <ServarrSourceForm source={source} onSaved={onSaved} />
    );
  }
  return target.type === 'filesystem' ? (
    <FilesystemSourceForm onSaved={onSaved} />
  ) : (
    <ServarrSourceForm app={target.type} onSaved={onSaved} />
  );
}
