defmodule WatchClubWeb.Components.Lists.ListDialogsLive do
  @moduledoc """
  The dialogs that create, edit or delete one of the user's lists. `WatchClubWeb.Layouts.app/1`
  renders it once, and the sidebar and pages open its dialogs with the functions below.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Lists.ListDialogs.CreateOrEditListModal
  import WatchClubWeb.Components.Lists.ListDialogs.DeleteListModal

  alias WatchClubWeb.Components.UI.IconPickerLive
  alias WatchClubWeb.Hooks.Flash

  @dom_id "list-dialogs"

  def dom_id, do: @dom_id

  def open_create_list_modal(js \\ %JS{}),
    do: JS.push(js, "open_create_list_modal", target: "##{@dom_id}")

  def open_edit_list_modal(js \\ %JS{}, %ContentList{} = list),
    do: JS.push(js, "open_edit_list_modal", target: "##{@dom_id}", value: %{list_id: list.id})

  def open_delete_list_modal(js \\ %JS{}, %ContentList{} = list),
    do: JS.push(js, "open_delete_list_modal", target: "##{@dom_id}", value: %{list_id: list.id})

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.create_or_edit_list_modal
        :if={@list_form}
        form={@list_form}
        icon={@list_icon}
        myself={@myself}
      />
      <.delete_list_modal :if={@list_to_delete} list={@list_to_delete} myself={@myself} />
      <.live_component
        :if={@list_icon_picker_open}
        module={IconPickerLive}
        id="list-icon-picker"
        selected_icon={@list_icon}
        title={dgettext("lists", "Choose an icon")}
        description={dgettext("lists", "Select an icon for your list")}
        on_select={JS.push("list_icon_selected", target: @myself)}
        on_close={JS.push("close_list_icon_picker", target: @myself)}
      />
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, reset_modals(socket)}
  end

  @impl true
  def handle_event("open_create_list_modal", _params, socket) do
    form = Lists.form_to_create_list(actor: socket.assigns.current_user)

    {:noreply, socket |> assign(list_form: to_form(form), list_icon: "list")}
  end

  def handle_event("open_edit_list_modal", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.current_user.lists, &(&1.id == list_id))
    form = Lists.form_to_update_list(list, actor: socket.assigns.current_user)

    {:noreply, socket |> assign(list_form: to_form(form), list_icon: list.icon)}
  end

  def handle_event("validate_list_form", %{"form" => params}, socket) do
    {:noreply,
     socket |> assign(:list_form, AshPhoenix.Form.validate(socket.assigns.list_form, params))}
  end

  def handle_event("submit_list_form", %{"form" => params}, socket) do
    form = socket.assigns.list_form
    edit? = form.source.type == :update

    case AshPhoenix.Form.submit(form, params: params, read_one?: true) do
      {:ok, _list} ->
        Flash.send_flash(
          :success,
          (edit? && dgettext("lists", "List updated")) || dgettext("lists", "List created")
        )

        {:noreply, socket |> reset_modals()}

      {:error, form} ->
        {:noreply, socket |> assign(:list_form, form)}
    end
  end

  def handle_event("open_list_icon_picker", _params, socket) do
    {:noreply, socket |> assign(:list_icon_picker_open, true)}
  end

  def handle_event("close_list_icon_picker", _params, socket) do
    {:noreply, socket |> assign(:list_icon_picker_open, false)}
  end

  def handle_event("list_icon_selected", %{"icon" => icon}, socket) do
    {:noreply, socket |> assign(list_icon: icon, list_icon_picker_open: false)}
  end

  def handle_event("open_delete_list_modal", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.current_user.lists, &(&1.id == list_id))

    {:noreply, socket |> assign(:list_to_delete, list)}
  end

  def handle_event("delete_list", %{"list_id" => list_id}, socket) do
    %{current_user: user} = socket.assigns
    list = Enum.find(user.lists, &(&1.id == list_id))

    Lists.destroy_list!(list, actor: user)

    Flash.send_flash(
      :success,
      dgettext("lists", "List %{list_name} deleted", list_name: list.name)
    )

    {:noreply, socket |> assign(:list_to_delete, nil)}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, reset_modals(socket)}
  end

  defp reset_modals(socket) do
    assign(socket,
      list_form: nil,
      list_to_delete: nil,
      list_icon: nil,
      list_icon_picker_open: false
    )
  end
end
