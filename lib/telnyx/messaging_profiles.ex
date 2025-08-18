defmodule Telnyx.MessagingProfiles do
  @moduledoc """
  Messaging profile management for Telnyx API.

  Provides functions to create, retrieve, update, and delete messaging profiles.
  """

  alias Telnyx.Client.FinchClient

  @doc """
  Creates a new messaging profile.

  ## Examples

      iex> params = %{
      ...>   name: "My App Notifications",
      ...>   webhook_url: "https://example.com/webhooks",
      ...>   webhook_api_version: "2"
      ...> }
      iex> Telnyx.MessagingProfiles.create(params, api_key)
      {:ok, %{"id" => "profile-123", "name" => "My App Notifications", ...}}

  """
  @spec create(map(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def create(params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.post("/messaging_profiles", headers, body, 10_000) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            case Jason.decode(response_body) do
              {:ok, %{"data" => data}} -> {:ok, data}
              {:ok, response} -> {:error, Telnyx.Error.api("Unexpected response format")}
              {:error, _} -> {:error, Telnyx.Error.api("Invalid JSON response")}
            end

          {:ok, %{status: status, body: response_body}} ->
            parse_error_response(response_body, status)

          {:error, :timeout} ->
            {:error, Telnyx.Error.network("Request timeout")}

          {:error, reason} ->
            {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:error, Telnyx.Error.unknown("JSON encoding failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Retrieves a messaging profile by ID.
  """
  @spec get(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def get(profile_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/messaging_profiles/#{profile_id}", headers, 10_000) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => data}} -> {:ok, data}
          {:ok, response} -> {:error, Telnyx.Error.api("Unexpected response format")}
          {:error, _} -> {:error, Telnyx.Error.api("Invalid JSON response")}
        end

      {:ok, %{status: status, body: response_body}} ->
        parse_error_response(response_body, status)

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Lists all messaging profiles.
  """
  @spec list(String.t()) :: {:ok, [map()]} | {:error, Telnyx.Error.t()}
  def list(api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/messaging_profiles", headers, 10_000) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => data}} -> {:ok, data}
          {:ok, response} -> {:error, Telnyx.Error.api("Unexpected response format")}
          {:error, _} -> {:error, Telnyx.Error.api("Invalid JSON response")}
        end

      {:ok, %{status: status, body: response_body}} ->
        parse_error_response(response_body, status)

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Finds a messaging profile by name.

  ## Examples

      iex> Telnyx.MessagingProfiles.find_by_name("My App Notifications", api_key)
      {:ok, %{"id" => "profile-123", "name" => "My App Notifications"}}

      iex> Telnyx.MessagingProfiles.find_by_name("Nonexistent", api_key)
      {:error, %Telnyx.Error{type: :validation, message: "Profile not found"}}

  """
  @spec find_by_name(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def find_by_name(name, api_key) do
    case list(api_key) do
      {:ok, profiles} ->
        case Enum.find(profiles, fn profile -> profile["name"] == name end) do
          nil -> {:error, Telnyx.Error.validation("Profile not found", code: "profile_not_found")}
          profile -> {:ok, profile}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Updates a messaging profile.
  """
  @spec update(String.t(), map(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def update(profile_id, params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch("/messaging_profiles/#{profile_id}", headers, body, 10_000) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            case Jason.decode(response_body) do
              {:ok, %{"data" => data}} -> {:ok, data}
              {:ok, response} -> {:error, Telnyx.Error.api("Unexpected response format")}
              {:error, _} -> {:error, Telnyx.Error.api("Invalid JSON response")}
            end

          {:ok, %{status: status, body: response_body}} ->
            parse_error_response(response_body, status)

          {:error, :timeout} ->
            {:error, Telnyx.Error.network("Request timeout")}

          {:error, reason} ->
            {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:error, Telnyx.Error.unknown("JSON encoding failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Creates or updates a messaging profile by name (idempotent operation).

  ## Examples

      iex> params = %{
      ...>   name: "My App Notifications",
      ...>   webhook_url: "https://example.com/webhooks"
      ...> }
      iex> Telnyx.MessagingProfiles.create_or_update(params, api_key)
      {:ok, %{"id" => "profile-123", "name" => "My App Notifications", ...}}

  """
  @spec create_or_update(map(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def create_or_update(%{"name" => name} = params, api_key) do
    case find_by_name(name, api_key) do
      {:ok, existing_profile} ->
        # Update existing profile
        update_params = Map.delete(params, "name")
        update(existing_profile["id"], update_params, api_key)

      {:error, %Telnyx.Error{code: "profile_not_found"}} ->
        # Create new profile
        create(params, api_key)

      {:error, error} ->
        {:error, error}
    end
  end

  def create_or_update(%{name: name} = params, api_key) do
    # Handle atom keys
    string_params = params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
    create_or_update(string_params, api_key)
  end

  # Private helper functions

  defp parse_error_response(response_body, status_code) do
    case Jason.decode(response_body) do
      {:ok, %{"errors" => [error | _]}} ->
        {:error, Telnyx.Error.from_response(error, status_code)}

      {:ok, %{"error" => error}} ->
        {:error, Telnyx.Error.from_response(error, status_code)}

      {:ok, _response} ->
        {:error, Telnyx.Error.api("Unexpected error response", status_code: status_code)}

      {:error, _reason} ->
        {:error, Telnyx.Error.api("Invalid error response", status_code: status_code)}
    end
  end
end