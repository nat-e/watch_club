defmodule WatchClub.Contents.Actions.RefreshAllMetadata do
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents.{Content, ContentIdentity, MetadataFetcher}

  require Ash.Query

  @impl true
  def run(%Ash.ActionInput{arguments: %{refreshed_before: refreshed_before}}, _opts, context) do
    Content
    |> Ash.Query.filter(
      is_nil(metadata_refreshed_at) or metadata_refreshed_at < ^refreshed_before
    )
    |> Ash.Query.select([:type, :external_id_source, :external_id])
    |> Ash.read!(scope: context)
    # Through the fetcher, so a User opening the same Content shares its fetch
    |> Enum.each(fn content ->
      {:ok, _content} = MetadataFetcher.fetch(ContentIdentity.from_content(content))
    end)

    :ok
  end
end
