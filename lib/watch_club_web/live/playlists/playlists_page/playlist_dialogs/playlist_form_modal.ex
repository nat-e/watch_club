defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.PlaylistFormModal do
  @moduledoc """
  The dialog that creates a Playlist, or edits its name and icon: the name, next to a button that
  opens the icon picker. Owner-private to `PlaylistDialogsLive`, which handles its events.
  """
  use WatchClubWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :myself, :any, required: true

  def playlist_form_modal(assigns) do
    assigns = assign(assigns, :edit?, assigns.form.source.type == :update)

    ~H"""
    <.modal id="playlist-modal" size="md" on_close={JS.push("close", target: @myself)}>
      <:title>
        {if @edit?,
          do: dgettext("playlists", "Edit playlist"),
          else: dgettext("playlists", "New playlist")}
      </:title>
      <:description :if={!@edit?}>
        {dgettext("playlists", "It's private until you share it.")}
      </:description>

      <.form
        for={@form}
        id="playlist-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <%!-- The icon picker sets the icon, which the form carries on submit --%>
        <input type="hidden" name={@form[:icon].name} value={@form[:icon].value} />

        <.field field={@form[:name]} label={dgettext("playlists", "Name")}>
          <:control>
            <div class="flex items-center gap-related">
              <.button
                id="playlist-icon-button"
                type="button"
                variant="secondary"
                size="icon"
                class="shrink-0"
                phx-click={JS.push("open_icon_picker", target: @myself)}
                aria-label={dgettext("playlists", "Change the icon")}
              >
                <.lucide_icon name={@form[:icon].value} class="size-icon-lg" />
              </.button>
              <.input
                field={@form[:name]}
                class="flex-1"
                autocomplete="off"
                phx-debounce="blur"
                placeholder={dgettext("playlists", "My playlist")}
                phx-mounted={JS.focus()}
              />
            </div>
          </:control>
        </.field>

        <:action>
          <.button id="playlist-cancel" type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button id="playlist-submit" type="submit">
            {if @edit?, do: dgettext("default", "Save"), else: dgettext("default", "Create")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
