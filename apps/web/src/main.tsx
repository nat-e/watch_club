import '@/index.css';
import {QueryClientProvider} from '@tanstack/react-query';
import {createRouter, RouterProvider} from '@tanstack/react-router';
import {createQueryClient} from '@watchclub/core/query-client';
import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {routeTree} from '@/routeTree.gen';

const queryClient = createQueryClient();

const router = createRouter({
  routeTree,
  context: {queryClient},
  defaultPreload: 'intent',
  // TanStack Query decides when the data is stale
  defaultPreloadStaleTime: 0,
  defaultErrorComponent: SomethingWentWrong,
  scrollRestoration: true,
});

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}

const container = document.getElementById('root');
if (!container) {
  throw new Error('index.html has no #root element');
}
createRoot(container).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
);
