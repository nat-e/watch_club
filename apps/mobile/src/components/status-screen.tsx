import {Button, Column, Text} from '@expo/ui';
import {font} from '@expo/ui/swift-ui/modifiers';
import {Stack} from 'expo-router';
import {ScrollView} from 'react-native';
import {useCSSVariable} from 'uniwind';
import {Host} from '@/components/host';

/** An action of a status screen, as a button. */
interface Action {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}

/**
 * A screen that only says how things stand, such as an error: its title in the header, what to do,
 * and the buttons that do it, the first one filled.
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
  const mutedForeground = useCSSVariable('--color-muted-foreground');

  return (
    <>
      <Stack.Screen options={{headerShown: true, title}} />
      {/* It scrolls when the User's text size makes it taller than the screen */}
      <ScrollView contentContainerClassName="grow justify-center p-6">
        <Host matchContents={{vertical: true}}>
          <Column alignment="center" spacing={16} style={{width: '100%'}}>
            <Text
              textStyle={{color: String(mutedForeground), fontSize: 17, textAlign: 'center'}}
              // iOS sizes it as its body text, with the User's text size
              modifiers={[font({textStyle: 'body'})]}
            >
              {description}
            </Text>
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
    </>
  );
}
