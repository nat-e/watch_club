# Copies of the same films in many formats, imported by a filesystem Media Source: containers,
# codecs, track flags, subtitle formats, HDR, Dolby Vision, 8K and a film split in two files.
# Copies of a film share their clip, so they share Watch Progress. The extra copies of Sol
# Levante, Charge, The Daily Dweebs, Caminandes and Cosmos Laundromat use the clips of their
# other copies.

commons = "https://commons.wikimedia.org/w/api.php?action=timedtext&trackformat=srt"
bbb = "movies/Big Buck Bunny (2008) {tmdb-10378}/Big Buck Bunny (2008) - "
bbb_clip = [{120, 90}]
ed = "movies/Elephants Dream (2006) {tmdb-9761}/Elephants Dream (2006) - "

# HDR10 in HEVC: BT.2020 and PQ, and a mastering display with P3 primaries and the given peak,
# in nits
hdr10 = fn preset, x265_params, max_luminance ->
  [
    "-color_primaries",
    "bt2020",
    "-color_trc",
    "smpte2084",
    "-colorspace",
    "bt2020nc",
    "-c:v",
    "libx265",
    "-preset",
    preset,
    "-x265-params",
    "log-level=error:hdr10=1:repeat-headers=1:" <>
      "master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" <>
      "L(#{max_luminance * 10_000},1):" <> x265_params
  ]
end

# swscale converts SDR to PQ with SDR white at 203 nits, as BT.2408 recommends
sdr_to_pq =
  "scale=out_primaries=bt2020:out_transfer=smpte2084:out_color_matrix=bt2020nc:out_range=tv"

%{
  sources: %{
    formats_big_buck_bunny: %{
      title: "Big Buck Bunny",
      author: "Blender Foundation | www.bigbuckbunny.org",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm",
      # The 60 fps 2013 version, whose 1080p copy keeps the 5.1 sound
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Big_Buck_Bunny_4K.webm/Big_Buck_Bunny_4K.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Big_Buck_Bunny_4K.webm&lang=en",
        fre: commons <> "&title=File:Big_Buck_Bunny_4K.webm&lang=fr",
        spa: commons <> "&title=File:Big_Buck_Bunny_4K.webm&lang=es"
      }
    },
    formats_big_buck_bunny_4k: %{
      title: "Big Buck Bunny",
      author: "Blender Foundation | www.bigbuckbunny.org",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/c/c0/Big_Buck_Bunny_4K.webm"
    },
    formats_elephants_dream: %{
      title: "Elephants Dream",
      author:
        "Orange Open Movie Team, Blender Foundation / Netherlands Media Art Institute / www.elephantsdream.org",
      license: "CC BY 2.5",
      license_url: "https://creativecommons.org/licenses/by/2.5/",
      page_url: "https://commons.wikimedia.org/wiki/File:Elephants_Dream_(2006).webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a2/Elephants_Dream_%282006%29.webm/Elephants_Dream_%282006%29.webm.1080p.vp9.webm",
      subtitle_urls: %{
        eng: commons <> "&title=File:Elephants_Dream_(2006).webm&lang=en",
        fre: commons <> "&title=File:Elephants_Dream_(2006).webm&lang=fr"
      }
    },
    # A 4K AV1 encode that keeps the PQ and BT.2020 of Netflix's HDR10 master
    formats_sol_levante: %{
      title: "Sol Levante",
      author: "Akira Saitoh, Production I.G, Netflix",
      license: "CC BY 4.0",
      license_url: "https://creativecommons.org/licenses/by/4.0/",
      page_url: "https://commons.wikimedia.org/wiki/File:Sol_Levante.webm",
      video_url: "https://upload.wikimedia.org/wikipedia/commons/4/44/Sol_Levante.webm"
    },
    formats_charge: %{
      title: "Charge",
      author: "Blender Studio",
      license: "CC BY 4.0",
      license_url: "https://creativecommons.org/licenses/by/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Charge_-_Blender_Open_Movie-full_movie.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/7/7a/Charge_-_Blender_Open_Movie-full_movie.webm"
    },
    formats_daily_dweebs: %{
      title: "The Daily Dweebs",
      author: "Blender Foundation",
      license: "CC BY 4.0",
      license_url: "https://creativecommons.org/licenses/by/4.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:The_Daily_Dweebs_-_Blender_Open_Movie-full_movie.webm",
      # 7680x4320
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/b/b2/The_Daily_Dweebs_-_Blender_Open_Movie-full_movie.webm"
    },
    formats_caminandes_llama_drama: %{
      title: "Caminandes: Llama Drama",
      author: "Pablo Vazquez, Beorn Leonard, Francesco Siddi; music and sound: Jan Morgenstern",
      license: "CC BY 3.0",
      license_url: "https://creativecommons.org/licenses/by/3.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Caminandes-_Llama_Drama_-_Short_Movie.ogv",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/d/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv"
    },
    # Netflix's 4000-nit HDR grade: P3 in PQ, 23.976 fps, without sound
    formats_cosmos_laundromat_hdr: %{
      title: "Cosmos Laundromat (HDR grade)",
      author: "Blender Institute; HDR grade by Netflix and Fotokem's Keep Me Posted",
      license: "CC BY 4.0",
      license_url: "https://creativecommons.org/licenses/by/4.0/",
      page_url: "https://opencontent.netflix.com/",
      video_url:
        "https://s3.amazonaws.com/download.opencontent.netflix.com/CosmosLaundromat/CosmosLaundromat_2k24p_HDR_P3PQ.mp4"
    },
    # The sound of the HDR grade
    formats_cosmos_laundromat: %{
      title: "Cosmos Laundromat",
      author: "Blender Foundation",
      license: "CC BY-SA 3.0",
      license_url: "https://creativecommons.org/licenses/by-sa/3.0/",
      page_url:
        "https://commons.wikimedia.org/wiki/File:Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm",
      video_url:
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/3/36/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm.240p.vp9.webm"
    },
    formats_home_video_font: %{
      title: "Home Video",
      author: "GGBotNet",
      license: "CC0 1.0",
      license_url: "https://creativecommons.org/publicdomain/zero/1.0/",
      page_url: "https://github.com/ggbotnet/fonts-cc0",
      font_url:
        "https://raw.githubusercontent.com/ggbotnet/fonts-cc0/670059749032c2310422b2287c24307b23656080/Home%20Video/TrueType%20(.ttf)/HomeVideo-Regular.ttf",
      font_family: "Home Video"
    }
  },
  files: [
    # Big Buck Bunny: the same 90 s in each format, from the 60 fps 1080p copy with 5.1 sound
    %{
      path: bbb <> "1080p H.264 AC-3 5.1.mkv",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      subtitles: [eng: [:default], fre: [:forced], spa: []],
      chapters: [{0, "Intro"}, {15, "Recap"}, {30, "Chapter 1"}, {75, "Credits"}],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:1080,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-map",
        "0:a:0",
        "-c:v",
        "libx264",
        "-preset",
        "slow",
        "-crf",
        "39",
        "-c:a:0",
        "ac3",
        "-b:a:0",
        "320k",
        "-c:a:1",
        "aac",
        "-b:a:1",
        "128k",
        "-ac:a:1",
        "2",
        "-metadata:s:a",
        "language=eng",
        "-metadata:s:a:0",
        "title=Surround 5.1",
        "-metadata:s:a:1",
        "title=Stereo",
        "-disposition:v:0",
        "default",
        "-disposition:a:0",
        "default",
        "-disposition:a:1",
        "0"
      ]
    },
    %{
      path: bbb <> "HEVC 60 fps mov_text.mp4",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      subtitles: [eng: [:default], fre: []],
      ffmpeg: [
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
        "2",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "default"
      ]
    },
    %{
      path: bbb <> "H.264 cover art.m4v",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      chapters: [{0, "Générique de début"}, {20, "Les écureuils"}, {80, "Générique de fin"}],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p,split[v][c];" <>
          "[c]select='eq(n,600)',scale=640:-2:out_range=pc,format=yuvj420p[cover]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-map",
        "[cover]",
        "-c:v:0",
        "libx264",
        "-preset:v:0",
        "slow",
        "-crf:v:0",
        "33",
        "-c:v:1",
        "mjpeg",
        "-q:v:1",
        "3",
        "-fps_mode:v:1",
        "passthrough",
        "-disposition:v:0",
        "default",
        "-disposition:v:1",
        "attached_pic",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-ac",
        "2",
        "-metadata:s:a:0",
        "language=eng"
      ]
    },
    %{
      path: bbb <> "Xvid MP3.avi",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      sidecars: [eng: [:default], fre: [:forced], spa: [charset: "WINDOWS-1252"]],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=640:360,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "mpeg4",
        "-vtag",
        "XVID",
        "-q:v",
        "14",
        "-bf",
        "2",
        "-c:a",
        "libmp3lame",
        "-b:a",
        "128k",
        "-ac",
        "2"
      ]
    },
    %{
      path: bbb <> "VP9 Opus.webm",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      sidecars: [eng: [format: :vtt]],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libvpx-vp9",
        "-crf",
        "50",
        "-b:v",
        "0",
        "-row-mt",
        "1",
        "-cpu-used",
        "4",
        "-c:a",
        "libopus",
        "-b:a",
        "96k",
        "-ac",
        "2",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "default"
      ]
    },
    %{
      path: bbb <> "AV1 10-bit Opus 5.1.mkv",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p10le[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libsvtav1",
        "-crf",
        "55",
        "-preset",
        "8",
        "-c:a",
        "libopus",
        "-b:a",
        "192k",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "default"
      ]
    },
    %{
      path: bbb <> "Hi10P FLAC ASS.mkv",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      subtitles: [eng: [:default, format: :ass], fre: [format: :ass]],
      font: :formats_home_video_font,
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p10le[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libx264",
        "-profile:v",
        "high10",
        "-preset",
        "slow",
        "-crf",
        "35",
        "-c:a",
        "flac",
        "-ac",
        "2",
        "-sample_fmt",
        "s16",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "default"
      ]
    },
    # NTSC DVD frames, 16:9 in 720x480, 60 fields per second
    %{
      path: bbb <> "MPEG-2 interlaced AC-3 DTS.ts",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]scale=720:480,setsar=32/27,interlace=scan=tff[v];" <>
          "[0:a:0]aformat=channel_layouts=5.1(side)[dts]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-map",
        "[dts]",
        "-c:v",
        "mpeg2video",
        "-flags",
        "+ilme+ildct",
        "-b:v",
        "450k",
        "-maxrate",
        "2000k",
        "-bufsize",
        "1835k",
        "-c:a:0",
        "ac3",
        "-b:a:0",
        "128k",
        "-ac:a:0",
        "2",
        "-c:a:1",
        "dca",
        "-strict",
        "-2",
        "-b:a:1",
        "768k",
        "-metadata:s:a",
        "language=eng"
      ]
    },
    # Like a phone: portrait frames shown in landscape, 30 then 20 then 30 fps, mono PCM
    %{
      path: bbb <> "rotated VFR PCM.mov",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      input_options: ["-noautorotate", "-display_rotation:v:0", "90"],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]select='if(between(t,30,60),not(mod(n,3)),not(mod(n,2)))'," <>
          "scale=-2:720,transpose=clock,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-fps_mode",
        "vfr",
        "-video_track_timescale",
        "600",
        "-c:v",
        "libx264",
        "-preset",
        "slow",
        "-crf",
        "33",
        "-c:a",
        "pcm_s16le",
        "-ac",
        "1",
        "-ar",
        "24000",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "default"
      ]
    },
    %{
      path: bbb <> "three audio tracks PGS VobSub.mkv",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      subtitles: [eng: [:default, format: :pgs], fre: [format: :vobsub]],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-map",
        "0:a:0",
        "-map",
        "0:a:0",
        "-c:v",
        "libx265",
        "-crf",
        "33",
        "-x265-params",
        "log-level=error",
        "-c:a",
        "aac",
        "-b:a:0",
        "128k",
        "-ac:a:0",
        "2",
        "-b:a:1",
        "96k",
        "-ac:a:1",
        "2",
        "-b:a:2",
        "64k",
        "-ac:a:2",
        "1",
        "-metadata:s:a:0",
        "language=eng",
        "-metadata:s:a:0",
        "title=Stereo",
        "-metadata:s:a:1",
        "language=",
        "-metadata:s:a:2",
        "language=eng",
        "-metadata:s:a:2",
        "title=Commentary",
        "-disposition:v:0",
        "default",
        "-disposition:a:0",
        "default",
        "-disposition:a:1",
        "0",
        "-disposition:a:2",
        "comment"
      ]
    },
    %{
      path: bbb <> "no default flags.mkv",
      source: :formats_big_buck_bunny,
      clips: bbb_clip,
      subtitles: [eng: [], fre: []],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]fps=30,scale=-2:720,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libx265",
        "-crf",
        "33",
        "-x265-params",
        "log-level=error",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-ac",
        "2",
        "-metadata:s:a:0",
        "language=eng",
        "-disposition:v:0",
        "0",
        "-disposition:a:0",
        "0"
      ]
    },
    %{
      path: bbb <> "4K HDR10.mkv",
      source: :formats_big_buck_bunny_4k,
      clips: bbb_clip,
      ffmpeg:
        [
          "-filter_complex",
          "[0:v:0]fps=30,scale=3840:2160,#{sdr_to_pq},format=yuv420p10le[v]",
          "-map",
          "[v]",
          "-map",
          "0:a:0",
          "-c:a",
          "eac3",
          "-b:a",
          "256k",
          "-disposition:v:0",
          "default"
        ] ++ hdr10.("fast", "crf=30:vbv-maxrate=1200:vbv-bufsize=2400:max-cll=203,0", 1000)
    },
    # Elephants Dream: one film in two files of 45 s
    %{
      path: ed <> "cd1.mkv",
      source: :formats_elephants_dream,
      clips: [{340, 45}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: ed <> "cd2.mkv",
      source: :formats_elephants_dream,
      clips: [{385, 45}],
      subtitles: [eng: [], fre: []]
    },
    %{
      path: "movies/Sol Levante (2020) {tmdb-688900}/Sol Levante (2020) - 4K HDR10.mkv",
      source: :formats_sol_levante,
      clips: [{40, 75}],
      ffmpeg:
        [
          "-filter_complex",
          "[0:v:0]format=yuv420p10le[v]",
          "-map",
          "[v]",
          "-map",
          "0:a:0",
          "-c:a",
          "aac",
          "-b:a",
          "128k",
          "-disposition:v:0",
          "default"
        ] ++ hdr10.("medium", "crf=30:vbv-maxrate=1700:vbv-bufsize=3400", 1000)
    },
    # Profile 8.1: an HDR10 base layer, made from the SDR film, and one static RPU
    %{
      path: "movies/Charge (2022) {tmdb-1062079}/Charge (2022) - 4K Dolby Vision.mkv",
      source: :formats_charge,
      clips: [{60, 75}],
      dolby_vision: %{
        max_display_mastering_luminance: 1000,
        min_display_mastering_luminance: 1,
        max_content_light_level: 203,
        max_frame_average_light_level: 0
      },
      ffmpeg:
        [
          "-filter_complex",
          "[0:v:0]#{sdr_to_pq},format=yuv420p10le[v]",
          "-map",
          "[v]",
          "-map",
          "0:a:0",
          "-c:a",
          "eac3",
          "-b:a",
          "128k",
          "-metadata:s:a:0",
          "language=eng",
          "-disposition:v:0",
          "default"
        ] ++ hdr10.("medium", "crf=30:vbv-maxrate=1500:vbv-bufsize=3000:max-cll=203,0", 1000)
    },
    %{
      path: "movies/The Daily Dweebs (2017) {tmdb-498482}/The Daily Dweebs (2017) - 8K.mp4",
      source: :formats_daily_dweebs,
      clips: [{0, 60}],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a:0",
        "-c:v",
        "libx265",
        "-preset",
        "faster",
        "-tag:v",
        "hvc1",
        "-x265-params",
        "log-level=error:crf=30:vbv-maxrate=1500:vbv-bufsize=3000",
        "-c:a",
        "aac",
        "-b:a",
        "128k"
      ]
    },
    # The stereo sound spread to 5.1: the center gets both sides, the LFE their bass, and the
    # surrounds stay silent so that the lossless sound stays small
    %{
      path:
        "movies/Caminandes - Llama Drama (2013) {tmdb-253777}/Caminandes - Llama Drama (2013) - FLAC 5.1.mkv",
      source: :formats_caminandes_llama_drama,
      clips: [{0, 90}],
      ffmpeg: [
        "-filter_complex",
        "[0:v:0]scale=-2:720,setsar=1,format=yuv420p[v];" <>
          "[0:a:0]pan=5.1|FL=FL|FR=FR|FC=0.5*FL+0.5*FR|LFE=0.5*FL+0.5*FR|BL=0*FL|BR=0*FR," <>
          "lowpass=f=120:channels=LFE[a]",
        "-map",
        "[v]",
        "-map",
        "[a]",
        "-c:v",
        "libx265",
        "-crf",
        "30",
        "-x265-params",
        "log-level=error",
        "-c:a",
        "flac",
        "-sample_fmt",
        "s16",
        "-disposition:v:0",
        "default",
        "-disposition:a:0",
        "default"
      ]
    },
    # Frame 7199 of the HDR grade is frame 7200 of the Commons copy, at 300 s: played at 24
    # fps, the 1800 frames from there fit the sound of {300, 75}. Its matrix is unknown: BT.601
    # is assumed
    %{
      path:
        "movies/Cosmos Laundromat (2015) {tmdb-358332}/Cosmos Laundromat (2015) - Netflix HDR grade.mkv",
      source: :formats_cosmos_laundromat_hdr,
      clips: [{300.257, 75.075}],
      inputs: [formats_cosmos_laundromat: {300, 75}],
      ffmpeg:
        [
          "-filter_complex",
          "[0:v:0]setpts=N/(24*TB),scale=in_primaries=smpte432:in_transfer=smpte2084:" <>
            "in_color_matrix=bt601:in_range=tv:out_primaries=bt2020:out_transfer=smpte2084:" <>
            "out_color_matrix=bt2020nc:out_range=tv,format=yuv420p10le[v]",
          "-map",
          "[v]",
          "-map",
          "1:a:0",
          "-r",
          "24",
          "-c:a",
          "aac",
          "-b:a",
          "128k",
          "-ac",
          "2",
          "-metadata:s:a:0",
          "language=eng",
          "-disposition:v:0",
          "default"
        ] ++ hdr10.("fast", "crf=28:vbv-maxrate=1000:vbv-bufsize=2000", 4000)
    }
  ]
}
