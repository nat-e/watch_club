defmodule WatchClubWeb.LiveComponents.ClubSelectionButton do
  use WatchClubWeb, :live_component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents
  alias WatchClub.Contents.ContentView

  attr :content, ContentView, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.button
        size="lg"
        class={@class}
        phx-target={@myself}
        phx-click="open"
      >
        <.inner clubs={ContentView.in_clubs(@content, @current_user)} />
      </.button>
      <.club_selection_modal
        :if={@form}
        content={@content}
        current_user={@current_user}
        form={@form}
        myself={@myself}
      />
    </div>
    """
  end

  defp inner(%{clubs: []} = assigns) do
    ~H"""
    <Lucideicons.download />
    <span>{dgettext("contents", "Add to club")}</span>
    """
  end

  defp inner(assigns) do
    ~H"""
    <.avatar_group avatars={@clubs} avatar_size="sm" />
    <.count_label count={length(@clubs)} />
    """
  end

  attr :count, :integer, required: true

  defp count_label(assigns) do
    ~H"""
    <span class="mr-tight">
      {dngettext("contents", "In %{count} club", "In %{count} clubs", @count)}
    </span>
    """
  end

  defp club_selection_modal(assigns) do
    ~H"""
    <.modal id="club-selection-modal" on_close={JS.push("close", target: @myself)}>
      <:title>{dgettext("contents", "Select clubs")}</:title>
      <.stack space="group" class="relative w-full max-w-lg">
        <.alert variant="default">
          <:icon><Lucideicons.users class="size-8" /></:icon>
          <p class="text-white">
            {raw(
              dgettext(
                "contents",
                "Select the clubs in which you want to add %{content_name}. Adding the content to the club will make it available for everyone.",
                content_name: gtboldunder(@content.title)
              )
            )}
          </p>
        </.alert>
        <.stack space="group">
          <.inline class="justify-around">
            <h2 class="text-lg font-bold">{dgettext("contents", "Select clubs")}</h2>
          </.inline>
          <.form
            for={@form}
            phx-target={@myself}
            phx-submit="submit"
          >
            <.club_selection_checkbox
              :for={membership <- @current_user.memberships}
              club={membership.club}
              current_user={@current_user}
              content={@content}
              selected?={in_club?(@content, membership.club.id)}
            />
            <:action>
              <.button type="submit">{dgettext("default", "Save")}</.button>
            </:action>
          </.form>
        </.stack>
      </.stack>
    </.modal>
    """
  end

  defp club_selection_checkbox(%{selected?: false} = assigns) do
    ~H"""
    <label class={[
      "flex h-16 w-full flex-row items-center justify-between rounded-control border p-group hover:bg-surface-raised/50",
      @selected? && "bg-surface-selected text-text"
    ]}>
      <.inline class="font-bold">
        <.avatar id={@club.id} name={@club.name} />
        {@club.name}
      </.inline>
      <.checkbox
        name="form[club_ids][]"
        value={@club.id}
        checked={@selected?}
      />
    </label>
    """
  end

  defp club_selection_checkbox(%{selected?: true} = assigns) do
    actor = assigns.current_user

    library_item =
      Enum.find(assigns.content.in_libraries, fn item -> item.club_id == assigns.club.id end)

    assigns =
      assigns
      |> assign(
        :can_remove?,
        Clubs.can_remove_content_from_club?(actor, library_item)
      )

    ~H"""
    <label class={[
      "flex h-16 w-full flex-row items-center justify-between rounded-control border p-group hover:bg-surface-raised/50",
      @selected? && "bg-surface-selected text-text"
    ]}>
      <.inline class="font-bold">
        <.avatar id={@club.id} name={@club.name} />
        {@club.name}
      </.inline>
      <.checkbox
        name="form[club_ids][]"
        value={@club.id}
        checked={@selected?}
        disabled={!@can_remove?}
      />
    </label>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(:form, nil)}
  end

  @impl true
  @spec handle_event(<<_::32, _::_*8>>, any(), any()) :: {:noreply, any()}
  def handle_event("open", _params, socket) do
    content_view = socket.assigns.content
    actor = socket.assigns.current_user

    form =
      case content_view do
        %ContentView{content: nil, type: :movie} ->
          Contents.form_to_create_movie(
            prepare_params: fn params, _ ->
              Map.put(params, :tmdb_id, String.to_integer(content_view.external_id))
            end,
            actor: actor
          )

        %ContentView{content: content, type: :movie} ->
          Contents.form_to_set_in_club_libraries(content, actor: actor)
      end

    {:noreply, socket |> assign(:form, form)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, socket |> assign(:form, nil)}
  end

  def handle_event("submit", params, socket) do
    club_ids = (params["form"] && params["form"]["club_ids"]) || []
    actor = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: %{club_ids: club_ids}, actor: actor) do
      {:ok, _content} ->
        {:noreply, socket |> assign(:form, nil)}

      {:error, form} ->
        Logger.warning("Error selecting clubs: #{inspect(form.source.errors)}")

        WatchClubWeb.Hooks.Flash.send_flash(
          :error,
          dgettext("default", "Something went wrong, try again later")
        )

        {:noreply, socket |> assign(:form, form)}
    end
  end

  defp in_club?(%ContentView{} = content, club_id) do
    Enum.any?(content.in_libraries, fn library_item -> library_item.club_id == club_id end)
  end
end
