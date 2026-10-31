defmodule WatchClubWeb.Lists.ListPage do
  use WatchClubWeb, :live_view

  alias WatchClub.Shared.SortOrder

  import WatchClubWeb.Components.Contents.ContentCard

  alias WatchClubWeb.Components.Contents.{
    AddToLibraryModalLive,
    AddToListModalLive,
    PlayOrRequestButtonLive
  }

  alias WatchClubWeb.Helpers.KeysetStreamState

  @contents_page_size 40

  # We keep a map of valid sort options string to atoms so that they
  # can be parsed from untrusted URL parameters without creating atoms
  # which will never be removed from memory
  @sort_options [:added_date, :release_date, :title]
  @sort_options_map Map.new(@sort_options, &{Atom.to_string(&1), &1})

  @list_item_fields_to_load [content: [:implementation, :actor_progress_status]]

  @impl true
  def mount(_params, _session, socket) do
    # The `user:<id>` topic (where List/ListItem notifications are published) is
    # already subscribed for us by the Auth on_mount hook. Here we only need the
    # content topics that drive the play/request buttons.
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:list_items, dom_id: & &1.id)
     |> reset_modals()}
  end

  @impl true
  def handle_params(%{"list_id" => list_id} = params, _uri, socket) do
    with {sort_by, sort_order} <- parse_sort_param(params["sort"]),
         {:ok, list} <- Lists.get_list_by_id(list_id, actor: socket.assigns.current_user) do
      {:noreply,
       socket
       |> assign(sort_by: sort_by, sort_order: sort_order, list: list)
       # A sort change re-runs handle_params: reset the keyset cursor so we
       # reload from the first page and reset the stream.
       |> assign(:stream_state, KeysetStreamState.init(@contents_page_size))
       |> load_list_items_page()}
    else
      :invalid_params ->
        {:noreply, socket |> push_patch(to: Url.list_link(list_id))}

      {:error, error} ->
        Logger.warning("Error loading list page: #{inspect(error)}")

        {:noreply,
         socket
         |> put_flash(:error, dgettext("lists", "The list you were looking for does not exist"))
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def render(%{list: %ContentList{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      class="p-2!"
      space="none"
    >
      <.stack space="group" class="w-full @container">
        <.stack space="related">
          <.inline space="related">
            <.lucide_icon name={@list.icon} class="size-icon-lg shrink-0 text-text-muted" />
            <h1 class="min-w-0 flex-1 truncate text-3xl font-bold">{@list.name}</h1>
          </.inline>
          <.list_sort_controls
            list_id={@list.id}
            current_sort_by={@sort_by}
            current_sort_order={@sort_order}
          />
        </.stack>

        <div
          id="list-content-stream"
          phx-update="stream"
          class="grid grid-cols-[repeat(auto-fill,minmax(10rem,1fr))] @5xl:grid-cols-[repeat(auto-fill,minmax(11rem,1fr))] gap-group"
        >
          <div id="list-content-empty" class="only:block hidden col-span-full">
            <.empty>
              <:icon><.lucide_icon name={@list.icon} /></:icon>
              <:title>{dgettext("lists", "This list is empty")}</:title>
              <:description>
                {dgettext("lists", "Add movies, shows and books to this list to see them here.")}
              </:description>
            </.empty>
          </div>

          <.content_card
            :for={{dom_id, list_item} <- @streams.list_items}
            id={dom_id}
            content={list_item.content}
            list_item={list_item}
            current_user={@current_user}
          />
        </div>

        <.infinite_scroll_trigger
          :if={KeysetStreamState.can_load_more?(@stream_state)}
          id="list-content-load-more"
          event="load_more_contents"
        />
      </.stack>

      <.live_component
        :if={@content_to_add_to_library}
        id="list-page-add-to-library-modal"
        module={AddToLibraryModalLive}
        content_identity={ContentIdentity.from_content(@content_to_add_to_library)}
        content_title={@content_to_add_to_library.implementation.best_localization.title}
        current_user={@current_user}
        on_close={fn -> send(self(), "close_add_to_library_modal") end}
      />

      <.live_component
        :if={@content_to_add_to_list}
        id="list-page-add-to-list-modal"
        module={AddToListModalLive}
        content_identity={ContentIdentity.from_content(@content_to_add_to_list)}
        content_title={@content_to_add_to_list.implementation.best_localization.title}
        current_user={@current_user}
        on_close={fn -> send(self(), "close_add_to_list_modal") end}
      />
    </Layouts.app>
    """
  end

  @impl true
  # The List was deleted, navigate back to the home page
  def handle_info(
        %Notification{data: %ContentList{id: list_id}, action: %{name: :destroy}},
        socket
      )
      when list_id == socket.assigns.list.id do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("lists", "The list was deleted"))
     |> push_navigate(to: ~p"/")}
  end

  # A Content was removed from the list. stream_delete is a no-op when the item
  # belongs to one of the user's other lists, so no list_id check is needed.
  def handle_info(
        %Notification{data: %ListItem{} = list_item, action: %{type: :destroy}},
        socket
      ) do
    {:noreply, socket |> stream_delete(:list_items, list_item)}
  end

  # A Content was added to a list. Insert it at the top (matching the default
  # added-date-descending sort) when it lands in the list currently displayed.
  def handle_info(
        %Notification{
          data: %ListItem{list_id: list_id},
          action: %{type: :create},
          metadata: %{content_id: content_id}
        },
        socket
      ) do
    if list_id == socket.assigns.list.id do
      list_item =
        Lists.get_list_item!(list_id, content_id,
          load: @list_item_fields_to_load,
          actor: socket.assigns.current_user
        )

      {:noreply, socket |> stream_insert(:list_items, list_item, at: 0)}
    else
      {:noreply, socket}
    end
  end

  # A content has changed: reload the list item and update it in place.
  def handle_info(%Notification{resource: resource, data: data, metadata: metadata}, socket)
      when resource in [Content, WatchProgress] do
    content_id =
      case data do
        %Content{id: id} -> id
        %WatchProgress{} -> metadata.content_id
      end

    case Lists.get_list_item(socket.assigns.list.id, content_id,
           load: @list_item_fields_to_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, list_item} ->
        {:noreply, socket |> stream_insert(:list_items, list_item, update_only: true)}

      # Ignore the message if the content is not in this list
      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_info("close_add_to_library_modal", socket) do
    {:noreply, socket |> assign(content_to_add_to_library: nil)}
  end

  def handle_info("close_add_to_list_modal", socket) do
    {:noreply, socket |> assign(content_to_add_to_list: nil)}
  end

  def handle_info(message, socket) do
    # Send updates to all the Live Components we are using on the content cards
    PlayOrRequestButtonLive.handle_pubsub_message(message, socket.assigns.current_user)

    {:noreply, socket}
  end

  attr :current_sort_by, :atom, required: true
  attr :current_sort_order, :atom, required: true
  attr :list_id, :string, required: true

  defp list_sort_controls(assigns) do
    ~H"""
    <div
      role="group"
      aria-label={dgettext("lists", "List sort order")}
      class="flex flex-wrap items-center justify-end gap-tight"
    >
      <.sort_toggle_button
        list_id={@list_id}
        current_sort_by={@current_sort_by}
        current_sort_order={@current_sort_order}
        sort_by={:title}
        default_order={:asc}
        asc_icon={:arrow_down_a_z}
        desc_icon={:arrow_down_z_a}
        label={dgettext("lists", "Title")}
      />
      <.sort_toggle_button
        list_id={@list_id}
        current_sort_by={@current_sort_by}
        current_sort_order={@current_sort_order}
        sort_by={:added_date}
        default_order={:desc}
        asc_icon={:calendar_arrow_down}
        desc_icon={:calendar_arrow_up}
        label={dgettext("lists", "Added date")}
      />
      <.sort_toggle_button
        list_id={@list_id}
        current_sort_by={@current_sort_by}
        current_sort_order={@current_sort_order}
        sort_by={:release_date}
        default_order={:desc}
        asc_icon={:calendar_arrow_down}
        desc_icon={:calendar_arrow_up}
        label={dgettext("lists", "Release date")}
      />
    </div>
    """
  end

  attr :current_sort_by, :atom, required: true
  attr :current_sort_order, :atom, required: true
  attr :sort_by, :atom, required: true
  attr :default_order, :atom, required: true
  attr :asc_icon, :atom, required: true
  attr :desc_icon, :atom, required: true
  attr :label, :string, required: true
  attr :list_id, :string, required: true

  defp sort_toggle_button(assigns) do
    active? = assigns.current_sort_by == assigns.sort_by

    target_sort_order =
      if active? do
        SortOrder.switch(assigns.current_sort_order)
      else
        assigns.default_order
      end

    target_icon =
      if active? do
        case assigns.current_sort_order do
          :asc -> assigns.asc_icon
          :desc -> assigns.desc_icon
        end
      else
        case target_sort_order do
          :asc -> assigns.asc_icon
          :desc -> assigns.desc_icon
        end
      end

    assigns =
      assigns
      |> assign(:active?, active?)
      |> assign(:target_sort_order, target_sort_order)
      |> assign(:target_icon, target_icon)

    ~H"""
    <.button
      id={"list-sort-#{@sort_by}-button"}
      patch={list_sort_path(@list_id, @sort_by, @target_sort_order)}
      replace
      variant={(@active? && "accent") || "secondary"}
      aria-pressed={to_string(@active?)}
      aria-label={
        dgettext("lists", "Sort by %{field} %{order}",
          field: @label,
          order: SortOrder.translated_label(@target_sort_order)
        )
      }
    >
      <:icon position="start">
        <Lucideicons.render name={@target_icon} />
      </:icon>
      {@label}
    </.button>
    """
  end

  @impl true
  def handle_event("load_more_contents", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.stream_state) do
      {:noreply, load_list_items_page(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_list_item", %{"content_id" => content_id}, socket) do
    Lists.get_list_item!(socket.assigns.list.id, content_id, actor: socket.assigns.current_user)
    |> Lists.destroy_list_item!(actor: socket.assigns.current_user)

    # The item is removed from the stream reactively through the PubSub notification
    {:noreply, socket |> put_flash(:success, dgettext("lists", "Removed from list"))}
  end

  def handle_event("open_add_to_library_modal", %{"content_id" => content_id}, socket) do
    {:noreply,
     socket
     |> assign(
       content_to_add_to_library:
         Contents.get_content_by_id!(content_id,
           load: [:implementation],
           actor: socket.assigns.current_user
         )
     )}
  end

  def handle_event("open_add_to_list_modal", %{"content_id" => content_id}, socket) do
    {:noreply,
     socket
     |> assign(
       content_to_add_to_list:
         Contents.get_content_by_id!(content_id,
           load: [:implementation],
           actor: socket.assigns.current_user
         )
     )}
  end

  defp load_list_items_page(socket) do
    stream_state = socket.assigns[:stream_state] || KeysetStreamState.init(@contents_page_size)

    %{list: list, sort_by: sort_by, sort_order: sort_order, current_user: current_user} =
      socket.assigns

    {:ok, new_state, items} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        Lists.get_list_items(list.id,
          query: [
            load: @list_item_fields_to_load,
            sort: sort_list_items_query(sort_by, sort_order)
          ],
          page: page_options,
          actor: current_user
        )
      end)

    socket
    |> assign(:stream_state, new_state)
    |> stream(:list_items, items, reset: stream_state.status == :init)
  end

  defp list_sort_path(list_id, sort_by, sort_order) do
    ~p"/lists/#{list_id}?#{[sort: "#{Atom.to_string(sort_by)}.#{Atom.to_string(sort_order)}"]}"
  end

  defp reset_modals(socket) do
    socket |> assign(content_to_add_to_library: nil, content_to_add_to_list: nil)
  end

  # Parses the field and direction on which to sort the list items, based on the
  # value of the URL parameters
  defp parse_sort_param(param) when is_nil(param), do: {:added_date, :desc}

  defp parse_sort_param(param) when is_binary(param) do
    with [sort_by_param, sort_order_param] <- String.split(param, ".", parts: 2),
         {:ok, sort_by} <- Map.fetch(@sort_options_map, sort_by_param),
         {:ok, sort_order} <- SortOrder.parse_param(sort_order_param) do
      {sort_by, sort_order}
    else
      _ -> :invalid_params
    end
  end

  defp sort_list_items_query(:added_date, sort_order) do
    [{:created_at, sort_order}]
  end

  defp sort_list_items_query(:release_date, sort_order) do
    [{"content.release_date", SortOrder.nils_last(sort_order)}]
  end

  defp sort_list_items_query(:title, sort_order) do
    [{"content.localized_title_key", SortOrder.nils_last(sort_order)}]
  end
end
