import {Pressable, ScrollView, Text} from 'react-native';

/** The options of `ChoiceChips`, and the one picked. */
interface ChoiceChipsProps<Value extends string> {
  /** The purpose of the options, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: Value; label: string}>;
  value: Value;
  onChange: (value: Value) => void;
}

/**
 * A row of pills of which one is picked, such as a search's scopes, drawn like the web app's chips:
 * the picked one pink on a dark pink, the others outlined. It scrolls sideways when they don't fit.
 */
export function ChoiceChips<Value extends string>({
  label,
  options,
  value,
  onChange,
}: ChoiceChipsProps<Value>) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      accessibilityRole="radiogroup"
      accessibilityLabel={label}
      contentContainerClassName="gap-2 px-4 py-2"
    >
      {options.map(option => {
        const isPicked = option.value === value;
        return (
          <Pressable
            key={option.value}
            accessibilityRole="radio"
            accessibilityState={{checked: isPicked}}
            onPress={() => {
              onChange(option.value);
            }}
            // The border shows which one a TV's remote is on, picked or not
            className={`rounded-full border px-4 py-1.5 focus:border-ring ${
              isPicked
                ? 'border-primary-border bg-primary-subtle'
                : 'border-input active:bg-pressed focus:bg-accent'
            }`}
          >
            <Text
              className={
                isPicked
                  ? 'text-sm font-semibold text-primary'
                  : 'text-sm font-semibold text-muted-foreground'
              }
            >
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}
