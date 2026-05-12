defmodule Shadcn.Storybook.DesignSystem do
  use PhoenixStorybook.Index

  def folder_open?, do: true
  def folder_name, do: "Watch Club Design"
  def folder_icon, do: {:fa, "palette"}
  def folder_index, do: 0

  def entry("design_tokens"), do: [name: "Foundation", icon: {:fa, "palette"}, index: 0]
end
