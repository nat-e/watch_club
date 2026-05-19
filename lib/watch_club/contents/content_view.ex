defmodule WatchClub.Contents.ContentView do
  use Ash.TypedStruct

  alias WatchClub.Clubs.LibraryItem

  alias WatchClub.Contents.{
    Content,
    ContentType,
    ContentView,
    ExternalIdSource,
    Movie,
    TvShow
  }

  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}

  typed_struct do
    field :external_id_source, ExternalIdSource,
      allow_nil?: false,
      description: "The source of the external ID (TMDB, Hardcover, ...)"

    field :external_id, :string,
      allow_nil?: false,
      description: "The ID of the content on the external source"

    field :type, ContentType,
      allow_nil?: false,
      description: "The content type"

    field :content, :struct,
      constraints: [instance_of: Content],
      allow_nil?: true,
      description: "The Content object, if it exists in the database"

    field :title, :string,
      allow_nil?: false,
      description: "The localized title of the content for the current user"

    field :description, :string,
      allow_nil?: true,
      description: "The localized description of the content for the current user"

    field :image_path, :string,
      allow_nil?: true,
      description: "A path to the localized image of the content for the current user"

    field :origin_country, :string,
      allow_nil?: true,
      description: "The ISO 3166_1 code of the main production country of the content"

    field :release_date, :struct,
      constraints: [instance_of: Date],
      allow_nil?: true,
      description: "The date at which the content was released"

    field :details, :struct,
      allow_nil?: true,
      description: "A struct containing the details response of the content if provided"

    field :in_libraries, {:array, :struct} do
      constraints items: [instance_of: LibraryItem]
      allow_nil? false
    end
  end

  @type t :: %__MODULE__{
          external_id_source: ExternalIdSource.t(),
          external_id: String.t(),
          type: ContentType.t(),
          content: Content.t() | nil,
          title: String.t(),
          description: String.t(),
          image_path: String.t() | nil,
          origin_country: String.t() | nil,
          release_date: Date.t() | nil,
          details: MovieDetailsResponse.t() | TvDetailsResponse.t() | nil,
          in_libraries: [LibraryItem.t()]
        }

  def unique_id(content), do: "#{content.external_id_source}-#{content.external_id}"

  def details_url(%ContentView{type: :book} = content), do: "/books/#{content.external_id}"
  def details_url(%ContentView{type: :movie} = content), do: "/movies/#{content.external_id}"
  def details_url(%ContentView{type: :tv_show} = content), do: "/shows/#{content.external_id}"

  def country_flag(%ContentView{origin_country: country}) do
    country
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end

  def in_clubs(content, current_user) do
    memberships_by_club_id = Map.new(current_user.memberships, fn m -> {m.club_id, m} end)

    content.in_libraries
    |> Enum.map(fn item -> Map.fetch!(memberships_by_club_id, item.library.club_id).club end)
    |> Enum.uniq_by(& &1.id)
  end

  def from_content(%Content{implementation: %Movie{} = movie} = content, _locale) do
    ContentView.new!(%{
      external_id_source: content.external_id_source,
      external_id: content.external_id,
      type: content.type,
      content: content,
      title: movie.best_localization.title,
      description: movie.best_localization.overview,
      image_path: movie.best_localization.poster_path,
      origin_country: content.origin_country,
      release_date: content.release_date,
      details: nil,
      in_libraries: content.library_items
    })
  end

  def from_content(%Content{implementation: %TvShow{} = tv_show} = content, _locale) do
    ContentView.new!(%{
      external_id_source: content.external_id_source,
      external_id: content.external_id,
      type: content.type,
      content: content,
      title: tv_show.best_localization.title,
      description: tv_show.best_localization.overview,
      image_path: tv_show.best_localization.poster_path,
      origin_country: content.origin_country,
      release_date: content.release_date,
      details: nil,
      in_libraries: content.library_items
    })
  end
end
