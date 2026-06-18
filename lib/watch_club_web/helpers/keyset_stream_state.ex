defmodule WatchClubWeb.Helpers.KeysetStreamState do
  @moduledoc """
  State for a synchronous infinite scroll list backed by Ash keyset pagination
  """

  require Logger

  @type status :: :init | :ready | :error
  @type t :: %__MODULE__{page_size: integer(), status: status(), after_keyset: term() | nil}

  defstruct [:page_size, status: :init, after_keyset: nil]

  def init(page_size) when is_integer(page_size), do: %__MODULE__{page_size: page_size}

  def load_page(%__MODULE__{} = state, load_fn) do
    case load_fn.(page_options(state)) do
      {:ok, %{results: results, more?: true}} ->
        after_keyset = List.last(results).__metadata__.keyset

        {:ok, %__MODULE__{state | status: :ready, after_keyset: after_keyset}, results}

      {:ok, %{results: results}} ->
        {:ok, %__MODULE__{state | status: :ready, after_keyset: nil}, results}

      {:error, error} ->
        Logger.error("Error loading keyset page: #{inspect(error)}")
        {:error, %__MODULE__{state | status: :error}, nil}
    end
  end

  def error?(%__MODULE__{status: status}), do: status == :error

  def can_load_more?(%__MODULE__{after_keyset: after_keyset}) do
    not is_nil(after_keyset)
  end

  defp page_options(%__MODULE__{page_size: page_size, after_keyset: nil}),
    do: [limit: page_size]

  defp page_options(%__MODULE__{page_size: page_size, after_keyset: after_keyset}),
    do: [limit: page_size, after: after_keyset]
end
