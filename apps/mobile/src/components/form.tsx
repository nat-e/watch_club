/**
 * The mobile app's forms, built with TanStack Form, whose fields the platform draws as the rows of a
 * `FieldGroup.Section`, with their errors under them.
 */
import {TextInput, type TextInputProps} from '@expo/ui';
import {createFormHook, type FieldWithValue, getFormHookHelpers} from '@tanstack/react-form';
import {Message} from '@/components/message';

const {fieldComponent} = getFormHookHelpers();

/** A form's field in the platform's text input, as a row of its section. */
function FormTextInput({
  field,
  ...input
}: {field: FieldWithValue<string>} & Omit<
  TextInputProps,
  'value' | 'defaultValue' | 'onChangeText' | 'onBlur'
>) {
  return (
    <TextInput
      {...input}
      defaultValue={field.value}
      onChangeText={text => {
        field.handleChange(text);
      }}
      onBlur={field.handleBlur}
    />
  );
}

/** The first of a field's errors, or else the hint, for the footer of its section. */
function FieldMessage({field, hint}: {field: FieldWithValue<string>; hint?: string}) {
  return <Message error={field.errors[0]?.message} hint={hint} />;
}

/** The form's errors that belong to no field, such as when the server is down, or else the hint. */
function FormMessage({hint}: {hint?: string}) {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.errors}>
      {errors => <Message error={errors[0]?.message} hint={hint} />}
    </form.Subscribe>
  );
}

// biome-ignore-start lint/style/useNamingConvention: the keys name components, as `<form.FormMessage>`
const formHook = createFormHook({
  fieldComponents: {
    TextInput: fieldComponent.strict(FormTextInput, 'field'),
    Message: fieldComponent.strict(FieldMessage, 'field'),
  },
  formComponents: {FormMessage},
});
// biome-ignore-end lint/style/useNamingConvention: the keys name components

const {useFormContext} = formHook;

/**
 * Returns the form for the options, which draws its fields and messages with this app's
 * components: `<field.TextInput>`, `<field.Message>` and `<form.FormMessage>`.
 */
export const useAppForm = formHook.useAppForm;
