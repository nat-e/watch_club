defmodule WatchClubWeb.Components.Media.FilesystemPath do
  @moduledoc """
  Inline chip that displays a filesystem path with a folder icon and a code-style
  inset surface. Truncates to its container width and works inline inside
  sentences (modal descriptions) or as a standalone element next to a label
  (cards, headers).
  """
  use WatchClubWeb, :component

  attr :path, :string, required: true
  attr :class, :any, default: nil

  def filesystem_path(assigns) do
    ~H"""
    <span class={[
      "inline-flex min-w-0 items-center gap-tight rounded-control border border-border-subtle bg-surface-inset px-related py-tight font-mono text-sm text-text align-middle",
      @class
    ]}>
      <Lucideicons.folder class="size-icon-sm shrink-0 text-text-muted" />
      <span class="truncate">{@path}</span>
    </span>
    """
  end
end
