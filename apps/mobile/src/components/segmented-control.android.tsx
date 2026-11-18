import {
  SegmentedButton,
  type SegmentedButtonColors,
  SingleChoiceSegmentedButtonRow,
  Text,
} from '@expo/ui/jetpack-compose';
import {semantics} from '@expo/ui/jetpack-compose/modifiers';
import {useCSSVariable} from 'uniwind';
import {Host} from '@/components/host';
// The iOS file's, which TypeScript reads for both platforms
import type {SegmentedControlProps} from '@/components/segmented-control';

/**
 * A row of options of which one is picked, such as a search's scopes, as Material 3's segmented
 * buttons, drawn like the web app's chips: the picked one pink on a dark pink, the others outlined.
 */
export function SegmentedControl<T extends string>({
  label,
  segments,
  value,
  onChange,
}: SegmentedControlProps<T>) {
  const [primary, primarySubtle, primaryBorder, mutedForeground, input] = useCSSVariable([
    '--color-primary',
    '--color-primary-subtle',
    '--color-primary-border',
    '--color-muted-foreground',
    '--color-input',
  ]).map(color => String(color));
  const colors: SegmentedButtonColors = {
    activeContainerColor: primarySubtle,
    activeContentColor: primary,
    activeBorderColor: primaryBorder,
    inactiveContainerColor: 'transparent',
    inactiveContentColor: mutedForeground,
    inactiveBorderColor: input,
  };
  return (
    <Host matchContents={{vertical: true}}>
      <SingleChoiceSegmentedButtonRow modifiers={[semantics({contentDescription: label})]}>
        {segments.map(segment => (
          <SegmentedButton
            key={segment.value}
            selected={segment.value === value}
            onClick={() => {
              onChange(segment.value);
            }}
            colors={colors}
          >
            <SegmentedButton.Label>
              <Text>{segment.label}</Text>
            </SegmentedButton.Label>
          </SegmentedButton>
        ))}
      </SingleChoiceSegmentedButtonRow>
    </Host>
  );
}
