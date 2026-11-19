export default {
  browse: {
    title: 'Browse',
  },
  contents: {
    loadFailed_book: "We couldn't load this book. Try again in a moment.",
    loadFailed_movie: "We couldn't load this movie. Try again in a moment.",
    loadFailed_tvShow: "We couldn't load this TV show. Try again in a moment.",
    notFound_book: "We couldn't find this book.",
    notFound_movie: "We couldn't find this movie.",
    notFound_tvShow: "We couldn't find this TV show.",
  },
  contentTypes: {
    book: 'Book',
    movie: 'Movie',
    tvShow: 'TV show',
  },
  controls: {
    close: 'Close',
    tryAgain: 'Try again',
  },
  errors: {
    somethingWentWrong: "We couldn't complete your request. Try again in a moment.",
  },
  home: {
    title: 'Home',
  },
  inbox: {
    title: 'Inbox',
  },
  myRequests: {
    navigationLabel: 'Requests',
    title: 'My Requests',
  },
  notFound: {
    description: "We couldn't find this page. It may not exist, or you may not have access to it.",
    goHome: 'Go home',
    title: 'Page not found',
  },
  playlists: {
    title: 'Playlists',
  },
  search: {
    failed: "The search didn't work.",
    hint_books: 'Find any book.',
    hint_moviesAndTvShows: "Find any movie or TV show, even ones that aren't on {{name}} yet.",
    noResults: 'No results',
    nothingFound: "We didn't find anything for “{{query}}”.",
    resultCount_one: '{{count}} result',
    resultCount_other: '{{count}} results',
    results: 'Search results',
    scope: 'Search in',
    scopes: {
      books: 'Books',
      moviesAndTvShows: 'Movies and TV shows',
    },
    search: 'Search',
    searching: 'Searching…',
  },
  settings: {
    audio: 'Audio',
    audioAndSubtitles: 'Audio and subtitles',
    audioAndSubtitlesDescription:
      'Choose the audio and subtitles videos start with. You can still change them while watching.',
    audioAndSubtitlesSaved: 'Your audio and subtitle preferences are saved',
    description: 'Manage your account preferences.',
    englishUs: 'English (US)',
    french: 'French',
    language: 'Language',
    languageSaved: 'Your language is saved',
    languagesWithoutSubtitles: 'Languages without subtitles',
    languagesWithoutSubtitlesDescription:
      'When the audio is in one of these languages, only forced subtitles show, for signs or lines in another language.',
    originalLanguage: 'Original language',
    preferences: 'Preferences',
    preferencesDescription: 'Choose the language used across {{name}}.',
    save: 'Save',
    subtitles: 'Subtitles',
    subtitlesOff: 'Off',
    title: 'Settings',
  },
  signIn: {
    enterPassword: 'Enter your password',
    enterUsername: 'Enter your username',
    forgotPassword: 'Forgot your password? Ask the administrator for a reset link.',
    submit: 'Sign in',
    title: 'Welcome back!',
    wrongCredentials: 'Wrong username or password',
  },
  trackLanguages: {
    en: 'English',
    fr: 'French',
  },
  user: {
    instanceAdministrator: 'Instance administrator',
    password: 'Password',
    signOut: 'Sign out',
    username: 'Username',
  },
} as const;
