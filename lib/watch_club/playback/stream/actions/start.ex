defmodule WatchClub.Playback.Stream.Actions.Start do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playback.Session
  alias WatchClub.Playback.Stream
  alias WatchClub.Playback.Stream.SegmentCache
  alias WatchClub.SystemActor

  @impl true
  def run(input, _opts, context) do
    actor = context.actor
    session_id = input.arguments.session_id

    with {:ok, session} <- read_session(session_id, actor),
         %{media: %{path: source_path}} when is_binary(source_path) <- session,
         :ok <- ensure_source_exists(source_path),
         :ok <- stop_previous_stream(session_id) do
      File.mkdir_p!(SegmentCache.root())
      stream_id = Ash.UUIDv7.generate()
      output_dir = SegmentCache.stream_dir(stream_id)
      File.mkdir_p!(output_dir)

      Stream
      |> Ash.Changeset.for_create(
        :create,
        %{
          session_id: session_id,
          media_id: session.media_id,
          output_dir: output_dir,
          media: session.media
        },
        actor: SystemActor.actor()
      )
      |> Ash.Changeset.force_change_attribute(:id, stream_id)
      |> Ash.create(actor: SystemActor.actor())
    else
      {:error, reason} -> {:error, reason}
      %Session{} -> {:error, :media_not_found}
    end
  end

  defp read_session(session_id, actor) do
    Ash.get(Session, session_id, action: :for_playback, actor: actor)
  end

  defp ensure_source_exists(source_path) do
    if File.exists?(source_path) do
      :ok
    else
      {:error, "Playback media file does not exist: #{source_path}"}
    end
  end

  defp stop_previous_stream(session_id) do
    case Ash.read(Stream, actor: SystemActor.actor()) do
      {:ok, streams} ->
        streams
        |> Enum.filter(&(&1.session_id == session_id))
        |> Enum.each(&destroy_stream/1)

        :ok

      _other ->
        :ok
    end
  end

  defp destroy_stream(stream) do
    File.rm_rf(stream.output_dir)
    Ash.destroy(stream, actor: SystemActor.actor())
  end
end
