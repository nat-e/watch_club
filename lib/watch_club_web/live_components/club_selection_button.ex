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
        variant="default"
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

  # 1–3 clubs: render them all stacked
  defp inner(%{clubs: clubs} = assigns) when length(clubs) <= 3 do
    ~H"""
    <div :for={{club, index} <- Enum.with_index(@clubs)} class={index > 0 && "ml-[-20px]"}>
      <.generic_avatar id={club.id} name={club.name} size="sm" />
    </div>
    <.count_label count={length(@clubs)} />
    """
  end

  # 4+ clubs: first 2 avatars + "+N" overflow chip
  defp inner(assigns) do
    ~H"""
    <div
      :for={{club, index} <- Enum.take(@clubs, 2) |> Enum.with_index()}
      class={index > 0 && "ml-[-20px]"}
    >
      <.generic_avatar id={club.id} name={club.name} size="sm" />
    </div>
    <div class="ml-[-20px]">
      <.avatar size="sm">
        <:fallback class="bg-gray-500 text-sm font-bold text-white">
          +{length(@clubs) - 2}
        </:fallback>
      </.avatar>
    </div>
    <.count_label count={length(@clubs)} />
    """
  end

  attr :count, :integer, required: true

  defp count_label(assigns) do
    ~H"""
    <span class="mr-1">
      {dngettext("contents", "In %{count} club", "In %{count} clubs", @count)}
    </span>
    """
  end

  defp club_selection_modal(assigns) do
    ~H"""
    <.modal open={true} on_close={JS.push("close", target: @myself)}>
      <.dialog>
        <:title>{dgettext("contents", "Select clubs")}</:title>
        <div class="relative w-full max-w-lg p-0">
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
          <div class="mt-4 flex flex-col gap-4">
            <div class="mr-6 flex flex-row items-center justify-around w-full">
              <h2 class="text-lg font-bold">{dgettext("contents", "Select clubs")}</h2>
            </div>
            <.form
              for={@form}
              phx-target={@myself}
              phx-submit="submit"
              class="flex flex-col gap-6 items-end"
            >
              <.club_selection_checkbox
                :for={membership <- @current_user.memberships}
                club={membership.club}
                current_user={@current_user}
                content={@content}
                selected?={in_club?(@content, membership.club.id)}
              />
              <.button type="submit">{dgettext("default", "Save")}</.button>
            </.form>
          </div>
        </div>
      </.dialog>
    </.modal>
    """
  end

  defp club_selection_checkbox(%{selected?: false} = assigns) do
    ~H"""
    <label class={[
      "flex h-16 w-full flex-row justify-between items-center border rounded-md p-4 hover:bg-secondary/50",
      @selected? && "bg-secondary text-secondary-foreground"
    ]}>
      <div class="flex gap-2 items-center font-bold">
        <.generic_avatar id={@club.id} name={@club.name} />
        {@club.name}
      </div>
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
      "flex h-16 w-full flex-row justify-between items-center border rounded-md p-4 hover:bg-secondary/50",
      @selected? && "bg-secondary text-secondary-foreground"
    ]}>
      <div class="flex gap-2 items-center font-bold">
        <.generic_avatar id={@club.id} name={@club.name} />
        {@club.name}
      </div>
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
