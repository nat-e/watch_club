defmodule WatchClub.Contents.Calculations.GetContentImplementation do
  use Ash.Resource.Calculation

  @impl true
  def load(_, _, _) do
    [:book, movie: [:best_localization], tv_show: [:best_localization]]
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
          record.book

        record.movie ->
          record.movie

        record.tv_show ->
          record.tv_show

        true ->
          raise "Unknown content type: #{inspect(record)}"
      end
    end)
  end
end
