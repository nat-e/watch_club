ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(WatchClub.Repo, :manual)

Mox.defmock(WatchClub.MediaSources.Import.ScannerMock, for: WatchClub.MediaSources.Import.Scanner)
Mox.defmock(WatchClub.Ffmpeg.ProbeMock, for: WatchClub.Ffmpeg.Probe)
