defmodule WatchClub.MediaSources.Servarr.App do
  @moduledoc """
  What WatchClub needs from one Servarr app, such as Radarr or Sonarr.

  Each app module translates its own API into WatchClub's terms: the Candidates
  to import, what a webhook means, and the state of a Media Source Request.
  The import, webhook and request flows stay the same for every app.
  """

  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.Servarr.Webhook.{MediaFile, RenamedFile}
  alias WatchClub.MediaCatalog.MediaType
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.Requests.MediaSourceRequestStatus
  alias WatchClub.Shared.Path, as: Paths

  @typedoc """
  What a webhook asks WatchClub to do. Paths are local to WatchClub, and ids are
  the app's id of the requested resource, as stored on the Media Source Request.
  """
  @type webhook_action ::
          {:ingest, [Candidate.t()]}
          | {:remove_media, String.t()}
          | {:relocate_media, from :: String.t(), to :: String.t()}
          | {:refresh_request, integer()}
          | {:forget_request, integer()}

  @doc "The Media Type this app imports."
  @callback media_type() :: MediaType.t()

  @doc "The notification events WatchClub subscribes to when it registers its webhook."
  @callback webhook_event_flags() :: [atom()]

  @doc "Every downloaded file of the source, as Candidates with local paths."
  @callback scan(Servarr.t()) :: [Candidate.t()]

  @doc "Translates a webhook payload into the actions WatchClub takes."
  @callback interpret_webhook(Servarr.t(), payload :: map()) :: [webhook_action()]

  @doc """
  Asks the app to download a Content, adding it when missing. Returns the app's
  id of the resource, or `:unavailable` when the app can't manage this Content.
  """
  @callback submit_request(Servarr.t(), Content.t()) :: {:ok, integer()} | :unavailable

  @doc "The status and download progress, from 0 to 100, of a requested resource."
  @callback request_state(Servarr.t(), resource_id :: integer()) ::
              {MediaSourceRequestStatus.t(), float()}

  @doc """
  Maps a path on the app's server onto WatchClub's disk. Nil when the path is
  outside the source's root folder.
  """
  @spec local_path(Servarr.t(), String.t() | nil) :: String.t() | nil
  def local_path(%Servarr{root_folder_path: root} = servarr, server_path)
      when is_binary(server_path) do
    server_path = Paths.normalize(server_path)
    root = Paths.normalize(root)

    if server_path == root or String.starts_with?(server_path, root <> "/") do
      Paths.remap_prefix(server_path, root, servarr.local_root_folder_path)
    end
  end

  def local_path(_servarr, _server_path), do: nil

  @doc "The local path of a webhook's file, inside its movie or series folder."
  @spec local_file_path(Servarr.t(), String.t() | nil, MediaFile.t() | nil) :: String.t() | nil
  def local_file_path(servarr, folder, %MediaFile{relative_path: relative_path})
      when is_binary(folder) and is_binary(relative_path) do
    local_path(servarr, Path.join(folder, relative_path))
  end

  def local_file_path(_servarr, _folder, _file), do: nil

  @doc "The `:relocate_media` actions of a Rename webhook's files, inside their folder."
  @spec relocations(Servarr.t(), String.t() | nil, [RenamedFile.t()]) :: [webhook_action()]
  def relocations(servarr, folder, renamed_files) when is_binary(folder) do
    for %RenamedFile{previous_path: previous, relative_path: relative} <- renamed_files,
        is_binary(previous) and is_binary(relative),
        from = local_path(servarr, previous),
        to = local_path(servarr, Path.join(folder, relative)),
        is_binary(from) and is_binary(to) and from != to,
        do: {:relocate_media, from, to}
  end

  def relocations(_servarr, _folder, _renamed_files), do: []
end
