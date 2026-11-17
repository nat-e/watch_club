import {Text} from '@expo/ui';
import {font} from '@expo/ui/swift-ui/modifiers';
import {useEffect} from 'react';
import {AccessibilityInfo} from 'react-native';
import {useCSSVariable} from 'uniwind';

/**
 * The text that says what a screen is for or what to do, in the platform's body size and the
 * muted color.
 */
export function Description({children, centered = false}: {children: string; centered?: boolean}) {
  const mutedForeground = useCSSVariable('--color-muted-foreground');
  return (
    <Text
      textStyle={{
        color: String(mutedForeground),
        fontSize: 17,
        textAlign: centered ? 'center' : undefined,
      }}
      // iOS sizes it as its body text, with the User's text size
      modifiers={[font({textStyle: 'body'})]}
    >
      {children}
    </Text>
  );
}

/**
 * The text under a field or a section: the error, which screen readers announce, or else the hint,
 * or nothing.
 */
export function Feedback({error, hint}: {error?: string; hint?: string}) {
  const [mutedForeground, destructive] = useCSSVariable([
    '--color-muted-foreground',
    '--color-destructive',
  ]).map(value => String(value));
  useAnnouncement(error);

  const text = error ?? hint;
  if (text === undefined) {
    return null;
  }
  return (
    <Text
      textStyle={{color: error === undefined ? mutedForeground : destructive, fontSize: 13}}
      // iOS sizes it as its footnotes, with the User's text size
      modifiers={[font({textStyle: 'footnote'})]}
    >
      {text}
    </Text>
  );
}

/**
 * Has screen readers read the text out each time it appears or changes, as an error that shows
 * where the User isn't looking.
 */
export function useAnnouncement(text?: string) {
  useEffect(() => {
    if (text !== undefined) {
      AccessibilityInfo.announceForAccessibility(text);
    }
  }, [text]);
}
