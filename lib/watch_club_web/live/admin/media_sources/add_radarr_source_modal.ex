defmodule WatchClubWeb.Admin.MediaSources.AddRadarrSourceModal do
  @moduledoc """
  Stateful modal for creating or editing a Radarr `Media Source`.

  The component owns the two-step Radarr wizard state:

    1. `Connect Radarr Server` — capture URL + API key and load quality
       profiles/root folders from the live Radarr server.
    2. `Configure Source` — pick the quality profile and root folder plus an
       optional path mapping, then create or update the Media Source.

  The parent LiveView remains the source of truth for the Media Source list;
  this component notifies it when the modal closes or the source is saved.
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Integrations.Radarr.Connection
  alias WatchClub.Media
  alias WatchClub.Media.MediaSource

  defmodule Wizard do
    @moduledoc false

    alias Phoenix.Component
    alias WatchClub.Integrations.Radarr.Connection
    alias WatchClub.Media.MediaSource
    alias WatchClub.Shared.Url

    defstruct [
      :mode,
      :media_source,
      :step,
      :form,
      :connection,
      :connect_error,
      :profiles_load_ref,
      :configuration,
      :wizard_id,
      :callback_base_url,
      :webhook_test_ref,
      :webhook_error,
      testing?: false,
      webhook_state: :unverified
    ]

    def create(default_callback_base_url) do
      %__MODULE__{
        mode: :create,
        step: :connect,
        form: radarr_form(%{"base_url" => "", "api_key" => ""}),
        wizard_id: Ash.UUIDv7.generate(),
        callback_base_url: default_callback_base_url
      }
    end

    def edit(%MediaSource{source_type: :radarr} = media_source, default_callback_base_url) do
      impl = media_source.implementation

      %__MODULE__{
        mode: :edit,
        media_source: media_source,
        step: :configure,
        form: radarr_form(existing_configuration_params(impl)),
        connection: %Connection{
          base_url: impl.base_url,
          api_key: impl.api_key,
          profiles: [],
          root_folders: []
        },
        wizard_id: media_source.id,
        callback_base_url: impl.webhook_callback_base_url || default_callback_base_url,
        webhook_state: :verified
      }
    end

    def validate_connection(%__MODULE__{} = wizard, params) do
      %{wizard | form: radarr_form(params), connect_error: nil}
    end

    def prepare_connection_test(%__MODULE__{} = wizard, params) do
      base_url = String.trim(params["base_url"] || "")
      api_key = params["api_key"] || ""
      wizard = %{wizard | form: radarr_form(params)}

      cond do
        base_url == "" or api_key == "" ->
          {:error, %{wizard | connect_error: :missing_credentials}}

        true ->
          {:ok, %{wizard | connect_error: nil}, base_url, api_key}
      end
    end

    def back_to_connection_step(%__MODULE__{} = wizard) do
      {base_url, api_key} =
        case wizard.connection do
          %Connection{base_url: url, api_key: key} -> {url, key}
          _ -> {"", ""}
        end

      %{
        wizard
        | step: :connect,
          form: radarr_form(%{"base_url" => base_url, "api_key" => api_key}),
          connection: nil,
          connect_error: nil,
          testing?: false,
          profiles_load_ref: nil,
          webhook_state: :unverified,
          webhook_error: nil,
          webhook_test_ref: nil
      }
    end

    def advance_to_webhook_step(%__MODULE__{} = wizard, configuration) do
      %{
        wizard
        | step: :webhook,
          configuration: configuration,
          form: radarr_form(%{"webhook_callback_base_url" => wizard.callback_base_url || ""}),
          webhook_state: :unverified,
          webhook_error: nil
      }
    end

    def back_to_configure_step(%__MODULE__{} = wizard) do
      %{
        wizard
        | step: :configure,
          form: radarr_form(configure_params_from_state(wizard)),
          webhook_state: :unverified,
          webhook_error: nil,
          webhook_test_ref: nil
      }
    end

    defp configure_params_from_state(%__MODULE__{configuration: nil} = wizard) do
      configuration_params(wizard, wizard.connection)
    end

    defp configure_params_from_state(%__MODULE__{configuration: config}) do
      %{
        "quality_profile_id" =>
          if(config.quality_profile_id, do: to_string(config.quality_profile_id), else: nil),
        "root_folder_path" => config.root_folder_path,
        "local_root_folder_path" => config.local_root_folder_path || ""
      }
    end

    def validate_webhook(%__MODULE__{} = wizard, params) do
      callback = String.trim(params["webhook_callback_base_url"] || "")

      state =
        cond do
          callback == "" -> :unverified
          callback == wizard.callback_base_url -> wizard.webhook_state
          true -> :unverified
        end

      %{
        wizard
        | form: radarr_form(params),
          callback_base_url: callback,
          webhook_state: state,
          webhook_error: nil
      }
    end

    def begin_webhook_test(%__MODULE__{} = wizard, ref) do
      %{wizard | webhook_state: :testing, webhook_error: nil, webhook_test_ref: ref}
    end

    def cancel_webhook_test(%__MODULE__{} = wizard) do
      %{wizard | webhook_state: :unverified, webhook_test_ref: nil}
    end

    def apply_webhook_test_result(%__MODULE__{webhook_test_ref: current_ref}, ref, _result)
        when current_ref != ref do
      :stale
    end

    def apply_webhook_test_result(%__MODULE__{} = wizard, _ref, {:ok, {:ok, :verified}}) do
      {:ok, %{wizard | webhook_state: :verified, webhook_error: nil, webhook_test_ref: nil}}
    end

    def apply_webhook_test_result(%__MODULE__{} = wizard, _ref, {:ok, {:error, reason}}) do
      {:ok, %{wizard | webhook_state: :failed, webhook_error: reason, webhook_test_ref: nil}}
    end

    def apply_webhook_test_result(%__MODULE__{} = wizard, _ref, {:exit, {:shutdown, :cancel}}) do
      {:ok, cancel_webhook_test(wizard)}
    end

    def apply_webhook_test_result(%__MODULE__{} = wizard, _ref, {:exit, reason}) do
      {:ok,
       %{
         wizard
         | webhook_state: :failed,
           webhook_error: {:transport_error, reason},
           webhook_test_ref: nil
       }}
    end

    def webhook_test_ref(%__MODULE__{webhook_test_ref: ref}), do: ref

    def ready_to_submit?(%__MODULE__{webhook_state: :verified}), do: true
    def ready_to_submit?(_), do: false

    def callback_url(%__MODULE__{callback_base_url: base, wizard_id: id})
        when is_binary(base) and is_binary(id) do
      Url.webhook_callback_url(base, :radarr, id)
    end

    def callback_url(_), do: nil

    def validate_configuration(%__MODULE__{} = wizard, params) do
      %{wizard | form: radarr_form(params)}
    end

    def configuration_input(%__MODULE__{connection: nil} = wizard, _params) do
      {:error,
       %{
         wizard
         | step: :connect,
           form: radarr_form(%{"base_url" => "", "api_key" => ""}),
           connect_error: :missing_credentials
       }}
    end

    def configuration_input(%__MODULE__{} = wizard, params) do
      if ready_to_configure?(wizard) do
        %Connection{base_url: base_url, api_key: api_key, profiles: profiles} = wizard.connection

        quality_profile_id = parse_integer(params["quality_profile_id"])
        profile = Enum.find(profiles, &(&1.id == quality_profile_id))

        local_root_folder_path =
          case String.trim(params["local_root_folder_path"] || "") do
            "" -> nil
            value -> value
          end

        {:ok,
         %{
           base_url: base_url,
           api_key: api_key,
           quality_profile_id: quality_profile_id,
           quality_profile_name: profile && profile.name,
           root_folder_path: params["root_folder_path"],
           local_root_folder_path: local_root_folder_path
         }}
      else
        :not_ready
      end
    end

    def begin_profile_load(%__MODULE__{} = wizard, ref) do
      %{wizard | testing?: true, connect_error: nil, profiles_load_ref: ref}
    end

    def cancel_profile_load(%__MODULE__{} = wizard) do
      %{wizard | testing?: false, profiles_load_ref: nil}
    end

    def apply_profile_load_result(%__MODULE__{profiles_load_ref: current_ref}, ref, _result)
        when current_ref != ref do
      :stale
    end

    def apply_profile_load_result(
          %__MODULE__{} = wizard,
          _ref,
          {:ok, {:ok, %Connection{} = connection}}
        ) do
      {:ok,
       %{
         wizard
         | step: :configure,
           form: radarr_form(configuration_params(wizard, connection)),
           connection: connection,
           testing?: false,
           profiles_load_ref: nil
       }}
    end

    def apply_profile_load_result(%__MODULE__{} = wizard, _ref, {:ok, {:error, reason}}) do
      {:ok, profile_load_failed(wizard, reason)}
    end

    def apply_profile_load_result(%__MODULE__{} = wizard, _ref, {:exit, {:shutdown, :cancel}}) do
      {:ok, cancel_profile_load(wizard)}
    end

    def apply_profile_load_result(%__MODULE__{} = wizard, _ref, {:exit, reason}) do
      {:ok, profile_load_failed(wizard, {:transport_error, reason})}
    end

    def ready_to_configure?(%__MODULE__{
          testing?: false,
          connection: %Connection{profiles: profiles, root_folders: root_folders}
        }) do
      profiles != [] and root_folders != []
    end

    def ready_to_configure?(_wizard), do: false

    def selected_root_folder(%__MODULE__{} = wizard) do
      case wizard.form[:root_folder_path].value do
        nil -> ""
        value -> to_string(value)
      end
    end

    def profile_load_ref(%__MODULE__{profiles_load_ref: ref}), do: ref

    defp profile_load_failed(%__MODULE__{} = wizard, reason) do
      wizard = %{wizard | testing?: false, profiles_load_ref: nil, connect_error: reason}

      case wizard do
        %__MODULE__{mode: :edit, step: :configure, media_source: %MediaSource{} = media_source} ->
          %{
            wizard
            | step: :connect,
              form:
                radarr_form(%{
                  "base_url" => media_source.implementation.base_url,
                  "api_key" => ""
                }),
              connection: nil
          }

        _ ->
          wizard
      end
    end

    defp configuration_params(
           %__MODULE__{mode: :edit, media_source: %MediaSource{} = media_source},
           connection
         ) do
      impl = media_source.implementation
      default_profile = pick_default_profile(connection.profiles)
      default_root = pick_default_root_folder(connection.root_folders)

      profile =
        Enum.find(connection.profiles, &(&1.id == impl.quality_profile_id)) || default_profile

      root =
        Enum.find(connection.root_folders, &(&1.path == impl.root_folder_path)) || default_root

      %{
        "quality_profile_id" => profile && to_string(profile.id),
        "root_folder_path" => root && root.path,
        "local_root_folder_path" => impl.local_root_folder_path || ""
      }
    end

    defp configuration_params(_wizard, connection) do
      default_profile = pick_default_profile(connection.profiles)
      default_root = pick_default_root_folder(connection.root_folders)

      %{
        "quality_profile_id" => default_profile && to_string(default_profile.id),
        "root_folder_path" => default_root && default_root.path,
        "local_root_folder_path" => ""
      }
    end

    defp existing_configuration_params(impl) do
      %{
        "quality_profile_id" => to_string(impl.quality_profile_id),
        "root_folder_path" => impl.root_folder_path,
        "local_root_folder_path" => impl.local_root_folder_path || ""
      }
    end

    defp radarr_form(params), do: Component.to_form(params, as: :radarr)

    defp parse_integer(value) when is_binary(value) do
      case Integer.parse(value) do
        {integer, _rest} -> integer
        :error -> 0
      end
    end

    defp parse_integer(_), do: 0

    defp pick_default_profile([]), do: nil

    defp pick_default_profile(profiles) do
      Enum.find(profiles, &(&1.name == "HD-1080p Bluray")) ||
        Enum.find(profiles, &String.contains?(String.downcase(&1.name), "1080")) ||
        hd(profiles)
    end

    defp pick_default_root_folder([]), do: nil
    defp pick_default_root_folder([first | _]), do: first
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, id: assigns.id, current_user: assigns.current_user)

    if Map.has_key?(socket.assigns, :wizard) do
      {:ok, socket}
    else
      {:ok, initialize(assigns, socket)}
    end
  end

  defp initialize(%{mode: :create}, socket) do
    assign(socket, :wizard, Wizard.create(default_callback_base_url()))
  end

  defp initialize(
         %{mode: :edit, media_source: %MediaSource{source_type: :radarr} = media_source},
         socket
       ) do
    impl = media_source.implementation

    socket
    |> assign(:wizard, Wizard.edit(media_source, default_callback_base_url()))
    |> start_radarr_profiles_load(impl.base_url, impl.api_key)
  end

  defp default_callback_base_url, do: WatchClubWeb.Endpoint.url()

  attr :id, :string, required: true
  attr :mode, :atom, required: true, values: [:create, :edit]
  attr :media_source, MediaSource, default: nil
  attr :current_user, WatchClub.Accounts.User, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal id="add-radarr-source-modal" size="lg" on_close={JS.push("close", target: @myself)}>
        <:title>
          <span class="inline-flex items-center gap-related">
            <img
              src="/images/source_types/radarr.svg"
              alt="Radarr logo"
              class="size-icon"
            />
            {step_title(@wizard.step)}
          </span>
        </:title>
        <:description>{step_description(@wizard.step)}</:description>

        <.connect_form
          :if={@wizard.step == :connect}
          wizard={@wizard}
          myself={@myself}
        />
        <.configure_form
          :if={@wizard.step == :configure}
          wizard={@wizard}
          myself={@myself}
        />
        <.webhook_form
          :if={@wizard.step == :webhook}
          wizard={@wizard}
          myself={@myself}
        />
      </.modal>
    </div>
    """
  end

  defp step_title(:connect),
    do: dgettext("admin_media_imports", "Connect Radarr Server")

  defp step_title(:configure),
    do: dgettext("admin_media_imports", "Configure Request Profile")

  defp step_title(:webhook),
    do: dgettext("admin_media_imports", "Configure Webhooks")

  defp step_description(:connect),
    do: dgettext("admin_media_imports", "Enter the credentials to connect to your Radarr server.")

  defp step_description(:configure),
    do:
      dgettext(
        "admin_media_imports",
        "Select the Quality Profile and root folder that will be used to import and request media from this server. If you want to configure multiple quality profiles or root folders, create multiple sources."
      )

  defp step_description(:webhook),
    do:
      dgettext(
        "admin_media_imports",
        "We need to create a Radarr Webhook Connection to get real time notifications when new movies are available in Radarr. You can see it in Radarr Settings > Connect"
      )

  attr :wizard, :map, required: true
  attr :myself, :any, required: true

  defp connect_form(assigns) do
    ~H"""
    <.form
      for={@wizard.form}
      id="add-radarr-connect-form"
      phx-change="validate_radarr_connect"
      phx-submit="submit_radarr_connect"
      phx-target={@myself}
    >
      <.field
        field={@wizard.form[:base_url]}
        label={dgettext("admin_media_imports", "Radarr URL")}
        type="url"
        input_class="font-mono"
        placeholder="http://radarr:7878"
        autocomplete="off"
      >
        <:hint>
          {dgettext("admin_media_imports", "The base URL to reach Radarr from Watch Club.")}
        </:hint>
      </.field>

      <.field
        field={@wizard.form[:api_key]}
        label={dgettext("admin_media_imports", "API Key")}
        type="password"
        input_class="font-mono"
        placeholder="a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
        autocomplete="off"
      >
        <:hint>
          {dgettext(
            "admin_media_imports",
            "Your Radarr API key. You can find it in Radarr's settings > General."
          )}
        </:hint>
      </.field>

      <.connect_error_banner :if={@wizard.connect_error} reason={@wizard.connect_error} />

      <:action>
        <.button id="cancel-add-radarr" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          id="submit-radarr-connect"
          type="submit"
          variant="primary"
          disabled={@wizard.testing?}
        >
          <:icon :if={@wizard.testing?} position="start">
            <Lucideicons.loader_circle class="size-icon-sm animate-spin" />
          </:icon>
          {if @wizard.testing?,
            do: dgettext("admin_media_imports", "Connecting…"),
            else: dgettext("admin_media_imports", "Connect")}
        </.button>
      </:action>
    </.form>
    """
  end

  attr :wizard, :map, required: true
  attr :myself, :any, required: true

  defp configure_form(assigns) do
    assigns = assign(assigns, :selected_root_folder, Wizard.selected_root_folder(assigns.wizard))

    ~H"""
    <.form
      for={@wizard.form}
      id="add-radarr-configure-form"
      phx-change="validate_radarr_configure"
      phx-submit="submit_radarr_configure"
      phx-target={@myself}
    >
      <.connection_summary connection={@wizard.connection} />

      <.field
        field={@wizard.form[:quality_profile_id]}
        label={dgettext("admin_media_imports", "Quality Profile")}
      >
        <:hint>
          {dgettext(
            "admin_media_imports",
            "The Quality profile to use for making requests from this source."
          )}
        </:hint>
        <:control>
          <.radio_group
            field={@wizard.form[:quality_profile_id]}
            class="grid grid-cols-1 gap-related sm:grid-cols-2"
          >
            <:item
              :for={profile <- @wizard.connection.profiles}
              value={to_string(profile.id)}
              class="group/radio-card flex cursor-pointer items-center gap-tight rounded-control border border-border bg-surface-inset px-related py-tight transition-colors has-[:checked]:border-accent has-[:checked]:bg-surface-selected has-[:focus-visible]:border-border-focus has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus-ring [&>[data-slot=radio-group-item]]:sr-only"
            >
              <Lucideicons.sparkles class="size-icon-sm text-text-muted" />
              <span class="text-sm font-medium">{profile.name}</span>
              <Lucideicons.check class="ml-auto size-icon-sm text-accent opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
            </:item>
          </.radio_group>
        </:control>
      </.field>

      <.field
        field={@wizard.form[:root_folder_path]}
        label={dgettext("admin_media_imports", "Root folder")}
      >
        <:hint>
          {dgettext(
            "admin_media_imports",
            "The Root folder to use for making requests and importing data from this source."
          )}
        </:hint>
        <:control>
          <.radio_group
            field={@wizard.form[:root_folder_path]}
            class="grid gap-tight"
          >
            <:item
              :for={folder <- @wizard.connection.root_folders}
              value={folder.path}
              class="group/radio-card flex cursor-pointer items-center gap-related rounded-control border border-border bg-surface-inset px-related py-tight transition-colors has-[:checked]:border-accent has-[:checked]:bg-surface-selected has-[:focus-visible]:border-border-focus has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus-ring [&>[data-slot=radio-group-item]]:sr-only"
            >
              <Lucideicons.folder class="size-icon-sm shrink-0 text-text-muted" />
              <span class="truncate font-mono text-sm text-text">{folder.path}</span>
              <Lucideicons.check class="ml-auto size-icon-sm text-accent opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
            </:item>
          </.radio_group>
        </:control>
      </.field>

      <.field
        field={@wizard.form[:local_root_folder_path]}
        label={dgettext("admin_media_imports", "Path mapping (Optional)")}
        type="text"
        input_class="font-mono"
        placeholder={@selected_root_folder}
      >
        <:hint>
          {dgettext(
            "admin_media_imports",
            "The root folder path must be accessible directly by Watch Club for playback. If the mounts are different, enter the path to the root folder from Watch Club file system."
          )}
        </:hint>
      </.field>

      <:action>
        <.button
          id="radarr-back"
          type="button"
          variant="secondary"
          phx-click="radarr_back_to_connect"
          phx-target={@myself}
        >
          <:icon position="start"><Lucideicons.arrow_left class="size-icon-sm" /></:icon>
          {dgettext("default", "Back")}
        </.button>
        <.button
          id="submit-radarr-configure"
          type="submit"
          variant="primary"
          disabled={!Wizard.ready_to_configure?(@wizard)}
        >
          {submit_label(@wizard)}
        </.button>
      </:action>
    </.form>
    """
  end

  defp submit_label(%Wizard{mode: :create}), do: dgettext("admin_media_imports", "Continue")
  defp submit_label(%Wizard{mode: :edit}), do: dgettext("admin_media_imports", "Save changes")

  attr :wizard, :map, required: true
  attr :myself, :any, required: true

  defp webhook_form(assigns) do
    assigns = assign(assigns, :callback_url, Wizard.callback_url(assigns.wizard))

    ~H"""
    <.form
      for={@wizard.form}
      id="add-radarr-webhook-form"
      phx-change="validate_radarr_webhook"
      phx-submit="submit_radarr_webhook"
      phx-target={@myself}
    >
      <.field
        field={@wizard.form[:webhook_callback_base_url]}
        label={dgettext("admin_media_imports", "Watch Club URL")}
        type="url"
        input_class="font-mono"
        placeholder="http://host.docker.internal:4000"
        autocomplete="off"
      >
        <:hint>
          {dgettext(
            "admin_media_imports",
            "Use an address Radarr can reach from its network. In Docker setups this might be different from your browser URL."
          )}
        </:hint>
      </.field>

      <div class="flex items-center gap-related">
        <.button
          id="test-radarr-webhook"
          type="button"
          variant="secondary"
          phx-click="test_radarr_webhook"
          phx-target={@myself}
          disabled={@wizard.webhook_state == :testing or @callback_url in [nil, ""]}
        >
          <:icon :if={@wizard.webhook_state == :testing} position="start">
            <Lucideicons.loader_circle class="size-icon-sm animate-spin" />
          </:icon>
          {dgettext("admin_media_imports", "Test webhook")}
        </.button>

        <.webhook_status_badge state={@wizard.webhook_state} error={@wizard.webhook_error} />
      </div>

      <:action>
        <.button
          id="radarr-back-to-configure"
          type="button"
          variant="secondary"
          phx-click="radarr_back_to_configure"
          phx-target={@myself}
        >
          <:icon position="start"><Lucideicons.arrow_left class="size-icon-sm" /></:icon>
          {dgettext("default", "Back")}
        </.button>
        <.button
          id="submit-radarr-webhook"
          type="submit"
          variant="primary"
          disabled={!Wizard.ready_to_submit?(@wizard)}
        >
          {dgettext("admin_media_imports", "Add Source")}
        </.button>
      </:action>
    </.form>
    """
  end

  attr :state, :atom, required: true
  attr :error, :any, default: nil

  defp webhook_status_badge(%{state: :verified} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-tight text-sm text-success">
      <Lucideicons.circle_check class="size-icon-sm" />
      {dgettext("admin_media_imports", "Webhook configuration validated")}
    </span>
    """
  end

  defp webhook_status_badge(%{state: :failed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-tight text-sm text-danger">
      <Lucideicons.circle_alert class="size-icon-sm" />
      {dgettext("admin_media_imports", "Webhook delivery failed, ")}
    </span>
    """
  end

  defp webhook_status_badge(%{state: :testing} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-tight text-sm text-text-muted">
      {dgettext("admin_media_imports", "Validating webhook configuration...")}
    </span>
    """
  end

  defp webhook_status_badge(assigns) do
    ~H"""
    """
  end

  attr :connection, Connection, required: true

  defp connection_summary(assigns) do
    ~H"""
    <div class="flex items-start gap-related rounded-control border border-success-border bg-success-bg p-related">
      <Lucideicons.circle_check class="size-icon-sm shrink-0 text-success" />
      <div class="grid gap-tight text-sm">
        <span class="font-medium text-success">
          {dgettext("admin_media_imports", "Connected to Radarr")}
        </span>
        <span class="font-mono text-xs text-text-muted">
          {strip_scheme(@connection.base_url)}
        </span>
      </div>
    </div>
    """
  end

  attr :reason, :any, required: true

  defp connect_error_banner(assigns) do
    ~H"""
    <div class="flex items-start gap-related rounded-control border border-danger-border bg-danger-bg p-related">
      <Lucideicons.circle_alert class="size-icon-sm shrink-0 text-danger" />
      <div class="grid gap-tight text-sm">
        <span class="font-medium text-danger">
          {dgettext("admin_media_imports", "Could not reach Radarr")}
        </span>
        <span class="text-xs text-text-muted">{reason_copy(@reason)}</span>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate_radarr_connect", %{"radarr" => params}, socket) do
    {:noreply, assign(socket, :wizard, Wizard.validate_connection(socket.assigns.wizard, params))}
  end

  def handle_event("submit_radarr_connect", %{"radarr" => params}, socket) do
    case Wizard.prepare_connection_test(socket.assigns.wizard, params) do
      {:ok, wizard, base_url, api_key} ->
        {:noreply,
         socket
         |> assign(:wizard, wizard)
         |> start_radarr_profiles_load(base_url, api_key)}

      {:error, wizard} ->
        {:noreply, assign(socket, :wizard, wizard)}
    end
  end

  def handle_event("radarr_back_to_connect", _params, socket) do
    socket = cancel_radarr_profiles_load(socket)

    {:noreply, assign(socket, :wizard, Wizard.back_to_connection_step(socket.assigns.wizard))}
  end

  def handle_event("validate_radarr_configure", %{"radarr" => params}, socket) do
    {:noreply,
     assign(socket, :wizard, Wizard.validate_configuration(socket.assigns.wizard, params))}
  end

  def handle_event("submit_radarr_configure", %{"radarr" => params}, socket) do
    case Wizard.configuration_input(socket.assigns.wizard, params) do
      {:ok, input} ->
        case socket.assigns.wizard.mode do
          :edit ->
            submit_radarr_configure(socket, input)

          :create ->
            {:noreply,
             assign(
               socket,
               :wizard,
               Wizard.advance_to_webhook_step(socket.assigns.wizard, input)
             )}
        end

      {:error, wizard} ->
        {:noreply, assign(socket, :wizard, wizard)}

      :not_ready ->
        {:noreply, socket}
    end
  end

  def handle_event("radarr_back_to_configure", _params, socket) do
    socket = cancel_radarr_webhook_test(socket)

    {:noreply, assign(socket, :wizard, Wizard.back_to_configure_step(socket.assigns.wizard))}
  end

  def handle_event("validate_radarr_webhook", %{"radarr" => params}, socket) do
    {:noreply, assign(socket, :wizard, Wizard.validate_webhook(socket.assigns.wizard, params))}
  end

  def handle_event("test_radarr_webhook", _params, socket) do
    {:noreply, start_radarr_webhook_test(socket)}
  end

  def handle_event("submit_radarr_webhook", _params, socket) do
    wizard = socket.assigns.wizard

    if Wizard.ready_to_submit?(wizard) do
      input = Map.put(wizard.configuration, :webhook_callback_base_url, wizard.callback_base_url)
      submit_radarr_configure(socket, input)
    else
      {:noreply, socket}
    end
  end

  def handle_event("close", _params, socket) do
    send(self(), :close_radarr_source_modal)

    {:noreply,
     socket
     |> cancel_radarr_profiles_load()
     |> cancel_radarr_webhook_test()}
  end

  @impl true
  def handle_async({:radarr_load_profiles, ref}, result, socket) do
    case Wizard.apply_profile_load_result(socket.assigns.wizard, ref, result) do
      {:ok, wizard} -> {:noreply, assign(socket, :wizard, wizard)}
      :stale -> {:noreply, socket}
    end
  end

  def handle_async({:radarr_test_webhook, ref}, result, socket) do
    case Wizard.apply_webhook_test_result(socket.assigns.wizard, ref, result) do
      {:ok, wizard} -> {:noreply, assign(socket, :wizard, wizard)}
      :stale -> {:noreply, socket}
    end
  end

  defp start_radarr_profiles_load(socket, base_url, api_key) do
    ref = System.unique_integer([:positive, :monotonic])
    current_user = socket.assigns.current_user
    socket = cancel_radarr_profiles_load(socket)

    socket
    |> assign(:wizard, Wizard.begin_profile_load(socket.assigns.wizard, ref))
    |> start_async({:radarr_load_profiles, ref}, fn ->
      Media.load_radarr_profiles(base_url, api_key, actor: current_user)
    end)
  end

  defp cancel_radarr_profiles_load(%{assigns: %{wizard: %Wizard{} = wizard}} = socket) do
    case Wizard.profile_load_ref(wizard) do
      nil ->
        socket

      ref ->
        socket
        |> cancel_async({:radarr_load_profiles, ref})
        |> assign(:wizard, Wizard.cancel_profile_load(wizard))
    end
  end

  defp cancel_radarr_profiles_load(socket), do: socket

  defp start_radarr_webhook_test(socket) do
    wizard = socket.assigns.wizard

    case wizard.connection do
      %Connection{base_url: base_url, api_key: api_key} when is_binary(base_url) ->
        callback_url = Wizard.callback_url(wizard)
        token = "watchclub-test"
        ref = System.unique_integer([:positive, :monotonic])

        socket = cancel_radarr_webhook_test(socket)

        socket
        |> assign(:wizard, Wizard.begin_webhook_test(socket.assigns.wizard, ref))
        |> start_async({:radarr_test_webhook, ref}, fn ->
          WatchClub.Integrations.Radarr.test_webhook(base_url, api_key, %{
            name: "WatchClub Test #{wizard.wizard_id}",
            callback_url: callback_url,
            token: token
          })
        end)

      _ ->
        socket
    end
  end

  defp cancel_radarr_webhook_test(%{assigns: %{wizard: %Wizard{} = wizard}} = socket) do
    case Wizard.webhook_test_ref(wizard) do
      nil ->
        socket

      ref ->
        socket
        |> cancel_async({:radarr_test_webhook, ref})
        |> assign(:wizard, Wizard.cancel_webhook_test(wizard))
    end
  end

  defp cancel_radarr_webhook_test(socket), do: socket

  defp submit_radarr_configure(socket, input) do
    wizard = socket.assigns.wizard

    result =
      case wizard.mode do
        :edit ->
          Media.update_radarr_media_source(
            wizard.media_source.implementation,
            input,
            actor: socket.assigns.current_user
          )

        :create ->
          Media.create_radarr_media_source(input, actor: socket.assigns.current_user)
      end

    case result do
      {:ok, _media_source} ->
        send(self(), {:radarr_source_saved, wizard.mode})
        {:noreply, socket}

      {:error, _error} ->
        send(self(), :radarr_source_save_failed)
        {:noreply, socket}
    end
  end

  defp reason_copy(:missing_credentials),
    do: dgettext("admin_media_imports", "Fill in both the Radarr URL and API key.")

  defp reason_copy(:unauthorized),
    do: dgettext("admin_media_imports", "The API key was rejected by Radarr.")

  defp reason_copy(:not_found),
    do: dgettext("admin_media_imports", "Radarr's API was not found at this URL.")

  defp reason_copy(:rate_limited),
    do:
      dgettext("admin_media_imports", "Radarr is rate-limiting requests. Try again in a moment.")

  defp reason_copy(:client_error),
    do: dgettext("admin_media_imports", "Radarr rejected the request.")

  defp reason_copy(:server_error),
    do: dgettext("admin_media_imports", "Radarr returned a server error.")

  defp reason_copy(:unexpected_status),
    do: dgettext("admin_media_imports", "Radarr returned an unexpected response.")

  defp reason_copy(:invalid_response),
    do:
      dgettext("admin_media_imports", "Radarr's response did not look like the expected payload.")

  defp reason_copy({:transport_error, _}),
    do: dgettext("admin_media_imports", "Watch Club could not connect to Radarr at this URL.")

  defp reason_copy(_),
    do: dgettext("admin_media_imports", "Something went wrong reaching Radarr.")

  defp strip_scheme(url), do: WatchClubWeb.Helpers.Url.strip_scheme(url)
end
