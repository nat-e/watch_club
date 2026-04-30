defmodule Shadcn.Storybook.Tabs do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Tabs

  def function, do: &Tabs.tabs/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "tabs-default", value: "account"},
        slots: [
          ~s|<:tab id="account" label="Account">Account info goes here.</:tab>|,
          ~s|<:tab id="password" label="Password">Password change form.</:tab>|,
          ~s|<:tab id="settings" label="Settings">Other settings.</:tab>|
        ]
      },
      %Variation{
        id: :line_variant,
        description: "Line variant",
        attributes: %{id: "tabs-line", value: "overview", variant: "line"},
        slots: [
          ~s|<:tab id="overview" label="Overview">Overview content.</:tab>|,
          ~s|<:tab id="analytics" label="Analytics">Analytics content.</:tab>|,
          ~s|<:tab id="reports" label="Reports">Reports content.</:tab>|
        ]
      },
      %Variation{
        id: :vertical,
        description: "Vertical orientation",
        attributes: %{id: "tabs-vertical", value: "general", orientation: "vertical"},
        slots: [
          ~s|<:tab id="general" label="General">General settings.</:tab>|,
          ~s|<:tab id="security" label="Security">Security settings.</:tab>|,
          ~s|<:tab id="advanced" label="Advanced">Advanced settings.</:tab>|
        ]
      },
      %Variation{
        id: :with_disabled,
        description: "With a disabled tab",
        attributes: %{id: "tabs-disabled", value: "active"},
        slots: [
          ~s|<:tab id="active" label="Active">Active tab.</:tab>|,
          ~s|<:tab id="locked" label="Locked" disabled>Locked content.</:tab>|,
          ~s|<:tab id="other" label="Other">Other content.</:tab>|
        ]
      }
    ]
  end
end
