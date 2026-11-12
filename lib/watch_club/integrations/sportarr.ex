defmodule WatchClub.Integrations.Sportarr do
  @moduledoc """
  Sportarr's own API (`/api`), for what its Sonarr-compatible `/api/v3` lacks:
  leagues, events and their files. Sportarr's local ids are integers; its
  `externalId`s are Sportarr IDs, such as `ev-028133` for an event.
  """

  alias WatchClub.Integrations.Servarr.Client

  # Sportarr's largest page of league events
  @page_size 1000

  defmodule Event do
    @moduledoc "A Sports Event in Sportarr, with the paths of its files."

    @type t :: %__MODULE__{
            id: integer(),
            external_id: String.t() | nil,
            monitored?: boolean(),
            has_file?: boolean(),
            file_paths: [String.t()]
          }

    defstruct [:id, :external_id, monitored?: false, has_file?: false, file_paths: []]

    @doc false
    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        external_id: data["externalId"],
        monitored?: data["monitored"] == true,
        has_file?: data["hasFile"] == true,
        file_paths: for(%{"filePath" => path, "exists" => true} <- data["files"] || [], do: path)
      }
    end
  end

  defmodule QueueItem do
    @moduledoc "A download in Sportarr's queue."

    @type t :: %__MODULE__{event_id: integer(), status: atom(), progress: float()}

    defstruct [:event_id, :status, progress: 0.0]

    # In the order of Sportarr's DownloadStatus, which it sends as integers
    @statuses [
      :queued,
      :downloading,
      :paused,
      :completed,
      :failed,
      :warning,
      :importing,
      :imported,
      :import_pending,
      :import_warning
    ]

    @doc false
    def from_api(data) do
      %__MODULE__{
        event_id: data["eventId"],
        status: Enum.at(@statuses, data["status"]),
        progress: (data["progress"] || 0) * 1.0
      }
    end

    @doc "Whether the download needs the Instance Administrator."
    def blocked?(%__MODULE__{status: status}),
      do: status in [:failed, :warning, :import_warning]
  end

  @doc "Every league Sportarr follows, as `%{id, external_id}` maps."
  @spec list_leagues(String.t(), String.t()) ::
          {:ok, [%{id: integer(), external_id: String.t()}]} | {:error, Client.error()}
  def list_leagues(base_url, api_key) do
    with {:ok, leagues} <- Client.get(base_url, api_key, "/api/leagues") do
      {:ok, Enum.map(leagues, &%{id: &1["id"], external_id: &1["externalId"]})}
    end
  end

  @doc "Every event of a league, monitored or not."
  @spec list_league_events(String.t(), String.t(), integer()) ::
          {:ok, [Event.t()]} | {:error, Client.error()}
  def list_league_events(base_url, api_key, league_id, page \\ 1) do
    with {:ok, %{"records" => records, "totalPages" => total_pages}} <-
           Client.get(base_url, api_key, "/api/leagues/#{league_id}/events",
             params: [showAll: true, page: page, pageSize: @page_size]
           ) do
      events = Enum.map(records, &Event.from_api/1)

      if page < total_pages do
        with {:ok, next} <- list_league_events(base_url, api_key, league_id, page + 1),
             do: {:ok, events ++ next}
      else
        {:ok, events}
      end
    end
  end

  @spec get_event!(String.t(), String.t(), integer()) :: Event.t()
  def get_event!(base_url, api_key, event_id) do
    {:ok, event} = Client.get(base_url, api_key, "/api/events/#{event_id}")
    Event.from_api(event)
  end

  @doc """
  Adds a league without downloading any of its events, which Sportarr then lists.
  `attrs` are Sportarr's: `externalId`, `name`, `sport`, `rootFolderId`, ...
  """
  @spec add_league(String.t(), String.t(), map()) :: {:ok, integer()} | {:error, Client.error()}
  def add_league(base_url, api_key, attrs) do
    body = Map.merge(attrs, %{monitored: true, monitorType: "None", enableDvr: false})

    with {:ok, %{"id" => id}} <- Client.post(base_url, api_key, "/api/leagues", body),
         do: {:ok, id}
  end

  @doc """
  Adds an event and follows it, or follows the event Sportarr already has with this
  `externalId`, then searches for it. `attrs` are Sportarr's: `externalId`,
  `title`, `sport`, `leagueId`, `eventDate`, ...
  """
  @spec request_event(String.t(), String.t(), map()) ::
          {:ok, integer()} | {:error, Client.error()}
  def request_event(base_url, api_key, attrs) do
    body = Map.merge(attrs, %{monitored: true, searchOnAdd: true})

    case Client.post(base_url, api_key, "/api/events", body) do
      # Sportarr returns the event it already has without following or searching it
      {:ok, %{"alreadyAdded" => true, "event" => %{"id" => id}}} ->
        with {:ok, _} <- Client.put(base_url, api_key, "/api/events/#{id}", %{monitored: true}),
             {:ok, _} <-
               Client.post(base_url, api_key, "/api/event/#{id}/automatic-search", %{}),
             do: {:ok, id}

      {:ok, %{"id" => id}} ->
        {:ok, id}

      {:error, _} = error ->
        error
    end
  end

  @spec queue!(String.t(), String.t()) :: [QueueItem.t()]
  def queue!(base_url, api_key) do
    {:ok, items} = Client.get(base_url, api_key, "/api/queue")
    Enum.map(items, &QueueItem.from_api/1)
  end
end
