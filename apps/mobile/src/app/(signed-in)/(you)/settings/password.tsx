import {
  PASSWORD_MIN_LENGTH,
  useChangePasswordFormOptions,
} from '@watchclub/core/accounts/passwords';
import {useNavigation} from 'expo-router';
import {useRef} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner-native';
import {useAppForm} from '@/components/forms/form';
import type {FocusableField} from '@/components/forms/text-field';
import {FormScreen} from '@/components/layouts/form-screen';

/**
 * The form that changes the User's password with their current one, which signs them out on their
 * other devices. It goes back to Settings once the password changed.
 */
export default function Password() {
  const {t} = useTranslation('core');
  const navigation = useNavigation();
  // The keyboard's next key moves from one field to the next
  const newPasswordInput = useRef<FocusableField>(null);
  const confirmationInput = useRef<FocusableField>(null);
  const form = useAppForm(
    useChangePasswordFormOptions(() => {
      toast.success(t($ => $.core.settings.passwordUpdated));
      // Unless the User already left
      if (navigation.isFocused()) {
        navigation.goBack();
      }
    }),
  );

  return (
    <FormScreen description={t($ => $.core.settings.securityDescription)}>
      <form.Field name="currentPassword">
        {field => (
          <field.TextField
            label={t($ => $.core.password.currentPassword)}
            purpose="current-password"
            autoFocus
            returnKeyType="next"
            onSubmitEditing={() => {
              newPasswordInput.current?.focus();
            }}
          />
        )}
      </form.Field>
      <form.Field name="newPassword">
        {field => (
          <field.TextField
            ref={newPasswordInput}
            label={t($ => $.core.password.newPassword)}
            hint={t($ => $.core.password.hint, {min: PASSWORD_MIN_LENGTH})}
            purpose="new-password"
            returnKeyType="next"
            onSubmitEditing={() => {
              confirmationInput.current?.focus();
            }}
          />
        )}
      </form.Field>
      <form.Field name="passwordConfirmation">
        {field => (
          <field.TextField
            ref={confirmationInput}
            label={t($ => $.core.password.confirmPassword)}
            purpose="new-password"
            returnKeyType="go"
            onSubmitEditing={() => {
              void form.handleSubmit();
            }}
          />
        )}
      </form.Field>
      <form.AppForm>
        <form.SubmitButton>{t($ => $.core.settings.updatePassword)}</form.SubmitButton>
        <form.FormFeedback />
      </form.AppForm>
    </FormScreen>
  );
}
