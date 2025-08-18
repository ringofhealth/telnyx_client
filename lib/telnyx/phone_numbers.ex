defmodule Telnyx.PhoneNumbers do
  @moduledoc """
  Phone number management for Telnyx API.

  Provides functions to search, buy, and manage phone numbers.
  """

  alias Telnyx.Client.FinchClient

  @doc """
  Searches for available phone numbers.

  ## Examples

      iex> search_params = %{
      ...>   filter: %{
      ...>     country_code: "US",
      ...>     phone_number: %{starts_with: "+1416"}
      ...>   },
      ...>   page: %{size: 10}
      ...> }
      iex> Telnyx.PhoneNumbers.search_available(search_params, api_key)
      {:ok, [%{"phone_number" => "+14165551234", ...}, ...]}

  """
  @spec search_available(map(), String.t()) :: {:ok, [map()]} | {:error, Telnyx.Error.t()}
  def search_available(search_params, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    # Build query parameters
    query_params = build_search_query(search_params)
    url = "/available_phone_numbers?" <> URI.encode_query(query_params)

    case FinchClient.get(url, headers, 10_000) do
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
  Searches for available phone numbers by area code (simplified interface).

  ## Examples

      iex> Telnyx.PhoneNumbers.search_by_area_code("416", api_key)
      {:ok, [%{"phone_number" => "+14165551234", ...}, ...]}

  """
  @spec search_by_area_code(String.t(), String.t()) :: {:ok, [map()]} | {:error, Telnyx.Error.t()}
  def search_by_area_code(area_code, api_key) do
    search_params = %{
      filter: %{
        country_code: "US",
        phone_number: %{starts_with: "+1#{area_code}"}
      },
      page: %{size: 10}
    }

    search_available(search_params, api_key)
  end

  @doc """
  Purchases a phone number.

  ## Examples

      iex> Telnyx.PhoneNumbers.buy("+14165551234", api_key)
      {:ok, %{"phone_number" => "+14165551234", "status" => "purchased", ...}}

  """
  @spec buy(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def buy(phone_number, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    params = %{phone_number: phone_number}

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.post("/phone_number_orders", headers, body, 10_000) do
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
  Gets information about a specific phone number.
  """
  @spec get(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def get(phone_number_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/phone_numbers/#{phone_number_id}", headers, 10_000) do
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
  Lists all phone numbers for the account.
  """
  @spec list(String.t()) :: {:ok, [map()]} | {:error, Telnyx.Error.t()}
  def list(api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/phone_numbers", headers, 10_000) do
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
  Updates a phone number (e.g., assigns to messaging profile).

  ## Examples

      iex> updates = %{messaging_profile_id: "profile-123"}
      iex> Telnyx.PhoneNumbers.update("phone-number-id", updates, api_key)
      {:ok, %{"messaging_profile_id" => "profile-123", ...}}

  """
  @spec update(String.t(), map(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def update(phone_number_id, params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch("/phone_numbers/#{phone_number_id}", headers, body, 10_000) do
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
  Assigns a phone number to a messaging profile.

  ## Examples

      iex> Telnyx.PhoneNumbers.assign_to_messaging_profile("phone-id", "profile-123", api_key)
      {:ok, %{"messaging_profile_id" => "profile-123", ...}}

  """
  @spec assign_to_messaging_profile(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def assign_to_messaging_profile(phone_number_id, messaging_profile_id, api_key) do
    update(phone_number_id, %{messaging_profile_id: messaging_profile_id}, api_key)
  end

  @doc """
  Finds a phone number by its actual phone number string.

  ## Examples

      iex> Telnyx.PhoneNumbers.find_by_number("+14165551234", api_key)
      {:ok, %{"id" => "phone-id", "phone_number" => "+14165551234", ...}}

  """
  @spec find_by_number(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def find_by_number(phone_number, api_key) do
    case list(api_key) do
      {:ok, phone_numbers} ->
        case Enum.find(phone_numbers, fn pn -> pn["phone_number"] == phone_number end) do
          nil -> {:error, Telnyx.Error.validation("Phone number not found", code: "phone_number_not_found")}
          phone_number_record -> {:ok, phone_number_record}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Searches for and purchases the first available phone number in an area code.

  ## Examples

      iex> Telnyx.PhoneNumbers.search_and_buy_first("416", api_key)
      {:ok, %{"phone_number" => "+14165551234", "status" => "purchased", ...}}

  """
  @spec search_and_buy_first(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def search_and_buy_first(area_code, api_key) do
    case search_by_area_code(area_code, api_key) do
      {:ok, []} ->
        {:error, Telnyx.Error.validation("No available numbers in area code #{area_code}")}

      {:ok, [first_number | _]} ->
        buy(first_number["phone_number"], api_key)

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  defp build_search_query(search_params) do
    search_params
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