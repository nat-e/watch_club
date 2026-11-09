defmodule WatchClubWeb.Components.Medias.VideoDownload do
  @moduledoc """
  Download for the Videos of a Movie or a TV Show Episode. Its control downloads the only Video, or
  opens a menu to choose one by its resolution, size and file name, the best first. It leaves out a
  Video whose file is gone, until the next scan removes its Media.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Medias.VideoResolutionBadge

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.MediaCatalog.VideoResolution

  @doc """
  What the menu needs loaded on each of the `videos` it's given.
  """
  def videos_load, do: [:default_video_track, media: [:file_name, :file_size]]

  attr :id, :string, required: true
  attr :videos, :list, required: true, doc: "with `videos_load/0`, intentionally small"
  attr :locale, :atom, required: true

  slot :trigger,
    required: true,
    doc:
      "the control, given the attributes that make it download the only Video, or none when it opens the menu"

  def video_download(assigns) do
    assigns =
      update(assigns, :videos, fn videos ->
        videos
        |> Enum.filter(& &1.media.file_size)
        |> Enum.sort_by(
          fn video ->
            resolution = video.default_video_track.resolution

            {Enum.find_index(VideoResolution.values(), &(&1 == resolution)),
             video.media.file_size}
          end,
          :desc
        )
      end)

    ~H"""
    <%= case @videos do %>
      <% [] -> %>
      <% [video] -> %>
        {render_slot(@trigger, %{href: ~p"/download/#{video.id}", download: true})}
      <% videos -> %>
        <.dropdown_menu id={@id}>
          <:trigger>{render_slot(@trigger, %{})}</:trigger>
          <.dropdown_menu_item
            :for={video <- videos}
            id={"#{@id}-#{video.id}"}
            href={~p"/download/#{video.id}"}
            download
            class="max-w-[min(28rem,calc(100vw-2rem))]"
          >
            <span class="flex min-w-0 flex-1 flex-col gap-tight">
              <span class="flex items-center justify-between gap-related">
                <.video_resolution_badge video={video} size="sm" />
                <span class="tabular-nums">{file_size(video.media.file_size, @locale)}</span>
              </span>
              <span class="break-all text-xs text-text-muted">{video.media.file_name}</span>
            </span>
          </.dropdown_menu_item>
        </.dropdown_menu>
    <% end %>
    """
  end

  # "8.2 GB", or "734 MB" under a gigabyte, in the User's language
  defp file_size(bytes, locale) do
    {value, unit} =
      if bytes >= 999_500_000,
        do: {Float.round(bytes / 1_000_000_000, 1), :gigabyte},
        else: {round(bytes / 1_000_000), :megabyte}

    value
    |> WatchClub.Cldr.Unit.new!(unit)
    |> WatchClub.Cldr.Unit.to_string!(
      style: :short,
      locale: UserLocale.to_cldr_locale_name(locale)
    )
  end
end
