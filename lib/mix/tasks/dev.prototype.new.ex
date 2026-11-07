defmodule Mix.Tasks.Dev.Prototype.New do
  @shortdoc "Creates a local prototype: an app page with floating, URL-based variation controls"
  @moduledoc """
  Run `mix dev.prototype.new browse-layout`, then open `/dev/prototypes/browse-layout`.
  Files are written into the Git-ignored `dev/prototypes/browse-layout/` folder.
  """
  use Mix.Task

  @impl true
  def run([slug]) do
    Mix.Task.run("compile")

    case WatchClub.Dev.Prototypes.create(slug) do
      {:ok, directory} -> Mix.shell().info("Created #{directory}\nOpen /dev/prototypes/#{slug}")
      {:error, error} -> Mix.raise(error)
    end
  end

  def run(_args), do: Mix.raise("Usage: mix dev.prototype.new <name>")
end
