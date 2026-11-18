import {Icon, ListItem, Row, Text} from '@expo/ui';
import {foregroundStyle} from '@expo/ui/swift-ui/modifiers';
import {type Href, router} from 'expo-router';
import type {ReactNode} from 'react';
import {Platform} from 'react-native';

/**
 * Returns the row of a `FieldGroup.Section` that opens a page, with the value it sets, if any, as
 * the platform's Settings app shows them: on the right before a chevron on iOS, under the label on
 * Android. A function rather than a component, as Android's section only draws the rows it's given
 * directly.
 */
export function linkRow({
  label,
  value,
  href,
}: {
  label: string;
  value?: string;
  href: Href;
}): ReactNode {
  const navigate = () => {
    router.navigate(href);
  };
  if (Platform.OS !== 'ios') {
    return (
      <ListItem supportingText={value} onPress={navigate}>
        {label}
      </ListItem>
    );
  }
  // The colors of the values and chevrons in iOS's Settings app
  return (
    <ListItem
      trailing={
        <Row alignment="center" spacing={6}>
          {value !== undefined && (
            <Text modifiers={[foregroundStyle({type: 'hierarchical', style: 'secondary'})]}>
              {value}
            </Text>
          )}
          <Icon
            name="chevron.right"
            size={14}
            modifiers={[foregroundStyle({type: 'hierarchical', style: 'tertiary'})]}
          />
        </Row>
      }
      onPress={navigate}
    >
      {label}
    </ListItem>
  );
}
