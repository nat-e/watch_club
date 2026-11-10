defmodule WatchClub.MediaSources.Import.Scanner.Servarr do
  @moduledoc """
  Servarr implementation of `WatchClub.MediaSources.Import.Scanner`: the source's
  app lists its downloaded files, see `WatchClub.MediaSources.Servarr.App.scan!/1`.
  """
  @behaviour WatchClub.MediaSources.Import.Scanner

  alias WatchClub.MediaSources.Import
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.Flavor

  @impl true
  def scan(%Import{media_source: %{implementation: %Servarr{flavor: flavor} = servarr}}) do
    Flavor.app(flavor).scan!(servarr)
  end
end
