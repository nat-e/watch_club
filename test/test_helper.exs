ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(WatchClub.Repo, :manual)

Mox.defmock(WatchClub.Media.ImportPipelineMock, for: WatchClub.Media.ImportPipeline)
