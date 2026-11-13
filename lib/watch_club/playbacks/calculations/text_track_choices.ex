defmodule WatchClub.Playbacks.Calculations.TextTrackChoices do
  @moduledoc """
  The Text Track Choices of a Playback, and the Forced Text Tracks that play while none is picked.

  The choices are one Text Track per language and region among English, French and the
  Content's original language. In each, it takes the Playback's picked Text Track, else an SDH
  Text Track when the User prefers them and a regular one otherwise, when the Video has one,
  else the first in the file. Forced and picture-based Text Tracks are never choices.

  While no Text Track is picked, the Forced Text Track in the User's Preferred Subtitle Language
  plays, otherwise the one in the audio's language: `forced` has it for each Audio Track.

  `names` has the name of each, in the User's Locale: its language, with its region when another
  choice has the same language, such as French (Canada) or English (SDH). The choices are in the
  order of their names. It reads the User Preferences of the User who started the Playback
  Session.
  """
  use Ash.Resource.Calculation
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.{TrackLanguage, UserLocale, UserSettings}
  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.{TextTrack, Video}

  @type t :: %__MODULE__{
          choices: [TextTrack.t()],
          forced: %{(audio_track_id :: String.t()) => TextTrack.t()},
          names: %{(text_track_id :: String.t()) => String.t()}
        }

  defstruct choices: [], forced: %{}, names: %{}

  @doc "What to load on a Video for `new/4`. Its Text Tracks are in the file's order."
  def video_fields,
    do: [audio_tracks: [:language_code], text_tracks: [:language_code, :hls_supported?]]

  @doc """
  The choices of a Video, for the Content's original language code, a User's preferences and
  the Text Track picked, if any.
  """
  @spec new(Video.t(), String.t() | nil, UserSettings.t(), String.t() | nil) :: t()
  def new(%Video{} = video, original_language, %UserSettings{} = settings, text_track_id) do
    {forced, full} =
      video.text_tracks
      |> Enum.filter(& &1.hls_supported?)
      |> Enum.split_with(& &1.forced?)

    choices = choices(full, original_language, settings.prefer_sdh?, text_track_id)
    forced = forced(forced, video.audio_tracks, settings.subtitle_language)
    names = names(choices, Map.values(forced), settings.locale)

    %__MODULE__{
      choices: Enum.sort_by(choices, &names[&1.id]),
      forced: forced,
      names: names
    }
  end

  @doc "Every Text Track a Screen may show: the choices, then the forced ones."
  @spec text_tracks(t()) :: [TextTrack.t()]
  def text_tracks(%__MODULE__{} = text_track_choices) do
    text_track_choices.choices ++
      (text_track_choices.forced |> Map.values() |> Enum.uniq_by(& &1.id))
  end

  # Calculation dependencies skip authorization
  @impl true
  def load(_query, _opts, _context) do
    [
      :text_track_id,
      media: [content: [:original_language], video: video_fields()],
      session: [started_by: :settings]
    ]
  end

  # Its Text Tracks are whole, for the Screens
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(playbacks, _opts, _context) do
    Enum.map(playbacks, fn %{media: media, session: session} = playback ->
      original_language = Languages.to_code(media.content && media.content.original_language)
      new(media.video, original_language, session.started_by.settings, playback.text_track_id)
    end)
  end

  defp choices(tracks, original_language, prefer_sdh?, text_track_id) do
    languages =
      Enum.reject(
        [original_language | Enum.map(TrackLanguage.values(), &Atom.to_string/1)],
        &is_nil/1
      )

    tracks
    |> Enum.filter(&(&1.language_code in languages))
    |> Enum.group_by(&Languages.to_tag(&1.language))
    |> Enum.map(fn {_tag, tracks} ->
      Enum.find(tracks, &(&1.id == text_track_id)) ||
        Enum.find(tracks, &(&1.sdh? == prefer_sdh?)) || hd(tracks)
    end)
  end

  defp forced(tracks, audio_tracks, subtitle_language) do
    preferred = find_in_language(tracks, subtitle_language && Atom.to_string(subtitle_language))

    for audio_track <- audio_tracks,
        track = preferred || find_in_language(tracks, audio_track.language_code),
        into: %{},
        do: {audio_track.id, track}
  end

  defp find_in_language(_tracks, nil), do: nil
  defp find_in_language(tracks, language), do: Enum.find(tracks, &(&1.language_code == language))

  # The region only tells apart choices of the same language
  defp names(choices, forced, locale) do
    choices_per_language = Enum.frequencies_by(choices, & &1.language_code)

    Gettext.with_locale(WatchClubWeb.Gettext, UserLocale.to_cldr_locale_name(locale), fn ->
      Map.new(choices ++ forced, fn track ->
        tag =
          if not track.forced? and choices_per_language[track.language_code] > 1,
            do: Languages.to_tag(track.language),
            else: track.language_code

        language = Languages.display_name!(tag, locale)

        name =
          cond do
            track.forced? -> dgettext("player", "%{language} (forced)", language: language)
            track.sdh? -> dgettext("player", "%{language} (SDH)", language: language)
            true -> language
          end

        {track.id, name}
      end)
    end)
  end
end
