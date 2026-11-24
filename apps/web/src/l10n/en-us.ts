export default {
  combobox: {
    remove: 'Remove',
  },
  contents: {
    back: 'Back',
  },
  copyLink: {
    failed: "We couldn't copy the link. Select it below to copy it yourself.",
  },
  invitations: {
    actions: 'Invitation actions',
    active: 'Active invitations',
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
    maxUsesAlreadyUsed: "It's already been used more times than that.",
    maxUsesHint:
      'Maximum number of accounts this invitation can create. Leave empty for unlimited.',
    maxUsesMinimum: 'Maximum uses must be at least {{min}}',
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
  mediaImports: {
    dialog: {
      description: 'Start a new import of {{source}} from:',
      filesToImport: 'Process',
      run: 'Run import',
      title: 'Run media import',
    },
    empty: {
      description:
        'Nothing imported from this source yet. Run an import to add its files to WatchClub.',
      title: 'No imports yet',
    },
    failed_one: '{{count}} failed',
    failed_other: '{{count}} failed',
    failures: {
      internalError: 'Something went wrong. Try again later.',
      interrupted: 'The import stopped before it finished. Run it again.',
      invalidApiKey: '{{app}} refused its API key. Edit the source to enter a new one.',
      invalidServarrUrl: 'Could not connect to {{app}} at its URL. Check that it runs.',
    },
    filesToImport: {
      all: {
        description: 'Reads every file again and matches it again.',
        name: 'All files',
        shortName: 'All',
      },
      new: {
        description: 'Only files not imported yet.',
        name: 'New files only',
        shortName: 'New',
      },
      newAndUnmatched: {
        description: "Also retries files that couldn't be matched.",
        name: 'New and unmatched files',
        shortName: 'New and unmatched',
      },
    },
    findingFiles: 'Finding files…',
    history: 'Import history',
    import: 'Import…',
    matched_one: '{{count}} matched',
    matched_other: '{{count}} matched',
    noFiles: 'No files to process',
    progress_one: '{{handled}} of {{count}} file',
    progress_other: '{{handled}} of {{count}} files',
    removed_one: '{{count}} removed',
    removed_other: '{{count}} removed',
    started: 'Import started',
    states: {
      completed: 'Completed',
      failed: 'Failed',
      running: 'In progress',
      waiting: 'Pending',
    },
    table: {
      duration: 'Duration',
      files: 'Files',
      started: 'Started',
      status: 'Status',
      trigger: 'Trigger',
    },
    triggers: {
      manual: 'Manual',
      scheduled: 'Scheduled',
    },
    unmatched_one: '{{count}} unmatched',
    unmatched_other: '{{count}} unmatched',
    viewHistory: 'View history',
  },
  newAccount: {
    chooseUsername: 'Choose a username',
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
  resetPassword: {
    askForNewLink: 'Reset links expire after 3 days. Ask the administrator for a new one.',
    backToSignIn: 'Back to sign in',
    noLongerWorks: 'This link no longer works',
    saved: 'New password saved.',
    submit: 'Save password',
    title: 'Choose a new password',
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
  sources: {
    actions: 'Actions for {{source}}',
    add: 'Add {{type}} source',
    configured: 'Source configured',
    connectionErrors: {
      invalidApiKey:
        "This API key doesn't work with {{app}}. Find yours in {{app}} under Settings > General.",
      invalidServarrUrl: 'Could not connect to {{app}} at this URL.',
    },
    delete: 'Delete…',
    deleted: 'Source deleted',
    deleteDialog: {
      confirm: 'Delete source',
      consequence: 'Its media will be removed from WatchClub too. Their files stay on disk.',
      deleting: 'Deleting…',
      intro: 'This will delete this source:',
      title: 'Delete source',
    },
    description:
      "Sources are where WatchClub finds its videos, and where it sends your friends' requests.",
    edit: 'Edit',
    filesystemForm: {
      create: 'Create source',
      createDescription: 'Choose what to import from your filesystem.',
      createTitle: 'Configure source',
      directory: 'Directory',
      directoryHint: 'WatchClub looks for files of this type in the folder and all its subfolders.',
      editTitle: 'Edit source',
      enterPath: 'Enter a path',
      mediaType: 'Media type',
      mediaTypeLocked: "You can't change the media type later.",
      save: 'Save changes',
    },
    folderErrors: {
      notAbsolute: "Enter the folder's full path, such as /media/movies.",
      notFound: "We can't find this folder on WatchClub's server. Check the path.",
    },
    mediaTypes: {
      movie: 'Movie',
      sportsEvent: 'Sports event',
      tvShowEpisode: 'TV show episode',
    },
    none: 'No {{type}} sources yet',
    qualityProfileErrors: {
      noneInApp: '{{app}} has no quality profiles. Add one in {{app}}, then connect again.',
    },
    rootFolderErrors: {
      noneInApp: '{{app}} has no root folders. Add one in {{app}}, then connect again.',
    },
    servarrForm: {
      add: 'Add source',
      apiKey: 'API key',
      apiKeyHint: 'Your {{app}} API key. Find it in {{app}} under Settings > General.',
      apiKeyKeepHint:
        "Leave this empty to keep the current key, or enter a new one from {{app}}'s Settings > General.",
      configureDescription:
        "Choose the quality profile and root folder WatchClub uses for your friends' requests.",
      configureTitle: 'Configure source',
      connect: 'Connect',
      connectDescription: 'Enter the credentials to connect to your {{app}} server.',
      connecting: 'Connecting…',
      connectTitle: 'Connect {{app}} server',
      enterApiKey: 'Enter the API key',
      enterUrl: 'Enter the URL',
      localRootFolder: 'Path in WatchClub (optional)',
      localRootFolderHint:
        'WatchClub needs to reach this folder to play its files. If it sees the folder at another path, for example in Docker, enter that path.',
      qualityProfile: 'Quality profile',
      qualityProfileHint: 'The quality used for requests sent to this source.',
      rootFolder: 'Root folder',
      rootFolderHint: 'Where requested files go, and where WatchClub imports them from.',
      save: 'Save changes',
      url: '{{app}} URL',
      urlHint: 'The address where WatchClub reaches {{app}}.',
    },
    title: 'Sources',
    types: {
      filesystem: {
        description: 'Import media from a directory on your hard drive or a remote filesystem.',
        empty: 'Configure a Filesystem source to scan a directory for media.',
        name: 'Filesystem',
      },
      radarr: {
        description: 'Import movies from Radarr, and send it movie requests.',
        empty: 'Connect a Radarr server to import movies and fulfill movie requests.',
        name: 'Radarr',
      },
      sonarr: {
        description: 'Import TV shows from Sonarr, and send it TV show requests.',
        empty: 'Connect a Sonarr server to import TV shows and fulfill TV show requests.',
        name: 'Sonarr',
      },
      sportarr: {
        description: 'Import sports events from Sportarr, and send it sports event requests.',
        empty:
          'Connect a Sportarr server to import sports events and fulfill sports event requests.',
        name: 'Sportarr',
      },
    },
    updated: 'Source updated',
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
    resetLinkCopied: 'Reset link copied. Send it to {{username}}: it works for 3 days.',
    resetPassword: 'Reset password',
    title: 'Users',
    user: 'User',
    userDeleted: 'User deleted',
  },
} as const;
