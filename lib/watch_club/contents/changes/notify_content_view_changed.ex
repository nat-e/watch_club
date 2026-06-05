defmodule WatchClub.Contents.Changes.NotifyContentViewChanged do
  @moduledoc """
  Sends a PubSub notification after an action that changes how a ContentView is presented to a given user.
  :content_path must be provided, a key or path (list of keys) locating the content on the action's record (e.g. :content or [:tv_show, :content]).

  We cannot use the built-in Ash.Notifier.PubSub because it doesn't support the actor id as part of the key
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    content_path = opts[:content_path]

    case content_path do
      nil ->
        {:error, ":content_path must be provided"}

      content_path when is_atom(content_path) or is_list(content_path) ->
        {:ok, opts}

      _ ->
        {:error, ":content_path must be a key or path (list of keys) to the content"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, record} = result ->
        content_path = opts |> Keyword.fetch!(:content_path) |> List.wrap()
        record = Ash.load!(record, content_path, authorize?: false)

        content = Enum.reduce(content_path, record, fn key, acc -> Map.fetch!(acc, key) end)

        notification =
          Ash.Notifier.Notification.new(changeset.resource,
            action: changeset.action,
            data: record,
            actor: context.actor,
            metadata: %{
              subject: :content_view_changed,
              content_id: content.id,
              external_id_source: content.external_id_source,
              external_id: content.external_id
            }
          )

        Phoenix.PubSub.broadcast(
          WatchClub.PubSub,
          WatchClub.PubSub.content_view_topic(
            content.external_id_source,
            content.external_id,
            context.actor.id
          ),
          notification
        )

        result

      _changeset, result ->
        # Don't notify when the action fails
        result
    end)
  end
end
