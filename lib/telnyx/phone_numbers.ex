defmodule Telnyx.PhoneNumbers do
  @moduledoc """
  Phone number management for Telnyx API.

  Provides functions to search, buy, and manage phone numbers.
  """

  alias Telnyx.Client.FinchClient

  @mutable_voice_fields ~w(
    tech_prefix_enabled
    translated_number
    caller_id_name_enabled
    call_forwarding
    cnam_listing
    usage_payment_method
    media_features
    call_recording
    inbound_call_screening
  )

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
  Gets voice settings for a phone number.

  This reads `/v2/phone_numbers/{id}/voice`, which includes carrier-side
  routing settings such as `call_forwarding`.
  """
  @spec get_voice(String.t(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def get_voice(phone_number_id, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.get("/phone_numbers/#{phone_number_id}/voice", headers, 10_000) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        decode_data_response(response_body)

      {:ok, %{status: status, body: response_body}} ->
        parse_error_response(response_body, status)

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Convenience variant of `get_voice/2` that resolves the API key from
  application config (`config :telnyx, api_key: ...`, optionally `{:system,
  "TELNYX_API_KEY"}`), matching the resolution used by `Telnyx.CallControl`.
  """
  @spec get_voice(String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def get_voice(phone_number_id) when is_binary(phone_number_id) do
    with {:ok, api_key} <- get_api_key() do
      get_voice(phone_number_id, api_key)
    end
  end

  @doc """
  Updates voice settings for a phone number.

  Callers should pass the complete mutable voice-settings payload they want
  Telnyx to persist. For call forwarding, prefer
  `set_call_forwarding/5`, which performs the read-modify-write needed to
  preserve unrelated voice settings.
  """
  @spec update_voice(String.t(), map(), String.t()) :: {:ok, map()} | {:error, Telnyx.Error.t()}
  def update_voice(phone_number_id, params, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch("/phone_numbers/#{phone_number_id}/voice", headers, body, 10_000) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            decode_data_response(response_body)

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
  Enables or disables call forwarding while preserving unrelated voice settings.
  """
  @spec set_call_forwarding(String.t(), boolean(), String.t() | nil, String.t(), String.t()) ::
          {:ok, map()} | {:error, Telnyx.Error.t()}
  def set_call_forwarding(phone_number_id, enabled?, forwards_to, forwarding_type, api_key)
      when is_boolean(enabled?) and is_binary(forwarding_type) do
    with {:ok, voice_settings} <- get_voice(phone_number_id, api_key) do
      phone_number_id
      |> update_voice(
        build_call_forwarding_payload(voice_settings, enabled?, forwards_to, forwarding_type),
        api_key
      )
    end
  end

  @doc """
  Convenience variant of `set_call_forwarding/5` that resolves the API key
  from application config, matching the resolution used by
  `Telnyx.CallControl`.
  """
  @spec set_call_forwarding(String.t(), boolean(), String.t() | nil, String.t()) ::
          {:ok, map()} | {:error, Telnyx.Error.t()}
  def set_call_forwarding(phone_number_id, enabled?, forwards_to, forwarding_type)
      when is_binary(phone_number_id) and is_boolean(enabled?) and is_binary(forwarding_type) do
    with {:ok, api_key} <- get_api_key() do
      set_call_forwarding(phone_number_id, enabled?, forwards_to, forwarding_type, api_key)
    end
  end

  @doc """
  Assigns a phone number to a messaging profile.

  ## Examples

      iex> Telnyx.PhoneNumbers.assign_to_messaging_profile("phone-id", "profile-123", api_key)
      {:ok, %{"messaging_profile_id" => "profile-123", ...}}

  """
  @spec assign_to_messaging_profile(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Telnyx.Error.t()}
  def assign_to_messaging_profile(phone_number_id, messaging_profile_id, api_key) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    params = %{messaging_profile_id: messaging_profile_id}

    case Jason.encode(params) do
      {:ok, body} ->
        case FinchClient.patch(
               "/phone_numbers/#{phone_number_id}/messaging",
               headers,
               body,
               10_000
             ) do
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
  Assigns a phone number to a Call Control Application.

  This sets the phone number's `connection_id` to the given Call Control
  Application `id`.

  The `phone_number_id` is the Telnyx UUID for the phone number. To look
  up a phone number by E.164 number, use `find_by_number/2` and then pass
  the returned `"id"` field to this function.

  ## Examples

      iex> {:ok, phone} = Telnyx.PhoneNumbers.find_by_number("+18555345529", api_key)
      iex> Telnyx.PhoneNumbers.assign_to_call_control_application(phone["id"], app_id, api_key)
      {:ok, %{"connection_id" => app_id, ...}}

  """
  @spec assign_to_call_control_application(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Telnyx.Error.t()}
  def assign_to_call_control_application(phone_number_id, call_control_application_id, api_key) do
    update(phone_number_id, %{connection_id: call_control_application_id}, api_key)
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
          nil ->
            {:error,
             Telnyx.Error.validation("Phone number not found", code: "phone_number_not_found")}

          phone_number_record ->
            {:ok, phone_number_record}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Resolves a phone number string to its Telnyx `phone_number_id`.

  Convenience wrapper around `find_by_number/2` that returns just the `"id"`
  of the matched record. The `phone_number_not_found` validation error from
  `find_by_number/2` and any other failure pass through as `%Telnyx.Error{}`
  so callers can pattern match against the existing error type.

  ## Examples

      iex> Telnyx.PhoneNumbers.find_phone_number_id("+14165551234", api_key)
      {:ok, "2922922584783717817"}

      iex> Telnyx.PhoneNumbers.find_phone_number_id("+10000000000", api_key)
      {:error, %Telnyx.Error{code: "phone_number_not_found"}}

  """
  @spec find_phone_number_id(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Telnyx.Error.t()}
  def find_phone_number_id(phone_number, api_key)
      when is_binary(phone_number) and is_binary(api_key) do
    with {:ok, record} <- find_by_number(phone_number, api_key) do
      extract_phone_number_id(record)
    end
  end

  @doc """
  Convenience variant of `find_phone_number_id/2` that resolves the API key
  from application config, matching the resolution used by
  `Telnyx.CallControl`.
  """
  @spec find_phone_number_id(String.t()) ::
          {:ok, String.t()} | {:error, Telnyx.Error.t()}
  def find_phone_number_id(phone_number) when is_binary(phone_number) do
    with {:ok, api_key} <- get_api_key() do
      find_phone_number_id(phone_number, api_key)
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

  defp decode_data_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"data" => data}} -> {:ok, data}
      {:ok, _response} -> {:error, Telnyx.Error.api("Unexpected response format")}
      {:error, _} -> {:error, Telnyx.Error.api("Invalid JSON response")}
    end
  end

  # Exposed for direct testing of payload semantics. Not part of the public
  # API — callers should use `set_call_forwarding/4` or `/5`.
  @doc false
  def build_call_forwarding_payload(voice_settings, enabled?, forwards_to, forwarding_type) do
    existing_forwarding = Map.get(voice_settings, "call_forwarding", %{})

    # When disabling, don't re-arm a previous destination by echoing the
    # stored value back. `enabled? == false` with `forwards_to == nil` lets
    # `reject_nil_values/1` drop the key from the PATCH payload, so Telnyx
    # keeps whatever it had stored but `call_forwarding_enabled: false`
    # gates routing regardless. When enabling without an explicit
    # destination, we fall back to the existing carrier value so callers
    # can flip `enabled? -> true` without re-specifying the number.
    effective_forwards_to =
      if enabled? do
        forwards_to || Map.get(existing_forwarding, "forwards_to")
      else
        forwards_to
      end

    forwarding =
      %{
        "call_forwarding_enabled" => enabled?,
        "forwards_to" => effective_forwards_to,
        "forwarding_type" =>
          forwarding_type || Map.get(existing_forwarding, "forwarding_type") || "always"
      }
      |> reject_nil_values()

    voice_settings
    |> Map.take(@mutable_voice_fields)
    |> Map.put("call_forwarding", forwarding)
    |> reject_nil_values()
  end

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  defp extract_phone_number_id(%{"id" => id}) when is_binary(id) and id != "", do: {:ok, id}

  defp extract_phone_number_id(_),
    do: {:error, Telnyx.Error.api("Phone number record missing id")}

  # API key resolution mirrors `Telnyx.CallControl.get_api_key/1`. Source order:
  # 1. Explicit `:api_key` opt (not supported in the no-opts arities — added when
  #    consumers ask for it).
  # 2. `Application.get_env(:telnyx, :api_key)` — accepts a literal string or
  #    `{:system, "ENV_VAR"}`.
  defp get_api_key do
    case get_api_key_from_config() do
      nil ->
        {:error,
         Telnyx.Error.authentication(
           "API key not found. Set :telnyx, :api_key in application config or " <>
             "TELNYX_API_KEY environment variable"
         )}

      "" ->
        {:error, Telnyx.Error.authentication("API key cannot be empty")}

      key when is_binary(key) ->
        {:ok, key}
    end
  end

  defp get_api_key_from_config do
    case Application.get_env(:telnyx, :api_key) do
      {:system, env_var} -> System.get_env(env_var)
      value -> value
    end
  end
end
