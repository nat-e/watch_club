defmodule WatchClubWeb.Accounts.SettingsPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader
  import WatchClubWeb.Components.Settings.SettingsSection

  alias WatchClub.Accounts.UserLocale

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.settings_header
        title={dgettext("settings", "Settings")}
        description={dgettext("settings", "Manage your account preferences.")}
      />

      <.settings_section
        title={dgettext("settings", "Preferences")}
        description={dgettext("settings", "Choose the language used across Watch Club.")}
      >
        <.form
          for={@user_settings_form}
          class="w-full sm:max-w-sm"
          phx-submit="submit_update_settings"
        >
          <.field
            field={@user_settings_form[:locale]}
            label={dgettext("settings", "Language")}
            class="w-full"
          >
            <:control>
              <.select field={@user_settings_form[:locale]} trigger_class="w-full" class="w-full">
                <.select_item
                  :for={locale <- UserLocale.values()}
                  value={locale}
                >
                  {UserLocale.translated_label(locale)}
                </.select_item>
              </.select>
            </:control>
          </.field>
          <:action class="sm:justify-start">
            <.button type="submit">{dgettext("default", "Save")}</.button>
          </:action>
        </.form>
      </.settings_section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: user} = socket.assigns
    form = Accounts.form_to_update_user_settings(user.settings, actor: user)
    {:ok, socket |> assign(:user_settings_form, to_form(form))}
  end

  @impl true
  def handle_event("submit_update_settings", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.user_settings_form, params: params) do
      {:ok, _settings} ->
        # Locale hook reloads connected LiveViews when the persisted locale changes.
        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:user_settings_form, form)
         |> put_flash(:error, dgettext("settings", "Error updating settings"))}
    end
  end
end
