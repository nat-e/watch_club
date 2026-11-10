defmodule WatchClub.MediaSources.SourceTest do
  use WatchClub.DataCase

  import WatchClub.MediaSources

  alias WatchClub.Ffmpeg.Trickplay
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.{Filesystem, Import, Servarr, Source}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor

  require Ash.Query

  describe "create_filesystem_media_source/*" do
    test "creates a filesystem Media Source with normalized path and auto-computed name" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %Source{
               source_type: :filesystem,
               media_type: :movie,
               name: name,
               implementation: %Filesystem{filesystem_path: normalized_path}
             } =
               create_filesystem_media_source!(
                 %{media_type: :movie, filesystem_path: path},
                 actor: admin
               )

      assert normalized_path == Path.expand(path)
      assert name == "Filesystem: #{normalized_path}"
    end

    test "rejects non-admin actors" do
      user = generate(user())

      create_filesystem_media_source(
        %{media_type: :movie, filesystem_path: "tmp/imports/movies"},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "loads :can_request? as false" do
      admin = generate(administrator())

      assert %Source{can_request?: false} =
               create_filesystem_media_source!(
                 %{media_type: :movie, filesystem_path: "tmp/movies"},
                 actor: admin
               )
    end
  end

  describe "create_servarr_media_source/* (radarr)" do
    test "creates a radarr Media Source with normalized local path, computed name, and movie media_type" do
      admin = generate(administrator())

      assert %Source{
               source_type: :radarr,
               media_type: :movie,
               name: name,
               can_request?: true,
               implementation: %Servarr{
                 flavor: :radarr,
                 base_url: "https://radarr.lan",
                 api_key: "abc123",
                 quality_profile_id: 7,
                 root_folder_path: "/movies",
                 local_root_folder_path: normalized_local
               }
             } =
               create_servarr_media_source!(
                 %{
                   flavor: :radarr,
                   base_url: "https://radarr.lan/",
                   api_key: "abc123",
                   quality_profile_id: 7,
                   quality_profile_name: "HD-1080p Bluray",
                   root_folder_path: "/movies",
                   local_root_folder_path: "tmp/movies/../movies",
                   webhook_callback_base_url: "http://watch-club.test"
                 },
                 actor: admin
               )

      assert normalized_local == Path.expand("tmp/movies/../movies")
      assert name == "Radarr · /movies"
    end

    test "accepts a nil local_root_folder_path" do
      admin = generate(administrator())

      assert %Source{
               implementation: %Servarr{local_root_folder_path: nil}
             } =
               create_servarr_media_source!(
                 %{
                   flavor: :radarr,
                   base_url: "https://radarr.lan",
                   api_key: "abc123",
                   quality_profile_id: 7,
                   quality_profile_name: "HD-1080p Bluray",
                   root_folder_path: "/movies",
                   webhook_callback_base_url: "http://watch-club.test"
                 },
                 actor: admin
               )
    end

    test "rejects non-admin actors" do
      user = generate(user())

      create_servarr_media_source(
        %{
          flavor: :radarr,
          base_url: "https://radarr.lan",
          api_key: "abc123",
          quality_profile_id: 7,
          quality_profile_name: "HD-1080p Bluray",
          root_folder_path: "/movies",
          webhook_callback_base_url: "http://watch-club.test"
        },
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_servarr_media_source/* (sonarr)" do
    test "creates a sonarr Media Source with computed name and tv_show_episode media_type" do
      admin = generate(administrator())

      assert %Source{
               source_type: :sonarr,
               media_type: :tv_show_episode,
               name: name,
               can_request?: true,
               implementation: %Servarr{
                 flavor: :sonarr,
                 base_url: "https://sonarr.lan",
                 api_key: "abc123",
                 quality_profile_id: 7,
                 root_folder_path: "/tv"
               }
             } =
               create_servarr_media_source!(
                 %{
                   flavor: :sonarr,
                   base_url: "https://sonarr.lan/",
                   api_key: "abc123",
                   quality_profile_id: 7,
                   quality_profile_name: "HD-1080p Bluray",
                   root_folder_path: "/tv",
                   webhook_callback_base_url: "http://watch-club.test"
                 },
                 actor: admin
               )

      assert name == "Sonarr · /tv"
    end

    test "rejects non-admin actors" do
      user = generate(user())

      create_servarr_media_source(
        %{
          flavor: :sonarr,
          base_url: "https://sonarr.lan",
          api_key: "abc123",
          quality_profile_id: 7,
          quality_profile_name: "HD-1080p Bluray",
          root_folder_path: "/tv",
          webhook_callback_base_url: "http://watch-club.test"
        },
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "create_servarr_media_source/* (sportarr)" do
    test "creates a sportarr Media Source that imports and requests Sports Events" do
      assert %Source{
               source_type: :sportarr,
               media_type: :sports_event,
               name: "Sportarr · /sports",
               can_request?: true,
               implementation: %Servarr{flavor: :sportarr, notification_id: notification_id}
             } =
               create_servarr_media_source!(
                 %{
                   flavor: :sportarr,
                   base_url: "http://sportarr:1867",
                   api_key: "abc123",
                   quality_profile_id: 1,
                   quality_profile_name: "WEB-1080p",
                   root_folder_path: "/sports",
                   webhook_callback_base_url: "http://watch-club.test"
                 },
                 actor: generate(administrator())
               )

      assert is_integer(notification_id)
    end
  end

  describe "update_filesystem_media_source/*" do
    test "updates the filesystem path and re-normalizes it" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %Filesystem{filesystem_path: normalized_path} =
               update_filesystem_media_source!(
                 media_source.implementation,
                 %{filesystem_path: path},
                 actor: admin
               )

      assert normalized_path == Path.expand(path)
    end
  end

  describe "update_radarr_media_source/*" do
    test "updates radarr config" do
      admin = generate(administrator())

      radarr =
        create_servarr_media_source!(
          %{
            flavor: :radarr,
            base_url: "https://radarr.lan",
            api_key: "abc123",
            quality_profile_id: 7,
            quality_profile_name: "HD-1080p Bluray",
            root_folder_path: "/movies",
            webhook_callback_base_url: "http://watch-club.test"
          },
          actor: admin
        )

      assert %Servarr{
               quality_profile_id: 8,
               root_folder_path: "/movies-4k"
             } =
               update_servarr_media_source!(
                 radarr.implementation,
                 %{
                   base_url: "https://radarr.lan",
                   api_key: "abc123",
                   quality_profile_id: 8,
                   root_folder_path: "/movies-4k"
                 },
                 actor: admin
               )
    end
  end

  describe "destroy_media_source/*" do
    test "destroys a Media Source and cascade-deletes past Media Imports" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      media_import = generate(media_import(media_source))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute Source
             |> Ash.Query.filter(id == ^media_source.id)
             |> Ash.exists?(authorize?: false)

      refute Import
             |> Ash.Query.filter(id == ^media_import.id)
             |> Ash.exists?(authorize?: false)
    end

    test "deletes its Media with their trickplay, and keeps the Media of other Media Sources" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      media = generate(video_media(generate(movie()), media_source_id: media_source.id))
      other_media = generate(video_media(generate(movie())))
      trickplay_dir = Trickplay.dir(media.id)
      File.mkdir_p!(trickplay_dir)

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute Media |> Ash.Query.filter(id == ^media.id) |> Ash.exists?(authorize?: false)
      assert Media |> Ash.Query.filter(id == ^other_media.id) |> Ash.exists?(authorize?: false)
      refute File.exists?(trickplay_dir)
    end

    test "cancels the jobs of its Processing Media Import" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      media_import = generate(media_import(media_source))

      {:ok, job} =
        Oban.insert(CandidateIngestor.new_job(media_import, Candidate.new("/x.mkv", :movie)))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      assert %Oban.Job{state: "cancelled"} = WatchClub.Repo.reload!(job)
    end

    test "destroys the filesystem implementation row" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute Filesystem
             |> Ash.Query.filter(id == ^media_source.id)
             |> Ash.exists?(authorize?: false)
    end
  end

  describe "list_media_sources/*" do
    test "lists Media Sources for an administrator" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))

      assert [%Source{id: id}] = list_media_sources!(actor: admin)
      assert id == media_source.id
    end

    test "loads :latest_import with the most recent Media Import" do
      admin = generate(administrator())
      media_source = generate(filesystem_media_source(actor: admin))
      _older = generate(media_import(media_source, status: :completed))
      newer = generate(media_import(media_source, status: :failed))

      assert [%Source{latest_import: %Import{id: latest_id, status: :failed}}] =
               list_media_sources!(actor: admin, load: [:latest_import])

      assert latest_id == newer.id
    end

    test "loads :latest_import as nil when the Media Source has no Media Imports" do
      admin = generate(administrator())
      generate(filesystem_media_source(actor: admin))

      assert [%Source{latest_import: nil}] =
               list_media_sources!(actor: admin, load: [:latest_import])
    end
  end
end
