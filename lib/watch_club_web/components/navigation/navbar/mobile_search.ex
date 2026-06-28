defmodule WatchClubWeb.Components.Navigation.Navbar.MobileSearch do
  @moduledoc """
  Mobile search control for the navigation bar.

  Owner-private to `NavbarLive`. The hardcoded phx-* event names are global
  navbar events handled by the owning LiveComponent rather than reusable
  component API.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Navigation.Navbar.SearchResults

  attr :form, Phoenix.HTML.Form, required: true
  attr :myself, :any, required: true
  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true
  attr :search_reasults, :list, required: true

  def mobile_search(assigns) do
    ~H"""
    <div class="flex md:hidden w-full flex-row justify-between items-center min-w-0">
      <h2 class="font-heading text-xl font-semibold">{@instance_settings.name}</h2>
      <.button
        id="mobile-search-open-button"
        class="block md:hidden shrink-0"
        variant="ghost"
        phx-click={
          JS.show(to: "#mobile-search-overlay", display: "flex")
          |> JS.focus(to: "#search-overlay-input")
        }
      >
        <Lucideicons.search class="size-icon-lg" />
      </.button>
      <.form
        id="mobile-search-overlay"
        for={@form}
        layout="none"
        phx-change="preview_search"
        phx-submit="open_search"
        phx-target={@myself}
        class="hidden flex-col z-50 fixed inset-0 bg-surface border-b border-border p-related"
      >
        <.search_overlay_header form={@form} />
        <div class="relative flex-1 flex flex-col min-h-0">
          <div class="flex-1 divide-y overflow-y-auto min-h-0">
            <.search_results
              id_prefix="mobile-search-results"
              myself={@myself}
              form={@form}
              search_results={@search_results}
            />
          </div>
          <div
            id="mobile-overlay-search-content-type"
            class="hidden h-full absolute inset-0 bg-surface"
          >
            <button
              :for={content_type <- SearchContentType.values()}
              id={"mobile-search-content-type-#{content_type}-button"}
              type="button"
              class={[
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
                @form[:content_type].value == content_type &&
                  "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-content-type",
                  "#mobile-search-input-content-type",
                  content_type
                )
              }
              phx-target={@myself}
            >
              <.content_type_icon type={content_type} class="size-icon" />{SearchContentType.translated_label(
                content_type
              )}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

  defp search_overlay_header(assigns) do
    ~H"""
    <div class="border-b p-related">
      <.inline class="h-row-lg">
        <.button
          id="mobile-search-back-button"
          variant="ghost"
          size="icon"
          phx-click={JS.hide(to: "#mobile-search-overlay")}
        >
          <Lucideicons.arrow_left />
        </.button>
        <div
          id="mobile-search-input-wrapper"
          class="relative flex-1"
          phx-click={JS.hide(to: "#mobile-overlay-search-content-type")}
        >
          <.input
            id="search-overlay-input"
            field={@form[:query]}
            placeholder={
              dgettext("search", "Search %{content_type}",
                content_type: SearchContentType.translated_label(@form[:content_type].value)
              )
            }
            class="peer h-control-md rounded-full bg-surface-inset p-group items-center pr-8 truncate"
            phx-debounce="300"
          />
          <.button
            id="mobile-search-clear-button"
            type="reset"
            variant="ghost"
            size="icon-sm"
            class="absolute right-2 top-1 peer-placeholder-shown:hidden"
            phx-click={JS.dispatch("change", to: "#mobile-search-overlay")}
          >
            <Lucideicons.x />
          </.button>
        </div>
      </.inline>
      <.cluster class="gap-x-group gap-y-related">
        <.input id="mobile-search-input-content-type" field={@form[:content_type]} class="hidden" />
        <.button
          id="mobile-search-content-type-filter-button"
          variant="secondary"
          class="flex gap-related w-46 items-center justify-between"
          phx-click={JS.toggle(to: "#mobile-overlay-search-content-type")}
        >
          <.inline>
            <.content_type_icon type={@form[:content_type].value} class="size-icon" />
            {SearchContentType.translated_label(@form[:content_type].value)}
          </.inline>
          <Lucideicons.chevron_down class="size-icon text-text-muted" />
        </.button>
      </.cluster>
    </div>
    """
  end

  defp hide_overlay_and_change_value(overlay_selector, field_selector, value) do
    JS.hide(to: overlay_selector)
    |> JS.set_attribute({"value", value},
      to: field_selector
    )
    |> JS.dispatch("input", to: field_selector)
    |> JS.focus(to: "#search-overlay-input")
  end
end
