defmodule WatchClubWeb.Components.Contents.PlayOrRequestButton do
  @moduledoc """
  Play for a Content with Media, or Request, with the state of the actor's Content Request.
  `PlayOrRequestButtonLive` loads what it shows and makes the request.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :has_media?, :boolean, required: true
  attr :play_href, :string, default: nil, doc: "the Player, nil when there's nothing to play"
  attr :play_label, :string, required: true, doc: "such as Play, or Resume S01E03"
  attr :title, :string, default: nil, doc: "the Content's name, in the round Play's label"

  attr :request, ContentRequest,
    default: nil,
    doc: "the actor's Content Request, with its `best_source_request`"

  attr :on_request, :any, default: nil, doc: "the event or JS commands of Request"
  attr :play_only, :boolean, default: false

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  attr :variant, :string,
    values: ~w(button round),
    default: "button",
    doc: "round: only Play, with only its icon, over a poster"

  @in_progress_statuses [:searching, :downloading, :downloaded]

  # Only Play, when there's something to play
  def play_or_request_button(%{variant: "round"} = assigns) do
    ~H"""
    <.button
      :if={@play_href}
      id={"#{@id}-play-button"}
      variant="primary"
      size="icon-lg"
      href={@play_href}
      aria-label={dgettext("contents", "%{action} %{title}", action: @play_label, title: @title)}
      title={@play_label}
      class="rounded-full! shadow-overlay"
    >
      <Lucideicons.play />
    </.button>
    """
  end

  def play_or_request_button(%{has_media?: false} = assigns) do
    ~H"""
    <.button
      :if={!@play_only}
      id={"#{@id}-request-button"}
      size={@size}
      variant="primary"
      emphasis
      phx-click={@on_request}
      disabled={@request != nil}
      class="w-full"
    >
      <.lucide_icon name={request_icon(@request)} class={[icon_spin(@request) && "animate-spin"]} />
      {request_label(@request)}
    </.button>
    """
  end

  def play_or_request_button(assigns) do
    ~H"""
    <.button
      id={"#{@id}-play-button"}
      size={@size}
      variant="primary"
      emphasis
      href={@play_href}
      disabled={!@play_href}
      class="w-full"
    >
      <:icon><Lucideicons.play /></:icon>
      {@play_label}
    </.button>
    """
  end

  defp icon_spin(nil), do: false

  defp icon_spin(%ContentRequest{best_source_request: nil}), do: true

  defp icon_spin(%ContentRequest{best_source_request: %MediaSourceRequest{status: status}}),
    do: status in @in_progress_statuses

  defp request_icon(nil), do: :download

  defp request_icon(%ContentRequest{best_source_request: nil}), do: :loader_circle

  defp request_icon(%ContentRequest{best_source_request: %MediaSourceRequest{status: status}})
       when status in @in_progress_statuses, do: :loader_circle

  defp request_icon(%ContentRequest{
         best_source_request: %MediaSourceRequest{status: :not_released}
       }),
       do: :calendar

  defp request_icon(%ContentRequest{
         best_source_request: %MediaSourceRequest{status: :needs_attention}
       }),
       do: :triangle_alert

  defp request_label(nil), do: dgettext("contents", "Request")

  defp request_label(%ContentRequest{
         best_source_request: %MediaSourceRequest{status: :searching}
       }) do
    dgettext("contents", "Searching")
  end

  defp request_label(%ContentRequest{best_source_request: nil}),
    do: dgettext("contents", "Downloading")

  defp request_label(%ContentRequest{best_source_request: %MediaSourceRequest{status: status}})
       when status in @in_progress_statuses do
    dgettext("contents", "Downloading")
  end

  defp request_label(%ContentRequest{
         best_source_request: %MediaSourceRequest{status: :not_released}
       }) do
    dgettext("contents", "Not Released")
  end

  defp request_label(%ContentRequest{
         best_source_request: %MediaSourceRequest{status: :needs_attention}
       }) do
    dgettext("contents", "Error")
  end
end
