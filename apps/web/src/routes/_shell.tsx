import {useMutation, useQueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {
  createFileRoute,
  Link,
  type LinkProps,
  Outlet,
  redirect,
  useMatchRoute,
  useRouter,
} from '@tanstack/react-router';
import {logoutMutation, type User} from '@watchclub/api';
import {currentUserQuery, forgetCurrentUser} from '@watchclub/core/accounts/current-user';
import {
  ChevronsUpDownIcon,
  ClapperboardIcon,
  DownloadIcon,
  FilmIcon,
  FlagIcon,
  FolderInputIcon,
  HouseIcon,
  InboxIcon,
  ListIcon,
  LogOutIcon,
  type LucideIcon,
  Settings2Icon,
  SettingsIcon,
  UsersIcon,
} from 'lucide-react';
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
    <Sidebar>
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
              <SidebarMenu>
                <SectionLink to="/" icon={HouseIcon} label={t($ => $.core.home.title)} />
                <SectionLink
                  to="/browse"
                  icon={ClapperboardIcon}
                  label={t($ => $.core.browse.title)}
                />
                <SectionLink
                  to="/playlists"
                  icon={ListIcon}
                  label={t($ => $.core.playlists.title)}
                />
                <SectionLink to="/inbox" icon={InboxIcon} label={t($ => $.core.inbox.title)} />
                <SectionLink
                  to="/my-requests"
                  icon={DownloadIcon}
                  label={t($ => $.core.myRequests.navigationLabel)}
                />
              </SidebarMenu>
            </nav>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter>
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
  icon: LucideIcon;
  label: string;
}) {
  const matchRoute = useMatchRoute();
  // Every path starts with Home's, though no page is under Home
  const isActive = Boolean(matchRoute({to, fuzzy: to !== '/'}));
  return (
    <SidebarMenuItem>
      <SidebarMenuButton isActive={isActive} render={<Link to={to} />}>
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
  const {isMobile} = useSidebar();
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
        <ChevronsUpDownIcon className="ml-auto" />
      </DropdownMenuTrigger>
      {/* On phones, the sidebar leaves no room on its right */}
      <DropdownMenuContent side={isMobile ? 'top' : 'right'} align="end">
        <DropdownMenuItem render={<Link to="/settings" />}>
          <SettingsIcon />
          {t($ => $.core.settings.title)}
        </DropdownMenuItem>
        {user.is_instance_administrator && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
              <DropdownMenuLabel>{t($ => $.web.shell.administration)}</DropdownMenuLabel>
              <DropdownMenuItem render={<Link to="/admin/settings" />}>
                <Settings2Icon />
                {t($ => $.web.instanceSettings.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/users" />}>
                <UsersIcon />
                {t($ => $.web.users.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/media" />}>
                <FilmIcon />
                {t($ => $.web.mediaBrowser.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/media/sources" />}>
                <FolderInputIcon />
                {t($ => $.web.mediaSources.title)}
              </DropdownMenuItem>
              <DropdownMenuItem render={<Link to="/admin/problem-reports" />}>
                <FlagIcon />
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
          <LogOutIcon />
          {t($ => $.core.user.signOut)}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
