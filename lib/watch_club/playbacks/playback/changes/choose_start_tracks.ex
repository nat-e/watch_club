defmodule WatchClub.Playbacks.Playback.Changes.ChooseStartTracks do
  @moduledoc """
  Picks the Audio Track and the Text Track Choice a Playback starts with.

  After a Playback of the same Content in its Playback Session, it keeps that one's audio
  language and its subtitles, or no subtitles. Otherwise, or when its Video has no track in that
  language, it starts with its Preferred Audio Track and Preferred Text Track, from the User
  Preferences of the User who started the Playback Session.

  Audio: the preferred audio language, then the Content's original language, then the file's
  default track. Subtitles: a choice in the preferred subtitle language, unless the audio is in
  one of the User's languages without subtitles. Without one, its Forced Text Track plays.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.Playbacks.Calculations.TextTrackChoices
  alias WatchClub.Playbacks.{Playback, Session}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case load_media(Ash.Changeset.get_attribute(changeset, :media_id)) do
        {:ok, media} -> choose!(changeset, media)
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end

  defp choose!(changeset, media) do
    session_id = Ash.Changeset.get_attribute(changeset, :session_id)
    previous = previous_playback!(session_id, media.content_id)

    settings =
      Ash.get!(Session, session_id, load: [started_by: :settings], authorize?: false).started_by.settings

    original_language = Languages.to_code(media.content && media.content.original_language)
    audio_tracks = sort_default_first(media.video.audio_tracks)

    audio_track =
      carried_over_audio_track(audio_tracks, previous) ||
        preferred_audio_track(audio_tracks, original_language, settings)

    text_tracks = TextTrackChoices.new(media.video, original_language, settings, nil).choices

    text_track =
      case carried_over_text_track(text_tracks, previous) do
        :none -> preferred_text_track(text_tracks, audio_track, settings)
        {:ok, track} -> track
      end

    Ash.Changeset.force_change_attributes(changeset, %{
      audio_track_id: audio_track && audio_track.id,
      text_track_id: text_track && text_track.id
    })
  end

  defp load_media(media_id) do
    Ash.get(Media, media_id,
      load: [content: [:original_language], video: TextTrackChoices.video_fields()],
      authorize?: false
    )
  end

  # The last Playback of the Playback Session, when it played the same Content
  defp previous_playback!(_session_id, nil), do: nil

  defp previous_playback!(session_id, content_id) do
    Playback
    |> Ash.Query.filter(session_id == ^session_id and media.content_id == ^content_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load(audio_track: [:language_code], text_track: [:language_code])
    |> Ash.read_one!(authorize?: false)
  end

  defp carried_over_audio_track(_tracks, nil), do: nil
  defp carried_over_audio_track(_tracks, %Playback{audio_track: nil}), do: nil

  defp carried_over_audio_track(tracks, %Playback{audio_track: audio_track}),
    do: find_in_language(tracks, audio_track.language_code)

  # {:ok, nil} keeps the subtitles off. Keeps their region too, when the choices have it.
  defp carried_over_text_track(_tracks, nil), do: :none
  defp carried_over_text_track(_tracks, %Playback{text_track: nil}), do: {:ok, nil}

  defp carried_over_text_track(tracks, %Playback{text_track: text_track}) do
    tag = Languages.to_tag(text_track.language)

    case Enum.find(tracks, &(Languages.to_tag(&1.language) == tag)) ||
           find_in_language(tracks, text_track.language_code) do
      nil -> :none
      track -> {:ok, track}
    end
  end

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

  defp preferred_text_track(tracks, audio_track, settings) do
    audio_language = audio_track && audio_track.language_code

    languages_without_subtitles =
      Enum.map(settings.languages_without_subtitles, &Atom.to_string/1)

    if settings.subtitle_language && audio_language not in languages_without_subtitles do
      find_in_language(tracks, Atom.to_string(settings.subtitle_language))
    end
  end

  defp sort_default_first(tracks), do: Enum.sort_by(tracks, &{not &1.default?, &1.stream_index})

  defp find_in_language(_tracks, nil), do: nil
  defp find_in_language(tracks, language), do: Enum.find(tracks, &(&1.language_code == language))
end
