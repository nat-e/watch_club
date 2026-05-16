defmodule WatchClubWeb.Clubs.LibraryPage.ContentStreamState do
  @moduledoc false

  defstruct status: :empty, next_keyset: nil

  def initial, do: %__MODULE__{}

  def reset(%{contents: []}) do
    %__MODULE__{status: :empty, next_keyset: nil}
  end

  def reset(page) do
    %__MODULE__{status: status_for(page), next_keyset: page.next_keyset}
  end

  def append(_state, page) do
    %__MODULE__{status: status_for(page), next_keyset: page.next_keyset}
  end

  def empty?(%__MODULE__{status: :empty}), do: true
  def empty?(%__MODULE__{}), do: false

  def can_load_more?(%__MODULE__{status: :ready, next_keyset: next_keyset}) do
    not is_nil(next_keyset)
  end

  def can_load_more?(%__MODULE__{}), do: false

  defp status_for(%{more?: true}), do: :ready
  defp status_for(%{more?: false}), do: :ended
end
