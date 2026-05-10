defmodule WatchClub.Contents.Calculations.GetContentImplementation do
  use Ash.Resource.Calculation

  @impl true
  def load(_, _, _) do
    [:book, :movie, :tv_show]
  end

  # This ensures that all attributes are selected by default
  # on the related loads we depend on.
  @impl true
  def strict_loads?, do: false
  @impl true
  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      cond do
        record.book ->
          %Ash.Union{type: :book, value: record.book}

        record.movie ->
          %Ash.Union{type: :movie, value: record.movie}

        record.tv_show ->
          %Ash.Union{type: :tv_show, value: record.tv_show}

        true ->
          nil
      end
    end)
  end
end
