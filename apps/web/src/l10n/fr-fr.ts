export default {
  combobox: {
    remove: 'Retirer',
  },
  contents: {
    back: 'Retour',
  },
  invitations: {
    actions: "Actions de l'invitation",
    active: 'Invitations actives',
    copyFailed: "On n'a pas pu copier le lien. Sélectionne-le ci-dessous pour le copier toi-même.",
    copyLink: "Copier le lien d'invitation",
    create: 'Créer',
    created: 'Invitation créée',
    delete: 'Supprimer',
    deleteConfirmation:
      "Plus personne ne pourra s'inscrire avec {{code}}. Les comptes déjà créés avec restent.",
    deleted: 'Invitation supprimée',
    deleteInvitation: "Supprimer l'invitation",
    dialogDescription:
      "Partage le lien avec tes amis pour qu'ils créent leur compte. Il est valable 7 jours.",
    edit: 'Modifier',
    editInvitation: "Modifier l'invitation",
    expires: 'Expire',
    inviteFriends: 'Inviter des amis',
    linkCopied: "Lien d'invitation copié. Envoie-le à tes amis.",
    maxUses: 'Utilisations maximum',
    maxUsesAlreadyUsed: 'Elle a déjà été utilisée plus de fois que ça.',
    maxUsesHint:
      'Nombre maximal de comptes que cette invitation peut créer. Laisse vide pour ne pas fixer de limite.',
    maxUsesMinimum: "Le nombre maximal d'utilisations doit être d'au moins {{min}}",
    newInvitation: 'Nouvelle invitation',
    noneActive: 'Aucune invitation active',
    save: 'Enregistrer',
    unlimited: 'Illimité',
    updated: 'Invitation mise à jour',
    uses: 'Utilisations',
  },
  join: {
    askForNewLink: "Demande un nouveau lien à la personne qui te l'a envoyée.",
    description:
      'Une communauté privée pour regarder des films, des séries et plus encore, et en discuter entre amis.',
    noLongerWorks: "Cette invitation n'est plus valable",
    title: "On t'invite à rejoindre {{name}}",
  },
  mediaBrowser: {
    title: 'Explorateur de médias',
  },
  mediaSources: {
    title: 'Sources de médias',
  },
  newAccount: {
    choosePassword: 'Choisis un mot de passe',
    chooseUsername: "Choisis un nom d'utilisateur",
    confirmPassword: 'Confirmer le mot de passe',
    passwordHint: 'Au moins {{min}} caractères.',
    passwordsDiffer: 'Les mots de passe ne correspondent pas',
    passwordTooShort: 'Le mot de passe doit contenir au moins {{min}} caractères',
    submit: 'Créer un compte',
    usernameCharacters: 'Utilise seulement des lettres minuscules, des chiffres et _',
    usernameHint: 'Tes amis le verront. Utilise des lettres minuscules, des chiffres et _.',
    usernameTaken: "Ce nom d'utilisateur est déjà pris",
    usernameTooLong: "Le nom d'utilisateur ne peut pas dépasser {{max}} caractères",
    usernameTooShort: "Le nom d'utilisateur doit contenir au moins {{min}} caractères",
  },
  problemReports: {
    title: 'Signalements',
  },
  search: {
    closeSearch: 'Fermer la recherche',
    inLibrary: 'Sur {{name}}',
    seeAll: 'Voir tous les résultats pour « {{query}} »',
  },
  settings: {
    addLanguage: 'Ajoute une langue',
    noLanguageMatches: 'Aucune langue ne correspond',
  },
  setup: {
    administratorAccount:
      'Crée le compte administrateur. Il te servira à gérer WatchClub et à inviter tes amis.',
    keepItToYourself:
      'Garde-le pour toi : tes amis auront leur propre compte grâce aux invitations.',
    title: 'Bienvenue sur WatchClub !',
  },
  shell: {
    administration: 'Administration',
    navigation: 'Navigation principale',
    signOutFailed: "On n'a pas pu te déconnecter. Réessaie dans un instant.",
  },
  sidebar: {
    description: 'La navigation principale et ton menu.',
    title: 'Barre latérale',
    toggle: 'Afficher ou masquer la barre latérale',
  },
  toaster: {
    closeNotification: 'Fermer la notification',
    notifications: 'Notifications',
  },
  users: {
    actions: 'Actions',
    actionsFor: 'Actions pour {{username}}',
    deleteConfirmation:
      "Supprimer {{username}} ? Cette personne ne pourra plus se connecter, et son historique et ses playlists seront supprimés. Ses messages et ses demandes restent, au nom d'un utilisateur supprimé. C'est définitif.",
    deleteUser: "Supprimer l'utilisateur",
    description: 'Invite tes amis sur {{name}} et gère qui y a accès.',
    memberSince: 'Membre depuis',
    title: 'Utilisateurs',
    user: 'Utilisateur',
    userDeleted: 'Utilisateur supprimé',
  },
} as const;
