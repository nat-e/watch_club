defmodule WatchClub.Dev.Catalog do
  @moduledoc """
  Seeds an empty dev database with the catalog in `dev/catalog`, as its README describes:
  its Users, its own Radarr, Sonarr and Sportarr, and the Media Sources that import the
  catalog's files.
  """
  require Logger

  alias WatchClub.{Accounts, MediaSources}
  alias WatchClub.Dev.Catalog.Servarrs

  @media_root "dev/catalog/media"
  @password "passw0rd"

  @doc """
  Seeds the database. The app must serve on `port`, because Radarr and Sonarr test the
  webhook of a new Media Source.
  """
  def seed!(port) do
    if Accounts.administrator_exists?() do
      raise "The database is already seeded: run `mix reset` to seed it again"
    end

    fetch_files!()
    project = WatchClub.Repo.config()[:database] <> "_servarrs"
    servarrs = Servarrs.recreate!(project, port)
    admin = create_users!()

    media_sources =
      Enum.map(servarrs, fn servarr ->
        servarr
        |> Map.put(:webhook_callback_base_url, "http://host.docker.internal:#{port}")
        |> MediaSources.create_servarr_media_source!(actor: admin)
      end) ++
        for {media_type, folder} <- [
              movie: "movies",
              tv_show_episode: "tv",
              sports_event: "sports"
            ] do
          MediaSources.create_filesystem_media_source!(
            %{
              media_type: media_type,
              filesystem_path: Path.expand(Path.join(@media_root, folder))
            },
            actor: admin
          )
        end

    media_imports =
      Enum.map(media_sources, &MediaSources.start_media_import!(&1.id, actor: admin))

    # The catalog's Unmatched Media are on purpose, but every file must be read
    for {media_source, media_import} <- Enum.zip(media_sources, media_imports) do
      case wait_until_finished!(media_import, admin) do
        %{status: :completed, unreadable_file_count: 0, failed_file_count: 0} = media_import ->
          Logger.info(
            "#{media_source.name}: #{media_import.matched_file_count} matched, " <>
              "#{media_import.unmatched_file_count} unmatched"
          )

        media_import ->
          raise "The Media Import of #{media_source.name} didn't import every file: " <>
                  inspect(
                    Map.take(media_import, [:status, :unreadable_file_count, :failed_file_count])
                  )
      end
    end
  end

  # Clones and CI skip the catalog's files, see .lfsconfig. Each one becomes a copy-on-write
  # clone of the Git LFS store that worktrees share, where the disk allows it, so worktrees
  # take no more space. `git lfs dedup` does the same, but only in a worktree without changes.
  defp fetch_files! do
    git!(["lfs", "install", "--local"])
    git!(["lfs", "fetch", "--include", "#{@media_root}/**", "--exclude", ""])
    objects = Path.join(String.trim(git!(["rev-parse", "--git-common-dir"])), "lfs/objects")

    changed =
      ["status", "--porcelain", "-z", "--", @media_root]
      |> git!()
      |> String.split(<<0>>, trim: true)
      |> MapSet.new(&String.slice(&1, 3..-1//1))

    lfs_files = git!(["lfs", "ls-files", "--long", "--include", "#{@media_root}/**"])

    for line <- String.split(lfs_files, "\n", trim: true),
        [oid, _status, path] = String.split(line, " ", parts: 3),
        path not in changed do
      object = Path.join([objects, String.slice(oid, 0, 2), String.slice(oid, 2, 2), oid])
      clone = Path.join(Path.dirname(path), ".clone-" <> Path.basename(path))
      {_output, 0} = System.cmd("cp", [clone_option(), object, clone], stderr_to_stdout: true)
      File.rename!(clone, path)
    end
  end

  defp clone_option do
    case :os.type() do
      {:unix, :darwin} -> "-c"
      _linux -> "--reflink=auto"
    end
  end

  defp git!(arguments) do
    {output, 0} = System.cmd("git", arguments, stderr_to_stdout: true)
    output
  end

  defp create_users! do
    admin =
      Accounts.create_administrator!(%{
        username: "admin",
        password: @password,
        password_confirmation: @password,
        locale: :en_US
      })

    invitation = Accounts.create_invitation_code!(%{code: "CATALOG", max_uses: 2}, actor: admin)

    for {username, locale} <- [alice: :en_US, bob: :fr_FR] do
      Accounts.register_with_password!(%{
        username: to_string(username),
        password: @password,
        password_confirmation: @password,
        invitation_code: invitation.code,
        locale: locale
      })
    end

    admin
  end

  defp wait_until_finished!(media_import, admin, attempts \\ 900) do
    media_import = MediaSources.get_media_import_by_id!(media_import.id, actor: admin)

    cond do
      media_import.status != :processing ->
        media_import

      attempts > 0 ->
        Process.sleep(1_000)
        wait_until_finished!(media_import, admin, attempts - 1)

      true ->
        raise "A Media Import is still processing after 15 minutes"
    end
  end
end
