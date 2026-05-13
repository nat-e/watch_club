defmodule Shadcn.Storybook.Empty do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Empty

  def function, do: &Empty.empty/1

  def imports,
    do: [
      {WatchClubWeb.UI.Avatar, [avatar: 1, avatar_group: 1]},
      {WatchClubWeb.UI.Button, [button: 1]},
      {Shadcn.Components.Kbd, [kbd: 1]},
      {Lucideicons,
       [
         arrow_up_right: 1,
         bell: 1,
         cloud: 1,
         folder_code: 1,
         plus: 1,
         refresh_ccw: 1,
         search: 1
       ]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          ~s|<:media variant="icon"><Lucideicons.folder_code /></:media>|,
          ~s|<:title>No Projects Yet</:title>|,
          ~s|<:description>You haven't created any projects yet. Get started by creating your first project.</:description>|,
          """
          <div class="flex flex-row gap-2 justify-center">
            <.button>Create Project</.button>
            <.button variant="outline">Import Project</.button>
          </div>
          <.button href="#" variant="link" size="sm" class="text-muted-foreground">
            Learn More
            <:icon position="end"><Lucideicons.arrow_up_right /></:icon>
          </.button>
          """
        ]
      },
      %Variation{
        id: :outline,
        description: "Dashed border container",
        attributes: %{class: "border border-dashed"},
        slots: [
          ~s|<:media variant="icon"><Lucideicons.cloud /></:media>|,
          ~s|<:title>Cloud Storage Empty</:title>|,
          ~s|<:description>Upload files to your cloud storage to access them anywhere.</:description>|,
          ~s|<.button variant="outline" size="sm">Upload Files</.button>|
        ]
      },
      %Variation{
        id: :background,
        description: "Muted background",
        attributes: %{class: "bg-muted/30"},
        slots: [
          ~s|<:media variant="icon"><Lucideicons.bell /></:media>|,
          ~s|<:title>No Notifications</:title>|,
          ~s|<:description class="max-w-xs text-pretty">You're all caught up. New notifications will appear here.</:description>|,
          """
          <.button variant="outline">
            <Lucideicons.refresh_ccw />
            Refresh
          </.button>
          """
        ]
      },
      %Variation{
        id: :avatar,
        description: "Avatar in media slot",
        slots: [
          """
          <:media variant="default">
            <.avatar id="user-lr" name="Lena Rivers" class="size-12 text-base" />
          </:media>
          """,
          ~s|<:title>User Offline</:title>|,
          ~s|<:description>This user is currently offline. You can leave a message to notify them or try again later.</:description>|,
          ~s|<.button size="sm">Leave Message</.button>|
        ]
      },
      %Variation{
        id: :avatar_group,
        description: "Multiple overlapping avatars",
        slots: [
          """
          <:media>
            <.avatar_group
              avatars={[
                %{id: "team-cn", name: "Casey Nguyen"},
                %{id: "team-lr", name: "Lena Rivers"},
                %{id: "team-er", name: "Eli Rowan"}
              ]}
              avatar_class="size-12 text-base"
            />
          </:media>
          """,
          ~s|<:title>No Team Members</:title>|,
          ~s|<:description>Invite your team to collaborate on this project.</:description>|,
          """
          <.button size="sm">
            <Lucideicons.plus />
            Invite Members
          </.button>
          """
        ]
      }
    ]
  end
end
