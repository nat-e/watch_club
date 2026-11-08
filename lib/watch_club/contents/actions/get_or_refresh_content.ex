defmodule WatchClub.Contents.Actions.GetOrRefreshContent do
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents
  alias WatchClub.Contents.{Content, MetadataUnavailable}

  @freshness_seconds 24 * 60 * 60

  @impl true
  def run(%Ash.ActionInput{arguments: %{content_identity: identity}}, _opts, context) do
    # Wait outside database transactions, then recheck persisted freshness under the lock.
    :global.trans({{__MODULE__, identity}, self()}, fn ->
      content =
        Contents.get_content_by_identity!(identity,
          not_found_error?: false,
          scope: context
        )

      case content do
        nil ->
          Contents.create_content(identity, scope: context)

        %Content{metadata_refreshed_at: refreshed_at}
        when not is_nil(refreshed_at) ->
          if DateTime.diff(DateTime.utc_now(), refreshed_at) < @freshness_seconds,
            do: {:ok, content},
            else: refresh_content(content, context)

        %Content{} ->
          refresh_content(content, context)
      end
    end)
  end

  defp refresh_content(content, context) do
    case Contents.refresh_metadata(content, %{}, scope: context) do
      {:ok, refreshed} ->
        {:ok, refreshed}

      {:error, error} ->
        if Enum.any?(error.errors, &match?(%MetadataUnavailable{}, &1)),
          do: {:ok, content},
          else: {:error, error}
    end
  end
end
