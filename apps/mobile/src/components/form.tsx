/**
 * The mobile app's forms, built with TanStack Form, whose components have the web app's names.
 */
import {createFormHook, type FieldWithValue, getFormHookHelpers} from '@tanstack/react-form';
import type {ComponentProps} from 'react';
import {Text} from 'react-native';
import {TextField} from '@/components/text-field';

const {fieldComponent} = getFormHookHelpers();

/** Shows a form's field in a text field, with the first of its errors, if any. */
function FormTextField({
  field,
  ...textField
}: {field: FieldWithValue<string>} & Omit<
  ComponentProps<typeof TextField>,
  'value' | 'onChangeText' | 'onBlur' | 'error'
>) {
  return (
    <TextField
      {...textField}
      value={field.value}
      onChangeText={text => {
        field.handleChange(text);
      }}
      onBlur={field.handleBlur}
      error={field.errors[0]?.message}
    />
  );
}

/** Shows the form's errors that belong to no field, such as when the server is down. */
function FormError() {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.errors}>
      {errors =>
        errors.map(error => (
          <Text key={error.message} accessibilityLiveRegion="polite" className="text-destructive">
            {error.message}
          </Text>
        ))
      }
    </form.Subscribe>
  );
}

// biome-ignore-start lint/style/useNamingConvention: the keys name components, as `<form.FormError>`
const formHook = createFormHook({
  fieldComponents: {TextField: fieldComponent.strict(FormTextField, 'field')},
  formComponents: {FormError},
});
// biome-ignore-end lint/style/useNamingConvention: the keys name components

const {useFormContext} = formHook;

/**
 * Returns the form for the options, which draws its fields and buttons with this app's components:
 * `<field.TextField>` and `<form.FormError>`.
 */
export const useAppForm = formHook.useAppForm;
