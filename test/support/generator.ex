defmodule WatchClub.Generator do
  use Ash.Generator
  alias WatchClub.Accounts.{InvitationCode, User, UserSettings}
  alias WatchClub.Clubs.{Club, Library, LibraryIcon, Membership}
  alias WatchClub.Contents.{Book, Content, ContentIdentity, TvShow}
  alias WatchClub.MediaSources.{Import, Source}

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
    {locale, opts} = Keyword.pop(opts, :locale, :en_US)

    # Use seed generator to skip invitation
    seed_generator(
      %User{
        username: username(),
        hashed_password: @default_hashed_password,
        administrator?: false
      },
      overrides: opts,
      after_action: fn user ->
        settings =
          Ash.Seed.seed!(UserSettings, %{
            user_id: user.id,
            locale: locale
          })

        %{user | settings: settings}
      end
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

  def invitation_code(opts \\ []) do
    changeset_generator(
      InvitationCode,
      :create,
      defaults: [
        code: sequence(:invitation_code, fn i -> "CODE_#{i}" end),
        club_ids: [],
        max_uses: nil
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: Keyword.drop(opts, [:actor])
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

  def library(%Club{} = club, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, :movie)

    seed_generator(
      %Library{
        name: sequence(:library_name, fn i -> "Library #{i}" end),
        club_id: club.id,
        content_type: content_type,
        icon: Keyword.get(opts, :icon, LibraryIcon.default_for_content_type(content_type)),
        index: sequence(:library_index, fn i -> i end)
      },
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
    library_ids = Keyword.get(opts, :library_ids)
    actor = opts[:actor]

    tmdb_id =
      case Keyword.fetch(opts, :tmdb_id) do
        {:ok, id} -> StreamData.constant(id)
        :error -> sequence(:tmdb_id, fn i -> i end)
      end

    changeset_generator(
      Content,
      :create,
      defaults: [content_identity: StreamData.map(tmdb_id, &ContentIdentity.for_movie/1)],
      authorize?: false,
      actor: actor,
      after_action: fn content ->
        # Library selection moved out of create into set_libraries; mirror that
        # here so callers can still seed a movie straight into club libraries.
        if library_ids do
          WatchClub.Contents.set_club_libraries!(content, %{library_ids: library_ids},
            actor: actor,
            authorize?: false
          )
        else
          content
        end
      end
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

  def media_source(opts \\ []) do
    changeset_generator(
      Source,
      :create_filesystem,
      defaults: [
        media_type: :movie,
        filesystem_path:
          sequence(:media_source_filesystem_path, fn i -> "tmp/media-imports/#{i}" end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def media_import(%Source{} = media_source, opts \\ []) do
    {status, opts} = Keyword.pop(opts, :status, :processing)

    seed_generator(
      %Import{
        media_source_id: media_source.id,
        status: status,
        refresh_metadata?: false,
        triggered_manually?: true
      },
      overrides: opts
    )
  end
end
