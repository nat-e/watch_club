defmodule WatchClubWeb.Components.Media.SourceIdentifier do
  @moduledoc """
  Compact monospace chip that identifies a Media Source.

  Filesystem sources show the filesystem path; Radarr sources show
  `host · root_folder_path`.
  """
  use WatchClubWeb, :component

  alias WatchClub.Media.{FilesystemMediaSource, MediaSource, RadarrMediaSource}

  attr :media_source, MediaSource, required: true
  attr :class, :any, default: nil

  def source_identifier(assigns) do
    assigns =
      assigns
      |> assign(:icon, identifier_icon(assigns.media_source))
      |> assign(:text, identifier_text(assigns.media_source))

    ~H"""
    <span class={[
      "inline-flex w-fit min-w-0 items-center gap-tight rounded-control border border-border-subtle bg-surface-inset px-related py-tight font-mono text-xs text-text-muted",
      @class
    ]}>
      <.lucide_icon name={@icon} class="size-icon-sm shrink-0" />
      <span class="truncate">{@text}</span>
    </span>
    """
  end

  defp identifier_icon(%MediaSource{source_type: :filesystem}), do: :folder
  defp identifier_icon(%MediaSource{source_type: :radarr}), do: :link

  defp identifier_text(%MediaSource{
         source_type: :filesystem,
         implementation: %FilesystemMediaSource{filesystem_path: path}
       }),
       do: path

  defp identifier_text(%MediaSource{
         source_type: :radarr,
         implementation: %RadarrMediaSource{base_url: url, root_folder_path: root}
       }) do
    "#{strip_scheme(url)} · #{root}"
  end

  defp strip_scheme(url), do: WatchClubWeb.Helpers.Url.strip_scheme(url)
end
