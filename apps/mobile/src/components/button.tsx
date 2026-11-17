import {Button as NativeButton, Text} from '@expo/ui';
import {frame} from '@expo/ui/swift-ui/modifiers';
import {Host} from '@/components/host';

/** A button the platform draws, labelled with text, as wide as the content around it. */
export function Button({
  variant = 'filled',
  children,
  disabled,
  onPress,
}: {
  variant?: 'filled' | 'outlined';
  children: string;
  disabled?: boolean;
  onPress: () => void;
}) {
  return (
    <Host matchContents={{vertical: true}}>
      <NativeButton variant={variant} disabled={disabled} onPress={onPress}>
        {/* SwiftUI sizes a button to its label, so the label takes the whole width */}
        <Text modifiers={[frame({maxWidth: Number.POSITIVE_INFINITY})]}>{children}</Text>
      </NativeButton>
    </Host>
  );
}
