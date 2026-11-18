import {Icon, ListItem} from '@expo/ui';
import {accessibilityAddTraits, disabled as disable} from '@expo/ui/swift-ui/modifiers';
import type {ReactNode} from 'react';
import {useCSSVariable} from 'uniwind';

/** The options to pick any of, and the ones picked. */
export interface Checks<T> {
  options: ReadonlyArray<{value: T; label: string}>;
  value: readonly T[];
  onChange: (value: T[]) => void;
  disabled?: boolean;
}

/**
 * Returns the rows of a `FieldGroup.Section` that pick any of the options, as the platform's
 * Settings app lists them: checkmarks on iOS, checkboxes on Android. A function rather than a
 * component, as Android's section only draws the rows it's given directly.
 */
export function checkRows<T>(checks: Checks<T>): ReactNode {
  return <CheckmarkRows {...checks} />;
}

/** The options, each a row that toggles it, with a checkmark in the app's color once picked. */
function CheckmarkRows<T>({options, value, onChange, disabled = false}: Checks<T>) {
  const primary = useCSSVariable('--color-primary');
  return options.map(option => {
    const isPicked = value.includes(option.value);
    return (
      <ListItem
        key={option.label}
        trailing={isPicked ? <Icon name="checkmark" size={17} color={String(primary)} /> : null}
        onPress={() => {
          const picked = isPicked
            ? value.filter(each => each !== option.value)
            : [...value, option.value];
          onChange(picked);
        }}
        modifiers={[disable(disabled), accessibilityAddTraits(isPicked ? ['isSelected'] : [])]}
      >
        {option.label}
      </ListItem>
    );
  });
}
