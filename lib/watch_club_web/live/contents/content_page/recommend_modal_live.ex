defmodule WatchClubWeb.Contents.ContentPage.RecommendModalLive do
  @moduledoc """
  Recommend Content: the User picks one or several other Users, writes a message if they want, and
  starts one Conversation with them all.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Accounts.UserAvatar

  alias WatchClub.{Accounts, Conversations}
  alias WatchClubWeb.Hooks.Flash

  attr :id, :string, required: true
  attr :content_identity, ContentIdentity, required: true
  attr :title, :string, required: true, doc: "the Content's name"

  attr :recommended_by_ids, :list,
    required: true,
    doc: "the Users who recommended the Content to the User"

  attr :current_user, User, required: true
  attr :on_close, :any, required: true, doc: "a function the dialog calls once it closes"

  @impl true
  def render(assigns) do
    selected = assigns.form[:recipient_ids].value || []
    assigns = assign(assigns, :selected, Enum.filter(assigns.users, &(&1.id in selected)))

    ~H"""
    <div>
      <.modal id={@id} size="md" on_close={JS.push("close", target: @myself)}>
        <:title>{dgettext("contents", "Recommend %{title}", title: @title)}</:title>
        <:description>
          {dgettext("contents", "To one person or several. Several people share one conversation.")}
        </:description>

        <.form
          for={@form}
          id={"#{@id}-form"}
          phx-change="validate"
          phx-submit="recommend"
          phx-target={@myself}
          layout="none"
          class="flex flex-col gap-cluster"
        >
          <fieldset class="flex flex-col gap-tight">
            <legend class="sr-only">{dgettext("contents", "People")}</legend>
            <ul class="-mx-related flex flex-col">
              <li :for={user <- @users}>
                <label
                  for={"#{@id}-to-#{user.id}"}
                  class="flex w-full cursor-pointer items-center gap-related rounded-control p-related transition-colors hover:bg-surface-hover has-checked:bg-surface-selected"
                >
                  <.user_avatar user={user} />
                  <span class="flex min-w-0 flex-1 flex-col">
                    <span class="truncate text-sm font-semibold">{user.username}</span>
                    <span
                      :if={user.id in @recommended_by_ids}
                      class="truncate text-xs text-text-muted"
                    >
                      {dgettext("contents", "Recommended it to you")}
                    </span>
                  </span>
                  <.checkbox
                    id={"#{@id}-to-#{user.id}"}
                    name={@form[:recipient_ids].name <> "[]"}
                    value={user.id}
                    checked={user in @selected}
                  />
                </label>
              </li>
            </ul>
            <.field_errors field={@form[:recipient_ids]} />
          </fieldset>

          <.field
            field={@form[:body]}
            label={dgettext("contents", "Message (optional)")}
            autocomplete="off"
            placeholder={dgettext("contents", "Why they'd love it")}
          />

          <p :if={@selected != []} class="flex items-center gap-related text-sm text-text-muted">
            <Lucideicons.messages_square class="size-icon-sm shrink-0" />
            {summary(@selected, @current_user)}
          </p>
        </.form>

        <:footer>
          <.button id={"#{@id}-cancel"} variant="ghost" phx-click={JS.push("close", target: @myself)}>
            {dgettext("contents", "Cancel")}
          </.button>
          <.button
            id={"#{@id}-submit"}
            type="submit"
            form={"#{@id}-form"}
            disabled={@selected == []}
          >
            <:icon><Lucideicons.send /></:icon>
            {dgettext("contents", "Recommend")}
          </.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  defp summary([user], _current_user),
    do: dgettext("contents", "Starts a conversation with %{name}.", name: user.username)

  defp summary(users, current_user) do
    dgettext("contents", "Starts one group conversation with %{names}.",
      names: names(users, current_user)
    )
  end

  defp names(users, current_user) do
    users
    |> Enum.map(& &1.username)
    |> WatchClub.Cldr.List.to_string!(
      locale: UserLocale.to_cldr_locale_name(current_user.settings.locale)
    )
  end

  # No need to support update_many for a modal
  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    user = assigns.current_user

    {:ok,
     assign_new(socket, :form, fn -> new_form(socket) end)
     |> assign_new(:users, fn ->
       # Intentionally small: every other User of the instance
       [actor: user, query: [sort: [username: :asc]]]
       |> Accounts.list_users!()
       |> Enum.reject(&(&1.id == user.id))
     end)}
  end

  defp new_form(socket) do
    %{content_identity: identity, current_user: user} = socket.assigns

    [
      actor: user,
      transform_params: fn _form, params, _type ->
        Map.put(params, "content_identity", Map.from_struct(identity))
      end
    ]
    |> Conversations.form_to_recommend_content()
    |> to_form()
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket),
    do: {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}

  def handle_event("recommend", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _conversation} ->
        %{users: users, current_user: user} = socket.assigns
        selected = Enum.filter(users, &(&1.id in params["recipient_ids"]))

        Flash.send_flash(
          :info,
          dgettext("contents", "Recommended to %{names}. The conversation is in your Inbox.",
            names: names(selected, user)
          )
        )

        socket.assigns.on_close.()
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end
end
