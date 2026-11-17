import {Button as NativeButton} from '@expo/ui';
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
      <NativeButton variant={variant} label={children} disabled={disabled} onPress={onPress} />
    </Host>
  );
}
