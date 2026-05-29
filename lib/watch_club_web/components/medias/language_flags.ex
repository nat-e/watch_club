defmodule WatchClubWeb.Components.Medias.LanguageFlags do
  @moduledoc """
  Compact flag-strip summaries of the audio and subtitle languages on a `Video`.

  Each component iterates the relevant tracks, dedupes by language code, and
  renders up to `max` unicode flag glyphs followed by a `+N` overflow count.
  Falls back to an em dash when no languages are available.
  """
  use WatchClubWeb, :component

  alias WatchClub.MediaCatalog.Video

  attr :video, Video, required: true
  attr :max, :integer, default: 3
  attr :class, :any, default: nil

  def audio_languages_flags(assigns) do
    flag_strip(assign(assigns, :languages, uniq_languages(assigns.video.audio_tracks)))
  end

  attr :video, Video, required: true
  attr :max, :integer, default: 3
  attr :class, :any, default: nil

  def subtitle_languages_flags(assigns) do
    flag_strip(assign(assigns, :languages, uniq_languages(assigns.video.text_tracks)))
  end

  defp flag_strip(%{languages: []} = assigns) do
    ~H"""
    <span class={["text-xs text-text-subtle", @class]}>—</span>
    """
  end

  defp flag_strip(assigns) do
    ~H"""
    <div class={["flex items-center whitespace-nowrap", @class]}>
      <span
        :for={lang <- Enum.take(@languages, @max)}
        title={lang}
        class="text-base leading-none"
      >
        {WatchClub.Languages.to_flag(lang)}
      </span>
      <span :if={length(@languages) > @max} class="text-xs text-text-subtle">
        +{length(@languages) - @max}
      </span>
    </div>
    """
  end

  defp uniq_languages(tracks) do
    tracks
    |> Enum.map(& &1.language)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end
end
