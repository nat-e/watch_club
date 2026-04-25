defmodule WatchClub.Generator do
  use Ash.Generator
  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Invitation, Membership}

  def email do
    sequence(:email, fn i -> "user#{i}@test.com" end)
  end

  def user(opts \\ []) do
    changeset_generator(
      User,
      :register_with_password,
      defaults: [
        email: email(),
        password: "passw0rd",
        password_confirmation: "passw0rd"
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def club(opts \\ []) do
    changeset_generator(
      Club,
      :create,
      defaults: [
        name: sequence(:name, fn i -> "Club #{i}" end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def invitation(%Club{} = club, opts \\ []) do
    changeset_generator(
      Invitation,
      :create,
      defaults: [
        email: email(),
        club_id: club.id,
        role: :member
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def membership(%Club{} = club, %User{} = user, opts \\ []) do
    changeset_generator(
      Membership,
      :create,
      defaults: [
        user_id: user.id,
        club_id: club.id,
        role: :member
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end
end
