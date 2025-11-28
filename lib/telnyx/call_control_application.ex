defmodule Telnyx.CallControlApplication do
  @moduledoc """
  Management of Telnyx Call Control Applications.

  Wraps the Call Control Applications API for creating, listing, updating,
  and deleting call control applications.

  The Call Control Application `id` is also used as the `connection_id` when
  assigning phone numbers.
  """

  alias Telnyx.Client.FinchClient

  @type t :: map()

  @doc """
  Creates a new Call Control Application.

  ## Examples

      iex> params = %{
      ...>   application_name: "violet-nexus-call-router-production",
      ...>   webhook_event_url: "https://example.com/webhooks/telnyx/inbound",
      ...>   webhook_api_version: "2"
      ...> }
      iex> Telnyx.CallControlApplication.create(params, api_key)
      {:ok, %{"id" => id, "application_name" => "violet-nexus-call-router-production", ...}}

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
        case FinchClient.post("/call_control_applications", headers, body, 10_000) do
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
  Retrieves a Call Control Application by ID.
  """
  @spec get(String.t(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def get(application_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/call_control_applications/#{application_id}", headers, 10_000) do
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
  Lists Call Control Applications.

  Supports optional filters and pagination via nested parameters, e.g.:

      Telnyx.CallControlApplication.list(api_key,
        filter: %{application_name: "violet-nexus"},
        page: %{size: 20, number: 1}
      )

  which maps to:

      GET /v2/call_control_applications?filter[application_name]=violet-nexus&page[size]=20&page[number]=1
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
        [] -> "/call_control_applications"
        _ -> "/call_control_applications?" <> URI.encode_query(query_params)
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
  Finds a Call Control Application by `application_name`.

  This is a convenience wrapper around `list/2` using the
  `filter[application_name]` parameter.
  """
  @spec find_by_application_name(String.t(), String.t()) ::
          {:ok, t()} | {:error, Telnyx.Error.t()}
  def find_by_application_name(application_name, api_key) do
    case list(api_key, filter: %{application_name: application_name}) do
      {:ok, [application | _]} ->
        {:ok, application}

      {:ok, []} ->
        {:error,
         Telnyx.Error.validation("Call Control application not found",
           code: "call_control_application_not_found"
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Updates a Call Control Application.
  """
  @spec update(String.t(), map(), String.t()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def update(application_id, params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch("/call_control_applications/#{application_id}", headers, body, 10_000) do
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
  Deletes a Call Control Application.

  Returns `:ok` on any successful 2xx response.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, Telnyx.Error.t()}
  def delete(application_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.delete("/call_control_applications/#{application_id}", headers, 10_000) do
      {:ok, %{status: status, body: _response_body}} when status in 200..299 ->
        # Telnyx typically returns 204 No Content; ignore body on success.
        :ok

      {:ok, %{status: status, body: response_body}} ->
        parse_error_response(response_body, status)

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
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
