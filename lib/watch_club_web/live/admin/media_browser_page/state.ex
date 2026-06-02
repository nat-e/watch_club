defmodule WatchClubWeb.Admin.MediaBrowserPage.State do
  @moduledoc """
  Transient state for the Admin Media browser LiveView.

  One umbrella struct that bundles four concerns the page tracks:

    * `Filter` — what the user has narrowed the list down to
    * `Sort`   — which column drives the order
    * `Stream` — pagination cursor + has-more flag for keyset paging
    * `Drawer` — which Media (if any) is open in the right panel

  Each concern lives as a nested submodule under this file. The page mounts
  with `State.new/0`, reads `state.filter` / `state.sort` from URL params via
  `from_params/1`, and writes them back via `to_query_params/1` so the
  filtered view is bookmarkable.
  """

  alias WatchClubWeb.Admin.MediaBrowserPage.State

  defstruct filter: nil, sort: nil, stream: nil, drawer: nil

  @type t :: %__MODULE__{
          filter: State.Filter.t(),
          sort: State.Sort.t(),
          stream: State.Stream.t(),
          drawer: State.Drawer.t()
        }

  @spec new() :: t()
  def new do
    %__MODULE__{
      filter: State.Filter.new(),
      sort: State.Sort.new(),
      stream: State.Stream.new(),
      drawer: State.Drawer.new()
    }
  end

  @spec from_params(map()) :: t()
  def from_params(params) when is_map(params) do
    %__MODULE__{
      filter: State.Filter.from_params(params),
      sort: State.Sort.from_params(params),
      stream: State.Stream.new(),
      drawer: State.Drawer.new()
    }
  end

  @doc """
  Returns the filter + sort URL params for the current state.

  Stream pagination cursor and drawer selection are transient and *not*
  carried in the URL.
  """
  @spec to_query_params(t()) :: %{optional(binary()) => binary()}
  def to_query_params(%__MODULE__{filter: f, sort: s}) do
    Map.merge(State.Filter.to_query_params(f), State.Sort.to_query_params(s))
  end

  @doc """
  Returns the arguments map to pass to `WatchClub.MediaCatalog.browse_media/2`.
  """
  @spec browse_arguments(t()) :: map()
  def browse_arguments(%__MODULE__{filter: f, sort: s}) do
    %{}
    |> maybe_put(:search, f.search)
    |> maybe_put(:media_type, f.media_type)
    |> maybe_put(:club_id, f.club_id)
    |> Map.put(:sort_by, s.by)
    |> Map.put(:sort_order, s.order)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # --------------------------------------------------------------------------
  # Filter
  # --------------------------------------------------------------------------

  defmodule Filter do
    @moduledoc """
    Filter portion of the page state.

    `search`     — free-text search across Media path and attached-content
                   titles.
    `media_type` — `:video | :ebook | :audiobook | nil`
    `club_id`    — UUID of the Club to narrow by, or `nil`.
    """

    defstruct search: "",
              media_type: nil,
              club_id: nil

    @type t :: %__MODULE__{
            search: String.t(),
            media_type: :video | :ebook | :audiobook | nil,
            club_id: binary() | nil
          }

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @spec set(t(), atom(), term()) :: t()
    def set(%__MODULE__{} = f, key, value) when key in [:search, :media_type, :club_id] do
      Map.put(f, key, normalize(key, value))
    end

    @spec clear(t()) :: t()
    def clear(%__MODULE__{}), do: new()

    @spec active?(t()) :: boolean()
    def active?(%__MODULE__{} = f) do
      f.search not in [nil, ""] or
        not is_nil(f.media_type) or
        not is_nil(f.club_id)
    end

    @spec from_params(map()) :: t()
    def from_params(params) when is_map(params) do
      %__MODULE__{
        search: params["search"] || "",
        media_type: parse_atom(params["media_type"], [:video, :ebook, :audiobook]),
        club_id: nilify_blank(params["club_id"])
      }
    end

    @spec to_query_params(t()) :: %{optional(binary()) => binary()}
    def to_query_params(%__MODULE__{} = f) do
      %{}
      |> put_if(f.search not in [nil, ""], "search", f.search)
      |> put_if(not is_nil(f.media_type), "media_type", to_string(f.media_type))
      |> put_if(not is_nil(f.club_id), "club_id", f.club_id)
    end

    defp put_if(map, true, k, v), do: Map.put(map, k, v)
    defp put_if(map, false, _k, _v), do: map

    defp normalize(:search, nil), do: ""
    defp normalize(:search, v) when is_binary(v), do: v
    defp normalize(_k, ""), do: nil
    defp normalize(_k, v), do: v

    defp parse_atom(nil, _allowed), do: nil
    defp parse_atom("", _allowed), do: nil

    defp parse_atom(value, allowed) when is_binary(value) do
      string_allowed = Enum.map(allowed, &Atom.to_string/1)

      if value in string_allowed do
        String.to_existing_atom(value)
      else
        nil
      end
    end

    defp parse_atom(value, allowed) when is_atom(value) do
      if value in allowed, do: value, else: nil
    end

    defp nilify_blank(nil), do: nil
    defp nilify_blank(""), do: nil
    defp nilify_blank(v) when is_binary(v), do: v
  end

  # --------------------------------------------------------------------------
  # Sort
  # --------------------------------------------------------------------------

  defmodule Sort do
    @moduledoc """
    Sort portion of the page state.

    Valid fields: `:imported_at | :path`. Direction reuses
    `WatchClub.Shared.SortOrder` (`:asc | :desc`). Default: `imported_at desc`.
    """

    alias WatchClub.Shared.SortOrder

    @valid_fields ~w(imported_at path)a

    defstruct by: :imported_at, order: :desc

    @type t :: %__MODULE__{
            by: :imported_at | :path,
            order: SortOrder.t()
          }

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @spec valid_fields() :: [atom()]
    def valid_fields, do: @valid_fields

    @spec set(t(), atom(), SortOrder.t()) :: t()
    def set(%__MODULE__{} = s, by, order)
        when by in @valid_fields and order in [:asc, :desc] do
      %{s | by: by, order: order}
    end

    @spec toggle_order(t()) :: t()
    def toggle_order(%__MODULE__{order: order} = s) do
      %{s | order: SortOrder.switch(order)}
    end

    @spec from_params(map()) :: t()
    def from_params(params) when is_map(params) do
      by = parse_field(params["sort_by"]) || :imported_at

      order =
        case SortOrder.parse_param(params["sort_order"] || "") do
          {:ok, value} -> value
          :error -> :desc
        end

      %__MODULE__{by: by, order: order}
    end

    @spec to_query_params(t()) :: %{optional(binary()) => binary()}
    def to_query_params(%__MODULE__{by: :imported_at, order: :desc}), do: %{}

    def to_query_params(%__MODULE__{by: by, order: order}) do
      %{"sort_by" => to_string(by), "sort_order" => to_string(order)}
    end

    defp parse_field(nil), do: nil
    defp parse_field(""), do: nil

    defp parse_field(value) when is_binary(value) do
      string_allowed = Enum.map(@valid_fields, &Atom.to_string/1)

      if value in string_allowed do
        String.to_existing_atom(value)
      else
        nil
      end
    end
  end

  # --------------------------------------------------------------------------
  # Stream (pagination cursor for keyset paging)
  # --------------------------------------------------------------------------

  defmodule Stream do
    @moduledoc """
    Pagination cursor state for the streamed media list.

    Covers the same ground as `WatchClubWeb.Helpers.KeysetStreamState` (the shared
    infinite-scroll bookkeeping used by the library and My Requests pages):
    tracks the keyset for the next page and whether more rows remain. A
    candidate to converge onto that module — see `append/2` below.
    """

    defstruct next_keyset: nil, can_load_more?: false, empty?: true

    @type t :: %__MODULE__{
            next_keyset: term() | nil,
            can_load_more?: boolean(),
            empty?: boolean()
          }

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @doc """
    Updates the stream cursor from an `Ash.Page.Keyset` page.

    A `:reset?` flag distinguishes the initial / re-filter case (empty
    stream replaced by a fresh first page) from append (a load_more append).
    """
    @spec append(t(), Ash.Page.Keyset.t()) :: t()
    def append(%__MODULE__{}, %Ash.Page.Keyset{} = page) do
      %__MODULE__{
        next_keyset: page.more?,
        can_load_more?: page.more? != false and page.more? != nil,
        empty?: page.results == []
      }
    end

    def append(%__MODULE__{} = stream, results) when is_list(results) do
      %{stream | empty?: results == [], can_load_more?: false, next_keyset: nil}
    end

    @spec reset(t()) :: t()
    def reset(%__MODULE__{}), do: new()

    @spec can_load_more?(t()) :: boolean()
    def can_load_more?(%__MODULE__{can_load_more?: v}), do: v

    @spec empty?(t()) :: boolean()
    def empty?(%__MODULE__{empty?: v}), do: v
  end

  # --------------------------------------------------------------------------
  # Drawer
  # --------------------------------------------------------------------------

  defmodule Drawer do
    @moduledoc """
    Drawer portion of the page state — which Media is currently open in the
    right panel, with its heavy preload tree.
    """

    defstruct open?: false, media: nil, confirm_remove_open?: false

    @type t :: %__MODULE__{open?: boolean(), media: term() | nil, confirm_remove_open?: boolean()}

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @spec open(t(), term()) :: t()
    def open(%__MODULE__{} = d, media),
      do: %{d | open?: true, media: media, confirm_remove_open?: false}

    @spec close(t()) :: t()
    def close(%__MODULE__{}), do: new()

    @spec open?(t()) :: boolean()
    def open?(%__MODULE__{open?: v}), do: v

    @spec open_confirm_remove(t()) :: t()
    def open_confirm_remove(%__MODULE__{} = d), do: %{d | confirm_remove_open?: true}

    @spec close_confirm_remove(t()) :: t()
    def close_confirm_remove(%__MODULE__{} = d), do: %{d | confirm_remove_open?: false}
  end
end
