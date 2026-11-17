import type {UniversalHostProps} from '@expo/ui';
import {Host as ComposeHost, type MaterialColors} from '@expo/ui/jetpack-compose';
import type {ReactNode} from 'react';
import {useCSSVariable} from 'uniwind';

/**
 * The root of the platform's own controls from `@expo/ui`, drawn by Material 3 in the app's colors
 * rather than the device's: its pink for actions, its aubergine surfaces and text.
 */
export function Host({
  children,
  ...props
}: Omit<UniversalHostProps, 'colorScheme' | 'seedColor'> & {children: ReactNode}) {
  const [primary, primaryForeground, background, card, muted, foreground, mutedForeground, border] =
    useCSSVariable([
      '--color-primary',
      '--color-primary-foreground',
      '--color-background',
      '--color-card',
      '--color-muted',
      '--color-foreground',
      '--color-muted-foreground',
      '--color-border',
    ]).map(value => color(String(value)));
  return (
    <ComposeHost
      colorScheme="dark"
      colorOverrides={{
        primary,
        onPrimary: primaryForeground,
        surface: background,
        onSurface: foreground,
        surfaceContainer: card,
        // The background of text fields, as the Settings language's
        surfaceContainerHighest: muted,
        onSurfaceVariant: mutedForeground,
        outline: border,
      }}
      {...props}
    >
      {children}
    </ComposeHost>
  );
}

/** Returns the CSS color as a Material color, which the Host converts from any CSS color. */
function color(value: string): MaterialColors['primary'] {
  // biome-ignore lint/nursery/noUnsafeTypeAssertion: the Host converts any React Native color, though its type says hex
  return value as MaterialColors['primary'];
}
