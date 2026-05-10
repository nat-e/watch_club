defmodule WatchClub.Contents.SearchResult do
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        # book: [
        #   type: :struct,
        #   constraints: [instance_of: MovieSearchResult]
        # ],
        movie: [
          type: :struct,
          constraints: [instance_of: MovieSearchResult]
        ],
        tv_show: [
          type: :struct,
          constraints: [instance_of: TvSearchResult]
        ]
      ]
    ]
end

As
