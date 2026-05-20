defmodule WatchClub.Media.Changes.NormalizePath do
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    attribute = Keyword.get(opts, :attribute, :path)

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
      nil ->
        changeset

      path when is_binary(path) ->
        Ash.Changeset.change_attribute(changeset, attribute, Path.expand(path))
    end
  end

  @impl true
  def atomic(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case Map.get(changeset.params, attribute) ||
           Map.get(changeset.params, Atom.to_string(attribute)) do
      nil ->
        :ok

      path when is_binary(path) ->
        atomics = %{attribute => Path.expand(path)}

        case changeset.action.type do
          :create -> {:atomic_set, atomics}
          :update -> {:atomic, atomics}
        end
    end
  end
end
