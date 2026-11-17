import {Toaster as SonnerToaster} from 'sonner-native';
import {useCSSVariable} from 'uniwind';

/**
 * The toasts that confirm what the User did, such as saving their preferences, in the colors of the
 * web app's: show one with `toast.success` from `sonner-native`.
 */
export function Toaster() {
  const [popover, popoverForeground, border] = useCSSVariable([
    '--color-popover',
    '--color-popover-foreground',
    '--color-border',
  ]).map(value => String(value));
  return (
    <SonnerToaster
      // WatchClub is dark only
      theme="dark"
      toastOptions={{
        style: {backgroundColor: popover, borderColor: border, borderWidth: 1},
        titleStyle: {color: popoverForeground},
      }}
    />
  );
}
