import {OutlinedTextField, Text, type TextFieldRef, useNativeState} from '@expo/ui/jetpack-compose';
import {fillMaxWidth, semantics} from '@expo/ui/jetpack-compose/modifiers';
import {useEffect, useImperativeHandle, useRef} from 'react';
import {AccessibilityInfo} from 'react-native';
import type {TextFieldProps} from '@/components/forms/text-field';

/**
 * A text field as Material 3 draws one: outlined, with its label inside, and its error or hint
 * under it.
 */
export function TextField({
  label,
  error,
  hint,
  defaultValue = '',
  onChangeText,
  onBlur,
  placeholder,
  secureTextEntry = false,
  autoComplete,
  inputMode,
  autoCapitalize,
  autoCorrect,
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
  useEffect(() => {
    if (error !== undefined) {
      AccessibilityInfo.announceForAccessibility(error);
    }
  }, [error]);

  const supportingText = error ?? hint;
  return (
    <OutlinedTextField
      ref={field}
      value={value}
      singleLine
      autoFocus={autoFocus}
      isError={error !== undefined}
      visualTransformation={secureTextEntry ? 'password' : 'none'}
      keyboardOptions={{
        keyboardType: secureTextEntry ? 'password' : inputMode === 'url' ? 'uri' : 'text',
        capitalization: autoCapitalize,
        autoCorrectEnabled: secureTextEntry ? false : autoCorrect,
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
      modifiers={[
        fillMaxWidth(),
        ...(autoComplete === undefined ? [] : [semantics({contentType: autoComplete})]),
      ]}
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
