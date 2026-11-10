defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaPoster do
  @moduledoc """
  A Media's poster, and its Content's title, both from the Content's Preferred Content
  Localization. Without one, as for Books, the Content shows its original title, and an icon for
  its Media Type instead of a poster, as Unmatched Media show a question mark.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Media.MediaTypeBadge

  attr :media, Media, required: true, doc: "with its `content`'s `title` and `poster_path` loaded"
  attr :size, :string, values: ~w(sm lg), required: true

  def media_poster(assigns) do
    assigns = assign(assigns, :path, poster_path(assigns.media.content))

    ~H"""
    <.tmdb_poster
      :if={@path}
      path={@path}
      size={if @size == "sm", do: "w92", else: "w185"}
      class={["shrink-0 rounded-md!", @size == "sm" && "w-8", @size == "lg" && "w-20"]}
    />
    <div
      :if={!@path}
      class={[
        "grid aspect-2/3 shrink-0 place-items-center rounded-md bg-surface-inset text-text-muted",
        @size == "sm" && "w-8",
        @size == "lg" && "w-20"
      ]}
    >
      <Lucideicons.file_question_mark :if={!@media.content} class="size-icon-sm" />
      <.media_type_icon :if={@media.content} media_type={@media.type} class="size-icon-sm" />
    </div>
    """
  end

  @doc "A Content's title in the User's language, with its `title` loaded."
  def content_title(%Content{title: title}), do: title

  defp poster_path(%Content{poster_path: path}), do: path
  defp poster_path(_unmatched), do: nil
end
