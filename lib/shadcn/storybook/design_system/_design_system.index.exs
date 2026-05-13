defmodule Shadcn.Storybook.DesignSystem do
  use PhoenixStorybook.Index

  def folder_open?, do: true
  def folder_name, do: "Watch Club Design"
  def folder_icon, do: {:fa, "palette"}
  def folder_index, do: 0

  def entry("design_tokens"), do: [name: "Foundation", icon: {:fa, "palette"}, index: 0]
  def entry("button"), do: [name: "Button", icon: {:fa, "square"}, index: 1]
  def entry("input"), do: [name: "Input", icon: {:fa, "input-text"}, index: 2]
  def entry("checkbox"), do: [name: "Checkbox", icon: {:fa, "box-check"}, index: 3]
  def entry("alert"), do: [name: "Alert", icon: {:fa, "circle-exclamation"}, index: 4]
  def entry("avatar"), do: [name: "Avatar", icon: {:fa, "circle-dot"}, index: 5]
  def entry("badge"), do: [name: "Badge", icon: {:fa, "circle-half-stroke"}, index: 6]
  def entry("modal"), do: [name: "Modal", icon: {:fa, "rectangle-ad"}, index: 7]
end
