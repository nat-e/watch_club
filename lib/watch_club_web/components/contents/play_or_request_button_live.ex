defmodule WatchClubWeb.Components.Contents.PlayOrRequestButtonLive do
  use WatchClubWeb, :live_component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, ContentView}
  alias WatchClub.Requests
  alias WatchClub.Requests.ContentRequestStatus

  attr :content, ContentView, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  @impl true
  def render(assigns) do
    assigns = assigns |> assign(:request, ContentView.current_request(assigns.content))

    ~H"""
    <div class={@class}>
      <.button
        :if={!ContentView.playable?(@content)}
        id={"#{@id}-request-button"}
        size={@size}
        variant="primary"
        emphasis
        phx-click="request-content"
        phx-target={@myself}
        disabled={@request != nil}
        class="w-full"
      >
        <:icon :if={@request != nil}><Lucideicons.loader_circle class="animate-spin" /></:icon>
        <:icon :if={@request == nil}><Lucideicons.download /></:icon>
        {(@request && ContentRequestStatus.translated_label(@request.status)) ||
          dgettext("contents", "Request")}
      </.button>
      <.button
        :if={ContentView.playable?(@content)}
        id={"#{@id}-play-button"}
        size={@size}
        variant="primary"
        emphasis
        href={play_link(@content)}
        class="w-full"
      >
        <:icon><Lucideicons.play /></:icon>
        {dgettext("contents", "Play")}
      </.button>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(:form, nil)}
  end

  @impl true
  def handle_event("request-content", _params, socket) do
    content = socket.assigns.content

    case Requests.request_content(
           %{
             external_id_source: content.external_id_source,
             external_id: content.external_id,
             content_type: content.type
           },
           actor: socket.assigns.current_user
         ) do
      {:ok, _request} ->
        {:noreply, put_flash(socket, :info, dgettext("contents", "Added to your requests."))}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, dgettext("contents", "Could not request this right now."))}
    end
  end

  defp play_link(%ContentView{content: %Content{movie: %Movie{} = movie}}) do
    video = List.first(movie.videos)
    ~p"/play/#{video.id}"
  end

  defp play_link(%ContentView{content: %Content{tv_show: %TvShow{} = show}}) do
    first_episode =
      Enum.find(show.episodes, fn e -> e.season_number == 1 and e.episode_number == 1 end)

    video = List.first(first_episode.videos)
    ~p"/play/#{video.id}"
  end
end
