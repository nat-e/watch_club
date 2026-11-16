import {useMutation, useQueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {
  createFileRoute,
  Link,
  Outlet,
  redirect,
  useLocation,
  useRouter,
} from '@tanstack/react-router';
import {logoutMutation, type User} from '@watchclub/api';
import {currentUserQuery, forgetCurrentUser} from '@watchclub/core/accounts/current-user';
import {ChevronsUpDownIcon, HouseIcon, LogOutIcon, SettingsIcon} from 'lucide-react';
import {useEffect} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {Avatar, AvatarFallback} from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
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
  SidebarTrigger,
  useSidebar,
} from '@/components/ui/sidebar';

/**
 * Lays out the pages for signed-in Users, beside a sidebar with the navigation and their menu. On
 * phones, the sidebar slides in from a bar above the page.
 */
export const Route = createFileRoute('/_shell')({
  beforeLoad: async ({context, location}) => {
    const user = await context.queryClient.ensureQueryData(currentUserQuery);
    if (!user) {
      // biome-ignore lint/style/useNamingConvention: URL parameters are snake_case
      throw redirect({to: '/sign-in', search: {return_to: location.href}});
    }
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
        <PhoneBar />
        <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 p-6">
          <Outlet />
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}

/**
 * Shows the navigation and the User's menu. On phones, it slides in over the page, and hides once
 * one of its links opens a page.
 */
function AppSidebar({user}: {user: User}) {
  const {t} = useTranslation(['web', 'core']);
  const location = useLocation();
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
                <SidebarMenuItem>
                  <SidebarMenuButton isActive={location.pathname === '/'} render={<Link to="/" />}>
                    <HouseIcon />
                    <span>{t($ => $.core.home.title)}</span>
                  </SidebarMenuButton>
                </SidebarMenuItem>
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

/** Shows a bar above the page on phones, whose button slides the sidebar in. */
function PhoneBar() {
  return (
    <header className="sticky top-0 z-10 flex h-12 items-center gap-2 border-b bg-background px-3 md:hidden">
      <SidebarTrigger />
      {/* i18next-instrument-ignore: the name stays the same in every language */}
      <span className="font-heading text-base font-semibold">WatchClub</span>
    </header>
  );
}

/** The button that opens the User's menu, with their settings and signing out. */
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
        <DropdownMenuSeparator />
        <DropdownMenuItem disabled={signOut.isPending} onClick={() => signOut.mutate({})}>
          <LogOutIcon />
          {t($ => $.core.user.signOut)}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
