defmodule WatchClubWeb.Components.Medias.DownloadMenu do
  @moduledoc """
  Download for the files of a Movie, a TV Show Episode or a Sports Event. Its trigger downloads
  the only file straight away, or opens a menu of the files, each named by its resolution and its
  file name, and by its Parts when there are several.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Medias.VideoResolutionBadge

  attr :id, :string, required: true

  attr :parts, :list,
    required: true,
    doc: "the Parts, with their `videos`, each with its `media` and `default_video_track`"

  slot :trigger,
    required: true,
    doc: "Gets the link attributes that download the only file, or none when it opens the menu"

  def download_menu(assigns) do
    assigns = assign(assigns, files: files(assigns.parts), named?: length(assigns.parts) > 1)

    ~H"""
    <.download_files id={@id} files={@files} named?={@named?}>
      <:trigger :let={download_link}>{render_slot(@trigger, download_link)}</:trigger>
    </.download_files>
    """
  end

  attr :id, :string, required: true
  attr :files, :list, required: true
  attr :named?, :boolean, required: true
  slot :trigger, required: true

  defp download_files(%{files: [{video, _parts}]} = assigns) do
    assigns = assign(assigns, :video, video)

    ~H"""
    {render_slot(@trigger, %{href: ~p"/media/#{@video.id}/download", download: true})}
    """
  end

  defp download_files(assigns) do
    ~H"""
    <.dropdown_menu id={@id}>
      <:trigger>{render_slot(@trigger, %{})}</:trigger>
      <.dropdown_menu_item
        :for={{video, parts} <- @files}
        id={"#{@id}-#{video.id}"}
        href={~p"/media/#{video.id}/download"}
        download
        class="max-w-80"
      >
        <.video_resolution_badge video={video} size="sm" class="shrink-0" />
        <span class="flex min-w-0 flex-col">
          <span :if={@named?}>{Enum.map_join(parts, ", ", &Parts.name/1)}</span>
          <span class={["[overflow-wrap:anywhere]", @named? && "text-xs text-text-muted"]}>
            {Path.basename(video.media.path)}
          </span>
        </span>
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  # Each file once, with the Parts it holds, in the order of its first Part
  defp files(parts) do
    held = for part <- parts, video <- part.videos, do: {video, part}

    held
    |> Enum.uniq_by(fn {video, _part} -> video.id end)
    |> Enum.map(fn {video, _part} ->
      {video, for({other, part} <- held, other.id == video.id, do: part)}
    end)
  end
end
