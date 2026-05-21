defmodule WatchClub.Media.ImportConfigurationTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{ImportConfiguration, ImportRun}

  require Ash.Query

  describe "create_filesystem_import_configuration/*" do
    test "creates a filesystem Media Import Configuration" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %ImportConfiguration{
               source_type: :filesystem,
               content_type: :movie,
               media_type: :video,
               filesystem_path: normalized_path,
               disabled?: false,
               name: name
             } =
               create_filesystem_import_configuration!(
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

      assert %ImportConfiguration{} =
               create_filesystem_import_configuration!(
                 %{content_type: :movie, media_type: :video, filesystem_path: path},
                 actor: admin
               )

      assert %ImportConfiguration{} =
               create_filesystem_import_configuration!(
                 %{content_type: :movie, media_type: :video, filesystem_path: path},
                 actor: admin
               )
    end

    test "rejects incompatible Content Type and Media Type combinations" do
      admin = generate(administrator())

      create_filesystem_import_configuration(
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

      create_filesystem_import_configuration(
        %{content_type: :movie, media_type: :video, filesystem_path: "tmp/imports/movies"},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_import_configurations/*" do
    test "lists Media Import Configurations for the Instance Administrator" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert [%ImportConfiguration{id: configuration_id}] =
               list_import_configurations!(actor: admin)

      assert configuration_id == configuration.id
    end

    test "only the Instance Administrator can list Media Import Configurations" do
      user = generate(user())

      list_import_configurations(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_import_configuration/*" do
    test "updates only the filesystem path and regenerates the name" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %ImportConfiguration{
               source_type: :filesystem,
               content_type: :movie,
               media_type: :video,
               disabled?: false,
               filesystem_path: normalized_path,
               name: name
             } =
               update_import_configuration!(configuration, %{filesystem_path: path},
                 actor: admin,
                 load: [:name]
               )

      assert normalized_path == Path.expand(path)
      assert name == "Movie Video Filesystem: #{normalized_path}"
    end

    test "rejects attempts to update source type, content type, media type, or disabled status" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      update_import_configuration(
        configuration,
        %{
          source_type: :filesystem,
          content_type: :book,
          media_type: :audiobook,
          disabled?: true,
          filesystem_path: "tmp/type-change-attempt"
        },
        actor: admin
      )
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Invalid.NoSuchInput{input: input}
        when input in [:source_type, :content_type, :media_type, :disabled?] ->
          true

        _ ->
          false
      end)
    end

    test "only the Instance Administrator can update Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))

      update_import_configuration(configuration, %{filesystem_path: "tmp/other"}, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "disable_import_configuration/*" do
    test "disables a Media Import Configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert %ImportConfiguration{disabled?: true} =
               disable_import_configuration!(configuration, actor: admin)
    end

    test "only the Instance Administrator can disable Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))

      disable_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "enable_import_configuration/*" do
    test "enables a Media Import Configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(disabled?: true))

      assert %ImportConfiguration{disabled?: false} =
               enable_import_configuration!(configuration, actor: admin)
    end

    test "only the Instance Administrator can enable Media Import Configurations" do
      user = generate(user())
      configuration = generate(import_configuration(disabled?: true))

      enable_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "destroy_import_configuration/*" do
    test "destroys a Media Import Configuration without deleting past Media Imports" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      run = generate(import_run(configuration))

      assert :ok = destroy_import_configuration!(configuration, actor: admin)

      refute ImportConfiguration
             |> Ash.Query.filter(id == ^configuration.id)
             |> Ash.exists?(authorize?: false)

      assert %ImportRun{configuration_id: nil} =
               Ash.get!(ImportRun, run.id, authorize?: false)
    end

    test "only the Instance Administrator can destroy Media Import Configurations" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(import_configuration(actor: admin))

      destroy_import_configuration(configuration, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
