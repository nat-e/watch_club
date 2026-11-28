# Copywriting

How WatchClub's interface text reads, in English, French and Polish. Use the terms in `CONTEXT.md`, and follow the i18n rules in `AGENTS.md`.

## Voice

- Warm, like a friend running the club. Keep it plain: no jokes, slang or marketing claims.
- WatchClub speaks as "we" ("on" in French). Users don't need to know it is self-hosted: name the Instance Administrator only when the user has to contact them.
- French uses "tu".

## Words

- Name the type when the text is about one movie or TV show: "this movie", "cette série". In French, this also sets the gender of the words around it.
- Say "content" ("contenu") for movies, TV shows and sports events together, not "titles". French calls a sports event "contenu" too.

## Say what it's for, then one action

- Explain what a feature does for the user before how to use it: "Request a movie or a TV show: we'll look for it and add it here for everyone", not "Search for a title in Browse and request it."
- Leave navigation to buttons and links. Don't describe where controls are ("in Browse", "from its page") when a button can take the user there.
- Give steps only when the task is unfamiliar or the order matters, such as casting to a TV.
- Stay concrete. Say what really happens, without promising more than the app does: a request can end up not found, so "we'll look for it", not "we'll add it".

## Match the moment

- First use: one or two sentences on what goes here and why it's useful, then one action.
- Returning users: short labels and states. Don't explain the concept again.
- Confirmations: say what happened and who it affects.
- Errors: say what went wrong and what the user can do, in plain words, with no warmth that hides the problem.
- Deleting, sharing and anything hard to undo: state the consequence before the user confirms.

## Polish

- Polish uses "ty", in lowercase: "twoja playlista". WatchClub speaks as "my": "Poszukamy go".
- Say "pozycja" for content: "dodawać i usuwać pozycje". Name the type when the text is about one: "ten film", "ten serial", "to wydarzenie sportowe".
- A past-tense verb shows the gender of who acted, which we don't know. Don't use one with "ty" or a user's name. Use the present tense ("%{user} poleca"), an impersonal form ("Zapisano", "Dodano do playlisty") or a participle that agrees with the content ("Polecane przez %{user}").
- Names, such as users, servers and the club, never change their ending. Put them where they read well as they are: "Polecane przez %{user}", "serwer %{name}".
- Buttons are imperatives: "Zapisz", "Usuń", not "Zapisać".
- Quote with „…”.

The words of `CONTEXT.md`:

| English | Polish |
| --- | --- |
| Home, Browse, For You | Strona główna, Przeglądaj, Dla ciebie |
| Movie, TV show, sports event, season, episode | film, serial, wydarzenie sportowe, sezon, odcinek |
| Playlist, To Watch | playlista, Do obejrzenia |
| Request (a Content Request), Get notified | prośba, Powiadom mnie |
| Recommend, Inbox, Conversation, Message | Poleć, Wiadomości, rozmowa, wiadomość |
| Continue Watching, Watching Now, Watched | Oglądaj dalej, Teraz oglądają, Obejrzane |
| Play, Resume, Download | Odtwórz, Wznów, Pobierz |
| Cast, Stop casting, Remote, TV | Przesyłaj, Zatrzymaj przesyłanie, Pilot, telewizor |
| Subtitles, Audio, Quality, SDH | napisy, dźwięk, jakość, napisy dla niesłyszących |
| Intro, Recap, Credits | czołówka, streszczenie, napisy końcowe |
| Report a problem, Problem report | Zgłoś problem, zgłoszenie |
| Media, Media Source, Media Import, Unmatched | media, źródło mediów, import mediów, niedopasowane |
| Invitation, Instance Administrator, Settings | zaproszenie, administrator, Ustawienia |
