export default {
  setup: {
    administratorAccount:
      'Crée le compte administrateur. Il te servira à gérer WatchClub et à inviter tes amis.',
    choosePassword: 'Choisis un mot de passe',
    chooseUsername: "Choisis un nom d'utilisateur",
    confirmPassword: 'Confirmer le mot de passe',
    keepItToYourself:
      'Garde-le pour toi : tes amis auront leur propre compte grâce aux invitations.',
    passwordsDiffer: 'Les mots de passe ne correspondent pas',
    passwordTooShort: 'Le mot de passe doit contenir au moins {{min}} caractères',
    submit: 'Créer un compte',
    title: 'Bienvenue sur WatchClub !',
    usernameCharacters: 'Utilise seulement des lettres minuscules, des chiffres et _',
    usernameTooLong: "Le nom d'utilisateur ne peut pas dépasser {{max}} caractères",
    usernameTooShort: "Le nom d'utilisateur doit contenir au moins {{min}} caractères",
  },
  sheet: {
    close: 'Fermer',
  },
  shell: {
    navigation: 'Navigation principale',
    signOutFailed: "On n'a pas pu te déconnecter. Réessaie dans un instant.",
  },
  sidebar: {
    description: 'La navigation principale et ton menu.',
    title: 'Barre latérale',
    toggle: 'Afficher ou masquer la barre latérale',
  },
  toaster: {
    notifications: 'Notifications',
  },
} as const;
