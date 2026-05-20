defmodule WatchClub.Media.MediaImportConfigurationTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{MediaImport, MediaImportConfiguration}

  require Ash.Query

  describe "create_filesystem_media_import_configuration/*" do
    test "creates a filesystem Media Import Configuration" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %MediaImportConfiguration{
               source_type: :filesystem,
               content_type: :movie,
               media_type: :video,
               filesystem_path: normalized_path,
               disabled?: false,
               name: name
             } =
               create_filesystem_media_import_configuration!(
                 %{content_type: :movie, media_type: :video, filesystem_path: path},
                 actor: admin,
                 load: [:name]
               )

      assert normalized_path == Path.expand(path)
      assert name == "Movie Video Filesystem: #{normalized_path}"
    end

    test "allows duplicate and overlapping Media Import Configurations" do
      admin = generate(administrator())
      path = "tmp/media-imports/duplicates"

      assert %MediaImportConfiguration{} =
               create_filesystem_media_import_configuration!(
                 %{content_type: :movie, media_type: :video, filesystem_path: path},
                 actor: admin
               )

      assert %MediaImportConfiguration{} =
               create_filesystem_media_import_configuration!(
                 %{content_type: :movie, media_type: :video, filesystem_path: path},
                 actor: admin
               )
    end

    test "rejects incompatible Content Type and Media Type combinations" do
      admin = generate(administrator())

      create_filesystem_media_import_configuration(
        %{content_type: :movie, media_type: :ebook, filesystem_path: "tmp/imports/books"},
        actor: admin
      )
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :media_type} -> true
        _ -> false
      end)
    end

    test "only the Instance Administrator can create Media Import Configurations" do
      user = generate(user())

      create_filesystem_media_import_configuration(
        %{content_type: :movie, media_type: :video, filesystem_path: "tmp/imports/movies"},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_media_import_configuration/*" do
    test "updates only the filesystem path and regenerates the name" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %MediaImportConfiguration{
               source_type: :filesystem,
               content_type: :movie,
               media_type: :video,
               disabled?: false,
               filesystem_path: normalized_path,
               name: name
             } =
               update_media_import_configuration!(configuration, %{filesystem_path: path},
                 actor: admin,
                 load: [:name]
               )

      assert normalized_path == Path.expand(path)
      assert name == "Movie Video Filesystem: #{normalized_path}"
    end

    test "rejects attempts to change the Content Type" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      update_media_import_configuration(configuration, %{content_type: :book}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Invalid.NoSuchInput{input: :content_type} -> true
        _ -> false
      end)
    end

    test "only the Instance Administrator can update Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))

      update_media_import_configuration(configuration, %{filesystem_path: "tmp/other"},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "disable_media_import_configuration/*" do
    test "disables a Media Import Configuration" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      assert %MediaImportConfiguration{disabled?: true} =
               disable_media_import_configuration!(configuration, actor: admin)
    end

    test "only the Instance Administrator can disable Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))

      disable_media_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "enable_media_import_configuration/*" do
    test "enables a Media Import Configuration" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(disabled?: true))

      assert %MediaImportConfiguration{disabled?: false} =
               enable_media_import_configuration!(configuration, actor: admin)
    end

    test "only the Instance Administrator can enable Media Import Configurations" do
      user = generate(user())
      configuration = generate(media_import_configuration(disabled?: true))

      enable_media_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "destroy_media_import_configuration/*" do
    test "destroys a Media Import Configuration without deleting past Media Imports" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      media_import = generate(media_import(configuration))

      assert :ok = destroy_media_import_configuration!(configuration, actor: admin)

      refute MediaImportConfiguration
             |> Ash.Query.filter(id == ^configuration.id)
             |> Ash.exists?(authorize?: false)

      assert %MediaImport{configuration_id: nil} =
               Ash.get!(MediaImport, media_import.id, authorize?: false)
    end

    test "only the Instance Administrator can destroy Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))

      destroy_media_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
