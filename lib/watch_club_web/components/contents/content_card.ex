defmodule WatchClubWeb.Components.Contents.ContentCard do
  @moduledoc """
  Card for a content result or library item.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentView
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  attr :id, :string
  attr :content, ContentView, required: true
  attr :current_user, User, required: true
  attr :library_id_context, :string, default: nil

  def content_card(assigns) do
    ~H"""
    <.card
      as="article"
      id={@id}
      data_slot="content-card"
      padding="none"
      class="group/content-card relative overflow-hidden w-44"
    >
      <.tmdb_poster size="w342" path={@content.image_path}>
        <Lucideicons.check_circle_2
          :if={ContentView.viewer_progress_status(@content) == :completed}
          class="absolute justify-self-end p-tight m-tight text-success size-9 bg-black/60 rounded-full"
        />
        <button
          id={"content-card-reveal-#{@id}"}
          type="button"
          class="absolute inset-0 z-20 [@media(hover:hover)]:hidden group-data-[state=revealed]/content-card:hidden"
          aria-label={dgettext("clubs", "Reveal details for %{title}", title: @content.title)}
          phx-click={reveal_content_card()}
        />
        <.overlay
          id={@id}
          content={@content}
          current_user={@current_user}
          library_id_context={@library_id_context}
        />
      </.tmdb_poster>
    </.card>
    """
  end

  attr :id, :string
  attr :content, ContentView, required: true
  attr :current_user, User, required: true
  attr :library_id_context, :string, default: nil

  defp overlay(assigns) do
    library_item =
      case assigns.library_id_context do
        nil ->
          nil

        library_id ->
          Enum.find(assigns.content.in_libraries, fn item -> item.library_id == library_id end)
      end

    assigns =
      assigns
      |> assign(:library_item, library_item)

    ~H"""
    <.stack
      space="related"
      class="pointer-events-none absolute inset-0 z-30 p-tight h-full w-full overflow-hidden bg-linear-to-b from-surface-inset/40 to-surface-inset/90 opacity-0 transition-opacity duration-150 group-hover/content-card:pointer-events-auto group-hover/content-card:opacity-100 group-focus-within/content-card:pointer-events-auto group-focus-within/content-card:opacity-100 group-data-[state=revealed]/content-card:pointer-events-auto group-data-[state=revealed]/content-card:opacity-100"
    >
      <div class="relative z-10 flex translate-y-[-0.25rem] items-center gap-related transition-transform duration-150 group-hover/content-card:translate-y-0 group-focus-within/content-card:translate-y-0 group-data-[state=revealed]/content-card:translate-y-0">
        <.avatar
          :if={@library_item && @library_item.added_by}
          id={@library_item.added_by.id}
          name={@library_item.added_by.username}
        />
        <.dropdown_menu id={"content-card-menu-#{@id}"} class="ml-auto">
          <:trigger>
            <.button
              id={"content-card-actions-trigger-#{@id}"}
              variant="secondary"
              size="icon"
              aria-label={dgettext("clubs", "Content actions")}
            >
              <Lucideicons.ellipsis_vertical />
            </.button>
          </:trigger>
          <.dropdown_menu_item
            id={"content-card-actions-coming-soon-#{@id}"}
            disabled
          >
            <Lucideicons.circle_ellipsis />
            {dgettext("clubs", "Actions coming soon")}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </div>

      <.stack space="tight" class="justify-end flex-1">
        <.inline space="tight" class="leading-none">
          <span :if={@content.origin_country}>
            {WatchClub.Languages.country_flag(@content.origin_country)}
          </span>
          <span :if={@content.release_date} class="font-medium">
            {@content.release_date.year}
          </span>
        </.inline>

        <.link
          navigate={ContentView.details_url(@content)}
          class="line-clamp-4 text-xl leading-tight font-bold after:absolute after:inset-0 after:content-['']"
        >
          {@content.title}
        </.link>
      </.stack>

      <.live_component
        id={"play-or-request-button-#{@id}"}
        module={PlayOrRequestButtonLive}
        content={@content}
        current_user={@current_user}
        size="md"
        class="z-10"
      />
    </.stack>
    """
  end

  defp reveal_content_card(js \\ %JS{}) do
    js
    |> JS.remove_attribute("data-state", to: "[data-slot='content-card']")
    |> JS.set_attribute({"data-state", "revealed"}, to: {:closest, "[data-slot='content-card']"})
  end
end
