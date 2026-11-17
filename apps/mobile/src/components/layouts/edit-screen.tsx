import {Stack, useNavigation} from 'expo-router';
import type {ReactNode} from 'react';
import {useTranslation} from 'react-i18next';
import {ListScreen} from '@/components/layouts/list-screen';

/** The draft an `EditScreen` edits, and how it saves it. */
export interface EditScreenProps {
  /** Saves the draft, and rejects when that fails, which the caller shows */
  save: () => Promise<unknown>;
  /** Whether a save is running, which disables saving again */
  isSaving: boolean;
  /** The `FieldGroup.Section`s that edit the draft */
  children: ReactNode;
}

/**
 * A screen of grouped rows that edit a draft, as iOS presents a short task: a sheet with Cancel and
 * Done. Done saves the draft and closes the sheet; Cancel, or swiping the sheet down, drops it. Its
 * route opens it with `presentation: 'modal'`.
 */
export function EditScreen({save, isSaving, children}: EditScreenProps) {
  const {t} = useTranslation('mobile');
  const navigation = useNavigation();
  // Unless the User already left, such as by swiping the sheet down while it saved
  const close = () => {
    if (navigation.isFocused()) {
      navigation.goBack();
    }
  };

  return (
    <>
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button onPress={close}>
          {t($ => $.mobile.editScreen.cancel)}
        </Stack.Toolbar.Button>
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          variant="done"
          disabled={isSaving}
          onPress={() => {
            save().then(close, () => {
              // The caller shows the failure, and the sheet stays open
            });
          }}
        >
          {t($ => $.mobile.editScreen.done)}
        </Stack.Toolbar.Button>
      </Stack.Toolbar>
      <ListScreen>{children}</ListScreen>
    </>
  );
}
