defmodule WatchClub.Contents.Changes.CreateContentNotification do
  @moduledoc """
  Emits a `:content_changed` notification after an action that changes a Content.

  Resolves the content and the user(s) to notify from the changed record, then
  hands the notification to `WatchClub.Contents.Notifiers.ContentChangedNotifier`
  (declared on the resource) for the broadcast — so resolution lives at the call
  site while the broadcast stays in one place.

  :content A key or path (list of keys) for resolving the content from the
  changed record (e.g. :content or [:tv_show, :content]). If it resolves to a
  nil record, no notification is emitted. Omit when the record is the Content.

  :user An optional key or path for resolving the User(s) to notify; each is
  notified on their ContentView PubSub topic. A path may fan out (e.g. a
  `has_many` like [:user_requests, :user] resolves to every requester). The
  `:__actor` atom resolves to the action actor. When unset, the notification is
  sent to a global Content topic (use for changes not specific to a given user).
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.Notifiers.ContentChangedNotifier

  @impl true
  def init(opts) do
    case opts[:content] do
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
    |> Ash.Changeset.after_action(fn changeset, record ->
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
          {:ok, record}

        content ->
          notification =
            ContentChangedNotifier.create_notification(
              changeset.resource,
              changeset.action,
              content,
              user_ids || :global,
              context.actor
            )

          {:ok, record, [notification]}
      end
    end)
  end

  # A destroy cascades away the rows the content path traverses, so by the time
  # the after_action runs the content is unreachable. Resolve and stash it (with
  # the users to notify) in a before_action, while the rows still exist.
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

  defp resolve_content(opts, record) do
    record |> resolve_path(opts[:content]) |> List.first()
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
  defp resolve_path(record, nil), do: [record]
  defp resolve_path(record, []), do: [record]

  defp resolve_path(record, path) do
    record = load_path(record, path)

    Enum.reduce(path, [record], fn key, records ->
      Enum.flat_map(records, fn record -> record |> Map.get(key) |> List.wrap() end)
    end)
  end

  defp load_path(record, nil), do: record
  defp load_path(record, []), do: record

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
