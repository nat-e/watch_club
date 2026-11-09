defmodule WatchClub.Contents.Actions.GetOrRefreshContent do
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents
  alias WatchClub.Contents.{Content, MetadataFetcher}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{content_identity: identity, max_age: max_age}},
        _opts,
        context
      ) do
    called_at = DateTime.utc_now()

    content =
      Contents.get_content_by_identity!(identity,
        not_found_error?: false,
        scope: context
      )

    case content do
      nil ->
        MetadataFetcher.fetch(identity)

      %Content{} when max_age == :infinity ->
        {:ok, content}

      %Content{metadata_refreshed_at: refreshed_at} ->
        if refreshed_at &&
             DateTime.compare(refreshed_at, DateTime.add(called_at, -max_age, :second)) != :lt,
           do: {:ok, content},
           else: MetadataFetcher.fetch(identity)
    end
  end
end
