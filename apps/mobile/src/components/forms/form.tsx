/**
 * The mobile app's forms, built with TanStack Form, whose fields and buttons the platform draws.
 */
import {Button, Text} from '@expo/ui';
import {fillMaxWidth} from '@expo/ui/jetpack-compose/modifiers';
import {controlSize, frame} from '@expo/ui/swift-ui/modifiers';
import {
  createFormHook,
  type FieldWithValue,
  getFormHookHelpers,
  useSelector,
} from '@tanstack/react-form';
import {Feedback} from '@/components/forms/feedback';
import {TextField, type TextFieldProps} from '@/components/forms/text-field';

const {fieldComponent} = getFormHookHelpers();

/** A form's field in a text field, with the first of its errors, or else the hint. */
function FormTextField({
  field,
  ...textField
}: {field: FieldWithValue<string>} & Omit<
  TextFieldProps,
  'error' | 'defaultValue' | 'onChangeText' | 'onBlur'
>) {
  return (
    <TextField
      {...textField}
      error={field.errors[0]?.message}
      defaultValue={field.value}
      onChangeText={text => {
        field.handleChange(text);
      }}
      onBlur={field.handleBlur}
    />
  );
}

/** The form's errors that belong to no field, such as when the server is down, or else the hint. */
function FormFeedback({hint}: {hint?: string}) {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.errors}>
      {errors => <Feedback error={errors[0]?.message} hint={hint} />}
    </form.Subscribe>
  );
}

/** The button that submits the form, large and as wide as the form, and disabled meanwhile. */
function SubmitButton({children}: {children: string}) {
  const form = useFormContext();
  const isSubmitting = useSelector(form.atom, state => state.isSubmitting);
  return (
    <Button
      variant="filled"
      disabled={isSubmitting}
      onPress={() => {
        void form.handleSubmit();
      }}
      // Each platform reads its own modifiers
      modifiers={[fillMaxWidth(), controlSize('large')]}
    >
      {/* SwiftUI sizes a button to its label, so the label takes the whole width */}
      <Text modifiers={[frame({maxWidth: Number.POSITIVE_INFINITY})]}>{children}</Text>
    </Button>
  );
}

// biome-ignore-start lint/style/useNamingConvention: the keys name components, as `<form.SubmitButton>`
const formHook = createFormHook({
  fieldComponents: {TextField: fieldComponent.strict(FormTextField, 'field')},
  formComponents: {FormFeedback, SubmitButton},
});
// biome-ignore-end lint/style/useNamingConvention: the keys name components

const {useFormContext} = formHook;

/**
 * Returns the form for the options, which draws its fields and buttons with this app's
 * components: `<field.TextField>`, `<form.SubmitButton>` and `<form.FormFeedback>`.
 */
export const useAppForm = formHook.useAppForm;
