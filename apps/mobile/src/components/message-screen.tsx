import {Button, Column, Spacer, Text} from '@expo/ui';
import {useCSSVariable} from 'uniwind';
import {Host} from '@/components/host';

/** An action of a message screen, as a button. */
interface Action {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}

/**
 * A screen with only a message, such as an error, drawn by the platform: its title, what to do,
 * and the buttons that do it, the first one filled.
 */
export function MessageScreen({
  title,
  description,
  actions,
}: {
  title: string;
  description: string;
  actions: readonly Action[];
}) {
  const [foreground, mutedForeground] = useCSSVariable([
    '--color-foreground',
    '--color-muted-foreground',
  ]).map(value => String(value));

  return (
    <Host style={{flex: 1}}>
      <Column alignment="center" spacing={16} style={{padding: 24, height: '100%'}}>
        <Spacer flexible />
        <Text
          textStyle={{color: foreground, fontSize: 28, fontWeight: 'bold', textAlign: 'center'}}
        >
          {title}
        </Text>
        <Text textStyle={{color: mutedForeground, fontSize: 17, textAlign: 'center'}}>
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
        <Spacer flexible />
      </Column>
    </Host>
  );
}
