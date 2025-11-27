# Telnyx

[![Hex.pm Version](https://img.shields.io/hexpm/v/telnyx.svg)](https://hex.pm/packages/telnyx)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/telnyx)

Modern Elixir client for the Telnyx API with support for SMS, Call Control, and webhook signature validation. Features telemetry integration, structured error handling, and flexible multi-tenant configuration.

## Features

- **SMS Messaging**: Send SMS with delivery tracking and webhooks
- **Call Control**: Transfer, answer, and hangup calls via programmable voice API
- **Webhook Validation**: ED25519 signature verification for secure webhook handling
- **Multi-Tenant Support**: Per-operation configuration for SaaS applications
- **Telemetry Integration**: Built-in observability for monitoring and debugging
- **Structured Errors**: Clear error categorization for robust retry logic
- **Modern Architecture**: Built with Finch HTTP client for performance

## Installation

Add `telnyx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telnyx, "~> 1.0"}
  ]
end
```

## Quick Start

### 1. Configure Your API Key

```elixir
# config/config.exs
config :telnyx,
  api_key: {:system, "TELNYX_API_KEY"},
  default_messaging_profile_id: "your-default-profile-id",
  webhook_public_key: {:system, "TELNYX_PUBLIC_KEY"}  # For webhook validation
```

### 2. Send Your First SMS

```elixir
# Simple send with default configuration
Telnyx.SMS.send(%{
  to: "+19876543210",
  text: "Hello from Telnyx!"
})
# => {:ok, %Telnyx.SMS.DeliveryResult{id: "msg_123", status: :queued, ...}}
```

### 3. Transfer a Call

```elixir
# Transfer to SIP trunk (e.g., LiveKit)
Telnyx.CallControl.transfer(call_control_id, "sip:+14155551234@trunk.livekit.cloud")

# Transfer to PSTN (e.g., call center)
Telnyx.CallControl.transfer(call_control_id, "+18005551234")
# => {:ok, %Telnyx.CallControl.Result{command_id: "cmd_abc", status: :ok}}
```

---

## Call Control API

The Call Control module provides commands for routing and managing inbound calls using Telnyx's programmable voice API. This is useful for building IVR systems, call routing, and integrating with SIP trunks like LiveKit.

### Available Commands

| Function | Description |
|----------|-------------|
| `transfer/3` | Transfer a call to a SIP URI or PSTN number |
| `hangup/2` | Terminate an active call |
| `answer/2` | Answer an incoming call (required before playing audio) |

### Transfer Calls

```elixir
# Transfer to LiveKit SIP trunk
{:ok, result} = Telnyx.CallControl.transfer(
  call_control_id,
  "sip:+14155551234@trunk.livekit.cloud"
)

# Transfer to PSTN call center
{:ok, result} = Telnyx.CallControl.transfer(
  call_control_id,
  "+18005551234"
)

# With explicit API key (for multi-tenant)
{:ok, result} = Telnyx.CallControl.transfer(
  call_control_id,
  destination,
  api_key: "KEY..."
)
```

### Hangup Calls

```elixir
# Gracefully terminate a call
{:ok, result} = Telnyx.CallControl.hangup(call_control_id)
```

### Answer Calls

```elixir
# Answer before playing audio (not needed for blind transfers)
{:ok, result} = Telnyx.CallControl.answer(call_control_id)
```

### Call Control Result

All commands return a structured result:

```elixir
%Telnyx.CallControl.Result{
  command_id: "cmd_abc123",      # Telnyx command tracking ID
  status: :ok,                    # Always :ok on success
  action: :transfer,              # :transfer | :hangup | :answer
  call_control_id: "v2:xyz789"   # Echo back for correlation
}
```

### Inbound Call Routing Example

```elixir
defmodule MyAppWeb.TelnyxWebhookController do
  use MyAppWeb, :controller

  def inbound(conn, %{"data" => %{"payload" => payload}}) do
    call_control_id = payload["call_control_id"]
    to_number = payload["to"]

    case route_call(to_number) do
      {:livekit, sip_uri} ->
        {:ok, _} = Telnyx.CallControl.transfer(call_control_id, sip_uri)
        json(conn, %{status: "transferred_to_livekit"})

      {:call_center, pstn_number} ->
        {:ok, _} = Telnyx.CallControl.transfer(call_control_id, pstn_number)
        json(conn, %{status: "transferred_to_call_center"})

      :unknown ->
        {:ok, _} = Telnyx.CallControl.hangup(call_control_id)
        json(conn, %{status: "unknown_number"})
    end
  end
end
```

---

## Webhook Signature Validation

Telnyx signs all webhooks using ED25519 signatures. This module validates those signatures to ensure webhooks are authentic.

### Configuration

Get your public key from the [Telnyx Portal](https://portal.telnyx.com/#/api-keys/public-key):

```elixir
config :telnyx,
  webhook_public_key: "your-base64-encoded-public-key"
```

### Verify Webhooks

```elixir
# Basic verification
case Telnyx.Webhook.verify(raw_body, signature, timestamp) do
  :ok ->
    # Signature valid, process webhook
    process_event(params)

  {:error, :invalid_signature} ->
    # Signature doesn't match
    reject_request()

  {:error, :timestamp_expired} ->
    # Request too old (>5 minutes)
    reject_request()

  {:error, :missing_public_key} ->
    # Public key not configured
    log_error()
end

# Boolean version
if Telnyx.Webhook.valid?(raw_body, signature, timestamp) do
  process_webhook(params)
end
```

### Phoenix Controller Integration

```elixir
defmodule MyAppWeb.TelnyxWebhookController do
  use MyAppWeb, :controller

  def handle(conn, params) do
    signature = get_req_header(conn, "telnyx-signature-ed25519") |> List.first()
    timestamp = get_req_header(conn, "telnyx-timestamp") |> List.first()
    raw_body = conn.assigns[:raw_body]

    case Telnyx.Webhook.verify(raw_body, signature, timestamp) do
      :ok ->
        process_event(params)
        json(conn, %{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(401)
        |> json(%{error: "Invalid signature", reason: reason})
    end
  end
end
```

### Capturing Raw Body

To validate signatures, you need the raw request body. Add this plug to your endpoint:

```elixir
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
```

### Using verify_conn/2

Convenience function for Phoenix controllers:

```elixir
def handle_webhook(conn, _params) do
  case Telnyx.Webhook.verify_conn(conn) do
    :ok ->
      # Process webhook
      json(conn, %{status: "ok"})

    {:error, reason} ->
      conn |> put_status(401) |> json(%{error: reason})
  end
end
```

### Signature Format

Telnyx signs webhooks using:
- **Algorithm**: ED25519
- **Headers**: `telnyx-signature-ed25519` (Base64), `telnyx-timestamp` (Unix)
- **Signed payload**: `{timestamp}|{raw_body}` (pipe-separated)
- **Tolerance**: 300 seconds (5 minutes)

---

## Configuration

### Global Configuration (Application Environment)

```elixir
# config/config.exs
config :telnyx,
  api_key: {:system, "TELNYX_API_KEY"},
  default_messaging_profile_id: "abc-123-def-456",
  default_from: "+14165551234",
  webhook_url: "https://your-app.com/webhooks/telnyx",
  webhook_failover_url: "https://your-app.com/webhooks/telnyx/failover",
  webhook_public_key: {:system, "TELNYX_PUBLIC_KEY"},
  timeout: 10_000  # 10 seconds
```

### Per-Operation Configuration

Perfect for multi-tenant applications:

```elixir
# Client-specific configurations
client_a_config = Telnyx.Config.new(
  messaging_profile_id: "profile-abc-123",
  default_from: "+14165551234",
  webhook_url: "https://app.com/webhooks/client-a-notifications"
)

client_b_config = Telnyx.Config.new(
  messaging_profile_id: "profile-xyz-456",
  default_from: "+14165555678",
  webhook_url: "https://app.com/webhooks/client-b-alerts"
)

# Send notification for client A
Telnyx.SMS.send(%{
  to: "+19876543210",
  text: "Your order is ready for pickup!"
}, client_a_config)

# Send alert for client B
Telnyx.SMS.send(%{
  to: "+15555551234",
  text: "Action required: Review pending request"
}, client_b_config)
```

---

## Usage Examples

### Basic SMS Sending

```elixir
# With default configuration
result = Telnyx.SMS.send(%{
  to: "+19876543210",
  text: "Welcome to our service!"
})

case result do
  {:ok, delivery} ->
    IO.puts("SMS sent! Message ID: #{delivery.id}")

  {:error, error} ->
    IO.puts("Failed to send SMS: #{error.message}")
end
```

### Per-Message Overrides

```elixir
config = Telnyx.Config.new(
  messaging_profile_id: "default-profile",
  default_from: "+14165551234"
)

# Override the 'from' number for this specific message
Telnyx.SMS.send(%{
  to: "+19876543210",
  text: "Urgent: System maintenance in 10 minutes",
  from: "+14165550911"  # Override default number
}, config)
```

### With Webhooks

```elixir
Telnyx.SMS.send(%{
  to: "+19876543210",
  text: "Your order is confirmed!",
  webhook_url: "https://your-app.com/sms-delivery-webhook",
  webhook_failover_url: "https://your-app.com/sms-webhook-backup"
}, config)
```

---

## Error Handling

The library provides structured error types for reliable error handling:

```elixir
case Telnyx.SMS.send(message, config) do
  {:ok, result} ->
    # Success - message queued/sent
    Logger.info("SMS sent successfully", message_id: result.id)

  {:error, %Telnyx.Error{type: :validation} = error} ->
    # Invalid message format - don't retry
    Logger.error("Invalid SMS message: #{error.message}")
    {:discard, "Invalid message"}

  {:error, %Telnyx.Error{type: :authentication}} ->
    # API key issue - don't retry, fix configuration
    Logger.error("Authentication failed - check API key")
    {:discard, "Authentication failed"}

  {:error, %Telnyx.Error{type: :rate_limit, retry_after: delay}} ->
    # Rate limited - retry after delay
    Logger.warn("Rate limited, retrying in #{delay} seconds")
    {:snooze, delay}

  {:error, %Telnyx.Error{type: :network}} ->
    # Network error - retry with backoff
    Logger.error("Network error sending SMS")
    {:error, "Network failure"}

  {:error, %Telnyx.Error{type: :api}} ->
    # Telnyx API error - may be retryable
    Logger.error("Telnyx API error: #{error.message}")
    {:error, "API error"}
end
```

### Integration with Oban (Background Jobs)

Perfect for reliable SMS delivery in production:

```elixir
defmodule MyApp.Workers.SmsWorker do
  use Oban.Worker, queue: :sms, max_attempts: 3

  def perform(%Oban.Job{args: %{"message" => message, "config" => config_params}}) do
    config = struct(Telnyx.Config, config_params)

    case Telnyx.SMS.send(message, config) do
      {:ok, _result} ->
        :ok

      {:error, %Telnyx.Error{type: :rate_limit, retry_after: delay}} ->
        {:snooze, delay}  # Oban will retry after delay

      {:error, %Telnyx.Error{type: :validation}} ->
        {:discard, "Invalid message"}  # Don't retry validation errors

      {:error, %Telnyx.Error{type: :authentication}} ->
        {:discard, "Authentication failed"}  # Don't retry auth errors

      {:error, _error} ->
        {:error, "SMS failed"}  # Retry with exponential backoff
    end
  end
end

# Enqueue SMS for background processing
%{
  "message" => %{to: "+19876543210", text: "Hello!"},
  "config" => %{messaging_profile_id: "profile-123"}
}
|> MyApp.Workers.SmsWorker.new()
|> Oban.insert()
```

---

## Telemetry & Monitoring

The library emits telemetry events for comprehensive observability:

### SMS Events

```elixir
[:telnyx, :sms, :send, :start]
[:telnyx, :sms, :send, :stop]
[:telnyx, :sms, :send, :exception]
```

### Call Control Events

```elixir
[:telnyx, :call_control, :transfer, :start]
[:telnyx, :call_control, :transfer, :stop]
[:telnyx, :call_control, :transfer, :exception]

[:telnyx, :call_control, :hangup, :start]
[:telnyx, :call_control, :hangup, :stop]
[:telnyx, :call_control, :hangup, :exception]

[:telnyx, :call_control, :answer, :start]
[:telnyx, :call_control, :answer, :stop]
[:telnyx, :call_control, :answer, :exception]
```

### Example Telemetry Handler

```elixir
# Attach telemetry handler for monitoring
:telemetry.attach_many(
  "my-app-telnyx-telemetry",
  [
    [:telnyx, :sms, :send, :start],
    [:telnyx, :sms, :send, :stop],
    [:telnyx, :sms, :send, :exception],
    [:telnyx, :call_control, :transfer, :stop]
  ],
  &MyApp.Telemetry.handle_telnyx_event/4,
  nil
)

def handle_telnyx_event([:telnyx, :sms, :send, :stop], measurements, metadata, _config) do
  duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

  case metadata.status do
    :success ->
      MyApp.Metrics.increment("sms.sent.success")
      MyApp.Metrics.timing("sms.send_duration", duration_ms)

      Logger.info("SMS sent successfully",
        message_id: metadata.message_id,
        duration_ms: duration_ms,
        cost: metadata.cost
      )

    :error ->
      MyApp.Metrics.increment("sms.sent.error", tags: %{error_type: metadata.error_type})

      Logger.error("SMS failed",
        error_type: metadata.error_type,
        error_code: metadata.error_code,
        duration_ms: duration_ms
      )
  end
end
```

---

## Advanced Usage

### Custom HTTP Client

If you need to customize HTTP behavior (proxy, custom certificates, etc.):

```elixir
# Create a custom Finch configuration
config :telnyx, :finch_options, [
  pools: %{
    default: [
      size: 10,
      count: 1,
      conn_opts: [
        transport_opts: [
          verify: :verify_peer,
          cacertfile: "/path/to/custom/ca-cert.pem"
        ]
      ]
    ]
  }
]
```

### Multiple Client Configuration

```elixir
defmodule MyApp.SMS do
  @client_configs %{
    "client_east" => Telnyx.Config.new(
      messaging_profile_id: "east-profile-123",
      default_from: "+14165551234",
      webhook_url: "https://app.com/webhooks/east"
    ),
    "client_west" => Telnyx.Config.new(
      messaging_profile_id: "west-profile-456",
      default_from: "+16045551234",
      webhook_url: "https://app.com/webhooks/west"
    )
  }

  def send_client_sms(client_id, message) do
    case Map.get(@client_configs, client_id) do
      nil ->
        {:error, "Unknown client: #{client_id}"}

      config ->
        Telnyx.SMS.send(message, config)
    end
  end
end

# Usage
MyApp.SMS.send_client_sms("client_east", %{
  to: "+19876543210",
  text: "Welcome to our service!"
})
```

---

## Management APIs

### Messaging Profiles

Create and manage messaging profiles programmatically:

```elixir
# Create a new messaging profile
{:ok, profile} = Telnyx.MessagingProfiles.create(%{
  name: "My App Notifications",
  webhook_url: "https://app.com/webhooks/telnyx",
  webhook_api_version: "2"
}, api_key)

# Find existing profile by name
{:ok, profile} = Telnyx.MessagingProfiles.find_by_name("My App Notifications", api_key)

# Create or update idempotently
{:ok, profile} = Telnyx.MessagingProfiles.create_or_update(%{
  name: "My App Notifications",
  webhook_url: "https://app.com/webhooks/telnyx"
}, api_key)

# List all profiles
{:ok, profiles} = Telnyx.MessagingProfiles.list(api_key)
```

### Phone Numbers

Search, buy, and manage phone numbers:

```elixir
# Search available numbers by area code
{:ok, available} = Telnyx.PhoneNumbers.search_by_area_code("416", api_key)

# Buy a specific number
{:ok, purchase} = Telnyx.PhoneNumbers.buy("+14165551234", api_key)

# Search and buy first available number
{:ok, number} = Telnyx.PhoneNumbers.search_and_buy_first("416", api_key)

# Assign number to messaging profile
{:ok, updated} = Telnyx.PhoneNumbers.assign_to_messaging_profile(
  "phone-number-id",
  "messaging-profile-id",
  api_key
)

# Find phone number by number string
{:ok, phone_record} = Telnyx.PhoneNumbers.find_by_number("+14165551234", api_key)

# List all your phone numbers
{:ok, numbers} = Telnyx.PhoneNumbers.list(api_key)
```

---

## API Reference

### Message Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `to` | `string` | ✅ | Destination phone number in E.164 format |
| `text` | `string` | ✅ | Message content (up to 1600 characters) |
| `from` | `string` | | Source phone number (overrides config default) |
| `messaging_profile_id` | `string` | | Telnyx messaging profile ID (overrides config) |
| `webhook_url` | `string` | | Delivery status webhook URL |
| `webhook_failover_url` | `string` | | Backup webhook URL |
| `use_profile_webhooks` | `boolean` | | Use webhooks configured in messaging profile |

### Error Types

| Type | Description | Retry Recommended |
|------|-------------|-------------------|
| `:validation` | Invalid message format or parameters | ❌ No |
| `:authentication` | API key missing or invalid | ❌ No |
| `:rate_limit` | Rate limit exceeded | ✅ Yes (with delay) |
| `:network` | Network connectivity issues | ✅ Yes (with backoff) |
| `:api` | Telnyx API errors | ⚠️ Depends on specific error |

### API Endpoints Used

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Send SMS | POST | `/v2/messages` |
| Transfer Call | POST | `/v2/calls/{call_control_id}/actions/transfer` |
| Answer Call | POST | `/v2/calls/{call_control_id}/actions/answer` |
| Hangup Call | POST | `/v2/calls/{call_control_id}/actions/hangup` |
| List Profiles | GET | `/v2/messaging_profiles` |
| Create Profile | POST | `/v2/messaging_profiles` |
| List Numbers | GET | `/v2/phone_numbers` |
| Buy Number | POST | `/v2/phone_number_orders` |

### Webhook Headers

| Header | Description |
|--------|-------------|
| `telnyx-signature-ed25519` | Base64-encoded ED25519 signature |
| `telnyx-timestamp` | Unix timestamp when webhook was generated |

---

## Production Guide

### Configuration Strategy

**Recommended: Hybrid approach** with secrets in environment and operational config per-tenant:

```elixir
# config/runtime.exs - Secure secrets from environment
config :telnyx,
  api_key: {:system, "TELNYX_API_KEY"},
  webhook_public_key: {:system, "TELNYX_PUBLIC_KEY"}

# Per-tenant configurations
defmodule MyApp.SMS.Config do
  @tenant_configs %{
    "tenant_a" => Telnyx.Config.new(
      messaging_profile_id: System.get_env("TENANT_A_MESSAGING_PROFILE_ID"),
      default_from: "+14165551234",
      webhook_url: "https://app.com/webhooks/tenant-a"
    ),
    "tenant_b" => Telnyx.Config.new(
      messaging_profile_id: System.get_env("TENANT_B_MESSAGING_PROFILE_ID"),
      default_from: "+16045551234",
      webhook_url: "https://app.com/webhooks/tenant-b"
    )
  }

  def get_config(tenant_id), do: Map.get(@tenant_configs, tenant_id)
end
```

### Oban Integration Pattern

Perfect integration with Oban background jobs:

```elixir
defmodule MyApp.Workers.SmsWorker do
  use Oban.Worker, queue: :sms, max_attempts: 3

  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "message" => msg}}) do
    config = MyApp.SMS.Config.get_config(tenant_id)

    case Telnyx.SMS.send(msg, config) do
      {:ok, _result} ->
        :ok

      {:error, %Telnyx.Error{type: :rate_limit, retry_after: delay}} ->
        {:snooze, delay}  # Oban will retry after delay

      {:error, %Telnyx.Error{type: :validation}} ->
        {:discard, "Invalid message"}  # Don't retry bad data

      {:error, %Telnyx.Error{type: :authentication}} ->
        {:discard, "Auth failed"}  # Don't retry auth issues

      {:error, %Telnyx.Error{type: :network}} ->
        {:error, "Network failure"}  # Retry with exponential backoff

      {:error, %Telnyx.Error{type: :api}} ->
        {:error, "API error"}  # Retry (may be temporary)
    end
  end
end

# Enqueue with deduplication
%{
  "tenant_id" => "tenant_a",
  "message" => %{to: "+19876543210", text: "Your order is ready!"}
}
|> MyApp.Workers.SmsWorker.new(unique: [period: 60])  # Prevent duplicates
|> Oban.insert()
```

### Message Templating

Handle templating in your application layer before calling the library:

```elixir
defmodule MyApp.Notifications.Templates do
  def order_ready_message(order_id) do
    "Your order ##{order_id} is ready for pickup!"
  end

  def staff_alert_message(location, alert_type) do
    "#{String.capitalize(alert_type)} needed at #{location}"
  end

  def appointment_reminder(customer_name, time) do
    "Hi #{customer_name}, reminder: appointment tomorrow at #{time}"
  end
end

# Usage
message_text = Templates.order_ready_message("12345")
Telnyx.SMS.send(%{to: phone, text: message_text}, config)
```

### Webhook Setup for Delivery Confirmation

**Recommended approach** for real-time delivery status:

```elixir
# Configure webhooks per tenant
config = Telnyx.Config.new(
  messaging_profile_id: "profile-123",
  webhook_url: "https://your-app.com/webhooks/telnyx",
  webhook_failover_url: "https://your-app.com/webhooks/telnyx/backup"
)

# Phoenix controller to handle webhooks
defmodule MyAppWeb.TelnyxWebhookController do
  use MyAppWeb, :controller

  def handle_webhook(conn, params) do
    # Validate signature first
    case Telnyx.Webhook.verify_conn(conn) do
      :ok ->
        process_event(params)
        json(conn, %{status: "ok"})

      {:error, reason} ->
        conn |> put_status(401) |> json(%{error: reason})
    end
  end

  defp process_event(params) do
    case params do
      %{"event_type" => "message.sent", "data" => %{"id" => message_id}} ->
        MyApp.Notifications.mark_delivered(message_id)

      %{"event_type" => "message.failed", "data" => %{"id" => message_id, "errors" => errors}} ->
        MyApp.Notifications.mark_failed(message_id, errors)

      %{"event_type" => "message.delivered", "data" => %{"id" => message_id}} ->
        MyApp.Notifications.mark_delivered_to_device(message_id)

      %{"event_type" => "call.initiated", "data" => %{"payload" => payload}} ->
        handle_inbound_call(payload)
    end
  end
end
```

### Production Monitoring & Telemetry

Set up comprehensive monitoring with the built-in telemetry:

```elixir
# In your application.ex
def start(_type, _args) do
  # Attach Telnyx telemetry
  :telemetry.attach_many(
    "myapp-telnyx-telemetry",
    [
      [:telnyx, :sms, :send, :start],
      [:telnyx, :sms, :send, :stop],
      [:telnyx, :sms, :send, :exception],
      [:telnyx, :call_control, :transfer, :stop],
      [:telnyx, :call_control, :hangup, :stop]
    ],
    &MyApp.Telemetry.handle_telnyx_event/4,
    nil
  )

  # ... rest of supervision tree
end

# Telemetry handler
defmodule MyApp.Telemetry do
  require Logger

  def handle_telnyx_event([:telnyx, :sms, :send, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    case metadata.status do
      :success ->
        MyApp.Metrics.increment("sms.sent.success",
          tags: %{tenant: metadata.tenant_id})
        MyApp.Metrics.timing("sms.send_duration", duration_ms)

        Logger.info("SMS sent successfully",
          message_id: metadata.message_id,
          duration_ms: duration_ms,
          cost: metadata.cost
        )

      :error ->
        MyApp.Metrics.increment("sms.sent.error",
          tags: %{error_type: metadata.error_type, tenant: metadata.tenant_id})

        Logger.error("SMS failed",
          error_type: metadata.error_type,
          error_code: metadata.error_code,
          duration_ms: duration_ms
        )
    end
  end

  def handle_telnyx_event([:telnyx, :call_control, action, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("Call control #{action} completed",
      call_control_id: metadata.call_control_id,
      status: metadata.status,
      duration_ms: duration_ms
    )
  end
end
```

### Production Best Practices

#### Queue Configuration
```elixir
# config/runtime.exs
config :myapp, Oban,
  repo: MyApp.Repo,
  queues: [
    sms: 10,        # 10 SMS workers for high throughput
    email: 5,       # 5 email workers
    default: 2      # Other background jobs
  ]
```

#### Connection Pooling
The library uses Finch with automatic connection pooling:
- HTTP/2 multiplexing supported
- Default pool size: 10 connections per host
- Automatic connection management

#### Rate Limiting
Built-in rate limit handling with automatic retry delays:
```elixir
# Rate limits return structured errors with retry timing
{:error, %Telnyx.Error{type: :rate_limit, retry_after: 60}}
# Oban automatically snoozes for the correct duration
```

#### Circuit Breaker Pattern (Optional)
For high-volume applications, consider circuit breaker pattern:

```elixir
defmodule MyApp.Workers.SmsWorker do
  def perform(%{args: args}) do
    if MyApp.CircuitBreaker.open?(:telnyx) do
      {:snooze, 300}  # Wait 5 minutes during outages
    else
      perform_sms(args)
    end
  end

  defp perform_sms(args) do
    case Telnyx.SMS.send(args["message"], args["config"]) do
      {:ok, result} ->
        MyApp.CircuitBreaker.record_success(:telnyx)
        :ok

      {:error, %{type: :api}} = error ->
        MyApp.CircuitBreaker.record_failure(:telnyx)
        {:error, "API error"}

      {:error, error} ->
        {:error, error}
    end
  end
end
```

#### Error Alerting
Set up alerts for critical error patterns:

```elixir
def handle_telnyx_event([:telnyx, :sms, :send, :stop], _measurements, metadata, _config) do
  case metadata do
    %{status: :error, error_type: :authentication} ->
      # Critical: API key issues
      MyApp.Alerts.send_urgent_alert("Telnyx authentication failed")

    %{status: :error, error_type: :api} ->
      # Monitor API error rates
      if error_rate_above_threshold?() do
        MyApp.Alerts.send_alert("High Telnyx API error rate")
      end
  end
end
```

### Performance Considerations

- **Message Deduplication**: Use Oban's unique jobs to prevent duplicate sends
- **Batch Processing**: For high volume, consider batching multiple messages
- **Webhook Security**: Validate webhook signatures from Telnyx
- **Monitoring**: Track success rates, delivery times, and error patterns
- **Failover**: Configure webhook failover URLs for reliability

---

## Telnyx Documentation References

### Official API Documentation

- [Call Control API Overview](https://developers.telnyx.com/docs/voice/programmable-voice/sending-commands)
- [Transfer Call](https://developers.telnyx.com/api/call-control/transfer-call)
- [Answer Call](https://developers.telnyx.com/api/call-control/answer-call)
- [Hangup Call](https://developers.telnyx.com/api/call-control/hangup-call)
- [Voice API Commands](https://developers.telnyx.com/docs/voice/programmable-voice/voice-api-commands-and-resources)
- [Webhook Signature Validation](https://developers.telnyx.com/development/api-fundamentals/webhooks/receiving-webhooks)
- [SMS Messaging API](https://developers.telnyx.com/docs/messaging/sms-api)

### Official Telnyx SDKs (Reference Implementations)

- [telnyx-python](https://github.com/team-telnyx/telnyx-python) - Python SDK
- [telnyx-node](https://github.com/team-telnyx/telnyx-node) - Node.js SDK
- [telnyx-ruby](https://github.com/team-telnyx/telnyx-ruby) - Ruby SDK

### Portal Links

- [Telnyx Portal - API Keys](https://portal.telnyx.com/#/api-keys)
- [Telnyx Portal - Public Key (for webhooks)](https://portal.telnyx.com/#/api-keys/public-key)

---

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/telnyx/sms/sms_test.exs
mix test test/telnyx/call_control/call_control_test.exs
mix test test/telnyx/webhook_test.exs
```

---

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run the test suite (`mix test`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.
