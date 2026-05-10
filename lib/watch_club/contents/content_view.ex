defmodule WatchClub.Contents.ContentView do
  use Ash.TypedStruct

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents.{Content, ContentType, ExternalIdSource}
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse

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
          release_date: Date.t() | nil,
          details: MovieDetailsResponse | nil,
          in_libraries: [LibraryItem.t()]
        }

  def in_clubs(context, current_user) do
    memberships_by_club_id = Map.new(current_user.memberships, fn m -> {m.club_id, m} end)

    context.in_libraries
    |> Enum.map(fn item -> Map.fetch!(memberships_by_club_id, item.club_id).club end)
  end
end
