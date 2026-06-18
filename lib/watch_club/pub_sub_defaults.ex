defmodule WatchClub.PubSubDefaults do
  @moduledoc """
  Shared PubSub configuration for all resources: broadcasts go through
  `WatchClub.PubSub` wrapped in `%Phoenix.Socket.Broadcast{}` envelopes.
  """
  use Spark.Dsl.Fragment, of: Ash.Resource, notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub
    broadcast_type :phoenix_broadcast
  end
end
