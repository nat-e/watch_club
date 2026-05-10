defmodule WatchClub.Generator do
  use Ash.Generator
  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Invitation, Membership}
  alias WatchClub.Contents.{Book, Movie, TvShow}

  @default_password "passw0rd"
  @default_hashed_password (
                             {:ok, hash} =
                               AshAuthentication.BcryptProvider.hash(@default_password)

                             hash
                           )

  def email, do: sequence(:email, fn i -> "user#{i}@test.com" end)
  def username, do: sequence(:username, fn i -> "user_#{i}" end)

  def administrator(opts \\ []) do
    changeset_generator(
      User,
      :create_administrator,
      defaults: [
        username: username(),
        email: email(),
        password: "passw0rd",
        password_confirmation: "passw0rd",
        locale: :en_US
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def user(opts \\ []) do
    # Use seed generator to skip invitation
    seed_generator(
      %User{
        username: username(),
        hashed_password: @default_hashed_password,
        administrator?: false
      },
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

  def invitation(%Club{} = club, %User{} = inviter, opts \\ []) do
    changeset_generator(
      Invitation,
      :create,
      defaults: [
        name: sequence(:invitation_name, fn i -> "Invitation #{i}" end),
        club_id: club.id,
        accepted?: false,
        role: :member
      ],
      authorize?: false,
      actor: inviter,
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

  def book(opts \\ []) do
    changeset_generator(
      Book,
      :create,
      defaults: [
        original_title: sequence(:book_title, fn i -> "Book #{i}" end),
        hardcover_id: sequence(:hardcover_id, fn i -> i end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def movie(opts \\ []) do
    changeset_generator(
      Movie,
      :create,
      defaults: [
        original_title: sequence(:movie_title, fn i -> "Movie #{i}" end),
        tmdb_id: sequence(:tmdb_id, fn i -> i end)
      ],
      actor: opts[:actor],
      overrides: opts
    )
  end

  def tv_show(opts \\ []) do
    changeset_generator(
      TvShow,
      :create,
      defaults: [
        original_name: sequence(:tv_show_name, fn i -> "Show #{i}" end),
        tmdb_id: sequence(:tmdb_id, fn i -> i end),
        tvdb_id: sequence(:tvdb_id, fn i -> i end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end
end
