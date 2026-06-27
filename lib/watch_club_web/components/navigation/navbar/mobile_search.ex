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
        <.search_overlay_header
          current_user={@current_user}
          myself={@myself}
          form={@form}
        />
        <div class="relative flex-1 flex flex-col min-h-0">
          <div class="flex-1 divide-y overflow-y-auto min-h-0">
            <.search_results
              id_prefix="mobile-search-results"
              myself={@myself}
              form={@form}
              search_results={@search_results}
            />
          </div>
          <div id="mobile-overlay-search-location" class="hidden absolute inset-0 bg-surface">
            <button
              id="mobile-search-location-everywhere-button"
              type="button"
              class={[
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
                @form[:location].value == nil && "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-location",
                  "#mobile-search-input-location",
                  ""
                )
              }
              phx-target={@myself}
            >
              <Lucideicons.globe class="size-icon-lg" />{dgettext("search", "Everywhere")}
            </button>
            <button
              :for={membership <- @current_user.memberships}
              id={"mobile-search-location-#{membership.club.id}-button"}
              type="button"
              class={[
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
                @form[:location].value == membership.club.id &&
                  "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-location",
                  "#mobile-search-input-location",
                  membership.club.id
                )
              }
              phx-target={@myself}
            >
              <.avatar
                :if={membership.club}
                id={membership.club.id}
                name={membership.club.name}
                size="sm"
              />
              <span class="truncate">{membership.club.name}</span>
            </button>
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
          phx-click={
            JS.hide(to: "#mobile-overlay-search-location")
            |> JS.hide(to: "#mobile-overlay-search-content-type")
          }
        >
          <.input
            id="search-overlay-input"
            field={@form[:query]}
            placeholder={placeholder(assigns)}
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
        <.input id="mobile-search-input-location" field={@form[:location]} class="hidden" />
        <.button
          id="mobile-search-location-filter-button"
          variant="secondary"
          class="flex-1 gap-related min-w-38 items-center justify-between shrink"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-content-type")
            |> JS.toggle(to: "#mobile-overlay-search-location")
          }
        >
          <.inline :if={@form[:location].value == nil}>
            <Lucideicons.globe class="size-icon" /> {dgettext("search", "Everywhere")}
          </.inline>

          <.inline :if={@form[:location].value != nil} class="min-w-0">
            <.avatar
              id={get_club(@current_user, @form[:location].value).id}
              name={get_club(@current_user, @form[:location].value).name}
              size="xs"
              class="shrink-0"
            />
            <span class="flex-1 truncate">
              {get_club(@current_user, @form[:location].value).name}
            </span>
          </.inline>
          <Lucideicons.chevron_down class="size-icon text-text-muted shrink-0" />
        </.button>
        <.input id="mobile-search-input-content-type" field={@form[:content_type]} class="hidden" />
        <.button
          id="mobile-search-content-type-filter-button"
          variant="secondary"
          class="flex gap-related w-46 items-center justify-between"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-location")
            |> JS.toggle(to: "#mobile-overlay-search-content-type")
          }
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

  defp get_club(current_user, club_id) do
    %Membership{} = m = Enum.find(current_user.memberships, fn m -> m.club.id == club_id end)
    m.club
  end

  defp placeholder(%{form: form, current_user: current_user}) do
    content_type = form[:content_type].value

    case form[:location].value do
      nil ->
        dgettext("search", "Search all %{content_type}",
          content_type: SearchContentType.translated_label(content_type)
        )

      location_id ->
        membership =
          Enum.find(
            current_user.memberships,
            &(&1.club.id ==
                location_id)
          )

        dgettext("search", "Search %{content_type} in %{club_name}",
          content_type: SearchContentType.translated_label(content_type),
          club_name: membership.club.name
        )
    end
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
