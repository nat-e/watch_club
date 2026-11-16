# Public-domain films from Wikimedia Commons, one 60 s clip each, imported by a filesystem
# Media Source. Silent films get public-domain Musopen recordings as music, except three that
# stay without an audio track. The sound films keep their original sound.

%{
  sources: %{
    pd_music_figaro: %{
      title: "Le nozze di Figaro, K. 492: Overture",
      author: "Wolfgang Amadeus Mozart; performed by the Musopen Symphony",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Mozart_-_Le_nozze_di_Figaro,_K492_-_Overture_(Musopen_Symphony).flac",
      audio_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d2/Mozart_-_Le_nozze_di_Figaro%2C_K492_-_Overture_%28Musopen_Symphony%29.flac/Mozart_-_Le_nozze_di_Figaro%2C_K492_-_Overture_%28Musopen_Symphony%29.flac.ogg"
    },
    pd_music_italian: %{
      title: "Symphony No. 4 in A major, Op. 90 \"Italian\": I. Allegro vivace",
      author: "Felix Mendelssohn; performed by the Musopen Symphony",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Mendelssohn_-_Symphony_No._4_in_A_major,_Op._90_'Italian'_-_I._Allegro_vivace_(Musopen_Symphony).flac",
      audio_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/fd/Mendelssohn_-_Symphony_No._4_in_A_major%2C_Op._90_%27Italian%27_-_I._Allegro_vivace_%28Musopen_Symphony%29.flac/Mendelssohn_-_Symphony_No._4_in_A_major%2C_Op._90_%27Italian%27_-_I._Allegro_vivace_%28Musopen_Symphony%29.flac.ogg"
    },
    pd_music_lark: %{
      title: "String Quartet in D major, Op. 64 No. 5 \"The Lark\": IV. Finale. Vivace",
      author: "Joseph Haydn; performed by the Musopen String Quartet",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Haydn_-_String_Quartet,_Op._64_No._5_in_D_major_'The_Lark'_-_IV._Finale._Vivace_(Musopen_String_Quartet).flac",
      audio_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/ba/Haydn_-_String_Quartet%2C_Op._64_No._5_in_D_major_%27The_Lark%27_-_IV._Finale._Vivace_%28Musopen_String_Quartet%29.flac/Haydn_-_String_Quartet%2C_Op._64_No._5_in_D_major_%27The_Lark%27_-_IV._Finale._Vivace_%28Musopen_String_Quartet%29.flac.ogg"
    },
    pd_music_morning: %{
      title: "Peer Gynt Suite No. 1, Op. 46: Morning Mood",
      author: "Edvard Grieg; performed by the Musopen Symphony Orchestra",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url: "https://commons.wikimedia.org/wiki/File:Musopen_-_Morning.ogg",
      audio_url: "https://upload.wikimedia.org/wikipedia/commons/1/1a/Musopen_-_Morning.ogg"
    },
    pd_music_symphony_40: %{
      title: "Symphony No. 40 in G minor, K. 550: I. Molto allegro",
      author: "Wolfgang Amadeus Mozart; performed by the Musopen Symphony",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Mozart_-_Symphony_No._40_in_G_minor,_K550_-_I._Molto_allegro_(Musopen_Symphony).flac",
      audio_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a8/Mozart_-_Symphony_No._40_in_G_minor%2C_K550_-_I._Molto_allegro_%28Musopen_Symphony%29.flac/Mozart_-_Symphony_No._40_in_G_minor%2C_K550_-_I._Molto_allegro_%28Musopen_Symphony%29.flac.ogg"
    },
    pd_music_tragic: %{
      title: "Tragic Overture, Op. 81",
      author: "Johannes Brahms; performed by the Musopen Symphony",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-author",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Brahms_-_Tragic_Overture,_Op._81_(Musopen_Symphony).flac",
      audio_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c4/Brahms_-_Tragic_Overture%2C_Op._81_%28Musopen_Symphony%29.flac/Brahms_-_Tragic_Overture%2C_Op._81_%28Musopen_Symphony%29.flac.ogg"
    },
    pd_the_kid: %{
      title: "The Kid (1921)",
      author: "Charlie Chaplin",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Kid_(1921).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/ea/The_Kid_%281921%29.webm/The_Kid_%281921%29.webm.720p.vp9.webm"
    },
    pd_the_gold_rush: %{
      title: "The Gold Rush (1925)",
      author: "Charlie Chaplin",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Gold_Rush.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d4/The_Gold_Rush.webm/The_Gold_Rush.webm.720p.vp9.webm"
    },
    pd_caligari: %{
      title: "The Cabinet of Dr. Caligari (1920)",
      author: "Robert Wiene, Carl Mayer, Hans Janowitz",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Das_Cabinet_des_Dr._Caligari.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/ba/Das_Cabinet_des_Dr._Caligari.webm/Das_Cabinet_des_Dr._Caligari.webm.720p.vp9.webm"
    },
    pd_battleship_potemkin: %{
      title: "Battleship Potemkin (1925)",
      author: "Sergei Eisenstein",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-Russia-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Battleship_Potemkin_(1925)_by_Sergei_Eisenstein.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/7/74/Battleship_Potemkin_%281925%29_by_Sergei_Eisenstein.webm/Battleship_Potemkin_%281925%29_by_Sergei_Eisenstein.webm.720p.vp9.webm"
    },
    pd_sherlock_jr: %{
      title: "Sherlock Jr. (1924)",
      author: "Buster Keaton",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Sherlock_Jr._(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/95/Sherlock_Jr._%281924%29.webm/Sherlock_Jr._%281924%29.webm.720p.vp9.webm"
    },
    pd_man_with_a_movie_camera: %{
      title: "Man with a Movie Camera (1929)",
      author: "Dziga Vertov",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Man_with_a_Movie_Camera_(1929)_by_Dziga_Vertov.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/e6/Man_with_a_Movie_Camera_%281929%29_by_Dziga_Vertov.webm/Man_with_a_Movie_Camera_%281929%29_by_Dziga_Vertov.webm.720p.vp9.webm"
    },
    pd_the_cameraman: %{
      title: "The Cameraman (1928)",
      author: "Buster Keaton, Edward Sedgwick",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Cameraman_(1928).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d8/The_Cameraman_%281928%29.webm/The_Cameraman_%281928%29.webm.720p.vp9.webm"
    },
    pd_intolerance: %{
      title: "Intolerance: Love's Struggle Throughout the Ages (1916)",
      author: "D. W. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Intolerance_(D._W._Griffith,_1916).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/9c/Intolerance_%28D._W._Griffith%2C_1916%29.webm/Intolerance_%28D._W._Griffith%2C_1916%29.webm.720p.vp9.webm"
    },
    pd_seven_chances: %{
      title: "Seven Chances (1925)",
      author: "Buster Keaton",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Seven_Chances_(1925).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/46/Seven_Chances_%281925%29.webm/Seven_Chances_%281925%29.webm.720p.vp9.webm"
    },
    pd_the_navigator: %{
      title: "The Navigator (1924)",
      author: "Donald Crisp and Buster Keaton",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Navigator_(1924)_by_Donald_Crisp_and_Buster_Keaton.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/3/32/The_Navigator_%281924%29_by_Donald_Crisp_and_Buster_Keaton.webm/The_Navigator_%281924%29_by_Donald_Crisp_and_Buster_Keaton.webm.720p.vp9.webm"
    },
    pd_broken_blossoms: %{
      title: "Broken Blossoms or The Yellow Man and the Girl (1919)",
      author: "D. W. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Broken_Blossoms.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/7/73/Broken_Blossoms.webm"
    },
    pd_greed: %{
      title: "Greed (1924)",
      author: "Erich von Stroheim",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Greed_(1924)_by_Erich_von_Stroheim.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f7/Greed_%281924%29_by_Erich_von_Stroheim.webm/Greed_%281924%29_by_Erich_von_Stroheim.webm.720p.vp9.webm"
    },
    pd_a_woman_of_paris: %{
      title: "A Woman of Paris: A Drama of Fate (1923)",
      author: "Charlie Chaplin",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:A_Woman_of_Paris,_A_Drama_of_Fate_(1923)_by_Charlie_Chaplin.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/0/06/A_Woman_of_Paris%2C_A_Drama_of_Fate_%281923%29_by_Charlie_Chaplin.webm"
    },
    pd_the_thief_of_bagdad: %{
      title: "The Thief of Bagdad (1924)",
      author: "Douglas Fairbanks, Raoul Walsh",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Thief_of_Bagdad_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/5b/The_Thief_of_Bagdad_%281924%29.webm/The_Thief_of_Bagdad_%281924%29.webm.720p.vp9.webm"
    },
    pd_go_west: %{
      title: "Go West (1925)",
      author: "Buster Keaton",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Go_West_(1925).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/56/Go_West_%281925%29.webm/Go_West_%281925%29.webm.720p.vp9.webm"
    },
    pd_the_hunchback_of_notre_dame: %{
      title: "The Hunchback of Notre Dame (1923)",
      author: "Wallace Worsley",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Hunchback_of_Notre_Dame_(Wallace_Worsley,_1923).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f1/The_Hunchback_of_Notre_Dame_%28Wallace_Worsley%2C_1923%29.webm/The_Hunchback_of_Notre_Dame_%28Wallace_Worsley%2C_1923%29.webm.720p.vp9.webm"
    },
    pd_the_hands_of_orlac: %{
      title: "The Hands of Orlac (1924)",
      author: "Robert Wiene",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Orlacs_H%C3%A4nde_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f7/Orlacs_H%C3%A4nde_%281924%29.webm/Orlacs_H%C3%A4nde_%281924%29.webm.720p.vp9.webm"
    },
    pd_way_down_east: %{
      title: "Way Down East (1920)",
      author: "D. W. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Way_Down_East_(film,_1920).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/27/Way_Down_East_%28film%2C_1920%29.webm/Way_Down_East_%28film%2C_1920%29.webm.720p.vp9.webm"
    },
    pd_speedy: %{
      title: "Speedy (1928)",
      author: "Ted Wilde",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Speedy_(1928)_by_Ted_Wilde.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/41/Speedy_%281928%29_by_Ted_Wilde.webm/Speedy_%281928%29_by_Ted_Wilde.webm.720p.vp9.webm"
    },
    pd_foolish_wives: %{
      title: "Foolish Wives (1922)",
      author: "Erich von Stroheim",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Foolish_Wives_(1922)_.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/9c/Foolish_Wives_%281922%29_.webm/Foolish_Wives_%281922%29_.webm.720p.vp9.webm"
    },
    pd_the_kid_brother: %{
      title: "The Kid Brother (1927)",
      author: "Ted Wilde, J.A. Howe, Harold Lloyd, Lewis Milestone",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Kid_Brother_(1927).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c9/The_Kid_Brother_%281927%29.webm/The_Kid_Brother_%281927%29.webm.720p.vp9.webm"
    },
    pd_orphans_of_the_storm: %{
      title: "Orphans of the Storm (1921)",
      author: "D. W. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Orphans_of_the_Storm_(1921).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/d/d3/Orphans_of_the_Storm_%281921%29.webm"
    },
    pd_the_last_command: %{
      title: "The Last Command (1928)",
      author: "Josef von Sternberg",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Last_Command_(1928).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/3/33/The_Last_Command_%281928%29.webm/The_Last_Command_%281928%29.webm.720p.vp9.webm"
    },
    pd_the_doll: %{
      title: "The Doll (1919)",
      author: "Ernst Lubitsch",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Die_Puppe_(1919).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a7/Die_Puppe_%281919%29.webm/Die_Puppe_%281919%29.webm.720p.vp9.webm"
    },
    pd_underworld: %{
      title: "Underworld (1927)",
      author: "Josef von Sternberg",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Underworld_(1927).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a1/Underworld_%281927%29.webm/Underworld_%281927%29.webm.720p.vp9.webm"
    },
    pd_the_cat_and_the_canary: %{
      title: "The Cat and the Canary (1927)",
      author: "Paul Leni",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Cat_and_the_Canary_(1927)_by_Paul_Leni.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/0/05/The_Cat_and_the_Canary_%281927%29_by_Paul_Leni.webm/The_Cat_and_the_Canary_%281927%29_by_Paul_Leni.webm.720p.vp9.webm"
    },
    pd_the_iron_horse: %{
      title: "The Iron Horse (1925)",
      author: "John Ford",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Iron_Horse_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/57/The_Iron_Horse_%281924%29.webm/The_Iron_Horse_%281924%29.webm.720p.vp9.webm"
    },
    pd_girl_shy: %{
      title: "Girl Shy (1924)",
      author: "Fred C. Newmeyer and Sam Taylor",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Girl_Shy_(1924).webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/f/fe/Girl_Shy_%281924%29.webm"
    },
    pd_waxworks: %{
      title: "Waxworks (1924)",
      author: "Paul Leni, Leo Birinski",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Das_Wachsfigurenkabinett_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/40/Das_Wachsfigurenkabinett_%281924%29.webm/Das_Wachsfigurenkabinett_%281924%29.webm.720p.vp9.webm"
    },
    pd_the_oyster_princess: %{
      title: "The Oyster Princess (1919)",
      author: "Ernst Lubitsch",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-75-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Die_Austernprinzessin_(1919).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/ad/Die_Austernprinzessin_%281919%29.webm/Die_Austernprinzessin_%281919%29.webm.720p.vp9.webm"
    },
    pd_20000_leagues_under_the_sea: %{
      title: "20,000 Leagues Under the Sea (1916)",
      author: "Stuart Paton",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:20,000_Leagues_Under_the_Sea_(1916).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/e0/20%2C000_Leagues_Under_the_Sea_%281916%29.webm/20%2C000_Leagues_Under_the_Sea_%281916%29.webm.720p.vp9.webm"
    },
    pd_the_sheik: %{
      title: "The Sheik (1921)",
      author: "George Melford",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Sheik_(1921)_by_George_Melford.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/28/The_Sheik_%281921%29_by_George_Melford.webm/The_Sheik_%281921%29_by_George_Melford.webm.720p.vp9.webm"
    },
    pd_street_angel: %{
      title: "Street Angel (1928)",
      author: "Frank Borzage",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Street_Angel_(1928)_by_Frank_Borzage.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/5a/Street_Angel_%281928%29_by_Frank_Borzage.webm/Street_Angel_%281928%29_by_Frank_Borzage.webm.720p.vp9.webm"
    },
    pd_robin_hood: %{
      title: "Robin Hood (1922)",
      author: "Douglas Fairbanks, Allan Dwan",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Douglas_Fairbanks_in_Robin_Hood_(1922).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c8/Douglas_Fairbanks_in_Robin_Hood_%281922%29.webm/Douglas_Fairbanks_in_Robin_Hood_%281922%29.webm.720p.vp9.webm"
    },
    pd_sherlock_holmes: %{
      title: "Sherlock Holmes (1916)",
      author: "Arthur Berthelet",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Sherlock_Holmes_(1916).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/9f/Sherlock_Holmes_%281916%29.webm/Sherlock_Holmes_%281916%29.webm.720p.vp9.webm"
    },
    pd_the_four_horsemen_of_the_apocalypse: %{
      title: "The Four Horsemen of the Apocalypse (1921)",
      author: "Rex Ingram, June Mathis, Vicente Blasco Ibáñez",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Four_Horsemen_of_the_Apocalypse_(1921).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/d/da/The_Four_Horsemen_of_the_Apocalypse_%281921%29.webm/The_Four_Horsemen_of_the_Apocalypse_%281921%29.webm.720p.vp9.webm"
    },
    pd_the_great_white_silence: %{
      title: "The Great White Silence (1924)",
      author: "Herbert Ponting",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Great_White_Silence_(1924)_by_Herbert_Ponting.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/ed/The_Great_White_Silence_%281924%29_by_Herbert_Ponting.webm/The_Great_White_Silence_%281924%29_by_Herbert_Ponting.webm.720p.vp9.webm"
    },
    pd_the_haunted_castle: %{
      title: "The Haunted Castle (1921)",
      author: "F. W. Murnau",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Haunted_Castle_(1921)_by_F._W._Murnau.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/fa/The_Haunted_Castle_%281921%29_by_F._W._Murnau.webm/The_Haunted_Castle_%281921%29_by_F._W._Murnau.webm.720p.vp9.webm"
    },
    pd_true_heart_susie: %{
      title: "True Heart Susie (1919)",
      author: "D. W. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:True_Heart_Susie_(1919)_by_D._W._Griffith.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/b4/True_Heart_Susie_%281919%29_by_D._W._Griffith.webm/True_Heart_Susie_%281919%29_by_D._W._Griffith.webm.720p.vp9.webm"
    },
    pd_the_saphead: %{
      title: "The Saphead (1920)",
      author: "Metro Pictures",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Saphead_(1920).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/7/73/The_Saphead_%281920%29.webm/The_Saphead_%281920%29.webm.720p.vp9.webm"
    },
    pd_the_wizard_of_oz: %{
      title: "The Wizard of Oz (1925)",
      author: "Larry Semon",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Wizard_of_Oz_(1925).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a7/Wizard_of_Oz_%281925%29.webm/Wizard_of_Oz_%281925%29.webm.720p.vp9.webm"
    },
    pd_peter_pan: %{
      title: "Peter Pan (1924)",
      author: "Herbert Brenon",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Peter_Pan_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/47/Peter_Pan_%281924%29.webm/Peter_Pan_%281924%29.webm.720p.vp9.webm"
    },
    pd_the_wildcat: %{
      title: "The Wildcat (1921)",
      author: "Ernst Lubitsch",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-auto-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Die_Bergkatze_(Ernst_Lubitsch,_1921).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/5d/Die_Bergkatze_%28Ernst_Lubitsch%2C_1921%29.webm/Die_Bergkatze_%28Ernst_Lubitsch%2C_1921%29.webm.720p.vp9.webm"
    },
    pd_the_regeneration: %{
      title: "The Regeneration (1915)",
      author: "Raoul Walsh",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Regeneration_(1915).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/0/0d/Regeneration_%281915%29.webm"
    },
    pd_the_marriage_circle: %{
      title: "The Marriage Circle (1924)",
      author: "Ernst Lubitsch",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Marriage_Circle_(1924).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/2/26/The_Marriage_Circle_%281924%29.webm"
    },
    pd_alice_in_wonderland: %{
      title: "Alice in Wonderland (1915)",
      author: "W.W. Young",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US",
      page_url: "https://commons.wikimedia.org/wiki/File:Alice_in_Wonderland_(1915).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/af/Alice_in_Wonderland_%281915%29.webm/Alice_in_Wonderland_%281915%29.webm.720p.vp9.webm"
    },
    pd_salome: %{
      title: "Salomé (1923)",
      author: "Alla Nazimova, Charles Bryant",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Salom%C3%A9_(1923).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Salom%C3%A9_%281923%29.webm/Salom%C3%A9_%281923%29.webm.720p.vp9.webm"
    },
    pd_a_trip_to_mars: %{
      title: "A Trip to Mars (1918)",
      author: "Holger-Madsen",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-old-70-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Himmelskibet_(1918)_by_Holger-Madsen.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/8/81/Himmelskibet_%281918%29_by_Holger-Madsen.webm/Himmelskibet_%281918%29_by_Holger-Madsen.webm.720p.vp9.webm"
    },
    pd_dr_jack: %{
      title: "Dr. Jack (1922)",
      author: "Fred Newmeyer",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Dr._Jack_(1922)_by_Fred_Newmeyer.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/0/0d/Dr._Jack_%281922%29_by_Fred_Newmeyer.webm/Dr._Jack_%281922%29_by_Fred_Newmeyer.webm.720p.vp9.webm"
    },
    pd_blind_husbands: %{
      title: "Blind Husbands (1919)",
      author: "Erich von Stroheim",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url: "https://commons.wikimedia.org/wiki/File:Blind_Husbands_(1919).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/1/1e/Blind_Husbands_%281919%29.webm"
    },
    pd_stella_maris: %{
      title: "Stella Maris (1918)",
      author: "Marshall Neilan",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-expired",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Stella_Maris_(1918)_by_Marshall_Neilan.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/58/Stella_Maris_%281918%29_by_Marshall_Neilan.webm/Stella_Maris_%281918%29_by_Marshall_Neilan.webm.720p.vp9.webm"
    },
    pd_night_of_the_living_dead: %{
      title: "Night of the Living Dead (1968)",
      author: "George A. Romero",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-no_notice",
      page_url: "https://commons.wikimedia.org/wiki/File:Night_of_the_Living_Dead_(1968).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/24/Night_of_the_Living_Dead_%281968%29.webm/Night_of_the_Living_Dead_%281968%29.webm.720p.vp9.webm"
    },
    pd_his_girl_friday: %{
      title: "His Girl Friday (1940)",
      author: "Howard Hawks",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-not_renewed",
      page_url: "https://commons.wikimedia.org/wiki/File:His_Girl_Friday_(1940).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/fb/His_Girl_Friday_%281940%29.webm/His_Girl_Friday_%281940%29.webm.720p.vp9.webm"
    },
    pd_plan_9_from_outer_space: %{
      title: "Plan 9 from Outer Space (1957)",
      author: "Edward D. Wood Jr.",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-not_renewed",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Plan_9_from_Outer_Space_(1959_film).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/e8/Plan_9_from_Outer_Space_%281959_film%29.webm/Plan_9_from_Outer_Space_%281959_film%29.webm.1080p.vp9.webm"
    },
    pd_the_little_shop_of_horrors: %{
      title: "The Little Shop of Horrors (1960)",
      author: "Roger Corman, Charles B. Griffith",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-no_notice",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Little_Shop_of_Horrors_(1960)_by_Roger_Corman.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/20/The_Little_Shop_of_Horrors_%281960%29_by_Roger_Corman.webm/The_Little_Shop_of_Horrors_%281960%29_by_Roger_Corman.webm.720p.vp9.webm"
    },
    pd_white_zombie: %{
      title: "White Zombie (1932)",
      author: "Halperin Productions",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-not_renewed",
      page_url:
        "https://commons.wikimedia.org/wiki/File:White_Zombie_(1932)_by_Victor_Hugo_Halperin_HR.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/3/38/White_Zombie_%281932%29_by_Victor_Hugo_Halperin_HR.webm/White_Zombie_%281932%29_by_Victor_Hugo_Halperin_HR.webm.720p.vp9.webm"
    },
    pd_the_hitch_hiker: %{
      title: "The Hitch-Hiker (1953)",
      author: "Ida Lupino",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US",
      page_url: "https://commons.wikimedia.org/wiki/File:The_Hitch-Hiker.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/fa/The_Hitch-Hiker.webm/The_Hitch-Hiker.webm.720p.vp9.webm"
    },
    pd_tell_your_children: %{
      title: "Tell Your Children (1938)",
      author: "Louis J. Gasnier",
      license: "Public domain",
      license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-not_renewed",
      page_url: "https://commons.wikimedia.org/wiki/File:Reefer_madness1938.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/7/7f/Reefer_madness1938.webm"
    }
  },
  files: [
    %{
      path: "movies/The Kid (1921) {tmdb-10098}/The Kid (1921).mkv",
      source: :pd_the_kid,
      clips: [{1200, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/The Gold Rush (1925) {tmdb-962}/The Gold Rush (1925).mkv",
      source: :pd_the_gold_rush,
      clips: [{2700, 60}],
      music: :pd_music_lark
    },
    %{
      path:
        "movies/The Cabinet of Dr. Caligari (1920) {tmdb-234}/The Cabinet of Dr. Caligari (1920).mkv",
      source: :pd_caligari,
      clips: [{2700, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/Battleship Potemkin (1925) {tmdb-643}/Battleship Potemkin (1925).mkv",
      source: :pd_battleship_potemkin,
      clips: [{2950, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path: "movies/Sherlock Jr. (1924) {tmdb-992}/Sherlock Jr. (1924).mkv",
      source: :pd_sherlock_jr,
      clips: [{2100, 60}],
      music: :pd_music_lark
    },
    %{
      path:
        "movies/Man with a Movie Camera (1929) {tmdb-26317}/Man with a Movie Camera (1929).mkv",
      source: :pd_man_with_a_movie_camera,
      clips: [{1800, 60}]
    },
    %{
      path: "movies/The Cameraman (1928) {tmdb-31411}/The Cameraman (1928).mkv",
      source: :pd_the_cameraman,
      clips: [{2000, 60}],
      music: :pd_music_lark
    },
    %{
      path:
        "movies/Intolerance - Love's Struggle Throughout the Ages (1916) {tmdb-3059}/Intolerance - Love's Struggle Throughout the Ages (1916).mkv",
      source: :pd_intolerance,
      clips: [{3600, 60}]
    },
    %{
      path: "movies/Seven Chances (1925) {tmdb-32600}/Seven Chances (1925).mkv",
      source: :pd_seven_chances,
      clips: [{2900, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/The Navigator (1924) {tmdb-32318}/The Navigator (1924).mkv",
      source: :pd_the_navigator,
      clips: [{2000, 60}],
      music: :pd_music_italian
    },
    %{
      path:
        "movies/Broken Blossoms or The Yellow Man and the Girl (1919) {tmdb-899}/Broken Blossoms or The Yellow Man and the Girl (1919).mkv",
      source: :pd_broken_blossoms,
      clips: [{2400, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/Greed (1924) {tmdb-1405}/Greed (1924).mkv",
      source: :pd_greed,
      clips: [{7200, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path:
        "movies/A Woman of Paris - A Drama of Fate (1923) {tmdb-28974}/A Woman of Paris - A Drama of Fate (1923).mkv",
      source: :pd_a_woman_of_paris,
      clips: [{2400, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/The Thief of Bagdad (1924) {tmdb-28963}/The Thief of Bagdad (1924).mkv",
      source: :pd_the_thief_of_bagdad,
      clips: [{4000, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/Go West (1925) {tmdb-33015}/Go West (1925).mkv",
      source: :pd_go_west,
      clips: [{3500, 60}],
      music: :pd_music_lark
    },
    %{
      path:
        "movies/The Hunchback of Notre Dame (1923) {tmdb-18987}/The Hunchback of Notre Dame (1923).mkv",
      source: :pd_the_hunchback_of_notre_dame,
      clips: [{3000, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/The Hands of Orlac (1924) {tmdb-2974}/The Hands of Orlac (1924).mkv",
      source: :pd_the_hands_of_orlac,
      clips: [{2500, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/Way Down East (1920) {tmdb-31509}/Way Down East (1920).mkv",
      source: :pd_way_down_east,
      clips: [{8300, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/Speedy (1928) {tmdb-22595}/Speedy (1928).mkv",
      source: :pd_speedy,
      clips: [{3500, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/Foolish Wives (1922) {tmdb-35227}/Foolish Wives (1922).mkv",
      source: :pd_foolish_wives,
      clips: [{4000, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path: "movies/The Kid Brother (1927) {tmdb-16661}/The Kid Brother (1927).mkv",
      source: :pd_the_kid_brother,
      clips: [{4300, 60}],
      music: :pd_music_lark
    },
    %{
      path: "movies/Orphans of the Storm (1921) {tmdb-42511}/Orphans of the Storm (1921).mkv",
      source: :pd_orphans_of_the_storm,
      clips: [{4000, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path: "movies/The Last Command (1928) {tmdb-52679}/The Last Command (1928).mkv",
      source: :pd_the_last_command,
      clips: [{3000, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path: "movies/The Doll (1919) {tmdb-48256}/The Doll (1919).mkv",
      source: :pd_the_doll,
      clips: [{1500, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/Underworld (1927) {tmdb-42565}/Underworld (1927).mkv",
      source: :pd_underworld,
      clips: [{2500, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path: "movies/The Cat and the Canary (1927) {tmdb-76804}/The Cat and the Canary (1927).mkv",
      source: :pd_the_cat_and_the_canary,
      clips: [{2000, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/The Iron Horse (1925) {tmdb-71068}/The Iron Horse (1925).mkv",
      source: :pd_the_iron_horse,
      clips: [{4000, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/Girl Shy (1924) {tmdb-40574}/Girl Shy (1924).mkv",
      source: :pd_girl_shy,
      clips: [{4700, 60}],
      music: :pd_music_lark
    },
    %{
      path: "movies/Waxworks (1924) {tmdb-27522}/Waxworks (1924).mkv",
      source: :pd_waxworks,
      clips: [{2000, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/The Oyster Princess (1919) {tmdb-48591}/The Oyster Princess (1919).mkv",
      source: :pd_the_oyster_princess,
      clips: [{1500, 60}],
      music: :pd_music_figaro
    },
    %{
      path:
        "movies/20,000 Leagues Under the Sea (1916) {tmdb-30266}/20,000 Leagues Under the Sea (1916).mkv",
      source: :pd_20000_leagues_under_the_sea,
      clips: [{2000, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/The Sheik (1921) {tmdb-36841}/The Sheik (1921).mkv",
      source: :pd_the_sheik,
      clips: [{2000, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/Street Angel (1928) {tmdb-28391}/Street Angel (1928).mkv",
      source: :pd_street_angel,
      clips: [{3000, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/Robin Hood (1922) {tmdb-71066}/Robin Hood (1922).mkv",
      source: :pd_robin_hood,
      clips: [{5500, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/Sherlock Holmes (1916) {tmdb-342831}/Sherlock Holmes (1916).mkv",
      source: :pd_sherlock_holmes,
      clips: [{3500, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path:
        "movies/The Four Horsemen of the Apocalypse (1921) {tmdb-31432}/The Four Horsemen of the Apocalypse (1921).mkv",
      source: :pd_the_four_horsemen_of_the_apocalypse,
      clips: [{2400, 60}],
      music: :pd_music_symphony_40
    },
    %{
      path:
        "movies/The Great White Silence (1924) {tmdb-84880}/The Great White Silence (1924).mkv",
      source: :pd_the_great_white_silence,
      clips: [{3000, 60}]
    },
    %{
      path: "movies/The Haunted Castle (1921) {tmdb-6793}/The Haunted Castle (1921).mkv",
      source: :pd_the_haunted_castle,
      clips: [{2400, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/True Heart Susie (1919) {tmdb-36106}/True Heart Susie (1919).mkv",
      source: :pd_true_heart_susie,
      clips: [{2500, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/The Saphead (1920) {tmdb-51392}/The Saphead (1920).mkv",
      source: :pd_the_saphead,
      clips: [{2500, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/The Wizard of Oz (1925) {tmdb-47508}/The Wizard of Oz (1925).mkv",
      source: :pd_the_wizard_of_oz,
      clips: [{2000, 60}],
      music: :pd_music_lark
    },
    %{
      path: "movies/Peter Pan (1924) {tmdb-120672}/Peter Pan (1924).mkv",
      source: :pd_peter_pan,
      clips: [{3500, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/The Wildcat (1921) {tmdb-55648}/The Wildcat (1921).mkv",
      source: :pd_the_wildcat,
      clips: [{2500, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/The Regeneration (1915) {tmdb-86081}/The Regeneration (1915).mkv",
      source: :pd_the_regeneration,
      clips: [{2000, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/The Marriage Circle (1924) {tmdb-96713}/The Marriage Circle (1924).mkv",
      source: :pd_the_marriage_circle,
      clips: [{2500, 60}],
      height: 576,
      music: :pd_music_figaro
    },
    %{
      path: "movies/Alice in Wonderland (1915) {tmdb-87300}/Alice in Wonderland (1915).mkv",
      source: :pd_alice_in_wonderland,
      clips: [{1500, 60}],
      music: :pd_music_lark
    },
    %{
      path: "movies/Salomé (1923) {tmdb-96951}/Salomé (1923).mkv",
      source: :pd_salome,
      clips: [{2000, 60}],
      music: :pd_music_tragic
    },
    %{
      path: "movies/A Trip to Mars (1918) {tmdb-2964}/A Trip to Mars (1918).mkv",
      source: :pd_a_trip_to_mars,
      clips: [{2800, 60}],
      music: :pd_music_italian
    },
    %{
      path: "movies/Dr. Jack (1922) {tmdb-42366}/Dr. Jack (1922).mkv",
      source: :pd_dr_jack,
      clips: [{1800, 60}],
      music: :pd_music_figaro
    },
    %{
      path: "movies/Blind Husbands (1919) {tmdb-70806}/Blind Husbands (1919).mkv",
      source: :pd_blind_husbands,
      clips: [{3000, 60}],
      music: :pd_music_morning
    },
    %{
      path: "movies/Stella Maris (1918) {tmdb-70753}/Stella Maris (1918).mkv",
      source: :pd_stella_maris,
      clips: [{2500, 60}],
      music: :pd_music_morning
    },
    %{
      path:
        "movies/Night of the Living Dead (1968) {tmdb-10331}/Night of the Living Dead (1968).mkv",
      source: :pd_night_of_the_living_dead,
      clips: [{3000, 60}]
    },
    %{
      path: "movies/His Girl Friday (1940) {tmdb-3085}/His Girl Friday (1940).mkv",
      source: :pd_his_girl_friday,
      clips: [{1500, 60}]
    },
    %{
      path:
        "movies/Plan 9 from Outer Space (1957) {tmdb-10513}/Plan 9 from Outer Space (1957).mkv",
      source: :pd_plan_9_from_outer_space,
      clips: [{2200, 60}]
    },
    %{
      path:
        "movies/The Little Shop of Horrors (1960) {tmdb-24452}/The Little Shop of Horrors (1960).mkv",
      source: :pd_the_little_shop_of_horrors,
      clips: [{1500, 60}]
    },
    %{
      path: "movies/White Zombie (1932) {tmdb-26860}/White Zombie (1932).mkv",
      source: :pd_white_zombie,
      clips: [{1500, 60}]
    },
    %{
      path: "movies/The Hitch-Hiker (1953) {tmdb-41462}/The Hitch-Hiker (1953).mkv",
      source: :pd_the_hitch_hiker,
      clips: [{2000, 60}]
    },
    %{
      path: "movies/Tell Your Children (1938) {tmdb-37833}/Tell Your Children (1938).mkv",
      source: :pd_tell_your_children,
      clips: [{2400, 60}],
      height: 480
    }
  ]
}
