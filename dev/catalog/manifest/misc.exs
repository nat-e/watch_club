# Sports Events, one long film and Unmatched Media, from Wikimedia Commons.
#
# - `sportarr/`: one file per Sports Event, where Sportarr would put it:
#   `<League name>/Season <first year of the season>/`, named with Sportarr's default format.
# - `sports/`: the two days of one Sports Event, for a filesystem Media Source, named as its
#   Parts `pt1` and `pt2` like Sportarr's multi-part files.
# - `movies/Orang-U…`: a whole 47-minute film at its own 300p, to test long scrubbing and resuming.
# - `movies/<Title> (<Year>)/`: shorts TMDB doesn't list, so they stay Unmatched Media.
#
# Rally footage of foliage is costly to encode, so it gets CRF 35 instead of the default 30.

rally_encoding = [
  "-filter_complex",
  "[0:v:0]scale=-2:720,format=yuv420p[v]",
  "-map",
  "[v]",
  "-map",
  "0:a:0",
  "-c:v",
  "libx265",
  "-crf",
  "35",
  "-tag:v",
  "hvc1",
  "-x265-params",
  "log-level=error",
  "-c:a",
  "aac",
  "-b:a",
  "128k",
  "-ac",
  "2"
]

%{
  sources: %{
    misc_wrc_croatia_2022_day_1: %{
      title: "WRC Croatia 2022 - day 1",
      author: "komik video",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:WRC_Croatia_2022_-_day_1.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/8/82/WRC_Croatia_2022_-_day_1.webm"
    },
    misc_mexico_city_eprix_2018: %{
      title: "Mexico City E-Prix 2018",
      author: "Rivera0997",
      license: "CC BY-SA 4.0",
      license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:Mexico_City_E-Prix_2018.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/d/db/Mexico_City_E-Prix_2018.webm"
    },
    misc_punta_del_este_eprix_2015_first_lap: %{
      title: "2015 Punta del Este ePrix - Video - First lap",
      author: "NaBUru38",
      license: "CC BY 4.0",
      license_url: "https://creativecommons.org/licenses/by/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:2015_Punta_del_Este_ePrix_-_Video_-_First_lap.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/8/8f/2015_Punta_del_Este_ePrix_-_Video_-_First_lap.webm"
    },
    misc_norisring_2019_dtm_sunday_race: %{
      title: "2019 Norisring Speedweekend - DTM Sunday race 05",
      author: "NaBUru38",
      license: "CC BY-SA 4.0",
      license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:2019_Norisring_Speedweekend_-_DTM_Sunday_race_05.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/c/c3/2019_Norisring_Speedweekend_-_DTM_Sunday_race_05.webm"
    },
    misc_wrc_croatia_2024_friday: %{
      title: "WRC Croatia 2024 - Friday",
      author: "komik video",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:WRC_Croatia_2024_-_Friday.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/0/0f/WRC_Croatia_2024_-_Friday.webm"
    },
    misc_wrc_croatia_2024_saturday: %{
      title: "WRC Croatia 2024 - Saturday",
      author: "komik video",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:WRC_Croatia_2024_-_Saturday.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/b/b2/WRC_Croatia_2024_-_Saturday.webm"
    },
    misc_orang_u: %{
      title: "Orang-U: An Ape Goes to College",
      author: "Matt Lee",
      license: "CC BY-SA 4.0",
      license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Orang-U_--_An_Ape_Goes_To_College_(2017).ogv",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/e/e2/Orang-U_--_An_Ape_Goes_To_College_%282017%29.ogv"
    },
    misc_sheep_possible: %{
      title: "Sheep Possible",
      author: "Aline Dykmans",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Aline_Dykmans_-_Sheep_Possible_(2015).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/1/1e/Aline_Dykmans_-_Sheep_Possible_%282015%29.webm"
    },
    misc_bye_bye_birdy: %{
      title: "Bye Bye Birdy",
      author: "Clément Masson",
      license: "CC BY-SA 3.0",
      license_url: "https://creativecommons.org/licenses/by-sa/3.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Clement_Masson_-_Bye_Bye_Birdy_(2017).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/f/fc/Clement_Masson_-_Bye_Bye_Birdy_%282017%29.webm"
    },
    misc_wormdog: %{
      title: "Wormdog",
      author: "Simone Kousol Graham; music by Tomáš Andel",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Simone_Kousol_Graham_-_Wormdog_(2019).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/3/32/Simone_Kousol_Graham_-_Wormdog_%282019%29.webm"
    }
  },
  files: [
    # Sports Events managed by Sportarr
    %{
      path:
        "sportarr/WRC/Season 2022/WRC - S2022E03 - WRC Croatia Rally - 720p - sportarr-ev-369578.mkv",
      source: :misc_wrc_croatia_2022_day_1,
      clips: [{230, 60}],
      ffmpeg: rally_encoding
    },
    # The whole 24 s video
    %{
      path:
        "sportarr/Formula E/Season 2017/Formula E - S2017E05 - Mexico City ePrix - 720p - sportarr-ev-174620.mkv",
      source: :misc_mexico_city_eprix_2018,
      clips: [{0, 25}]
    },
    # The whole 27 s video. The podium and victory lap are other files, so they can't be clips
    %{
      path:
        "sportarr/Formula E/Season 2015/Formula E - S2015E03 - Punta del Este ePrix - 720p - sportarr-ev-174596.mkv",
      source: :misc_punta_del_este_eprix_2015_first_lap,
      clips: [{0, 28}]
    },
    # The whole 11 s video
    %{
      path:
        "sportarr/DTM/Season 2019/DTM - S2019E04 - Norisring - 720p - sportarr-ev-2621992.mkv",
      source: :misc_norisring_2019_dtm_sunday_race,
      clips: [{0, 12}]
    },

    # Two Parts of one Sports Event, for a filesystem Media Source
    %{
      path:
        "sports/WRC/Season 2024/WRC - S2024E04 - pt1 - WRC Croatia Rally - Friday - sportarr-ev-369605.mkv",
      source: :misc_wrc_croatia_2024_friday,
      clips: [{25, 120}],
      ffmpeg: rally_encoding
    },
    %{
      path:
        "sports/WRC/Season 2024/WRC - S2024E04 - pt2 - WRC Croatia Rally - Saturday - sportarr-ev-369605.mkv",
      source: :misc_wrc_croatia_2024_saturday,
      clips: [{20, 120}],
      ffmpeg: rally_encoding
    },

    # The whole film, small enough for Git LFS: 300p, as its source, CRF 36 and 48 kb/s audio
    %{
      path:
        "movies/Orang-U - An Ape Goes to College (2017) {tmdb-477375}/Orang-U - An Ape Goes to College (2017).mkv",
      source: :misc_orang_u,
      clips: [{0, 2853}],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]scale=-2:300,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libx265",
        "-crf",
        "36",
        "-tag:v",
        "hvc1",
        "-x265-params",
        "log-level=error",
        "-c:a",
        "aac",
        "-b:a",
        "48k",
        "-ac",
        "2"
      ]
    },

    # Unmatched Media: TMDB finds no movie with these titles
    %{
      path: "movies/Sheep Possible (2015)/Sheep Possible (2015).mkv",
      source: :misc_sheep_possible,
      clips: [{15, 60}]
    },
    %{
      path: "movies/Bye Bye Birdy (2017)/Bye Bye Birdy (2017).mkv",
      source: :misc_bye_bye_birdy,
      clips: [{5, 60}]
    },
    %{
      path: "movies/Wormdog (2019)/Wormdog (2019).mkv",
      source: :misc_wormdog,
      clips: [{15, 60}]
    }
  ]
}
