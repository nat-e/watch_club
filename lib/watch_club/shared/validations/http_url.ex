defmodule WatchClub.Shared.Validations.HttpUrl do
  @moduledoc """
  Validates that a URL attribute is an `http` or `https` URL with a host.
  Req raises on any other URL, so run this before calling a URL the user
  typed. Run it after `NormalizeUrl`, which adds the missing `http://`.
  """
  use Ash.Resource.Validation
  use Gettext, backend: WatchClubWeb.Gettext

  @impl true
  def validate(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case URI.new(Ash.Changeset.get_attribute(changeset, attribute)) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and host not in [nil, ""] ->
        :ok

      _invalid ->
        {:error, field: attribute, message: dgettext_noop("errors", "This URL is not valid.")}
    end
  end
end
