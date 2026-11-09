defmodule WatchClubWeb.Live.Player.ReportProblemLive do
  @moduledoc """
  The form to Report a Problem, over the Player. Once the Problem Report is saved, it sends
  `{ReportProblemLive, :reported}` to its LiveView.
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.ProblemReport.Category
  alias WatchClubWeb.Components.Playbacks.ProblemCategory

  attr :id, :string, required: true

  attr :details, :map,
    required: true,
    doc: "`playback_id`, `user_agent` and what the Player showed, for the Problem Report"

  attr :category, :atom, default: nil, doc: "the category picked when the form opens"
  attr :current_user, User, required: true
  attr :on_close, JS, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={"#{@id}-modal"} size="sm" phone="sheet" on_close={@on_close}>
        <:title>{dgettext("player", "Report a problem")}</:title>
        <:description>
          {dgettext("player", "Let the administrator know there's a problem with this content.")}
        </:description>

        <.form
          id={"#{@id}-form"}
          for={@form}
          phx-change="validate"
          phx-submit="send"
          phx-target={@myself}
        >
          <div class="grid gap-related">
            <.label id={"#{@id}-category-label"}>{dgettext("player", "What's wrong?")}</.label>
            <%!-- Other is a slim row under the tiles, so the vaguest choice isn't the biggest --%>
            <.radio_group
              field={@form[:category]}
              aria-labelledby={"#{@id}-category-label"}
              class="grid-cols-2"
            >
              <:item
                :for={category <- Category.values()}
                value={category}
                class={[
                  "group/radio-card flex cursor-pointer items-center justify-center gap-related rounded-control border border-border-control bg-surface-inset text-center font-semibold transition-colors hover:bg-surface-hover has-checked:border-accent has-checked:bg-surface-selected has-focus-visible:border-border-focus has-focus-visible:ring-2 has-focus-visible:ring-focus-ring *:data-[slot=radio-group-item]:sr-only",
                  category != :other && "flex-col p-group",
                  category == :other && "col-span-2 p-related"
                ]}
              >
                <.lucide_icon
                  name={ProblemCategory.icon(category)}
                  class={[
                    "shrink-0 text-text-muted group-has-checked/radio-card:text-accent",
                    if(category == :other, do: "size-icon-sm", else: "size-icon-lg")
                  ]}
                />
                {ProblemCategory.name(category)}
              </:item>
            </.radio_group>
            <.field_errors field={@form[:category]} />
          </div>

          <.field
            field={@form[:comment]}
            type="textarea"
            rows="3"
            label={dgettext("player", "Details (optional)")}
            placeholder={dgettext("player", "What happened?")}
          />
        </.form>

        <:footer>
          <.button
            id={"#{@id}-send"}
            type="submit"
            form={"#{@id}-form"}
            variant="primary"
            disabled={@form[:category].value in [nil, ""]}
          >
            {dgettext("player", "Send report")}
          </.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    {:ok, if(socket.assigns[:form], do: socket, else: assign_form(socket))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket),
    do: {:noreply, update(socket, :form, &AshPhoenix.Form.validate(&1, params))}

  def handle_event("send", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _report} ->
        send(self(), {__MODULE__, :reported})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(socket) do
    %{details: details, category: category, current_user: user} = socket.assigns

    form =
      Playbacks.form_to_report_problem(
        actor: user,
        params: %{"category" => category},
        prepare_source: &Ash.Changeset.change_attributes(&1, details)
      )

    assign(socket, :form, to_form(form))
  end
end
