import {type ComponentProps, useId} from 'react';
import {Field, FieldError, FieldLabel} from '@/components/ui/field';
import {Input} from '@/components/ui/input';

/** A labelled text input, with an optional error message. */
export function TextField({
  label,
  error,
  ...input
}: {label: string; error?: string} & Omit<
  ComponentProps<typeof Input>,
  // It sets them itself, to tie the label and the error to the input
  'id' | 'aria-invalid' | 'aria-describedby'
>) {
  const id = useId();
  const errorId = useId();
  return (
    <Field data-invalid={error !== undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <Input
        id={id}
        aria-invalid={error !== undefined}
        aria-describedby={error === undefined ? undefined : errorId}
        {...input}
      />
      <FieldError id={errorId}>{error}</FieldError>
    </Field>
  );
}
