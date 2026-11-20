import {useId} from 'react';
import {Field, FieldDescription, FieldError, FieldLabel} from '@/components/ui/field';
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

/**
 * A labelled list to choose one of the options from, which shows the chosen one, with an optional
 * hint below it and an optional error message.
 */
export function SelectField<T>({
  label,
  description,
  error,
  disabled = false,
  options,
  value,
  onChange,
}: {
  label: string;
  description?: string;
  error?: string;
  disabled?: boolean;
  options: ReadonlyArray<Option<T>>;
  value: T;
  onChange: (value: T) => void;
}) {
  const id = useId();
  const descriptionId = useId();
  const errorId = useId();
  const describedBy = [
    description === undefined ? undefined : descriptionId,
    error === undefined ? undefined : errorId,
  ].filter(each => each !== undefined);
  return (
    <Field data-invalid={error !== undefined} data-disabled={disabled}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      {/* The options themselves are the values, so that any value works, even null, which the
          select would take for no choice */}
      <Select
        value={options.find(option => option.value === value) ?? null}
        disabled={disabled}
        isItemEqualToValue={(item, chosen) => item.value === chosen.value}
        itemToStringValue={option => String(option.value)}
        onValueChange={option => {
          if (option) {
            onChange(option.value);
          }
        }}
      >
        <SelectTrigger
          id={id}
          className="w-full"
          aria-invalid={error !== undefined}
          aria-describedby={describedBy.length === 0 ? undefined : describedBy.join(' ')}
        >
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
      {description !== undefined && (
        <FieldDescription id={descriptionId}>{description}</FieldDescription>
      )}
      <FieldError id={errorId}>{error}</FieldError>
    </Field>
  );
}
