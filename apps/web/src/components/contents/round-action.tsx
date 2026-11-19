import {mergeProps} from '@base-ui/react/merge-props';
import {useRender} from '@base-ui/react/use-render';
import type {ReactNode} from 'react';

/**
 * A quiet action beside a Content's main one: its icon in a circle, with its label under it. A
 * button, unless `render` makes it another element, such as a link.
 */
export function RoundAction({
  label,
  icon,
  render,
  ref,
  ...props
}: useRender.ComponentProps<'button'> & {label: string; icon: ReactNode}) {
  return useRender({
    defaultTagName: 'button',
    render,
    ref,
    props: mergeProps<'button'>(
      {
        className:
          'group/action flex w-20 flex-col items-center gap-1 rounded-md text-xs text-muted-foreground outline-none focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50',
        children: (
          <>
            <span className="grid size-12 place-items-center rounded-full border bg-secondary text-foreground transition-colors group-hover/action:bg-accent group-active/action:bg-pressed [&_svg]:size-5">
              {icon}
            </span>
            {label}
          </>
        ),
      },
      props,
    ),
  });
}
