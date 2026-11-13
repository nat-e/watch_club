defmodule WatchClub.Dev.Catalog do
  @moduledoc """
  Seeds an empty dev database with the catalog in `dev/catalog`, as its README describes: its
  Users, this worktree's own Radarr, Sonarr and Sportarr, and the Media Sources that import the
  catalog's files.

  The first seed of a version of the catalog imports its files for real, waits for their
  Scrubbing Thumbnails and Markers, then saves a snapshot. Later seeds, in any worktree,
  restore that snapshot in seconds, see `WatchClub.Dev.Catalog.Snapshot`.
  """
  require Ecto.Query
  require Logger

  alias WatchClub.{Accounts, MediaSources, Repo}
  alias WatchClub.Dev.Catalog.{Servarrs, Snapshot}

  # Bump it when the seed changes what it creates, so that no older snapshot is restored
  @version 1
  @password "passw0rd"

  @doc """
  Seeds the database, which the app's Repo must not use yet. The seed starts the app, which
  must serve on `port`, because Radarr and Sonarr test the webhook of a Media Source.
  """
  def seed!(port) do
    {:ok, seeded?, _apps} =
      Ecto.Migrator.with_repo(Repo, fn _repo -> Accounts.administrator_exists?() end)

    if seeded?, do: raise("The database is already seeded: run `mix reset` to seed it again")

    snapshot = Snapshot.prepare!(@version)
    project = Repo.config()[:database] <> "_servarrs"

    if Servarrs.saved?(snapshot.name) and Snapshot.restore!(snapshot) do
      {:ok, _apps} = Application.ensure_all_started(:watch_club)
      base_urls = Servarrs.restore!(project, port, snapshot.media, snapshot.name)
      reconnect_servarrs!(base_urls, port)
      Logger.info("Restored the snapshot #{snapshot.name} of the catalog")
    else
      {:ok, _apps} = Application.ensure_all_started(:watch_club)
      admin = import!(snapshot, project, port)
      wait_until_idle!()
      video_ids = Enum.map(Ash.read!(WatchClub.MediaCatalog.Video, actor: admin), & &1.id)
      # The snapshot's database is a copy, which needs the database without connections
      :ok = Application.stop(:watch_club)
      Servarrs.save!(project, port, snapshot.media, snapshot.name)
      Snapshot.save!(snapshot, video_ids)
      Logger.info("Saved the snapshot #{snapshot.name} of the catalog")
    end
  end

  defp import!(snapshot, project, port) do
    admin = create_users!()

    # Radarr, Sonarr and Sportarr take their files first: Sportarr and the imports use the
    # same sportarr.net, which limits each IP address
    servarr_sources =
      for servarr <- Servarrs.fill!(project, port, snapshot.media) do
        servarr
        |> Map.put(:webhook_callback_base_url, webhook_callback_base_url(port))
        |> MediaSources.create_servarr_media_source!(actor: admin)
      end

    filesystem_sources =
      for {media_type, folder} <- [movie: "movies", tv_show_episode: "tv", sports_event: "sports"] do
        MediaSources.create_filesystem_media_source!(
          %{media_type: media_type, filesystem_path: Path.join(snapshot.media, folder)},
          actor: admin
        )
      end

    media_sources = servarr_sources ++ filesystem_sources

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

    admin
  end

  # The snapshot's Media Sources connect to the snapshot's ports
  defp reconnect_servarrs!(base_urls, port) do
    admin = Accounts.get_instance_administrator!(authorize?: false)

    for %{implementation: %MediaSources.Servarr{} = servarr} <-
          MediaSources.list_media_sources!(actor: admin) do
      MediaSources.update_servarr_media_source!(
        servarr,
        %{
          base_url: Map.fetch!(base_urls, servarr.flavor),
          webhook_callback_base_url: webhook_callback_base_url(port)
        },
        actor: admin
      )
    end
  end

  defp webhook_callback_base_url(port), do: "http://host.docker.internal:#{port}"

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

  # Until the Scrubbing Thumbnails and Markers are done, including the Markers of a season,
  # which wait a minute after its last episode
  defp wait_until_idle!(attempts \\ 1_800) do
    pending =
      Oban.Job
      |> Ecto.Query.where([job], job.queue in ["trickplay_generation", "marker_detection"])
      |> Ecto.Query.where(
        [job],
        job.state in ["available", "scheduled", "executing", "retryable"]
      )
      |> Repo.aggregate(:count)

    cond do
      pending == 0 ->
        :ok

      attempts > 0 ->
        Process.sleep(1_000)
        wait_until_idle!(attempts - 1)

      true ->
        raise "#{pending} background jobs are still pending after 30 minutes"
    end
  end
end
