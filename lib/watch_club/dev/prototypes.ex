defmodule WatchClub.Dev.Prototypes do
  @moduledoc "Lists and manages the experiments in this worktree's prototype folder."

  alias WatchClub.Dev.{Prototype, PrototypeRuntime}

  def root, do: Application.get_env(:watch_club, :prototype_root, Path.expand("dev/prototypes"))

  def list! do
    Path.wildcard(Path.join(root(), "*"))
    |> Enum.filter(&(File.dir?(&1) and not String.starts_with?(Path.basename(&1), "_")))
    |> Enum.map(&read_prototype!/1)
    |> Enum.reject(fn prototype ->
      prototype.files != [] and Enum.all?(prototype.files, &(Path.extname(&1) == ".bak"))
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get(slug), do: Enum.find(list!(), &(&1.slug == slug))

  def resolve(slug, page_path) do
    prototypes = list!()

    case Enum.find(prototypes, &(&1.slug == slug)) do
      nil ->
        Enum.find_value(prototypes, {:error, "Prototype not found"}, fn prototype ->
          case Enum.find(prototype.pages, &(slug in &1.aliases and page_path == "")) do
            nil -> nil
            page -> {:ok, prototype, page}
          end
        end)

      prototype ->
        case Enum.find(prototype.pages, &(&1.path == page_path)) do
          nil when not is_nil(prototype.error) -> {:error, prototype.error}
          nil -> {:error, "Prototype page not found"}
          page -> {:ok, prototype, page}
        end
    end
  end

  def page_path(prototype, page),
    do: "/dev/prototypes/#{prototype.slug}" <> if(page.path == "", do: "", else: "/#{page.path}")

  def delete(slug) do
    case get(slug) do
      nil ->
        {:error, "Prototype not found"}

      prototype ->
        case File.rm_rf(prototype.directory) do
          {:ok, _files} ->
            PrototypeRuntime.forget(slug)
            :ok

          {:error, reason, path} ->
            {:error,
             "Could not delete #{Path.relative_to(path, root())}: #{:file.format_error(reason)}"}
        end
    end
  end

  def create(slug) do
    cond do
      not is_binary(slug) or not Regex.match?(~r/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/, slug) ->
        {:error, "Use a name such as browse-layout, with lowercase letters, numbers and hyphens"}

      File.exists?(Path.join(root(), slug)) ->
        {:error, "A prototype named #{slug} already exists"}

      true ->
        directory = Path.join(root(), slug)
        name = slug |> String.split("-") |> Enum.map_join(" ", &String.capitalize/1)
        module = "WatchClubWeb.Prototypes.#{Macro.camelize(String.replace(slug, "-", "_"))}.Page"

        manifest =
          Jason.encode!(
            %{
              name: name,
              description:
                "Compare three layouts. Edit this description to state the experiment's goal.",
              level: "reshape",
              pages: [%{path: "", name: "Overview", module: module}]
            },
            pretty: true
          ) <> "\n"

        template = Path.join(:code.priv_dir(:watch_club), "prototypes/page.ex.eex")

        with :ok <- File.mkdir_p(root()),
             :ok <- File.mkdir(directory),
             {:ok, source} <- File.read(template),
             :ok <- File.write(Path.join(directory, "prototype.json"), manifest),
             :ok <-
               File.write(
                 Path.join(directory, "page.ex"),
                 EEx.eval_string(source, module: module, name: name)
               ) do
          {:ok, directory}
        else
          {:error, reason} ->
            {:error, "Could not create prototype: #{:file.format_error(reason)}"}
        end
    end
  end

  defp read_prototype!(directory) do
    slug = Path.basename(directory)
    files = Path.wildcard(Path.join(directory, "**/*")) |> Enum.filter(&File.regular?/1)
    updated_at = files |> Enum.map(&File.stat!(&1, time: :posix).mtime) |> Enum.max(fn -> 0 end)

    prototype = %Prototype{
      slug: slug,
      name: slug,
      directory: directory,
      files: files,
      updated_at: updated_at
    }

    with {:ok, json} <- File.read(Path.join(directory, "prototype.json")),
         {:ok, %{"name" => name, "pages" => pages} = manifest} <- Jason.decode(json),
         true <- is_binary(name) and is_list(pages) and pages != [],
         true <- Enum.all?(pages, &valid_page?/1),
         true <- length(Enum.uniq_by(pages, & &1["path"])) == length(pages),
         true <- is_nil(manifest["description"]) or is_binary(manifest["description"]),
         true <- manifest["level"] in [nil, "explore", "reshape", "polish"],
         shared when is_list(shared) <- Map.get(manifest, "shared", []),
         true <-
           Enum.all?(
             shared,
             &(is_binary(&1) and Path.basename(&1) == &1 and Path.extname(&1) == ".ex")
           ) do
      %{
        prototype
        | name: name,
          description: manifest["description"],
          level: manifest["level"],
          shared_files: Enum.map(shared, &Path.join([root(), "_shared", &1])),
          pages:
            Enum.map(pages, fn page ->
              %{
                path: page["path"],
                name: page["name"],
                module: page["module"],
                aliases: Map.get(page, "aliases", [])
              }
            end)
      }
    else
      _ ->
        %{
          prototype
          | error: "Check prototype.json: it needs a name and pages with path, name and module"
        }
    end
  end

  defp valid_page?(%{"path" => path, "name" => name, "module" => module} = page)
       when is_binary(path) and is_binary(name) and is_binary(module) do
    Regex.match?(~r/\A(?:[a-z0-9_-]+(?:\/[a-z0-9_-]+)*)?\z/, path) and
      String.starts_with?(module, "WatchClubWeb.Prototypes.") and
      is_list(Map.get(page, "aliases", [])) and
      Enum.all?(Map.get(page, "aliases", []), &is_binary/1)
  end

  defp valid_page?(_page), do: false
end
