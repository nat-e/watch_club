defmodule WatchClubWeb.Dev.PrototypePage do
  @moduledoc "A stable LiveView boundary around code loaded from a local experiment."
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Prototypes.Frame
  alias WatchClub.Dev.{PrototypeRuntime, Prototypes}

  @impl true
  def mount(params, session, socket) do
    socket =
      assign(socket, :prototype_preview, %{slug: params["prototype"], module: nil, error: nil})

    with {:ok, prototype, page} <-
           Prototypes.resolve(params["prototype"], Enum.join(params["page"] || [], "/")),
         {:ok, modules} <- PrototypeRuntime.load(prototype),
         module when not is_nil(module) <-
           Enum.find(modules, &(Atom.to_string(&1) == "Elixir." <> page.module)) do
      socket =
        assign(socket, :prototype_preview, %{slug: prototype.slug, module: module, error: nil})

      try do
        if function_exported?(module, :mount, 3),
          do: module.mount(params, session, socket),
          else: {:ok, socket}
      rescue
        error -> {:ok, failed(socket, error, __STACKTRACE__)}
      end
    else
      {:error, error} ->
        {:ok,
         assign(socket, :prototype_preview, %{socket.assigns.prototype_preview | error: error})}

      nil ->
        {:ok,
         assign(socket, :prototype_preview, %{
           socket.assigns.prototype_preview
           | error: "The page's module was not found in the experiment's files"
         })}
    end
  end

  @impl true
  def render(%{prototype_preview: %{error: nil, module: module}} = assigns)
      when not is_nil(module) do
    module.render(assigns)
  rescue
    error ->
      message = Exception.format(:error, error, __STACKTRACE__)
      PrototypeRuntime.failed(assigns.prototype_preview.slug, message)

      error_page(
        assign(assigns, :prototype_preview, %{assigns.prototype_preview | error: message})
      )
  end

  def render(assigns), do: error_page(assigns)

  defp error_page(assigns) do
    ~H"""
    <.prototype_frame
      flash={@flash}
      title="This prototype needs fixing"
      description="The app is running. Fix the experiment's files, then open it again."
    >
      <div class="flex min-w-0 flex-col gap-group">
        <.alert variant="danger"><:title>Prototype error</:title>{@prototype_preview.slug}</.alert>
        <pre
          id="prototype-error"
          class="max-w-full overflow-auto rounded-card border border-border-subtle bg-surface-inset p-group font-mono text-xs text-text-muted"
        >{@prototype_preview.error}</pre>
        <div>
          <.button id="retry-prototype" variant="secondary" href={Url.to_url(@current_url)}><Lucideicons.refresh_cw />Try again</.button>
        </div>
      </div>
    </.prototype_frame>
    """
  end

  @impl true
  def handle_params(params, uri, socket), do: dispatch(:handle_params, [params, uri], socket)

  @impl true
  def handle_event(event, params, socket), do: dispatch(:handle_event, [event, params], socket)

  @impl true
  def handle_info(message, socket), do: dispatch(:handle_info, [message], socket)

  @impl true
  def handle_async(name, result, socket), do: dispatch(:handle_async, [name, result], socket)

  defp dispatch(callback, args, socket) do
    %{module: module, error: error} = socket.assigns.prototype_preview

    if is_nil(error) and not is_nil(module) and
         function_exported?(module, callback, length(args) + 1) do
      try do
        apply(module, callback, args ++ [socket])
      rescue
        error -> {:noreply, failed(socket, error, __STACKTRACE__)}
      end
    else
      {:noreply, socket}
    end
  end

  defp failed(socket, error, stacktrace) do
    message = Exception.format(:error, error, stacktrace)
    preview = %{socket.assigns.prototype_preview | error: message}
    PrototypeRuntime.failed(preview.slug, message)
    assign(socket, :prototype_preview, preview)
  end
end
