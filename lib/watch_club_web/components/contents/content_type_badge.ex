defmodule WatchClubWeb.Components.Contents.ContentTypeBadge do
  @moduledoc """
  Badge for a WatchClub content type.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon

  alias WatchClub.Contents.ContentType

  attr :class, :any, default: nil
  attr :type, :atom, required: true

  def content_type_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class={["whitespace-nowrap", @class]}>
      <:icon><.content_type_icon type={@type} /></:icon>
      {ContentType.translated_label(@type)}
    </.badge>
    """
  end
end
