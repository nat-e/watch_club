defmodule Shadcn.Storybook.Card do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Card

  def function, do: &Card.card/1

  def imports, do: [{WatchClubWeb.UI.Button, [button: 1]}]

  @meta Card.__components__().card
  @sizes Enum.find(@meta.attrs, &(&1.name == :size)).opts[:values]

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          "<:title>Account</:title>",
          "<:description>Manage your account settings.</:description>",
          "<p>Update your profile, password, and preferences here.</p>"
        ]
      },
      %Variation{
        id: :with_footer,
        description: "With footer",
        slots: [
          "<:title>Notifications</:title>",
          "<:description>You have 3 unread messages.</:description>",
          "<p>Mark them all as read or open your inbox to review.</p>",
          "<:footer><.button>Mark all as read</.button></:footer>"
        ]
      },
      %Variation{
        id: :with_action,
        description: "With header action",
        slots: [
          "<:title>Project</:title>",
          "<:description>Recently modified.</:description>",
          ~s(<:action><.button variant="ghost" size="sm">Edit</.button></:action>),
          "<p>Last edited 2 hours ago.</p>"
        ]
      },
      %Variation{
        id: :with_image,
        description: "With image",
        slots: [
          ~s(<:image><img src="https://picsum.photos/seed/watch/600/300" alt="" /></:image>),
          "<:title>Hands-on review</:title>",
          "<:description>A closer look at this season's release.</:description>",
          "<p>Read the full review for our verdict.</p>"
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        variations:
          for s <- @sizes do
            %Variation{
              id: String.to_atom(s),
              attributes: %{size: s},
              slots: [
                "<:title>#{String.capitalize(s)}</:title>",
                "<:description>Card at #{s} size.</:description>",
                "<p>Body content adjusts spacing per size.</p>"
              ]
            }
          end
      },
      %Variation{
        id: :body_only,
        description: "Body only (no header/footer)",
        slots: ["<p>Just a wrapper around some content.</p>"]
      }
    ]
  end
end
