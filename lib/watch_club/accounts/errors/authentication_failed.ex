# Deliberately redefines ash_authentication_phoenix's implementation (expect a
# "redefining module" compile warning): theirs interpolates field names into an
# English sentence that cannot be a gettext msgid. Ours owns the message and is
# translated at render time, like the resource validation messages.
defimpl AshPhoenix.FormData.Error, for: AshAuthentication.Errors.AuthenticationFailed do
  use Gettext, backend: WatchClubWeb.Gettext

  def to_form_error(error) do
    [
      {error.field || :password, dgettext_noop("errors", "Your username or password is invalid"),
       []}
    ]
  end
end
