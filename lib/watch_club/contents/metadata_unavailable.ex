defmodule WatchClub.Contents.MetadataUnavailable do
  @moduledoc "A Metadata Provider request failed before the Content could be refreshed."
  use Splode.Error, fields: [:reason], class: :unknown

  def message(%{reason: reason}), do: "Content metadata is unavailable: #{inspect(reason)}"
end
