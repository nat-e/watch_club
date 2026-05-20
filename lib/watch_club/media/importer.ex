defmodule WatchClub.Media.Importer do
  @moduledoc false

  require Logger

  alias WatchClub.Media.Importer.{
    ExistingMediaGate,
    FilesystemDiscovery,
    PathHints,
    Probe,
    SidecarTextTracks
  }

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.MediaImport
  alias WatchClub.Media.MediaImportConfiguration
  alias WatchClub.SystemActor

  def process_import(%MediaImport{} = media_import) do
    with {:ok, configuration} <- configuration_from_snapshot(media_import),
         {:ok, candidates} <- FilesystemDiscovery.stream(configuration) do
      candidates
      |> filter_existing_media(media_import)
      |> add_content_hints(configuration)
      |> load_sidecar_text_tracks()
      |> probe_files()
      |> Enum.reduce_while(:ok, fn result, :ok ->
        case handle_probe_result(result, media_import, configuration) do
          :ok -> {:cont, :ok}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
    end
  rescue
    error in [FilesystemDiscovery.Error] ->
      {:error, error.message}
  end

  defp configuration_from_snapshot(%MediaImport{configuration_snapshot: snapshot}) do
    configuration = %MediaImportConfiguration{
      id: Map.fetch!(snapshot, "id"),
      source_type: snapshot_atom(snapshot, "source_type"),
      content_type: snapshot_atom(snapshot, "content_type"),
      media_type: snapshot_atom(snapshot, "media_type"),
      filesystem_path: Map.fetch!(snapshot, "filesystem_path")
    }

    {:ok, configuration}
  end

  defp snapshot_atom(snapshot, key) do
    snapshot
    |> Map.fetch!(key)
    |> String.to_existing_atom()
  end

  defp filter_existing_media(candidates, media_import) do
    Stream.flat_map(candidates, fn candidate ->
      case ExistingMediaGate.apply(candidate, media_import) do
        {:ok, candidate} -> [candidate]
        :skip -> []
        {:error, error} -> raise "Could not filter Media Candidate: #{inspect(error)}"
      end
    end)
  end

  defp add_content_hints(candidates, configuration) do
    Stream.map(candidates, &PathHints.apply(&1, configuration))
  end

  defp load_sidecar_text_tracks(candidates) do
    Stream.map(candidates, &SidecarTextTracks.apply/1)
  end

  defp probe_files(candidates), do: Probe.stream(candidates)

  defp handle_probe_result({:ok, candidate}, media_import, configuration) do
    Logger.debug("Probed Media Candidate #{candidate.path}")

    case create_no_match_result(candidate, media_import, configuration) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp handle_probe_result({:error, candidate, message}, media_import, configuration) do
    case create_failed_result(candidate, media_import, configuration, message) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp handle_probe_result({:fatal, message}, _media_import, _configuration),
    do: {:error, message}

  defp create_no_match_result(candidate, media_import, configuration) do
    create_result(candidate, media_import, configuration,
      status: :no_match,
      stage: "content_matching",
      message: "Could not confidently match file to Content or TV Show Episode"
    )
  end

  defp create_failed_result(candidate, media_import, configuration, message) do
    create_result(candidate, media_import, configuration,
      status: :failed,
      stage: "probe",
      message: message
    )
  end

  defp create_result(candidate, media_import, configuration, opts) do
    metadata = %{
      "stage" => Keyword.fetch!(opts, :stage),
      "content_type" => Atom.to_string(configuration.content_type),
      "media_type" => Atom.to_string(configuration.media_type),
      "relative_path" => candidate.relative_path,
      "existing_media_id" => existing_media_id(candidate)
    }

    MediaDomain.create_media_import_result(
      %{
        media_import_id: media_import.id,
        status: Keyword.fetch!(opts, :status),
        path: candidate.path,
        message: Keyword.fetch!(opts, :message),
        metadata: metadata
      },
      actor: SystemActor.actor()
    )
  end

  defp existing_media_id(%{existing_media: %{id: id}}), do: id
  defp existing_media_id(_candidate), do: nil
end
