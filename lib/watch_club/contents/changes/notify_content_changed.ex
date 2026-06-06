defmodule WatchClub.Contents.Changes.NotifyContentChanged do
  @moduledoc """
  Sends a PubSub notification after an action that changes a Content.

  :content A key or path (list of keys) for resolving the content from the Resource being changed (e.g. :content or [:tv_show, :content]).
  If the :content resolves to a nil record, the notification is not broadcasted

  :user An optional key or path (list of keys) for resolving the User(s). When set, the notification is published to each resolved user's ContentView PubSub
  topic. A path may fan out (e.g. a `has_many` like [:user_requests, :user] resolves to every requester). When unset, the notification is sent to a global
  Content topic (use for changes that are not specific to a given user). The `:__actor` atom can be used to resolve the user to the action actor.

  We cannot use the built-in Ash.Notifier.PubSub because it doesn't support the actor id as part of the key
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    content = opts[:content]

    case content do
      nil ->
        {:error, ":content must be provided"}

      content when is_atom(content) or is_list(content) ->
        {:ok, opts}

      _ ->
        {:error, ":content must be a key or path (list of keys) to the content"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    changeset
    |> snapshot_content_before_destroy(opts, context)
    |> Ash.Changeset.after_transaction(fn
      changeset, {:ok, record} = result ->
        {content, user_ids} =
          case changeset.context[:notify_content_changed] do
            nil ->
              content = resolve_content(opts, record)
              {content, content && resolve_user_ids(opts, record, context)}

            snapshot ->
              {snapshot.content, snapshot.user_ids}
          end

        case content do
          nil ->
            result

          content ->
            notification =
              Ash.Notifier.Notification.new(changeset.resource,
                action: changeset.action,
                data: record,
                actor: context.actor,
                metadata: %{
                  subject: :content_changed,
                  content_id: content.id,
                  external_id_source: content.external_id_source,
                  external_id: content.external_id
                }
              )

            broadcast(content, user_ids, notification)
            result
        end

      _changeset, result ->
        # Don't notify when the action fails
        result
    end)
  end

  # A destroy cascades away the rows the content path traverses, so by the time the
  # after_transaction broadcast runs the content is unreachable. Resolve and stash it
  # (with the user to notify) in a before_action, while the rows still exist.
  defp snapshot_content_before_destroy(changeset, opts, context) do
    if changeset.action_type == :destroy do
      Ash.Changeset.before_action(changeset, fn changeset ->
        content = resolve_content(opts, changeset.data)
        user_ids = content && resolve_user_ids(opts, changeset.data, context)

        Ash.Changeset.put_context(changeset, :notify_content_changed, %{
          content: content,
          user_ids: user_ids
        })
      end)
    else
      changeset
    end
  end

  # nil user_ids => not user-scoped, broadcast to the global content topic.
  # A list => one notification per user's content-view topic ([] notifies nobody).
  defp broadcast(content, nil, notification),
    do:
      Phoenix.PubSub.broadcast(
        WatchClub.PubSub,
        WatchClub.PubSub.content_topic(content.external_id_source, content.external_id),
        notification
      )

  defp broadcast(content, user_ids, notification),
    do:
      Enum.each(user_ids, fn user_id ->
        Phoenix.PubSub.broadcast(
          WatchClub.PubSub,
          WatchClub.PubSub.content_view_topic(
            content.external_id_source,
            content.external_id,
            user_id
          ),
          notification
        )
      end)

  defp resolve_content(opts, record) do
    path = opts |> Keyword.fetch!(:content) |> List.wrap()
    record |> resolve_path(path) |> List.first()
  end

  defp resolve_user_ids(opts, record, context) do
    case Keyword.get(opts, :user) do
      nil ->
        nil

      :__actor ->
        [context.actor.id]

      path ->
        record |> resolve_path(List.wrap(path)) |> Enum.map(& &1.id)
    end
  end

  # Walks the path, flat-mapping each step so a key resolving to a `has_many`
  # fans out: each step keeps only the present values (`nil` and `[]` drop out).
  defp resolve_path(record, path) do
    record = load_path(record, path)

    Enum.reduce(path, [record], fn key, records ->
      Enum.flat_map(records, fn record -> record |> Map.get(key) |> List.wrap() end)
    end)
  end

  defp load_path(record, path) do
    # path is a flat traversal path; nest it into a load statement
    # so Ash loads down the chain, e.g. [:video, :content] -> [video: :content]
    load_statement =
      path
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.reduce(fn key, nested -> [{key, nested}] end)

    Ash.load!(record, load_statement, authorize?: false)
  end
end
