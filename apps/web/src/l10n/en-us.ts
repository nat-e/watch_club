export default {
  setup: {
    administratorAccount:
      "Create the administrator account. You'll use it to manage WatchClub and invite your friends.",
    choosePassword: 'Choose a password',
    chooseUsername: 'Choose a username',
    confirmPassword: 'Confirm password',
    keepItToYourself:
      'Keep it to yourself: your friends get their own accounts through invitations.',
    passwordsDiffer: 'Passwords do not match',
    passwordTooShort: 'Password must be at least {{min}} characters',
    submit: 'Create account',
    title: 'Welcome to WatchClub!',
    usernameCharacters: 'Use only lowercase letters, numbers and _',
    usernameTooLong: 'Username cannot be longer than {{max}} characters',
    usernameTooShort: 'Username must be at least {{min}} characters',
  },
  sheet: {
    close: 'Close',
  },
  shell: {
    navigation: 'Main navigation',
    signOutFailed: "We couldn't sign you out. Try again in a moment.",
  },
  sidebar: {
    description: 'The main navigation and your menu.',
    title: 'Sidebar',
    toggle: 'Show or hide the sidebar',
  },
  toaster: {
    notifications: 'Notifications',
  },
} as const;
