defmodule WatchClub.Contents.ContentImplementation do
  alias WatchClub.Contents.{Book, Movie, TvShow}

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        book: [
          type: :struct,
          constraints: [instance_of: Book]
        ],
        movie: [
          type: :struct,
          constraints: [instance_of: Movie]
        ],
        tv_show: [
          type: :struct,
          constraints: [instance_of: TvShow]
        ]
      ]
    ]
end
