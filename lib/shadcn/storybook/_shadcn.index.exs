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

  def entry("flash"), do: [icon: {:fa, "bell"}]
  def entry("kbd"), do: [icon: {:fa, "code"}]
  def entry("label"), do: [icon: {:fa, "heading"}]
  def entry("radio_group"), do: [icon: {:fa, "circle-dot"}]
  def entry("select"), do: [icon: {:fa, "caret-down"}]
  def entry("sidebar"), do: [icon: {:fa, "navicon"}]
  def entry("skeleton"), do: [icon: {:fa, "bars"}]
  def entry("table"), do: [icon: {:fa, "table"}]
end
