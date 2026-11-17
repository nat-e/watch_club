import {ListItem} from '@expo/ui';
import {RadioButton} from '@expo/ui/jetpack-compose';
import {selectable} from '@expo/ui/jetpack-compose/modifiers';
import type {ReactNode} from 'react';
import type {Choice} from '@/components/choice-rows';

/**
 * Returns the rows of a `FieldGroup.Section` that pick one of the options, as Android's Settings app
 * lists them: one row per option, with a radio button. A function rather than a component, as the
 * section only draws the rows it's given directly.
 */
export function choiceRows<T extends string>({
  options,
  value,
  onChange,
  disabled = false,
}: Choice<T>): ReactNode {
  return options.map(option => {
    const selected = option.value === value;
    return (
      <ListItem
        key={option.value}
        leading={<RadioButton selected={selected} enabled={!disabled} />}
        // The whole row picks the option, and screen readers announce it as a radio button
        modifiers={
          disabled
            ? []
            : [
                selectable(
                  selected,
                  () => {
                    onChange(option.value);
                  },
                  'radioButton',
                ),
              ]
        }
      >
        {option.label}
      </ListItem>
    );
  });
}
