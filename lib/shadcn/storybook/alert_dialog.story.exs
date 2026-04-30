defmodule Shadcn.Storybook.AlertDialog do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.AlertDialog

  def function, do: &AlertDialog.alert_dialog/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Lucideicons, [circle_fading_plus: 1, bluetooth: 1, trash_2: 1]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        description: "Basic — title, description, cancel/continue",
        attributes: %{id: "alert-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Show Dialog</.button></:trigger>|,
          ~s|<:title>Are you absolutely sure?</:title>|,
          ~s|<:description>This action cannot be undone. This will permanently delete your account and remove your data from our servers.</:description>|,
          ~s|<:cancel>Cancel</:cancel>|,
          ~s|<:action>Continue</:action>|
        ]
      },
      %Variation{
        id: :small,
        description: ~s|Compact layout via size="sm" — footer becomes 2-col grid|,
        attributes: %{id: "alert-small", size: "sm"},
        slots: [
          ~s|<:trigger><.button variant="outline">Show Dialog</.button></:trigger>|,
          ~s|<:title>Allow accessory to connect?</:title>|,
          ~s|<:description>Do you want to allow the USB accessory to connect to this device?</:description>|,
          ~s|<:cancel>Don't allow</:cancel>|,
          ~s|<:action>Allow</:action>|
        ]
      },
      %Variation{
        id: :media,
        description: "With media — icon block above the title (left of title on sm+)",
        attributes: %{id: "alert-media"},
        slots: [
          ~s|<:trigger><.button variant="outline">Share Project</.button></:trigger>|,
          ~s|<:media><Lucideicons.circle_fading_plus /></:media>|,
          ~s|<:title>Share this project?</:title>|,
          ~s|<:description>Anyone with the link will be able to view and edit this project.</:description>|,
          ~s|<:cancel>Cancel</:cancel>|,
          ~s|<:action>Share</:action>|
        ]
      },
      %Variation{
        id: :small_with_media,
        description: ~s|Compact layout with media icon|,
        attributes: %{id: "alert-small-media", size: "sm"},
        slots: [
          ~s|<:trigger><.button variant="outline">Show Dialog</.button></:trigger>|,
          ~s|<:media><Lucideicons.bluetooth /></:media>|,
          ~s|<:title>Allow accessory to connect?</:title>|,
          ~s|<:description>Do you want to allow the USB accessory to connect to this device?</:description>|,
          ~s|<:cancel>Don't allow</:cancel>|,
          ~s|<:action>Allow</:action>|
        ]
      },
      %Variation{
        id: :destructive,
        description: "Destructive — tinted media, destructive action, link in description",
        attributes: %{id: "alert-destructive", size: "sm"},
        slots: [
          ~s|<:trigger><.button variant="destructive">Delete Chat</.button></:trigger>|,
          ~s|<:media class="bg-destructive/10 text-destructive dark:bg-destructive/20 dark:text-destructive"><Lucideicons.trash_2 /></:media>|,
          ~s|<:title>Delete chat?</:title>|,
          ~s|<:description>This will permanently delete this chat conversation. View <a href="#">Settings</a> to delete any memories saved during this chat.</:description>|,
          ~s|<:cancel variant="outline">Cancel</:cancel>|,
          ~s|<:action variant="destructive">Delete</:action>|
        ]
      }
    ]
  end
end
