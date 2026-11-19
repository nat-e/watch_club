import type {QueryClient} from '@tanstack/react-query';
import {createRootRouteWithContext, Outlet} from '@tanstack/react-router';
import {getInstanceOptions} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {useInstanceName} from '@watchclub/core/instance';
import {useEffect} from 'react';
import {NotFound} from '@/components/not-found';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {Toaster} from '@/components/ui/sonner';
import {Localization} from '@/l10n';

export const Route = createRootRouteWithContext<{queryClient: QueryClient}>()({
  // Every page's language depends on who's signed in, and many pages show the Instance Name
  beforeLoad: async ({context}) => {
    await Promise.all([
      context.queryClient.ensureQueryData(currentUserQuery),
      context.queryClient.ensureQueryData(getInstanceOptions()),
    ]);
  },
  component: Root,
  notFoundComponent: NotFound,
  errorComponent: () => (
    <Localization>
      <SomethingWentWrong />
    </Localization>
  ),
});

/** Every page, in the User's language, in a browser tab named after the Instance. */
function Root() {
  const instanceName = useInstanceName();
  useEffect(() => {
    document.title = instanceName;
  }, [instanceName]);

  return (
    <Localization>
      <Outlet />
      <Toaster />
    </Localization>
  );
}
