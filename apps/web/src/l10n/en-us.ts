export default {
  combobox: {
    remove: 'Remove',
  },
  contents: {
    back: 'Back',
  },
  invitations: {
    actions: 'Invitation actions',
    active: 'Active invitations',
    copyFailed: "We couldn't copy the link. Select it below to copy it yourself.",
    copyLink: 'Copy invitation link',
    create: 'Create',
    created: 'Invitation created',
    delete: 'Delete',
    deleteConfirmation:
      'Nobody can sign up with {{code}} anymore. Accounts already created with it stay.',
    deleted: 'Invitation deleted',
    deleteInvitation: 'Delete invitation',
    dialogDescription:
      'Share the link with friends so they can create their account. It works for 7 days.',
    edit: 'Edit',
    editInvitation: 'Edit invitation',
    expires: 'Expires',
    inviteFriends: 'Invite friends',
    linkCopied: 'Invitation link copied. Send it to your friends.',
    maxUses: 'Maximum uses',
    maxUsesBelowUses: "It's already been used more times than that.",
    maxUsesHint:
      'Maximum number of accounts this invitation can create. Leave empty for unlimited.',
    maxUsesTooLow: 'Maximum uses must be at least {{min}}',
    newInvitation: 'New invitation',
    noneActive: 'No active invitations',
    save: 'Save',
    unlimited: 'Unlimited',
    updated: 'Invitation updated',
    uses: 'Uses',
  },
  join: {
    askForNewLink: 'Ask the person who invited you for a new link.',
    description:
      'A private community for watching and discussing movies, TV shows and more with friends.',
    noLongerWorks: 'This invitation no longer works',
    title: "You're invited to {{name}}",
  },
  mediaBrowser: {
    title: 'Media browser',
  },
  mediaSources: {
    title: 'Media sources',
  },
  newAccount: {
    choosePassword: 'Choose a password',
    chooseUsername: 'Choose a username',
    confirmPassword: 'Confirm password',
    passwordHint: 'At least {{min}} characters.',
    passwordsDiffer: 'Passwords do not match',
    passwordTooShort: 'Password must be at least {{min}} characters',
    submit: 'Create account',
    usernameCharacters: 'Use only lowercase letters, numbers and _',
    usernameHint: 'Your friends will see it. Use lowercase letters, numbers and _.',
    usernameTaken: 'This username is already taken',
    usernameTooLong: 'Username cannot be longer than {{max}} characters',
    usernameTooShort: 'Username must be at least {{min}} characters',
  },
  problemReports: {
    title: 'Problem reports',
  },
  search: {
    closeSearch: 'Close search',
    inLibrary: 'On {{name}}',
    seeAll: 'See all results for “{{query}}”',
  },
  settings: {
    addLanguage: 'Add a language',
    noLanguageMatches: 'No language matches',
  },
  setup: {
    administratorAccount:
      "Create the administrator account. You'll use it to manage WatchClub and invite your friends.",
    keepItToYourself:
      'Keep it to yourself: your friends get their own accounts through invitations.',
    title: 'Welcome to WatchClub!',
  },
  shell: {
    administration: 'Administration',
    navigation: 'Main navigation',
    signOutFailed: "We couldn't sign you out. Try again in a moment.",
  },
  sidebar: {
    description: 'The main navigation and your menu.',
    title: 'Sidebar',
    toggle: 'Show or hide the sidebar',
  },
  toaster: {
    closeNotification: 'Close notification',
    notifications: 'Notifications',
  },
  users: {
    actions: 'Actions',
    actionsFor: 'Actions for {{username}}',
    deleteConfirmation:
      "Delete {{username}}? They can't sign in anymore, and their watch history and playlists are deleted. Their messages and requests stay, shown as from a deleted user. You can't undo this.",
    deleteUser: 'Delete user',
    description: 'Invite friends to {{name}} and manage who has access.',
    memberSince: 'Member since',
    title: 'Users',
    user: 'User',
    userDeleted: 'User deleted',
  },
} as const;
