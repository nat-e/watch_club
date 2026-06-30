defmodule WatchClub.Contents.Calculations.GetContentImplementation do
  @moduledoc """
  Resolves a Content's polymorphic implementation (its Book, Movie or TvShow payload).

  By default this calculation loads the implementation record and its best localization.
  It is possible to add extra loading relations or calculations by passing a `load` argument
  (an atom or a list per content type), which will be merged with the defaults, e.g.
  `implementation: %{load: [tv_show: [:episodes]]}`.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, context) do
    [
      book: merge_load(context, :book),
      movie: merge_load(context, :movie, [:best_localization]),
      tv_show: merge_load(context, :tv_show, [:best_localization])
    ]
  end

  defp merge_load(context, name, default \\ []) do
    custom_load = context.arguments[:load] || []
    # List.wrap so a single load term (`tv_show: :episodes`) works like a list.
    default ++ List.wrap(Keyword.get(custom_load, name, []))
  end

  # This ensures that all attributes are selected by default
  # on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _, _) do
    Enum.map(records, &(&1.book || &1.movie || &1.tv_show))
  end
end
