/**
 * The web app's forms, built with TanStack Form, with the same components as the mobile app's.
 */
import {createFormHook, type FieldWithValue, getFormHookHelpers} from '@tanstack/react-form';
import type {ComponentProps} from 'react';
import {TextField} from '@/components/text-field';
import {Button} from '@/components/ui/button';
import {FieldError} from '@/components/ui/field';

const {fieldComponent} = getFormHookHelpers();

/** Shows a form's field in a text field, with the first of its errors, if any. */
function FormTextField({
  field,
  ...textField
}: {field: FieldWithValue<string>} & Omit<
  ComponentProps<typeof TextField>,
  'name' | 'value' | 'onChange' | 'onBlur' | 'error'
>) {
  return (
    <TextField
      {...textField}
      name={field.name}
      value={field.value}
      onChange={event => {
        field.handleChange(event.target.value);
      }}
      onBlur={field.handleBlur}
      error={field.errors[0]?.message}
    />
  );
}

/** Wraps the fields in a `<form>`, which submits through TanStack Form rather than the browser. */
function Form(props: Omit<ComponentProps<'form'>, 'onSubmit' | 'noValidate'>) {
  const form = useFormContext();
  return (
    <form
      {...props}
      // The fields show the form's errors rather than the browser's
      noValidate
      onSubmit={event => {
        event.preventDefault();
        form.handleSubmit();
      }}
    />
  );
}

/** Shows the form's errors that belong to no field, such as when the server is down. */
function FormError() {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.errors}>
      {errors => <FieldError errors={errors} />}
    </form.Subscribe>
  );
}

/** Shows the button that submits the form, disabled while the form submits. */
function SubmitButton(props: Omit<ComponentProps<typeof Button>, 'type' | 'disabled'>) {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.isSubmitting}>
      {isSubmitting => <Button {...props} type="submit" disabled={isSubmitting} />}
    </form.Subscribe>
  );
}

// biome-ignore-start lint/style/useNamingConvention: the keys name components, as `<form.Form>`
const formHook = createFormHook({
  fieldComponents: {TextField: fieldComponent.strict(FormTextField, 'field')},
  formComponents: {Form, FormError, SubmitButton},
});
// biome-ignore-end lint/style/useNamingConvention: the keys name components

const {useFormContext} = formHook;

/**
 * Returns the form for the options, which draws its fields and buttons with this app's components:
 * `<form.Form>`, `<field.TextField>`, `<form.FormError>` and `<form.SubmitButton>`.
 */
export const useAppForm = formHook.useAppForm;
