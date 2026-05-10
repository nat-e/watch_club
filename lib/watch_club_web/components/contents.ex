defmodule WatchClubWeb.Components.Contents do
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :type, :atom, required: true

  def content_type_icon(%{type: :movie} = assigns) do
    ~H"""
    <Lucideicons.film class={@class} />
    """
  end

  def content_type_icon(%{type: :tv_show} = assigns) do
    ~H"""
    <Lucideicons.tv class={@class} />
    """
  end

  def content_type_icon(%{type: :book} = assigns) do
    ~H"""
    <Lucideicons.book_open class={@class} />
    """
  end

  def content_type_icon(%{type: :movies_and_shows} = assigns) do
    ~H"""
    <Lucideicons.film class={@class} />
    """
  end

  def content_type_icon(%{type: :books} = assigns) do
    ~H"""
    <Lucideicons.book_open class={@class} />
    """
  end

  attr :class, :any, default: nil
  attr :type, :atom, required: true

  def content_type_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class={["gap-1.5 whitespace-nowrap", @class]}>
      <.content_type_icon type={@type} class="size-3.5" />
      {ContentType.translated_label(@type)}
    </.badge>
    """
  end
end
