import type {ReactNode} from 'react';
import {Pressable, type PressableProps, Text} from 'react-native';

const VARIANTS = {
  primary: {
    button: 'bg-primary active:opacity-80',
    text: 'text-primary-foreground',
  },
  outline: {
    button: 'border border-border active:bg-accent',
    text: 'text-foreground',
  },
} as const;

/** Shows a button labelled with text, whose focus ring shows where the remote is on TVs. */
export function Button({
  variant = 'primary',
  children,
  ...pressable
}: {variant?: keyof typeof VARIANTS; children: ReactNode} & Omit<PressableProps, 'children'>) {
  const {button, text} = VARIANTS[variant];
  return (
    <Pressable
      accessibilityRole="button"
      className={`h-11 items-center justify-center rounded-lg px-4 focus:ring-2 focus:ring-ring disabled:opacity-50 ${button}`}
      {...pressable}
    >
      <Text className={`text-base font-medium ${text}`}>{children}</Text>
    </Pressable>
  );
}
