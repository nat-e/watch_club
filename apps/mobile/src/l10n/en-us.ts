export default {
  signIn: {
    address: 'Address of your WatchClub',
    addressPlaceholder: 'watchclub.example.com',
    description:
      'Sign in to the same WatchClub you use in your browser. Enter its address to get started.',
    enterAddress: 'Enter the address of your WatchClub, such as watchclub.example.com',
    needsSetup: "This WatchClub isn't set up yet. Open it in a browser to finish setting it up.",
    unreachable: "We can't reach WatchClub at this address. Check it and try again.",
  },
  unreachable: {
    description: 'Check your internet connection, then try again.',
    title: "We can't reach your WatchClub",
    tryAgain: 'Try again',
  },
  you: {
    title: 'You',
  },
} as const;
