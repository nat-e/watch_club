defmodule WatchClub.Contents.Preparations.FilterByContentIdentities do
  @moduledoc """
  An Ash Preparation that filters a Query where Contents are part of a provided
  list of ContentIdentity.
  The query must declare a `content_identities` argument that accepts a list of Content Identity, or a single `content_identity`.
  This will compile to a giant SQL OR statement like this:
    WHERE (external_id_source = 'tmdb' AND external_id = 1)
      OR (external_id_source = 'tmdb' AND external_id = 2)...

  Options:
  - content_path: A relationship path to the Content resource, defaults to [] (meaning, on the Content resource)
  """
  use Ash.Resource.Preparation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def prepare(query, opts, _context) do
    identities =
      Ash.Query.get_argument(query, :content_identities) ||
        Ash.Query.get_argument(query, :content_identity) |> List.wrap()

    content_path = Keyword.get(opts, :content_path, []) |> List.wrap()
    external_source_ref = ref(content_path, :external_id_source)
    external_id_ref = ref(content_path, :external_id)

    combined =
      Enum.reduce(identities, nil, fn id, acc ->
        clause =
          expr(
            ^external_source_ref == ^id.external_id_source and
              ^external_id_ref == ^id.external_id
          )

        if acc, do: expr(^acc or ^clause), else: clause
      end)

    # empty list → match nothing (same semantics as `in []`), not everything
    Ash.Query.filter(query, ^(combined || expr(false)))
  end
end
