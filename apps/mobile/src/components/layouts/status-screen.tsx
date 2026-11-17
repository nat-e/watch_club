import {Button, Column} from '@expo/ui';
import {Text as ReactNativeText, ScrollView} from 'react-native';
import {Host} from '@/components/host';
import {Description} from '@/components/text';

/** An action of a status screen, as a button. */
interface Action {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}

/**
 * A screen that only says how things stand, such as an error: its title, what to do, and the
 * buttons that do it, the first one filled.
 */
export function StatusScreen({
  title,
  description,
  actions,
}: {
  title: string;
  description: string;
  actions: readonly Action[];
}) {
  return (
    // It scrolls when the User's text size makes it taller than the screen
    <ScrollView contentContainerClassName="grow justify-center gap-4 p-6">
      {/* React Native's text, as @expo/ui's can't be a heading for Android's screen readers */}
      <ReactNativeText
        accessibilityRole="header"
        className="text-center text-3xl font-semibold text-foreground"
      >
        {title}
      </ReactNativeText>
      <Host matchContents={{vertical: true}}>
        <Column alignment="center" spacing={16} style={{width: '100%'}}>
          <Description centered>{description}</Description>
          {actions.map(({label, onPress, disabled}, index) => (
            <Button
              key={label}
              variant={index === 0 ? 'filled' : 'outlined'}
              label={label}
              onPress={onPress}
              disabled={disabled}
            />
          ))}
        </Column>
      </Host>
    </ScrollView>
  );
}
