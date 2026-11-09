defmodule WatchClub.Playbacks.PlaybackTest do
  use WatchClub.DataCase, async: true

  alias WatchClub.Playbacks

  describe "get_playback_by_id/*" do
    test "starts with the audio and subtitles in the preferred languages" do
      user = generate(user(audio_language: :fr, subtitle_language: :en))

      media =
        media_with_tracks("en",
          audio: [
            %{language: "eng", title: "English", default?: true},
            %{language: "fre", title: "French"}
          ],
          text: [%{language: "fre", title: "French"}, %{language: "eng", title: "English"}]
        )

      assert preferred_track_titles(media, user) == {"French", "English"}
    end

    test "starts with the audio in the original language" do
      user = generate(user(audio_language: :original))

      media =
        media_with_tracks("ja",
          audio: [
            %{language: "fre", title: "French", default?: true},
            %{language: "jpn", title: "Japanese"}
          ],
          text: []
        )

      assert {"Japanese", nil} = preferred_track_titles(media, user)
    end

    test "starts with forced subtitles only when the audio is in a language without subtitles" do
      user = generate(user(subtitle_language: :en, languages_without_subtitles: [:en]))

      media =
        media_with_tracks("en",
          audio: [%{language: "eng", title: "English"}],
          text: [
            %{language: "eng", title: "English"},
            %{language: "eng", title: "English forced", forced?: true}
          ]
        )

      assert preferred_track_titles(media, user) == {"English", "English forced"}
    end

    test "assumes audio without a language is in the original language" do
      user = generate(user(subtitle_language: :fr, languages_without_subtitles: [:fr]))

      media =
        media_with_tracks("fr",
          audio: [
            %{language: "eng", title: "English", default?: true},
            %{language: nil, title: "Untagged"}
          ],
          text: [%{language: "fre", title: "French"}]
        )

      assert preferred_track_titles(media, user) == {"Untagged", nil}
    end
  end

  # Media for a Movie in the original language, whose Video has the given tracks
  defp media_with_tracks(original_language, audio: audio_tracks, text: text_tracks) do
    movie = generate(movie(original_language: original_language))

    video = %{
      audio_tracks:
        Enum.with_index(audio_tracks, &Map.merge(%{stream_index: &2 + 1, codec: "aac"}, &1)),
      text_tracks:
        Enum.with_index(text_tracks, &Map.merge(%{stream_index: &2 + 10, codec: "subrip"}, &1))
    }

    movie
    |> video_media(video: video)
    |> generate()
    |> Ash.load!([video: [:audio_tracks, :text_tracks]], authorize?: false)
  end

  # The titles of the Audio Track and Text Track the Player starts the User's Playback with
  defp preferred_track_titles(media, user) do
    playback = generate(playback(media, started_by: user))

    %{preferred_audio_track_id: audio_track_id, preferred_text_track_id: text_track_id} =
      Playbacks.get_playback_by_id!(playback.id,
        load: [:preferred_audio_track_id, :preferred_text_track_id],
        actor: user
      )

    titles = Map.new(media.video.audio_tracks ++ media.video.text_tracks, &{&1.id, &1.title})
    {titles[audio_track_id], titles[text_track_id]}
  end
end
