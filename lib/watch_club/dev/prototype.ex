defmodule WatchClub.Dev.Prototype do
  @moduledoc "A local experiment: its metadata, pages and files, without loading its code."
  defstruct [
    :slug,
    :name,
    :description,
    :level,
    :directory,
    :updated_at,
    :error,
    pages: [],
    files: [],
    shared_files: []
  ]
end
