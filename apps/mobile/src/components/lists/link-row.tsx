import {Icon, ListItem} from '@expo/ui';
import {foregroundStyle} from '@expo/ui/swift-ui/modifiers';
import {type Href, router} from 'expo-router';
import type {ReactNode} from 'react';
import {Platform} from 'react-native';

/**
 * Returns the row of a `FieldGroup.Section` that opens a page, which iOS marks with a chevron, as
 * its Settings app does, and Android doesn't. A function rather than a component, as Android's
 * section only draws the rows it's given directly.
 */
export function linkRow({label, href}: {label: string; href: Href}): ReactNode {
  return (
    <ListItem
      trailing={
        Platform.OS === 'ios' ? (
          <Icon
            name="chevron.right"
            size={14}
            // The color of the chevrons in iOS's Settings app
            modifiers={[foregroundStyle({type: 'hierarchical', style: 'tertiary'})]}
          />
        ) : null
      }
      onPress={() => {
        router.navigate(href);
      }}
    >
      {label}
    </ListItem>
  );
}
