defmodule Telnyx.MessagingCompliance do
  @moduledoc """
  Transport primitives for Telnyx 10DLC and toll-free messaging registration.

  Product workflow and lifecycle decisions belong to the calling application.
  This module only authenticates, sends one API request, and normalizes the
  carrier response. The HTTP client is injectable so tests never need network
  access or credentials.
  """

  alias Telnyx.Client.FinchClient

  @default_timeout 15_000

  def create_brand(params, opts \\ []),
    do: request(:post, "/10dlc/brand", params, opts)

  def get_brand(brand_id, opts \\ []),
    do: request(:get, "/10dlc/brand/#{encode(brand_id)}", nil, opts)

  def trigger_brand_otp(brand_id, params, opts \\ []),
    do: request(:post, "/10dlc/brand/#{encode(brand_id)}/smsOtp", params, opts)

  def get_brand_otp(brand_id, opts \\ []),
    do: request(:get, "/10dlc/brand/#{encode(brand_id)}/smsOtp", nil, opts)

  def verify_brand_otp(brand_id, otp_pin, opts \\ []) when is_binary(otp_pin),
    do: request(:put, "/10dlc/brand/#{encode(brand_id)}/smsOtp", %{"otpPin" => otp_pin}, opts)

  def create_campaign(params, opts \\ []),
    do: request(:post, "/10dlc/campaignBuilder", params, opts)

  def get_campaign(campaign_id, opts \\ []),
    do: request(:get, "/10dlc/campaign/#{encode(campaign_id)}", nil, opts)

  def assign_phone_number(phone_number, campaign_id, opts \\ []) do
    request(
      :post,
      "/10dlc/phone_number_campaigns",
      %{"phoneNumber" => phone_number, "campaignId" => campaign_id},
      opts
    )
  end

  def get_phone_number_campaign(phone_number, opts \\ []),
    do: request(:get, "/10dlc/phone_number_campaigns/#{encode(phone_number)}", nil, opts)

  def create_toll_free_verification(params, opts \\ []),
    do: request(:post, "/messaging_tollfree/verification/requests", params, opts)

  def get_toll_free_verification(request_id, opts \\ []),
    do:
      request(
        :get,
        "/messaging_tollfree/verification/requests/#{encode(request_id)}",
        nil,
        opts
      )

  defp request(method, path, params, opts) do
    with {:ok, api_key} <- api_key(opts),
         {:ok, body} <- encode_body(method, params),
         {:ok, response} <- send_request(method, path, body, api_key, opts) do
      normalize_response(response)
    end
  end

  defp send_request(method, path, body, api_key, opts) do
    client = Keyword.get(opts, :http_client, FinchClient)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case method do
      :get -> client.get(path, headers, timeout)
      :post -> client.post(path, headers, body, timeout)
      :put -> client.put(path, headers, body, timeout)
    end
  end

  defp normalize_response(%{status: status, body: body}) when status in 200..299 do
    case decode_body(body) do
      {:ok, %{"data" => data}} -> {:ok, data}
      {:ok, data} when is_map(data) or is_list(data) -> {:ok, data}
      {:ok, _unexpected} -> invalid_response(status)
      {:error, _reason} -> invalid_response(status)
    end
  end

  defp normalize_response(%{status: status, body: body}) do
    case decode_body(body) do
      {:ok, %{"errors" => [error | _]}} when is_map(error) ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, %{"error" => error}} when is_map(error) ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, error} when is_map(error) ->
        {:error, Telnyx.Error.from_response(error, status)}

      _invalid ->
        invalid_response(status)
    end
  end

  defp decode_body(body) when is_map(body) or is_list(body), do: {:ok, body}
  defp decode_body(""), do: {:ok, %{}}
  defp decode_body(body) when is_binary(body), do: Jason.decode(body)
  defp decode_body(_body), do: {:error, :invalid_body}

  defp encode_body(:get, _params), do: {:ok, ""}
  defp encode_body(_method, params), do: Jason.encode(params)

  defp api_key(opts) do
    configured =
      case Keyword.fetch(opts, :api_key) do
        {:ok, explicit} -> explicit
        :error -> Telnyx.Config.new(messaging_profile_id: nil) |> Telnyx.Config.get_api_key()
      end

    case configured do
      value when is_binary(value) and value != "" -> {:ok, value}
      _missing -> {:error, Telnyx.Error.authentication("Telnyx API key is not configured")}
    end
  end

  defp invalid_response(status) do
    {:error,
     Telnyx.Error.api("Unexpected Telnyx response",
       code: "invalid_telnyx_response",
       status_code: status
     )}
  end

  defp encode(value), do: value |> to_string() |> URI.encode(&URI.char_unreserved?/1)
end
