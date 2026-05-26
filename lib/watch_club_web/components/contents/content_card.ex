defmodule WatchClubWeb.Components.Contents.ContentCard do
  @moduledoc """
  Card for a content result or library item.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.ContentView

  attr :content, ContentView, required: true
  attr :library_id_context, :string, default: nil

  def content_card(assigns) do
    library_item =
      case assigns.library_id_context do
        nil ->
          nil

        library_id ->
          Enum.find(assigns.content.in_libraries, fn item -> item.library_id == library_id end)
      end

    assigns = assigns |> assign(:library_item, library_item)

    ~H"""
    <.card
      as="article"
      id={"content-card-#{ContentView.unique_id(@content)}"}
      data_slot="content-card"
      padding="none"
      class="group/content-card w-full overflow-hidden"
    >
      <.tmdb_poster size="w342" path={@content.image_path} class="w-full">
        <button
          id={"content-card-reveal-#{ContentView.unique_id(@content)}"}
          type="button"
          class="absolute inset-0 z-20 md:hidden group-data-[state=revealed]/content-card:hidden"
          aria-label={dgettext("clubs", "Reveal details for %{title}", title: @content.title)}
          phx-click={reveal_content_card()}
        />

        <div class="pointer-events-none absolute inset-0 z-30 flex h-full w-full flex-col overflow-hidden bg-linear-to-b from-surface-inset/40 to-surface-inset/90 opacity-0 transition-opacity duration-150 group-hover/content-card:pointer-events-auto group-hover/content-card:opacity-100 group-focus-within/content-card:pointer-events-auto group-focus-within/content-card:opacity-100 group-data-[state=revealed]/content-card:pointer-events-auto group-data-[state=revealed]/content-card:opacity-100">
          <div class="flex translate-y-[-0.25rem] items-center justify-between gap-related p-tight transition-transform duration-150 group-hover/content-card:translate-y-0 group-focus-within/content-card:translate-y-0 group-data-[state=revealed]/content-card:translate-y-0">
            <.avatar
              :if={@library_item && @library_item.added_by}
              id={@library_item.added_by.id}
              name={@library_item.added_by.username}
              size="lg"
            />
            <div class="flex-1"></div>
            <.dropdown_menu id={"content-card-menu-#{ContentView.unique_id(@content)}"}>
              <:trigger>
                <.button
                  id={"content-card-actions-trigger-#{ContentView.unique_id(@content)}"}
                  variant="secondary"
                  size="icon"
                  aria-label={dgettext("clubs", "Content actions")}
                >
                  <Lucideicons.ellipsis_vertical />
                </.button>
              </:trigger>
              <.dropdown_menu_item
                id={"content-card-actions-coming-soon-#{ContentView.unique_id(@content)}"}
                disabled
              >
                <Lucideicons.circle_ellipsis />
                {dgettext("clubs", "Actions coming soon")}
              </.dropdown_menu_item>
            </.dropdown_menu>
          </div>

          <.link
            id={"content-card-details-link-#{ContentView.unique_id(@content)}"}
            navigate={ContentView.details_url(@content)}
            class="min-h-0 flex-1 overflow-hidden text-left"
          >
            <div class="flex h-full w-full items-end">
              <div class="px-related pb-related text-text">
                <div class="flex flex-row items-center gap-tight leading-none">
                  <span :if={@content.origin_country}>
                    {WatchClub.Languages.to_flag(@content.origin_country)}
                  </span>
                  <span :if={@content.release_date} class="font-medium">
                    {@content.release_date.year}
                  </span>
                </div>

                <h2 class="mt-tight line-clamp-3 text-xl leading-tight font-bold whitespace-normal text-text">
                  {@content.title}
                </h2>
              </div>
            </div>
          </.link>

          <div class="mb-tight flex w-full flex-row gap-tight px-tight">
            <.button
              id={"content-card-play-button-#{ContentView.unique_id(@content)}"}
              type="button"
              variant="primary"
              class="w-full"
            >
              <Lucideicons.play />
              {dgettext("clubs", "Play")}
            </.button>
          </div>
        </div>
      </.tmdb_poster>
    </.card>
    """
  end

  defp reveal_content_card(js \\ %JS{}) do
    js
    |> JS.remove_attribute("data-state", to: "[data-slot='content-card']")
    |> JS.set_attribute({"data-state", "revealed"}, to: {:closest, "[data-slot='content-card']"})
  end
end
