defmodule WatchClubWeb.Storybook.Alert do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Alert

  def function, do: &Alert.alert/1

  def imports,
    do: [
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {Lucideicons, [circle_alert: 1, circle_check: 1, info: 1, triangle_alert: 1]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default callout",
        attributes: %{class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.circle_check /></:icon>",
          "<:title>Account updated</:title>",
          "Your profile information has been saved."
        ]
      },
      %Variation{
        id: :info,
        description: "Informational callout",
        attributes: %{variant: "info", class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.info /></:icon>",
          "<:title>Heads up</:title>",
          "Two-factor authentication is available in security settings."
        ]
      },
      %Variation{
        id: :warning,
        description: "Warning callout",
        attributes: %{variant: "warning", class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.triangle_alert /></:icon>",
          "<:title>Your subscription expires soon.</:title>",
          "Renew now to avoid service interruption."
        ]
      },
      %Variation{
        id: :danger,
        description: "Danger callout",
        attributes: %{variant: "danger", class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.circle_alert /></:icon>",
          "<:title>Payment failed</:title>",
          "Check your payment method and try again."
        ]
      },
      %Variation{
        id: :action,
        description: "With an action button",
        attributes: %{class: "max-w-md"},
        slots: [
          "<:title>Dark mode is available</:title>",
          "Enable it under your profile settings.",
          ~s|<:action><.button size="sm">Enable</.button></:action>|
        ]
      }
    ]
  end
end
