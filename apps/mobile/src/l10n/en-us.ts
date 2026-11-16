export default {
  connect: {
    address: 'Address of your WatchClub',
    addressPlaceholder: 'watchclub.example.com',
    description: 'Enter the address you open WatchClub at in your browser.',
    enterAddress: 'Enter the address of your WatchClub, such as watchclub.example.com',
    needsSetup: "This WatchClub isn't set up yet. Open it in a browser to finish setting it up.",
    submit: 'Continue',
    unreachable: "We can't reach WatchClub at this address. Check it and try again.",
  },
  signIn: {
    useAnotherAddress: 'Use another address',
  },
} as const;
