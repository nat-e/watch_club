defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogsLive do
  @moduledoc """
  The dialogs of the Playlists page: New playlist, and the owner's Edit, Delete and Share for the
  Playlist shown. The page renders it once and opens its dialogs with `open/2`.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.DeletePlaylistModal
  import WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.PlaylistFormModal
  import WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.SharePlaylistModal

  alias WatchClubWeb.Components.UI.IconPickerLive
  alias WatchClubWeb.Hooks.Flash

  @dom_id "playlist-dialogs"

  def dom_id, do: @dom_id

  @doc """
  Opens a dialog: `:new`, or `:edit`, `:delete` or `:share` for the Playlist shown.
  """
  def open(js \\ %JS{}, dialog) when dialog in [:new, :edit, :delete, :share],
    do: JS.push(js, "open", target: "##{@dom_id}", value: %{dialog: dialog})

  attr :playlist, Playlist, doc: "the Playlist shown, with the `user` of its `accesses`"
  attr :current_user, User, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.playlist_form_modal :if={@dialog in [:new, :edit]} form={@form} myself={@myself} />
      <.live_component
        :if={@icon_picker_open?}
        module={IconPickerLive}
        id="playlist-icon-picker"
        selected_icon={@form[:icon].value}
        title={dgettext("playlists", "Choose an icon")}
        description={dgettext("playlists", "Select an icon for your playlist")}
        on_select={JS.push("icon_selected", target: @myself)}
        on_close={JS.push("close_icon_picker", target: @myself)}
      />
      <.delete_playlist_modal
        :if={@dialog == :delete}
        playlist={@playlist}
        current_user={@current_user}
        myself={@myself}
      />
      <.share_playlist_modal
        :if={@dialog == :share}
        playlist={@playlist}
        users={@users}
        levels={@levels}
        current_user={@current_user}
        myself={@myself}
      />
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, close(socket)}

  @impl true
  def handle_event("open", %{"dialog" => "new"}, socket) do
    form =
      Playlists.form_to_create_playlist(
        params: %{"icon" => "list"},
        actor: socket.assigns.current_user
      )

    {:noreply, assign(socket, dialog: :new, form: to_form(form))}
  end

  def handle_event("open", %{"dialog" => "edit"}, socket) do
    %{playlist: playlist, current_user: user} = socket.assigns
    form = Playlists.form_to_update_playlist(playlist, actor: user)
    {:noreply, assign(socket, dialog: :edit, form: to_form(form))}
  end

  def handle_event("open", %{"dialog" => "delete"}, socket),
    do: {:noreply, assign(socket, :dialog, :delete)}

  def handle_event("open", %{"dialog" => "share"}, socket) do
    %{playlist: playlist, current_user: user} = socket.assigns

    levels = Map.new(playlist.accesses, &{&1.user_id, Atom.to_string(&1.level)})

    # Intentionally small: the instance's Users. Those who have it come first.
    users =
      [actor: user]
      |> Accounts.list_users!()
      |> Enum.reject(&(&1.id == user.id))
      |> Enum.sort_by(&{not Map.has_key?(levels, &1.id), String.downcase(&1.username)})

    {:noreply, assign(socket, dialog: :share, users: users, levels: levels)}
  end

  def handle_event("close", _params, socket), do: {:noreply, close(socket)}

  def handle_event("validate", %{"form" => params}, socket),
    do: {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}

  # A new Playlist opens once created
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, playlist} when socket.assigns.dialog == :new ->
        {:noreply, socket |> close() |> push_patch(to: ~p"/playlists/#{playlist.id}")}

      {:ok, _playlist} ->
        {:noreply, close(socket)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("open_icon_picker", _params, socket),
    do: {:noreply, assign(socket, :icon_picker_open?, true)}

  def handle_event("close_icon_picker", _params, socket),
    do: {:noreply, assign(socket, :icon_picker_open?, false)}

  def handle_event("icon_selected", %{"icon" => icon}, socket) do
    form = AshPhoenix.Form.update_params(socket.assigns.form, &Map.put(&1, "icon", icon))
    {:noreply, assign(socket, form: form, icon_picker_open?: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    Playlists.destroy_playlist!(socket.assigns.playlist, actor: socket.assigns.current_user)
    Flash.send_flash(:success, dgettext("playlists", "Playlist deleted."))
    {:noreply, socket |> close() |> push_patch(to: ~p"/playlists")}
  end

  def handle_event("choose_access", %{"levels" => levels}, socket) do
    levels = for {user_id, level} <- levels, level != "none", into: %{}, do: {user_id, level}
    {:noreply, assign(socket, :levels, levels)}
  end

  def handle_event("save_access", _params, socket) do
    %{levels: levels, playlist: playlist, current_user: user} = socket.assigns
    accesses = Enum.map(levels, fn {user_id, level} -> %{user_id: user_id, level: level} end)
    Playlists.share_playlist!(playlist, accesses, actor: user)

    Flash.send_flash(
      :success,
      if(accesses == [],
        do: dgettext("playlists", "The playlist is private."),
        else: dgettext("playlists", "Shared. It's in their Playlists now.")
      )
    )

    {:noreply, close(socket)}
  end

  defp close(socket),
    do: assign(socket, dialog: nil, form: nil, icon_picker_open?: false, users: [], levels: %{})
end
