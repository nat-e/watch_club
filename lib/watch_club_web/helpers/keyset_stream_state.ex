defmodule WatchClubWeb.Helpers.KeysetStreamState do
  @moduledoc """
  State for a synchronous infinite scroll list backed by Ash keyset pagination
  """

  require Logger

  @type status :: :init | :ready | :error
  @type t :: %__MODULE__{
          page_size: integer(),
          status: status(),
          after_keyset: term() | nil,
          pages: non_neg_integer()
        }

  # `pages` counts the pages requested so far, including any past the last one
  defstruct [:page_size, status: :init, after_keyset: nil, pages: 0]

  def init(page_size) when is_integer(page_size), do: %__MODULE__{page_size: page_size}

  def load_page(%__MODULE__{} = state, load_fn), do: load_pages(state, 1, load_fn)

  @doc """
  Loads the next `count` pages at once. Past the last page, it loads nothing.
  """
  def load_pages(%__MODULE__{status: :ready, after_keyset: nil} = state, _count, _load_fn),
    do: {:ok, state, []}

  def load_pages(%__MODULE__{} = state, count, load_fn) when is_integer(count) and count > 0 do
    case load_records(state, state.page_size * count, load_fn, []) do
      {:ok, %__MODULE__{} = new_state, results} ->
        {:ok, %__MODULE__{new_state | pages: state.pages + count}, results}

      error ->
        error
    end
  end

  # Ash caps the records a query returns, at 250 by default, so a large load may take more queries
  defp load_records(state, limit, load_fn, loaded) do
    case load_fn.(page_options(state, limit)) do
      {:ok, %{results: results, more?: true}} ->
        state = %__MODULE__{
          state
          | status: :ready,
            after_keyset: List.last(results).__metadata__.keyset
        }

        missing = limit - length(results)

        if missing > 0,
          do: load_records(state, missing, load_fn, loaded ++ results),
          else: {:ok, state, loaded ++ results}

      {:ok, %{results: results}} ->
        {:ok, %__MODULE__{state | status: :ready, after_keyset: nil}, loaded ++ results}

      {:error, error} ->
        Logger.error("Error loading keyset page: #{inspect(error)}")
        {:error, %__MODULE__{state | status: :error}, nil}
    end
  end

  def error?(%__MODULE__{status: status}), do: status == :error

  def can_load_more?(%__MODULE__{after_keyset: after_keyset}) do
    not is_nil(after_keyset)
  end

  defp page_options(%__MODULE__{after_keyset: nil}, limit), do: [limit: limit]

  defp page_options(%__MODULE__{after_keyset: after_keyset}, limit),
    do: [limit: limit, after: after_keyset]
end
