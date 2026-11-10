defmodule WatchClubWeb.Admin.MediaSources.AddServarrSourceModal do
  @moduledoc """
  Stateful modal for creating or editing a Servarr (Radarr / Sonarr / Sportarr)
  `Media Source`. The `:flavor` assign (`:radarr` | `:sonarr` | `:sportarr`) drives the
  product name, logo, and copy; the flow is identical for all.

  In create mode the modal drives a three-step wizard backed by the
  in-memory `Servarr.Wizard` resource:

    1. `:connection`      — base URL + API key (validated by fetching the
                            server's status, then loads its quality
                            profiles and root folders)
    2. `:request_profile` — pick quality profile and root folder
    3. `:webhook`         — webhook callback URL (validated by asking the
                            server to fire a `Test` event)

  Each step's form is an `AshPhoenix.Form` over the wizard's matching
  `:configure_*` update action. On final step submit the wizard transitions
  to `:finished` and the LiveComponent hands its attributes to
  `MediaSources.create_servarr_media_source/2`.

  In edit mode the wizard starts at `:connection` with the saved source's
  values (`for_edit`), and the final step hands its attributes to
  `MediaSources.update_servarr_media_source/3`.
  """
  use WatchClubWeb, :live_component

  alias AshPhoenix.Form
  alias WatchClub.MediaSources.Servarr.{Flavor, Wizard}
  alias WatchClubWeb.Endpoint

  @impl true
  def update(assigns, socket) do
    socket =
      assign(socket,
        id: assigns.id,
        mode: assigns.mode,
        flavor: assigns.flavor,
        current_user: assigns.current_user,
        instance_settings: assigns.instance_settings
      )

    if Map.has_key?(socket.assigns, :form) do
      {:ok, socket}
    else
      {:ok, initialize(assigns, socket)}
    end
  end

  defp initialize(%{mode: :create, flavor: flavor}, socket) do
    actor = socket.assigns.current_user
    {:ok, wizard} = MediaSources.create_servarr_wizard_for_create(flavor, actor: actor)

    socket
    |> assign(:wizard, wizard)
    |> assign(:form, form_for_wizard(wizard, actor))
  end

  defp initialize(%{mode: :edit, media_source: %Source{} = media_source}, socket) do
    actor = socket.assigns.current_user
    {:ok, wizard} = MediaSources.create_servarr_wizard_for_edit(media_source, actor: actor)

    socket
    |> assign(:media_source, media_source)
    |> assign(:wizard, wizard)
    |> assign(:form, form_for_wizard(wizard, actor))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal id="add-servarr-source-modal" size="lg" on_close={JS.push("close", target: @myself)}>
        <:title>
          <span class="inline-flex items-center gap-related">
            <img
              src={"/images/source_types/#{@flavor}.svg"}
              alt={"#{app_name(@flavor)} logo"}
              class="size-icon"
            />
            {title(assigns)}
          </span>
        </:title>
        <:description>{description(assigns)}</:description>

        <.form
          for={@form}
          id="add-servarr-form"
          phx-change="validate"
          phx-submit="submit"
          phx-target={@myself}
        >
          <.wizard_step_form
            wizard={@wizard}
            form={@form}
            flavor={@flavor}
            myself={@myself}
            instance_settings={@instance_settings}
          />

          <:action>
            <.wizard_step_actions mode={@mode} wizard={@wizard} form={@form} myself={@myself} />
          </:action>
        </.form>
      </.modal>
    </div>
    """
  end

  # ── EVENT HANDLERS ────────────────────────────────────────────────

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    submit_wizard_step(socket, params)
  end

  def handle_event("back", _params, socket) do
    actor = socket.assigns.current_user

    {:ok, wizard} =
      MediaSources.servarr_wizard_back_to_previous_step(socket.assigns.wizard, actor: actor)

    {:noreply,
     socket
     |> assign(:wizard, wizard)
     |> assign(:form, form_for_wizard(wizard, actor))}
  end

  def handle_event("close", _params, socket) do
    send(self(), :close_servarr_source_modal)
    {:noreply, socket}
  end

  defp submit_wizard_step(socket, params) do
    actor = socket.assigns.current_user
    mode = socket.assigns.mode

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, %Wizard{step: :finished} = wizard} when mode == :create ->
        create_media_source(socket, wizard)

      {:ok, %Wizard{step: :finished} = wizard} when mode == :edit ->
        edit_media_source(socket, wizard)

      {:ok, %Wizard{} = wizard} ->
        {:noreply,
         socket
         |> assign(:wizard, wizard)
         |> assign(:form, form_for_wizard(wizard, actor))}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp create_media_source(socket, %Wizard{} = wizard) do
    input = Map.put(wizard_to_input(wizard), :flavor, socket.assigns.flavor)

    case MediaSources.create_servarr_media_source(input, actor: socket.assigns.current_user) do
      {:ok, _media_source} ->
        send(self(), {:servarr_source_saved, :create})
        {:noreply, socket}

      {:error, _error} ->
        send(self(), :servarr_source_save_failed)
        {:noreply, socket}
    end
  end

  defp edit_media_source(socket, %Wizard{} = wizard) do
    impl = socket.assigns.media_source.implementation

    case MediaSources.update_servarr_media_source(impl, wizard_to_input(wizard),
           actor: socket.assigns.current_user
         ) do
      {:ok, _impl} ->
        send(self(), {:servarr_source_saved, :edit})
        {:noreply, socket}

      {:error, _error} ->
        send(self(), :servarr_source_save_failed)
        {:noreply, socket}
    end
  end

  defp wizard_to_input(%Wizard{} = wizard) do
    %{
      base_url: wizard.base_url,
      api_key: wizard.api_key,
      quality_profile_id: wizard.selected_quality_profile_id,
      quality_profile_name: selected_profile_name(wizard),
      root_folder_path: wizard.selected_root_path,
      local_root_folder_path: wizard.local_root_folder_path,
      webhook_callback_base_url: wizard.webhook_callback_base_url
    }
  end

  # ── FORM CONSTRUCTORS ─────────────────────────────────────────────

  defp form_for_wizard(%Wizard{step: :connection} = wizard, actor) do
    Form.for_update(wizard, :configure_connection, actor: actor) |> to_form()
  end

  defp form_for_wizard(%Wizard{step: :request_profile} = wizard, actor) do
    Form.for_update(wizard, :configure_request_profile, actor: actor)
    |> to_form()
  end

  defp form_for_wizard(%Wizard{step: :webhook} = wizard, actor) do
    params = %{"webhook_callback_base_url" => wizard.webhook_callback_base_url || Endpoint.url()}

    Form.for_update(wizard, :configure_webhook, actor: actor, params: params)
    |> to_form()
  end

  # ── STEP COPY ─────────────────────────────────────────────────────

  defp app_name(flavor), do: Flavor.label(flavor)

  defp title(%{wizard: %Wizard{step: step}, flavor: flavor}), do: step_title(step, flavor)

  defp description(%{
         wizard: %Wizard{step: step},
         flavor: flavor,
         instance_settings: instance_settings
       }),
       do: step_description(step, flavor, instance_settings.name)

  defp step_title(:connection, flavor),
    do: dgettext("admin_media_imports", "Connect %{name} Server", name: app_name(flavor))

  defp step_title(:request_profile, _flavor),
    do: dgettext("admin_media_imports", "Configure Source")

  defp step_title(:webhook, _flavor),
    do: dgettext("admin_media_imports", "Verify Webhooks")

  defp step_title(_, _flavor), do: ""

  defp step_description(:connection, flavor, _instance_name),
    do:
      dgettext("admin_media_imports", "Enter the credentials to connect to your %{name} server.",
        name: app_name(flavor)
      )

  defp step_description(:request_profile, _flavor, instance_name),
    do:
      dgettext(
        "admin_media_imports",
        "Select the quality profile and root folder that %{instance} will use when requesting media.",
        instance: instance_name
      )

  defp step_description(:webhook, flavor, instance_name),
    do:
      dgettext(
        "admin_media_imports",
        "%{name} will POST events to %{instance} at the URL below. Submitting will verify the URL is reachable.",
        name: app_name(flavor),
        instance: instance_name
      )

  defp step_description(_, _flavor, _instance_name), do: ""

  # ── STEP RENDER ───────────────────────────────────────────────────

  attr :wizard, Wizard, required: true
  attr :form, :map, required: true
  attr :flavor, :atom, required: true
  attr :myself, :any, required: true
  attr :instance_settings, InstanceSettings, required: true

  defp wizard_step_form(%{wizard: %Wizard{step: :connection}} = assigns) do
    ~H"""
    <.field
      field={@form[:base_url]}
      label={dgettext("admin_media_imports", "%{name} URL", name: app_name(@flavor))}
      inputmode="url"
      autocapitalize="none"
      autocorrect="off"
      spellcheck="false"
      input_class="font-mono"
      placeholder={connection_url_placeholder(@flavor)}
      autocomplete="off"
    >
      <:hint>
        {dgettext("admin_media_imports", "The base URL to reach %{name} from %{instance}.",
          name: app_name(@flavor),
          instance: @instance_settings.name
        )}
      </:hint>
    </.field>

    <.field
      field={@form[:api_key]}
      label={dgettext("admin_media_imports", "API Key")}
      type="password"
      input_class="font-mono"
      placeholder="a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
      autocomplete="off"
    >
      <:hint>
        {dgettext(
          "admin_media_imports",
          "Your %{name} API key. You can find it in %{name}'s settings > General.",
          name: app_name(@flavor)
        )}
      </:hint>
    </.field>
    """
  end

  defp wizard_step_form(%{wizard: %Wizard{step: :request_profile} = wizard} = assigns) do
    assigns =
      assigns
      |> assign(:profiles, wizard.quality_profiles)
      |> assign(:root_folders, wizard.root_folders)

    ~H"""
    <.field
      field={@form[:selected_quality_profile_id]}
      label={dgettext("admin_media_imports", "Quality Profile")}
    >
      <:hint>
        {dgettext(
          "admin_media_imports",
          "The quality profile to use for making requests from this source."
        )}
      </:hint>
      <:control :let={describedby}>
        <.radio_group
          field={@form[:selected_quality_profile_id]}
          variant="card"
          class="grid grid-cols-1 gap-related sm:grid-cols-2"
          aria-describedby={describedby}
        >
          <:item
            :for={profile <- @profiles}
            value={to_string(profile["id"])}
            class="flex items-center gap-tight px-related py-tight"
          >
            <Lucideicons.sparkles class="size-icon-sm text-text-muted" />
            <span class="text-sm">{profile["name"]}</span>
            <Lucideicons.check class="ml-auto size-icon-sm text-accent opacity-0 transition-opacity group-has-checked/radio-card:opacity-100" />
          </:item>
        </.radio_group>
      </:control>
    </.field>

    <.field
      field={@form[:selected_root_path]}
      label={dgettext("admin_media_imports", "Root folder")}
    >
      <:hint>
        {dgettext(
          "admin_media_imports",
          "The root folder to use for making requests and importing data from this source."
        )}
      </:hint>
      <:control :let={describedby}>
        <.radio_group
          field={@form[:selected_root_path]}
          variant="card"
          class="grid-cols-1 gap-tight"
          aria-describedby={describedby}
        >
          <:item
            :for={path <- @root_folders}
            value={path}
            class="flex items-center gap-related px-related py-tight"
          >
            <Lucideicons.folder class="size-icon-sm shrink-0 text-text-muted" />
            <span class="truncate font-mono text-sm text-text">{path}</span>
            <Lucideicons.check class="ml-auto size-icon-sm text-accent opacity-0 transition-opacity group-has-checked/radio-card:opacity-100" />
          </:item>
        </.radio_group>
      </:control>
    </.field>

    <.field
      field={@form[:local_root_folder_path]}
      label={dgettext("admin_media_imports", "Path mapping (Optional)")}
      type="text"
      input_class="font-mono"
      placeholder={@wizard.selected_root_path}
    >
      <:hint>
        {dgettext(
          "admin_media_imports",
          "The root folder path must be accessible directly by %{instance} for playback. If the mounts are different, enter the path to the root folder from %{instance} file system.",
          instance: @instance_settings.name
        )}
      </:hint>
    </.field>
    """
  end

  defp wizard_step_form(%{wizard: %Wizard{step: :webhook}} = assigns) do
    ~H"""
    <.field
      field={@form[:webhook_callback_base_url]}
      label={
        dgettext("admin_media_imports", "%{instance} URL %{name} will call",
          name: app_name(@flavor),
          instance: @instance_settings.name
        )
      }
      inputmode="url"
      autocapitalize="none"
      autocorrect="off"
      spellcheck="false"
      input_class="font-mono"
      placeholder="http://host.docker.internal:4000"
      autocomplete="off"
    >
      <:hint>
        {dgettext(
          "admin_media_imports",
          "Use the address %{name} can reach from its network. In Docker setups this is usually different from your browser URL.",
          name: app_name(@flavor)
        )}
      </:hint>
    </.field>
    """
  end

  attr :mode, :atom, required: true
  attr :wizard, :any, required: true
  attr :form, :map, required: true
  attr :myself, :any, required: true

  defp wizard_step_actions(%{wizard: %Wizard{step: :connection}} = assigns) do
    ~H"""
    <.button id="servarr-wizard-connection-cancel" type="button" variant="secondary" data-modal-close>
      {dgettext("default", "Cancel")}
    </.button>
    <.button
      id="servarr-wizard-connection-submit"
      type="submit"
      variant="primary"
      phx-disable-with={dgettext("admin_media_imports", "Connecting…")}
    >
      {dgettext("admin_media_imports", "Connect")}
    </.button>
    """
  end

  defp wizard_step_actions(%{wizard: %Wizard{step: :request_profile}} = assigns) do
    ~H"""
    <.button
      id="servarr-wizard-request-profile-back"
      type="button"
      variant="secondary"
      phx-click="back"
      phx-target={@myself}
    >
      <:icon position="start"><Lucideicons.arrow_left class="size-icon-sm" /></:icon>
      {dgettext("default", "Back")}
    </.button>
    <.button id="servarr-wizard-request-profile-submit" type="submit" variant="primary">
      {dgettext("admin_media_imports", "Continue")}
    </.button>
    """
  end

  defp wizard_step_actions(%{wizard: %Wizard{step: :webhook}, mode: :edit} = assigns) do
    ~H"""
    <.button
      id="servarr-wizard-webhook-edit-back"
      type="button"
      variant="secondary"
      phx-click="back"
      phx-target={@myself}
    >
      <:icon position="start"><Lucideicons.arrow_left class="size-icon-sm" /></:icon>
      {dgettext("default", "Back")}
    </.button>
    <.button
      id="servarr-wizard-webhook-edit-submit"
      type="submit"
      variant="primary"
      phx-disable-with={dgettext("admin_media_imports", "Verifying…")}
    >
      {dgettext("admin_media_imports", "Save changes")}
    </.button>
    """
  end

  defp wizard_step_actions(%{wizard: %Wizard{step: :webhook}} = assigns) do
    ~H"""
    <.button
      id="servarr-wizard-webhook-back"
      type="button"
      variant="secondary"
      phx-click="back"
      phx-target={@myself}
    >
      <:icon position="start"><Lucideicons.arrow_left class="size-icon-sm" /></:icon>
      {dgettext("default", "Back")}
    </.button>
    <.button
      id="servarr-wizard-webhook-submit"
      type="submit"
      variant="primary"
      phx-disable-with={dgettext("admin_media_imports", "Verifying…")}
    >
      {dgettext("admin_media_imports", "Add Source")}
    </.button>
    """
  end

  # ── HELPERS ───────────────────────────────────────────────────────

  defp connection_url_placeholder(:radarr), do: "http://radarr:7878"
  defp connection_url_placeholder(:sonarr), do: "http://sonarr:8989"
  defp connection_url_placeholder(:sportarr), do: "http://sportarr:1867"

  defp selected_profile_name(%Wizard{
         quality_profiles: profiles,
         selected_quality_profile_id: id
       })
       when not is_nil(id) do
    Enum.find_value(profiles, fn p ->
      if p["id"] == id, do: p["name"]
    end)
  end

  defp selected_profile_name(_), do: nil
end
