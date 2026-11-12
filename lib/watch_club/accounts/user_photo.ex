defmodule WatchClub.Accounts.UserPhoto do
  @moduledoc """
  The files of Users' photos, in the app data folder. Each photo is re-encoded as a 256px square
  WebP without metadata, and named by its revision: a new photo never overwrites the one shown.
  """

  @size 256

  # The browser sends a 512px crop, so a bigger image isn't one. Checked before decoding, as a
  # small file can decode into a huge image.
  @max_pixels 4096 * 4096

  @loaders ~w(VipsForeignLoadJpegFile VipsForeignLoadPngFile VipsForeignLoadWebpFile)

  @doc "Stores the JPEG, PNG or WebP image at `source_path` as a new photo"
  @spec store(Path.t()) :: {:ok, revision :: Ecto.UUID.t()} | {:error, :unreadable}
  def store(source_path) do
    revision = Ash.UUIDv7.generate()
    File.mkdir_p!(dir())

    with {:ok, loader} when loader in @loaders <- Vix.Vips.Foreign.find_load(source_path),
         {:ok, image} <- Image.open(source_path, fail_on: :error),
         true <- Image.width(image) * Image.height(image) <= @max_pixels,
         {:ok, photo} <- Image.thumbnail(image, @size, crop: :center),
         {:ok, _photo} <- Image.write(photo, path(revision), strip_metadata: true) do
      {:ok, revision}
    else
      _unreadable ->
        delete(revision)
        {:error, :unreadable}
    end
  end

  @doc "The file of a photo. A revision comes from the URL, so anything but a UUID raises."
  @spec path(Ecto.UUID.t()) :: Path.t()
  def path(revision), do: Path.join(dir(), "#{Ecto.UUID.cast!(revision)}.webp")

  @doc "Deletes a photo's file, if any"
  @spec delete(Ecto.UUID.t() | nil) :: :ok
  def delete(nil), do: :ok

  def delete(revision) do
    File.rm(path(revision))
    :ok
  end

  defp dir, do: Path.join(Application.fetch_env!(:watch_club, :app_data), "user_photos")
end
