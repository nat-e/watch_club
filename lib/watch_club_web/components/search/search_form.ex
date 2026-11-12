defmodule WatchClubWeb.Components.Search.SearchForm do
  @moduledoc """
  A search typed in a dialog: one field after a search icon, which searches as you type and on
  Enter. It focuses itself, since the dialogs that hold it exist to search, such as Match.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :query, :string, required: true
  attr :label, :string, required: true, doc: "what it searches, for screen readers"
  attr :placeholder, :string, default: nil, doc: "the label when unset"

  attr :on_search, :any,
    required: true,
    doc: "the event or JS commands of a search, with its `query`"

  attr :class, :any, default: nil

  def search_form(assigns) do
    ~H"""
    <.form
      id={@id}
      for={to_form(%{})}
      layout="none"
      role="search"
      autocomplete="off"
      phx-change={@on_search}
      phx-submit={@on_search}
      class={@class}
    >
      <div class="relative">
        <Lucideicons.search
          aria-hidden="true"
          class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle"
        />
        <.input
          id={"#{@id}-query"}
          name="query"
          value={@query}
          type="search"
          placeholder={@placeholder || @label}
          aria-label={@label}
          autofocus
          phx-debounce="300"
          class="pl-9!"
        />
      </div>
    </.form>
    """
  end
end
