defmodule WatchClub.Playbacks.Playback.PreferredTrack do
  @moduledoc """
  Calculates the id of the Audio Track or Text Track (`track: :audio | :text`)
  the Player starts a Playback with, from the User Preferences of its User.

  Audio: the preferred audio language, then the Content's original language,
  then the file's default track. Subtitles: a full Text Track in the preferred
  subtitle language, unless the audio is in one of the User's languages without
  subtitles; otherwise a forced Text Track in the audio's language, if any.
  """

  use Ash.Resource.Calculation

  alias WatchClub.Languages

  @impl true
  def load(_query, _opts, _context) do
    [
      session: [
        started_by: [
          settings: [:audio_language, :subtitle_language, :languages_without_subtitles]
        ]
      ],
      media: [
        content: [:original_language],
        video: [
          audio_tracks: [:language, :default?, :stream_index],
          text_tracks: [:language, :default?, :forced?, :stream_index, :hls_supported?]
        ]
      ]
    ]
  end

  @impl true
  def calculate(playbacks, opts, _context) do
    Enum.map(playbacks, fn playback ->
      settings = playback.session.started_by.settings
      video = playback.media.video
      content = playback.media.content
      original_language = Languages.to_code(content && content.original_language)

      # Audio without a language is most likely in the original language
      audio_tracks =
        for track <- sort_default_first(video.audio_tracks),
            do: {track, Languages.to_code(track.language) || original_language}

      text_tracks =
        for track <- sort_default_first(video.text_tracks),
            track.hls_supported?,
            do: {track, Languages.to_code(track.language)}

      audio = preferred_audio_track(audio_tracks, original_language, settings)

      preferred =
        case Keyword.fetch!(opts, :track) do
          :audio -> audio
          :text -> preferred_text_track(text_tracks, audio, settings)
        end

      with {track, _language} <- preferred, do: track.id
    end)
  end

  # Tracks are `{track, language}` pairs, the file's default tracks first
  defp preferred_audio_track(tracks, original_language, settings) do
    preferred_language =
      case settings.audio_language do
        :original -> original_language
        language -> Atom.to_string(language)
      end

    find_in_language(tracks, preferred_language) ||
      find_in_language(tracks, original_language) ||
      List.first(tracks)
  end

  defp preferred_text_track(tracks, audio, settings) do
    {forced_tracks, full_tracks} =
      Enum.split_with(tracks, fn {track, _language} -> track.forced? end)

    audio_language = with {_track, language} <- audio, do: language

    languages_without_subtitles =
      Enum.map(settings.languages_without_subtitles, &Atom.to_string/1)

    full_track =
      if settings.subtitle_language && audio_language not in languages_without_subtitles do
        find_in_language(full_tracks, Atom.to_string(settings.subtitle_language))
      end

    full_track || find_in_language(forced_tracks, audio_language)
  end

  defp sort_default_first(tracks), do: Enum.sort_by(tracks, &{not &1.default?, &1.stream_index})

  defp find_in_language(_tracks, nil), do: nil
  defp find_in_language(tracks, language), do: Enum.find(tracks, &match?({_track, ^language}, &1))
end
