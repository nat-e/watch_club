# TV shows.
#
# BBS: The Documentary (2005), imported by a filesystem Media Source. Each episode keeps its
# real opening and its real credits, with a bit of the middle, about 4 minutes in all. Episodes
# 1 to 7 open with the same 21 s BBS logo and music, their Intro, found from their shared audio.
# Compression (episode 8) has no such logo, and the credits of every episode have their own
# music, so the Intro of Compression and all Credits come from chapters only. The files are
# numbered as Sonarr numbers them after TVDB splits Baud in two, and No Carrier (episode 7) has
# no file, so the show stays incomplete. The 640x480 sources stay at 480 lines.
#
# Bonanza (1959), managed by Sonarr: 6 episodes of each of its first 2 seasons, one 75 s
# dialogue scene each. See the Bonanza sources for why these episodes are in the public domain.

# The original uploads, 640x480 (624x480 for Baud), copied from the Internet Archive
bbs = fn number, title, directory ->
  %{
    title: "BBS: The Documentary, episode #{number}: #{title}",
    author: "Jason Scott",
    license: "CC BY-SA 3.0",
    license_url: "https://creativecommons.org/licenses/by-sa/3.0/",
    page_url:
      "https://commons.wikimedia.org/wiki/File:BBS_The_Documentary,_Episode_#{number}.webm",
    video_url:
      "https://upload.wikimedia.org/wikipedia/commons/#{directory}/BBS_The_Documentary%2C_Episode_#{number}.webm"
  }
end

bbs_folder = "tv/BBS - The Documentary (2005) {tmdb-84836}/Season 01"

# Copyright evidence, from the US Copyright Office's public records
# (https://publicrecords.copyright.gov, registration class RE, series "Bonanza", claimant
# National Broadcasting Company, Inc.). A 1959, 1960 or 1961 copyright had to be renewed in its
# 28th year, 1987, 1988 or 1989:
# - NBC renewed every episode registered in 1959 on 1987-12-14, RE0000359894 to RE0000392717,
#   for LP0000021975 ("A Rose for Lotta", 1959-05-07) to LP0000022201 ("A House Divided",
#   1959-12-31): season 1, episodes 1 to 18
# - NBC renewed every episode registered from 1961 on 1989-12-14, RE0000463133 to
#   RE0000463180, starting with LP0000022460 ("The Bride", season 2 episode 18, 1961-01-05)
# - No renewal exists for an episode registered in 1960: season 1 episodes 19 to 32 and season
#   2 episodes 1 to 17. A keyword search of renewals for each episode below finds no NBC or
#   Bonanza record of it (2026-11-13).
# The music stays copyrighted: the theme by Livingston and Evans (RE0000320759, RE0000320760,
# RE0000374585) and David Rose's cues "Ponderosa", "Journey of the Hopefuls" and "Silent
# Thunder" (RE0000418398, RE0000418399, RE0000418407). These prints have no main titles and no
# end credits, and each clip is a dialogue scene in the middle of the episode, without music:
# the PANNs AudioSet tagger gives every 2 s of it a music probability below 0.08. "The
# Hopefuls" and "Silent Thunder" are left out because their cues were renewed.
bonanza = fn file ->
  %{
    title: "Bonanza",
    author: "National Broadcasting Company",
    license: "Public domain",
    license_url: "https://commons.wikimedia.org/wiki/Template:PD-US-not_renewed",
    page_url: "https://archive.org/details/bonanzapd",
    video_url: "https://archive.org/download/bonanzapd/" <> URI.encode(file)
  }
end

bonanza_folder = "sonarr/Bonanza (1959) {tvdb-73378}"

# {season, episode, TVDB title, source file, start of the 75 s scene}
bonanza_episodes = [
  {1, 20, "The Fear Merchants", "Bonanza s01e20 THE FEAR MERCHANTS.mp4", 1490.1},
  {1, 22, "Blood on the Land", "Bonanza s01e22 BLOOD ON THE LAND.mp4", 1048.6},
  {1, 23, "Desert Justice", "Bonanza s01e23 DESERT JUSTICE.mp4", 1629.5},
  {1, 24, "The Stranger", "Bonanza s01e24 THE STRANGER.mp4", 975.1},
  {1, 26, "The Avenger", "Bonanza s01e26 THE AVENGER.mp4", 1202.2},
  {1, 30, "Feet of Clay", "Bonanza s01e30 FEET OF CLAY.mp4", 1212.5},
  {2, 3, "Badge Without Honor", "Bonanza s02e03 BADGE WITHOUT HONOR.mp4", 1342.8},
  {2, 4, "The Mill", "Bonanza s02e04 THE MILL.mp4", 900.7},
  {2, 6, "Denver McKee", "Bonanza s02e06 DENVER MCKEE.mp4", 1365.1},
  {2, 10, "The Last Viking", "Bonanza s02e10 THE LAST VIKING.mp4", 914.1},
  {2, 12, "The Savage", "Bonanza s02e12 THE SAVAGE.mp4", 1542.6},
  {2, 15, "The Blood Line", "Bonanza s02e15 THE BLOOD LINE.mp4", 1048.5}
]

two_digits = &String.pad_leading(Integer.to_string(&1), 2, "0")
bonanza_number = fn season, episode -> "S#{two_digits.(season)}E#{two_digits.(episode)}" end
bonanza_key = &:"tv_bonanza_#{String.downcase(bonanza_number.(&1, &2))}"

# Clips of each episode: its opening, a bit of the middle, its credits
baud_part_1 = [{0, 64}, {688, 56}]
# Part 2 opens with a recap: 16 s of the scene that ends part 1
baud_part_2 = [{704, 16}, {1702, 34}, {2290, 70}]
make_it_pay = [{0, 88}, {1384, 100}, {2763, 52}]
fidonet = [{0, 124}, {1328, 40}, {2563, 77}]
artscene = [{0, 60}, {1290, 131}, {2516, 49}]

%{
  sources:
    Map.merge(
      %{
        tv_bbs_baud: bbs.(1, "Baud", "a/aa"),
        tv_bbs_sysops: bbs.(2, "SysOps and Users", "4/43"),
        tv_bbs_make_it_pay: bbs.(3, "Make It Pay", "f/f0"),
        tv_bbs_fidonet: bbs.(4, "FidoNet", "4/45"),
        tv_bbs_artscene: bbs.(5, "Artscene", "3/3a"),
        tv_bbs_hpac: bbs.(6, "HPAC (Hacking Phreaking Anarchy Cracking)", "3/39"),
        tv_bbs_compression: bbs.(8, "Compression", "a/a0")
      },
      Map.new(bonanza_episodes, fn {season, episode, _title, file, _start} ->
        {bonanza_key.(season, episode), bonanza.(file)}
      end)
    ),
  files:
    [
      %{
        path: "#{bbs_folder}/S01E01 - Baud (1).mkv",
        source: :tv_bbs_baud,
        clips: baud_part_1,
        height: 480
      },
      %{
        path: "#{bbs_folder}/S01E02 - Baud (2).mkv",
        source: :tv_bbs_baud,
        clips: baud_part_2,
        height: 480,
        chapters: [{0, "Recap"}, {16, "Chapter 2"}, {50, "Credits"}]
      },
      # Both parts of Baud in one file, without chapters
      %{
        path: "#{bbs_folder}/S01E01-E02 - Baud.mkv",
        source: :tv_bbs_baud,
        clips: baud_part_1 ++ baud_part_2,
        height: 480
      },
      %{
        path: "#{bbs_folder}/S01E03 - SysOps and Users.mkv",
        source: :tv_bbs_sysops,
        clips: [{0, 94}, {1370, 84}, {2626, 62}],
        height: 480
      },
      # Two episodes in one file
      %{
        path: "#{bbs_folder}/S01E04-E05 - Make It Pay + FidoNet.mkv",
        source: :tv_bbs_make_it_pay,
        clips:
          make_it_pay ++
            Enum.map(fidonet, fn {start, duration} -> {:tv_bbs_fidonet, start, duration} end),
        height: 480
      },
      # Two copies of Artscene, in HEVC 480p and in H.264 360p
      %{
        path: "#{bbs_folder}/S01E06 - Artscene.mkv",
        source: :tv_bbs_artscene,
        clips: artscene,
        height: 480
      },
      %{
        path: "#{bbs_folder}/S01E06 - Artscene.h264.mkv",
        source: :tv_bbs_artscene,
        clips: artscene,
        height: 360,
        codec: :h264
      },
      %{
        path: "#{bbs_folder}/S01E07 - HPAC (Hacking Phreaking Anarchy Cracking).mkv",
        source: :tv_bbs_hpac,
        clips: [{0, 74}, {1114, 100}, {2241, 66}],
        height: 480
      },
      # Text cards, then the title sequence, its Intro
      %{
        path: "#{bbs_folder}/S01E09 - Compression.mkv",
        source: :tv_bbs_compression,
        clips: [{0, 61}, {588, 111}, {1179, 68}],
        height: 480,
        chapters: [{0, "Chapter 1"}, {44, "Intro"}, {61, "Chapter 3"}, {172, "Credits"}]
      }
    ] ++
      Enum.map(bonanza_episodes, fn {season, episode, title, _file, start} ->
        %{
          path:
            "#{bonanza_folder}/Season #{two_digits.(season)}/" <>
              "Bonanza - #{bonanza_number.(season, episode)} - #{title}.mkv",
          source: bonanza_key.(season, episode),
          clips: [{start, 75}],
          height: 480
        }
      end)
}
