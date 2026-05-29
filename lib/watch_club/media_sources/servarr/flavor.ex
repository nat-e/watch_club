defmodule WatchClub.MediaSources.Servarr.Flavor do
  @moduledoc """
  The Servarr product a Media Source talks to (Radarr / Sonarr), as an
  `Ash.Type.Enum`.

  Carries the per-flavor knowledge WatchClub needs when it acts *on* the
  source: the product `label/1` (also the `appName` the server reports on
  `/api/v3/system/status`), and the notification event flags to subscribe
  to (the one part of the webhook payload that differs between products).
  Catalog endpoints stay in the `Radarr` / `Sonarr` integration facades;
  everything else goes through the flavor-agnostic `Servarr.Client`.
  """

  use Ash.Type.Enum,
    values: [
      radarr: [label: "Radarr", description: "A Radarr server (movies)"],
      sonarr: [label: "Sonarr", description: "A Sonarr server (TV shows)"]
    ]

  @shared_event_flags [
    :onGrab,
    :onDownload,
    :onUpgrade,
    :onRename,
    :onHealthIssue,
    :onHealthRestored,
    :onApplicationUpdate,
    :onManualInteractionRequired
  ]

  @radarr_event_flags @shared_event_flags ++
                        [
                          :onMovieAdded,
                          :onMovieDelete,
                          :onMovieFileDelete,
                          :onMovieFileDeleteForUpgrade
                        ]

  @sonarr_event_flags @shared_event_flags ++
                        [
                          :onSeriesAdd,
                          :onSeriesDelete,
                          :onEpisodeFileDelete,
                          :onEpisodeFileDeleteForUpgrade
                        ]

  @doc """
  The notification event flags WatchClub subscribes to when registering its
  webhook. Shared flags plus the flavor's content-entity events (`onMovie*`
  vs `onSeries*` / `onEpisodeFile*`).
  """
  @spec webhook_event_flags(t()) :: [atom()]
  def webhook_event_flags(:radarr), do: @radarr_event_flags
  def webhook_event_flags(:sonarr), do: @sonarr_event_flags
end
