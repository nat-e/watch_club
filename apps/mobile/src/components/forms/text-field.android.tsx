import {OutlinedTextField, Text, type TextFieldRef, useNativeState} from '@expo/ui/jetpack-compose';
import {fillMaxWidth, semantics} from '@expo/ui/jetpack-compose/modifiers';
import {useImperativeHandle, useRef} from 'react';
import type {TextFieldProps} from '@/components/forms/text-field';
import {useAnnouncement} from '@/components/text';

/**
 * A text field as Material 3 draws one: outlined, with its label inside, and its error or hint
 * under it.
 */
export function TextField({
  label,
  purpose,
  error,
  hint,
  defaultValue = '',
  onChangeText,
  onBlur,
  placeholder,
  autoFocus,
  returnKeyType,
  onSubmitEditing,
  ref,
}: TextFieldProps) {
  const value = useNativeState(defaultValue);
  const field = useRef<TextFieldRef>(null);
  useImperativeHandle(ref, () => ({
    focus: () => {
      void field.current?.focus();
    },
  }));
  // Material shows the error itself, rather than through `Feedback`, which announces it elsewhere
  useAnnouncement(error);

  const isPassword = purpose === 'current-password';
  const supportingText = error ?? hint;
  return (
    <OutlinedTextField
      ref={field}
      value={value}
      singleLine
      autoFocus={autoFocus}
      isError={error !== undefined}
      visualTransformation={isPassword ? 'password' : 'none'}
      keyboardOptions={{
        keyboardType: isPassword ? 'password' : purpose === 'url' ? 'uri' : 'text',
        capitalization: 'none',
        autoCorrectEnabled: false,
        imeAction: returnKeyType,
      }}
      keyboardActions={{onNext: onSubmitEditing, onGo: onSubmitEditing}}
      onValueChange={onChangeText}
      onFocusChanged={focused => {
        if (!focused) {
          onBlur?.();
        }
      }}
      // Autofill finds the field by its content type
      modifiers={[fillMaxWidth(), semantics({contentType: purpose})]}
    >
      <OutlinedTextField.Label>
        <Text>{label}</Text>
      </OutlinedTextField.Label>
      {placeholder !== undefined && (
        <OutlinedTextField.Placeholder>
          <Text>{placeholder}</Text>
        </OutlinedTextField.Placeholder>
      )}
      {supportingText !== undefined && (
        <OutlinedTextField.SupportingText>
          <Text>{supportingText}</Text>
        </OutlinedTextField.SupportingText>
      )}
    </OutlinedTextField>
  );
}
