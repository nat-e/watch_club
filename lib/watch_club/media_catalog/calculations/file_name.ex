defmodule WatchClub.MediaCatalog.Calculations.FileName do
  @moduledoc """
  The name of a Media's file, which a Download saves it as.
  """

  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:path]

  @impl true
  def calculate(medias, _opts, _context), do: Enum.map(medias, &Path.basename(&1.path))
end
