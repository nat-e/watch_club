import {Text} from '@expo/ui';
import {useEffect} from 'react';
import {AccessibilityInfo} from 'react-native';
import {useCSSVariable} from 'uniwind';

/**
 * The text under a section's rows: the error, which screen readers announce, or else the hint, or
 * nothing.
 */
export function Message({error, hint}: {error?: string; hint?: string}) {
  const [mutedForeground, destructive] = useCSSVariable([
    '--color-muted-foreground',
    '--color-destructive',
  ]).map(value => String(value));

  useEffect(() => {
    if (error !== undefined) {
      AccessibilityInfo.announceForAccessibility(error);
    }
  }, [error]);

  if (error !== undefined) {
    return <Text textStyle={{color: destructive}}>{error}</Text>;
  }
  if (hint !== undefined) {
    return <Text textStyle={{color: mutedForeground}}>{hint}</Text>;
  }
  return null;
}
