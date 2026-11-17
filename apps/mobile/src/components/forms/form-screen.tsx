import {Column, ScrollView, Text} from '@expo/ui';
import {font} from '@expo/ui/swift-ui/modifiers';
import type {ReactNode} from 'react';
import {useCSSVariable} from 'uniwind';
import {Host} from '@/components/host';

/**
 * A screen with a form: an optional description, then its fields and buttons in a column that
 * scrolls, which the platform draws.
 */
export function FormScreen({description, children}: {description?: string; children: ReactNode}) {
  const mutedForeground = useCSSVariable('--color-muted-foreground');
  return (
    <Host style={{flex: 1}}>
      <ScrollView>
        <Column spacing={16} style={{padding: 24, width: '100%'}}>
          {description !== undefined && (
            <Text
              textStyle={{color: String(mutedForeground), fontSize: 17}}
              // iOS sizes it as its body text, with the User's text size
              modifiers={[font({textStyle: 'body'})]}
            >
              {description}
            </Text>
          )}
          {children}
        </Column>
      </ScrollView>
    </Host>
  );
}
