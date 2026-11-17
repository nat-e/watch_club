import {FieldGroup} from '@expo/ui';
import type {ReactNode} from 'react';
import {Host} from '@/components/host';

/**
 * A screen of grouped rows the platform draws, as in its Settings app: a SwiftUI `Form` on iOS,
 * Material 3 rows on Android. Its children are `FieldGroup.Section`s.
 */
export function ListScreen({children}: {children: ReactNode}) {
  return (
    <Host style={{flex: 1}}>
      <FieldGroup>{children}</FieldGroup>
    </Host>
  );
}
