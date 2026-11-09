defmodule WatchClubWeb.Components.Medias.VideoDownload do
  @moduledoc """
  Download for the Videos of a Movie or a TV Show Episode. Its control downloads the only Video, or
  opens a menu to choose one by its resolution, size and file name.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Medias.VideoResolutionBadge

  alias WatchClub.Accounts.UserLocale

  attr :id, :string, required: true

  attr :videos, :list,
    required: true,
    doc: "with `:default_video_track` and `media: [:file_name, :file_size]`, intentionally small"

  attr :locale, :atom, required: true

  slot :trigger,
    required: true,
    doc:
      "the control, given the attributes that make it download the only Video, or none when it opens the menu"

  def video_download(%{videos: [video]} = assigns) do
    assigns = assign(assigns, :href, ~p"/download/#{video.id}")

    ~H"""
    {render_slot(@trigger, %{href: @href, download: true})}
    """
  end

  def video_download(assigns) do
    ~H"""
    <.dropdown_menu id={@id}>
      <:trigger>{render_slot(@trigger, %{})}</:trigger>
      <.dropdown_menu_item
        :for={video <- Enum.sort_by(@videos, & &1.media.file_name)}
        id={"#{@id}-#{video.id}"}
        href={~p"/download/#{video.id}"}
        download
        class="max-w-[min(28rem,calc(100vw-2rem))]"
      >
        <.video_resolution_badge video={video} size="sm" />
        <span class="flex min-w-0 flex-col">
          <span :if={video.media.file_size}>{file_size(video.media.file_size, @locale)}</span>
          <span class="truncate text-xs text-text-muted">{video.media.file_name}</span>
        </span>
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  # "8.2 GB", or "734 MB" under a gigabyte, in the User's language
  defp file_size(bytes, locale) do
    {value, unit} =
      if bytes >= 1_000_000_000,
        do: {bytes / 1_000_000_000, :gigabyte},
        else: {bytes / 1_000_000, :megabyte}

    value
    |> Float.round(1)
    |> WatchClub.Cldr.Unit.new!(unit)
    |> WatchClub.Cldr.Unit.to_string!(
      style: :short,
      locale: UserLocale.to_cldr_locale_name(locale)
    )
  end
end
