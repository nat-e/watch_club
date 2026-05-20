defmodule WatchClub.Media.MediaImportTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.MediaImport

  describe "trigger_media_import/*" do
    test "creates a Pending Media Import with a configuration snapshot" do
      admin = generate(administrator())

      configuration =
        generate(
          media_import_configuration(
            actor: admin,
            content_type: :book,
            media_type: :ebook
          )
        )

      assert %MediaImport{
               status: :pending,
               configuration_id: configuration_id,
               refresh_metadata?: false,
               triggered_manually?: true,
               configuration_snapshot: snapshot
             } = trigger_media_import!(configuration.id, actor: admin)

      assert configuration_id == configuration.id

      assert snapshot == %{
               "id" => configuration.id,
               "name" => "Book Ebook Filesystem: #{configuration.filesystem_path}",
               "source_type" => "filesystem",
               "content_type" => "book",
               "media_type" => "ebook",
               "filesystem_path" => configuration.filesystem_path
             }
    end

    test "can refresh metadata for manually triggered imports" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      assert %MediaImport{refresh_metadata?: true} =
               trigger_media_import!(configuration.id, %{refresh_metadata?: true}, actor: admin)
    end

    test "rejects attempts to mark manually triggered imports as scheduled" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      trigger_media_import(configuration.id, %{triggered_manually?: false}, actor: admin)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Invalid.NoSuchInput{input: :triggered_manually?} -> true
        _ -> false
      end)
    end

    test "allows multiple Pending Media Imports for one configuration" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      assert %MediaImport{status: :pending} =
               trigger_media_import!(configuration.id, actor: admin)

      assert %MediaImport{status: :pending} =
               trigger_media_import!(configuration.id, actor: admin)
    end

    test "only the Instance Administrator can trigger Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))

      trigger_media_import(configuration.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "list_media_imports/*" do
    test "lists Media Imports for the Instance Administrator" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      assert [%MediaImport{id: media_import_id}] = list_media_imports!(actor: admin)
      assert media_import_id == media_import.id
    end

    test "only the Instance Administrator can list Media Imports" do
      user = generate(user())

      list_media_imports(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "start_media_import/*" do
    test "starts a Pending Media Import" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      assert %MediaImport{status: :running} = start_media_import!(media_import, actor: admin)
    end

    test "only the Instance Administrator can start Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      start_media_import(media_import, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "complete_media_import/*" do
    test "completes a Running Media Import" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)
      media_import = start_media_import!(media_import, actor: admin)

      assert %MediaImport{status: :completed} = complete_media_import!(media_import, actor: admin)
    end

    test "only the Instance Administrator can complete Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)
      media_import = start_media_import!(media_import, actor: admin)

      complete_media_import(media_import, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "fail_media_import/*" do
    test "fails a Pending Media Import" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      assert %MediaImport{status: :failed} = fail_media_import!(media_import, actor: admin)
    end

    test "only the Instance Administrator can fail Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      fail_media_import(media_import, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
