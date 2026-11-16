defmodule WatchClub.Dev.Catalog.Servarrs do
  @moduledoc """
  This worktree's own Radarr, Sonarr and Sportarr, run with Docker Compose from
  `dev/catalog/docker-compose.yml` on ports derived from the app's: + 20000, + 30000 and
  + 40000. They read the catalog's files in the `radarr`, `sonarr` and `sportarr` folders
  of a snapshot's media, see `WatchClub.Dev.Catalog.Snapshot`.

  `fill!/3` starts them empty and has each one take its files where they are. `save!/4` and
  `restore!/4` copy their data to and from Docker volumes named after a snapshot.
  """
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Integrations.{Sportarr, SportarrHub}
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.ExternalIdExtractor

  @compose_file "dev/catalog/docker-compose.yml"
  @flavors [:radarr, :sonarr, :sportarr]
  @port_offsets %{radarr: 20_000, sonarr: 30_000, sportarr: 40_000}
  # Adding a movie or a series fetches its metadata first
  @slow [receive_timeout: 120_000]

  @doc """
  Deletes the apps of the Docker Compose `project` with their data, starts them again empty,
  and has them take the files in `media`. Returns, for each app, the arguments that
  `create_servarr_media_source` needs to connect to it.
  """
  def fill!(project, port, media) do
    compose!(project, port, media, ["down", "--volumes", "--remove-orphans"])
    compose!(project, port, media, ["up", "--detach"])

    for flavor <- @flavors do
      base_url = base_url(port, flavor)
      wait_until_up!(base_url)
      api_key = api_key!(project, port, media, flavor)
      root_folder_path = "/media/#{flavor}"
      local_root_folder_path = Path.join(media, to_string(flavor))

      # Sportarr adds root folders outside its Sonarr-compatible API
      root_folders_path =
        if flavor == :sportarr, do: "/api/rootfolder", else: "/api/v3/rootfolder"

      {:ok, %{"id" => root_folder_id}} =
        Client.post(base_url, api_key, root_folders_path, %{path: root_folder_path})

      {:ok, [profile | _]} = Client.list_quality_profiles(base_url, api_key)

      app = %{
        base_url: base_url,
        api_key: api_key,
        root_folder_id: root_folder_id,
        quality_profile_id: profile.id
      }

      for folder <- local_root_folder_path |> File.ls!() |> Enum.sort(),
          not String.starts_with?(folder, "."),
          do: add!(flavor, app, folder, Path.join(local_root_folder_path, folder))

      wait_until_idle!(flavor, app)

      %{
        flavor: flavor,
        base_url: base_url,
        api_key: api_key,
        quality_profile_id: profile.id,
        quality_profile_name: profile.name,
        root_folder_path: root_folder_path,
        local_root_folder_path: local_root_folder_path
      }
    end
  end

  @doc "Copies the data of the apps of `project` to the volumes of the snapshot `name`."
  def save!(project, port, media, name) do
    # Their databases are only consistent once they are stopped
    compose!(project, port, media, ["stop"])

    for flavor <- @flavors do
      docker!(["volume", "rm", "--force", snapshot_volume(name, flavor)])
      copy_volume!(project_volume(project, flavor), snapshot_volume(name, flavor))
    end

    compose!(project, port, media, ["start"])
  end

  @doc "Whether the volumes of the snapshot `name` exist."
  def saved?(name) do
    Enum.all?(@flavors, fn flavor ->
      match?(
        {_output, 0},
        System.cmd("docker", ["volume", "inspect", snapshot_volume(name, flavor)],
          stderr_to_stdout: true
        )
      )
    end)
  end

  @doc """
  Recreates the apps of `project` with the data of the snapshot `name`, and returns the base URL
  of each one by flavor.
  """
  def restore!(project, port, media, name) do
    # Runs before the app starts
    {:ok, _apps} = Application.ensure_all_started(:req)
    compose!(project, port, media, ["down", "--volumes", "--remove-orphans"])
    # Creates their volumes, empty, without starting them
    compose!(project, port, media, ["create"])

    for flavor <- @flavors,
        do: copy_volume!(snapshot_volume(name, flavor), project_volume(project, flavor))

    compose!(project, port, media, ["start"])

    Map.new(@flavors, fn flavor ->
      base_url = base_url(port, flavor)
      wait_until_up!(base_url)
      {flavor, base_url}
    end)
  end

  defp base_url(port, flavor), do: "http://localhost:#{port + @port_offsets[flavor]}"

  defp project_volume(project, flavor), do: "#{project}_#{flavor}-config"
  defp snapshot_volume(name, flavor), do: "watch_club_catalog_#{name}_#{flavor}"

  defp copy_volume!(from, to) do
    docker!([
      "run",
      "--rm",
      "-v",
      "#{from}:/from:ro",
      "-v",
      "#{to}:/to",
      "alpine",
      "cp",
      "-a",
      "/from/.",
      "/to/"
    ])
  end

  # A movie's folder, named "Title (Year) {tmdb-123}"
  defp add!(:radarr, app, folder, _local_path) do
    [_match, title, tmdb_id] = Regex.run(~r/^(.+?) \(\d{4}\) \{tmdb-(\d+)\}$/, folder)

    {:ok, _movie} =
      Client.post(
        app.base_url,
        app.api_key,
        "/api/v3/movie",
        %{
          tmdbId: String.to_integer(tmdb_id),
          title: title,
          qualityProfileId: app.quality_profile_id,
          path: "/media/radarr/#{folder}",
          monitored: true,
          minimumAvailability: "released",
          addOptions: %{searchForMovie: false}
        },
        @slow
      )
  end

  # A series' folder, named "Title (Year) {tvdb-123}"
  defp add!(:sonarr, app, folder, _local_path) do
    [_match, title, tvdb_id] = Regex.run(~r/^(.+?) \(\d{4}\) \{tvdb-(\d+)\}$/, folder)

    {:ok, _series} =
      Client.post(
        app.base_url,
        app.api_key,
        "/api/v3/series",
        %{
          tvdbId: String.to_integer(tvdb_id),
          title: title,
          qualityProfileId: app.quality_profile_id,
          path: "/media/sonarr/#{folder}",
          seasonFolder: true,
          monitored: true,
          seriesType: "standard",
          addOptions: %{monitor: "existing", searchForMissingEpisodes: false}
        },
        @slow
      )
  end

  # A league's folder, named after the league, with a folder per season. Sportarr leaves a
  # file where it is only when it is already where Sportarr would put it.
  defp add!(:sportarr, app, league_name, local_path) do
    files =
      for path <- Path.wildcard(Path.join(local_path, "*/*")) do
        {path, "ev-" <> _id = ExternalIdExtractor.find_sportarr(path)}
      end

    {_path, first_event_id} = hd(files)
    {:ok, event} = SportarrHub.get_event(first_event_id)

    {:ok, league_id} =
      Sportarr.add_league(app.base_url, app.api_key, %{
        externalId: event.league_id,
        name: league_name,
        sport: event.sport,
        rootFolderId: app.root_folder_id,
        qualityProfileId: app.quality_profile_id
      })

    # Adding a league lists its events in the background
    wait_until_idle!(:sportarr, app)
    {:ok, events} = Sportarr.list_league_events(app.base_url, app.api_key, league_id)

    imports =
      for {path, event_id} <- files do
        %{
          filePath: "/media/sportarr/" <> Path.relative_to(path, Path.dirname(local_path)),
          eventId: Enum.find(events, &(&1.external_id == event_id)).id
        }
      end

    {:ok, _task} =
      Client.request(app.base_url, app.api_key,
        method: :post,
        url: "/api/library/import",
        json: imports
      )
  end

  defp wait_until_idle!(flavor, app, attempts \\ 600) do
    busy? =
      case flavor do
        :sportarr ->
          {:ok, tasks} =
            Client.get(app.base_url, app.api_key, "/api/task", params: [pageSize: 50])

          Enum.any?(tasks, &(&1["status"] in ["Queued", "Running"]))

        _radarr_or_sonarr ->
          {:ok, commands} = Client.get(app.base_url, app.api_key, "/api/v3/command")
          Enum.any?(commands, &(&1["status"] in ["queued", "started"]))
      end

    cond do
      not busy? ->
        :ok

      attempts > 0 ->
        Process.sleep(1_000)
        wait_until_idle!(flavor, app, attempts - 1)

      true ->
        raise "#{flavor} is still busy after 10 minutes"
    end
  end

  defp wait_until_up!(base_url, attempts \\ 120) do
    case Req.get(base_url <> "/ping", retry: false) do
      {:ok, %{status: 200}} ->
        :ok

      _not_yet when attempts > 0 ->
        Process.sleep(1_000)
        wait_until_up!(base_url, attempts - 1)

      _never ->
        raise "#{base_url} didn't start within 2 minutes"
    end
  end

  # Each app writes its API key to its config.xml when it first starts
  defp api_key!(project, port, media, flavor) do
    config =
      compose!(project, port, media, [
        "exec",
        "-T",
        to_string(flavor),
        "cat",
        "/config/config.xml"
      ])

    [_match, api_key] = Regex.run(~r/<ApiKey>(\w+)<\/ApiKey>/, config)
    api_key
  end

  defp compose!(project, port, media, arguments) do
    env =
      [{"CATALOG_MEDIA", media}] ++
        for {flavor, offset} <- @port_offsets,
            do: {"#{String.upcase(to_string(flavor))}_PORT", to_string(port + offset)}

    docker!(["compose", "--project-name", project, "--file", @compose_file | arguments], env)
  end

  defp docker!(arguments, env \\ []) do
    case System.cmd("docker", arguments, env: env, stderr_to_stdout: true) do
      {output, 0} ->
        output

      {output, status} ->
        raise "docker #{Enum.join(arguments, " ")} exited with #{status}:\n#{output}"
    end
  end
end
