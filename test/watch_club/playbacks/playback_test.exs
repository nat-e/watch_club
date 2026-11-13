defmodule WatchClub.Playbacks.PlaybackTest do
  use WatchClub.DataCase, async: true

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Calculations.TextTrackChoices
  alias WatchClub.Playbacks.Calculations.TextTrackChoices.Choice

  describe "text_track_choices" do
    test "offers one Text Track per language and region among English, French and the original language" do
      media =
        movie_media("es",
          audio: [%{language: "spa"}],
          text: [
            %{language: "en", title: "English SDH", sdh?: true},
            %{language: "en", title: "English"},
            %{language: "en", title: "English forced", forced?: true},
            %{language: "en", title: "English PGS", codec: "hdmv_pgs_subtitle"},
            %{language: "es", title: "Spanish"},
            %{language: "es", title: "Spanish again"},
            %{language: "de", title: "German"},
            %{language: "fr-FR", title: "VFF"},
            %{language: "fr-CA", title: "VFQ"}
          ]
        )

      assert %TextTrackChoices{choices: choices} = text_track_choices(media, generate(user()))

      assert Enum.map(choices, &{&1.language, &1.text_track.title}) == [
               {"en", "English"},
               {"es", "Spanish"},
               {"fr-CA", "VFQ"},
               {"fr-FR", "VFF"}
             ]
    end

    test "offers SDH Text Tracks to a User who prefers them" do
      media =
        movie_media("en",
          audio: [%{language: "eng"}],
          text: [%{language: "en", title: "English"}, %{language: "en", title: "SDH", sdh?: true}]
        )

      assert %TextTrackChoices{choices: [%Choice{text_track: %{title: "SDH"}}]} =
               text_track_choices(media, generate(user(prefer_sdh?: true)))
    end

    test "plays the Forced Text Track in the Preferred Subtitle Language with every Audio Track" do
      media =
        movie_media("en",
          audio: [%{language: "eng"}, %{language: "spa"}],
          text: [
            %{language: "en", title: "English forced", forced?: true},
            %{language: "fr", title: "French forced", forced?: true}
          ]
        )

      %TextTrackChoices{forced: forced} =
        text_track_choices(media, generate(user(subtitle_language: :fr)))

      assert forced |> Map.values() |> Enum.map(& &1.title) == ["French forced", "French forced"]
    end

    test "plays the Forced Text Track in the audio's language without one in the Preferred Subtitle Language" do
      media =
        movie_media("en",
          audio: [%{language: "eng"}, %{language: "spa"}],
          text: [
            %{language: "en", title: "English forced", forced?: true},
            %{language: "es", title: "Spanish forced", forced?: true}
          ]
        )

      %TextTrackChoices{forced: forced} =
        text_track_choices(media, generate(user(subtitle_language: :fr)))

      assert forced |> Map.values() |> Enum.map(& &1.title) |> Enum.sort() ==
               ["English forced", "Spanish forced"]
    end
  end

  defp text_track_choices(media, user) do
    Playbacks.play!(media.id, "player",
      load: [current_playback: :text_track_choices],
      actor: user
    ).current_playback.text_track_choices
  end

  defp movie_media(original_language, audio: audio_tracks, text: text_tracks) do
    video = %{
      audio_tracks:
        Enum.with_index(audio_tracks, &Map.merge(%{stream_index: &2 + 1, codec: "aac"}, &1)),
      text_tracks:
        Enum.with_index(text_tracks, &Map.merge(%{stream_index: &2 + 10, codec: "subrip"}, &1))
    }

    generate(movie(original_language: original_language))
    |> video_media(video: video)
    |> generate()
  end
end
