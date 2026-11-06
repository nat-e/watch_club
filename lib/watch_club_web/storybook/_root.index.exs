defmodule WatchClubWeb.Storybook.Root do
  use PhoenixStorybook.Index

  def folder_open?, do: true
  def folder_name, do: "Watch Club"
  def folder_icon, do: {:fa, "palette"}
  def folder_index, do: 0

  def entry("design_tokens"), do: [name: "Foundation", icon: {:fa, "palette"}, index: 0]

  def entry("spacing_layout"),
    do: [name: "Spacing & layout", icon: {:fa, "ruler-combined"}, index: 1]

  def entry("button"), do: [name: "Button", icon: {:fa, "square"}, index: 2]
  def entry("input"), do: [name: "Input", icon: {:fa, "input-text"}, index: 3]
  def entry("select"), do: [name: "Select", icon: {:fa, "caret-down"}, index: 4]
  def entry("label"), do: [name: "Label", icon: {:fa, "heading"}, index: 5]
  def entry("checkbox"), do: [name: "Checkbox", icon: {:fa, "box-check"}, index: 6]
  def entry("radio_group"), do: [name: "Radio group", icon: {:fa, "circle-dot"}, index: 7]
  def entry("kbd"), do: [name: "Kbd", icon: {:fa, "code"}, index: 8]
  def entry("alert"), do: [name: "Alert", icon: {:fa, "circle-exclamation"}, index: 9]
  def entry("dropdown_menu"), do: [name: "Dropdown menu", icon: {:fa, "list"}, index: 10]
  def entry("table"), do: [name: "Table", icon: {:fa, "table"}, index: 11]
  def entry("empty"), do: [name: "Empty", icon: {:fa, "circle-question"}, index: 12]
  def entry("avatar"), do: [name: "Avatar", icon: {:fa, "circle-dot"}, index: 13]
  def entry("badge"), do: [name: "Badge", icon: {:fa, "circle-half-stroke"}, index: 14]
  def entry("flash"), do: [name: "Flash", icon: {:fa, "circle-exclamation"}, index: 15]
  def entry("modal"), do: [name: "Modal", icon: {:fa, "rectangle-ad"}, index: 16]

  def entry("segmented_control"),
    do: [name: "Segmented control", icon: {:fa, "grip-lines"}, index: 17]

  def entry("filter_chip"), do: [name: "Filter chip", icon: {:fa, "filter"}, index: 18]
  def entry("progress_bar"), do: [name: "Progress bar", icon: {:fa, "bars-progress"}, index: 19]

  def entry("play_or_request_button"),
    do: [name: "Play or request button", icon: {:fa, "play"}, index: 20]

  def entry("star_rating"), do: [name: "Star rating", icon: {:fa, "star"}, index: 21]
  def entry("unread_badge"), do: [name: "Unread badge", icon: {:fa, "bell"}, index: 22]
  def entry("user_avatar"), do: [name: "User avatar", icon: {:fa, "user"}, index: 23]
  def entry("recipients"), do: [name: "Recipients", icon: {:fa, "users"}, index: 24]

  def entry("recommendation_text"),
    do: [name: "Recommendation text", icon: {:fa, "quote-left"}, index: 25]
end
