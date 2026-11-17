import {Picker, Text} from '@expo/ui/swift-ui';
import {disabled as disable, labelsHidden, pickerStyle, tag} from '@expo/ui/swift-ui/modifiers';
import {type ReactNode, useState} from 'react';

/** The options to pick one from, and the one picked. */
export interface Choice<T extends string> {
  /** The name of what's picked, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: T; label: string}>;
  value: T;
  /** Saves the option picked, and rejects when that fails, which the caller shows */
  onChange: (value: T) => Promise<unknown>;
  disabled?: boolean;
}

/**
 * Returns the rows of a `FieldGroup.Section` that pick one of the options, as the platform's
 * Settings app lists them: checkmarks on iOS, radio buttons on Android. A function rather than a
 * component, as Android's section only draws the rows it's given directly.
 */
export function choiceRows<T extends string>(choice: Choice<T>): ReactNode {
  return <InlinePicker {...choice} />;
}

/** SwiftUI's picker, which lists the options in the section with a checkmark on the picked one. */
function InlinePicker<T extends string>({
  label,
  options,
  value,
  onChange,
  disabled = false,
}: Choice<T>) {
  // SwiftUI keeps the option picked even when saving it fails: a new key starts it again from
  // `value`
  const [failures, setFailures] = useState(0);
  return (
    <Picker
      key={failures}
      label={label}
      selection={value}
      onSelectionChange={(picked: T) => {
        onChange(picked).catch(() => {
          setFailures(count => count + 1);
        });
      }}
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
