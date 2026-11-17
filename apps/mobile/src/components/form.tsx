/**
 * The mobile app's forms, built with TanStack Form, whose fields the platform draws as the rows of a
 * `FieldGroup.Section`, with their errors under them.
 */
import {FieldGroup, TextInput, type TextInputProps} from '@expo/ui';
import {
  type AnyFieldApi,
  createFormHook,
  type FieldWithValue,
  getFormHookHelpers,
} from '@tanstack/react-form';
import type {ComponentType, ReactNode} from 'react';
import {SectionFeedback} from '@/components/section-feedback';

const {fieldComponent} = getFormHookHelpers();

/** The props of a field's text input, besides those the field sets. */
type FieldInputProps = Omit<TextInputProps, 'value' | 'defaultValue' | 'onChangeText' | 'onBlur'>;

/** A form's field in the platform's text input, as a row of its section. */
function FormTextInput({field, ...input}: {field: FieldWithValue<string>} & FieldInputProps) {
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

/** The first of a field's errors, or else the hint, under its section. */
function FieldFeedback({field, hint}: {field: AnyFieldApi; hint?: string}) {
  return <SectionFeedback error={field.errors[0]?.message} hint={hint} />;
}

/** The form's errors that belong to no field, such as when the server is down, or else the hint. */
function FormFeedback({hint}: {hint?: string}) {
  const form = useFormContext();
  return (
    <form.Subscribe selector={state => state.errors}>
      {errors => <SectionFeedback error={errors[0]?.message} hint={hint} />}
    </form.Subscribe>
  );
}

// biome-ignore-start lint/style/useNamingConvention: the keys name components, as `<form.FormFeedback>`
const formHook = createFormHook({
  fieldComponents: {
    TextInput: fieldComponent.strict(FormTextInput, 'field'),
    Feedback: fieldComponent.loose(FieldFeedback, 'field'),
  },
  formComponents: {FormFeedback},
});
// biome-ignore-end lint/style/useNamingConvention: the keys name components

const {useFormContext} = formHook;

/**
 * Returns the form for the options, which draws its fields with this app's components, such as in
 * `fieldSection` and `<form.FormFeedback>`.
 */
export const useAppForm = formHook.useAppForm;

/** A field of one of this app's forms, with the components that draw it. */
interface SectionField {
  // biome-ignore-start lint/style/useNamingConvention: the keys name components
  TextInput: ComponentType<FieldInputProps>;
  Feedback: ComponentType<{hint?: string}>;
  // biome-ignore-end lint/style/useNamingConvention: the keys name components
}

/**
 * Returns a `FieldGroup.Section` with the field's text input, titled with its label, and its error
 * or hint under it. `bind` renders the form's field: `render => <form.Field name="…">{render}</form.Field>`.
 * A function rather than a component, as Android only draws the sections and footers it's given
 * directly, so the field renders twice: once for the input, once for the error.
 */
export function fieldSection({
  label,
  hint,
  bind,
  ...input
}: {
  label: string;
  hint?: string;
  bind: (render: (field: SectionField) => ReactNode) => ReactNode;
} & FieldInputProps): ReactNode {
  return (
    <FieldGroup.Section title={label}>
      {bind(field => (
        <field.TextInput accessibilityLabel={label} {...input} />
      ))}
      <FieldGroup.SectionFooter>
        {bind(field => (
          <field.Feedback hint={hint} />
        ))}
      </FieldGroup.SectionFooter>
    </FieldGroup.Section>
  );
}
