import type {ReactNode} from 'react';
import {SidebarTrigger} from '@/components/ui/sidebar';

/**
 * A page for signed-in Users: a bar with its title, then its content. On phones, the bar's button
 * slides the sidebar in.
 */
export function Page({title, children}: {title: string; children?: ReactNode}) {
  return (
    <>
      <header className="sticky top-0 z-10 flex h-12 shrink-0 items-center gap-2 border-b bg-background px-3 md:px-6">
        <SidebarTrigger className="md:hidden" />
        <h1 className="truncate font-heading text-base font-semibold">{title}</h1>
      </header>
      <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 p-6">{children}</div>
    </>
  );
}
