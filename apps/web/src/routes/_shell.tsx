import {useMutation, useQueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {
  createFileRoute,
  Link,
  type LinkProps,
  Outlet,
  redirect,
  useRouter,
} from '@tanstack/react-router';
import {logoutMutation, type User} from '@watchclub/api';
import {currentUserQuery, forgetCurrentUser} from '@watchclub/core/accounts/current-user';
import * as icons from 'lucide-react';
import {useEffect} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {Avatar, AvatarFallback} from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  useSidebar,
} from '@/components/ui/sidebar';

/**
 * The layout of the pages for signed-in Users, beside a sidebar with the navigation and their menu.
 * On phones, the sidebar slides in from each page's bar.
 */
export const Route = createFileRoute('/_shell')({
  beforeLoad: async ({context, location}) => {
    const user = await context.queryClient.ensureQueryData(currentUserQuery);
    if (!user) {
      // biome-ignore lint/style/useNamingConvention: URL parameters are snake_case
      throw redirect({to: '/sign-in', search: {return_to: location.href}});
    }
    // For the pages below that only some Users may open
    return {user};
  },
  component: Shell,
});

function Shell() {
  const {data: user} = useSuspenseQuery(currentUserQuery);
  const router = useRouter();
  const isSignedIn = user !== null;
  // Once nobody is signed in, however the session ended, running `beforeLoad` again sends the
  // visitor to sign in
  useEffect(() => {
    if (!isSignedIn) {
      void router.invalidate();
    }
  }, [isSignedIn, router]);
  if (!user) {
    return null;
  }

  // `open` keeps the sidebar on wide screens, which have no button to bring it back
  return (
    <SidebarProvider open>
      <AppSidebar user={user} />
      <SidebarInset>
        <Outlet />
      </SidebarInset>
    </SidebarProvider>
  );
}

/**
 * The navigation and the User's menu. On phones, it slides in over the page, and hides once one of
 * its links opens a page.
 */
function AppSidebar({user}: {user: User}) {
  const {t} = useTranslation(['web', 'core']);
  const router = useRouter();
  const {setOpenMobile} = useSidebar();
  useEffect(
    () =>
      router.subscribe('onResolved', () => {
        setOpenMobile(false);
      }),
    [router, setOpenMobile],
  );

  return (
    // No border: the sidebar's color sets it apart from the page
    <Sidebar className="group-data-[side=left]:border-r-0">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" render={<Link to="/" />}>
              {/* i18next-instrument-ignore: the name stays the same in every language */}
              <span className="font-heading text-base font-semibold">WatchClub</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupContent>
            <nav aria-label={t($ => $.web.shell.navigation)}>
              <SidebarMenu className="gap-px">
                <SectionLink to="/" icon={icons.HouseIcon} label={t($ => $.core.home.title)} />
                <SectionLink
                  to="/browse"
                  icon={icons.ClapperboardIcon}
                  label={t($ => $.core.browse.title)}
                />
                <SectionLink
                  to="/playlists"
                  icon={icons.ListIcon}
                  label={t($ => $.core.playlists.title)}
                />
                <SectionLink
                  to="/inbox"
                  icon={icons.InboxIcon}
                  label={t($ => $.core.inbox.title)}
                />
                <SectionLink
                  to="/my-requests"
                  icon={icons.DownloadIcon}
                  label={t($ => $.core.myRequests.navigationLabel)}
                />
              </SidebarMenu>
            </nav>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter className="border-t border-sidebar-border">
        <SidebarMenu>
          <SidebarMenuItem>
            <UserMenu user={user} />
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}

/** The link to one of the app's sections, highlighted on its page and the pages under it. */
function SectionLink({
  to,
  icon: Icon,
  label,
}: {
  to: LinkProps['to'];
  icon: icons.LucideIcon;
  label: string;
}) {
  return (
    <SidebarMenuItem>
      <SidebarMenuButton
        // Taller for fingers. The current section's text and icon stand out from the others'
        className="h-9 font-semibold text-muted-foreground pointer-coarse:h-11 hover:text-foreground data-active:bg-selected data-active:font-semibold data-active:text-foreground data-active:hover:bg-selected [&_svg]:text-subtle-foreground data-active:[&_svg]:text-muted-foreground"
        render={
          <Link
            to={to}
            // Every path starts with Home's, though no page is under Home
            activeOptions={{exact: to === '/'}}
            // The sidebar's style for the current section
            activeProps={{'data-active': ''}}
          />
        }
      >
        <Icon />
        <span>{label}</span>
      </SidebarMenuButton>
    </SidebarMenuItem>
  );
}

/**
 * The button that opens the User's menu, with their settings, the administration pages for the
 * Instance Administrator, and signing out.
 */
function UserMenu({user}: {user: User}) {
  const {t} = useTranslation(['web', 'core']);
  const queryClient = useQueryClient();
  const signOut = useMutation({
    ...logoutMutation(),
    // Fails at once when the device is offline, rather than waiting for the network unseen
    networkMode: 'always',
    onSuccess: () => forgetCurrentUser(queryClient),
    // The User stays signed in, as only the server can remove the session cookie, and the menu has
    // closed, so a toast tells them
    onError: () => {
      toast.error(t($ => $.web.shell.signOutFailed));
    },
  });
  // Usernames are lowercase ASCII, so their first character is a letter or digit
  const initial = user.username.slice(0, 1).toUpperCase();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger render={<SidebarMenuButton size="lg" />}>
        <Avatar size="sm">
          <AvatarFallback>{initial}</AvatarFallback>
        </Avatar>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="truncate font-medium">{user.username}</span>
          {user.is_instance_administrator && (
            <span className="truncate text-xs text-muted-foreground">
              {t($ => $.core.user.instanceAdministrator)}
            </span>
          )}
        </span>
        <icons.ChevronsUpDownIcon className="ml-auto" />
      </DropdownMenuTrigger>
      <DropdownMenuContent side="top">
        <DropdownMenuItem render={<Link to="/settings" />}>
          <icons.SettingsIcon />
          {t($ => $.core.settings.title)}
        </DropdownMenuItem>
        {user.is_instance_administrator && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
              <DropdownMenuLabel>{t($ => $.web.shell.administration)}</DropdownMenuLabel>
              <DropdownMenuItem render={<Link to="/admin/settings" />}>
                <icons.Settings2Icon />
                {t($ => $.web.instanceSettings.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/users" />}>
                <icons.UsersIcon />
                {t($ => $.web.users.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/media" />}>
                <icons.FilmIcon />
                {t($ => $.web.mediaBrowser.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/media/sources" />}>
                <icons.FolderInputIcon />
                {t($ => $.web.mediaSources.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/problem-reports" />}>
                <icons.FlagIcon />
                {t($ => $.web.problemReports.title)}
              </DropdownMenuItem>
            </DropdownMenuGroup>
          </>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem
          disabled={signOut.isPending}
          onClick={() => {
            signOut.mutate({});
          }}
        >
          <icons.LogOutIcon />
          {t($ => $.core.user.signOut)}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
