defmodule Telnyx.OutboundVoiceProfiles do
  @moduledoc """
  Outbound Voice Profile management for Telnyx API.

  Outbound Voice Profiles are required to make outbound calls (transfers, refers, dials).
  They control:
  - Billing method
  - Allowed destinations (US/Canada by default, international optional)
  - Concurrent call limits

  ## Examples

      # Create a profile
      {:ok, profile} = Telnyx.OutboundVoiceProfiles.create(%{
        name: "violet-nexus-production",
        traffic_type: "conversational"
      }, api_key)

      # Assign to a Call Control Application
      Telnyx.CallControlApplication.update(app_id, %{
        outbound_voice_profile_id: profile["id"]
      }, api_key)

  """

  alias Telnyx.Client.FinchClient

  @type t :: map()

  @doc """
  Creates a new Outbound Voice Profile.

  ## Parameters

  - `name` (required) - A user-assigned name for the profile
  - `traffic_type` - Type of traffic: "conversational" (default) or "short_duration"
  - `service_plan` - Service plan: "us", "international", "global"
  - `concurrent_call_limit` - Max concurrent outbound calls (optional)
  - `enabled` - Whether profile is enabled (default: true)
  - `tags` - List of tags for the profile

  ## Examples

      iex> params = %{
      ...>   name: "violet-nexus-production",
      ...>   traffic_type: "conversational"
      ...> }
      iex> Telnyx.OutboundVoiceProfiles.create(params, api_key)
      {:ok, %{"id" => "...", "name" => "violet-nexus-production", ...}}

  """
  @spec create(map(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def create(params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.post("/outbound_voice_profiles", headers, body, 10_000) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            case Jason.decode(response_body) do
              {:ok, %{"data" => data}} -> {:ok, data}
              {:ok, _response} -> {:error, Telnyx.Error.api("Unexpected response format")}
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
  Retrieves an Outbound Voice Profile by ID.
  """
  @spec get(String.t(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def get(profile_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/outbound_voice_profiles/#{profile_id}", headers, 10_000) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => data}} -> {:ok, data}
          {:ok, _response} -> {:error, Telnyx.Error.api("Unexpected response format")}
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
  Lists all Outbound Voice Profiles.

  Supports optional filters and pagination:

      Telnyx.OutboundVoiceProfiles.list(api_key,
        filter: %{name: "violet-nexus"},
        page: %{size: 20, number: 1}
      )
  """
  @spec list(String.t(), keyword()) :: {:ok, [t()]} | {:error, Telnyx.Error.t()}
  def list(api_key, opts \\ []) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    query_params =
      opts
      |> Enum.into(%{})
      |> build_query_params()

    path =
      case query_params do
        [] -> "/outbound_voice_profiles"
        _ -> "/outbound_voice_profiles?" <> URI.encode_query(query_params)
      end

    case FinchClient.get(path, headers, 10_000) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => data}} -> {:ok, data}
          {:ok, _response} -> {:error, Telnyx.Error.api("Unexpected response format")}
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
  Finds an Outbound Voice Profile by name.

  ## Examples

      iex> Telnyx.OutboundVoiceProfiles.find_by_name("violet-nexus-production", api_key)
      {:ok, %{"id" => "...", "name" => "violet-nexus-production"}}

      iex> Telnyx.OutboundVoiceProfiles.find_by_name("nonexistent", api_key)
      {:error, %Telnyx.Error{type: :validation, message: "Outbound voice profile not found"}}

  """
  @spec find_by_name(String.t(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def find_by_name(name, api_key) do
    case list(api_key) do
      {:ok, profiles} ->
        case Enum.find(profiles, fn profile -> profile["name"] == name end) do
          nil ->
            {:error,
             Telnyx.Error.validation("Outbound voice profile not found",
               code: "outbound_voice_profile_not_found"
             )}

          profile ->
            {:ok, profile}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Updates an Outbound Voice Profile.
  """
  @spec update(String.t(), map(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def update(profile_id, params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch("/outbound_voice_profiles/#{profile_id}", headers, body, 10_000) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            case Jason.decode(response_body) do
              {:ok, %{"data" => data}} -> {:ok, data}
              {:ok, _response} -> {:error, Telnyx.Error.api("Unexpected response format")}
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
  Deletes an Outbound Voice Profile.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, Telnyx.Error.t()}
  def delete(profile_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.delete("/outbound_voice_profiles/#{profile_id}", headers, 10_000) do
      {:ok, %{status: status, body: _response_body}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: response_body}} ->
        parse_error_response(response_body, status)

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Creates or updates an Outbound Voice Profile by name (idempotent operation).

  If a profile with the given name exists, it will be updated.
  Otherwise, a new profile will be created.

  ## Examples

      iex> params = %{
      ...>   name: "violet-nexus-production",
      ...>   traffic_type: "conversational"
      ...> }
      iex> Telnyx.OutboundVoiceProfiles.create_or_update(params, api_key)
      {:ok, %{"id" => "...", "name" => "violet-nexus-production", ...}}

  """
  @spec create_or_update(map(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def create_or_update(%{"name" => name} = params, api_key) do
    case find_by_name(name, api_key) do
      {:ok, existing_profile} ->
        # Update existing profile
        update_params = Map.delete(params, "name")
        update(existing_profile["id"], update_params, api_key)

      {:error, %Telnyx.Error{code: "outbound_voice_profile_not_found"}} ->
        # Create new profile
        create(params, api_key)

      {:error, error} ->
        {:error, error}
    end
  end

  def create_or_update(%{name: _name} = params, api_key) do
    # Handle atom keys
    string_params = params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
    create_or_update(string_params, api_key)
  end

  # Private helpers

  defp build_query_params(%{} = params) do
    params
    |> flatten_nested_params()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp flatten_nested_params(params, prefix \\ "") do
    Enum.flat_map(params, fn {key, value} ->
      param_key = if prefix == "", do: to_string(key), else: "#{prefix}[#{key}]"

      case value do
        %{} = nested_map ->
          flatten_nested_params(nested_map, param_key)

        _ ->
          [{param_key, value}]
      end
    end)
  end

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
