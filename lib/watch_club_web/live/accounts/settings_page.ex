defmodule WatchClubWeb.Accounts.SettingsPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      space="section"
      class="max-w-panel"
      title={dgettext("settings", "Settings")}
    >
      <.page_description text={dgettext("settings", "Manage your account preferences.")} />

      <.section
        title={dgettext("settings", "Preferences")}
        description={
          dgettext("settings", "Choose the language used across %{name}.",
            name: @instance_settings.name
          )
        }
      >
        <.form
          for={@user_settings_form}
          id="user-settings-form"
          class="w-full sm:max-w-sm"
          phx-change="validate_update_settings"
          phx-submit="submit_update_settings"
        >
          <.field
            field={@user_settings_form[:locale]}
            label={dgettext("settings", "Language")}
            class="w-full"
          >
            <:control>
              <.select
                id="user-settings-locale-select"
                field={@user_settings_form[:locale]}
                class="w-full"
              >
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
            <.button id="account-settings-submit-button" type="submit">
              {dgettext("default", "Save")}
            </.button>
          </:action>
        </.form>
      </.section>

      <.section
        title={dgettext("settings", "Security")}
        description={
          dgettext(
            "settings",
            "Change the password used to sign in. Your other devices will be signed out."
          )
        }
      >
        <.form
          for={@change_password_form}
          id="change-password-form"
          class="w-full sm:max-w-sm"
          phx-change="validate_change_password"
          phx-submit="submit_change_password"
        >
          <.field
            field={@change_password_form[:current_password]}
            label={dgettext("settings", "Current password")}
            autocomplete="current-password"
            type="password"
          />
          <.field
            field={@change_password_form[:password]}
            label={dgettext("settings", "New password")}
            autocomplete="new-password"
            type="password"
          />
          <.field
            field={@change_password_form[:password_confirmation]}
            label={dgettext("settings", "Confirm password")}
            autocomplete="new-password"
            type="password"
          />
          <:action class="sm:justify-start">
            <.button id="change-password-submit-button" type="submit">
              {dgettext("settings", "Update password")}
            </.button>
          </:action>
        </.form>
      </.section>

      <%!-- TMDB's terms require this exact notice, and their logo unaltered and less prominent than ours --%>
      <.section
        title={dgettext("settings", "About")}
        description={
          dgettext(
            "settings",
            "This product uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB."
          )
        }
      >
        <.link
          id="settings-tmdb-link"
          href="https://www.themoviedb.org"
          target="_blank"
          class="inline-flex min-h-touch-target items-center self-start"
        >
          <img src={~p"/images/tmdb/logo.svg"} alt="The Movie Database (TMDB)" class="h-icon-sm" />
        </.link>
      </.section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    settings_form = Accounts.form_to_update_user_settings(user.settings, actor: user)

    change_password_form =
      Accounts.form_to_change_password(user, actor: user, context: %{token_type: :sign_in})

    {:ok,
     socket
     |> assign(:user_settings_form, to_form(settings_form))
     |> assign(:change_password_form, to_form(change_password_form))}
  end

  @impl true
  def handle_event("validate_update_settings", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       :user_settings_form,
       AshPhoenix.Form.validate(socket.assigns.user_settings_form, params)
     )}
  end

  def handle_event("submit_update_settings", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.user_settings_form, params: params) do
      # Locale hook reloads connected LiveViews when the persisted locale changes.
      {:ok, _settings} -> {:noreply, socket}
      {:error, form} -> {:noreply, socket |> assign(:user_settings_form, form)}
    end
  end

  def handle_event("validate_change_password", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       :change_password_form,
       AshPhoenix.Form.validate(socket.assigns.change_password_form, params)
     )}
  end

  def handle_event("submit_change_password", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.change_password_form, params: params) do
      {:ok, user} ->
        # The password change revoked every token, sign the current session
        # back in with the token generated by the action
        {:noreply,
         socket
         |> put_flash(:success, dgettext("settings", "Your password has been updated"))
         |> redirect(
           to:
             ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}&return_to=#{~p"/settings"}"
         )}

      {:error, form} ->
        {:noreply, socket |> assign(:change_password_form, form)}
    end
  end
end
