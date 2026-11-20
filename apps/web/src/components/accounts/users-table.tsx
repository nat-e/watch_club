import {useMutation, useSuspenseQuery} from '@tanstack/react-query';
import type {User} from '@watchclub/api';
import {deleteUserMutation, usersQuery} from '@watchclub/core/accounts/users';
import {formatRelativeTime} from '@watchclub/core/l10n';
import {EllipsisVerticalIcon, ShieldIcon, Trash2Icon} from 'lucide-react';
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
import {Avatar, AvatarFallback} from '@/components/ui/avatar';
import {Badge} from '@/components/ui/badge';
import {Button} from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {Table, TableBody, TableCell, TableHead, TableHeader, TableRow} from '@/components/ui/table';

/** Every User, the first to join first, with when they joined and what the Instance Administrator can do to them. */
export function UsersTable() {
  const {t} = useTranslation('web');
  const {data: users} = useSuspenseQuery(usersQuery);
  return (
    // A container, so that narrow pages leave out when each User joined
    <div className="@container">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-full">{t($ => $.web.users.user)}</TableHead>
            <TableHead className="hidden @xl:table-cell">
              {t($ => $.web.users.memberSince)}
            </TableHead>
            <TableHead className="text-end">
              <span className="sr-only">{t($ => $.web.users.actions)}</span>
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {users.map(user => (
            <UserRow key={user.id} user={user} />
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

/** A User: their username, whether they're the Instance Administrator, and when they joined. */
function UserRow({user}: {user: User}) {
  const {t, i18n} = useTranslation(['web', 'core']);
  const [isDeleting, setIsDeleting] = useState(false);
  // Usernames are lowercase ASCII, so their first character is a letter or digit
  const initial = user.username.slice(0, 1).toUpperCase();

  return (
    <TableRow>
      <TableCell className="max-w-0">
        <div className="flex items-center gap-3">
          <Avatar>
            <AvatarFallback>{initial}</AvatarFallback>
          </Avatar>
          <div className="flex min-w-0 flex-col gap-1">
            <span className="truncate font-semibold">{user.username}</span>
            {user.is_instance_administrator && (
              <Badge variant="secondary">
                <ShieldIcon />
                {t($ => $.core.user.instanceAdministrator)}
              </Badge>
            )}
          </div>
        </div>
      </TableCell>
      <TableCell className="hidden text-muted-foreground @xl:table-cell">
        {formatRelativeTime(user.member_since, i18n.language)}
      </TableCell>
      <TableCell className="text-end">
        {/* The Instance Administrator can't be deleted */}
        {!user.is_instance_administrator && (
          <>
            <DropdownMenu>
              <DropdownMenuTrigger
                render={
                  <Button
                    variant="outline"
                    size="icon"
                    aria-label={t($ => $.web.users.actionsFor, {username: user.username})}
                  />
                }
              >
                <EllipsisVerticalIcon />
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem
                  variant="destructive"
                  onClick={() => {
                    setIsDeleting(true);
                  }}
                >
                  <Trash2Icon />
                  {t($ => $.web.users.deleteUser)}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <DeleteUserDialog user={user} open={isDeleting} onOpenChange={setIsDeleting} />
          </>
        )}
      </TableCell>
    </TableRow>
  );
}

/** The dialog that confirms deleting a User, with what it deletes. */
function DeleteUserDialog({
  user,
  open,
  onOpenChange,
}: {
  user: User;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const deleteUser = useMutation(deleteUserMutation);

  async function confirmDeletion() {
    try {
      await deleteUser.mutateAsync(user.id);
    } catch {
      toast.error(t($ => $.core.errors.somethingWentWrong));
      return;
    }
    toast.success(t($ => $.web.users.userDeleted));
    onOpenChange(false);
  }

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent size="sm">
        <AlertDialogHeader>
          <AlertDialogTitle>{t($ => $.web.users.deleteUser)}</AlertDialogTitle>
          <AlertDialogDescription>
            {t($ => $.web.users.deleteConfirmation, {username: user.username})}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t($ => $.core.controls.cancel)}</AlertDialogCancel>
          <Button
            variant="destructive"
            disabled={deleteUser.isPending}
            onClick={() => {
              void confirmDeletion();
            }}
          >
            {t($ => $.web.users.deleteUser)}
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
