defmodule WatchClub.Media.ImportPipeline do
  @moduledoc """
  Behaviour for defining a processing pipeline for importing Media.
  """
  alias WatchClub.Media.MediaImport

  @callback import_medias(MediaImport.t()) :: :ok | {:error, term()}
end
