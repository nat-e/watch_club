defmodule WatchClub.Dev.Catalog.Snapshot do
  @moduledoc """
  What seeding one version of the catalog produced, which every worktree can restore. It
  lives in the primary worktree's `tmp/dev_catalog_snapshots/<name>`:

    * `media/`: the catalog's files, as copy-on-write clones of the Git LFS store, so that the
      database and Radarr, Sonarr and Sportarr find them at the same path in every worktree
    * `app_data/`: the Scrubbing Thumbnails and audio fingerprints of its Videos
    * `saved`: written once the snapshot is complete

  Its database is a copy in Postgres, named after it. Radarr, Sonarr and Sportarr keep their
  data in Docker volumes, see `WatchClub.Dev.Catalog.Servarrs`.
  """
  alias WatchClub.Repo

  @enforce_keys [:name, :directory, :media]
  defstruct @enforce_keys

  @catalog_media "dev/catalog/media"
  @app_data_folders ["trickplay", "fingerprints"]

  @doc """
  The snapshot of this checkout's catalog files, with its files ready. A new `version` of the
  seed gets new snapshots.
  """
  def prepare!(version) do
    git!(["lfs", "install", "--local"])
    # Clones and CI skip the catalog's files, see .lfsconfig
    git!(["lfs", "fetch", "--include", "#{@catalog_media}/**", "--exclude", ""])
    common_dir = Path.expand(String.trim(git!(["rev-parse", "--git-common-dir"])))

    files =
      for line <-
            String.split(git!(["lfs", "ls-files", "--long", "-I", "#{@catalog_media}/**"]), "\n",
              trim: true
            ) do
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
      object =
        Path.join([
          common_dir,
          "lfs/objects",
          binary_part(oid, 0, 2),
          binary_part(oid, 2, 2),
          oid
        ])

      File.mkdir_p!(Path.dirname(target))
      clone!(object, target)
    end

    snapshot
  end

  @doc "The database's name in Postgres, which Radarr, Sonarr and Sportarr's volumes also use."
  def database(%__MODULE__{name: name}), do: "watch_club_catalog_" <> name

  @doc """
  Replaces the database with the snapshot's, then brings it up to date with this branch's
  migrations, and restores the files of its Videos. Returns false when the snapshot isn't
  saved, or comes from a branch with migrations that this one lacks: the database is then
  empty, as before.
  """
  def restore!(snapshot) do
    config = Repo.config()

    with true <- File.exists?(Path.join(snapshot.directory, "saved")),
         :up <- Ecto.Adapters.Postgres.storage_status(database_config(snapshot)),
         :ok <- replace_database!(config, snapshot),
         true <- migrations_known?() || recreate_empty_database!(config) do
      {:ok, _migrated, _apps} =
        Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :up, all: true))

      copy_app_data!(Path.join(snapshot.directory, "app_data"), app_data())
      true
    else
      _not_restored -> false
    end
  end

  @doc """
  Saves the database, which must have no connection left, and the files of `video_ids`, then
  marks the snapshot as saved.
  """
  def save!(snapshot, video_ids) do
    saved = Path.join(snapshot.directory, "saved")
    File.rm_rf!(saved)

    _maybe_missing = Ecto.Adapters.Postgres.storage_down(database_config(snapshot))

    :ok =
      Ecto.Adapters.Postgres.storage_up(
        Keyword.put(database_config(snapshot), :template, Repo.config()[:database])
      )

    app_data = Path.join(snapshot.directory, "app_data")
    File.rm_rf!(app_data)
    copy_app_data!(app_data(), app_data, video_ids)
    File.write!(saved, "")
  end

  defp replace_database!(config, snapshot) do
    :ok = Ecto.Adapters.Postgres.storage_down(Keyword.put(config, :force_drop, true))
    :ok = Ecto.Adapters.Postgres.storage_up(Keyword.put(config, :template, database(snapshot)))
  end

  # A branch that lacks a migration of the snapshot can't use its database
  defp migrations_known? do
    {:ok, migrations, _apps} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.migrations/1)
    not Enum.any?(migrations, fn {_status, _version, name} -> name == "** FILE NOT FOUND **" end)
  end

  defp recreate_empty_database!(config) do
    :ok = Ecto.Adapters.Postgres.storage_down(Keyword.put(config, :force_drop, true))
    :ok = Ecto.Adapters.Postgres.storage_up(config)

    {:ok, _migrated, _apps} =
      Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :up, all: true))

    false
  end

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
