import {type ComponentProps, useId} from 'react';
import {Field, FieldDescription, FieldError, FieldLabel} from '@/components/ui/field';
import {Input} from '@/components/ui/input';

/** A labelled text input, with an optional hint and an optional error message. */
export function TextField({
  label,
  hint,
  error,
  ...input
}: {
  label: string;
  /** What the field takes, under the input */
  hint?: string;
  error?: string;
} & Omit<
  ComponentProps<typeof Input>,
  // It sets them itself, to tie the label, the hint and the error to the input
  'id' | 'aria-invalid' | 'aria-describedby'
>) {
  const id = useId();
  const hintId = useId();
  const errorId = useId();
  const describedBy = [hint === undefined ? null : hintId, error === undefined ? null : errorId]
    .filter(each => each !== null)
    .join(' ');
  return (
    <Field data-invalid={error !== undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <Input
        id={id}
        aria-invalid={error !== undefined}
        aria-describedby={describedBy === '' ? undefined : describedBy}
        {...input}
      />
      {hint !== undefined && <FieldDescription id={hintId}>{hint}</FieldDescription>}
      <FieldError id={errorId}>{error}</FieldError>
    </Field>
  );
}
