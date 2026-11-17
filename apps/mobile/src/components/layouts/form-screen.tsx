import {Column, ScrollView} from '@expo/ui';
import type {ReactNode} from 'react';
import {Host} from '@/components/host';
import {Description} from '@/components/text';

/**
 * A screen with a form: an optional description, then its fields and buttons in a column that
 * scrolls, which the platform draws.
 */
export function FormScreen({description, children}: {description?: string; children: ReactNode}) {
  return (
    <Host style={{flex: 1}}>
      <ScrollView>
        <Column spacing={16} style={{padding: 24, width: '100%'}}>
          {description !== undefined && <Description>{description}</Description>}
          {children}
        </Column>
      </ScrollView>
    </Host>
  );
}
