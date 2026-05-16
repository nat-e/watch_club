defmodule WatchClubWeb.Components.Contents do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Images

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.{ContentType, ContentView}

  @lucide_icon_names Lucideicons.icon_names()
  @lucide_icon_names_by_string Map.new(@lucide_icon_names, &{Atom.to_string(&1), &1})

  attr :class, :any, default: nil
  attr :name, :any, required: true
  attr :rest, :global

  def lucide_icon(assigns) do
    icon_name = normalize_icon_name(assigns.name)
    attrs = if assigns.class, do: Map.put(assigns.rest, :class, assigns.class), else: assigns.rest

    apply(Lucideicons, icon_name, [Map.put(attrs, :__changed__, nil)])
  end

  attr :class, :any, default: nil
  attr :library, Library, required: true
  attr :rest, :global

  def library_icon(assigns) do
    ~H"""
    <.lucide_icon name={@library.icon} class={@class} {@rest} />
    """
  end

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
    <.badge variant="secondary" class={["whitespace-nowrap", @class]}>
      <:icon><.content_type_icon type={@type} /></:icon>
      {ContentType.translated_label(@type)}
    </.badge>
    """
  end

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
    <article
      id={"content-card-#{ContentView.unique_id(@content)}"}
      data-slot="content-card"
      class="group/content-card relative w-full overflow-hidden rounded-xl border border-border-subtle bg-surface-inset shadow transition-shadow duration-300 outline-none hover:shadow-lg focus-within:ring-border-strong"
    >
      <.tmdb_poster size="w342" path={@content.image_path} class="w-full rounded-xl">
        <button
          type="button"
          class="absolute inset-0 z-20 md:hidden group-data-[state=revealed]/content-card:hidden"
          aria-label={dgettext("clubs", "Reveal details for %{title}", title: @content.title)}
          phx-click={reveal_content_card()}
        />

        <div class="pointer-events-none absolute inset-0 z-30 flex h-full w-full flex-col overflow-hidden rounded-xl bg-linear-to-b from-surface-inset/40 to-surface-inset/90 opacity-0 transition-opacity duration-150 group-hover/content-card:pointer-events-auto group-hover/content-card:opacity-100 group-focus-within/content-card:pointer-events-auto group-focus-within/content-card:opacity-100 group-data-[state=revealed]/content-card:pointer-events-auto group-data-[state=revealed]/content-card:opacity-100">
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
                  variant="secondary"
                  size="icon"
                  aria-label={dgettext("clubs", "Content actions")}
                >
                  <Lucideicons.ellipsis_vertical />
                </.button>
              </:trigger>
              <.dropdown_menu_item disabled>
                <Lucideicons.circle_ellipsis />
                {dgettext("clubs", "Actions coming soon")}
              </.dropdown_menu_item>
            </.dropdown_menu>
          </div>

          <.link
            href={ContentView.details_url(@content)}
            class="min-h-0 flex-1 overflow-hidden text-left"
          >
            <div class="flex h-full w-full items-end">
              <div class="px-related pb-related text-white">
                <div class="flex flex-row items-center gap-tight leading-none">
                  <span :if={@content.origin_country}>{ContentView.country_flag(@content)}</span>
                  <span :if={@content.release_date} class="font-medium">
                    {@content.release_date.year}
                  </span>
                </div>

                <h2 class="mt-tight line-clamp-3 text-xl leading-tight font-bold whitespace-normal text-white">
                  {@content.title}
                </h2>
              </div>
            </div>
          </.link>

          <div class="mb-tight flex w-full flex-row gap-tight px-tight">
            <.button
              type="button"
              variant="secondary"
              class="w-full border-0 bg-primary text-on-primary hover:bg-primary-hover active:bg-primary-active"
            >
              <Lucideicons.play />
              {dgettext("clubs", "Play")}
            </.button>
          </div>
        </div>
      </.tmdb_poster>
    </article>
    """
  end

  defp normalize_icon_name(name) when is_atom(name) and name in @lucide_icon_names, do: name

  defp normalize_icon_name(name) when is_binary(name) do
    Map.get(@lucide_icon_names_by_string, name, :library)
  end

  defp normalize_icon_name(_name), do: :library

  defp reveal_content_card(js \\ %JS{}) do
    js
    |> JS.remove_attribute("data-state", to: "[data-slot='content-card']")
    |> JS.set_attribute({"data-state", "revealed"}, to: {:closest, "[data-slot='content-card']"})
  end
end
