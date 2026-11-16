import type {ReactNode} from 'react';
import {ScrollView} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';

/** A screen's scrollable content, clear of the notch and the system bars. */
export function Screen({children}: {children: ReactNode}) {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={['bottom', 'left', 'right']}>
      <ScrollView
        contentContainerClassName="mx-auto w-full max-w-md grow justify-center gap-6 p-6"
        keyboardShouldPersistTaps="handled"
      >
        {children}
      </ScrollView>
    </SafeAreaView>
  );
}
