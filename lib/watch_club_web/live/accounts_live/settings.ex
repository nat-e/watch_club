defmodule WatchClubWeb.AccountsLive.Settings do
  use WatchClubWeb, :live_view

  alias WatchClub.Accounts.UserLocale

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <h1>{dgettext("settings", "Settings")}</h1>
      <.form
        for={@user_settings_form}
        class="max-w-80 flex flex-col items-end gap-4"
        phx-submit="submit_update_settings"
      >
        <.input_with_label
          field={@user_settings_form[:locale]}
          label={dgettext("settings", "Language")}
          class="w-full"
        >
          <.select field={@user_settings_form[:locale]} trigger_class="w-full" class="w-full">
            <.select_item
              :for={locale <- UserLocale.values()}
              value={locale}
            >
              {UserLocale.translated_label(locale)}
            </.select_item>
          </.select>
        </.input_with_label>
        <.button type="submit">{dgettext("default", "Save")}</.button>
      </.form>
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
        # Reload the page to apply the new locale
        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:user_settings_form, form)
         |> put_flash(:error, dgettext("settings", "Error updating settings"))}
    end
  end
end
