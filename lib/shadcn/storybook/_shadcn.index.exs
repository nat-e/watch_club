# Font Awesome icons for storybook entries.
#
# `phoenix_storybook` ships a curated SUBSET of FontAwesome — about 50
# icons, not the entire free set. Names like `user`, `keyboard`, `ghost`,
# `grip-lines`, or `display` (valid in vanilla FA Free) silently fail to
# render here. The full bundled list, extracted from
# `deps/phoenix_storybook/priv/static/css/phoenix_storybook_fonts.css`:
#
#   ad, adjust, angle-right, arrow-alt-circle-left, arrow-right, bars,
#   bolt, bomb, book, book-open, box-check, brightness, caret-down,
#   caret-right, chain, check, circle-dot, circle-exclamation,
#   circle-half-stroke, circle-left, circle-question, close, code, copy,
#   dice, dot-circle, exclamation-circle, eye, file-code, github,
#   hand-wave, header, heading, heart-music-camera-bolt, icons,
#   input-text, link, list, list-squares, list-timeline, magnifying-glass,
#   moon, multiply, navicon, palette, question-circle, rectangle-ad,
#   remove, search, table, times, toolbox, xmark, zap
#
# To extend: regenerate the kit at https://fontawesome.com/kits, or wire
# in a separate FA bundle through the assets pipeline.
defmodule Shadcn.Storybook do
  use PhoenixStorybook.Index

  def folder_open?, do: true
  def folder_name, do: "Shadcn"
  def folder_icon, do: {:fa, "palette"}

  def entry("accordion"), do: [icon: {:fa, "list"}]
  def entry("alert"), do: [icon: {:fa, "circle-exclamation"}]
  def entry("alert_dialog"), do: [icon: {:fa, "circle-exclamation"}]
  def entry("aspect_ratio"), do: [icon: {:fa, "table"}]
  def entry("avatar"), do: [icon: {:fa, "circle-dot"}]
  def entry("badge"), do: [icon: {:fa, "circle-half-stroke"}]
  def entry("breadcrumb"), do: [icon: {:fa, "angle-right"}]
  def entry("button_group"), do: [icon: {:fa, "icons"}]
  def entry("calendar"), do: [icon: {:fa, "table"}]
  def entry("card"), do: [icon: {:fa, "copy"}]
  def entry("carousel"), do: [icon: {:fa, "icons"}]
  def entry("chart"), do: [icon: {:fa, "list-timeline"}]
  def entry("checkbox"), do: [icon: {:fa, "box-check"}]
  def entry("collapsible"), do: [icon: {:fa, "caret-down"}]
  def entry("combobox"), do: [icon: {:fa, "magnifying-glass"}]
  def entry("command"), do: [icon: {:fa, "magnifying-glass"}]
  def entry("context_menu"), do: [icon: {:fa, "list"}]
  def entry("dialog"), do: [icon: {:fa, "rectangle-ad"}]
  def entry("drawer"), do: [icon: {:fa, "rectangle-ad"}]
  def entry("dropdown_menu"), do: [icon: {:fa, "list"}]
  def entry("empty"), do: [icon: {:fa, "ghost"}]
  def entry("field"), do: [icon: {:fa, "input-text"}]
  def entry("flash"), do: [icon: {:fa, "bell"}]
  def entry("hover_card"), do: [icon: {:fa, "rectangle-ad"}]
  def entry("input"), do: [icon: {:fa, "input-text"}]
  def entry("input_group"), do: [icon: {:fa, "input-text"}]
  def entry("input_otp"), do: [icon: {:fa, "input-text"}]
  def entry("item"), do: [icon: {:fa, "list"}]
  def entry("kbd"), do: [icon: {:fa, "code"}]
  def entry("label"), do: [icon: {:fa, "heading"}]
  def entry("menubar"), do: [icon: {:fa, "list"}]
  def entry("native_select"), do: [icon: {:fa, "caret-down"}]
  def entry("navigation_menu"), do: [icon: {:fa, "navicon"}]
  def entry("pagination"), do: [icon: {:fa, "list-squares"}]
  def entry("popover"), do: [icon: {:fa, "rectangle-ad"}]
  def entry("progress"), do: [icon: {:fa, "list-timeline"}]
  def entry("radio_group"), do: [icon: {:fa, "circle-dot"}]
  def entry("resizable"), do: [icon: {:fa, "icons"}]
  def entry("scroll_area"), do: [icon: {:fa, "list"}]
  def entry("select"), do: [icon: {:fa, "caret-down"}]
  def entry("separator"), do: [icon: {:fa, "chain"}]
  def entry("sheet"), do: [icon: {:fa, "rectangle-ad"}]
  def entry("sidebar"), do: [icon: {:fa, "navicon"}]
  def entry("skeleton"), do: [icon: {:fa, "bars"}]
  def entry("slider"), do: [icon: {:fa, "list-timeline"}]
  def entry("spinner"), do: [icon: {:fa, "bars"}]
  def entry("switch"), do: [icon: {:fa, "toolbox"}]
  def entry("table"), do: [icon: {:fa, "table"}]
  def entry("tabs"), do: [icon: {:fa, "list-squares"}]
  def entry("textarea"), do: [icon: {:fa, "input-text"}]
  def entry("toggle"), do: [icon: {:fa, "toolbox"}]
  def entry("toggle_group"), do: [icon: {:fa, "icons"}]
  def entry("tooltip"), do: [icon: {:fa, "circle-question"}]
end
