import {Text} from '@expo/ui';
import {font} from '@expo/ui/swift-ui/modifiers';
import {useEffect} from 'react';
import {AccessibilityInfo} from 'react-native';
import {useCSSVariable} from 'uniwind';

/**
 * The text under a section's rows: the error, which screen readers announce, or else the hint, or
 * nothing.
 */
export function SectionFeedback({error, hint}: {error?: string; hint?: string}) {
  const [mutedForeground, destructive] = useCSSVariable([
    '--color-muted-foreground',
    '--color-destructive',
  ]).map(value => String(value));

  useEffect(() => {
    if (error !== undefined) {
      AccessibilityInfo.announceForAccessibility(error);
    }
  }, [error]);

  const text = error ?? hint;
  if (text === undefined) {
    return null;
  }
  return (
    <Text
      textStyle={{color: error === undefined ? mutedForeground : destructive}}
      // iOS sizes it as its footers, with the User's text size
      modifiers={[font({textStyle: 'footnote'})]}
    >
      {text}
    </Text>
  );
}
