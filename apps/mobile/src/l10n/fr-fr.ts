export default {
  signIn: {
    address: 'Adresse de ton WatchClub',
    addressPlaceholder: 'watchclub.example.com',
    description: "Saisis l'adresse à laquelle tu ouvres WatchClub dans ton navigateur.",
    enterAddress: "Saisis l'adresse de ton WatchClub, par exemple watchclub.example.com",
    needsSetup:
      "Ce WatchClub n'est pas encore configuré. Ouvre-le dans un navigateur pour terminer sa configuration.",
    unreachable: "On n'arrive pas à joindre WatchClub à cette adresse. Vérifie-la et réessaie.",
  },
  unreachable: {
    description: 'Vérifie ta connexion à internet, puis réessaie.',
    title: "On n'arrive pas à joindre ton WatchClub",
    tryAgain: 'Réessayer',
  },
} as const;
