defmodule WatchClubWeb.Components.Contents.ContentCard do
  @moduledoc """
  Card for a content result or library item.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  attr :id, :string
  attr :content, Content, required: true
  attr :current_user, User, required: true

  attr :library_item, LibraryItem,
    default: nil,
    doc:
      "If we are in the context of displaying a LibraryItem, an avatar will be displayed in the overlay"

  def content_card(assigns) do
    ~H"""
    <.card
      as="article"
      id={@id}
      data_slot="content-card"
      padding="none"
      class="group/content-card relative overflow-hidden w-44"
    >
      <.tmdb_poster size="w342" path={@content.implementation.best_localization.poster_path}>
        <Lucideicons.check_circle_2
          :if={@content.actor_progress_status == :completed}
          class="absolute justify-self-end p-tight m-tight text-success size-9 bg-black/60 rounded-full"
        />
        <button
          id={"content-card-reveal-#{@id}"}
          type="button"
          class="absolute inset-0 z-20 [@media(hover:hover)]:hidden group-data-[state=revealed]/content-card:hidden"
          aria-label={
            dgettext("clubs", "Reveal details for %{title}",
              title: @content.implementation.best_localization.title
            )
          }
          phx-click={reveal_content_card()}
        />
        <.overlay
          id={@id}
          content={@content}
          current_user={@current_user}
          library_item={@library_item}
        />
      </.tmdb_poster>
    </.card>
    """
  end

  attr :id, :string
  attr :content, Content, required: true
  attr :current_user, User, required: true
  attr :library_item, LibraryItem, default: nil

  defp overlay(assigns) do
    assigns =
      assigns
      |> assign(
        removable?:
          assigns.library_item &&
            Clubs.can_destroy_library_item?(assigns.current_user, assigns.library_item)
      )

    ~H"""
    <.stack
      space="related"
      class="pointer-events-none absolute inset-0 z-30 p-tight h-full w-full overflow-hidden bg-linear-to-b from-surface-inset/40 to-surface-inset/90 opacity-0 transition-opacity duration-150 card-revealed:pointer-events-auto card-revealed:opacity-100"
    >
      <div class="relative z-10 flex translate-y-[-0.25rem] items-center gap-related transition-transform duration-150 card-revealed:translate-y-0">
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
            id={"content-card-actions-share-#{@id}"}
            phx-click="open_add_to_library_modal"
            phx-value-content_id={@content.id}
          >
            <Lucideicons.share_2 />
            {dgettext("clubs", "Share with club")}
          </.dropdown_menu_item>
          <.dropdown_menu_separator />
          <.dropdown_menu_item
            :if={@removable?}
            id={"content-card-actions-remove-#{@id}"}
            variant="destructive"
            phx-click="remove_library_item"
            phx-value-content_id={@library_item.content_id}
          >
            <Lucideicons.trash_2 />
            {dgettext("clubs", "Remove from club")}
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
          navigate={Url.content_details_link(@content.type, @content.external_id)}
          class="line-clamp-4 text-xl leading-tight font-bold after:absolute after:inset-0 after:content-['']"
        >
          {@content.implementation.best_localization.title}
        </.link>
      </.stack>

      <.live_component
        id={PlayOrRequestButtonLive.dom_id(ContentIdentity.from_content(@content))}
        module={PlayOrRequestButtonLive}
        content_identity={ContentIdentity.from_content(@content)}
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
