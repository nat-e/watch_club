import {Picker, Text} from '@expo/ui/swift-ui';
import {disabled as disable, labelsHidden, pickerStyle, tag} from '@expo/ui/swift-ui/modifiers';
import type {ReactNode} from 'react';

/** The options to pick one from, and the one picked. */
export interface Choice<T extends string> {
  /** The name of what's picked, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: T; label: string}>;
  value: T;
  onChange: (value: T) => void;
  disabled?: boolean;
}

/**
 * Returns the rows of a `FieldGroup.Section` that pick one of the options, as the platform's
 * Settings app lists them: checkmarks on iOS, radio buttons on Android. A function rather than a
 * component, as Android's section only draws the rows it's given directly.
 */
export function choiceRows<T extends string>({
  label,
  options,
  value,
  onChange,
  disabled = false,
}: Choice<T>): ReactNode {
  return (
    <Picker
      label={label}
      selection={value}
      onSelectionChange={onChange}
      modifiers={[pickerStyle('inline'), labelsHidden(), disable(disabled)]}
    >
      {options.map(option => (
        <Text key={option.value} modifiers={[tag(option.value)]}>
          {option.label}
        </Text>
      ))}
    </Picker>
  );
}
