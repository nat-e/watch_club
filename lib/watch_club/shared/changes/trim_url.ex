defmodule WatchClub.Shared.Changes.TrimUrl do
  @moduledoc """
  Normalizes a URL attribute on a changeset by trimming surrounding
  whitespace and stripping a single trailing slash.

  Pairs with `NormalizePath` for filesystem paths; the two are deliberately
  separate because URL semantics (trailing slash optional, scheme
  preserved) differ from path normalization.
  """
  use Ash.Resource.Change

  alias WatchClub.Shared.Path

  @impl true
  def init(opts) do
    attribute = Keyword.get(opts, :attribute, :url)

    if is_atom(attribute) do
      {:ok, Keyword.put(opts, :attribute, attribute)}
    else
      {:error, "attribute must be an atom"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case Ash.Changeset.get_attribute(changeset, attribute) do
      url when is_binary(url) ->
        Ash.Changeset.change_attribute(changeset, attribute, Path.normalize_base_url(url))

      _ ->
        changeset
    end
  end

  @impl true
  def atomic(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case Map.get(changeset.params, attribute) ||
           Map.get(changeset.params, Atom.to_string(attribute)) do
      url when is_binary(url) ->
        atomics = %{attribute => Path.normalize_base_url(url)}

        case changeset.action.type do
          :create -> {:atomic_set, atomics}
          :update -> {:atomic, atomics}
        end

      _ ->
        :ok
    end
  end
end
