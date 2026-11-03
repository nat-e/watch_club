defmodule WatchClubWeb.Admin.InstanceSettingsPage do
  @moduledoc """
  Instance-administrator settings page for configuring the instance itself.
  """
  use WatchClubWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    form =
      Instance.form_to_update_instance_settings(socket.assigns.instance_settings,
        actor: socket.assigns.current_user
      )

    {:ok, assign(socket, :form, to_form(form))}
  end

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
      title={dgettext("admin_instance_settings", "Instance settings")}
    >
      <.page_description text={
        dgettext("admin_instance_settings", "Configure how your instance presents itself.")
      } />

      <.section
        title={dgettext("admin_instance_settings", "General")}
        description={
          dgettext(
            "admin_instance_settings",
            "The name shown across the app, in the browser tab, and in invitations."
          )
        }
      >
        <.form
          for={@form}
          id="instance-settings-form"
          class="w-full sm:max-w-sm"
          phx-change="validate_instance_settings"
          phx-submit="submit_instance_settings"
        >
          <.field
            field={@form[:name]}
            label={dgettext("admin_instance_settings", "Instance name")}
            type="text"
            class="w-full"
          />
          <:action class="sm:justify-start">
            <.button id="instance-settings-submit-button" type="submit">
              {dgettext("default", "Save")}
            </.button>
          </:action>
        </.form>
      </.section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate_instance_settings", %{"form" => params}, socket) do
    {:noreply, socket |> assign(:form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_instance_settings", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, instance_settings} ->
        {:noreply,
         socket
         |> assign(:instance_settings, instance_settings)
         |> put_flash(:info, dgettext("admin_instance_settings", "Instance settings updated."))}

      {:error, form} ->
        {:noreply, socket |> assign(:form, form)}
    end
  end
end
