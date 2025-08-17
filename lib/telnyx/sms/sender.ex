defmodule Telnyx.SMS.Sender do
  @moduledoc """
  Core SMS sending logic with HTTP client abstraction.

  Handles the HTTP communication with Telnyx API and response parsing.
  """

  alias Telnyx.Client.FinchClient
  alias Telnyx.SMS.{Message, DeliveryResult}

  require Logger

  @messages_endpoint "/messages"

  @doc """
  Sends an SMS message via Telnyx API.

  ## Examples

      iex> message = %Telnyx.SMS.Message{to: "+19876543210", text: "Hello!"}
      iex> config = %Telnyx.Config{messaging_profile_id: "abc-123"}
      iex> Telnyx.SMS.Sender.send(message, config)
      {:ok, %Telnyx.SMS.DeliveryResult{id: "msg_123", status: :queued}}

  """
  @spec send(Message.t(), Telnyx.Config.t()) ::
          {:ok, DeliveryResult.t()} | {:error, Telnyx.Error.t()}
  def send(%Message{} = message, %Telnyx.Config{} = config) do
    with {:ok, api_key} <- validate_api_key(config),
         {:ok, merged_message} <- merge_message_with_config(message, config),
         {:ok, body} <- encode_request_body(merged_message),
         {:ok, response} <- make_http_request(api_key, body, config.timeout),
         {:ok, result} <- parse_response(response) do
      {:ok, result}
    end
  end

  # Private functions

  defp validate_api_key(config) do
    case Telnyx.Config.get_api_key(config) do
      nil ->
        {:error,
         Telnyx.Error.authentication(
           "API key not found. Set via config or TELNYX_API_KEY environment variable"
         )}

      "" ->
        {:error, Telnyx.Error.authentication("API key cannot be empty")}

      api_key when is_binary(api_key) ->
        {:ok, api_key}
    end
  end

  defp merge_message_with_config(message, config) do
    merged = Message.merge_with_config(message, config)

    # Validate that we have either a 'from' number or messaging_profile_id
    case {merged.from, merged.messaging_profile_id} do
      {nil, nil} ->
        {:error,
         Telnyx.Error.validation(
           "Either 'from' phone number or 'messaging_profile_id' must be provided"
         )}

      _ ->
        {:ok, merged}
    end
  end

  defp encode_request_body(message) do
    case Jason.encode(Message.to_api_params(message)) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Telnyx.Error.unknown("JSON encoding failed: #{inspect(reason)}")}
    end
  end

  defp make_http_request(api_key, body, timeout) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.post(@messages_endpoint, headers, body, timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout after #{timeout}ms")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  defp parse_response(%{status: status, body: body}) when status in 200..299 do
    case Jason.decode(body) do
      {:ok, %{"data" => data}} ->
        result = DeliveryResult.from_response(data)
        {:ok, result}

      {:ok, response} ->
        Logger.warning("Unexpected Telnyx response format", response: response)
        {:error, Telnyx.Error.api("Unexpected response format")}

      {:error, reason} ->
        Logger.error("Failed to parse Telnyx response", body: body, reason: reason)
        {:error, Telnyx.Error.api("Invalid JSON response")}
    end
  end

  defp parse_response(%{status: status, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"errors" => [error | _]}} ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, %{"error" => error}} ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, response} ->
        Logger.warning("Unexpected Telnyx error response", response: response, status: status)
        {:error, Telnyx.Error.api("Unexpected error response", status_code: status)}

      {:error, _reason} ->
        Logger.error("Failed to parse Telnyx error response", body: body, status: status)
        {:error, Telnyx.Error.api("Invalid error response", status_code: status)}
    end
  end
end