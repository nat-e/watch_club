defmodule WatchClubWeb.LiveComponents.ClubSelectionButton do
  use WatchClubWeb, :live_component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents
  alias WatchClub.Contents.{Content, ContentView}

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
      <:title>{dgettext("contents", "Select libraries")}</:title>
      <.stack space="group" class="relative w-full max-w-lg">
        <.alert variant="default">
          <:icon><Lucideicons.users class="size-icon-xl" /></:icon>
          {raw(
            dgettext(
              "contents",
              "Add %{content_name} to club libraries to share it with the members of your clubs.",
              content_name: gtboldunder(@content.title)
            )
          )}
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
            <.library_selection_checkbox
              :for={option <- libraries_for_content(@current_user, @content)}
              club={option.club}
              library={option.library}
              selected?={in_library?(@content, option.library.id)}
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

  defp library_selection_checkbox(assigns) do
    ~H"""
    <label class={[
      "flex min-h-row-lg w-full flex-row items-center justify-between rounded-control border p-group hover:bg-surface-raised/50",
      @selected? && "bg-surface-selected text-text"
    ]}>
      <div class="flex min-w-0 flex-row items-center gap-related">
        <.avatar id={@club.id} name={@club.name} />
        <div class="min-w-0">
          <p class="truncate font-bold">{@club.name}</p>
          <p class="truncate text-sm text-text-muted">{@library.name}</p>
        </div>
      </div>
      <.checkbox
        name="form[library_ids][]"
        value={@library.id}
        checked={@selected?}
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
          Contents.form_to_set_club_libraries(content, actor: actor)
      end

    {:noreply, socket |> assign(:form, form)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, socket |> assign(:form, nil)}
  end

  def handle_event("submit", params, socket) do
    library_ids = (params["form"] && params["form"]["library_ids"]) || []
    actor = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: %{library_ids: library_ids},
           actor: actor
         ) do
      {:ok, %Content{} = content} ->
        content_view = ContentView.from_content(content, actor.settings.locale)

        {:noreply, socket |> assign(:form, nil) |> assign(:content, content_view)}

      {:error, form} ->
        Logger.warning("Error selecting clubs: #{inspect(form.source.errors)}")

        WatchClubWeb.Hooks.Flash.send_flash(
          :error,
          dgettext("default", "Something went wrong, try again later")
        )

        {:noreply, socket |> assign(:form, form)}
    end
  end

  defp libraries_for_content(%User{} = user, %ContentView{} = content) do
    user.memberships
    |> Enum.flat_map(fn membership ->
      membership.club.libraries
      |> Enum.filter(&(content.type in &1.accepted_content_types))
      |> Enum.map(&%{club: membership.club, library: &1})
    end)
  end

  defp in_library?(%ContentView{} = content, library_id) do
    Enum.any?(content.in_libraries, &(&1.library_id == library_id))
  end
end
