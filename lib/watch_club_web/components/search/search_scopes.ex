defmodule WatchClubWeb.Components.Search.SearchScopes do
  @moduledoc """
  What a search looks in: one scope per Metadata Provider, because their results can't share one
  list. Movies and TV Shows are the only scope today, and Books show as coming soon, so they're
  labels rather than choices. Then the In the library filter, which keeps only the Library.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :has_media, :boolean, required: true, doc: "whether the In the library filter is on"
  attr :on_toggle, :any, required: true, doc: "the event or JS commands of the filter"
  attr :class, :any, default: nil

  def search_scopes(assigns) do
    ~H"""
    <div id={@id} class={["flex flex-wrap items-center gap-related", @class]}>
      <.badge id={"#{@id}-movies-and-shows"} variant="default" size="lg">
        <:icon class="[&_svg]:size-icon-sm"><Lucideicons.clapperboard /></:icon>
        {SearchContentType.translated_label(:movies_and_shows)}
      </.badge>
      <.badge id={"#{@id}-books"} variant="muted" size="lg" class="text-text-disabled!">
        <:icon class="[&_svg]:size-icon-sm"><Lucideicons.book_open /></:icon>
        {ContentType.translated_plural_label(:book)}
        <span class="font-normal">{dgettext("search", "soon")}</span>
      </.badge>
      <.filter_chip id={"#{@id}-in-library"} on={@has_media} phx-click={@on_toggle} class="ml-auto">
        <:icon><Lucideicons.library /></:icon>
        {dgettext("search", "In the library")}
      </.filter_chip>
    </div>
    """
  end
end
