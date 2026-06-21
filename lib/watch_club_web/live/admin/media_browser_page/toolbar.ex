defmodule WatchClubWeb.Admin.MediaBrowserPage.Toolbar do
  @moduledoc """
  Toolbar for the Admin Media browser.

  Wraps every control in a single `<form phx-change="apply_state">` so every
  filter / sort change patches the URL through one handler. Below the
  controls, applied filters render as removable chips when at least one
  filter is active.
  """
  use WatchClubWeb, :html

  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.UI.Select

  alias WatchClubWeb.Admin.MediaBrowserPage.State

  attr :state, State, required: true

  def toolbar(assigns) do
    ~H"""
    <.card surface="default" padding="cluster">
      <form
        id="media-browser-toolbar"
        phx-change="apply_state"
        aria-label="Filter media"
      >
        <.stack space="related">
          <.cluster space="related">
            <div class="relative grow basis-full sm:basis-[18rem] min-w-0">
              <label for="media-browser-search" class="sr-only">
                Search file name or matched content
              </label>
              <Lucideicons.search
                aria-hidden="true"
                class="pointer-events-none absolute left-3 top-1/2 size-icon-sm -translate-y-1/2 text-text-subtle"
              />
              <input
                id="media-browser-search"
                type="search"
                name="search"
                value={@state.filter.search}
                placeholder="Search file name or content…"
                phx-debounce="300"
                class="h-control-md w-full rounded-md border border-border bg-surface-inset pl-9 pr-3 text-sm text-text placeholder:text-text-subtle focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
              />
            </div>

            <.facet_select
              id="filter-media-type"
              name="media_type"
              value={@state.filter.media_type}
              placeholder="Media: Any"
              label_prefix="Media"
              options={[{:video, "Video"}, {:ebook, "Ebook"}, {:audiobook, "Audiobook"}]}
            />

            <div class="sm:ml-auto">
              <.sort_select state={@state} />
            </div>
          </.cluster>

          <.cluster :if={State.Filter.active?(@state.filter)} space="tight">
            <.applied_chip
              :if={present?(@state.filter.search)}
              label="Search"
              field="search"
            >
              {@state.filter.search}
            </.applied_chip>
            <.applied_chip
              :if={@state.filter.media_type}
              label="Media"
              field="media_type"
            >
              {humanize(@state.filter.media_type)}
            </.applied_chip>
            <button
              type="button"
              phx-click="filter_clear"
              class="inline-flex h-control-sm items-center px-2 text-xs text-text-subtle hover:text-text"
            >
              Clear all
            </button>
          </.cluster>
        </.stack>
      </form>
    </.card>
    """
  end

  # --------------------------------------------------------------------------
  # Filter select
  # --------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :atom, default: nil
  attr :placeholder, :string, required: true
  attr :label_prefix, :string, required: true
  attr :options, :list, required: true

  defp facet_select(assigns) do
    ~H"""
    <.select
      id={@id}
      name={@name}
      value={@value && to_string(@value)}
      placeholder={@placeholder}
      size="md"
    >
      <.select_item value="">{@placeholder}</.select_item>
      <.select_item :for={{atom, label} <- @options} value={to_string(atom)}>
        {@label_prefix}: {label}
      </.select_item>
    </.select>
    """
  end

  # --------------------------------------------------------------------------
  # Sort select — combines field + order into one option (Last import desc,
  # Last import asc, Path asc, Path desc). Submitted as "sort" form field
  # and decoded server-side into sort_by + sort_order.
  # --------------------------------------------------------------------------

  attr :state, State, required: true

  defp sort_select(assigns) do
    assigns = assign(assigns, :value, sort_value(assigns.state.sort))

    ~H"""
    <.select
      id="sort-select"
      name="sort"
      value={@value}
      size="md"
    >
      <.select_item :for={{value, label} <- sort_options()} value={value}>
        {label}
      </.select_item>
    </.select>
    """
  end

  @doc """
  Returns the list of sort `{form_value, label}` pairs.
  Format: `"<field>:<order>"` e.g. `"imported_at:desc"`.
  """
  def sort_options do
    [
      {"imported_at:desc", "Last import (newest first)"},
      {"imported_at:asc", "Last import (oldest first)"},
      {"path:asc", "Path (A → Z)"},
      {"path:desc", "Path (Z → A)"}
    ]
  end

  defp sort_value(%State.Sort{by: by, order: order}),
    do: "#{by}:#{order}"

  # --------------------------------------------------------------------------
  # Applied filter chip — × button clears that single filter
  # --------------------------------------------------------------------------

  attr :label, :string, required: true
  attr :field, :string, required: true
  slot :inner_block, required: true

  defp applied_chip(assigns) do
    ~H"""
    <span class="inline-flex h-7 items-center gap-tight rounded-full border border-accent-border bg-accent-bg pl-3 pr-1.5 text-xs text-accent">
      <span>{@label}:</span>
      <strong class="font-semibold">{render_slot(@inner_block)}</strong>
      <button
        type="button"
        phx-click="filter_remove"
        phx-value-field={@field}
        class="grid size-icon-sm place-items-center rounded-full hover:bg-surface-hover"
        aria-label={"Remove #{@label} filter"}
      >
        <Lucideicons.x class="size-icon-sm" />
      </button>
    </span>
    """
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

  defp humanize(:video), do: "Video"
  defp humanize(:ebook), do: "Ebook"
  defp humanize(:audiobook), do: "Audiobook"
  defp humanize(other), do: to_string(other)
end
