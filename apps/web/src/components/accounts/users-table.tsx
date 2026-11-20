import {useMutation, useSuspenseQuery} from '@tanstack/react-query';
import {useRouter} from '@tanstack/react-router';
import type {User} from '@watchclub/api';
import {
  createPasswordResetLinkMutation,
  deleteUserMutation,
  usersQuery,
} from '@watchclub/core/accounts/users';
import {formatRelativeTime} from '@watchclub/core/l10n';
import {EllipsisVerticalIcon, KeyRoundIcon, ShieldIcon, Trash2Icon} from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {DeleteDialog} from '@/components/delete-dialog';
import {Avatar, AvatarFallback} from '@/components/ui/avatar';
import {Badge} from '@/components/ui/badge';
import {Button} from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {Table, TableBody, TableCell, TableHead, TableHeader, TableRow} from '@/components/ui/table';
import {useCopyLink} from '@/lib/copy-link';

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

/**
 * A User: their username, whether they're the Instance Administrator, and when they joined, with
 * the menu that copies a Password Reset Link for them or deletes them.
 */
function UserRow({user}: {user: User}) {
  const {t, i18n} = useTranslation(['web', 'core']);
  const router = useRouter();
  const copyLink = useCopyLink();
  const [isDeleting, setIsDeleting] = useState(false);
  const createPasswordResetLink = useMutation(createPasswordResetLinkMutation);
  const deleteUser = useMutation(deleteUserMutation);
  // Usernames are lowercase ASCII, so their first character is a letter or digit
  const initial = user.username.slice(0, 1).toUpperCase();

  async function copyPasswordResetLink() {
    // Copied once the API creates it, without waiting for it first: see `useCopyLink`
    const link = createPasswordResetLink.mutateAsync(user.id).then(token => {
      const {href} = router.buildLocation({to: '/reset-password', search: {token}});
      return new URL(href, window.location.origin).href;
    });
    let wasCopied: boolean;
    try {
      wasCopied = await copyLink(link);
    } catch {
      toast.error(t($ => $.core.errors.somethingWentWrong));
      return;
    }
    if (wasCopied) {
      toast.success(t($ => $.web.users.resetLinkCopied, {username: user.username}));
    }
  }

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
          {/* As wide as its items, rather than as the button, so that they don't wrap */}
          <DropdownMenuContent align="end" className="w-auto">
            <DropdownMenuItem
              onClick={() => {
                void copyPasswordResetLink();
              }}
            >
              <KeyRoundIcon />
              {t($ => $.web.users.resetPassword)}
            </DropdownMenuItem>
            {/* The Instance Administrator can't be deleted */}
            {!user.is_instance_administrator && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  variant="destructive"
                  onClick={() => {
                    setIsDeleting(true);
                  }}
                >
                  <Trash2Icon />
                  {t($ => $.web.users.deleteUser)}
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
        {!user.is_instance_administrator && (
          <DeleteDialog
            title={t($ => $.web.users.deleteUser)}
            description={t($ => $.web.users.deleteConfirmation, {username: user.username})}
            deletedMessage={t($ => $.web.users.userDeleted)}
            onDelete={async () => {
              await deleteUser.mutateAsync(user.id);
            }}
            open={isDeleting}
            onOpenChange={setIsDeleting}
          />
        )}
      </TableCell>
    </TableRow>
  );
}
