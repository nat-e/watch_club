ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(WatchClub.Repo, :manual)

Mox.defmock(WatchClub.Media.ImportPipelineMock, for: WatchClub.Media.ImportPipeline)
Mox.defmock(WatchClub.Media.FfprobeMock, for: WatchClub.Media.Ffmpeg.Probe)
