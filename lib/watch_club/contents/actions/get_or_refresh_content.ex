defmodule WatchClub.Contents.Actions.GetOrRefreshContent do
  use Ash.Resource.Actions.Implementation

  alias OpenTelemetry.Tracer
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

    served =
      case content do
        nil ->
          :fetched

        %Content{} when max_age == :infinity ->
          :stored

        %Content{metadata_refreshed_at: refreshed_at} ->
          if refreshed_at &&
               DateTime.compare(refreshed_at, DateTime.add(called_at, -max_age, :second)) != :lt,
             do: :stored,
             else: :fetched
      end

    Tracer.set_attribute("watch_club.metadata_request.served", to_string(served))

    :telemetry.execute([:watch_club, :contents, :metadata_request], %{count: 1}, %{served: served})

    if served == :stored, do: {:ok, content}, else: MetadataFetcher.fetch(identity)
  end
end
