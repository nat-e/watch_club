defmodule WatchClub.PubSub do
  @moduledoc """
  Helpers and topics for the WatchClub PubSub notification service
  """
  def content_view_topic(external_id_source, external_id, user_id),
    do: "content:#{external_id_source}:#{external_id}:user:#{user_id}"
end
