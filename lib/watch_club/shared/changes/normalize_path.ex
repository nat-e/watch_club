defmodule WatchClub.Shared.Changes.NormalizePath do
  @moduledoc """
  Normalizes a filesystem path on a changeset by expanding it.

  Accepts either:
    * `attribute: :name` — normalize the attribute (default: `:path`).
    * `argument: :name` — normalize an action argument; the change rewrites
      the argument in place via `Ash.Changeset.set_argument/3` so that
      downstream changes (e.g. `manage_relationship` using
      `value_is_key:`) see the normalized value.
  """
  use Ash.Resource.Change

  alias WatchClub.Shared.Path, as: Paths

  @impl true
  def init(opts) do
    if Keyword.has_key?(opts, :argument) do
      validate_atom!(opts, :argument)
    else
      attribute = Keyword.get(opts, :attribute, :path)
      validate_atom!(Keyword.put(opts, :attribute, attribute), :attribute)
    end
  end

  defp validate_atom!(opts, key) do
    case Keyword.fetch!(opts, key) do
      name when is_atom(name) -> {:ok, opts}
      _ -> {:error, "#{inspect(key)} must be an atom"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    cond do
      argument = Keyword.get(opts, :argument) ->
        case Ash.Changeset.get_argument(changeset, argument) do
          nil ->
            changeset

          "" ->
            changeset

          path when is_binary(path) ->
            Ash.Changeset.set_argument(changeset, argument, Paths.normalize(path))
        end

      attribute = Keyword.get(opts, :attribute) ->
        case Ash.Changeset.get_attribute(changeset, attribute) do
          nil ->
            changeset

          path when is_binary(path) ->
            Ash.Changeset.change_attribute(changeset, attribute, Paths.normalize(path))
        end
    end
  end

  @impl true
  def atomic(changeset, opts, _context) do
    cond do
      Keyword.has_key?(opts, :argument) ->
        # The argument-rewrite branch can't be expressed as a single atomic
        # SQL update because downstream changes read the rewritten argument
        # from the changeset. Force the action out of atomic mode.
        {:not_atomic, "NormalizePath argument rewrite is not atomic"}

      attribute = Keyword.get(opts, :attribute) ->
        case Map.get(changeset.params, attribute) ||
               Map.get(changeset.params, Atom.to_string(attribute)) do
          nil ->
            :ok

          path when is_binary(path) ->
            atomics = %{attribute => Paths.normalize(path)}

            case changeset.action.type do
              :create -> {:atomic_set, atomics}
              :update -> {:atomic, atomics}
            end
        end
    end
  end
end
