import {useId} from 'react';
import {Field, FieldLabel} from '@/components/ui/field';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

/** An option to choose, with its name. */
interface Option<T> {
  value: T;
  label: string;
}

/** A labelled list to choose one of the options from, which shows the chosen one. */
export function SelectField<T>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: ReadonlyArray<Option<T>>;
  value: T;
  onChange: (value: T) => void;
}) {
  const id = useId();
  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      {/* The options themselves are the values, so that any value works, even null, which the
          select would take for no choice */}
      <Select
        value={options.find(option => option.value === value) ?? null}
        isItemEqualToValue={(item, chosen) => item.value === chosen.value}
        itemToStringValue={option => String(option.value)}
        onValueChange={option => {
          if (option) {
            onChange(option.value);
          }
        }}
      >
        <SelectTrigger id={id} className="w-full">
          <SelectValue />
        </SelectTrigger>
        {/* Below the field, rather than over it with the chosen option on the field's value */}
        <SelectContent alignItemWithTrigger={false}>
          {options.map(option => (
            <SelectItem key={option.label} value={option}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  );
}
