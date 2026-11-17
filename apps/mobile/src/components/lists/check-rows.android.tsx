import {ListItem} from '@expo/ui';
import {Checkbox} from '@expo/ui/jetpack-compose';
import {toggleable} from '@expo/ui/jetpack-compose/modifiers';
import type {ReactNode} from 'react';
import type {Checks} from '@/components/lists/check-rows';

/**
 * Returns the rows of a `FieldGroup.Section` that pick any of the options, as Android's Settings app
 * lists them: one row per option, with a checkbox. A function rather than a component, as the
 * section only draws the rows it's given directly.
 */
export function checkRows<T>({options, value, onChange, disabled = false}: Checks<T>): ReactNode {
  return options.map(option => {
    const isPicked = value.includes(option.value);
    return (
      <ListItem
        key={option.label}
        leading={<Checkbox value={isPicked} enabled={!disabled} />}
        // The whole row toggles the option, and screen readers announce it as a checkbox
        modifiers={[
          toggleable(
            isPicked,
            () => {
              const picked = isPicked
                ? value.filter(each => each !== option.value)
                : [...value, option.value];
              onChange(picked);
            },
            {role: 'checkbox', enabled: !disabled},
          ),
        ]}
      >
        {option.label}
      </ListItem>
    );
  });
}
