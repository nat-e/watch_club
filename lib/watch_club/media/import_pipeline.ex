defmodule WatchClub.Media.ImportPipeline do
  @moduledoc """
  Behaviour for defining a processing pipeline for importing Media.
  """
  alias WatchClub.Media.ImportRun

  @callback import_medias(ImportRun.t()) :: :ok | {:error, term()}
end
