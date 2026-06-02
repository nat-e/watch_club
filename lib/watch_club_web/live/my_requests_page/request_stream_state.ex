defmodule WatchClubWeb.MyRequestsPage.RequestStreamState do
  @moduledoc """
  Offset-pagination bookkeeping for the My Requests stream.

  Holds the current Ash page so the next page is a single
  `Ash.page!(page, :next)`, and answers the two questions the LiveView asks of
  it: is the list empty, and are there more rows to load. (Offset, not keyset:
  the default `:last_update` sort is the aggregate-backed `last_activity_at`
  calculation, whose value can't be encoded into a keyset cursor.)
  """

  defstruct page: nil

  def initial, do: %__MODULE__{}

  def reset(page), do: %__MODULE__{page: page}

  def next(%__MODULE__{page: page}), do: %__MODULE__{page: Ash.page!(page, :next)}

  def results(%__MODULE__{page: nil}), do: []
  def results(%__MODULE__{page: page}), do: page.results

  def empty?(%__MODULE__{page: nil}), do: true
  def empty?(%__MODULE__{page: %{results: []}}), do: true
  def empty?(%__MODULE__{}), do: false

  def can_load_more?(%__MODULE__{page: %{more?: more?}}), do: more?
  def can_load_more?(%__MODULE__{}), do: false
end
