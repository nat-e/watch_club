import {FieldGroup} from '@expo/ui';
import {useNavigation} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {ListScreen} from '@/components/layouts/list-screen';
import {choiceRows} from '@/components/lists/choice-rows';
import {Feedback} from '@/components/text';

/** The setting a `ChoiceScreen` changes, and how it saves it. */
interface ChoiceScreenProps<T> {
  /** The setting's name, which screen readers announce */
  label: string;
  options: ReadonlyArray<{value: T; label: string}>;
  value: T;
  /** Saves the option picked, and rejects when that fails */
  save: (value: T) => Promise<unknown>;
  /** Whether a save is running, which disables the options */
  isSaving: boolean;
  /** Whether the last save failed, which the screen says */
  hasFailed: boolean;
  /** The text under the options, which says what the setting does */
  hint?: string;
}

/**
 * A screen that lists the options to pick one, as the platform's Settings app does for a setting
 * with many values. Picking one saves it, then goes back. When saving fails, the screen stays and
 * says so.
 */
export function ChoiceScreen<T>({
  label,
  options,
  value,
  save,
  isSaving,
  hasFailed,
  hint,
}: ChoiceScreenProps<T>) {
  const {t} = useTranslation('core');
  const navigation = useNavigation();

  return (
    <ListScreen>
      <FieldGroup.Section>
        {choiceRows({
          label,
          options,
          value,
          disabled: isSaving,
          onChange: async picked => {
            await save(picked);
            // Unless the User already left
            if (navigation.isFocused()) {
              navigation.goBack();
            }
          },
        })}
        {(hasFailed || hint !== undefined) && (
          <FieldGroup.SectionFooter>
            <Feedback
              error={hasFailed ? t($ => $.core.errors.somethingWentWrong) : undefined}
              hint={hint}
            />
          </FieldGroup.SectionFooter>
        )}
      </FieldGroup.Section>
    </ListScreen>
  );
}
