import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import {Button} from '@/components/ui/button';

/**
 * A dialog that asks to confirm deleting something, with what deleting does. Once `onDelete` deletes
 * it, the dialog closes and a toast says it's deleted; when it fails, the dialog stays open and a
 * toast says so.
 */
export function DeleteDialog({
  title,
  description,
  deletedMessage,
  onDelete,
  open,
  onOpenChange,
}: {
  /** The dialog's title, which its button repeats, such as "Delete user" */
  title: string;
  /** The consequences of deleting, which the User reads before confirming */
  description: string;
  /** The toast once deleted, such as "User deleted" */
  deletedMessage: string;
  onDelete: () => Promise<void>;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const {t} = useTranslation('core');
  const [isDeleting, setIsDeleting] = useState(false);

  // Awaited rather than through a mutation's callbacks: the deleted thing's component, which
  // holds this dialog, can go once its list refreshes
  async function confirmDeletion() {
    setIsDeleting(true);
    try {
      await onDelete();
    } catch {
      toast.error(t($ => $.core.errors.somethingWentWrong));
      return;
    } finally {
      setIsDeleting(false);
    }
    toast.success(deletedMessage);
    onOpenChange(false);
  }

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t($ => $.core.controls.cancel)}</AlertDialogCancel>
          <Button
            variant="destructive"
            disabled={isDeleting}
            onClick={() => {
              void confirmDeletion();
            }}
          >
            {title}
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
