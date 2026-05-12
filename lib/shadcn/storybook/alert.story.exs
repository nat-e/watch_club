defmodule Shadcn.Storybook.Alert do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Alert

  def function, do: &Alert.alert/1

  def imports,
    do: [
      {WatchClubWeb.UI.Button, [button: 1]},
      {Lucideicons, [circle_alert: 1, circle_check: 1, info: 1, triangle_alert: 1]}
    ]

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Basic — icon, title, description",
        attributes: %{class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.circle_check /></:icon>",
          "<:title>Account updated successfully</:title>",
          "Your profile information has been saved. Changes will be reflected immediately."
        ]
      },
      %Variation{
        id: :secondary,
        description: "Secondary variant",
        attributes: %{variant: "secondary", class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.info /></:icon>",
          "<:title>Heads up</:title>",
          "Two-factor authentication is now available in security settings."
        ]
      },
      %Variation{
        id: :destructive,
        description: "Destructive variant",
        attributes: %{variant: "destructive", class: "max-w-md"},
        slots: [
          "<:icon><Lucideicons.circle_alert /></:icon>",
          "<:title>Payment failed</:title>",
          "Your payment could not be processed. Please check your payment method and try again."
        ]
      },
      %Variation{
        id: :action,
        description: "With an action button in the top-right",
        attributes: %{class: "max-w-md"},
        slots: [
          "<:title>Dark mode is now available</:title>",
          "Enable it under your profile settings to get started.",
          ~s|<:action><.button size="xs">Enable</.button></:action>|
        ]
      },
      %Variation{
        id: :colors,
        description: "Custom colors via className",
        attributes: %{
          class:
            "max-w-md border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-50"
        },
        slots: [
          "<:icon><Lucideicons.triangle_alert /></:icon>",
          "<:title>Your subscription will expire in 3 days.</:title>",
          "Renew now to avoid service interruption or upgrade to a paid plan to continue using the service."
        ]
      }
    ]
  end
end
