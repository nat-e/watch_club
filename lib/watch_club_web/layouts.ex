defmodule WatchClubWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WatchClubWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  The main app layout, used on most screens.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true
  def app(assigns)

  @doc """
  A layout displaying content in a centered card with a movie poster image fader background.
  Mainly used for authentication screens.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :class, :list, default: nil
  slot :inner_block, required: true
  def centered_card(assigns)
end
