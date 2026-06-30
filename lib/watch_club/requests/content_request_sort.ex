defmodule WatchClub.Requests.ContentRequestSort do
  @moduledoc """
  Sort options for the My Requests page (`ContentRequest.for_current_user`).

  Owns URL-param parsing and the sort applied to the query. `translated_label/1` drives the sort menu.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  @values [:last_update, :created]
  @params Map.new(@values, &{Atom.to_string(&1), &1})

  use Ash.Type.Enum, values: @values

  def default, do: :last_update

  def parse_param(sort) when is_nil(sort) or sort == "", do: default()
  def parse_param(sort) when is_binary(sort), do: Map.get(@params, sort, default())
  def parse_param(_sort), do: default()

  def to_param(sort), do: Atom.to_string(sort)

  def translated_label(:last_update), do: dgettext("content_request_sorts", "Last update")
  def translated_label(:created), do: dgettext("content_request_sorts", "Created")

  # "Last update" tracks the Media Source Requests' transitions (the request
  # row itself doesn't move), so it sorts on the latest activity across them.
  def sort_query(query, :last_update),
    do: Ash.Query.sort(query, updated_at: :desc, id: :desc)

  def sort_query(query, :created),
    do: Ash.Query.sort(query, inserted_at: :desc, id: :desc)
end
