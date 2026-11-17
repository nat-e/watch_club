import {createFileRoute, Outlet} from '@tanstack/react-router';

/** The layout of the pages for visitors who aren't signed in: a card in the middle of the page. */
export const Route = createFileRoute('/_signed-out')({
  component: () => (
    <main className="flex min-h-svh items-center justify-center p-6">
      <div className="w-full max-w-md">
        <Outlet />
      </div>
    </main>
  ),
});
