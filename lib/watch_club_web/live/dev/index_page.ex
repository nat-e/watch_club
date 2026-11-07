defmodule WatchClubWeb.Dev.IndexPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Prototypes.Frame
  alias WatchClub.Dev.Prototypes

  @impl true
  def mount(_params, _session, socket) do
    # A local worktree has a small, bounded set of experiments.
    {:ok,
     assign(socket,
       prototypes: Prototypes.list!(),
       delete_target: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.prototype_frame
      flash={@flash}
      title={if @live_action == :home, do: "Development", else: "Prototypes"}
      description={
        if @live_action == :home,
          do: "Local tools and experiments for this worktree.",
          else:
            "Each experiment keeps its pages and sample data together. Code loads only when you open it."
      }
      back={if @live_action == :home, do: "/", else: "/dev"}
      back_label={if @live_action == :home, do: "Watch Club", else: "Development"}
    >
      <:action>
        <.button id="refresh-prototypes" variant="ghost" phx-click="refresh"><Lucideicons.refresh_cw />Refresh</.button>
      </:action>
      <div class="flex flex-col gap-section">
        <nav
          :if={@live_action == :home}
          aria-label="Developer tools"
          class="flex flex-wrap gap-related"
        >
          <.button id="dev-prototypes" variant="secondary" navigate="/dev/prototypes"><Lucideicons.flask_conical />Prototypes</.button>
          <.button id="dev-components" variant="secondary" href="/dev/storybook"><Lucideicons.palette />Components</.button>
          <.button id="dev-dashboard" variant="secondary" href="/dev/dashboard"><Lucideicons.gauge />Dashboard</.button>
          <.button id="dev-jobs" variant="secondary" href="/dev/oban"><Lucideicons.list_checks />Background jobs</.button>
        </nav>

        <section aria-labelledby="experiments-title" class="flex flex-col gap-group">
          <div class="flex flex-wrap items-baseline justify-between gap-related">
            <h2 id="experiments-title" class="font-heading text-xl font-semibold">
              Experiments <span class="text-text-muted">{length(@prototypes)}</span>
            </h2>
            <p class="text-sm text-text-muted">
              Create one with
              <code class="font-mono text-text">mix dev.prototype.new &lt;name&gt;</code>
            </p>
          </div>

          <.empty :if={@prototypes == []}>
            <:icon><Lucideicons.flask_conical /></:icon>
            <:title>No prototypes yet</:title>
            <:description>
              Create an experiment to compare a few designs without changing the app.
            </:description>
          </.empty>

          <.card
            :for={prototype <- @prototypes}
            id={"prototype-#{prototype.slug}"}
            class="@container relative flex flex-col gap-group transition-colors hover:bg-surface-hover"
          >
            <div class="flex items-start justify-between gap-group">
              <div class="flex min-w-0 flex-col gap-tight">
                <h3 class="font-semibold">
                  <.link
                    navigate={"/dev/prototypes/#{prototype.slug}"}
                    class="rounded-control after:absolute after:inset-0 after:rounded-card focus-visible:outline-2 focus-visible:outline-focus focus-visible:outline-offset-2"
                  >{prototype.name}</.link>
                </h3>
                <p :if={prototype.description} class="max-w-readable text-sm text-text-muted">
                  {prototype.description}
                </p>
              </div>
              <.button
                :if={@current_user.administrator?}
                id={"delete-#{prototype.slug}"}
                variant="ghost"
                size="icon-sm"
                phx-click="ask_delete"
                phx-value-slug={prototype.slug}
                aria-label={"Delete #{prototype.name}"}
                class="relative z-1 shrink-0"
              ><Lucideicons.trash_2 /></.button>
            </div>
            <div class="flex flex-wrap items-center gap-related text-xs text-text-muted">
              <span :if={prototype.updated_at > 0}>Updated {Calendar.strftime(
                DateTime.from_unix!(prototype.updated_at),
                "%d %b %Y"
              )}</span>
              <span class="min-w-0 break-all font-mono">dev/prototypes/{prototype.slug}</span>
            </div>
            <p :if={prototype.error} class="text-sm text-danger">{prototype.error}</p>
          </.card>
        </section>
      </div>
    </.prototype_frame>

    <.modal :if={@delete_target} id="delete-prototype" size="sm" on_close={JS.push("cancel_delete")}>
      <:title>Delete {@delete_target.name}?</:title>
      <:description>
        All {length(@delete_target.files)} files in this experiment will be permanently removed from this worktree.
      </:description>
      <p class="break-all font-mono text-text-muted">dev/prototypes/{@delete_target.slug}</p>
      <:footer>
        <.button id="cancel-delete-prototype" variant="secondary" phx-click="cancel_delete">Cancel</.button>
        <.button id="confirm-delete-prototype" variant="danger" phx-click="delete">Delete prototype</.button>
      </:footer>
    </.modal>
    """
  end

  @impl true
  def handle_event("refresh", _params, socket),
    do: {:noreply, assign(socket, prototypes: Prototypes.list!())}

  def handle_event("ask_delete", %{"slug" => slug}, socket) do
    if socket.assigns.current_user.administrator? do
      {:noreply, assign(socket, :delete_target, Prototypes.get(slug))}
    else
      {:noreply,
       put_flash(socket, :error, "Only the Instance Administrator can delete prototypes")}
    end
  end

  def handle_event("cancel_delete", _params, socket),
    do: {:noreply, assign(socket, :delete_target, nil)}

  def handle_event("delete", _params, %{assigns: %{delete_target: target}} = socket) do
    if socket.assigns.current_user.administrator? and target do
      case Prototypes.delete(target.slug) do
        :ok ->
          {:noreply,
           socket
           |> assign(prototypes: Prototypes.list!(), delete_target: nil)
           |> put_flash(:info, "Prototype deleted")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, error)}
      end
    else
      {:noreply, put_flash(socket, :error, "Choose a prototype to delete")}
    end
  end
end
