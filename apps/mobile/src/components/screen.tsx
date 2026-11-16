import {useHeaderHeight} from 'expo-router/react-navigation';
import type {ReactNode} from 'react';
import {KeyboardAvoidingView, ScrollView} from 'react-native';
import {SafeAreaView as SafeArea} from 'react-native-safe-area-context';
import {withUniwind} from 'uniwind';

// Uniwind styles React Native's own components, and others once wrapped
const SafeAreaView = withUniwind(SafeArea);

/**
 * A screen's scrollable content, centered and clear of the notch, the system bars and the keyboard.
 */
export function Screen({children}: {children: ReactNode}) {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={['bottom', 'left', 'right']}>
      {/* The keyboard covers the app on both platforms: this leaves it room below the content */}
      <KeyboardAvoidingView
        behavior="padding"
        keyboardVerticalOffset={useHeaderHeight()}
        className="flex-1"
      >
        <ScrollView
          contentContainerClassName="mx-auto w-full max-w-md grow justify-center gap-6 p-6"
          keyboardShouldPersistTaps="handled"
        >
          {children}
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
