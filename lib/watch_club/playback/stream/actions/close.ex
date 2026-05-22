defmodule WatchClub.Playback.Stream.Actions.Close do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playback.Stream.Actions.Helpers
  alias WatchClub.SystemActor

  @impl true
  def run(input, _opts, context) do
    case Helpers.fetch_authorized_stream(input.arguments.stream_id, context.actor) do
      {:ok, stream} ->
        File.rm_rf(stream.output_dir)
        Ash.destroy(stream, actor: SystemActor.actor())

      {:error, :not_found} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
