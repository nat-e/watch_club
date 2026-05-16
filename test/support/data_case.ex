defmodule WatchClub.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WatchClub.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  import Req.Test

  using do
    quote do
      import Ash.Test
      import WatchClub.DataCase
      import WatchClub.Generator
    end
  end

  setup :set_req_test_from_context
  setup :verify_on_exit!

  setup tags do
    WatchClub.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(WatchClub.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  def tmdb_fixture(name) do
    Path.join([__DIR__, "fixtures", "tmdb", "#{name}.json"])
    |> File.read!()
    |> Jason.decode!()
  end
end
