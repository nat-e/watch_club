defmodule WatchClub.MediaSources.Servarr.Sportarr do
  @moduledoc """
  Sportarr as a `WatchClub.MediaSources.Servarr.App`: one Sports Event per Sportarr
  event, identified by its Sportarr ID, with one Candidate per file, such as its
  Prelims and its Main Card.

  Sportarr's Sonarr-compatible API covers the setup, but not events and their
  files, so this module uses Sportarr's own API for those and for the webhook.
  """
  @behaviour WatchClub.MediaSources.Servarr.App

  alias WatchClub.Contents.{Content, ContentIdentity, SportsEvent}
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Integrations.Sportarr, as: SportarrApi
  alias WatchClub.Integrations.Sportarr.{Event, QueueItem}
  alias WatchClub.Integrations.SportarrHub
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.SportsEventIdentity
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.MediaSources.Servarr.App
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  @impl true
  def media_type, do: :sports_event

  @impl true
  def notifications_path, do: "/api/notification"

  # Sportarr's own notification: its settings are a JSON string, and so are its headers.
  @impl true
  def webhook_notification(%{name: name, callback_url: callback_url, token: token}) do
    %{
      name: name,
      implementation: "Webhook",
      enabled: true,
      configJson:
        Jason.encode!(%{
          url: callback_url,
          method: "POST",
          headers: Jason.encode!(%{"X-WatchClub-Token" => token}),
          onGrab: true,
          onDownload: true,
          onUpgrade: true,
          onRename: true,
          onEventDelete: true,
          onEventFileDelete: true,
          onEventFileDeleteForUpgrade: true,
          onManualInteractionRequired: true
        })
    }
  end

  # Lists the files of every league's events under this source's root folder.
  @impl true
  def scan!(%Servarr{} = servarr) do
    Logger.info("Fetch events from Sportarr", event: :sportarr_fetch_started)

    {:ok, leagues} = SportarrApi.list_leagues(servarr.base_url, servarr.api_key)

    candidates =
      for league <- leagues,
          {:ok, events} =
            SportarrApi.list_league_events(servarr.base_url, servarr.api_key, league.id),
          event <- events,
          candidate <- event_candidates(servarr, event),
          do: candidate

    Logger.info("Found #{length(candidates)} eligible files",
      event: :sportarr_scan_finished,
      num_candidates: length(candidates)
    )

    candidates
  end

  defp event_candidates(_servarr, %Event{external_id: nil}), do: []

  defp event_candidates(servarr, %Event{} = event) do
    for server_path <- event.file_paths,
        path = App.local_path(servarr, server_path),
        is_binary(path),
        do: candidate(path, event.external_id)
  end

  defp candidate(path, sportarr_id) do
    %Candidate{
      path: path,
      media_type: :sports_event,
      identity: %SportsEventIdentity{sportarr_id: sportarr_id}
    }
  end

  # Sportarr's webhooks look like Sonarr's: its event is the `series`.
  @impl true
  def interpret_webhook!(%Servarr{} = servarr, %{
        "eventType" => "Download",
        "series" => %{"id" => id, "externalId" => sportarr_id},
        "episodeFile" => %{"path" => server_path}
      }) do
    ingest =
      case App.local_path(servarr, server_path) do
        nil ->
          Logger.warning("sportarr webhook: file doesn't match source")
          []

        path ->
          [{:ingest, [candidate(path, sportarr_id)]}]
      end

    ingest ++ [{:refresh_request, id}]
  end

  def interpret_webhook!(%Servarr{} = servarr, %{
        "eventType" => "EpisodeFileDelete",
        "series" => %{"id" => id},
        "deletedFiles" => files
      }) do
    remove =
      for %{"path" => server_path} <- files,
          path = App.local_path(servarr, server_path),
          is_binary(path),
          do: {:remove_media, path}

    remove ++ [{:refresh_request, id}]
  end

  # A Rename only counts the renamed files, so import the event's files again and
  # drop the Media whose old paths are gone.
  def interpret_webhook!(%Servarr{} = servarr, %{
        "eventType" => "Rename",
        "series" => %{"id" => id, "externalId" => sportarr_id}
      }) do
    event = SportarrApi.get_event!(servarr.base_url, servarr.api_key, id)

    [
      {:ingest, event_candidates(servarr, event)},
      {:remove_missing_media, ContentIdentity.for_sports_event(sportarr_id)}
    ]
  end

  def interpret_webhook!(_servarr, %{"eventType" => "SeriesDelete", "series" => %{"id" => id}}),
    do: [{:forget_request, id}]

  # Any other event about an event (Grab, ManualInteractionRequired…) refreshes its request.
  def interpret_webhook!(_servarr, %{"series" => %{"id" => id}}) when is_integer(id),
    do: [{:refresh_request, id}]

  def interpret_webhook!(_servarr, _params), do: []

  # Sportarr files events under their league, so add the league first when it's
  # missing, without downloading its other events.
  @impl true
  def submit_request!(%Servarr{} = servarr, %Content{implementation: %SportsEvent{}} = content) do
    {:ok, event} = SportarrHub.get_event(content.external_id)

    {:ok, event_id} =
      SportarrApi.request_event(servarr.base_url, servarr.api_key, %{
        externalId: event.id,
        title: event.title,
        sport: event.sport,
        leagueId: event.league_id && league_id!(servarr, event),
        season: event.season,
        eventDate: event.starts_at,
        qualityProfileId: servarr.quality_profile_id
      })

    {:ok, event_id}
  end

  defp league_id!(servarr, %SportarrHub.Event{} = event) do
    {:ok, leagues} = SportarrApi.list_leagues(servarr.base_url, servarr.api_key)

    case Enum.find(leagues, &(&1.external_id == event.league_id)) do
      %{id: id} ->
        id

      nil ->
        {:ok, id} =
          SportarrApi.add_league(servarr.base_url, servarr.api_key, %{
            externalId: event.league_id,
            name: event.league_name,
            sport: event.sport,
            rootFolderId: root_folder_id!(servarr),
            qualityProfileId: servarr.quality_profile_id
          })

        id
    end
  end

  defp root_folder_id!(servarr) do
    {:ok, folders} = Client.list_root_folders(servarr.base_url, servarr.api_key)
    root = Paths.normalize(servarr.root_folder_path)
    Enum.find_value(folders, &(Paths.normalize(&1.path) == root && &1.id))
  end

  @impl true
  def request_state!(%Servarr{} = servarr, event_id) do
    event = SportarrApi.get_event!(servarr.base_url, servarr.api_key, event_id)

    queue =
      servarr.base_url
      |> SportarrApi.queue!(servarr.api_key)
      |> Enum.filter(&(&1.event_id == event_id))

    {status(event, queue), progress(event, queue)}
  end

  defp status(%Event{} = event, queue) do
    cond do
      event.has_file? -> :downloaded
      Enum.any?(queue, &QueueItem.blocked?/1) -> :needs_attention
      queue != [] -> :downloading
      # After the other states: an event can be found before it happens.
      event.date && DateTime.after?(event.date, DateTime.utc_now()) -> :not_released
      true -> :searching
    end
  end

  defp progress(%Event{has_file?: true}, _queue), do: 100.0
  defp progress(_event, queue), do: queue |> Enum.map(& &1.progress) |> List.first(0.0)
end
