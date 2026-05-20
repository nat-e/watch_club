defmodule WatchClub.Media.MediaImportTest do
  use WatchClub.DataCase

  import WatchClub.Media

  alias WatchClub.Media.MediaImport
  alias WatchClub.SystemActor

  describe "trigger_media_import/*" do
    test "creates a Pending Media Import with a configuration snapshot and enqueues processing" do
      admin = generate(administrator())

      configuration =
        generate(
          media_import_configuration(
            actor: admin,
            content_type: :book,
            media_type: :ebook
          )
        )

      media_import = trigger_media_import!(configuration.id, actor: admin)

      assert %MediaImport{
               status: :pending,
               configuration_id: configuration_id,
               refresh_metadata?: false,
               triggered_manually?: true,
               configuration_snapshot: snapshot
             } = media_import

      assert configuration_id == configuration.id

      assert snapshot == %{
               "id" => configuration.id,
               "name" => "Book Ebook Filesystem: #{configuration.filesystem_path}",
               "source_type" => "filesystem",
               "content_type" => "book",
               "media_type" => "ebook",
               "filesystem_path" => configuration.filesystem_path
             }

      assert_triggered(media_import, :process, queue: :media_imports)
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

    test "background processing completes the Media Import" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))
      media_import = trigger_media_import!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %MediaImport{status: :completed} =
               get_media_import_by_id!(media_import.id, actor: admin)
    end

    test "background processing completes queued Media Imports for one configuration" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      first_import = trigger_media_import!(configuration.id, actor: admin)
      second_import = trigger_media_import!(configuration.id, actor: admin)

      Oban.drain_queue(queue: :media_imports)

      assert %MediaImport{status: :completed} =
               get_media_import_by_id!(first_import.id, actor: admin)

      assert %MediaImport{status: :completed} =
               get_media_import_by_id!(second_import.id, actor: admin)
    end

    test "only the Instance Administrator can trigger Media Imports" do
      admin = generate(administrator())
      user = generate(user())
      configuration = generate(media_import_configuration(actor: admin))

      trigger_media_import(configuration.id, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "mark_media_import_completed/*" do
    test "completes a Processing Media Import for the system actor" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      media_import =
        Ash.Seed.seed!(MediaImport, %{
          configuration_id: configuration.id,
          status: :processing,
          refresh_metadata?: false,
          triggered_manually?: true,
          configuration_snapshot: %{"id" => configuration.id}
        })

      assert %MediaImport{status: :completed} =
               mark_media_import_completed!(media_import, actor: SystemActor.actor())
    end

    test "only the system actor can complete Media Imports" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      media_import =
        Ash.Seed.seed!(MediaImport, %{
          configuration_id: configuration.id,
          status: :processing,
          refresh_metadata?: false,
          triggered_manually?: true,
          configuration_snapshot: %{"id" => configuration.id}
        })

      mark_media_import_completed(media_import, actor: admin)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "mark_media_import_failed/*" do
    test "fails a Pending Media Import for the system actor" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      media_import =
        Ash.Seed.seed!(MediaImport, %{
          configuration_id: configuration.id,
          status: :pending,
          refresh_metadata?: false,
          triggered_manually?: true,
          configuration_snapshot: %{"id" => configuration.id}
        })

      assert %MediaImport{status: :failed} =
               mark_media_import_failed!(media_import, actor: SystemActor.actor())
    end

    test "only the system actor can fail Media Imports" do
      admin = generate(administrator())
      configuration = generate(media_import_configuration(actor: admin))

      media_import =
        Ash.Seed.seed!(MediaImport, %{
          configuration_id: configuration.id,
          status: :pending,
          refresh_metadata?: false,
          triggered_manually?: true,
          configuration_snapshot: %{"id" => configuration.id}
        })

      mark_media_import_failed(media_import, actor: admin)
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
end
