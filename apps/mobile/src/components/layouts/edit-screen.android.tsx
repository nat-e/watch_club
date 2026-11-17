import closeIcon from '@expo/material-symbols/close.xml';
import {Button, Text} from '@expo/ui';
import {Stack, useNavigation} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {Host} from '@/components/host';
import type {EditScreenProps} from '@/components/layouts/edit-screen';
import {ListScreen} from '@/components/layouts/list-screen';

/**
 * A screen of grouped rows that edit a draft, as Android presents a full-screen editor: × on the
 * left and Save on the right of its top bar. Save saves the draft and closes the screen; ×, or going
 * back, drops it. Its route opens it with `presentation: 'modal'`.
 */
export function EditScreen({save, isSaving, children}: EditScreenProps) {
  const {t} = useTranslation(['mobile', 'core']);
  const navigation = useNavigation();
  // Unless the User already left, such as by going back while it saved
  const close = () => {
    if (navigation.isFocused()) {
      navigation.goBack();
    }
  };

  return (
    <>
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button
          icon={closeIcon}
          accessibilityLabel={t($ => $.core.controls.close)}
          onPress={close}
        />
      </Stack.Toolbar>
      {/* A text button, as the toolbar's own buttons only show icons on Android */}
      <Stack.Toolbar placement="right" asChild>
        <Host matchContents>
          <Button
            variant="text"
            disabled={isSaving}
            onPress={() => {
              save().then(close, () => {
                // The caller shows the failure, and the screen stays open
              });
            }}
          >
            <Text>{t($ => $.core.settings.save)}</Text>
          </Button>
        </Host>
      </Stack.Toolbar>
      <ListScreen>{children}</ListScreen>
    </>
  );
}
