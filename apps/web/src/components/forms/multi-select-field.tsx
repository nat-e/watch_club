import {useId} from 'react';
import * as combobox from '@/components/ui/combobox';
import {Field, FieldDescription, FieldLabel} from '@/components/ui/field';

/** An option to choose, with its name. */
interface Option<T> {
  value: T;
  label: string;
}

/**
 * A labelled field to choose any of the options, which shows each chosen one as a chip, in the
 * options' order, and filters the options as the User types.
 */
export function MultiSelectField<T>({
  label,
  description,
  placeholder,
  noMatch,
  options,
  value,
  onChange,
}: {
  label: string;
  description: string;
  /** The text in the input, which says what typing does */
  placeholder: string;
  /** The text that says no option matches what the User typed */
  noMatch: string;
  options: ReadonlyArray<Option<T>>;
  value: readonly T[];
  onChange: (value: T[]) => void;
}) {
  const id = useId();
  const descriptionId = useId();
  const anchor = combobox.useComboboxAnchor();
  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <combobox.Combobox
        multiple
        autoHighlight
        items={options}
        value={options.filter(option => value.includes(option.value))}
        isItemEqualToValue={(item, chosen) => item.value === chosen.value}
        onValueChange={chosen => {
          const isChosen = (option: Option<T>) => chosen.some(each => each.value === option.value);
          onChange(options.filter(isChosen).map(option => option.value));
        }}
      >
        <combobox.ComboboxChips ref={anchor}>
          <combobox.ComboboxValue>
            {(chosen: Array<Option<T>>) => (
              <>
                {chosen.map(option => (
                  <combobox.ComboboxChip key={option.label}>{option.label}</combobox.ComboboxChip>
                ))}
                <combobox.ComboboxChipsInput
                  id={id}
                  aria-describedby={descriptionId}
                  placeholder={placeholder}
                />
              </>
            )}
          </combobox.ComboboxValue>
        </combobox.ComboboxChips>
        <combobox.ComboboxContent anchor={anchor}>
          <combobox.ComboboxEmpty>{noMatch}</combobox.ComboboxEmpty>
          <combobox.ComboboxList>
            {(option: Option<T>) => (
              <combobox.ComboboxItem key={option.label} value={option}>
                {option.label}
              </combobox.ComboboxItem>
            )}
          </combobox.ComboboxList>
        </combobox.ComboboxContent>
      </combobox.Combobox>
      <FieldDescription id={descriptionId}>{description}</FieldDescription>
    </Field>
  );
}
