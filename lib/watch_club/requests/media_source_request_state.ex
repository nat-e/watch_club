defmodule WatchClub.Requests.MediaSourceRequestState do
  @moduledoc """
  The progress of a `MediaSourceRequest` in its upstream system.

  Recomputed from the *arr's *current truth* (the resource + its download
  queue), never driven by individual webhook events — so it can't oscillate
  and a poll and a webhook share the same code path. Just a plain enum: any
  value can follow any other (a file deleted upstream really is
  `downloaded → submitted`), so there is no state machine.
  """
  use Ash.Type.Enum,
    values: [
      :submitted,
      :not_released,
      :downloading,
      :partially_downloaded,
      :downloaded,
      :needs_attention
    ]
end
