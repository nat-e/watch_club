defmodule WatchClubWeb.Components.UI.SplitView do
  @moduledoc """
  A list beside what's open from it, as on the Playlists page. Narrow screens show one at a time:
  the list, or what's open. Wider screens show both, each scrolling on its own under the app bar.
  Phones float the list's main action above the tabs.

  It switches at the `@4xl` width of the layout's main column, like the app bar's back arrow for
  a `narrow_only` parent, so the arrow shows exactly while the list isn't beside what's open.
  """

  use Phoenix.Component

  attr :open, :boolean, required: true, doc: "narrow screens show the detail instead of the list"
  slot :list, required: true
  slot :detail, required: true, doc: "a container, so its content follows its own width"
  slot :fab, doc: "the list's main action, floating above the tabs on phones"

  def split_view(assigns) do
    ~H"""
    <div class="flex md:h-[calc(100svh-var(--wc-app-bar-height))]">
      <div class={[
        "w-full flex-col gap-group border-border-subtle pb-group md:overflow-y-auto md:pt-group [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] @4xl/main:flex @4xl/main:w-72 @4xl/main:shrink-0 @4xl/main:border-r",
        @fab != [] && "max-md:pb-[calc(var(--spacing-control-lg)+2*var(--spacing-group))]",
        @open && "hidden",
        !@open && "flex"
      ]}>
        {render_slot(@list)}
      </div>
      <div
        :if={@fab != [] and not @open}
        class="fixed right-page bottom-[calc(var(--wc-tab-bar-height)+var(--spacing-group))] z-30 md:hidden"
      >
        {render_slot(@fab)}
      </div>
      <div class={[
        "@container min-w-0 flex-1 flex-col md:overflow-y-auto [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] @4xl/main:flex",
        @open && "flex",
        !@open && "hidden"
      ]}>
        {render_slot(@detail)}
      </div>
    </div>
    """
  end
end
