defmodule WatchClub.Media.ImportConfigurationTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{ImportConfiguration, ImportRun}

  require Ash.Query

  describe "create_filesystem_import_configuration/*" do
    test "creates a filesystem configuration with normalized path and computed name" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %ImportConfiguration{
               source_type: :filesystem,
               media_type: :movie,
               filesystem_path: normalized_path,
               disabled?: false,
               name: name
             } =
               create_filesystem_import_configuration!(
                 %{media_type: :movie, filesystem_path: path},
                 actor: admin,
                 load: [:name]
               )

      assert normalized_path == Path.expand(path)
      assert name == "Movie Filesystem: #{normalized_path}"
    end

    test "rejects non-admin actors" do
      user = generate(user())

      create_filesystem_import_configuration(
        %{media_type: :movie, filesystem_path: "tmp/imports/movies"},
        actor: user
      )
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "update_import_configuration/*" do
    test "updates the filesystem path and re-normalizes it" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %ImportConfiguration{filesystem_path: normalized_path} =
               update_import_configuration!(configuration, %{filesystem_path: path}, actor: admin)

      assert normalized_path == Path.expand(path)
    end
  end

  describe "disable_import_configuration/*" do
    test "disables a configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert %ImportConfiguration{disabled?: true} =
               disable_import_configuration!(configuration, actor: admin)
    end
  end

  describe "enable_import_configuration/*" do
    test "enables a configuration" do
      admin = generate(administrator())
      configuration = generate(import_configuration(disabled?: true))

      assert %ImportConfiguration{disabled?: false} =
               enable_import_configuration!(configuration, actor: admin)
    end
  end

  describe "destroy_import_configuration/*" do
    test "destroys a configuration and nullifies the FK on past runs" do
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
  end

  describe "list_import_configurations/*" do
    test "lists configurations for an administrator" do
      admin = generate(administrator())
      configuration = generate(import_configuration(actor: admin))

      assert [%ImportConfiguration{id: id}] = list_import_configurations!(actor: admin)
      assert id == configuration.id
    end
  end
end
