import type {QueryClient} from '@tanstack/react-query';
import {createRootRouteWithContext, Outlet} from '@tanstack/react-router';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {Toaster} from '@/components/ui/sonner';
import {Localization} from '@/l10n';

export const Route = createRootRouteWithContext<{queryClient: QueryClient}>()({
  // Every page's language depends on who's signed in
  beforeLoad: async ({context}) => {
    await context.queryClient.ensureQueryData(currentUserQuery);
  },
  component: () => (
    <Localization>
      <Outlet />
      <Toaster />
    </Localization>
  ),
  errorComponent: () => (
    <Localization>
      <SomethingWentWrong />
    </Localization>
  ),
});
