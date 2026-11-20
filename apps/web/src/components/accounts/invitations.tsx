import {useMutation, useSuspenseQuery} from '@tanstack/react-query';
import {useRouter} from '@tanstack/react-router';
import {hasCode, type Invitation} from '@watchclub/api';
import {
  createInvitationMutation,
  deleteInvitationMutation,
  invitationsQuery,
  parseMaxUses,
  updateInvitationMutation,
} from '@watchclub/core/accounts/invitations';
import {formatRelativeTime} from '@watchclub/core/l10n';
import {
  CheckIcon,
  ClockIcon,
  CopyIcon,
  EllipsisVerticalIcon,
  MailIcon,
  PencilIcon,
  PlusIcon,
  Trash2Icon,
} from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {DeleteDialog} from '@/components/delete-dialog';
import {useAppForm} from '@/components/forms/form';
import {Button} from '@/components/ui/button';
import {Card} from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {Empty, EmptyHeader, EmptyMedia, EmptyTitle} from '@/components/ui/empty';
import {Progress} from '@/components/ui/progress';

/** The time the copy button shows that it copied the link */
const COPIED_DURATION_MS = 3000;

/** The Invitations that can still be redeemed, each on a card, or that there are none. */
export function Invitations() {
  const {t} = useTranslation('web');
  const {data: invitations} = useSuspenseQuery(invitationsQuery);

  if (invitations.length === 0) {
    return (
      <Empty className="border p-6">
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <MailIcon />
          </EmptyMedia>
          <EmptyTitle>{t($ => $.web.invitations.noneActive)}</EmptyTitle>
        </EmptyHeader>
      </Empty>
    );
  }
  return (
    <section className="flex flex-col gap-3">
      <h2 className="flex items-center gap-2 font-heading font-semibold">
        <MailIcon className="size-4 text-muted-foreground" />
        {t($ => $.web.invitations.active)}
      </h2>
      <div className="flex flex-wrap gap-4">
        {invitations.map(invitation => (
          <InvitationCard key={invitation.id} invitation={invitation} />
        ))}
      </div>
    </section>
  );
}

/** The button that opens the dialog that creates an Invitation. */
export function InviteFriendsButton() {
  const {t} = useTranslation('web');
  const [isOpen, setIsOpen] = useState(false);
  return (
    <>
      <Button
        onClick={() => {
          setIsOpen(true);
        }}
      >
        <PlusIcon />
        {t($ => $.web.invitations.inviteFriends)}
      </Button>
      <InvitationDialog invitation={null} open={isOpen} onOpenChange={setIsOpen} />
    </>
  );
}

/** An Invitation: its code, which copies its link, how many Users it created, and when it expires. */
function InvitationCard({invitation}: {invitation: Invitation}) {
  const {t, i18n} = useTranslation('web');
  const [isEditing, setIsEditing] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const deleteInvitation = useMutation(deleteInvitationMutation);

  return (
    <Card size="sm" className="w-72 px-(--card-spacing)">
      <div className="flex items-center justify-between gap-2">
        <div className="flex h-9 min-w-0 flex-1 items-center gap-1 rounded-md border bg-muted pr-0.5 pl-3">
          <span className="min-w-0 flex-1 truncate font-mono font-semibold tracking-wide">
            {invitation.code}
          </span>
          <CopyLinkButton code={invitation.code} />
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger
            render={
              <Button
                variant="outline"
                size="icon"
                aria-label={t($ => $.web.invitations.actions)}
              />
            }
          >
            <EllipsisVerticalIcon />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem
              onClick={() => {
                setIsEditing(true);
              }}
            >
              <PencilIcon />
              {t($ => $.web.invitations.edit)}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              variant="destructive"
              onClick={() => {
                setIsDeleting(true);
              }}
            >
              <Trash2Icon />
              {t($ => $.web.invitations.delete)}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between gap-2">
          <span className="text-muted-foreground">{t($ => $.web.invitations.uses)}</span>
          <span className="font-mono tabular-nums">
            {invitation.max_uses === null
              ? invitation.uses
              : `${invitation.uses} / ${invitation.max_uses}`}
          </span>
        </div>
        {invitation.max_uses !== null && (
          <Progress
            value={invitation.uses}
            max={invitation.max_uses}
            aria-label={t($ => $.web.invitations.uses)}
          />
        )}
      </div>
      <div className="flex items-center justify-between gap-2">
        <span className="text-muted-foreground">{t($ => $.web.invitations.expires)}</span>
        <span className="flex items-center gap-1 text-xs text-muted-foreground">
          <ClockIcon className="size-3.5" />
          {formatRelativeTime(invitation.expires_at, i18n.language)}
        </span>
      </div>

      <InvitationDialog invitation={invitation} open={isEditing} onOpenChange={setIsEditing} />
      <DeleteDialog
        title={t($ => $.web.invitations.deleteInvitation)}
        description={t($ => $.web.invitations.deleteConfirmation, {code: invitation.code})}
        deletedMessage={t($ => $.web.invitations.deleted)}
        onDelete={async () => {
          await deleteInvitation.mutateAsync(invitation.id);
        }}
        open={isDeleting}
        onOpenChange={setIsDeleting}
      />
    </Card>
  );
}

/** The button that copies an Invitation's link, to send to friends. */
function CopyLinkButton({code}: {code: string}) {
  const {t} = useTranslation('web');
  const router = useRouter();
  const [isCopied, setIsCopied] = useState(false);

  async function copyLink() {
    // Through the router, which quotes a code it would read back as a number, such as one of only
    // digits
    const {href} = router.buildLocation({to: '/join', search: {code}});
    const link = new URL(href, window.location.origin).href;
    try {
      await navigator.clipboard.writeText(link);
    } catch {
      // Such as on an address without HTTPS, where browsers don't let pages copy. The User can
      // still copy the link from the toast
      toast.error(
        t($ => $.web.invitations.copyFailed),
        {
          description: link,
          duration: Number.POSITIVE_INFINITY,
          closeButton: true,
        },
      );
      return;
    }
    toast.success(t($ => $.web.invitations.linkCopied));
    setIsCopied(true);
    setTimeout(() => {
      setIsCopied(false);
    }, COPIED_DURATION_MS);
  }

  return (
    <Button
      variant="ghost"
      size="icon-sm"
      aria-label={t($ => $.web.invitations.copyLink)}
      onClick={() => {
        void copyLink();
      }}
    >
      {isCopied ? <CheckIcon className="text-success" /> : <CopyIcon />}
    </Button>
  );
}

/** The dialog that creates an Invitation, or changes the Max Uses of `invitation`. */
function InvitationDialog({
  invitation,
  open,
  onOpenChange,
}: {
  /** The Invitation to change, or null to create one */
  invitation: Invitation | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const {t} = useTranslation('web');
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {invitation === null
              ? t($ => $.web.invitations.newInvitation)
              : t($ => $.web.invitations.editInvitation)}
          </DialogTitle>
          <DialogDescription>{t($ => $.web.invitations.dialogDescription)}</DialogDescription>
        </DialogHeader>
        {/* In the dialog's content, so that each opening starts from the Invitation's values */}
        <InvitationForm
          invitation={invitation}
          onSaved={() => {
            onOpenChange(false);
          }}
        />
      </DialogContent>
    </Dialog>
  );
}

/** The form of the Invitation dialog: its Max Uses. */
function InvitationForm({
  invitation,
  onSaved,
}: {
  invitation: Invitation | null;
  onSaved: () => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const create = useMutation(createInvitationMutation);
  const updateInvitation = useMutation(updateInvitationMutation);
  const form = useAppForm({
    defaultValues: {maxUses: invitation?.max_uses?.toString() ?? ''},
    validators: [
      {
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (parseMaxUses(value.maxUses) === undefined) {
            errors.fields.maxUses = t($ => $.web.invitations.maxUsesMinimum, {min: 1});
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      const maxUses = parseMaxUses(value.maxUses) ?? null;
      try {
        if (invitation === null) {
          await create.mutateAsync(maxUses);
        } else {
          await updateInvitation.mutateAsync({invitationId: invitation.id, maxUses});
        }
      } catch (error) {
        return hasCode(error, 'max_uses_too_low')
          ? createValidationError({fields: {maxUses: t($ => $.web.invitations.maxUsesAlreadyUsed)}})
          : createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      toast.success(
        invitation === null ? t($ => $.web.invitations.created) : t($ => $.web.invitations.updated),
      );
      onSaved();
      return null;
    },
  });

  return (
    <form.AppForm>
      <form.Form className="flex flex-col gap-6">
        <form.Field name="maxUses">
          {field => (
            <field.TextField
              label={t($ => $.web.invitations.maxUses)}
              hint={t($ => $.web.invitations.maxUsesHint)}
              placeholder={t($ => $.web.invitations.unlimited)}
              type="number"
              inputMode="numeric"
              min={1}
              autoFocus
            />
          )}
        </form.Field>
        <form.FormError />
        <form.SubmitButton className="w-full">
          {invitation === null ? t($ => $.web.invitations.create) : t($ => $.web.invitations.save)}
        </form.SubmitButton>
      </form.Form>
    </form.AppForm>
  );
}
