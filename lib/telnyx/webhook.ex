defmodule Telnyx.Webhook do
  @moduledoc """
  Webhook signature validation for Telnyx webhooks.

  Telnyx signs all webhooks using ED25519 signatures. This module provides
  functions to validate those signatures to ensure webhooks are authentic.

  ## Configuration

  Configure the Telnyx public key in your application config:

      config :telnyx,
        webhook_public_key: "your-public-key-from-telnyx-portal"

  You can find your public key in the Telnyx Portal under:
  Account -> API Keys -> Public Key

  ## Usage in Phoenix Controller

      defmodule MyAppWeb.TelnyxWebhookController do
        use MyAppWeb, :controller

        def handle(conn, params) do
          signature = get_req_header(conn, "telnyx-signature-ed25519") |> List.first()
          timestamp = get_req_header(conn, "telnyx-timestamp") |> List.first()
          raw_body = conn.assigns[:raw_body]  # Must capture raw body in plug

          case Telnyx.Webhook.verify(raw_body, signature, timestamp) do
            :ok ->
              # Process webhook
              process_event(params)
              json(conn, %{status: "ok"})

            {:error, reason} ->
              conn
              |> put_status(401)
              |> json(%{error: "Invalid signature", reason: reason})
          end
        end
      end

  ## Capturing Raw Body

  To validate signatures, you need the raw request body. Add this plug to your endpoint:

      defmodule MyAppWeb.Endpoint do
        # ... other plugs ...

        plug Plug.Parsers,
          parsers: [:json],
          pass: ["application/json"],
          json_decoder: Jason,
          body_reader: {MyAppWeb.CacheBodyReader, :read_body, []}
      end

      defmodule MyAppWeb.CacheBodyReader do
        def read_body(conn, opts) do
          {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
          conn = Plug.Conn.assign(conn, :raw_body, body)
          {:ok, body, conn}
        end
      end

  """

  @tolerance_seconds 300

  @doc """
  Verify a Telnyx webhook signature.

  ## Parameters

  - `payload` - The raw request body as a string
  - `signature` - The value of the `telnyx-signature-ed25519` header (Base64 encoded)
  - `timestamp` - The value of the `telnyx-timestamp` header
  - `opts` - Optional keyword list:
    - `:public_key` - Override the configured public key
    - `:tolerance` - Timestamp tolerance in seconds (default: 300)

  ## Returns

  - `:ok` - Signature is valid
  - `{:error, :invalid_signature}` - Signature does not match
  - `{:error, :timestamp_expired}` - Timestamp is outside tolerance window
  - `{:error, :missing_public_key}` - No public key configured
  - `{:error, :invalid_public_key}` - Public key format is invalid

  ## Examples

      iex> Telnyx.Webhook.verify(raw_body, signature, timestamp)
      :ok

      iex> Telnyx.Webhook.verify(raw_body, "invalid", timestamp)
      {:error, :invalid_signature}

  """
  @spec verify(String.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, atom()}
  def verify(payload, signature, timestamp, opts \\ [])

  def verify(payload, signature, timestamp, opts)
      when is_binary(payload) and is_binary(signature) and is_binary(timestamp) do
    with {:ok, public_key} <- get_public_key(opts),
         {:ok, decoded_key} <- decode_public_key(public_key),
         {:ok, decoded_signature} <- decode_signature(signature),
         :ok <- verify_timestamp(timestamp, opts),
         :ok <- verify_signature(payload, timestamp, decoded_signature, decoded_key) do
      :ok
    end
  end

  def verify(_payload, _signature, _timestamp, _opts) do
    {:error, :invalid_parameters}
  end

  @doc """
  Check if a webhook signature is valid (boolean version).

  This is a convenience function that returns a boolean instead of
  tagged tuples. Useful for simple validation checks.

  ## Examples

      if Telnyx.Webhook.valid?(raw_body, signature, timestamp) do
        process_webhook(params)
      else
        reject_request()
      end

  """
  @spec valid?(String.t(), String.t(), String.t(), keyword()) :: boolean()
  def valid?(payload, signature, timestamp, opts \\ []) do
    verify(payload, signature, timestamp, opts) == :ok
  end

  @doc """
  Extract and verify a webhook from a Plug.Conn.

  This is a convenience function for Phoenix controllers that extracts
  the required headers and raw body from the connection.

  Requires the raw body to be stored in `conn.assigns[:raw_body]`.

  ## Examples

      def handle_webhook(conn, _params) do
        case Telnyx.Webhook.verify_conn(conn) do
          :ok ->
            # Process webhook
            json(conn, %{status: "ok"})

          {:error, reason} ->
            conn |> put_status(401) |> json(%{error: reason})
        end
      end

  """
  @spec verify_conn(Plug.Conn.t(), keyword()) :: :ok | {:error, atom()}
  def verify_conn(conn, opts \\ []) do
    with {:ok, signature} <- get_header(conn, "telnyx-signature-ed25519"),
         {:ok, timestamp} <- get_header(conn, "telnyx-timestamp"),
         {:ok, raw_body} <- get_raw_body(conn) do
      verify(raw_body, signature, timestamp, opts)
    end
  end

  # Private functions

  defp get_public_key(opts) do
    key =
      Keyword.get(opts, :public_key) ||
        Application.get_env(:telnyx, :webhook_public_key)

    case key do
      nil -> {:error, :missing_public_key}
      key when is_binary(key) -> {:ok, key}
    end
  end

  defp decode_public_key(public_key) do
    case Base.decode64(public_key) do
      {:ok, decoded} when byte_size(decoded) == 32 ->
        {:ok, decoded}

      {:ok, _} ->
        {:error, :invalid_public_key}

      :error ->
        {:error, :invalid_public_key}
    end
  end

  defp decode_signature(signature) do
    case Base.decode64(signature) do
      {:ok, decoded} when byte_size(decoded) == 64 ->
        {:ok, decoded}

      {:ok, _} ->
        {:error, :invalid_signature}

      :error ->
        {:error, :invalid_signature}
    end
  end

  defp verify_timestamp(timestamp, opts) do
    tolerance = Keyword.get(opts, :tolerance, @tolerance_seconds)

    case Integer.parse(timestamp) do
      {ts, ""} ->
        now = System.system_time(:second)

        if abs(now - ts) <= tolerance do
          :ok
        else
          {:error, :timestamp_expired}
        end

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  defp verify_signature(payload, timestamp, signature, public_key) do
    # Telnyx signs: timestamp + "." + payload
    signed_payload = "#{timestamp}.#{payload}"

    case :crypto.verify(:eddsa, :none, signed_payload, signature, [public_key, :ed25519]) do
      true -> :ok
      false -> {:error, :invalid_signature}
    end
  end

  defp get_header(conn, header_name) do
    case Plug.Conn.get_req_header(conn, header_name) do
      [value | _] -> {:ok, value}
      [] -> {:error, :missing_header}
    end
  end

  defp get_raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> {:error, :missing_raw_body}
      body when is_binary(body) -> {:ok, body}
    end
  end
end
