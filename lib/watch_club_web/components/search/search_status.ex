defmodule WatchClubWeb.Components.Search.SearchStatus do
  @moduledoc """
  What a search shows instead of results: a hint before typing, loading rows, an error or no
  results, nothing while there are results. It also tells screen readers how the search went,
  as they can't see the results change.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :status, :atom, values: [:idle, :loading, :error, :ok], required: true
  attr :query, :string, required: true
  attr :result_count, :integer, required: true
  attr :on_retry, :any, required: true, doc: "the event or JS commands of the Try again button"
  attr :hint, :string, required: true, doc: "what to type, before typing"
  attr :class, :any, default: nil

  def search_status(assigns) do
    ~H"""
    <p role="status" class="sr-only">
      <span :if={@status == :loading}>{dgettext("search", "Searching…")}</span>
      <span :if={@status == :error}>{dgettext("search", "The search didn't work.")}</span>
      <span :if={@status == :ok}>
        {dngettext("search", "%{count} result", "%{count} results", @result_count)}
      </span>
    </p>
    <.status_body
      id={@id}
      status={@status}
      query={@query}
      result_count={@result_count}
      on_retry={@on_retry}
      hint={@hint}
      class={@class}
    />
    """
  end

  defp status_body(%{status: :idle} = assigns) do
    ~H"""
    <p id={@id} class={["p-group text-center text-sm text-text-muted", @class]}>
      {@hint}
    </p>
    """
  end

  defp status_body(%{status: :loading} = assigns) do
    ~H"""
    <div id={@id} class={["flex flex-col", @class]} aria-hidden="true">
      <div :for={_row <- 1..4} class="flex animate-pulse items-center gap-group p-related">
        <span class="aspect-2/3 w-12 shrink-0 rounded-sm bg-surface-hover"></span>
        <span class="flex flex-1 flex-col gap-related">
          <span class="h-3 w-1/2 rounded-full bg-surface-hover"></span>
          <span class="h-3 w-1/4 rounded-full bg-surface-hover"></span>
        </span>
      </div>
    </div>
    """
  end

  defp status_body(%{status: :error} = assigns) do
    ~H"""
    <.empty id={@id} border={false} size="sm" class={@class}>
      <:icon><Lucideicons.triangle_alert /></:icon>
      <:description>{dgettext("search", "The search didn't work.")}</:description>
      <.button id={"#{@id}-retry"} variant="secondary" size="sm" phx-click={@on_retry}>
        {dgettext("search", "Try again")}
      </.button>
    </.empty>
    """
  end

  defp status_body(%{status: :ok, result_count: 0} = assigns) do
    ~H"""
    <.empty id={@id} border={false} size="sm" class={@class}>
      <:icon><Lucideicons.search_x /></:icon>
      <:title>{dgettext("search", "No results")}</:title>
      <:description>
        {raw(
          dgettext("search", "We didn't find anything for “%{query}”.",
            query: gtspan(@query, "font-semibold text-text")
          )
        )}
      </:description>
    </.empty>
    """
  end

  defp status_body(assigns) do
    ~H"""
    """
  end
end
