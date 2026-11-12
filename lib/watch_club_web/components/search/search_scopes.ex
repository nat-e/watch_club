defmodule WatchClubWeb.Components.Search.SearchScopes do
  @moduledoc """
  What a search looks in: one scope per Metadata Provider, because their results can't share one
  list: Movies and TV Shows, or Sports Events. Then the filter that keeps only the Library, named
  after the instance.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :scope, :atom, required: true, values: SearchContentType.values()

  attr :on_scope, :any,
    required: true,
    doc: "the event or JS commands of a scope, with its `scope`"

  attr :has_media, :boolean, required: true, doc: "whether the Library filter is on"
  attr :on_toggle, :any, required: true, doc: "the event or JS commands of the filter"
  attr :instance_name, :string, required: true, doc: "names the Library filter"
  attr :class, :any, default: nil

  def search_scopes(assigns) do
    ~H"""
    <div id={@id} class={["flex flex-wrap items-center gap-related", @class]}>
      <div
        role="radiogroup"
        aria-label={dgettext("search", "Search in")}
        class="flex flex-wrap items-center gap-related"
      >
        <.filter_chip
          :for={scope <- SearchContentType.values()}
          id={"#{@id}-#{scope}"}
          on={@scope == scope}
          radio
          phx-click={@on_scope}
          phx-value-scope={scope}
        >
          <:icon>
            <Lucideicons.clapperboard :if={scope == :movies_and_shows} />
            <Lucideicons.trophy :if={scope == :sports_events} />
          </:icon>
          {SearchContentType.translated_label(scope)}
        </.filter_chip>
      </div>
      <.filter_chip id={"#{@id}-in-library"} on={@has_media} phx-click={@on_toggle} class="ml-auto">
        <:icon><Lucideicons.library /></:icon>
        {dgettext("search", "On %{name}", name: @instance_name)}
      </.filter_chip>
    </div>
    """
  end
end
