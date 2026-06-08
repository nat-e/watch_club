defmodule WatchClub.Contents.ContentIdentity do
  @moduledoc """
  Addresses a Content by its external identity from the main Metadata Provider
  `(type, external_id_source, external_id)`.
  """
  use Ash.TypedStruct

  alias WatchClub.Contents.{ContentType, ExternalIdSource}

  typed_struct do
    field :type, ContentType,
      allow_nil?: false,
      description: "The content type (movie, tv_show, book)"

    field :external_id_source, ExternalIdSource,
      allow_nil?: false,
      description: "The source of the external ID (TMDB, Hardcover, ...)"

    field :external_id, :string,
      allow_nil?: false,
      description: "The ID of the content on the external source"
  end

  @type t :: %__MODULE__{
          type: ContentType.t(),
          external_id_source: ExternalIdSource.t(),
          external_id: String.t()
        }

  @spec for_movie(integer() | binary()) :: t()
  def for_movie(tmdb_id) do
    %__MODULE__{type: :movie, external_id_source: :tmdb, external_id: to_string(tmdb_id)}
  end

  @spec for_tv_show(integer() | binary()) :: t()
  def for_tv_show(tmdb_id) do
    %__MODULE__{type: :tv_show, external_id_source: :tmdb, external_id: to_string(tmdb_id)}
  end

  @spec for_book(integer() | binary()) :: t()
  def for_book(hardcover_id) do
    %__MODULE__{type: :book, external_id_source: :hardcover, external_id: to_string(hardcover_id)}
  end
end
