export default {
  combobox: {
    remove: 'Retirer',
  },
  contents: {
    back: 'Retour',
  },
  copyLink: {
    failed: "On n'a pas pu copier le lien. Sélectionne-le ci-dessous pour le copier toi-même.",
  },
  invitations: {
    actions: "Actions de l'invitation",
    active: 'Invitations actives',
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
  mediaImports: {
    dialog: {
      description: 'Lancer un nouvel import de {{source}} depuis :',
      filesToImport: 'Traiter',
      run: "Lancer l'import",
      title: 'Lancer un import de médias',
    },
    empty: {
      description:
        "Rien n'a encore été importé depuis cette source. Lance un import pour ajouter ses fichiers à WatchClub.",
      title: 'Aucun import pour le moment',
    },
    failed_one: '{{count}} en échec',
    failed_many: '{{count}} en échec',
    failed_other: '{{count}} en échec',
    failures: {
      internalError: 'Un problème est survenu. Réessaie plus tard.',
      interrupted: "L'import s'est interrompu avant la fin. Relance-le.",
      invalidApiKey: '{{app}} a refusé sa clé API. Modifie la source pour en saisir une nouvelle.',
      invalidServarrUrl: "Impossible de se connecter à {{app}} à son URL. Vérifie qu'il est lancé.",
    },
    filesToImport: {
      all: {
        description: "Relit chaque fichier et l'associe à nouveau.",
        name: 'Tous les fichiers',
        shortName: 'Tous',
      },
      new: {
        description: 'Seulement les fichiers pas encore importés.',
        name: 'Nouveaux fichiers uniquement',
        shortName: 'Nouveaux',
      },
      newAndUnmatched: {
        description: "Réessaie aussi les fichiers qui n'ont pas pu être associés.",
        name: 'Nouveaux fichiers et fichiers non associés',
        shortName: 'Nouveaux et non associés',
      },
    },
    findingFiles: 'Recherche des fichiers…',
    history: 'Historique des imports',
    import: 'Importer…',
    matched_one: '{{count}} associé',
    matched_many: '{{count}} associés',
    matched_other: '{{count}} associés',
    noFiles: 'Aucun fichier à traiter',
    progress_one: '{{handled}} sur {{count}} fichier',
    progress_many: '{{handled}} sur {{count}} fichiers',
    progress_other: '{{handled}} sur {{count}} fichiers',
    removed_one: '{{count}} retiré',
    removed_many: '{{count}} retirés',
    removed_other: '{{count}} retirés',
    started: 'Import lancé',
    states: {
      completed: 'Terminé',
      failed: 'Échec',
      running: 'En cours',
      waiting: 'En attente',
    },
    table: {
      duration: 'Durée',
      files: 'Fichiers',
      started: 'Début',
      status: 'Statut',
      trigger: 'Déclencheur',
    },
    triggers: {
      manual: 'Manuel',
      scheduled: 'Planifié',
    },
    unmatched_one: '{{count}} non associé',
    unmatched_many: '{{count}} non associés',
    unmatched_other: '{{count}} non associés',
    viewHistory: "Voir l'historique",
  },
  newAccount: {
    chooseUsername: "Choisis un nom d'utilisateur",
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
  resetPassword: {
    askForNewLink:
      "Les liens de réinitialisation expirent au bout de 3 jours. Demande un nouveau lien à l'administrateur.",
    backToSignIn: 'Retour à la connexion',
    noLongerWorks: 'Ce lien ne marche plus',
    saved: 'Nouveau mot de passe enregistré.',
    submit: 'Enregistrer le mot de passe',
    title: 'Choisis un nouveau mot de passe',
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
  sources: {
    actions: 'Actions pour {{source}}',
    add: 'Ajouter une source {{type}}',
    configured: 'Source configurée',
    connectionErrors: {
      invalidApiKey:
        'Cette clé API ne fonctionne pas avec {{app}}. Tu trouveras la tienne dans {{app}}, sous Paramètres > Général.',
      invalidServarrUrl: 'Impossible de se connecter à {{app}} à cette URL.',
    },
    delete: 'Supprimer…',
    deleted: 'Source supprimée',
    deleteDialog: {
      confirm: 'Supprimer la source',
      consequence:
        'Ses médias seront aussi retirés de WatchClub. Leurs fichiers restent sur le disque.',
      deleting: 'Suppression…',
      intro: 'Cela supprimera cette source :',
      title: 'Supprimer la source',
    },
    description:
      "Les sources sont l'endroit où WatchClub trouve ses vidéos, et où il envoie les demandes de tes amis.",
    edit: 'Modifier',
    filesystemForm: {
      create: 'Créer la source',
      createDescription: "Choisis ce qu'il faut importer depuis ton système de fichiers.",
      createTitle: 'Configurer la source',
      directory: 'Dossier',
      directoryHint:
        'WatchClub cherche les fichiers de ce type dans le dossier et tous ses sous-dossiers.',
      editTitle: 'Modifier la source',
      enterPath: 'Saisis un chemin',
      mediaType: 'Type de média',
      mediaTypeLocked: 'Tu ne pourras plus changer le type de média ensuite.',
      save: 'Enregistrer les modifications',
    },
    folderErrors: {
      notAbsolute: 'Saisis le chemin complet du dossier, par exemple /media/movies.',
      notFound: 'On ne trouve pas ce dossier sur le serveur de WatchClub. Vérifie le chemin.',
    },
    mediaTypes: {
      movie: 'Film',
      sportsEvent: 'Événement sportif',
      tvShowEpisode: 'Épisode de série',
    },
    none: 'Aucune source {{type}} pour le moment',
    qualityProfileErrors: {
      noneInApp:
        '{{app}} ne propose aucun profil de qualité. Ajoute-en un dans {{app}}, puis relance la connexion.',
    },
    rootFolderErrors: {
      noneInApp:
        '{{app}} ne propose aucun dossier racine. Ajoute-en un dans {{app}}, puis relance la connexion.',
    },
    servarrForm: {
      add: 'Ajouter la source',
      apiKey: 'Clé API',
      apiKeyHint: 'Ta clé API {{app}}. Tu la trouveras dans {{app}}, sous Paramètres > Général.',
      apiKeyKeepHint:
        'Laisse ce champ vide pour garder la clé actuelle, ou saisis-en une nouvelle depuis Paramètres > Général dans {{app}}.',
      configureDescription:
        'Choisis le profil de qualité et le dossier racine que WatchClub utilise pour les demandes de tes amis.',
      configureTitle: 'Configurer la source',
      connect: 'Connecter',
      connectDescription: 'Saisis les identifiants de connexion à ton serveur {{app}}.',
      connecting: 'Connexion…',
      connectTitle: 'Connecter le serveur {{app}}',
      enterApiKey: 'Saisis la clé API',
      enterUrl: "Saisis l'URL",
      localRootFolder: 'Chemin dans WatchClub (facultatif)',
      localRootFolderHint:
        "WatchClub doit accéder à ce dossier pour lire ses fichiers. S'il le voit à un autre chemin, par exemple avec Docker, saisis ce chemin.",
      qualityProfile: 'Profil de qualité',
      qualityProfileHint: 'La qualité utilisée pour les demandes envoyées à cette source.',
      rootFolder: 'Dossier racine',
      rootFolderHint: "Là où vont les fichiers demandés, et d'où WatchClub les importe.",
      save: 'Enregistrer les modifications',
      url: 'URL de {{app}}',
      urlHint: "L'adresse à laquelle WatchClub joint {{app}}.",
    },
    title: 'Sources',
    types: {
      filesystem: {
        description:
          "Importe des médias depuis un dossier de ton disque dur ou d'un système de fichiers distant.",
        empty: 'Configure une source Système de fichiers pour chercher des médias dans un dossier.',
        name: 'Système de fichiers',
      },
      radarr: {
        description: 'Importe des films depuis Radarr et envoie-lui les demandes de films.',
        empty:
          'Connecte un serveur Radarr pour importer des films et traiter les demandes de films.',
        name: 'Radarr',
      },
      sonarr: {
        description: 'Importe des séries depuis Sonarr et envoie-lui les demandes de séries.',
        empty:
          'Connecte un serveur Sonarr pour importer des séries et traiter les demandes de séries.',
        name: 'Sonarr',
      },
      sportarr: {
        description:
          "Importe des événements sportifs depuis Sportarr et envoie-lui les demandes d'événements sportifs.",
        empty:
          "Connecte un serveur Sportarr pour importer des événements sportifs et traiter les demandes d'événements sportifs.",
        name: 'Sportarr',
      },
    },
    updated: 'Source mise à jour',
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
    resetLinkCopied:
      'Lien de réinitialisation copié. Envoie-le à {{username}} : il est valable 3 jours.',
    resetPassword: 'Réinitialiser le mot de passe',
    title: 'Utilisateurs',
    user: 'Utilisateur',
    userDeleted: 'Utilisateur supprimé',
  },
} as const;
