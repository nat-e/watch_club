defmodule WatchClub.Shared.Changes.NormalizeUrl do
  @moduledoc """
  Normalizes a base URL attribute on a changeset: trims it, adds `http://`
  when it has no scheme (`localhost:8989`) and strips trailing slashes.

  Run it in every action that accepts a typed URL (the Servarr wizard steps
  and `Servarr` create and update), so code that reads the URL can use it
  as it is.

  Pairs with `NormalizePath` for filesystem paths; the two stay separate
  because `Path.expand/1` would turn the `//` of `http://` into `/`.
  """
  use Ash.Resource.Change

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
        Ash.Changeset.change_attribute(changeset, attribute, normalize(url))

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
        atomics = %{attribute => normalize(url)}

        case changeset.action.type do
          :create -> {:atomic_set, atomics}
          :update -> {:atomic, atomics}
        end

      _ ->
        :ok
    end
  end

  defp normalize(url) do
    url = String.trim(url)
    url = if String.contains?(url, "://"), do: url, else: "http://#{url}"
    String.replace_trailing(url, "/", "")
  end
end
