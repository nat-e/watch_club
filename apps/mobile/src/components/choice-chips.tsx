import {Pressable, ScrollView, Text} from 'react-native';

/** The options of `ChoiceChips`, and the one picked. */
interface ChoiceChipsProps<T extends string> {
  /** The purpose of the options, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: T; label: string}>;
  value: T;
  onChange: (value: T) => void;
}

/**
 * A row of pills of which one is picked, such as a search's scopes, drawn like the web app's chips:
 * the picked one pink on a dark pink, the others outlined. It scrolls sideways when they don't fit.
 */
export function ChoiceChips<T extends string>({
  label,
  options,
  value,
  onChange,
}: ChoiceChipsProps<T>) {
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
            className={
              isPicked
                ? 'rounded-full border border-primary-border bg-primary-subtle px-4 py-1.5'
                : 'rounded-full border border-input px-4 py-1.5 active:bg-pressed focus:bg-accent'
            }
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
