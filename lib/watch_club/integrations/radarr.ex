defmodule WatchClub.Integrations.Radarr do
  @moduledoc """
  High-level Radarr v3 API facade.
  """

  import WatchClub.Integrations.Radarr.Client

  alias WatchClub.Integrations.Radarr.{QualityProfile, RootFolder, Webhook}

  @doc """
  Returns the quality profiles defined on the Radarr server.
  """
  @spec list_quality_profiles(String.t(), String.t()) ::
          {:ok, [QualityProfile.t()]} | {:error, term()}
  def list_quality_profiles(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/qualityprofile") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &QualityProfile.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the root folders configured on the Radarr server.
  """
  @spec list_root_folders(String.t(), String.t()) ::
          {:ok, [RootFolder.t()]} | {:error, term()}
  def list_root_folders(base_url, api_key) do
    case get(base_url, api_key, "/api/v3/rootfolder") do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &RootFolder.from_api/1)}
      {:ok, _other} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  @doc """
  Asks Radarr to fire a `Test` event against the supplied webhook
  configuration. Radarr resolves the call synchronously and only
  returns 200 if the callback URL answered with a 2xx.

  Nothing is persisted on Radarr's side.
  """
  @spec test_webhook(String.t(), String.t(), Webhook.config()) ::
          {:ok, :verified} | {:error, term()}
  def test_webhook(base_url, api_key, config) do
    case post(base_url, api_key, "/api/v3/notification/test", Webhook.body(config)) do
      {:ok, _body} -> {:ok, :verified}
      {:error, _} = error -> error
    end
  end

  @doc """
  Creates a persistent Webhook notification on Radarr. Radarr also runs
  its own `Test` step before persisting, so a successful response means
  the callback URL was reachable at registration time.
  """
  @spec create_webhook(String.t(), String.t(), Webhook.config()) ::
          {:ok, %{id: integer()}} | {:error, term()}
  def create_webhook(base_url, api_key, config) do
    case post(base_url, api_key, "/api/v3/notification", Webhook.body(config)) do
      {:ok, %{"id" => id}} when is_integer(id) ->
        {:ok, %{id: id}}

      {:ok, _other} ->
        {:error, :invalid_response}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Deletes a Webhook notification by its Radarr id. A 404 from Radarr is
  treated as success so the operation stays idempotent.
  """
  @spec delete_webhook(String.t(), String.t(), integer()) ::
          {:ok, :deleted} | {:error, term()}
  def delete_webhook(base_url, api_key, notification_id) when is_integer(notification_id) do
    case delete(base_url, api_key, "/api/v3/notification/#{notification_id}") do
      {:ok, _body} -> {:ok, :deleted}
      {:error, :not_found} -> {:ok, :deleted}
      {:error, _} = error -> error
    end
  end
end
