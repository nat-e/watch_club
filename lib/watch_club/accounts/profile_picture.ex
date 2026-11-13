defmodule WatchClub.Accounts.ProfilePicture do
  @moduledoc """
  The files of Users' profile pictures, in the app data folder. Each one is re-encoded as a 256px
  square WebP without metadata, and named by its revision: a new profile picture never
  overwrites the one shown.
  """

  require Logger

  @size 256

  # The browser sends a 512px crop, so a bigger image isn't one. Checked before decoding, as a
  # small file can decode into a huge image.
  @max_pixels 4096 * 4096

  @loaders ~w(VipsForeignLoadJpegFile VipsForeignLoadPngFile VipsForeignLoadWebpFile)

  @doc """
  Stores the JPEG, PNG or WebP image at `source_path` as a new profile picture. The browser always
  sends a readable crop, so an unreadable one is logged as an error.
  """
  @spec store(Path.t()) :: {:ok, revision :: Ecto.UUID.t()} | {:error, :unreadable}
  def store(source_path) do
    revision = Ash.UUIDv7.generate()
    File.mkdir_p!(dir())

    with {:ok, loader} <- Vix.Vips.Foreign.find_load(source_path),
         :ok <- if(loader in @loaders, do: :ok, else: {:error, {:unsupported_format, loader}}),
         {:ok, image} <- Image.open(source_path, fail_on: :error),
         pixels = Image.width(image) * Image.height(image),
         :ok <- if(pixels <= @max_pixels, do: :ok, else: {:error, {:too_many_pixels, pixels}}),
         {:ok, picture} <- Image.thumbnail(image, @size, crop: :center),
         {:ok, _picture} <- Image.write(picture, path!(revision), strip_metadata: true) do
      {:ok, revision}
    else
      {:error, reason} ->
        Logger.error("Profile picture — Couldn't store an image: #{inspect(reason)}",
          event: :profile_picture_unreadable,
          error: inspect(reason)
        )

        delete(revision)
        {:error, :unreadable}
    end
  end

  @doc "The file of a profile picture. A revision comes from the URL, so anything but a UUID raises."
  @spec path!(Ecto.UUID.t()) :: Path.t()
  def path!(revision), do: Path.join(dir(), "#{Ecto.UUID.cast!(revision)}.webp")

  @doc "Deletes a profile picture's file, if any"
  @spec delete(Ecto.UUID.t() | nil) :: :ok
  def delete(nil), do: :ok

  # A file that can't be deleted stays on disk, unused
  def delete(revision) do
    case File.rm(path!(revision)) do
      {:error, reason} when reason != :enoent ->
        Logger.warning("Profile picture — Couldn't delete #{revision}: #{inspect(reason)}",
          event: :profile_picture_not_deleted,
          error: inspect(reason)
        )

      _deleted_or_missing ->
        :ok
    end

    :ok
  end

  defp dir, do: Path.join(Application.fetch_env!(:watch_club, :app_data), "profile_pictures")
end
