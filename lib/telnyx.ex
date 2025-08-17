defmodule Telnyx do
  @moduledoc """
  Modern Elixir client for the Telnyx SMS API.

  ## Quick Start

      # Configure your API key
      config :telnyx,
        api_key: {:system, "TELNYX_API_KEY"},
        default_messaging_profile_id: "your-profile-id"

      # Send an SMS
      Telnyx.SMS.send(%{
        to: "+19876543210",
        text: "Hello from Telnyx!"
      })

  ## Features

  - **Modern Architecture**: Built with Finch HTTP client and structured error handling
  - **Flexible Configuration**: Per-client/per-operation configuration support
  - **Telemetry Integration**: Built-in observability for monitoring and debugging
  - **Structured Errors**: Clear error categorization for upstream retry logic
  - **Domain-Driven Design**: Clean separation of concerns and boundaries

  ## Configuration

  ### Global Configuration (Application Environment)

      config :telnyx,
        api_key: {:system, "TELNYX_API_KEY"},
        default_messaging_profile_id: "abc-123-def",
        default_from: "+14165551234",
        webhook_url: "https://your-app.com/webhooks/telnyx",
        timeout: 10_000

  ### Per-Operation Configuration

      # Client-specific config
      config = Telnyx.Config.new(
        messaging_profile_id: "client-profile-123",
        default_from: "+14165551234",
        webhook_url: "https://app.com/webhooks/notifications"
      )

      Telnyx.SMS.send(%{
        to: "+19876543210",
        text: "Your order is ready!"
      }, config)

  ## Error Handling

  The library provides structured error types for reliable error handling:

      case Telnyx.SMS.send(message, config) do
        {:ok, result} ->
          # Success - message queued/sent
          Logger.info("SMS sent", message_id: result.id)

        {:error, %Telnyx.Error{type: :validation}} ->
          # Invalid message format - don't retry
          {:discard, "Invalid message"}

        {:error, %Telnyx.Error{type: :rate_limit, retry_after: delay}} ->
          # Rate limited - retry after delay
          {:snooze, delay}

        {:error, %Telnyx.Error{type: :network}} ->
          # Network error - retry with backoff
          {:error, "Network failure"}
      end

  ## Telemetry

  The library emits telemetry events for observability:

      :telemetry.attach("my-sms-handler", [:telnyx, :sms, :send, :stop], fn
        _event, %{duration: duration}, %{status: :success, message_id: id}, _config ->
          MyApp.Metrics.increment("sms.sent", tags: %{message_id: id})

        _event, %{duration: duration}, %{status: :error, error_type: type}, _config ->
          MyApp.Metrics.increment("sms.failed", tags: %{error_type: type})
      end, nil)

  See `Telnyx.Telemetry` for complete event documentation.
  """

  # Convenience delegation to main SMS interface
  defdelegate send(message, config \\ nil), to: Telnyx.SMS

  @doc """
  Returns the version of the Telnyx library.
  """
  def version do
    Application.spec(:telnyx, :vsn) |> to_string()
  end
end