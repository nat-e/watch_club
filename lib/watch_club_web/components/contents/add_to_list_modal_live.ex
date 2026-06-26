defmodule WatchClubWeb.Components.Contents.AddToListModalLive do
  use WatchClubWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id="list-selection-modal" on_close={JS.push("close", target: @myself)}>
        <:title>{dgettext("contents", "Add %{title} to List", title: @content_title)}</:title>
        <.stack space="group" class="relative w-full max-w-lg">
          <.stack space="group">
            <.empty :if={@list_options == []}>
              <:icon><Lucideicons.list /></:icon>
              <:title>{dgettext("contents", "You don't have any list yet")}</:title>
              <:description>
                {dgettext("contents", "You need to create a List before adding content to it")}
              </:description>
            </.empty>
            <.form
              :if={@list_options != []}
              for={%{}}
              id="list-selection-form"
              phx-target={@myself}
              phx-submit="submit"
            >
              <.list_selection_checkbox
                :for={option <- @list_options}
                list={option.list}
                already_in?={option.already_in?}
              />
              <:action>
                <.button
                  id="list-selection-submit-button"
                  type="submit"
                  disabled={Enum.all?(@list_options, & &1.already_in?)}
                >
                  {dgettext("default", "Save")}
                </.button>
              </:action>
            </.form>
          </.stack>
        </.stack>
      </.modal>
    </div>
    """
  end

  defp list_selection_checkbox(%{already_in?: true} = assigns) do
    ~H"""
    <div class="flex min-h-row-lg w-full flex-row items-center justify-between rounded-md border border-border bg-surface-selected p-group text-text">
      <div class="flex min-w-0 flex-row items-center gap-related">
        <.lucide_icon name={@list.icon} class="size-icon shrink-0" />
        <p class="truncate font-bold">{@list.name}</p>
      </div>
      <.badge variant="success">
        {dgettext("contents", "Already added")}
      </.badge>
    </div>
    """
  end

  defp list_selection_checkbox(assigns) do
    ~H"""
    <label class="flex min-h-row-lg w-full flex-row items-center justify-between rounded-md border border-border p-group transition-colors hover:bg-surface-hover active:bg-surface-active">
      <div class="flex min-w-0 flex-row items-center gap-related">
        <.lucide_icon name={@list.icon} class="size-icon shrink-0" />
        <p class="truncate font-bold">{@list.name}</p>
      </div>
      <.checkbox
        id={"list-checkbox-#{@list.id}"}
        name="form[list_ids][]"
        value={@list.id}
      />
    </label>
    """
  end

  # No need to support update_many for a modal
  @impl true
  def update(assigns, socket) do
    identity = assigns.content_identity

    list_items =
      Lists.get_list_items_by_identities!([identity], actor: assigns.current_user)

    list_options =
      assigns.current_user.lists
      |> Enum.map(fn list ->
        %{list: list, already_in?: Enum.any?(list_items, &(list.id == &1.list_id))}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(list_options: list_options)}
  end

  # Adds the Content to the newly-checked lists. Already-in lists aren't
  # selectable, so this only ever adds. The bulk action broadcasts a
  # notification per list, so subscribed pages reload.
  @impl true
  def handle_event("submit", params, socket) do
    case (params["form"] && params["form"]["list_ids"]) || [] do
      [] ->
        socket.assigns.on_close.()
        {:noreply, socket}

      list_ids ->
        case Lists.add_content_to_lists(socket.assigns.content_identity, list_ids,
               actor: socket.assigns.current_user
             ) do
          {:ok, _} ->
            socket.assigns.on_close.()
            {:noreply, socket}

          {:error, error} ->
            socket.assigns.on_close.()
            Logger.warning("Error adding to lists: #{inspect(error)}")

            WatchClubWeb.Hooks.Flash.send_flash(
              :error,
              dgettext("default", "Something went wrong, try again later")
            )

            {:noreply, socket}
        end
    end
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end
end
