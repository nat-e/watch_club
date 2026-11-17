import {Host as NativeHost, type UniversalHostProps} from '@expo/ui';
import type {ReactNode} from 'react';
import {useCSSVariable} from 'uniwind';

/**
 * The root of the platform's own controls from `@expo/ui`, drawn dark. On iOS, the app's pink tints
 * SwiftUI's controls; Android has its own file.
 */
export function Host({
  children,
  ...props
}: Omit<UniversalHostProps, 'colorScheme' | 'seedColor'> & {children: ReactNode}) {
  const primary = useCSSVariable('--color-primary');
  return (
    <NativeHost colorScheme="dark" seedColor={String(primary)} {...props}>
      {children}
    </NativeHost>
  );
}
