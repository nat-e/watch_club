defmodule WatchClubWeb.Components.Navigation.Navbar.SearchResults do
  @moduledoc """
  Search result states for the navigation search.

  Owner-private to `NavbarLive`. The hardcoded retry phx-click is a global
  navbar event handled by the owning LiveComponent rather than reusable
  component API.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.ContentView

  attr :form, :any, required: true
  attr :id_prefix, :string, required: true
  attr :myself, :any, required: true
  attr :search_results, :any, required: true

  def search_results(%{search_results: nil, form: %{errors: []}} = assigns) do
    ~H"""
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.search />
      </:icon>
      <:description>
        {dgettext("search", "Start typing to search")}
      </:description>
    </.empty>
    """
  end

  def search_results(%{search_results: nil} = assigns) do
    ~H"""
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.triangle_alert />
      </:icon>
      <:description>
        {dgettext("search", "There was an error searching for your content")}
      </:description>
      <.button
        id={"#{@id_prefix}-retry-button"}
        variant="secondary"
        size="sm"
        phx-target={@myself}
        phx-click="retry_preview_search"
      >
        {dgettext("default", "Try again")}
      </.button>
    </.empty>
    """
  end

  def search_results(%{search_results: []} = assigns) do
    ~H"""
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.search_x />
      </:icon>
      <:description>
        {dgettext("search", "We didn't find any content for your search")}
      </:description>
    </.empty>
    """
  end

  def search_results(assigns) do
    ~H"""
    <button
      id={"#{@id_prefix}-see-all-results-button"}
      type="submit"
      class="flex w-full shrink-0 items-center justify-center gap-related border-b border-border-subtle p-related text-sm font-semibold text-text-muted transition-colors hover:bg-surface-hover hover:text-text focus-visible:bg-surface-hover focus-visible:text-text focus-visible:outline-none"
    >
      <span>
        {dgettext("search", "See all results")}
        <.kbd>Enter ⏎</.kbd>
      </span>
      <Lucideicons.chevron_right class="size-icon" />
    </button>
    <.search_preview_card
      :for={result <- @search_results}
      id_prefix={@id_prefix}
      content={result}
    />
    """
  end

  attr :content, ContentView, required: true
  attr :id_prefix, :string, required: true

  defp search_preview_card(assigns) do
    ~H"""
    <.link
      id={"#{@id_prefix}-preview-link-#{ContentView.unique_id(@content)}"}
      class="flex gap-related hover:bg-surface-hover p-related"
      navigate={details_url(@content)}
    >
      <.tmdb_poster
        path={@content.image_path}
        size="w154"
        class="w-20 shrink-0 rounded-control"
      />
      <.stack space="related" class="h-full flex-1">
        <span class="font-bold">{search_preview_title(@content)}</span>
        <p class="line-clamp-2 text-sm text-text-muted">{@content.description}</p>
      </.stack>
    </.link>
    """
  end

  defp search_preview_title(%ContentView{title: title, release_date: nil}), do: title

  defp search_preview_title(%ContentView{title: title, release_date: date}),
    do: "#{title} (#{date.year})"

  defp details_url(%ContentView{type: :movie} = movie), do: ~p"/movies/#{movie.external_id}"
  defp details_url(%ContentView{type: :tv_show} = show), do: ~p"/shows/#{show.external_id}"
end
