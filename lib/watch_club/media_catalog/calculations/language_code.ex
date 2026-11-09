defmodule WatchClub.MediaCatalog.Calculations.LanguageCode do
  @moduledoc """
  Calculates the code of an Audio Track's or Text Track's language, as
  `WatchClub.Languages.to_code/1` returns it, so that languages written
  differently compare.

  With `untagged_is_original?: true`, a track without a language is taken to
  be in the original language of its Content.
  """

  use Ash.Resource.Calculation

  alias WatchClub.Languages

  @impl true
  def load(_query, opts, _context) do
    if opts[:untagged_is_original?],
      do: [:language, video: [media: [content: [:original_language]]]],
      else: [:language]
  end

  @impl true
  def calculate(tracks, opts, _context) do
    Enum.map(tracks, fn track ->
      Languages.to_code(track.language) ||
        if opts[:untagged_is_original?] do
          content = track.video.media.content
          Languages.to_code(content && content.original_language)
        end
    end)
  end
end
