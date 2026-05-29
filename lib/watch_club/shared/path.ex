defmodule WatchClub.Shared.Path do
  @moduledoc """
  The shared normalization for `Media` paths, which are stored normalized
  and globally unique. Used by every producer of a `Media` path.

  Aliasing this module shadows stdlib `Path`; callers that also need the
  stdlib should `alias WatchClub.Shared.Path, as: Paths`.
  """

  @doc """
  Normalizes a path by expanding it (resolves `.`/`..`, strips trailing
  slashes). `nil` passes through. An empty string expands to the cwd —
  guard it.
  """
  @spec normalize(nil) :: nil
  @spec normalize(String.t()) :: String.t()
  def normalize(nil), do: nil
  def normalize(path) when is_binary(path), do: Elixir.Path.expand(path)

  @doc """
  Rewrites `path` from under `from_root` to under `to_root` and normalizes.
  A `nil` `to_root` (same mount) only normalizes. Used to map an external
  system's file path onto WatchClub's disk.
  """
  @spec remap_prefix(String.t(), String.t(), String.t() | nil) :: String.t()
  def remap_prefix(path, _from_root, nil) when is_binary(path), do: normalize(path)

  def remap_prefix(path, from_root, to_root)
      when is_binary(path) and is_binary(from_root) and is_binary(to_root) do
    path
    |> normalize()
    |> String.replace_prefix(normalize(from_root), normalize(to_root))
  end
end
