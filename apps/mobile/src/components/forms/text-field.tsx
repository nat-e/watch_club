import {Column, Text, TextInput, type TextInputRef} from '@expo/ui';
import {font, textFieldStyle} from '@expo/ui/swift-ui/modifiers';
import {type Ref, useImperativeHandle, useRef} from 'react';
import {useCSSVariable} from 'uniwind';
import {Feedback} from '@/components/forms/feedback';

/** A text field that the keyboard's next key can move to. */
export interface FocusableField {
  focus: () => void;
}

/** A labelled text field, with its error or hint, and the keyboard it needs. */
export interface TextFieldProps {
  label: string;
  error?: string;
  hint?: string;
  defaultValue?: string;
  onChangeText: (text: string) => void;
  onBlur?: () => void;
  placeholder?: string;
  secureTextEntry?: boolean;
  autoComplete?: 'url' | 'username' | 'current-password';
  inputMode?: 'url';
  autoCapitalize?: 'none';
  autoCorrect?: boolean;
  autoFocus?: boolean;
  returnKeyType?: 'next' | 'go';
  onSubmitEditing?: () => void;
  ref?: Ref<FocusableField>;
}

/**
 * A text field as iOS draws one outside a list: its label above a rounded field, and its error or
 * hint under it. Android has its own file.
 */
export function TextField({label, error, hint, ref, ...input}: TextFieldProps) {
  const foreground = useCSSVariable('--color-foreground');
  const field = useRef<TextInputRef>(null);
  useImperativeHandle(ref, () => ({
    focus: () => {
      field.current?.focus();
    },
  }));

  return (
    <Column spacing={6} style={{width: '100%'}}>
      <Text
        textStyle={{color: String(foreground), fontSize: 15, fontWeight: '500'}}
        modifiers={[font({textStyle: 'subheadline', weight: 'medium'})]}
      >
        {label}
      </Text>
      <TextInput
        ref={field}
        accessibilityLabel={label}
        modifiers={[textFieldStyle('roundedBorder')]}
        {...input}
      />
      <Feedback error={error} hint={hint} />
    </Column>
  );
}
