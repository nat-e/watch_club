/**
 * User Preferences: the User's choices, such as their Locale.
 */
import {useMutation, useQueryClient} from '@tanstack/react-query';
import {updatePreferencesMutation} from '@watchclub/api';
import {signedIn} from './session';

/** Returns the mutation that saves the User's Preferences, after which the app follows them. */
export function useSavePreferences() {
  const queryClient = useQueryClient();
  return useMutation({
    ...updatePreferencesMutation(),
    // The app switches to the User's new Locale
    onSuccess: user => signedIn(queryClient, user),
  });
}
