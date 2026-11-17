import type {ReactNode} from 'react';
import {SidebarTrigger} from '@/components/ui/sidebar';

/**
 * A page for signed-in Users: a bar with its title, then its content. On phones, the bar's button
 * slides the sidebar in.
 */
export function Page({title, children}: {title: string; children?: ReactNode}) {
  return (
    <>
      <header className="sticky top-0 z-10 flex h-16 shrink-0 items-center gap-2 border-b bg-background px-page">
        <SidebarTrigger className="md:hidden" />
        <h1 className="truncate text-base font-semibold">{title}</h1>
      </header>
      {/* One column, so a long line of text can't widen the page past the screen */}
      <div className="mx-auto grid w-full max-w-panel flex-1 grid-cols-1 content-start gap-6 px-page py-page-y">
        {children}
      </div>
    </>
  );
}
