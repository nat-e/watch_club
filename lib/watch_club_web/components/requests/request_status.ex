defmodule WatchClubWeb.Components.Requests.RequestStatus do
  @moduledoc """
  A Content Request Status, named as everywhere in WatchClub, in the color of how it's going. My
  Requests' cards, Playlist Items and the Content page show it.
  """
  use WatchClubWeb, :component

  attr :status, :atom, required: true, doc: "a `ContentRequestStatus`"
  attr :rest, :global

  def request_status(assigns) do
    assigns = assign(assigns, :variant, variant(assigns.status))

    ~H"""
    <span
      class={[
        "text-sm font-semibold tracking-wider uppercase",
        @variant == "default" && "text-text-muted",
        @variant == "accent" && "text-accent",
        @variant == "danger" && "text-danger",
        @variant == "success" && "text-success"
      ]}
      {@rest}
    >
      {ContentRequestStatus.translated_label(@status)}
    </span>
    """
  end

  @doc """
  How a Content Request is going, as a color variant: `"accent"` while it's on its way,
  `"default"` while it waits for a release or a source, then `"danger"` or `"success"`.
  """
  def variant(status) when status in [:queued, :downloading, :importing], do: "accent"
  def variant(status) when status in [:not_released, :not_found], do: "default"
  def variant(:failed), do: "danger"
  def variant(:completed), do: "success"
end
