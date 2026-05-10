defmodule WatchClub.Clubs.LibraryItemTest do
  use WatchClub.DataCase

  import WatchClub.Clubs

  alias WatchClub.Clubs.{Club, Invitation, LibraryItem, Membership}

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    # Add a member
    member = generate(user())
    generate(membership(club, member, role: :member))
    # book = generate(book())
    movie = generate(movie())
    # show = generate(tv_show())

    {:ok, admin: admin, club: club, member: member, movie: movie}
  end

  describe "add_content_to_club/*" do
    test "adds a movie to a club", %{admin: admin, club: club, movie: movie} do
      admin_id = admin.id
      club_id = club.id
      movie_id = movie.id

      assert %LibraryItem{
               club_id: ^club_id,
               content_id: ^movie_id,
               added_by_id: ^admin_id
             } =
               add_content_to_club!(club.id, movie.id, actor: admin)
    end

    test "only members can add contents", %{club: club, movie: movie} do
      other_user = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        add_content_to_club!(club.id, movie.id, actor: other_user)
      end
    end
  end
end
