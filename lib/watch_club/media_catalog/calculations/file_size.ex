defmodule WatchClub.MediaCatalog.Calculations.FileSize do
  @moduledoc """
  The size of a Media's file in bytes, read from disk. `nil` when the file is gone, until the next
  scan removes its Media.
  """

  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:path]

  @impl true
  def calculate(medias, _opts, _context) do
    Enum.map(medias, fn media ->
      case File.stat(media.path) do
        {:ok, stat} -> stat.size
        {:error, _reason} -> nil
      end
    end)
  end
end
