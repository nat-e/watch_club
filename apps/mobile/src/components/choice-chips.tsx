import {Pressable, Text} from 'react-native';
import {ScrollRow} from '@/components/scroll-row';

/** The options of `ChoiceChips`, and the one picked. */
interface ChoiceChipsProps<Value extends string> {
  /** The purpose of the options, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: Value; label: string}>;
  value: Value;
  onChange: (value: Value) => void;
  /**
   * `chip`: a filter, such as a search's scope, the picked one pink and the others outlined.
   * `pill`: a view, such as a TV Show's season, the picked one grey
   */
  variant?: 'chip' | 'pill';
}

/**
 * A row of pills of which one is picked, drawn like the web app's chips or pills. It scrolls
 * sideways when they don't fit.
 */
export function ChoiceChips<Value extends string>({
  label,
  options,
  value,
  onChange,
  variant = 'chip',
}: ChoiceChipsProps<Value>) {
  return (
    <ScrollRow
      accessibilityRole="radiogroup"
      accessibilityLabel={label}
      contentContainerClassName="gap-2 px-4 py-2"
    >
      {options.map(option => {
        const isPicked = option.value === value;
        const classes = variantClasses(variant, isPicked);
        return (
          <Pressable
            key={option.value}
            accessibilityRole="radio"
            accessibilityState={{checked: isPicked}}
            onPress={() => {
              onChange(option.value);
            }}
            // The border shows which one a TV's remote is on, picked or not
            className={`rounded-full border px-4 py-1.5 focus:border-ring ${classes.pill}`}
          >
            <Text className={`text-sm font-semibold ${classes.text}`}>{option.label}</Text>
          </Pressable>
        );
      })}
    </ScrollRow>
  );
}

/** Returns the colors of a chip or a pill, picked or not: its border and background, and its text. */
function variantClasses(variant: 'chip' | 'pill', isPicked: boolean): {pill: string; text: string} {
  if (!isPicked) {
    return {
      pill: `${variant === 'chip' ? 'border-input' : 'border-transparent'} active:bg-pressed focus:bg-accent`,
      text: 'text-muted-foreground',
    };
  }
  switch (variant) {
    case 'chip':
      return {pill: 'border-primary-border bg-primary-subtle', text: 'text-primary'};
    case 'pill':
      return {pill: 'border-transparent bg-selected', text: 'text-foreground'};
  }
}
