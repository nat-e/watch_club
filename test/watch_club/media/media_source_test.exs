defmodule WatchClub.Media.MediaSourceTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{FilesystemMediaSource, MediaImport, MediaSource, RadarrMediaSource}

  require Ash.Query

  describe "create_filesystem_media_source/*" do
    test "creates a filesystem Media Source with normalized path and auto-computed name" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %MediaSource{
               source_type: :filesystem,
               media_type: :movie,
               name: name,
               implementation: %FilesystemMediaSource{filesystem_path: normalized_path}
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

      assert %MediaSource{can_request?: false} =
               create_filesystem_media_source!(
                 %{media_type: :movie, filesystem_path: "tmp/movies"},
                 actor: admin
               )
    end
  end

  describe "create_radarr_media_source/*" do
    test "creates a radarr Media Source with normalized local path, computed name, and movie media_type" do
      admin = generate(administrator())

      assert %MediaSource{
               source_type: :radarr,
               media_type: :movie,
               name: name,
               can_request?: true,
               implementation: %RadarrMediaSource{
                 base_url: "https://radarr.lan",
                 api_key: "abc123",
                 quality_profile_id: 7,
                 root_folder_path: "/movies",
                 local_root_folder_path: normalized_local
               }
             } =
               create_radarr_media_source!(
                 %{
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

      assert %MediaSource{
               implementation: %RadarrMediaSource{local_root_folder_path: nil}
             } =
               create_radarr_media_source!(
                 %{
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

      create_radarr_media_source(
        %{
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

  describe "update_filesystem_media_source/*" do
    test "updates the filesystem path and re-normalizes it" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %FilesystemMediaSource{filesystem_path: normalized_path} =
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
        create_radarr_media_source!(
          %{
            base_url: "https://radarr.lan",
            api_key: "abc123",
            quality_profile_id: 7,
            quality_profile_name: "HD-1080p Bluray",
            root_folder_path: "/movies",
            webhook_callback_base_url: "http://watch-club.test"
          },
          actor: admin
        )

      assert %RadarrMediaSource{
               quality_profile_id: 8,
               root_folder_path: "/movies-4k"
             } =
               update_radarr_media_source!(
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
      media_source = generate(media_source(actor: admin))
      media_import = generate(media_import(media_source))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute MediaSource
             |> Ash.Query.filter(id == ^media_source.id)
             |> Ash.exists?(authorize?: false)

      refute MediaImport
             |> Ash.Query.filter(id == ^media_import.id)
             |> Ash.exists?(authorize?: false)
    end

    test "destroys the filesystem implementation row" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute FilesystemMediaSource
             |> Ash.Query.filter(id == ^media_source.id)
             |> Ash.exists?(authorize?: false)
    end
  end

  describe "list_media_sources/*" do
    test "lists Media Sources for an administrator" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))

      assert [%MediaSource{id: id}] = list_media_sources!(actor: admin)
      assert id == media_source.id
    end

    test "loads :latest_import with the most recent Media Import" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))
      _older = generate(media_import(media_source, status: :completed))
      newer = generate(media_import(media_source, status: :failed))

      assert [%MediaSource{latest_import: %MediaImport{id: latest_id, status: :failed}}] =
               list_media_sources!(actor: admin, load: [:latest_import])

      assert latest_id == newer.id
    end

    test "loads :latest_import as nil when the Media Source has no Media Imports" do
      admin = generate(administrator())
      generate(media_source(actor: admin))

      assert [%MediaSource{latest_import: nil}] =
               list_media_sources!(actor: admin, load: [:latest_import])
    end
  end
end
