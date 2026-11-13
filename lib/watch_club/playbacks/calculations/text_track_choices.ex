defmodule WatchClub.Playbacks.Calculations.TextTrackChoices do
  @moduledoc """
  The Text Track Choices of a Playback, and the Forced Text Tracks that play while none is picked.

  The choices are one Text Track per language and region among English, French and the
  Content's original language, in the order of their language tags. In each, it takes an SDH
  Text Track when the User prefers them and a regular one otherwise, when the Video has one,
  else the first in the file. Forced and picture-based Text Tracks are never choices.

  While no Text Track is picked, the Forced Text Track in the User's Preferred Subtitle Language
  plays, otherwise the one in the audio's language: `forced` has it for each Audio Track.

  It reads the User Preferences of the User who started the Playback Session, whoever reads it.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Accounts.{TrackLanguage, UserSettings}
  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.{TextTrack, Video}

  defmodule Choice do
    @moduledoc """
    A Text Track Choice, and the language tag to name it by: with its region only when another
    choice has the same language.
    """
    @type t :: %__MODULE__{text_track: TextTrack.t(), language: String.t()}

    defstruct [:text_track, :language]
  end

  @type t :: %__MODULE__{
          choices: [Choice.t()],
          forced: %{(audio_track_id :: String.t()) => TextTrack.t()}
        }

  defstruct choices: [], forced: %{}

  @doc "What to load on a Video for `new/3`."
  def video_fields,
    do: [audio_tracks: [:language_code], text_tracks: [:language_code, :hls_supported?]]

  @doc "The choices of a Video, for the Content's original language code and a User's preferences."
  @spec new(Video.t(), String.t() | nil, UserSettings.t()) :: t()
  def new(%Video{} = video, original_language, %UserSettings{} = settings) do
    {forced, full} =
      video.text_tracks
      |> Enum.filter(& &1.hls_supported?)
      |> Enum.sort_by(&{not &1.default?, &1.stream_index})
      |> Enum.split_with(& &1.forced?)

    %__MODULE__{
      choices: choices(full, original_language, settings.prefer_sdh?),
      forced: forced(forced, video.audio_tracks, settings.subtitle_language)
    }
  end

  @doc "Every Text Track a Screen may show: the choices, then the forced ones."
  @spec text_tracks(t()) :: [TextTrack.t()]
  def text_tracks(%__MODULE__{} = text_track_choices) do
    Enum.map(text_track_choices.choices, & &1.text_track) ++
      (text_track_choices.forced |> Map.values() |> Enum.uniq_by(& &1.id))
  end

  @impl true
  def load(_query, _opts, _context), do: [:media_id, :session_id]

  @impl true
  def calculate(playbacks, _opts, _context) do
    playbacks
    |> Ash.load!(
      [
        media: [content: [:original_language], video: video_fields()],
        session: [started_by: :settings]
      ],
      authorize?: false,
      lazy?: true
    )
    |> Enum.map(fn %{media: media, session: session} ->
      original_language = Languages.to_code(media.content && media.content.original_language)
      new(media.video, original_language, session.started_by.settings)
    end)
  end

  defp choices(tracks, original_language, prefer_sdh?) do
    languages =
      Enum.reject(
        [original_language | Enum.map(TrackLanguage.values(), &Atom.to_string/1)],
        &is_nil/1
      )

    picked =
      tracks
      |> Enum.filter(&(&1.language_code in languages))
      |> Enum.group_by(&Languages.to_tag(&1.language))
      |> Enum.map(fn {_tag, tracks} ->
        Enum.find(tracks, &(&1.sdh? == prefer_sdh?)) || hd(tracks)
      end)

    choices_per_language = Enum.frequencies_by(picked, & &1.language_code)

    picked
    |> Enum.map(fn track ->
      language =
        if choices_per_language[track.language_code] > 1,
          do: Languages.to_tag(track.language),
          else: track.language_code

      %Choice{text_track: track, language: language}
    end)
    |> Enum.sort_by(& &1.language)
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
end
