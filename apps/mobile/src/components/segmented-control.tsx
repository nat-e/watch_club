import {Picker, Text} from '@expo/ui/swift-ui';
import {createModifier, pickerStyle, tag} from '@expo/ui/swift-ui/modifiers';
import {useCSSVariable} from 'uniwind';
import {Host} from '@/components/host';

/** The options of a `SegmentedControl`, and the one picked. */
export interface SegmentedControlProps<T extends string> {
  /** What the options pick, which screen readers announce */
  label: string;
  segments: ReadonlyArray<{value: T; label: string}>;
  value: T;
  onChange: (value: T) => void;
}

/**
 * A row of options of which one is picked, such as a search's scopes, as iOS draws it, with the
 * picked one in the app's pink. Android has its own file.
 */
export function SegmentedControl<T extends string>({
  label,
  segments,
  value,
  onChange,
}: SegmentedControlProps<T>) {
  // The darkest pink of the theme that white text stays readable on, as iOS keeps the text white
  const primaryBorder = useCSSVariable('--color-primary-border');
  return (
    <Host matchContents={{vertical: true}}>
      <Picker
        label={label}
        selection={value}
        onSelectionChange={onChange}
        modifiers={[
          pickerStyle('segmented'),
          // SwiftUI can't tint a segmented picker: `@expo/ui` sets it on UIKit's control behind it
          createModifier('selectedSegmentTintColor', {color: String(primaryBorder)}),
        ]}
      >
        {segments.map(segment => (
          <Text key={segment.value} modifiers={[tag(segment.value)]}>
            {segment.label}
          </Text>
        ))}
      </Picker>
    </Host>
  );
}
