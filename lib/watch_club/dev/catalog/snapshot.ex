defmodule WatchClub.Dev.Catalog.Snapshot do
  @moduledoc """
  What seeding one version of the catalog produced, which every worktree can restore. It
  lives in the primary worktree's `tmp/dev_catalog_snapshots/<name>`:

    * `media/`: the catalog's files, as copy-on-write clones of the Git LFS store, so that the
      database and Radarr, Sonarr and Sportarr find them at the same path in every worktree
    * `app_data/`: the Scrubbing Thumbnails and audio fingerprints of its Videos
    * `saved`: the migrations of its database, written once the snapshot is complete

  Its database is a copy in Postgres, and Radarr, Sonarr and Sportarr's data is in Docker
  volumes, see `WatchClub.Dev.Catalog.Servarrs`, all named after it. A lock next to its folder
  keeps a worktree from restoring a snapshot that another one is saving.
  """
  alias WatchClub.Dev.Catalog.Servarrs
  alias WatchClub.Repo

  @enforce_keys [:name, :directory, :media]
  defstruct @enforce_keys

  @catalog_media "dev/catalog/media"
  @migrations "priv/repo/migrations"
  @app_data_folders ["trickplay", "fingerprints"]

  @doc """
  The snapshot of the catalog files committed in this checkout, with its files ready. A new
  `version` of the seed gets new snapshots.
  """
  def prepare!(version) do
    git!(["lfs", "install", "--local"])
    # Clones and CI skip the catalog's files, see .lfsconfig
    git!(["lfs", "fetch", "--include", "#{@catalog_media}/**", "--exclude", ""])
    common_dir = Path.expand(String.trim(git!(["rev-parse", "--git-common-dir"])))
    lfs_files = git!(["lfs", "ls-files", "--long", "--include", "#{@catalog_media}/**", "HEAD"])

    files =
      for line <- String.split(lfs_files, "\n", trim: true) do
        [oid, _status, path] = String.split(line, " ", parts: 3)
        {oid, Path.relative_to(path, @catalog_media)}
      end

    name =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary({version, Enum.sort(files)}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    directory = Path.join([Path.dirname(common_dir), "tmp/dev_catalog_snapshots", name])
    snapshot = %__MODULE__{name: name, directory: directory, media: Path.join(directory, "media")}

    # Puts back any file deleted since, such as by Radarr
    for {oid, path} <- files,
        target = Path.join(snapshot.media, path),
        not File.exists?(target) do
      objects = Path.join(common_dir, "lfs/objects")
      File.mkdir_p!(Path.dirname(target))
      clone!(Path.join([objects, binary_part(oid, 0, 2), binary_part(oid, 2, 2), oid]), target)
    end

    snapshot
  end

  @doc """
  Replaces the database with the snapshot's, brings it up to date with this branch's newer
  migrations, restores the files of its Videos, and recreates the Radarr, Sonarr and Sportarr
  of the Docker Compose `project` with its data, on ports derived from the app's `port`.
  Returns their base URLs by flavor, or `:not_saved` without changing anything when the
  snapshot isn't saved, or when one of its migrations is missing or changed in this branch.
  """
  def restore!(snapshot, project, port) do
    with_lock!(snapshot, fn ->
      saved = Path.join(snapshot.directory, "saved")

      if File.exists?(saved) and migrations_match?(JSON.decode!(File.read!(saved))) and
           Servarrs.saved?(snapshot.name) do
        config = Repo.config()
        :ok = Ecto.Adapters.Postgres.storage_down(Keyword.put(config, :force_drop, true))

        :ok =
          Ecto.Adapters.Postgres.storage_up(Keyword.put(config, :template, database(snapshot)))

        {:ok, _migrated, _apps} =
          Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :up, all: true))

        copy_app_data!(Path.join(snapshot.directory, "app_data"), app_data())
        {:ok, Servarrs.restore!(project, port, snapshot.media, snapshot.name)}
      else
        :not_saved
      end
    end)
  end

  @doc """
  Saves the database, which must have no connection left, the data of the Radarr, Sonarr and
  Sportarr of `project`, and the files of `video_ids`, then marks the snapshot as saved.
  """
  def save!(snapshot, project, port, video_ids) do
    with_lock!(snapshot, fn ->
      saved = Path.join(snapshot.directory, "saved")
      # Until it is complete again, nobody restores a snapshot that mixes two seeds
      File.rm_rf!(saved)

      Servarrs.save!(project, port, snapshot.media, snapshot.name)

      _maybe_missing = Ecto.Adapters.Postgres.storage_down(database_config(snapshot))

      :ok =
        Ecto.Adapters.Postgres.storage_up(
          Keyword.put(database_config(snapshot), :template, Repo.config()[:database])
        )

      app_data = Path.join(snapshot.directory, "app_data")
      File.rm_rf!(app_data)
      copy_app_data!(app_data(), app_data, video_ids)

      {:ok, applied, _apps} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.migrations/1)
      versions = for {:up, version, _name} <- applied, do: to_string(version)
      File.write!(saved, JSON.encode!(Map.take(migration_hashes(), versions)))
    end)
  end

  # Ecto doesn't run again a migration that changed since it ran
  defp migrations_match?(saved_hashes) do
    hashes = migration_hashes()
    Enum.all?(saved_hashes, fn {version, hash} -> hashes[version] == hash end)
  end

  defp migration_hashes do
    Map.new(Path.wildcard(Path.join(@migrations, "*.exs")), fn path ->
      [version | _name] = String.split(Path.basename(path), "_", parts: 2)
      {version, Base.encode16(:crypto.hash(:sha256, File.read!(path)), case: :lower)}
    end)
  end

  # Waits for another seed to finish with the snapshot, unless its process is gone
  defp with_lock!(snapshot, fun, attempts \\ 600) do
    lock = snapshot.directory <> ".lock"
    File.mkdir_p!(Path.dirname(lock))

    case File.open(lock, [:write, :exclusive]) do
      {:ok, file} ->
        IO.write(file, System.pid())
        File.close(file)

        try do
          fun.()
        after
          File.rm(lock)
        end

      {:error, :eexist} ->
        holder_alive? =
          case File.read(lock) do
            {:ok, pid} ->
              match?({_output, 0}, System.cmd("kill", ["-0", pid], stderr_to_stdout: true))

            {:error, :enoent} ->
              true
          end

        cond do
          not holder_alive? -> File.rm(lock)
          attempts > 0 -> Process.sleep(1_000)
          true -> raise "Another seed has held #{lock} for 10 minutes"
        end

        with_lock!(snapshot, fun, attempts - 1)
    end
  end

  defp database(%__MODULE__{name: name}), do: "watch_club_catalog_" <> name

  defp database_config(snapshot), do: Keyword.put(Repo.config(), :database, database(snapshot))

  defp app_data, do: Application.fetch_env!(:watch_club, :app_data)

  # Each Video's files are in a folder named after it
  defp copy_app_data!(from, to, video_ids \\ :all) do
    for folder <- @app_data_folders,
        source = Path.join(from, folder),
        File.dir?(source),
        id <- File.ls!(source),
        video_ids == :all or id in video_ids do
      target = Path.join([to, folder, id])
      File.rm_rf!(target)
      File.mkdir_p!(Path.dirname(target))
      clone!(Path.join(source, id), target)
    end
  end

  defp clone!(source, target) do
    options =
      case :os.type() do
        {:unix, :darwin} -> ["-c", "-R"]
        _linux -> ["--reflink=auto", "-R"]
      end

    {_output, 0} = System.cmd("cp", options ++ [source, target], stderr_to_stdout: true)
  end

  defp git!(arguments) do
    {output, 0} = System.cmd("git", arguments, stderr_to_stdout: true)
    output
  end
end
