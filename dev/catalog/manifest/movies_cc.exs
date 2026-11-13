# Creative Commons films that TMDB lists, from Wikimedia Commons, one clip each.
#
# - `radarr/`: the best known, one file per folder, where Radarr would put it.
# - `movies/`: the others, for a filesystem Media Source, some with sidecar subtitles.
#
# Five clips are the last 90 s of their film, so they end on its credits, with a chapter
# there. Sol Levante, Charge, The Daily Dweebs and Caminandes: Llama Drama share their source
# and clip with their copies in `formats.exs`, and Cosmos Laundromat its clip. Folder names
# write TMDB's colons as " - ", like Radarr does.

commons = "https://commons.wikimedia.org/w/api.php?action=timedtext&trackformat=srt"
cc_by_3 = "https://creativecommons.org/licenses/by/3.0/"
cc_by_4 = "https://creativecommons.org/licenses/by/4.0/"
cc_by_sa_3 = "https://creativecommons.org/licenses/by-sa/3.0/"

%{
  sources: %{
    cc_sintel: %{
      title: "Sintel",
      author: "Blender Foundation, Durian Open Movie Project",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Sintel_movie_4K.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f1/Sintel_movie_4K.webm/Sintel_movie_4K.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Sintel_movie_4K.webm&lang=en",
        fre: commons <> "&title=File:Sintel_movie_4K.webm&lang=fr"
      }
    },
    cc_tears_of_steel: %{
      title: "Tears of Steel",
      author: "Blender Foundation",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/1/10/Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm/Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: "https://download.blender.org/demo/movies/ToS/subtitles/TOS-en.srt",
        fre: "https://download.blender.org/demo/movies/ToS/subtitles/TOS-fr-orig.srt"
      }
    },
    cc_cosmos_laundromat: %{
      title: "Cosmos Laundromat",
      author: "Blender Foundation",
      license: "CC BY-SA 3.0",
      license_url: cc_by_sa_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/3/36/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm",
      subtitle_urls: %{
        eng:
          commons <>
            "&title=File:Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm&lang=en",
        fre:
          commons <>
            "&title=File:Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm&lang=fr"
      }
    },
    # The source of formats.exs, so both copies share one download
    cc_caminandes_llama_drama: %{
      title: "Caminandes: Llama Drama",
      author: "Pablo Vazquez, Beorn Leonard, Francesco Siddi; music and sound: Jan Morgenstern",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Caminandes-_Llama_Drama_-_Short_Movie.ogv",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/d/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv"
    },
    cc_caminandes_gran_dillama: %{
      title: "Caminandes: Gran Dillama",
      author: "Pablo Vazquez, Beorn Leonard, Francesco Siddi; soundtrack: Jan Morgenstern",
      license: "CC BY-SA 3.0",
      license_url: cc_by_sa_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Caminandes_-_Gran_Dillama_-_Blender_Foundation's_new_Open_Movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/7/7c/Caminandes_-_Gran_Dillama_-_Blender_Foundation%27s_new_Open_Movie.webm/Caminandes_-_Gran_Dillama_-_Blender_Foundation%27s_new_Open_Movie.webm.1080p.vp9.webm"
    },
    cc_caminandes_llamigos: %{
      title: "Caminandes: Llamigos",
      author: "Blender Foundation",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Caminandes_3_-_Llamigos_-_Blender_Animated_Short.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/ab/Caminandes_3_-_Llamigos_-_Blender_Animated_Short.webm/Caminandes_3_-_Llamigos_-_Blender_Animated_Short.webm.1080p.vp9.webm"
    },
    cc_glass_half: %{
      title: "Glass Half",
      author: "Blender Foundation",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Glass_Half_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/0/02/Glass_Half_-_Blender_Open_Movie-full_movie.webm/Glass_Half_-_Blender_Open_Movie-full_movie.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Glass_Half_-_Blender_Open_Movie-full_movie.webm&lang=en",
        fre: commons <> "&title=File:Glass_Half_-_Blender_Open_Movie-full_movie.webm&lang=fr"
      }
    },
    # The source of formats.exs, so both copies share one download
    cc_daily_dweebs: %{
      title: "The Daily Dweebs",
      author: "Blender Foundation",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Daily_Dweebs_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/b/b2/The_Daily_Dweebs_-_Blender_Open_Movie-full_movie.webm"
    },
    cc_hero: %{
      title: "HERO",
      author: "Blender Foundation",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:HERO_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/a/a9/HERO_-_Blender_Open_Movie-full_movie.webm"
    },
    cc_spring: %{
      title: "Spring",
      author: "Andy Goralczyk / Blender Foundation",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url: "https://commons.wikimedia.org/wiki/File:Spring_-_Blender_Open_Movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/a/a5/Spring_-_Blender_Open_Movie.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Spring_-_Blender_Open_Movie.webm&lang=en",
        fre: commons <> "&title=File:Spring_-_Blender_Open_Movie.webm&lang=fr"
      }
    },
    cc_coffee_run: %{
      title: "Coffee Run",
      author: "Blender Foundation",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Coffee_Run_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/3/3f/Coffee_Run_-_Blender_Open_Movie-full_movie.webm"
    },
    cc_sprite_fright: %{
      title: "Sprite Fright",
      author: "Blender Studio",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Sprite_Fright_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/7/76/Sprite_Fright_-_Blender_Open_Movie-full_movie.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Sprite_Fright_-_Blender_Open_Movie-full_movie.webm&lang=en"
      }
    },
    # The source of formats.exs, so both copies share one download
    cc_charge: %{
      title: "Charge",
      author: "Blender Studio",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Charge_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/7/7a/Charge_-_Blender_Open_Movie-full_movie.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Charge_-_Blender_Open_Movie-full_movie.webm&lang=en",
        fre: commons <> "&title=File:Charge_-_Blender_Open_Movie-full_movie.webm&lang=fr"
      }
    },
    cc_wing_it: %{
      title: "Wing It!",
      author: "Blender Studio",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:WING_IT!_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/3/38/WING_IT%21_-_Blender_Open_Movie-full_movie.webm/WING_IT%21_-_Blender_Open_Movie-full_movie.webm.1080p.vp9.webm"
    },
    cc_singularity: %{
      title: "Singularity",
      author: "Blender Studio",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:SINGULARITY_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f2/SINGULARITY_-_Blender_Open_Movie-full_movie.webm/SINGULARITY_-_Blender_Open_Movie-full_movie.webm.1080p.vp9.webm"
    },
    # The HDR10 source of formats.exs, so both copies share one download
    cc_sol_levante: %{
      title: "Sol Levante",
      author: "Akira Saitoh, Production I.G, Netflix",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url: "https://commons.wikimedia.org/wiki/File:Sol_Levante.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/4/44/Sol_Levante.webm"
    },
    cc_dominion: %{
      title: "Dominion",
      author: "Chris Delforce, Farm Transparency Project",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url: "https://commons.wikimedia.org/wiki/File:Dominion_(2018)_–_full_documentary.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/0/0b/Dominion_%282018%29_%E2%80%93_full_documentary.webm/Dominion_%282018%29_%E2%80%93_full_documentary.webm.1080p.vp9.webm"
    },
    cc_panopticon: %{
      title: "Panopticon",
      author: "Peter Vlemmix",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:FULL_DOCUMENTARY_-_Panopticon_privacy_-_Peter_Vlemmix.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/0/0e/FULL_DOCUMENTARY_-_Panopticon_privacy_-_Peter_Vlemmix.webm"
    },
    cc_paywall: %{
      title: "Paywall: The Business of Scholarship",
      author: "Jason Schmitt",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url:
        "https://commons.wikimedia.org/wiki/File:2018_documentary_'Paywall_–_The_Business_of_Scholarship'.ogg",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/b/bb/2018_documentary_%27Paywall_%E2%80%93_The_Business_of_Scholarship%27.ogg"
    },
    cc_other_lily: %{
      title: "Other Lily",
      author: "David Romero",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:David_Romero_-_Other_Lily_(2015).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/6/6b/David_Romero_-_Other_Lily_%282015%29.webm"
    },
    cc_spirit_chaser: %{
      title: "Spirit Chaser",
      author: "Karl Pajak",
      license: "CC BY-SA 3.0",
      license_url: cc_by_sa_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Karl_Pajak_-_Spirit_Chaser_(2016).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/ca/Karl_Pajak_-_Spirit_Chaser_%282016%29.webm/Karl_Pajak_-_Spirit_Chaser_%282016%29.webm.1080p.vp9.webm"
    },
    cc_roadkill: %{
      title: "Roadkill",
      author: "Leszek Mozga",
      license: "CC BY-SA 3.0",
      license_url: cc_by_sa_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Leszek_Mozga_-_Roadkill_(2018).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/ba/Leszek_Mozga_-_Roadkill_%282018%29.webm/Leszek_Mozga_-_Roadkill_%282018%29.webm.1080p.vp9.webm"
    },
    cc_beware_of_bunny: %{
      title: "Beware of Bunny",
      author: "Becky Gill",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Becky_Gill_-_Beware_of_Bunny_(2015).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/23/Becky_Gill_-_Beware_of_Bunny_%282015%29.webm/Becky_Gill_-_Beware_of_Bunny_%282015%29.webm.1080p.vp9.webm"
    },
    cc_fox_tale: %{
      title: "Fox Tale",
      author: "Doosun Shin",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Fox_Tale_-_Official_(2015).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/6/63/Fox_Tale_-_Official_%282015%29.webm"
    },
    cc_midnight_snack: %{
      title: "Midnight Snack",
      author: "David Romero",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:David_Romero_-_Midnight_Snack_(2014).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/2f/David_Romero_-_Midnight_Snack_%282014%29.webm/David_Romero_-_Midnight_Snack_%282014%29.webm.1080p.vp9.webm"
    },
    cc_pine_devil: %{
      title: "Pine Devil",
      author: "David Romero",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:David_Romero_-_Pine_Devil_(2016).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a6/David_Romero_-_Pine_Devil_%282016%29.webm/David_Romero_-_Pine_Devil_%282016%29.webm.1080p.vp9.webm"
    },
    cc_butterflies: %{
      title: "Butterflies",
      author: "Abby Boyce",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Abby_Boyce_-_Butterflies_(2018).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/5/58/Abby_Boyce_-_Butterflies_%282018%29.webm/Abby_Boyce_-_Butterflies_%282018%29.webm.1080p.vp9.webm"
    },
    cc_reticulum_rex: %{
      title: "Reticulum Rex",
      author:
        "Glenn Otis Brown, Neeru Paharia, Ryan Junell, Benjamen Walker; narrated by Christopher Lydon (Creative Commons)",
      license: "CC BY-SA 1.0",
      license_url: "https://creativecommons.org/licenses/by-sa/1.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Reticulum_Rex_with_subtitles_-_Creative_Commons.ogv",
      # Seeking in the Ogg original takes more requests than Wikimedia allows: this copy
      # keeps its size
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/9/94/Reticulum_Rex_with_subtitles_-_Creative_Commons.ogv/Reticulum_Rex_with_subtitles_-_Creative_Commons.ogv.360p.mpeg4.mov",
      subtitle_urls: %{
        eng:
          commons <>
            "&title=File:Reticulum_Rex_with_subtitles_-_Creative_Commons.ogv&lang=en"
      }
    },
    cc_my_moon: %{
      title: "My Moon",
      author: "Nikolay Prodanov",
      license: "CC BY 4.0",
      license_url: cc_by_4,
      page_url: "https://commons.wikimedia.org/wiki/File:Nikolay_Prodanov_-_My_Moon.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/1/13/Nikolay_Prodanov_-_My_Moon.webm/Nikolay_Prodanov_-_My_Moon.webm.1080p.vp9.webm"
    },
    cc_colourful: %{
      title: "Colourful",
      author: "Seryung Lee (Dimlight)",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Seryung_Lee_-_Colourful_(2018).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/45/Seryung_Lee_-_Colourful_%282018%29.webm/Seryung_Lee_-_Colourful_%282018%29.webm.1080p.vp9.webm"
    },
    cc_ada_and_zangemann: %{
      title: "Ada & Zangemann: A Tale of Software, Skateboards, and Raspberry Ice Cream",
      author:
        "Free Software Foundation Europe; Matthias Kirschner (idea and script), Sandra Brandstätter (illustrations)",
      license: "CC BY-SA 4.0",
      license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Ada_%26_Zangemann_-_A_Tale_of_Software,_Skateboards,_and_Raspberry_Ice_Cream.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/23/Ada_%26_Zangemann_-_A_Tale_of_Software%2C_Skateboards%2C_and_Raspberry_Ice_Cream.webm/Ada_%26_Zangemann_-_A_Tale_of_Software%2C_Skateboards%2C_and_Raspberry_Ice_Cream.webm.1080p.vp9.webm"
    },
    cc_no_need_to_rush_life: %{
      title: "No Need to Rush Life",
      author: "Jona Melvin Grobe",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url:
        "https://commons.wikimedia.org/wiki/File:Jona_Melvin_Grobe_-_No_Need_to_Rush_Life_(2022).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/2/29/Jona_Melvin_Grobe_-_No_Need_to_Rush_Life_%282022%29.webm"
    },
    cc_096: %{
      title: "096",
      author: "MrKlay (Klay Abele)",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:096_-_SCP_Short_Film.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/2f/096_-_SCP_Short_Film.webm/096_-_SCP_Short_Film.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:096_-_SCP_Short_Film.webm&lang=en",
        fre: commons <> "&title=File:096_-_SCP_Short_Film.webm&lang=fr"
      }
    },
    cc_eskimal: %{
      title: "Eskimal",
      author: "Homero Ramírez Tena",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:ESKIMAL.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/c/ca/ESKIMAL.webm"
    },
    cc_little_tombstone: %{
      title: "Little Tombstone",
      author: "Frédéric Azais, Théo Di Malta, Benjamin Leymonerie, Adrien Quillet",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:Little_tombstone.ogv",
      # Seeking in the Ogg original takes more requests than Wikimedia allows
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/21/Little_tombstone.ogv/Little_tombstone.ogv.480p.vp9.webm"
    },
    cc_pendatang: %{
      title: "Pendatang",
      author: "Kuman Pictures",
      license: "CC BY 3.0",
      license_url: cc_by_3,
      page_url: "https://commons.wikimedia.org/wiki/File:PENDATANG_(2023)_full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/6/62/PENDATANG_%282023%29_full_movie.webm/PENDATANG_%282023%29_full_movie.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:PENDATANG_(2023)_full_movie.webm&lang=en"
      }
    }
  },
  files: [
    # Radarr
    %{
      path: "radarr/Sintel (2010) {tmdb-45745}/Sintel (2010).mkv",
      source: :cc_sintel,
      clips: [{105, 75}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: "radarr/Tears of Steel (2012) {tmdb-133701}/Tears of Steel (2012).mp4",
      source: :cc_tears_of_steel,
      clips: [{188, 60}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: "radarr/Cosmos Laundromat (2015) {tmdb-358332}/Cosmos Laundromat (2015).mkv",
      source: :cc_cosmos_laundromat,
      clips: [{300, 75}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path:
        "radarr/Caminandes - Llama Drama (2013) {tmdb-253777}/Caminandes - Llama Drama (2013).mkv",
      source: :cc_caminandes_llama_drama,
      clips: [{0, 90}],
      codec: :h264
    },
    %{
      path:
        "radarr/Caminandes - Gran Dillama (2013) {tmdb-253774}/Caminandes - Gran Dillama (2013).mkv",
      source: :cc_caminandes_gran_dillama,
      clips: [{5, 75}]
    },
    %{
      path: "radarr/Caminandes - Llamigos (2016) {tmdb-406956}/Caminandes - Llamigos (2016).mp4",
      source: :cc_caminandes_llamigos,
      clips: [{12, 60}],
      codec: :h264
    },
    %{
      path: "radarr/Glass Half (2015) {tmdb-420577}/Glass Half (2015).mkv",
      source: :cc_glass_half,
      clips: [{103, 90}],
      subtitles: [eng: [], fre: []],
      chapters: [{0, "Chapter 1"}, {68, "Credits"}]
    },
    %{
      path: "radarr/The Daily Dweebs (2017) {tmdb-498482}/The Daily Dweebs (2017).mkv",
      source: :cc_daily_dweebs,
      clips: [{0, 60}]
    },
    %{
      path: "radarr/HERO (2018) {tmdb-615324}/HERO (2018).mkv",
      source: :cc_hero,
      clips: [{50, 60}]
    },
    %{
      path: "radarr/Spring (2019) {tmdb-593048}/Spring (2019).mkv",
      source: :cc_spring,
      clips: [{176, 75}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: "radarr/Coffee Run (2020) {tmdb-717986}/Coffee Run (2020).mkv",
      source: :cc_coffee_run,
      clips: [{94, 90}],
      chapters: [{0, "Chapter 1"}, {70, "Credits"}]
    },
    %{
      path: "radarr/Sprite Fright (2024) {tmdb-891761}/Sprite Fright (2024).mkv",
      source: :cc_sprite_fright,
      clips: [{156, 75}],
      subtitles: [eng: []]
    },
    %{
      path: "radarr/Charge (2022) {tmdb-1062079}/Charge (2022).mkv",
      source: :cc_charge,
      clips: [{60, 75}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: "radarr/Wing It! (2023) {tmdb-1177628}/Wing It! (2023).mkv",
      source: :cc_wing_it,
      clips: [{147, 90}],
      codec: :h264,
      chapters: [{0, "Chapter 1"}, {38, "Credits"}]
    },
    %{
      path: "radarr/Singularity (2026) {tmdb-1687677}/Singularity (2026).mkv",
      source: :cc_singularity,
      clips: [{98, 75}]
    },
    %{
      path: "radarr/Sol Levante (2020) {tmdb-688900}/Sol Levante (2020).mkv",
      source: :cc_sol_levante,
      clips: [{40, 75}],
      # The HDR10 source tone-mapped to SDR, at CRF 36 because its particles cost twice as much
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]scale=-2:720:in_transfer=smpte2084:out_transfer=bt709:in_primaries=bt2020:" <>
          "out_primaries=bt709:in_color_matrix=bt2020:out_color_matrix=bt709:intent=perceptual," <>
          "format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-color_primaries",
        "bt709",
        "-color_trc",
        "bt709",
        "-colorspace",
        "bt709",
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
        "128k",
        "-ac",
        "2"
      ]
    },
    %{
      path: "radarr/Dominion (2018) {tmdb-472796}/Dominion (2018).mkv",
      source: :cc_dominion,
      clips: [{120, 60}],
      codec: :h264
    },
    %{
      path: "radarr/Panopticon (2012) {tmdb-139893}/Panopticon (2012).mp4",
      source: :cc_panopticon,
      clips: [{890, 60}],
      codec: :h264
    },
    %{
      path:
        "radarr/Paywall - The Business of Scholarship (2018) {tmdb-548013}/Paywall - The Business of Scholarship (2018).mp4",
      source: :cc_paywall,
      clips: [{300, 75}],
      height: 300
    },
    %{
      path: "radarr/Other Lily (2017) {tmdb-505920}/Other Lily (2017).mkv",
      source: :cc_other_lily,
      clips: [{5, 60}],
      codec: :h264
    },

    # Filesystem
    %{
      path: "movies/Spirit Chaser (2016) {tmdb-1119357}/Spirit Chaser (2016).mkv",
      source: :cc_spirit_chaser,
      clips: [{9, 75}]
    },
    %{
      path: "movies/Roadkill (2019) {tmdb-596433}/Roadkill (2019).mkv",
      source: :cc_roadkill,
      clips: [{192, 60}],
      codec: :h264
    },
    %{
      path: "movies/Beware of Bunny (2015) {tmdb-1605817}/Beware of Bunny (2015).mkv",
      source: :cc_beware_of_bunny,
      clips: [{90, 75}]
    },
    %{
      path: "movies/Fox Tale (2015) {tmdb-386502}/Fox Tale (2015).mkv",
      source: :cc_fox_tale,
      clips: [{5, 60}],
      codec: :h264
    },
    %{
      path: "movies/Midnight Snack (2014) {tmdb-435712}/Midnight Snack (2014).mkv",
      source: :cc_midnight_snack,
      clips: [{5, 75}]
    },
    %{
      path: "movies/Pine Devil (2016) {tmdb-435704}/Pine Devil (2016).mkv",
      source: :cc_pine_devil,
      clips: [{40, 75}]
    },
    %{
      path: "movies/Butterflies (2018) {tmdb-885487}/Butterflies (2018).mkv",
      source: :cc_butterflies,
      clips: [{44, 90}],
      chapters: [{0, "Chapter 1"}, {80, "Credits"}]
    },
    %{
      path: "movies/Reticulum Rex (2003) {tmdb-498198}/Reticulum Rex (2003).mkv",
      source: :cc_reticulum_rex,
      clips: [{28, 75}],
      height: 288,
      codec: :h264,
      sidecars: [eng: []]
    },
    %{
      path: "movies/My Moon (2017) {tmdb-498193}/My Moon (2017).mp4",
      source: :cc_my_moon,
      clips: [{40, 75}]
    },
    %{
      path: "movies/Colourful (2018) {tmdb-1123203}/Colourful (2018).mkv",
      source: :cc_colourful,
      clips: [{24, 60}],
      codec: :h264
    },
    %{
      path:
        "movies/Ada & Zangemann - A Tale of Software, Skateboards, and Raspberry Icre Cream (2024) {tmdb-1385292}/Ada & Zangemann - A Tale of Software, Skateboards, and Raspberry Icre Cream (2024).mkv",
      source: :cc_ada_and_zangemann,
      clips: [{150, 75}]
    },
    %{
      path: "movies/No Need to Rush Life (2022) {tmdb-1631991}/No Need to Rush Life (2022).mkv",
      source: :cc_no_need_to_rush_life,
      clips: [{18, 75}]
    },
    %{
      path: "movies/096 (2020) {tmdb-1696028}/096 (2020).mkv",
      source: :cc_096,
      clips: [{141, 75}],
      sidecars: [eng: [], fre: [:forced]]
    },
    %{
      path: "movies/Eskimal (2011) {tmdb-510913}/Eskimal (2011).mkv",
      source: :cc_eskimal,
      clips: [{36, 75}]
    },
    %{
      path: "movies/Little Tombstone (2011) {tmdb-259800}/Little Tombstone (2011).mkv",
      source: :cc_little_tombstone,
      clips: [{232, 90}],
      height: 480,
      codec: :h264,
      chapters: [{0, "Chapter 1"}, {53, "Credits"}]
    },
    %{
      path: "movies/Pendatang (2023) {tmdb-1072528}/Pendatang (2023).mkv",
      source: :cc_pendatang,
      clips: [{160, 75}],
      sidecars: [eng: []]
    }
  ]
}
