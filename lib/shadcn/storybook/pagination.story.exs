defmodule Shadcn.Storybook.Pagination do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Pagination

  def function, do: &Pagination.pagination/1

  def imports,
    do: [
      {Shadcn.Components.Pagination,
       [
         pagination_ellipsis: 1,
         pagination_link: 1,
         pagination_next: 1,
         pagination_previous: 1
       ]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          ~s|<.pagination_previous href="#" />|,
          ~s|<.pagination_link href="#">1</.pagination_link>|,
          ~s|<.pagination_link href="#" active>2</.pagination_link>|,
          ~s|<.pagination_link href="#">3</.pagination_link>|,
          ~s|<.pagination_ellipsis />|,
          ~s|<.pagination_link href="#">10</.pagination_link>|,
          ~s|<.pagination_next href="#" />|
        ]
      },
      %Variation{
        id: :short,
        description: "Short pagination",
        slots: [
          ~s|<.pagination_previous href="#" />|,
          ~s|<.pagination_link href="#" active>1</.pagination_link>|,
          ~s|<.pagination_link href="#">2</.pagination_link>|,
          ~s|<.pagination_link href="#">3</.pagination_link>|,
          ~s|<.pagination_next href="#" />|
        ]
      }
    ]
  end
end
