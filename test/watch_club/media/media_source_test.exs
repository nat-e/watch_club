defmodule WatchClub.Media.MediaSourceTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.{MediaImport, MediaSource}

  require Ash.Query

  describe "create_filesystem_media_source/*" do
    test "creates a filesystem Media Source with normalized path and auto-computed name" do
      admin = generate(administrator())
      path = "tmp/media-imports/../movies"

      assert %MediaSource{
               source_type: :filesystem,
               media_type: :movie,
               filesystem_path: normalized_path,
               name: name
             } =
               create_filesystem_media_source!(
                 %{media_type: :movie, filesystem_path: path},
                 actor: admin
               )

      assert normalized_path == Path.expand(path)
      assert name == "Filesystem: #{normalized_path}"
    end

    test "uses the caller-provided name when one is supplied" do
      admin = generate(administrator())

      assert %MediaSource{name: "Main movie library"} =
               create_filesystem_media_source!(
                 %{
                   name: "Main movie library",
                   media_type: :movie,
                   filesystem_path: "tmp/movies"
                 },
                 actor: admin
               )
    end

    test "auto-computes the name when the caller passes a blank string" do
      admin = generate(administrator())

      assert %MediaSource{filesystem_path: normalized_path, name: name} =
               create_filesystem_media_source!(
                 %{name: "", media_type: :movie, filesystem_path: "tmp/movies"},
                 actor: admin
               )

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
  end

  describe "update_media_source/*" do
    test "updates the filesystem path and re-normalizes it" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))
      path = "tmp/media-imports/../movie-updates"

      assert %MediaSource{filesystem_path: normalized_path} =
               update_media_source!(media_source, %{filesystem_path: path}, actor: admin)

      assert normalized_path == Path.expand(path)
    end
  end

  describe "destroy_media_source/*" do
    test "destroys a Media Source and nullifies the FK on past Media Imports" do
      admin = generate(administrator())
      media_source = generate(media_source(actor: admin))
      media_import = generate(media_import(media_source))

      assert :ok = destroy_media_source!(media_source, actor: admin)

      refute MediaSource
             |> Ash.Query.filter(id == ^media_source.id)
             |> Ash.exists?(authorize?: false)

      assert %MediaImport{media_source_id: nil} =
               Ash.get!(MediaImport, media_import.id, authorize?: false)
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
