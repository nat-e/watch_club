defmodule WatchClubWeb.Helpers.KeysetStreamState do
  @moduledoc """
  Bookkeeping shared by the infinite-scroll LiveView streams.

  Answers the only two questions a paginated stream asks of its state — is the
  list empty, and where does the next keyset page begin — and nothing more. The
  loaded rows live in the LiveView's `stream`, never here; this struct holds
  just the cursor and a status.

  Feed `reset/1` and `append/2` a normalized page map exposing `:more?` and
  `:next_keyset` (any extra keys, e.g. the results, are ignored). The owning
  LiveView fetches the next slice by re-issuing its read with `after:` the
  stored `next_keyset`.
  """

  @type status :: :empty | :ready | :ended
  @type page :: %{optional(any) => any, more?: boolean, next_keyset: term | nil}
  @type t :: %__MODULE__{status: status, next_keyset: term | nil}

  defstruct status: :empty, next_keyset: nil

  def initial, do: %__MODULE__{}

  @doc """
  First page, or a full reload. A page with no rows (`next_keyset: nil`)
  collapses to `:empty`.
  """
  def reset(%{next_keyset: nil}), do: %__MODULE__{status: :empty}
  def reset(page), do: from_page(page)

  @doc """
  A subsequent page appended to an already-populated stream. Never collapses to
  `:empty` — the stream already holds rows — so an exhausted page lands on
  `:ended`.
  """
  def append(_state, page), do: from_page(page)

  def empty?(%__MODULE__{status: :empty}), do: true
  def empty?(%__MODULE__{}), do: false

  def can_load_more?(%__MODULE__{status: :ready, next_keyset: next_keyset}) do
    not is_nil(next_keyset)
  end

  def can_load_more?(%__MODULE__{}), do: false

  defp from_page(%{more?: true, next_keyset: next_keyset}) do
    %__MODULE__{status: :ready, next_keyset: next_keyset}
  end

  defp from_page(%{more?: false, next_keyset: next_keyset}) do
    %__MODULE__{status: :ended, next_keyset: next_keyset}
  end
end
