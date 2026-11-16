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
import {currentUserQuery, signedOut} from '@watchclub/core/accounts/session';
import {ChevronsUpDownIcon, HouseIcon, LogOutIcon, SettingsIcon} from 'lucide-react';
import {useTranslation} from 'react-i18next';
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
} from '@/components/ui/sidebar';

/** Lays out the pages for signed-in Users, beside a sidebar with the navigation and their menu. */
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
  const {t} = useTranslation(['web', 'core']);
  const {data: user} = useSuspenseQuery(currentUserQuery);
  const location = useLocation();
  // Signed out: `beforeLoad` sends the visitor to sign in once the router runs it again
  if (!user) {
    return null;
  }

  return (
    <SidebarProvider>
      <Sidebar collapsible="none" className="sticky top-0 h-svh">
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
                    <SidebarMenuButton
                      isActive={location.pathname === '/'}
                      render={<Link to="/" />}
                    >
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
      <SidebarInset>
        <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 p-6">
          <Outlet />
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}

/** The button that opens the User's menu, with their settings and signing out. */
function UserMenu({user}: {user: User}) {
  const {t} = useTranslation('core');
  const queryClient = useQueryClient();
  const router = useRouter();
  const signOut = useMutation({
    ...logoutMutation(),
    onSuccess: async () => {
      await signedOut(queryClient);
      await router.invalidate();
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
      <DropdownMenuContent side="right" align="end">
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
