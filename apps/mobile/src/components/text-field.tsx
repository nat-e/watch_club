import {useId} from 'react';
import {Text, TextInput, type TextInputProps, View} from 'react-native';

/** A labelled text input, with the error that its value breaks, if any. */
export function TextField({
  label,
  error,
  ...input
}: {label: string; error?: string} & TextInputProps) {
  const labelId = useId();
  return (
    <View className="gap-2">
      <Text nativeID={labelId} className="text-sm font-medium text-foreground">
        {label}
      </Text>
      <TextInput
        accessibilityLabelledBy={labelId}
        accessibilityLabel={label}
        accessibilityHint={error}
        className={`h-11 rounded-lg border bg-muted px-3 text-base text-foreground focus:border-ring ${error === undefined ? 'border-input' : 'border-destructive'}`}
        placeholderTextColorClassName="accent-muted-foreground"
        {...input}
      />
      {error !== undefined && (
        <Text accessibilityLiveRegion="polite" className="text-sm text-destructive">
          {error}
        </Text>
      )}
    </View>
  );
}
